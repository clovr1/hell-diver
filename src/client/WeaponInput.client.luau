--!strict
-- Tahan klik kiri untuk menembak ke arah kursor. Tidak menembak saat mode sinyal bantuan
-- aktif (Ctrl ditahan atau penanda siap lempar); status itu dibagikan lewat attribute "StratagemBusy".

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Weapon = require(ReplicatedStorage.Shared.WeaponConfig)
local remotes = ReplicatedStorage:WaitForChild("WeaponRemotes")
local fireRemote = remotes:WaitForChild("Fire") :: RemoteEvent
local tracerRemote = remotes:WaitForChild("Tracer") :: RemoteEvent

local player = Players.LocalPlayer

-- HUD amunisi -----------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "WeaponUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local ammoLabel = Instance.new("TextLabel")
ammoLabel.AnchorPoint = Vector2.new(1, 1)
ammoLabel.Position = UDim2.new(1, -24, 1, -24)
ammoLabel.Size = UDim2.fromOffset(220, 36)
ammoLabel.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
ammoLabel.BackgroundTransparency = 0.25
ammoLabel.BorderSizePixel = 0
ammoLabel.Font = Enum.Font.GothamBold
ammoLabel.TextSize = 18
ammoLabel.Parent = gui

local function updateAmmo()
	local ammo = player:GetAttribute("Ammo")
	local value = if typeof(ammo) == "number" then ammo else 0
	ammoLabel.Text = `{Weapon.name}   {value}`
	ammoLabel.TextColor3 = if value > 0 then Color3.new(1, 1, 1) else Color3.fromRGB(255, 80, 80)
end
player:GetAttributeChangedSignal("Ammo"):Connect(updateAmmo)
updateAmmo()

-- Menembak --------------------------------------------------------------------

local firing = false
local lastFire = 0

local function isBusy(): boolean
	return player:GetAttribute("StratagemBusy") == true
end

UserInputService.InputBegan:Connect(function(input, processed)
	-- Klik yang melempar penanda tidak boleh sekaligus menembak: attribute baru dilepas setelah klik diproses.
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not processed and not isBusy() then
		firing = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		firing = false
	end
end)

RunService.Heartbeat:Connect(function()
	if not firing or isBusy() then
		return
	end
	local now = os.clock()
	if now - lastFire < Weapon.fireInterval then
		return
	end
	local ammo = player:GetAttribute("Ammo")
	if typeof(ammo) ~= "number" or ammo < Weapon.ammoPerShot then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not (character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") and camera) then
		return
	end

	-- Titik bidik dari kamera lewat kursor; tembakan sendiri keluar dari badan karakter.
	local mouse = UserInputService:GetMouseLocation()
	local cameraRay = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(cameraRay.Origin, cameraRay.Direction * Weapon.range * 2, params)
	local aim = if hit then hit.Position else cameraRay.Origin + cameraRay.Direction * Weapon.range

	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local direction = aim - origin
	if direction.Magnitude < 1 then
		return
	end

	lastFire = now
	fireRemote:FireServer(origin, direction.Unit)
end)

-- Jejak peluru ----------------------------------------------------------------

tracerRemote.OnClientEvent:Connect(function(origin: Vector3, endpoint: Vector3)
	local length = (endpoint - origin).Magnitude
	if length < 1 then
		return
	end
	local tracer = Instance.new("Part")
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.CanTouch = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Weapon.tracerColor
	tracer.Size = Vector3.new(0.12, 0.12, length)
	tracer.CFrame = CFrame.lookAt(origin, endpoint) * CFrame.new(0, 0, -length / 2)
	tracer.Parent = workspace
	Debris:AddItem(tracer, 0.06)
end)
