--!strict
-- Membuat musuh dan menjalankan AI kejar-dan-serang untuk semuanya dalam satu loop.
-- Belum ada pathfinding: musuh berjalan lurus ke pemain terdekat dan melompat kalau tersangkut.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyConfig = require(ReplicatedStorage.Shared.EnemyConfig)

local TICK = 0.25
local CORPSE_LIFETIME = 3

type Enemy = {
	def: EnemyConfig.EnemyDef,
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	lastAttack: number,
	lastPosition: Vector3,
}

type Target = { root: BasePart, humanoid: Humanoid }

local enemies: { [Model]: Enemy } = {}
local aliveCount = 0

local folder = Instance.new("Folder")
folder.Name = "Enemies"
folder.Parent = workspace

local EnemyService = {}
EnemyService.folder = folder

function EnemyService.aliveCount(): number
	return aliveCount
end

local function remove(enemy: Enemy)
	if enemies[enemy.model] then
		enemies[enemy.model] = nil
		aliveCount -= 1
	end
end

local function build(def: EnemyConfig.EnemyDef, position: Vector3): Enemy
	local model = Instance.new("Model")
	model.Name = def.name

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = def.size
	root.Color = def.color
	root.Material = def.material
	root.CFrame = CFrame.new(position + Vector3.new(0, def.size.Y / 2, 0))
	root.Parent = model
	model.PrimaryPart = root

	-- Mata menandai sisi depan.
	local eye = Instance.new("Part")
	eye.Name = "Eye"
	eye.Size = Vector3.new(def.size.X * 0.6, def.size.Y * 0.2, 0.2)
	eye.Color = def.eyeColor
	eye.Material = Enum.Material.Neon
	eye.CanCollide = false
	eye.CanTouch = false
	eye.Massless = true
	eye.CFrame = root.CFrame * CFrame.new(0, def.size.Y * 0.15, -def.size.Z / 2)
	eye.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = eye
	weld.Parent = root

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = def.health
	humanoid.Health = def.health
	humanoid.WalkSpeed = def.speed
	humanoid.HipHeight = 0 -- tidak ada kaki; pusat root berada setengah tinggi di atas tanah
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	model.Parent = folder
	root:SetNetworkOwner(nil) -- fisika musuh dihitung server, bukan pemain terdekat

	local enemy: Enemy = {
		def = def,
		model = model,
		root = root,
		humanoid = humanoid,
		lastAttack = 0,
		lastPosition = root.Position,
	}
	humanoid.Died:Connect(function()
		remove(enemy)
		Debris:AddItem(model, CORPSE_LIFETIME)
	end)
	return enemy
end

-- position: titik di permukaan tanah.
function EnemyService.spawn(id: string, position: Vector3)
	local def = EnemyConfig.Enemies[id]
	if not def then
		warn(`Jenis musuh tidak dikenal: {id}`)
		return
	end
	local enemy = build(def, position)
	enemies[enemy.model] = enemy
	aliveCount += 1
end

local function livingTargets(): { Target }
	local targets: { Target } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			table.insert(targets, { root = root, humanoid = humanoid })
		end
	end
	return targets
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

task.spawn(function()
	while true do
		task.wait(TICK)
		local targets = livingTargets()
		if #targets == 0 then
			continue
		end
		local now = os.clock()

		for model, enemy in enemies do
			if enemy.humanoid.Health <= 0 or not model:IsDescendantOf(workspace) then
				remove(enemy)
				continue
			end

			local position = enemy.root.Position
			local nearest: Target = targets[1]
			local nearestDistance = math.huge
			for _, target in targets do
				local distance = (target.root.Position - position).Magnitude
				if distance < nearestDistance then
					nearest = target
					nearestDistance = distance
				end
			end

			if nearestDistance <= enemy.def.attackRange then
				if now - enemy.lastAttack >= enemy.def.attackCooldown then
					enemy.lastAttack = now
					nearest.humanoid:TakeDamage(enemy.def.damage)
				end
			else
				enemy.humanoid:MoveTo(nearest.root.Position)
				-- Hampir tidak bergerak padahal belum sampai: kemungkinan tersangkut, lompat.
				local moved = (flat(position) - flat(enemy.lastPosition)).Magnitude
				if moved < enemy.def.speed * TICK * 0.2 then
					enemy.humanoid.Jump = true
				end
			end
			enemy.lastPosition = position
		end
	end
end)

return EnemyService
