--!strict
-- Renders race status, a live timer, the local player's lap progress, and a
-- results list, driven entirely by RaceManager's RemoteEvents.
--
-- The timer runs off the SERVER clock (workspace:GetServerTimeNow) so it always
-- agrees with the authoritative finish time, and it FREEZES at the local
-- player's exact finish time the moment they finish — it does not wait on the
-- global race-finished state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local RaceEvents = ReplicatedStorage:WaitForChild("RaceEvents")
local RaceStateChangedEvent = RaceEvents:WaitForChild("RaceStateChanged") :: RemoteEvent
local LapUpdateEvent = RaceEvents:WaitForChild("LapUpdate") :: RemoteEvent
local RaceFinishedEvent = RaceEvents:WaitForChild("RaceFinished") :: RemoteEvent

local Hud = PlayerGui:WaitForChild("RaceHud")
local StatusLabel = Hud:WaitForChild("StatusLabel") :: TextLabel
local TimerLabel = Hud:WaitForChild("TimerLabel") :: TextLabel
local LapLabel = Hud:WaitForChild("LapLabel") :: TextLabel
local ResultsFrame = Hud:WaitForChild("ResultsFrame") :: Frame

local TOTAL_LENGTHS = 2

local myLane: number? = nil
local resultCount = 0

-- Timer state
local timerConn: RBXScriptConnection? = nil
local serverStartTime: number? = nil
local frozenTime: number? = nil

-- Countdown state (ticks off the server clock so 8..1 and 3..2..1 are live)
local countdownPhase: string? = nil -- "Waiting" | "Countdown" | nil
local countdownEndTime: number? = nil

local function formatTime(seconds: number): string
	local minutes = math.floor(seconds / 60)
	local secs = seconds - minutes * 60
	return string.format("%d:%05.2f", minutes, secs)
end

local function clearResults()
	for _, child in ResultsFrame:GetChildren() do
		if child:IsA("TextLabel") and child.Name ~= "Title" then
			child:Destroy()
		end
	end
	resultCount = 0
end

local function stopTimerLoop()
	if timerConn then
		timerConn:Disconnect()
		timerConn = nil
	end
end

-- Freeze the timer display at a specific time and stop ticking.
local function freezeTimer(atTime: number)
	frozenTime = atTime
	stopTimerLoop()
	TimerLabel.Text = formatTime(atTime)
end

local function clearTimer()
	frozenTime = nil
	serverStartTime = nil
	stopTimerLoop()
	TimerLabel.Text = ""
end

local function startTimer(startTime: number)
	frozenTime = nil
	serverStartTime = startTime
	stopTimerLoop()
	timerConn = RunService.RenderStepped:Connect(function()
		if frozenTime ~= nil or serverStartTime == nil then
			return
		end
		local elapsed = Workspace:GetServerTimeNow() - serverStartTime
		if elapsed < 0 then
			elapsed = 0
		end
		TimerLabel.Text = formatTime(elapsed)
	end)
end

-- Live countdown display, recomputed each frame from the server end-time.
RunService.Heartbeat:Connect(function()
	if countdownPhase == nil or countdownEndTime == nil then
		return
	end
	local remaining = math.max(0, math.ceil(countdownEndTime - Workspace:GetServerTimeNow()))
	if countdownPhase == "Waiting" then
		StatusLabel.Text = string.format("Race starts in %d — touch a starting block to join!", remaining)
	elseif countdownPhase == "Countdown" then
		StatusLabel.Text = if remaining > 0 then string.format("Get ready... %d", remaining) else "GO!"
	end
end)

RaceStateChangedEvent.OnClientEvent:Connect(function(payload: { [string]: any })
	local state = payload.state

	if payload.joinedLane ~= nil and payload.playerName == LocalPlayer.Name then
		myLane = payload.joinedLane
	end

	if state == "Idle" then
		myLane = nil
		countdownPhase = nil
		clearTimer()
		clearResults()
		StatusLabel.Text = "Touch a starting block to join the race!"
		LapLabel.Text = ""
	elseif state == "Waiting" then
		clearResults()
		countdownPhase = "Waiting"
		countdownEndTime = payload.endTime
		LapLabel.Text = ""
	elseif state == "Countdown" then
		countdownPhase = "Countdown"
		countdownEndTime = payload.endTime
	elseif state == "Racing" then
		countdownPhase = nil
		StatusLabel.Text = if myLane then "GO! Swim!" else "Race in progress"
		if myLane then
			LapLabel.Text = string.format("Lane %d — length 0/%d", myLane, TOTAL_LENGTHS)
		end
		if payload.serverStartTime then
			startTimer(payload.serverStartTime)
		end
	elseif state == "Finished" then
		countdownPhase = nil
		-- If the local player finished, keep their frozen time; otherwise stop.
		if frozenTime == nil then
			stopTimerLoop()
		end
		if payload.champion then
			StatusLabel.Text = string.format("🏆 Champion: %s — %s", payload.champion, payload.championTime or "")
		else
			StatusLabel.Text = "Race finished!"
		end
	end
end)

LapUpdateEvent.OnClientEvent:Connect(function(lane: number, lengths: number, total: number)
	if myLane and lane == myLane then
		LapLabel.Text = string.format("Lane %d — length %d/%d", lane, lengths, total)
	end
end)

RaceFinishedEvent.OnClientEvent:Connect(function(lane: number, playerName: string, finishTime: number)
	resultCount += 1
	local entry = Instance.new("TextLabel")
	entry.Name = "Result" .. resultCount
	entry.Size = UDim2.new(1, 0, 0, 22)
	entry.BackgroundTransparency = 1
	entry.Font = Enum.Font.Gotham
	entry.TextScaled = true
	entry.TextXAlignment = Enum.TextXAlignment.Left
	entry.TextColor3 = Color3.new(1, 1, 1)
	entry.LayoutOrder = resultCount
	entry.Text = string.format("#%d  Lane %d — %s: %s", resultCount, lane, playerName, formatTime(finishTime))
	entry.Parent = ResultsFrame

	if lane == myLane then
		-- Freeze the local player's timer at their exact finish time.
		freezeTimer(finishTime)
		LapLabel.Text = string.format("Finished in %s!", formatTime(finishTime))
		StatusLabel.Text = "You finished!"
	end
end)
