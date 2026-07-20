--!strict
-- Wires the shop economy to the network: sets up joining players, saves on
-- leave, and validates purchase/equip requests on the server. All the actual
-- rules and state live in PlayerData; this script is just the boundary.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))

local RaceEvents = ReplicatedStorage:WaitForChild("RaceEvents")
local RequestPurchase = RaceEvents:WaitForChild("RequestPurchase") :: RemoteFunction
local EquipStyle = RaceEvents:WaitForChild("EquipStyle") :: RemoteEvent

Players.PlayerAdded:Connect(function(player: Player)
	PlayerData.setup(player)
end)
for _, existing in Players:GetPlayers() do
	task.spawn(PlayerData.setup, existing)
end

-- PlayerRemoving/save is handled inside PlayerData; add a shutdown flush so the
-- last session's points/unlocks aren't lost when the server closes.
game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		PlayerData.save(player)
	end
end)

RequestPurchase.OnServerInvoke = function(player: Player, styleKey: any)
	if type(styleKey) ~= "string" then
		return { ok = false, reason = "Bad request" }
	end
	local ok, reason = PlayerData.tryPurchase(player, styleKey)
	return { ok = ok, reason = reason, points = player:GetAttribute("Points") }
end

EquipStyle.OnServerEvent:Connect(function(player: Player, styleKey: any)
	if type(styleKey) ~= "string" then
		return
	end
	PlayerData.tryEquip(player, styleKey)
end)
