--!strict
-- Efek tiap sinyal bantuan. Dipanggil server setelah callDelay; boleh yield.
-- "reinforce" masih placeholder (tiang cahaya), diganti di langkah 5.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.StratagemConfig)

export type Handler = (player: Player, position: Vector3) -> ()

-- Serangan orbital ----------------------------------------------------------

local STRIKE_BLASTS = 12
local STRIKE_INTERVAL = 0.22 -- jeda antar peluru dijatuhkan
local SHELL_FALL_TIME = 0.5
local SHELL_HEIGHT = 120
local BLAST_RADIUS = 8
local BLAST_DAMAGE_MAX = 70 -- tepat di pusat ledakan
local BLAST_DAMAGE_MIN = 15 -- di tepi radius
local GOLDEN_ANGLE = math.pi * (3 - math.sqrt(5))

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

-- Peluru terlihat jatuh dari langit, lalu meledak saat mendarat.
local function dropShell(position: Vector3, color: Color3)
	local shell = Instance.new("Part")
	shell.Name = "OrbitalShell"
	shell.Size = Vector3.new(0.7, 7, 0.7)
	shell.Anchored = true
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.Material = Enum.Material.Neon
	shell.Color = color
	shell.Position = position + Vector3.new(0, SHELL_HEIGHT, 0)
	shell.Parent = workspace

	local fall = TweenService:Create(
		shell,
		TweenInfo.new(SHELL_FALL_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = position + Vector3.new(0, 3.5, 0) }
	)
	fall:Play()
	fall.Completed:Wait()
	shell:Destroy()
	blast(position)
end

local function orbitalStrike(_player: Player, position: Vector3)
	local def = Config.ById.airstrike
	local spread = (def.radius :: number) - BLAST_RADIUS -- ledakan tetap di dalam lingkaran
	local rng = Random.new()

	-- Titik tersebar merata (spiral sudut emas), lalu urutannya diacak.
	local spiralOffset = rng:NextNumber(0, math.pi * 2)
	local points: { Vector3 } = {}
	for i = 1, STRIKE_BLASTS do
		local radius = math.sqrt((i - 0.5) / STRIKE_BLASTS) * spread
		local angle = spiralOffset + i * GOLDEN_ANGLE
		table.insert(points, position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
	end
	for i = #points, 2, -1 do
		local j = rng:NextInteger(1, i)
		points[i], points[j] = points[j], points[i]
	end

	for i, point in points do
		task.delay((i - 1) * STRIKE_INTERVAL, dropShell, point, def.color)
	end
	-- Tahan handler sampai peluru terakhir meledak, supaya penanda tidak hilang lebih awal.
	task.wait((STRIKE_BLASTS - 1) * STRIKE_INTERVAL + SHELL_FALL_TIME + 0.2)
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
