--!strict
-- Radio bantuan: tekan Q (atau tombol RADIO), pilih sinyal, lalu bidik dari kamera atas.
-- Klik kiri / PANGGIL mengonfirmasi, klik kanan / BATAL / Q membatalkan.
-- Selama menu atau bidikan aktif, senjata tidak menembak (attribute "StratagemBusy", dibaca WeaponInput).
-- Game tidak di-pause: karakter tetap rentan sementara pemain membidik.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.StratagemConfig)
local remotes = ReplicatedStorage:WaitForChild("StratagemRemotes")
local throwRemote = remotes:WaitForChild("Throw") :: RemoteEvent
local resultRemote = remotes:WaitForChild("Result") :: RemoteEvent

local player = Players.LocalPlayer

local RADIO_KEY = Enum.KeyCode.Q
local CANCEL_KEYS = { [Enum.KeyCode.X] = true, [Enum.KeyCode.Escape] = true }
local SELECT_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
}

local TOP_HEIGHT = 170 -- tinggi kamera atas di atas karakter (stud)
local TOP_FOV = 70
local BLEND_SECONDS = 0.6 -- lama kamera naik atau turun
local RANGE_MARGIN = 10 -- sasaran dibatasi sedikit di bawah batas server
local DEFAULT_MARKER_RADIUS = 5

type Mode = "idle" | "menu" | "aiming" | "returning"

-- State ---------------------------------------------------------------------

local mode: Mode = "idle"
local selected: Config.Stratagem? = nil
local readyAt: { [string]: number } = {} -- waktu server
local blend = 0 -- 0 = kamera normal, 1 = kamera atas
local blendTarget = 0
local savedCFrame = CFrame.new()
local savedFov = 70
local pointer = Vector2.zero
local usingTouch = false
local targetPosition: Vector3? = nil
local reticle: Part? = nil

local function onCooldown(id: string): boolean
	return (readyAt[id] or 0) > workspace:GetServerTimeNow()
end

local function getRoot(): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- UI ------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "RadioUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local PANEL_COLOR = Color3.fromRGB(15, 18, 24)

local function makeButton(text: string, size: UDim2, parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.BackgroundColor3 = PANEL_COLOR
	button.BackgroundTransparency = 0.25
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = text
	button.Parent = parent
	return button
end

local radioButton = makeButton("RADIO [Q]", UDim2.fromOffset(110, 36), gui)
radioButton.AnchorPoint = Vector2.new(0, 1)
radioButton.Position = UDim2.new(0, 24, 1, -24)

local menu = Instance.new("Frame")
menu.AnchorPoint = Vector2.new(0, 1)
menu.Position = UDim2.new(0, 24, 1, -70)
menu.AutomaticSize = Enum.AutomaticSize.XY
menu.BackgroundColor3 = PANEL_COLOR
menu.BackgroundTransparency = 0.25
menu.BorderSizePixel = 0
menu.Visible = false
menu.Parent = gui

local menuLayout = Instance.new("UIListLayout")
menuLayout.Padding = UDim.new(0, 4)
menuLayout.Parent = menu
local menuPadding = Instance.new("UIPadding")
menuPadding.PaddingTop = UDim.new(0, 8)
menuPadding.PaddingBottom = UDim.new(0, 8)
menuPadding.PaddingLeft = UDim.new(0, 8)
menuPadding.PaddingRight = UDim.new(0, 8)
menuPadding.Parent = menu

local menuTitle = Instance.new("TextLabel")
menuTitle.LayoutOrder = 0
menuTitle.Size = UDim2.fromOffset(300, 22)
menuTitle.BackgroundTransparency = 1
menuTitle.Font = Enum.Font.GothamBold
menuTitle.TextSize = 14
menuTitle.TextColor3 = Color3.fromRGB(170, 175, 185)
menuTitle.TextXAlignment = Enum.TextXAlignment.Left
menuTitle.Text = "RADIO MARKAS — pilih bantuan"
menuTitle.Parent = menu

local rows: { [string]: TextButton } = {}
for i, def in Config.Stratagems do
	local row = makeButton("", UDim2.fromOffset(300, 34), menu)
	row.LayoutOrder = i
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextSize = 15
	rows[def.id] = row
end

local aimBar = Instance.new("Frame")
aimBar.AnchorPoint = Vector2.new(0.5, 1)
aimBar.Position = UDim2.new(0.5, 0, 1, -24)
aimBar.Size = UDim2.fromOffset(460, 84)
aimBar.BackgroundColor3 = PANEL_COLOR
aimBar.BackgroundTransparency = 0.25
aimBar.BorderSizePixel = 0
aimBar.Visible = false
aimBar.Parent = gui

local aimTitle = Instance.new("TextLabel")
aimTitle.Position = UDim2.fromOffset(12, 6)
aimTitle.Size = UDim2.new(1, -24, 0, 22)
aimTitle.BackgroundTransparency = 1
aimTitle.Font = Enum.Font.GothamBold
aimTitle.TextSize = 16
aimTitle.TextColor3 = Color3.new(1, 1, 1)
aimTitle.TextXAlignment = Enum.TextXAlignment.Left
aimTitle.Parent = aimBar

local aimHint = Instance.new("TextLabel")
aimHint.Position = UDim2.fromOffset(12, 28)
aimHint.Size = UDim2.new(1, -24, 0, 18)
aimHint.BackgroundTransparency = 1
aimHint.Font = Enum.Font.Gotham
aimHint.TextSize = 13
aimHint.TextColor3 = Color3.fromRGB(170, 175, 185)
aimHint.TextXAlignment = Enum.TextXAlignment.Left
aimHint.Parent = aimBar

local confirmButton = makeButton("PANGGIL", UDim2.fromOffset(200, 28), aimBar)
confirmButton.Position = UDim2.fromOffset(12, 50)
local cancelButton = makeButton("BATAL", UDim2.fromOffset(120, 28), aimBar)
cancelButton.Position = UDim2.fromOffset(222, 50)

-- Tombol PANGGIL/BATAL hanya untuk sentuhan; dengan mouse, klik kiri/kanan sudah cukup.
local function applyAimLayout()
	confirmButton.Visible = usingTouch
	cancelButton.Visible = usingTouch
	aimBar.Size = UDim2.fromOffset(460, if usingTouch then 84 else 54)
end

local function aimHintText(): string
	if usingTouch then
		return "Ketuk peta untuk membidik, lalu tekan PANGGIL."
	end
	return "Klik kiri untuk memanggil, klik kanan untuk batal."
end

local toast = Instance.new("TextLabel")
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 70)
toast.AutomaticSize = Enum.AutomaticSize.XY
toast.BackgroundColor3 = PANEL_COLOR
toast.BackgroundTransparency = 0.25
toast.BorderSizePixel = 0
toast.Font = Enum.Font.GothamMedium
toast.TextSize = 16
toast.TextColor3 = Color3.new(1, 1, 1)
toast.Visible = false
toast.Parent = gui
local toastPadding = Instance.new("UIPadding")
toastPadding.PaddingTop = UDim.new(0, 8)
toastPadding.PaddingBottom = UDim.new(0, 8)
toastPadding.PaddingLeft = UDim.new(0, 14)
toastPadding.PaddingRight = UDim.new(0, 14)
toastPadding.Parent = toast

local toastToken = 0
local function showToast(text: string)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	toast.Visible = true
	task.delay(3, function()
		if token == toastToken then
			toast.Visible = false
		end
	end)
end

local function refreshRows()
	local now = workspace:GetServerTimeNow()
	for i, def in Config.Stratagems do
		local remaining = (readyAt[def.id] or 0) - now
		local suffix = if remaining > 0 then `   ({math.ceil(remaining)}d)` else ""
		local row = rows[def.id]
		row.Text = `  {i}   {def.name}{suffix}`
		row.TextColor3 = if remaining > 0 then Color3.fromRGB(120, 120, 120) else Color3.new(1, 1, 1)
	end
end

local function render()
	menu.Visible = mode == "menu"
	aimBar.Visible = mode == "aiming"
	radioButton.Visible = mode == "idle" or mode == "menu"
	local def = selected
	if def then
		aimTitle.Text = `BIDIK: {def.name}`
		aimTitle.TextColor3 = def.color
	end
	applyAimLayout()
	refreshRows()
end

local function setMode(newMode: Mode)
	mode = newMode
	render()
	-- Dibaca WeaponInput agar klik yang sama tidak ikut menembak. Ditunda supaya baru
	-- berubah setelah semua handler klik itu selesai.
	local busy = newMode ~= "idle"
	task.defer(function()
		player:SetAttribute("StratagemBusy", busy)
	end)
end

-- Bidikan -------------------------------------------------------------------

local function rayParams(): RaycastParams
	local filter: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(filter, other.Character)
		end
	end
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		table.insert(filter, enemies)
	end
	if reticle then
		table.insert(filter, reticle)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = filter
	return params
end

local function topDownCFrame(root: BasePart): CFrame
	local position = root.Position + Vector3.new(0, TOP_HEIGHT, 0)
	return CFrame.lookAt(position, root.Position, Vector3.new(0, 0, -1)) -- atas layar = utara (-Z)
end

local function destroyReticle()
	if reticle then
		reticle:Destroy()
		reticle = nil
	end
	targetPosition = nil
end

local function createReticle(def: Config.Stratagem)
	destroyReticle()
	local radius = def.radius or DEFAULT_MARKER_RADIUS
	local part = Instance.new("Part")
	part.Name = "RadioReticle"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.3, radius * 2, radius * 2)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = def.color
	part.Transparency = 1 -- tampil setelah kamera sampai di atas
	part.Parent = workspace
	reticle = part
end

local function updateReticle(root: BasePart, camera: Camera)
	local part = reticle
	local def = selected
	if not part or not def then
		return
	end
	if blend < 0.9 then
		part.Transparency = 1
		targetPosition = nil
		return
	end

	applyAimLayout() -- perangkat bisa berganti antara mouse dan sentuhan saat membidik
	if not usingTouch then
		pointer = UserInputService:GetMouseLocation()
	end
	local params = rayParams()
	local ray = camera:ViewportPointToRay(pointer.X, pointer.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	local point: Vector3
	if hit then
		point = hit.Position
	elseif ray.Direction.Y < -0.01 then
		-- Tidak kena apa pun: pakai bidang setinggi kaki karakter.
		local t = (root.Position.Y - 3 - ray.Origin.Y) / ray.Direction.Y
		point = ray.Origin + ray.Direction * t
	else
		part.Transparency = 1
		targetPosition = nil
		return
	end

	-- Batasi jarak mendatar dari karakter, lalu cari tanah tepat di titik itu.
	local offset = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
	local maxDistance = Config.MAX_THROW_DISTANCE - RANGE_MARGIN
	local clamped = offset.Magnitude > maxDistance
	if clamped then
		offset = offset.Unit * maxDistance
	end
	local x, z = root.Position.X + offset.X, root.Position.Z + offset.Z
	local ground = workspace:Raycast(Vector3.new(x, root.Position.Y + 200, z), Vector3.new(0, -400, 0), params)
	if not ground then
		part.Transparency = 1
		targetPosition = nil
		aimHint.Text = "Tidak ada tanah di sana"
		return
	end

	targetPosition = ground.Position
	part.CFrame = CFrame.new(ground.Position + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	part.Transparency = 0.55
	aimHint.Text = if clamped
		then "Di luar jangkauan radio — dibatasi di titik terjauh"
		else aimHintText()
end

-- Transisi ------------------------------------------------------------------

local function easeInOut(t: number): number
	return t * t * (3 - 2 * t)
end

local function restoreCamera()
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = savedFov
	end
end

local function openMenu()
	if mode == "idle" and getRoot() then
		setMode("menu")
	end
end

local function closeMenu()
	if mode == "menu" then
		setMode("idle")
	end
end

local function beginAim(def: Config.Stratagem)
	local camera = workspace.CurrentCamera
	if not camera or not getRoot() then
		return
	end
	selected = def
	savedCFrame = camera.CFrame
	savedFov = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable
	createReticle(def)
	if usingTouch then
		pointer = camera.ViewportSize / 2
	else
		pointer = UserInputService:GetMouseLocation()
	end
	aimHint.Text = aimHintText()
	blendTarget = 1
	setMode("aiming")
end

local function endAim()
	destroyReticle()
	blendTarget = 0
	setMode("returning")
end

local function selectStratagem(index: number)
	local def = Config.Stratagems[index]
	if mode ~= "menu" or not def then
		return
	end
	if onCooldown(def.id) then
		showToast(`{def.name} masih dalam kooldaun`)
		return
	end
	beginAim(def)
end

local function confirm()
	local def = selected
	local position = targetPosition
	if mode ~= "aiming" or not def or not position then
		return
	end
	throwRemote:FireServer(def.id, position)
	showToast(`RADIO: {def.callLine}`)
	endAim()
end

local function abort()
	-- Karakter mati atau hilang: kembali ke kamera normal tanpa animasi.
	destroyReticle()
	if mode == "aiming" or mode == "returning" then
		restoreCamera()
	end
	blend = 0
	blendTarget = 0
	setMode("idle")
end

RunService:BindToRenderStep("RadioCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if mode ~= "aiming" and mode ~= "returning" then
		return
	end
	local camera = workspace.CurrentCamera
	local root = getRoot()
	if not camera or not root then
		abort()
		return
	end

	if blend < blendTarget then
		blend = math.min(blendTarget, blend + dt / BLEND_SECONDS)
	elseif blend > blendTarget then
		blend = math.max(blendTarget, blend - dt / BLEND_SECONDS)
	end

	local alpha = easeInOut(blend)
	camera.CFrame = savedCFrame:Lerp(topDownCFrame(root), alpha)
	camera.FieldOfView = savedFov + (TOP_FOV - savedFov) * alpha

	if mode == "aiming" then
		updateReticle(root, camera)
	elseif blend <= 0 then
		restoreCamera()
		setMode("idle")
	end
end)

-- Input ---------------------------------------------------------------------

local function toggleRadio()
	if mode == "idle" then
		openMenu()
	elseif mode == "menu" then
		closeMenu()
	elseif mode == "aiming" then
		endAim()
	end
end

local function cancel()
	if mode == "menu" then
		closeMenu()
	elseif mode == "aiming" then
		endAim()
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	local inputType = input.UserInputType
	if inputType == Enum.UserInputType.Touch then
		usingTouch = true
		if mode == "aiming" and not processed then
			local inset = GuiService:GetGuiInset()
			pointer = Vector2.new(input.Position.X, input.Position.Y) + inset
		end
		return
	elseif inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.MouseButton2 then
		usingTouch = false
		if processed then
			return
		end
		if inputType == Enum.UserInputType.MouseButton1 then
			confirm()
		else
			cancel()
		end
		return
	end

	if processed and input.KeyCode ~= Enum.KeyCode.Escape then
		return
	end
	if input.KeyCode == RADIO_KEY then
		toggleRadio()
	elseif CANCEL_KEYS[input.KeyCode] then
		cancel()
	elseif SELECT_KEYS[input.KeyCode] then
		selectStratagem(SELECT_KEYS[input.KeyCode])
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		usingTouch = true
		if mode == "aiming" then
			local inset = GuiService:GetGuiInset()
			pointer = Vector2.new(input.Position.X, input.Position.Y) + inset
		end
	elseif input.UserInputType == Enum.UserInputType.MouseMovement then
		usingTouch = false
	end
end)

radioButton.Activated:Connect(toggleRadio)
confirmButton.Activated:Connect(confirm)
cancelButton.Activated:Connect(cancel)
for i, def in Config.Stratagems do
	rows[def.id].Activated:Connect(function()
		selectStratagem(i)
	end)
end

resultRemote.OnClientEvent:Connect(function(id: string, ok: boolean, serverReadyAt: number)
	readyAt[id] = serverReadyAt
	if not ok then
		local def = Config.ById[id]
		showToast(`Panggilan {if def then def.name else id} ditolak (kooldaun, mati, atau terlalu jauh)`)
	end
	refreshRows()
end)

player.CharacterRemoving:Connect(function()
	if mode ~= "idle" then
		abort()
	end
end)

-- Penghitung kooldaun di menu.
task.spawn(function()
	while true do
		task.wait(0.25)
		if mode == "menu" then
			refreshRows()
		end
	end
end)

render()
