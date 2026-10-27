--!strict
-- Tembakan hitscan. Client hanya mengirim arah; server yang mengurangi amunisi,
-- membatasi laju tembak, menembakkan ray, dan memberi damage (friendly fire aktif).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StratagemConfig = require(ReplicatedStorage.Shared.StratagemConfig)
local Weapon = require(ReplicatedStorage.Shared.WeaponConfig)

local remotes = Instance.new("Folder")
remotes.Name = "WeaponRemotes"

local fireRemote = Instance.new("RemoteEvent")
fireRemote.Name = "Fire" -- client -> server: (origin: Vector3, direction: Vector3)
fireRemote.Parent = remotes

local tracerRemote = Instance.new("RemoteEvent")
tracerRemote.Name = "Tracer" -- server -> semua client: (origin: Vector3, endpoint: Vector3)
tracerRemote.Parent = remotes

remotes.Parent = ReplicatedStorage

local MAX_ORIGIN_OFFSET = 8 -- origin tembakan harus dekat karakter
local lastShot: { [Player]: number } = {}

local function giveAmmo(player: Player)
	player:SetAttribute("Ammo", StratagemConfig.MAX_AMMO)
end
Players.PlayerAdded:Connect(giveAmmo)
for _, player in Players:GetPlayers() do
	giveAmmo(player)
end
Players.PlayerRemoving:Connect(function(player)
	lastShot[player] = nil
end)

local function isFinite(v: Vector3): boolean
	return v == v and math.abs(v.X) ~= math.huge and math.abs(v.Y) ~= math.huge and math.abs(v.Z) ~= math.huge
end

fireRemote.OnServerEvent:Connect(function(player: Player, origin: unknown, direction: unknown)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end
	if not isFinite(origin) or not isFinite(direction) or direction.Magnitude < 1e-3 then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")) then
		return
	end
	if (origin - root.Position).Magnitude > MAX_ORIGIN_OFFSET then
		return
	end

	local now = os.clock()
	if now - (lastShot[player] or 0) < Weapon.fireInterval * 0.8 then -- toleransi jitter jaringan
		return
	end
	local ammo = player:GetAttribute("Ammo")
	if typeof(ammo) ~= "number" or ammo < Weapon.ammoPerShot then
		return
	end
	lastShot[player] = now
	player:SetAttribute("Ammo", ammo - Weapon.ammoPerShot)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local ray = direction.Unit * Weapon.range
	local result = workspace:Raycast(origin, ray, params)
	local endpoint = result and result.Position or origin + ray

	if result then
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		local target = model and model:FindFirstChildOfClass("Humanoid")
		if target and target.Health > 0 then
			target:TakeDamage(Weapon.damage)
		end
	end

	tracerRemote:FireAllClients(origin, endpoint)
end)
