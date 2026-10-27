--!strict
-- Menjatuhkan kelompok musuh secara berkala di sekitar para pemain, di luar jarak pandang dekat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyConfig = require(ReplicatedStorage.Shared.EnemyConfig)
local EnemyService = require(script.Parent.EnemyService)

local D = EnemyConfig.Director
if not D.enabled then
	return -- gelombang dimatikan di EnemyConfig.Director.enabled
end
local rng = Random.new()

local totalWeight = 0
for _, weight in D.weights do
	totalWeight += weight
end

local function pickType(): string
	local roll = rng:NextNumber(0, totalWeight)
	for id, weight in D.weights do
		roll -= weight
		if roll <= 0 then
			return id
		end
	end
	return next(D.weights) :: string
end

-- Titik tengah pemain yang masih hidup, plus karakter mereka (untuk dikecualikan dari raycast).
local function playerCenter(): (Vector3?, { Instance })
	local sum = Vector3.zero
	local count = 0
	local characters: { Instance } = { EnemyService.folder }
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			sum += root.Position
			count += 1
			table.insert(characters, character)
		end
	end
	if count == 0 then
		return nil, characters
	end
	return sum / count, characters
end

local function spawnGroup()
	local center, exclude = playerCenter()
	if not center then
		return
	end
	local room = D.maxAlive - EnemyService.aliveCount()
	if room <= 0 then
		return
	end

	local size = math.min(rng:NextInteger(D.groupMin, D.groupMax), room)
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = rng:NextNumber(D.spawnDistanceMin, D.spawnDistanceMax)
	local groupCenter = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude

	for _ = 1, size do
		local x = groupCenter.X + rng:NextNumber(-D.groupSpread, D.groupSpread)
		local z = groupCenter.Z + rng:NextNumber(-D.groupSpread, D.groupSpread)
		local hit = workspace:Raycast(Vector3.new(x, center.Y + 300, z), Vector3.new(0, -600, 0), params)
		if hit then -- tidak ada tanah di titik itu (tepi map): lewati
			EnemyService.spawn(pickType(), hit.Position)
		end
	end
end

task.wait(D.firstDelay)
while true do
	spawnGroup()
	task.wait(D.interval)
end
