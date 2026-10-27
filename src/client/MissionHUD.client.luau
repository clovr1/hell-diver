--!strict
-- Teks tujuan di atas layar (lobby, hitung mundur, terjun, misi) + penanda jarak di atas sasaran misi.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("MissionState")
local objects = workspace:WaitForChild("MissionObjects")

local PANEL_COLOR = Color3.fromRGB(15, 18, 24)
local PENDING_COLOR = Color3.fromRGB(255, 90, 90)
local DONE_COLOR = Color3.fromRGB(90, 255, 130)
local DEFAULT_MARKER_OFFSET = 8 -- stud di atas pusat Part, kalau server tidak mengatur MarkerOffset

local gui = Instance.new("ScreenGui")
gui.Name = "MissionUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Panel tujuan --------------------------------------------------------------------

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 16)
panel.Size = UDim2.fromOffset(460, 70)
panel.BackgroundColor3 = PANEL_COLOR
panel.BackgroundTransparency = 0.25
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(12, 6)
title.Size = UDim2.new(1, -24, 0, 24)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.Position = UDim2.fromOffset(12, 30)
subtitle.Size = UDim2.new(1, -24, 0, 18)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 14
subtitle.TextColor3 = Color3.fromRGB(170, 175, 185)
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = panel

local barBack = Instance.new("Frame")
barBack.Position = UDim2.fromOffset(12, 54)
barBack.Size = UDim2.new(1, -24, 0, 8)
barBack.BackgroundColor3 = Color3.fromRGB(50, 55, 65)
barBack.BorderSizePixel = 0
barBack.Visible = false
barBack.Parent = panel

local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = DONE_COLOR
barFill.BorderSizePixel = 0
barFill.Parent = barBack

local function inMission(): boolean
	return player:GetAttribute("InMission") == true
end

local function render()
	local phase = state:GetAttribute("Phase")
	local active = state:GetAttribute("TowersActive")
	local total = state:GetAttribute("TowersTotal")
	local progress = state:GetAttribute("EvacProgress")
	local countdownEnd = state:GetAttribute("CountdownEnd")

	panel.Visible = true
	barBack.Visible = false

	if phase == "lobby" then
		title.Text = "LOBBY"
		subtitle.Text = "Naik ke dropship, lalu tekan E di konsol untuk memulai penerjunan."
	elseif phase == "countdown" then
		local remaining = if typeof(countdownEnd) == "number"
			then math.max(0, math.ceil(countdownEnd - workspace:GetServerTimeNow()))
			else 0
		title.Text = "PENERJUNAN DIMULAI"
		subtitle.Text = `Naik ke dropship! Berangkat dalam {remaining} detik.`
	elseif not inMission() then
		title.Text = "MISI SEDANG BERLANGSUNG"
		subtitle.Text = "Tunggu di lobby sampai misi selesai."
	elseif phase == "drop" then
		title.Text = "MENERJUN KE PLANET"
		subtitle.Text = "Bersiap mendarat..."
	elseif phase == "towers" then
		title.Text = "MISI: NYALAKAN MENARA RADIO"
		subtitle.Text = `{active}/{total} menara aktif. Tahan E di dekat menara.`
	elseif phase == "evac" then
		title.Text = "KABUR KE TITIK EVAKUASI"
		subtitle.Text = "Semua pemain yang hidup harus berada di dalam lingkaran."
		barBack.Visible = true
		barFill.Size = UDim2.fromScale(if typeof(progress) == "number" then progress else 0, 1)
	elseif phase == "success" then
		title.Text = "MISI SELESAI"
		subtitle.Text = "Kembali ke lobby sebentar lagi."
	else
		panel.Visible = false
	end
end

state.AttributeChanged:Connect(render)
player:GetAttributeChangedSignal("InMission"):Connect(render)
render()

-- Hitung mundur di panel.
task.spawn(function()
	while true do
		task.wait(0.25)
		if state:GetAttribute("Phase") == "countdown" then
			render()
		end
	end
end)

-- Penanda sasaran -----------------------------------------------------------------

type Marker = { label: TextLabel, billboard: BillboardGui }
local markers: { [BasePart]: Marker } = {}

local function addMarker(part: BasePart)
	local name = part:GetAttribute("ObjectiveName")
	if typeof(name) ~= "string" or markers[part] then
		return
	end
	local offset = part:GetAttribute("MarkerOffset")

	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = part
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(180, 44)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, if typeof(offset) == "number" then offset else DEFAULT_MARKER_OFFSET, 0)
	billboard.Parent = gui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextColor3 = PENDING_COLOR
	label.TextStrokeTransparency = 0.4
	label.Parent = billboard

	markers[part] = { label = label, billboard = billboard }
	-- Server menghapus Part (ronde baru): bersihkan penandanya.
	part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(workspace) then
			markers[part] = nil
			billboard:Destroy()
		end
	end)
end

-- Part dan attribute-nya dibuat server di frame yang sama, tapi attribute bisa tiba terlambat:
-- pasang pengamat supaya penanda tetap dibuat begitu ObjectiveName muncul.
local function watch(part: BasePart)
	addMarker(part)
	part:GetAttributeChangedSignal("ObjectiveName"):Connect(function()
		addMarker(part)
	end)
end

for _, child in objects:GetChildren() do
	if child:IsA("BasePart") then
		watch(child)
	end
end
objects.ChildAdded:Connect(function(child)
	if child:IsA("BasePart") then
		watch(child)
	end
end)

task.spawn(function()
	while true do
		task.wait(0.2)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local visible = inMission()
		for part, marker in markers do
			local name = part:GetAttribute("ObjectiveName")
			local done = part:GetAttribute("ObjectiveDone") == true
			marker.billboard.Enabled = visible -- yang masih di lobby tidak perlu melihat penanda misi
			if typeof(name) == "string" then
				local distance = if root and root:IsA("BasePart") then (part.Position - root.Position).Magnitude else 0
				marker.label.Text = if done then `{name} ✓` else `{name}\n{math.floor(distance)} m`
				marker.label.TextColor3 = if done then DONE_COLOR else PENDING_COLOR
			end
		end
	end
end)
