--!strict
-- Efek tiap sinyal bantuan. Sekarang masih placeholder (tiang cahaya) supaya alurnya bisa dites.
-- Langkah 2 mengganti "airstrike" dan "ammo" dengan efek asli, langkah 5 mengganti "reinforce".

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.StratagemConfig)

export type Handler = (player: Player, position: Vector3) -> ()

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

local Handlers: { [string]: Handler } = {}
for _, def in Config.Stratagems do
	Handlers[def.id] = placeholder(def.id)
end

return Handlers
