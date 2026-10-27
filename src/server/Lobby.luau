--!strict
-- Membangun lobby: platform melayang, dropship dengan konsol "Luncurkan", dan titik spawn.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.LobbyConfig)

local SHIP_WIDTH = 24
local SHIP_LENGTH = 44 -- sepanjang sumbu Z; belakang (+Z) terbuka sebagai pintu masuk
local SHIP_HEIGHT = 10

export type Lobby = {
	model: Model,
	spawn: SpawnLocation,
	console: ProximityPrompt,
	isAboard: (position: Vector3) -> boolean,
	setEngines: (on: boolean) -> (),
}

local Lobby = {}

function Lobby.build(): Lobby
	local origin = Config.origin
	local topY = origin.Y + Config.platformSize.Y / 2
	local shipCenter = Vector3.new(origin.X, topY, origin.Z)

	local model = Instance.new("Model")
	model.Name = "Lobby"

	local function part(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = position
		p.Color = color
		p.Material = material
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local hullColor = Color3.fromRGB(80, 86, 96)
	local darkColor = Color3.fromRGB(40, 44, 52)
	local accent = Color3.fromRGB(90, 200, 255)

	-- Platform dan pagar tak terlihat supaya tidak jatuh.
	part("Platform", Config.platformSize, origin, darkColor, Enum.Material.Metal)
	local half = Config.platformSize.X / 2
	for _, side in { { 0, -half, Config.platformSize.X, 1 }, { 0, half, Config.platformSize.X, 1 } } do
		local wall = part("EdgeWall", Vector3.new(side[3], 40, side[4]), Vector3.new(origin.X + side[1], topY + 20, origin.Z + side[2]), darkColor, Enum.Material.Metal)
		wall.Transparency = 1
		wall.CanQuery = false
	end
	for _, side in { { -half, 0 }, { half, 0 } } do
		local wall = part("EdgeWall", Vector3.new(1, 40, Config.platformSize.Z), Vector3.new(origin.X + side[1], topY + 20, origin.Z + side[2]), darkColor, Enum.Material.Metal)
		wall.Transparency = 1
		wall.CanQuery = false
	end
	for _, z in { -half + 0.5, half - 0.5 } do
		local strip = part("EdgeLight", Vector3.new(Config.platformSize.X, 0.2, 0.6), Vector3.new(origin.X, topY + 0.1, origin.Z + z), accent, Enum.Material.Neon)
		strip.CanCollide = false
	end

	-- Dropship: lantai, dinding kiri/kanan/depan, atap, hidung, dan mesin.
	part("ShipFloor", Vector3.new(SHIP_WIDTH, 0.4, SHIP_LENGTH), shipCenter + Vector3.new(0, 0.2, 0), Color3.fromRGB(60, 65, 74), Enum.Material.DiamondPlate)
	for _, x in { -SHIP_WIDTH / 2, SHIP_WIDTH / 2 } do
		part("ShipWall", Vector3.new(1, SHIP_HEIGHT, SHIP_LENGTH), shipCenter + Vector3.new(x, SHIP_HEIGHT / 2, 0), hullColor, Enum.Material.Metal)
	end
	part("ShipFrontWall", Vector3.new(SHIP_WIDTH, SHIP_HEIGHT, 1), shipCenter + Vector3.new(0, SHIP_HEIGHT / 2, -SHIP_LENGTH / 2), hullColor, Enum.Material.Metal)
	local roof = part("ShipRoof", Vector3.new(SHIP_WIDTH + 2, 1, SHIP_LENGTH + 2), shipCenter + Vector3.new(0, SHIP_HEIGHT + 0.5, 0), darkColor, Enum.Material.Metal)
	part("ShipNose", Vector3.new(16, 7, 12), shipCenter + Vector3.new(0, 3.5, -SHIP_LENGTH / 2 - 6), hullColor, Enum.Material.Metal)
	local window = part("Cockpit", Vector3.new(12, 2.5, 0.4), shipCenter + Vector3.new(0, 4.5, -SHIP_LENGTH / 2 - 12.1), accent, Enum.Material.Neon)
	window.CanCollide = false

	local light = Instance.new("PointLight")
	light.Range = 30
	light.Brightness = 1.5
	light.Color = Color3.fromRGB(200, 225, 255)
	light.Parent = roof

	local fires: { Fire } = {}
	for _, x in { -SHIP_WIDTH / 2 - 3, SHIP_WIDTH / 2 + 3 } do
		local engine = part("Engine", Vector3.new(4, 4, 12), shipCenter + Vector3.new(x, 6, 8), darkColor, Enum.Material.Metal)
		local fire = Instance.new("Fire")
		fire.Size = 14
		fire.Heat = 8
		fire.Enabled = false
		fire.Parent = engine
		table.insert(fires, fire)
	end

	-- Konsol peluncuran di dekat hidung.
	local console = part("Console", Vector3.new(6, 3.5, 2.5), shipCenter + Vector3.new(0, 1.75, -SHIP_LENGTH / 2 + 3), darkColor, Enum.Material.Metal)
	local screen = part("ConsoleScreen", Vector3.new(5, 1.4, 0.2), shipCenter + Vector3.new(0, 3, -SHIP_LENGTH / 2 + 4.4), accent, Enum.Material.Neon)
	screen.CanCollide = false

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Konsol Dropship"
	prompt.ActionText = "Luncurkan"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = console

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(220, 40)
	sign.StudsOffset = Vector3.new(0, 7, 0)
	sign.Adornee = roof
	sign.AlwaysOnTop = false
	sign.MaxDistance = 250
	sign.Parent = roof
	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.fromScale(1, 1)
	signText.BackgroundTransparency = 1
	signText.Font = Enum.Font.GothamBold
	signText.TextSize = 22
	signText.TextColor3 = accent
	signText.TextStrokeTransparency = 0.4
	signText.Text = "DROPSHIP"
	signText.Parent = sign

	-- Spawn lobby, jauh di belakang dropship.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(origin.X, topY + 0.5, origin.Z + SHIP_LENGTH / 2 + 28)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = accent
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.5
	spawn.Parent = model

	model.Parent = workspace

	return {
		model = model,
		spawn = spawn,
		console = prompt,
		isAboard = function(position: Vector3): boolean
			local rel = position - shipCenter
			return math.abs(rel.X) <= SHIP_WIDTH / 2
				and math.abs(rel.Z) <= SHIP_LENGTH / 2
				and rel.Y >= -2
				and rel.Y <= SHIP_HEIGHT + 4
		end,
		setEngines = function(on: boolean)
			for _, fire in fires do
				fire.Enabled = on
			end
		end,
	}
end

return Lobby
