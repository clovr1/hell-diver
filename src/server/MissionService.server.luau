--!strict
-- Alur misi: menunggu pemain -> nyalakan menara (tahan E) -> evakuasi -> selesai -> ronde baru.
-- Status disiarkan lewat attribute di ReplicatedStorage.MissionState; penanda sasaran ada di
-- workspace.MissionObjects (client memasang label jarak untuk tiap Part ber-attribute ObjectiveName).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.MissionConfig)

local TICK = 0.25

local state = Instance.new("Folder")
state.Name = "MissionState"
state:SetAttribute("Phase", "waiting") -- waiting | towers | evac | success
state:SetAttribute("TowersActive", 0)
state:SetAttribute("TowersTotal", #Config.towerOffsets)
state:SetAttribute("EvacProgress", 0)
state.Parent = ReplicatedStorage

local objects = Instance.new("Folder")
objects.Name = "MissionObjects"
objects.Parent = workspace

type Points = { towers: { Vector3 }, evac: Vector3 }

-- Pemain ----------------------------------------------------------------------

local function aliveRoots(): { BasePart }
	local roots: { BasePart } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			table.insert(roots, root)
		end
	end
	return roots
end

-- Titik misi ------------------------------------------------------------------

local function groundAt(x: number, z: number, fallbackY: number): Vector3
	local filter: { Instance } = { objects }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(filter, player.Character)
		end
	end
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		table.insert(filter, enemies)
	end
	local markers = workspace:FindFirstChild("MissionPoints")
	if markers then
		table.insert(filter, markers)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = filter

	local hit = workspace:Raycast(Vector3.new(x, 500, z), Vector3.new(0, -1000, 0), params)
	return if hit then hit.Position else Vector3.new(x, fallbackY, z)
end

local function resolvePoints(): Points
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local center = if spawn then spawn.Position else Vector3.zero
	local baseY = center.Y

	local markers = workspace:FindFirstChild("MissionPoints")
	if markers then
		local towers: { Vector3 } = {}
		while true do
			local part = markers:FindFirstChild(`Tower{#towers + 1}`)
			if not part or not part:IsA("BasePart") then
				break
			end
			table.insert(towers, groundAt(part.Position.X, part.Position.Z, baseY))
		end
		local evacPart = markers:FindFirstChild("Evac")
		if #towers > 0 and evacPart and evacPart:IsA("BasePart") then
			return { towers = towers, evac = groundAt(evacPart.Position.X, evacPart.Position.Z, baseY) }
		end
		warn("MissionPoints ada, tapi butuh Tower1..N dan Evac; memakai posisi default.")
	end

	local towers: { Vector3 } = {}
	for _, offset in Config.towerOffsets do
		table.insert(towers, groundAt(center.X + offset.X, center.Z + offset.Z, baseY))
	end
	return {
		towers = towers,
		evac = groundAt(center.X + Config.evacOffset.X, center.Z + Config.evacOffset.Z, baseY),
	}
end

-- Objek -----------------------------------------------------------------------

local INACTIVE_COLOR = Color3.fromRGB(255, 70, 70)
local ACTIVE_COLOR = Color3.fromRGB(90, 255, 130)

local function makePart(size: Vector3, color: Color3, material: Enum.Material, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Size = size
	part.Color = color
	part.Material = material
	part.CFrame = cframe
	part.Anchored = true
	part.Parent = objects
	return part
end

-- Menara: tiang + lampu. Prompt "tahan E" di tiang; menahan dibatalkan otomatis kalau pemain menjauh.
local function createTower(index: number, position: Vector3, onActivated: () -> ()): ()
	local pillar =
		makePart(Vector3.new(3, 28, 3), Color3.fromRGB(70, 75, 85), Enum.Material.Metal, CFrame.new(position + Vector3.new(0, 14, 0)))
	pillar.Name = `Tower{index}`
	pillar:SetAttribute("ObjectiveName", `Menara Radio {index}`)
	pillar:SetAttribute("ObjectiveDone", false)

	local lamp = makePart(
		Vector3.new(5, 5, 5),
		INACTIVE_COLOR,
		Enum.Material.Neon,
		CFrame.new(position + Vector3.new(0, 30.5, 0))
	)
	lamp.Name = "Lamp"
	lamp.Shape = Enum.PartType.Ball
	lamp.CanCollide = false
	lamp.CanQuery = false

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = `Menara Radio {index}`
	prompt.ActionText = "Nyalakan"
	prompt.HoldDuration = Config.activationSeconds
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = pillar

	prompt.Triggered:Connect(function()
		if not prompt.Enabled then
			return
		end
		prompt.Enabled = false
		lamp.Color = ACTIVE_COLOR
		pillar:SetAttribute("ObjectiveDone", true)

		local beam = makePart(
			Vector3.new(1.5, 120, 1.5),
			ACTIVE_COLOR,
			Enum.Material.Neon,
			CFrame.new(position + Vector3.new(0, 90, 0))
		)
		beam.Name = "Beam"
		beam.Transparency = 0.5
		beam.CanCollide = false
		beam.CanQuery = false

		onActivated()
	end)
end

local function createEvac(position: Vector3): Part
	local radius = Config.evacRadius
	local ring = makePart(
		Vector3.new(0.4, radius * 2, radius * 2),
		ACTIVE_COLOR,
		Enum.Material.Neon,
		CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	)
	ring.Name = "EvacZone"
	ring.Transparency = 0.6
	ring.CanCollide = false
	ring.CanQuery = false
	ring:SetAttribute("ObjectiveName", "Titik Evakuasi")
	ring:SetAttribute("ObjectiveDone", false)

	local beam =
		makePart(Vector3.new(2, 150, 2), ACTIVE_COLOR, Enum.Material.Neon, CFrame.new(position + Vector3.new(0, 75, 0)))
	beam.Name = "EvacBeam"
	beam.Transparency = 0.5
	beam.CanCollide = false
	beam.CanQuery = false
	return ring
end

-- Alur ronde ------------------------------------------------------------------

local function setPhase(phase: string)
	state:SetAttribute("Phase", phase)
end

local function runRound()
	setPhase("waiting")
	state:SetAttribute("TowersActive", 0)
	state:SetAttribute("EvacProgress", 0)
	while #aliveRoots() == 0 do
		task.wait(1)
	end
	task.wait(Config.startDelay)

	-- Menara
	local points = resolvePoints()
	local total = #points.towers
	local active = 0
	state:SetAttribute("TowersTotal", total)
	for index, position in points.towers do
		createTower(index, position, function()
			active += 1
			state:SetAttribute("TowersActive", active)
		end)
	end
	setPhase("towers")
	while active < total do
		task.wait(TICK)
	end

	-- Evakuasi: semua pemain hidup harus berada di lingkaran selama evacHoldSeconds berturut-turut.
	-- Kalau ada yang keluar, progres turun pelan (separuh kecepatan naik) supaya tidak langsung hangus.
	local ring = createEvac(points.evac)
	setPhase("evac")
	local progress = 0
	while progress < 1 do
		task.wait(TICK)
		local roots = aliveRoots()
		local inside = 0
		for _, root in roots do
			local offset = root.Position - points.evac
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= Config.evacRadius then
				inside += 1
			end
		end
		if #roots > 0 and inside == #roots then
			progress = math.min(1, progress + TICK / Config.evacHoldSeconds)
		else
			progress = math.max(0, progress - TICK / (Config.evacHoldSeconds * 2))
		end
		state:SetAttribute("EvacProgress", progress)
	end
	ring:SetAttribute("ObjectiveDone", true)

	setPhase("success")
	task.wait(Config.resetDelay)
	objects:ClearAllChildren()
end

task.spawn(function()
	while true do
		runRound()
	end
end)
