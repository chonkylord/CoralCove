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
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local RaceEvents = ReplicatedStorage:WaitForChild("RaceEvents")
local RaceStateChangedEvent = RaceEvents:WaitForChild("RaceStateChanged") :: RemoteEvent
local LapUpdateEvent = RaceEvents:WaitForChild("LapUpdate") :: RemoteEvent
local RaceFinishedEvent = RaceEvents:WaitForChild("RaceFinished") :: RemoteEvent
local PointsAwardedEvent = RaceEvents:WaitForChild("PointsAwarded") :: RemoteEvent

local Hud = PlayerGui:WaitForChild("RaceHud")
local StatusLabel = Hud:WaitForChild("StatusLabel") :: TextLabel
local TimerLabel = Hud:WaitForChild("TimerLabel") :: TextLabel
local LapLabel = Hud:WaitForChild("LapLabel") :: TextLabel

-- Coach Marina owns the arrival guidance. Keep the old full-width status
-- banner quiet until an actual race state needs to be communicated.
StatusLabel.Text = ""
TimerLabel.Text = ""
LapLabel.Text = ""
StatusLabel.Visible = false

local TOTAL_LENGTHS = 2

local myLane: number? = nil
local lastFinishTime: number? = nil

local function formatTime(seconds: number): string
	local minutes = math.floor(seconds / 60)
	local secs = seconds - minutes * 60
	return string.format("%d:%05.2f", minutes, secs)
end

-- A compact result card gives the player a clear payoff for finishing and a
-- concrete next action. The server remains the source of every displayed award
-- and personal-best flag; this client only presents that result.
local resultCard = Instance.new("Frame")
resultCard.Name = "RaceResultCard"
resultCard.AnchorPoint = Vector2.new(0.5, 1)
resultCard.Position = UDim2.new(0.5, 0, 1, -92)
resultCard.Size = UDim2.fromOffset(390, 116)
resultCard.BackgroundColor3 = Color3.fromRGB(19, 29, 45)
resultCard.BackgroundTransparency = 0.08
resultCard.BorderSizePixel = 0
resultCard.Visible = false
resultCard.Parent = Hud

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 14)
cardCorner.Parent = resultCard

local cardStroke = Instance.new("UIStroke")
cardStroke.Color = Color3.fromRGB(83, 190, 255)
cardStroke.Thickness = 2
cardStroke.Transparency = 0.2
cardStroke.Parent = resultCard

local cardScale = Instance.new("UIScale")
cardScale.Scale = 0.88
cardScale.Parent = resultCard

local resultTitle = Instance.new("TextLabel")
resultTitle.Name = "Title"
resultTitle.Position = UDim2.fromOffset(16, 12)
resultTitle.Size = UDim2.new(1, -32, 0, 32)
resultTitle.BackgroundTransparency = 1
resultTitle.Font = Enum.Font.GothamBold
resultTitle.TextColor3 = Color3.fromRGB(255, 216, 96)
resultTitle.TextSize = 22
resultTitle.TextXAlignment = Enum.TextXAlignment.Center
resultTitle.Parent = resultCard

local resultDetail = Instance.new("TextLabel")
resultDetail.Name = "Detail"
resultDetail.Position = UDim2.fromOffset(16, 45)
resultDetail.Size = UDim2.new(1, -32, 0, 26)
resultDetail.BackgroundTransparency = 1
resultDetail.Font = Enum.Font.GothamBold
resultDetail.TextColor3 = Color3.fromRGB(240, 245, 255)
resultDetail.TextSize = 18
resultDetail.TextXAlignment = Enum.TextXAlignment.Center
resultDetail.Parent = resultCard

local resultNext = Instance.new("TextLabel")
resultNext.Name = "Next"
resultNext.Position = UDim2.fromOffset(16, 76)
resultNext.Size = UDim2.new(1, -32, 0, 24)
resultNext.BackgroundTransparency = 1
resultNext.Font = Enum.Font.GothamMedium
resultNext.TextColor3 = Color3.fromRGB(161, 205, 236)
resultNext.TextSize = 14
resultNext.Text = "Ready for another heat? Touch any starting block."
resultNext.TextXAlignment = Enum.TextXAlignment.Center
resultNext.Parent = resultCard

local resultToken = 0
local function showResultCard(awarded: number, faster: number, isBest: boolean)
	resultToken += 1
	local myToken = resultToken
	if isBest then
		resultTitle.Text = "🏅 NEW PERSONAL BEST!"
	elseif faster > 0 then
		resultTitle.Text = string.format("⚡ %.2fs FASTER!", faster)
	else
		resultTitle.Text = "🏁 RACE COMPLETE!"
	end
	local timeText = if lastFinishTime then formatTime(lastFinishTime) else "Finished"
	resultDetail.Text = string.format("%s   •   +%d points", timeText, awarded)
	resultCard.Visible = true
	cardScale.Scale = 0.88
	TweenService:Create(cardScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()

	-- Leave enough time to read the reward, then return visual focus to the
	-- starting blocks. A newer result always owns the card.
	task.delay(6, function()
		if resultToken == myToken then
			resultCard.Visible = false
		end
	end)
end

-- Timer state
local timerConn: RBXScriptConnection? = nil
local serverStartTime: number? = nil
local frozenTime: number? = nil

-- Countdown state (ticks off the server clock so 8..1 and 3..2..1 are live)
local countdownPhase: string? = nil -- "Waiting" | "Countdown" | nil
local countdownEndTime: number? = nil

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
		StatusLabel.Visible = false
		LapLabel.Text = ""
	elseif state == "Waiting" then
		StatusLabel.Visible = true
		countdownPhase = "Waiting"
		countdownEndTime = payload.endTime
		LapLabel.Text = ""
	elseif state == "Countdown" then
		StatusLabel.Visible = true
		countdownPhase = "Countdown"
		countdownEndTime = payload.endTime
	elseif state == "Racing" then
		StatusLabel.Visible = true
		countdownPhase = nil
		StatusLabel.Text = if myLane then "GO! Touch the far wall, then race back!" else "Race in progress"
		if myLane then
			LapLabel.Text = string.format("Lane %d — length 0/%d", myLane, TOTAL_LENGTHS)
		end
		if payload.serverStartTime then
			startTimer(payload.serverStartTime)
		end
	elseif state == "Finished" then
		StatusLabel.Visible = true
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
		StatusLabel.Visible = true
		LapLabel.Text = string.format("Lane %d — length %d/%d", lane, lengths, total)
		if lengths < total then
			StatusLabel.Text = "Great turn — race back to the finish!"
		end
	end
end)

RaceFinishedEvent.OnClientEvent:Connect(function(lane: number, _playerName: string, finishTime: number)
	-- Full standings now live on the poolside scoreboard; the HUD only reacts to
	-- the LOCAL player's finish, freezing their timer at their exact finish time.
	if lane == myLane then
		StatusLabel.Visible = true
		lastFinishTime = finishTime
		freezeTimer(finishTime)
		LapLabel.Text = string.format("Finished in %s!", formatTime(finishTime))
		StatusLabel.Text = "Finish confirmed — calculating your reward..."
	end
end)

PointsAwardedEvent.OnClientEvent:Connect(function(awarded: number, _newTotal: number, faster: number, isBest: boolean)
	StatusLabel.Visible = true
	showResultCard(awarded, faster, isBest)
	if isBest then
		StatusLabel.Text = "New personal best — return to a starting block to race again!"
	else
		StatusLabel.Text = "Points earned — return to a starting block to race again!"
	end
end)
