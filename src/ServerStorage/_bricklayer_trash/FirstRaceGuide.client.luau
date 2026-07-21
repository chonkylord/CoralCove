--!strict
-- A lightweight race coach. It stays visible for every player, so the next
-- action is always clear even after they have set a personal best. It reacts to
-- server-sent race state instead of trusting client movement or touch detection.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local raceEvents = ReplicatedStorage:WaitForChild("RaceEvents")
local raceStateChanged = raceEvents:WaitForChild("RaceStateChanged") :: RemoteEvent
local lapUpdate = raceEvents:WaitForChild("LapUpdate") :: RemoteEvent
local raceFinished = raceEvents:WaitForChild("RaceFinished") :: RemoteEvent

local gui = Instance.new("ScreenGui")
gui.Name = "FirstRaceGuide"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local card = Instance.new("Frame")
card.Name = "CoachCard"
card.Position = UDim2.fromOffset(18, 86)
card.Size = UDim2.fromOffset(330, 142)
card.BackgroundColor3 = Color3.fromRGB(17, 28, 44)
card.BackgroundTransparency = 0.06
card.BorderSizePixel = 0
card.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = card

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(72, 177, 244)
stroke.Transparency = 0.35
stroke.Thickness = 1.5
stroke.Parent = card

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(16, 12)
title.Size = UDim2.new(1, -32, 0, 26)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "🏊 AQUA SPRINT: READY TO RACE"
title.TextColor3 = Color3.fromRGB(113, 204, 255)
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = card

local body = Instance.new("TextLabel")
body.Position = UDim2.fromOffset(16, 43)
body.Size = UDim2.new(1, -32, 0, 86)
body.BackgroundTransparency = 1
body.Font = Enum.Font.GothamMedium
body.Text = "Touch any starting block to join.\nSwim to the far wall, turn back, and finish to earn points."
body.TextColor3 = Color3.fromRGB(238, 244, 252)
body.TextSize = 16
body.TextWrapped = true
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
body.Parent = card

local myLane: number? = nil
local finishedThisRace = false

raceStateChanged.OnClientEvent:Connect(function(payload: { [string]: any })
	local joinedLane = payload.joinedLane
	if type(joinedLane) == "number" and payload.playerName == player.Name then
		myLane = joinedLane
		finishedThisRace = false
		card.Visible = true
		title.Text = string.format("✅ YOU'RE IN LANE %d", joinedLane)
		body.Text =
			"Stay on your block for the countdown.\nAt GO: swim to the far wall, turn, then race back to finish."
	end

	if not card.Visible or finishedThisRace then
		return
	end
	if payload.state == "Countdown" then
		title.Text = "⏱ GET READY"
		body.Text = "The gate drops at GO.\nTouch the far wall first — then return to the finish wall."
	elseif payload.state == "Racing" and myLane then
		title.Text = "🏊 RACE ON"
		body.Text = "First target: the far wall.\nKeep your head above water to refill breath."
	end
end)

lapUpdate.OnClientEvent:Connect(function(lane: number, lengths: number, total: number)
	if card.Visible and myLane == lane and lengths < total then
		title.Text = "↩ TURN COMPLETE"
		body.Text = "Nice! Now swim all the way back to the finish wall.\nA faster time earns more points."
	end
end)

raceFinished.OnClientEvent:Connect(function(lane: number, _name: string, _finishTime: number)
	if myLane ~= lane or finishedThisRace then
		return
	end
	finishedThisRace = true
	card.Visible = true
	title.Text = "🏁 RACE COMPLETE!"
	body.Text =
		"You earned points for finishing.\nUse 🛒 Shop to unlock strokes, then return to the blocks to beat your time."
end)
