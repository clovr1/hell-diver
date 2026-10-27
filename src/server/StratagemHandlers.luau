--!strict
-- Efek tiap sinyal bantuan. Dipanggil server setelah callDelay; boleh yield.
-- "reinforce" masih placeholder (tiang cahaya), diganti di langkah 5.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.StratagemConfig)

export type Handler = (player: Player, position: Vector3) -> ()

-- Serangan orbital ----------------------------------------------------------

local STRIKE_BLASTS = 6
local STRIKE_INTERVAL = 0.35
local BLAST_RADIUS = 10
local BLAST_DAMAGE_MAX = 120 -- tepat di pusat ledakan
local BLAST_DAMAGE_MIN = 20 -- di tepi radius

-- Friendly fire disengaja: semua Humanoid kena, termasuk pelempar dan rekan setim.
local function blast(position: Vector3)
	local visual = Instance.new("Explosion")
	visual.Position = position
	visual.BlastRadius = BLAST_RADIUS
	visual.BlastPressure = 0 -- hanya visual; kerusakan dihitung manual
	visual.DestroyJointRadiusPercent = 0
	visual.ExplosionType = Enum.ExplosionType.NoCraters
	visual.Parent = workspace

	local hitModels: { [Model]: boolean } = {}
	for _, part in workspace:GetPartBoundsInRadius(position, BLAST_RADIUS) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not hitModels[model] then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
				hitModels[model] = true
				local distance = (root.Position - position).Magnitude
				if distance <= BLAST_RADIUS then
					local falloff = 1 - distance / BLAST_RADIUS
					humanoid:TakeDamage(BLAST_DAMAGE_MIN + (BLAST_DAMAGE_MAX - BLAST_DAMAGE_MIN) * falloff)
				end
			end
		end
	end
end

local function orbitalStrike(_player: Player, position: Vector3)
	local area = Config.ById.airstrike.radius :: number
	local rng = Random.new()
	for i = 1, STRIKE_BLASTS do
		local offset = Vector3.zero
		if i > 1 then -- ledakan pertama tepat di penanda
			local angle = rng:NextNumber(0, math.pi * 2)
			local distance = math.sqrt(rng:NextNumber()) * (area - BLAST_RADIUS) -- seluruh ledakan tetap di dalam lingkaran
			offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		end
		blast(position + offset)
		task.wait(STRIKE_INTERVAL)
	end
end

-- Paket logistik ------------------------------------------------------------

local CRATE_USES = 4 -- jumlah pemain berbeda yang bisa mengambil
local CRATE_LIFETIME = 60
local CRATE_DROP_HEIGHT = 90

local function ammoCrate(_player: Player, position: Vector3)
	local def = Config.ById.ammo

	local crate = Instance.new("Part")
	crate.Name = "AmmoCrate"
	crate.Size = Vector3.new(3, 2, 3)
	crate.Anchored = true
	crate.Material = Enum.Material.Metal
	crate.Color = def.color
	crate.Position = position + Vector3.new(0, CRATE_DROP_HEIGHT, 0)
	crate.Parent = workspace
	Debris:AddItem(crate, CRATE_LIFETIME)

	local fall = TweenService:Create(
		crate,
		TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = position + Vector3.new(0, crate.Size.Y / 2, 0) }
	)
	fall:Play()
	fall.Completed:Wait()

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = def.name
	prompt.ActionText = "Ambil amunisi"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 10
	prompt.Parent = crate

	local taken: { [Player]: boolean } = {}
	local usesLeft = CRATE_USES
	prompt.Triggered:Connect(function(taker)
		if taken[taker] or usesLeft <= 0 then
			return
		end
		taken[taker] = true
		usesLeft -= 1
		taker:SetAttribute("Ammo", Config.MAX_AMMO)
		if usesLeft <= 0 then
			crate:Destroy()
		end
	end)
end

-- Placeholder ---------------------------------------------------------------

local function placeholder(id: string): Handler
	return function(player, position)
		local def = Config.ById[id]
		local column = Instance.new("Part")
		column.Name = `{id}_placeholder`
		column.Anchored = true
		column.CanCollide = false
		column.CanQuery = false
		column.Material = Enum.Material.Neon
		column.Color = def.color
		column.Transparency = 0.4
		column.Size = Vector3.new(4, 60, 4)
		column.Position = position + Vector3.new(0, 30, 0)
		column.Parent = workspace
		Debris:AddItem(column, 1.5)
		print(`[{id}] tiba di {position} (dipanggil {player.Name})`)
	end
end

local Handlers: { [string]: Handler } = {
	airstrike = orbitalStrike,
	ammo = ammoCrate,
	reinforce = placeholder("reinforce"),
}

return Handlers
