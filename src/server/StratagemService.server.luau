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

throwRemote.OnServerEvent:Connect(function(player: Player, id: unknown, position: unknown)
	if typeof(id) ~= "string" or typeof(position) ~= "Vector3" then
		return
	end
	local def = Config.ById[id]
	local cooldowns = readyAt[player]
	if not def or not cooldowns then
		return
	end
	-- NaN/inf lolos typeof; tolak.
	if position ~= position or position.Magnitude == math.huge then
		return
	end

	local now = workspace:GetServerTimeNow()
	local root = getAliveRoot(player)
	local ready = cooldowns[id] or 0
	local ok = root ~= nil
		and now >= ready - 0.25 -- toleransi latensi
		and (position - root.Position).Magnitude <= Config.MAX_THROW_DISTANCE + 5

	if not ok then
		resultRemote:FireClient(player, id, false, ready)
		return
	end

	cooldowns[id] = now + def.cooldown
	resultRemote:FireClient(player, id, true, cooldowns[id])

	task.delay(def.callDelay, function()
		-- Pemain boleh keluar atau mati setelah melempar; bantuan tetap jatuh.
		Handlers[id](player, position)
	end)
end)
