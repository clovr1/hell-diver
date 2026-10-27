--!strict
-- Alur permainan: lobby -> hitung mundur -> dropship berangkat -> terjun ke planet -> misi -> kembali ke lobby.
-- Pemain yang sedang dalam misi punya attribute InMission = true; yang lain berada di lobby.
-- Efek layar (getar, layar putih, FOV) dikirim ke client lewat FlowRemotes.Cinematic.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LobbyConfig = require(ReplicatedStorage.Shared.LobbyConfig)
local StratagemConfig = require(ReplicatedStorage.Shared.StratagemConfig)
local Lobby = require(script.Parent.Lobby)
local MissionService = require(script.Parent.MissionService)

local lobby = Lobby.build()
local rng = Random.new()

local remotes = Instance.new("Folder")
remotes.Name = "FlowRemotes"
local cinematic = Instance.new("RemoteEvent")
cinematic.Name = "Cinematic" -- server -> client: (cue: string)
cinematic.Parent = remotes
remotes.Parent = ReplicatedStorage

local phase = "lobby"
local requested = false
local missionSpawn: SpawnLocation? = nil

local function setPhase(newPhase: string)
	phase = newPhase
	MissionService.setPhase(newPhase)
	lobby.console.Enabled = newPhase == "lobby"
end

local function cue(players: { Player }, name: string)
	for _, player in players do
		cinematic:FireClient(player, name)
	end
end

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function missionParticipants(): { Player }
	local list: { Player } = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("InMission") == true then
			table.insert(list, player)
		end
	end
	return list
end

-- Pemain di lobby ---------------------------------------------------------------

local function sendToLobby(player: Player)
	player.RespawnLocation = lobby.spawn
	local root = aliveRoot(player)
	local character = player.Character
	if root and character then
		root.Anchored = false
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
		local offset = Vector3.new(rng:NextNumber(-8, 8), 4, rng:NextNumber(-8, 8))
		character:PivotTo(CFrame.new(lobby.spawn.Position + offset))
	elseif character then
		player:LoadCharacter() -- sudah mati: muncul lagi di lobby (RespawnLocation)
	end
end

local function setupPlayer(player: Player)
	player:SetAttribute("InMission", false)
	player.RespawnLocation = lobby.spawn
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do
	setupPlayer(player)
	if player.Character then
		sendToLobby(player)
	end
end

lobby.console.Triggered:Connect(function(player)
	if phase ~= "lobby" then
		return
	end
	local root = aliveRoot(player)
	if root and lobby.isAboard(root.Position) then
		requested = true
	end
end)

local function aboardPlayers(): { Player }
	local list: { Player } = {}
	for _, player in Players:GetPlayers() do
		local root = aliveRoot(player)
		if player:GetAttribute("InMission") ~= true and root and lobby.isAboard(root.Position) then
			table.insert(list, player)
		end
	end
	return list
end

-- Penerjunan ------------------------------------------------------------------

-- Titik pusat map: SpawnLocation pertama yang bukan milik lobby atau misi.
local function mapCenter(): Vector3
	for _, descendant in workspace:GetDescendants() do
		if
			descendant:IsA("SpawnLocation")
			and not lobby.model:IsAncestorOf(descendant)
			and descendant.Name ~= "MissionSpawn"
		then
			return descendant.Position
		end
	end
	return Vector3.zero
end

-- Pemain dibungkus kapsul (bola) yang jatuh dari ketinggian dengan percepatan, lalu mendarat.
-- Berjalan sampai pemain mendarat (yield).
local function dropPlayer(player: Player, target: Vector3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and root and root:IsA("BasePart")) then
		return
	end

	local start = target + Vector3.new(0, LobbyConfig.dropAltitude, 0)
	local pod = Instance.new("Part")
	pod.Name = "DropPod"
	pod.Shape = Enum.PartType.Ball
	pod.Size = Vector3.one * 10
	pod.Anchored = true
	pod.CanCollide = false
	pod.CanQuery = false
	pod.CanTouch = false
	pod.Material = Enum.Material.Glass
	pod.Color = Color3.fromRGB(255, 170, 90)
	pod.Transparency = 0.5
	pod.CFrame = CFrame.new(start)
	local fire = Instance.new("Fire")
	fire.Size = 18
	fire.Heat = 10
	fire.Parent = pod
	pod.Parent = workspace

	root.Anchored = true
	root.CFrame = CFrame.new(start)

	local startTime = os.clock()
	while true do
		local alpha = (os.clock() - startTime) / LobbyConfig.dropSeconds
		if alpha >= 1 or not root.Parent then
			break
		end
		local y = start.Y + (target.Y + 3 - start.Y) * alpha * alpha -- makin cepat
		local frame = CFrame.new(start.X, y, start.Z)
		pod.CFrame = frame
		root.CFrame = frame
		RunService.Heartbeat:Wait()
	end
	pod:Destroy()

	if root.Parent then
		root.CFrame = CFrame.new(target + Vector3.new(0, 3, 0))
		root.Anchored = false
	end
	-- Hanya visual: tanpa tekanan dan tanpa memutus sendi, jadi tidak melukai siapa pun.
	local impact = Instance.new("Explosion")
	impact.Position = target
	impact.BlastRadius = 12
	impact.BlastPressure = 0
	impact.DestroyJointRadiusPercent = 0
	impact.ExplosionType = Enum.ExplosionType.NoCraters
	impact.Parent = workspace
end

local function dropAll(players: { Player }, landing: Vector3)
	local pending = #players
	for index, player in players do
		local angle = (index - 1) / #players * math.pi * 2
		local spread = if #players > 1 then LobbyConfig.dropSpread else 0
		local x = landing.X + math.cos(angle) * spread
		local z = landing.Z + math.sin(angle) * spread
		local target = MissionService.groundAt(x, z, landing.Y)
		task.spawn(function()
			local ok, err = pcall(dropPlayer, player, target)
			if not ok then
				warn(`dropPlayer gagal untuk {player.Name}: {err}`)
			end
			pending -= 1 -- selalu turun, supaya alur tidak macet kalau ada yang error
		end)
	end
	while pending > 0 do
		task.wait(0.1)
	end
end

local function returnToLobby(players: { Player })
	cue(players, "fade_out")
	task.wait(0.8)
	for _, player in players do
		player:SetAttribute("InMission", false)
		player:SetAttribute("Ammo", StratagemConfig.MAX_AMMO)
		sendToLobby(player)
	end
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		enemies:ClearAllChildren()
	end
	if missionSpawn then
		missionSpawn:Destroy()
		missionSpawn = nil
	end
	cue(players, "fade_in")
end

-- Satu siklus ------------------------------------------------------------------

local function cycle()
	setPhase("lobby")
	requested = false
	while not requested do
		task.wait(0.25)
	end

	setPhase("countdown")
	MissionService.state:SetAttribute("CountdownEnd", workspace:GetServerTimeNow() + LobbyConfig.countdownSeconds)
	task.wait(LobbyConfig.countdownSeconds)

	local aboard = aboardPlayers()
	if #aboard == 0 then
		return -- tidak ada yang naik; kembali ke lobby
	end

	setPhase("drop")
	for _, player in aboard do
		player:SetAttribute("InMission", true)
	end
	lobby.setEngines(true)
	cue(aboard, "launch")
	task.wait(LobbyConfig.launchSeconds)
	cue(aboard, "fade_out")
	task.wait(0.8)
	lobby.setEngines(false)

	-- Titik pendaratan + spawn misi (supaya yang mati muncul lagi di planet, bukan di lobby).
	local center = mapCenter()
	local landing = MissionService.groundAt(center.X, center.Z, center.Y)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MissionSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = landing + Vector3.new(0, 0.5, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = workspace
	missionSpawn = spawn
	for _, player in aboard do
		player.RespawnLocation = spawn
	end

	cue(aboard, "drop")
	dropAll(aboard, landing) -- memindahkan pemain ke ketinggian saat dipanggil, lalu menunggu mendarat
	cue(aboard, "land")
	task.wait(1.5)

	MissionService.run(landing)
	returnToLobby(missionParticipants())
end

while true do
	local ok, err = pcall(cycle)
	if not ok then
		warn(`GameFlow error: {err}`)
		lobby.setEngines(false)
		returnToLobby(missionParticipants())
		task.wait(2)
	end
end
