--!strict
-- Efek layar untuk peluncuran dan penerjunan: getar kamera, layar putih (fade), dan FOV melebar saat terjun.
-- Cue dikirim server lewat FlowRemotes.Cinematic: launch, fade_out, fade_in, drop, land.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local cinematic = ReplicatedStorage:WaitForChild("FlowRemotes"):WaitForChild("Cinematic") :: RemoteEvent

local DROP_FOV = 95

local gui = Instance.new("ScreenGui")
gui.Name = "FlowEffects"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.Parent = player:WaitForChild("PlayerGui")

local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.new(1, 1, 1)
overlay.BackgroundTransparency = 1
overlay.BorderSizePixel = 0
overlay.Active = false
overlay.Parent = gui

local function fade(toTransparency: number, seconds: number)
	TweenService:Create(overlay, TweenInfo.new(seconds, Enum.EasingStyle.Quad), { BackgroundTransparency = toTransparency })
		:Play()
end

-- Getar lewat Humanoid.CameraOffset, supaya kamera bawaan tetap bekerja.
local shakeUntil = 0
local shakeStrength = 0
local shaking = false

local function shake(seconds: number, strength: number)
	shakeUntil = os.clock() + seconds
	shakeStrength = strength
end

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if os.clock() < shakeUntil then
		shaking = true
		humanoid.CameraOffset = Vector3.new(
			(math.random() - 0.5) * 2 * shakeStrength,
			(math.random() - 0.5) * 2 * shakeStrength,
			0
		)
	elseif shaking then
		shaking = false
		humanoid.CameraOffset = Vector3.zero
	end
end)

local function setFov(value: number, seconds: number)
	local camera = workspace.CurrentCamera
	if camera then
		TweenService:Create(camera, TweenInfo.new(seconds, Enum.EasingStyle.Quad), { FieldOfView = value }):Play()
	end
end

local baseFov = 70
do
	local camera = workspace.CurrentCamera
	if camera then
		baseFov = camera.FieldOfView
	end
end

cinematic.OnClientEvent:Connect(function(name: string)
	if name == "launch" then
		shake(10, 0.25)
	elseif name == "fade_out" then
		fade(0, 0.7)
	elseif name == "fade_in" then
		fade(1, 1)
	elseif name == "drop" then
		shakeUntil = 0
		fade(1, 1) -- layar putih membuka saat mulai terjun
		setFov(DROP_FOV, 1.5)
	elseif name == "land" then
		shake(0.8, 0.8)
		setFov(baseFov, 0.6)
	end
end)
