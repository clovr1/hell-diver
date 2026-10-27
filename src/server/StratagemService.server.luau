--!strict
-- Server memvalidasi lemparan penanda lalu memanggil handler bantuan.
-- Client hanya mengirim id dan posisi; kooldaun, jarak, dan status hidup dicek di sini.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.StratagemConfig)
local Handlers = require(script.Parent.StratagemHandlers)

local remotes = Instance.new("Folder")
remotes.Name = "StratagemRemotes"

local throwRemote = Instance.new("RemoteEvent")
throwRemote.Name = "Throw" -- client -> server: (id: string, position: Vector3)
throwRemote.Parent = remotes

local resultRemote = Instance.new("RemoteEvent")
resultRemote.Name = "Result" -- server -> client: (id: string, ok: boolean, readyAt: number)
resultRemote.Parent = remotes

remotes.Parent = ReplicatedStorage

-- Penanda di tanah selama bantuan dalam perjalanan. Lingkaran menunjukkan area efek,
-- supaya pemain (termasuk tim) tahu harus menyingkir.
local function spawnBeacon(def: Config.Stratagem, position: Vector3): Part
	local beacon = Instance.new("Part")
	beacon.Name = `{def.id}_beacon`
	beacon.Shape = Enum.PartType.Ball
	beacon.Size = Vector3.one * 1.5
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.Material = Enum.Material.Neon
	beacon.Color = def.color
	beacon.Position = position + Vector3.new(0, 0.75, 0)

	if def.radius and def.targeting == "area" then
		local ring = Instance.new("Part")
		ring.Name = "AreaRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.2, def.radius * 2, def.radius * 2)
		ring.CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.Material = Enum.Material.Neon
		ring.Color = def.color
		ring.Transparency = 0.7
		ring.Parent = beacon
	end

	beacon.Parent = workspace
	return beacon
end

-- Waktu server (workspace:GetServerTimeNow) kapan sinyal tersebut siap lagi.
local readyAt: { [Player]: { [string]: number } } = {}

Players.PlayerAdded:Connect(function(player)
	readyAt[player] = {}
end)
Players.PlayerRemoving:Connect(function(player)
	readyAt[player] = nil
end)
for _, player in Players:GetPlayers() do
	readyAt[player] = readyAt[player] or {}
end

local function getAliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Titik jatuh untuk sinyal "self": sedikit di depan karakter, di permukaan tanah.
-- Dihitung server, jadi posisi dari client diabaikan untuk sinyal ini.
local SELF_DROP_OFFSET = 6

local function groundInFront(root: BasePart): Vector3
	local look = root.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	local spot = root.Position
	if forward.Magnitude > 0.01 then
		spot += forward.Unit * SELF_DROP_OFFSET
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root.Parent :: Instance }
	local hit = workspace:Raycast(spot + Vector3.new(0, 5, 0), Vector3.new(0, -30, 0), params)
	return if hit then hit.Position else spot - Vector3.new(0, 3, 0)
end

throwRemote.OnServerEvent:Connect(function(player: Player, id: unknown, position: unknown)
	if typeof(id) ~= "string" or typeof(position) ~= "Vector3" then
		return
	end
	local def = Config.ById[id]
	local cooldowns = readyAt[player]
	if not def or not cooldowns or player:GetAttribute("InMission") ~= true then
		return -- bantuan hanya aktif saat misi, bukan di lobby
	end
	-- NaN/inf lolos typeof; tolak.
	if position ~= position or position.Magnitude == math.huge then
		return
	end

	local now = workspace:GetServerTimeNow()
	local root = getAliveRoot(player)
	local ready = cooldowns[id] or 0
	local target: Vector3 = position
	if root and def.targeting == "self" then
		target = groundInFront(root)
	end
	local ok = root ~= nil
		and now >= ready - 0.25 -- toleransi latensi
		and (target - root.Position).Magnitude <= Config.MAX_THROW_DISTANCE + 5

	if not ok then
		resultRemote:FireClient(player, id, false, ready)
		return
	end

	cooldowns[id] = now + def.cooldown
	resultRemote:FireClient(player, id, true, cooldowns[id])

	local beacon = if def.beacon ~= false then spawnBeacon(def, target) else nil
	task.delay(def.callDelay, function()
		-- Pemain boleh keluar atau mati setelah melempar; bantuan tetap jatuh.
		-- pcall: handler yang error tidak boleh meninggalkan penanda menggantung.
		local success, err = pcall(Handlers[id], player, target)
		if not success then
			warn(`Handler {id} gagal: {err}`)
		end
		if beacon then
			beacon:Destroy()
		end
	end)
end)
