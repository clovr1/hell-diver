--!strict
-- Tahan Ctrl kiri, ketik kombinasi panah (atau WASD), lalu klik kiri untuk melempar penanda.
-- Esc / X membatalkan penanda yang sudah siap.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.StratagemConfig)
local remotes = ReplicatedStorage:WaitForChild("StratagemRemotes")
local throwRemote = remotes:WaitForChild("Throw") :: RemoteEvent
local resultRemote = remotes:WaitForChild("Result") :: RemoteEvent

local player = Players.LocalPlayer

local HOLD_KEY = Enum.KeyCode.LeftControl
local CANCEL_KEYS = { [Enum.KeyCode.X] = true, [Enum.KeyCode.Escape] = true }
local KEY_TO_DIR: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.Up] = "U",
	[Enum.KeyCode.Down] = "D",
	[Enum.KeyCode.Left] = "L",
	[Enum.KeyCode.Right] = "R",
	[Enum.KeyCode.W] = "U",
	[Enum.KeyCode.S] = "D",
	[Enum.KeyCode.A] = "L",
	[Enum.KeyCode.D] = "R",
}

-- State ---------------------------------------------------------------------

local open = false
local buffer: { string } = {}
local armed: Config.Stratagem? = nil
local readyAt: { [string]: number } = {} -- waktu server

local function onCooldown(id: string): boolean
	return (readyAt[id] or 0) > workspace:GetServerTimeNow()
end

-- UI ------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "StratagemUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -24)
panel.AutomaticSize = Enum.AutomaticSize.XY
panel.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
panel.BackgroundTransparency = 0.25
panel.BorderSizePixel = 0
panel.Parent = gui

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.Parent = panel

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = panel

local status = Instance.new("TextLabel")
status.LayoutOrder = 0
status.Size = UDim2.fromOffset(300, 22)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamBold
status.TextSize = 16
status.TextColor3 = Color3.new(1, 1, 1)
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = panel

local rows: { [string]: TextLabel } = {}
for i, def in Config.Stratagems do
	local row = Instance.new("TextLabel")
	row.LayoutOrder = i
	row.Size = UDim2.fromOffset(300, 22)
	row.BackgroundTransparency = 1
	row.Font = Enum.Font.Gotham
	row.TextSize = 15
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.RichText = true
	row.Parent = panel
	rows[def.id] = row
end

local function render()
	panel.Visible = open or armed ~= nil

	if armed then
		status.Text = `SIAP: {armed.name} — klik untuk melempar (X batal)`
		status.TextColor3 = armed.color
	else
		status.Text = open and "SINYAL BANTUAN" or ""
		status.TextColor3 = Color3.new(1, 1, 1)
	end

	local now = workspace:GetServerTimeNow()
	for _, def in Config.Stratagems do
		local parts = {}
		for i, dir in def.code do
			local glyph = Config.ARROW_GLYPH[dir]
			if i <= #buffer then
				glyph = `<font color="#ffd54a">{glyph}</font>`
			end
			table.insert(parts, glyph)
		end
		local remaining = (readyAt[def.id] or 0) - now
		local suffix = remaining > 0 and `  ({math.ceil(remaining)}d)` or ""
		local row = rows[def.id]
		row.Text = `{def.name}   {table.concat(parts, " ")}{suffix}`
		row.TextColor3 = remaining > 0 and Color3.fromRGB(120, 120, 120) or Color3.new(1, 1, 1)
	end
end

local function flashError()
	status.Text = "KODE SALAH"
	status.TextColor3 = Color3.fromRGB(255, 70, 70)
end

-- Logika kombinasi -----------------------------------------------------------

local function matches(def: Config.Stratagem): boolean
	for i, dir in buffer do
		if def.code[i] ~= dir then
			return false
		end
	end
	return true
end

local function pushDirection(dir: string)
	table.insert(buffer, dir)

	local candidate: Config.Stratagem? = nil
	for _, def in Config.Stratagems do
		if matches(def) and not onCooldown(def.id) then
			candidate = def
			if #def.code == #buffer then
				-- Kombinasi lengkap. Tidak ada kode yang jadi awalan kode lain (dicek di config).
				armed = def
				buffer = {}
				render()
				return
			end
		end
	end

	if not candidate then
		buffer = {}
		render()
		flashError()
		return
	end
	render()
end

local function setOpen(value: boolean)
	open = value
	buffer = {}
	render()
end

local function cancelArmed()
	armed = nil
	render()
end

-- Input ---------------------------------------------------------------------

-- Dipasang permanen; hanya menelan input WASD/panah saat mode sinyal terbuka, sehingga
-- karakter tidak berjalan sambil mengetik kombinasi.
ContextActionService:BindActionAtPriority(
	"StratagemDirections",
	function(_, state, input)
		if not open then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			local dir = KEY_TO_DIR[input.KeyCode]
			if dir and not armed then
				pushDirection(dir)
			end
		end
		return Enum.ContextActionResult.Sink
	end,
	false,
	Enum.ContextActionPriority.High.Value,
	table.unpack((function()
		local keys = {}
		for key in KEY_TO_DIR do
			table.insert(keys, key)
		end
		return keys
	end)())
)

local function throwBeacon()
	local def = armed
	if not def then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance? }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if not hit then
		return -- klik ke langit; penanda tetap siap
	end

	throwRemote:FireServer(def.id, hit.Position)
	-- Penanda dianggap terpakai. Kalau server menolak, Result akan mengembalikan statusnya.
	armed = nil
	render()
end

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == HOLD_KEY then
		if not processed then
			setOpen(true)
		end
	elseif armed and CANCEL_KEYS[input.KeyCode] then
		cancelArmed()
	elseif armed and input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
		throwBeacon()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == HOLD_KEY then
		setOpen(false)
	end
end)

resultRemote.OnClientEvent:Connect(function(id: string, ok: boolean, serverReadyAt: number)
	readyAt[id] = serverReadyAt
	if not ok then
		-- Ditolak (kooldaun, mati, atau terlalu jauh): jangan hilangkan penanda diam-diam.
		local def = Config.ById[id]
		if def and not onCooldown(id) then
			armed = def
		end
	end
	render()
end)

player.CharacterRemoving:Connect(function()
	setOpen(false)
	cancelArmed()
end)

-- Penghitung kooldaun di UI.
task.spawn(function()
	while true do
		task.wait(0.5)
		if panel.Visible then
			render()
		end
	end
end)

render()
