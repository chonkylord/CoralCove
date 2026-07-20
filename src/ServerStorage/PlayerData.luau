--!strict
-- Server-authoritative player economy: points balance, unlocked swim styles,
-- equipped style, and best/last race times — plus DataStore persistence.
--
-- Nothing here trusts the client: purchases and equips are validated against the
-- server's cached balance, and all mutation happens here. State is mirrored onto
-- the Player via leaderstats (Points, Best Time) and attributes (Points,
-- BestTimeSeconds, LastRaceSeconds, EquippedStyle, Unlocked_<Style>) so clients
-- can read it — attributes set on the server replicate to every client.
--
-- Persistence degrades gracefully: in an unpublished place, or when Studio API
-- access is off, the DataStore calls fail and we simply run session-only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local SwimConfig = require(ReplicatedStorage:WaitForChild("SwimConfig"))
local RaceEconomy = require(ReplicatedStorage:WaitForChild("RaceEconomy"))

local STORE_NAME = "SwimEconomy_v1"

-- GetDataStore itself rarely throws, but grab it defensively; the risky calls
-- (GetAsync/SetAsync) are pcall'd at each use.
local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Economy] DataStore unavailable — running session-only: " .. tostring(result))
	end
end

type Data = {
	points: number,
	unlocked: { [string]: boolean },
	best: number?,
	last: number?,
	equipped: string,
}

local cache: { [Player]: Data } = {}

local PlayerData = {}

local function formatTime(seconds: number): string
	local minutes = math.floor(seconds / 60)
	local secs = seconds - minutes * 60
	return string.format("%d:%05.2f", minutes, secs)
end

local function defaultData(): Data
	local unlocked: { [string]: boolean } = {}
	for key, style in SwimConfig.styles do
		if style.default then
			unlocked[key] = true
		end
	end
	return { points = 0, unlocked = unlocked, best = nil, last = nil, equipped = "Freestyle" }
end

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function load(player: Player): Data
	local data = defaultData()
	if store then
		local ok, saved = pcall(function()
			return (store :: DataStore):GetAsync(keyFor(player))
		end)
		if ok and type(saved) == "table" then
			data.points = tonumber(saved.points) or 0
			if type(saved.unlocked) == "table" then
				for k, v in saved.unlocked do
					if v and SwimConfig.styles[k] then
						data.unlocked[k] = true
					end
				end
			end
			data.best = tonumber(saved.best)
			data.last = tonumber(saved.last)
			if type(saved.equipped) == "string" and SwimConfig.styles[saved.equipped] then
				data.equipped = saved.equipped
			end
		elseif not ok then
			warn("[Economy] load failed for " .. player.Name .. ": " .. tostring(saved))
		end
	end
	-- Defaults are always unlocked, and you can only have an unlocked style equipped.
	for key, style in SwimConfig.styles do
		if style.default then
			data.unlocked[key] = true
		end
	end
	if not data.unlocked[data.equipped] then
		data.equipped = "Freestyle"
	end
	return data
end

local function getData(player: Player): Data
	local existing = cache[player]
	if existing then
		return existing
	end
	local data = load(player)
	cache[player] = data
	return data
end

local function getOrMake(parent: Instance, name: string, className: string): Instance
	local found = parent:FindFirstChild(name)
	if found then
		return found
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = parent
	return made
end

local function pushPoints(player: Player, data: Data)
	player:SetAttribute("Points", data.points)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local stat = ls:FindFirstChild("Points")
		if stat and stat:IsA("IntValue") then
			stat.Value = data.points
		end
	end
end

local function pushBest(player: Player, data: Data)
	if data.best then
		player:SetAttribute("BestTimeSeconds", data.best)
	end
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local stat = ls:FindFirstChild("Best Time")
		if stat and stat:IsA("StringValue") then
			stat.Value = if data.best then formatTime(data.best) else "—"
		end
	end
end

-- Create leaderstats + attributes for a joining player from their loaded data.
function PlayerData.setup(player: Player)
	local data = getData(player)

	local ls = getOrMake(player, "leaderstats", "Folder")
	local points = getOrMake(ls, "Points", "IntValue") :: IntValue
	points.Value = data.points
	local best = getOrMake(ls, "Best Time", "StringValue") :: StringValue
	best.Value = if data.best then formatTime(data.best) else "—"

	player:SetAttribute("Points", data.points)
	if data.best then
		player:SetAttribute("BestTimeSeconds", data.best)
	end
	if data.last then
		player:SetAttribute("LastRaceSeconds", data.last)
	end
	player:SetAttribute("EquippedStyle", data.equipped)
	for key in SwimConfig.styles do
		player:SetAttribute("Unlocked_" .. key, data.unlocked[key] == true)
	end
end

-- Record a completed race: award points (vs the player's PREVIOUS race), update
-- last/best times. Returns a summary the caller can relay to the client.
function PlayerData.recordFinish(
	player: Player,
	finishTime: number
): { awarded: number, newTotal: number, faster: number, isBest: boolean }
	local data = getData(player)
	local prev = data.last
	local awarded = RaceEconomy.pointsForRace(prev, finishTime)

	data.last = finishTime
	player:SetAttribute("LastRaceSeconds", finishTime)

	local isBest = false
	if data.best == nil or finishTime < data.best then
		data.best = finishTime
		isBest = true
	end
	pushBest(player, data)

	data.points += awarded
	pushPoints(player, data)

	local faster = if prev then prev - finishTime else 0
	return { awarded = awarded, newTotal = data.points, faster = faster, isBest = isBest }
end

-- Spend points to unlock a style. Server-validated. Returns (ok, reason).
function PlayerData.tryPurchase(player: Player, styleKey: string): (boolean, string)
	local style = SwimConfig.styles[styleKey]
	if not style then
		return false, "Unknown style"
	end
	local data = getData(player)
	if data.unlocked[styleKey] then
		return false, "Already owned"
	end
	if data.points < style.cost then
		return false, "Not enough points"
	end
	data.points -= style.cost
	data.unlocked[styleKey] = true
	pushPoints(player, data)
	player:SetAttribute("Unlocked_" .. styleKey, true)
	return true, "Purchased"
end

-- Equip an already-unlocked style. Server-validated. Returns (ok, reason).
function PlayerData.tryEquip(player: Player, styleKey: string): (boolean, string)
	local style = SwimConfig.styles[styleKey]
	if not style then
		return false, "Unknown style"
	end
	local data = getData(player)
	if not data.unlocked[styleKey] then
		return false, "Locked"
	end
	data.equipped = styleKey
	player:SetAttribute("EquippedStyle", styleKey)
	return true, "Equipped"
end

function PlayerData.save(player: Player)
	local data = cache[player]
	if not data or not store then
		return
	end
	local payload = {
		points = data.points,
		unlocked = data.unlocked,
		best = data.best,
		last = data.last,
		equipped = data.equipped,
	}
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync(keyFor(player), payload)
	end)
	if not ok then
		warn("[Economy] save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

function PlayerData.release(player: Player)
	cache[player] = nil
end

Players.PlayerRemoving:Connect(function(player: Player)
	PlayerData.save(player)
	PlayerData.release(player)
end)

return PlayerData
