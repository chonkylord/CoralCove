--!strict
-- Server-authoritative swimming race: players join by standing on a numbered
-- starting block, then alternate touching the far (Turn) and near (Finish)
-- wall of their lane to complete lengths.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")

local RaceEvents = ReplicatedStorage:WaitForChild("RaceEvents")
local RaceStateChangedEvent = RaceEvents:WaitForChild("RaceStateChanged") :: RemoteEvent
local LapUpdateEvent = RaceEvents:WaitForChild("LapUpdate") :: RemoteEvent
local RaceFinishedEvent = RaceEvents:WaitForChild("RaceFinished") :: RemoteEvent

local Pool = Workspace:WaitForChild("OlympicPool")
local Checkpoints = Pool:WaitForChild("Checkpoints")

local CountdownBeep = SoundService:WaitForChild("CountdownBeep") :: Sound
local StartHorn = SoundService:WaitForChild("StartHorn") :: Sound
local FinishFanfare = SoundService:WaitForChild("FinishFanfare") :: Sound

-- 2 lengths = one down-and-back "lap" of the pool (like a 100m race).
local TOTAL_LENGTHS = 2
local JOIN_WINDOW_SECONDS = 8
local COUNTDOWN_SECONDS = 3
local RACE_TIMEOUT_SECONDS = 120
local RESET_DELAY_SECONDS = 6

type RaceState = "Idle" | "Waiting" | "Countdown" | "Racing" | "Finished"
type WallKind = "Turn" | "Finish"

type Racer = {
	player: Player,
	lengths: number,
	expecting: WallKind,
	finishTime: number?,
}

-- Mutable race state lives behind a table, not bare locals: task.spawn
-- closures below run long after they're created, and bare-local/table-field
-- narrowing doesn't account for reassignment that happens in between. A
-- getter function call is opaque to the checker's flow analysis, so it
-- always yields the full RaceState union instead of a stale narrowed literal.
local Race = {
	state = "Idle" :: RaceState,
	racers = {} :: { [number]: Racer },
	startClock = 0,
}

local function getState(): RaceState
	return Race.state
end

local function broadcastState(extra: { [string]: any }?)
	local payload: { [string]: any } = extra or {}
	payload.state = getState()
	RaceStateChangedEvent:FireAllClients(payload)
end

local function resetRace()
	Race.state = "Idle"
	Race.racers = {}
	broadcastState()
	print("[Race] reset to Idle")
end

local function finishRaceEarlyIfAllDone()
	for _, racer in Race.racers do
		if not racer.finishTime then
			return
		end
	end
	Race.state = "Finished"
	broadcastState()
	FinishFanfare:Play()
	task.spawn(function()
		task.wait(RESET_DELAY_SECONDS)
		if getState() == "Finished" then
			resetRace()
		end
	end)
end

local function startCountdown()
	if getState() ~= "Waiting" then
		return
	end
	Race.state = "Countdown"
	broadcastState({ seconds = COUNTDOWN_SECONDS })

	task.spawn(function()
		for _ = 1, COUNTDOWN_SECONDS do
			if getState() ~= "Countdown" then
				return
			end
			CountdownBeep:Play()
			task.wait(1)
		end
		if getState() ~= "Countdown" then
			return
		end
		Race.state = "Racing"
		Race.startClock = workspace:GetServerTimeNow()
		broadcastState({ serverStartTime = Race.startClock })
		StartHorn:Play()
		local racerCount = 0
		for _ in Race.racers do
			racerCount += 1
		end
		print(string.format("[Race] started with %d racer(s)", racerCount))

		task.spawn(function()
			task.wait(RACE_TIMEOUT_SECONDS)
			if getState() == "Racing" then
				Race.state = "Finished"
				broadcastState()
				task.wait(RESET_DELAY_SECONDS)
				if getState() == "Finished" then
					resetRace()
				end
			end
		end)
	end)
end

local function tryStartJoinWindow()
	if getState() ~= "Idle" then
		return
	end
	Race.state = "Waiting"
	broadcastState({ seconds = JOIN_WINDOW_SECONDS })

	task.spawn(function()
		task.wait(JOIN_WINDOW_SECONDS)
		if getState() == "Waiting" then
			startCountdown()
		end
	end)
end

local function joinLane(player: Player, lane: number)
	if getState() ~= "Idle" and getState() ~= "Waiting" then
		return
	end
	if Race.racers[lane] and Race.racers[lane].player == player then
		return
	end
	for existingLane, racer in Race.racers do
		if racer.player == player then
			Race.racers[existingLane] = nil
		end
	end
	if Race.racers[lane] then
		return
	end

	Race.racers[lane] = {
		player = player,
		lengths = 0,
		expecting = "Turn",
		finishTime = nil,
	}
	broadcastState({ joinedLane = lane, playerName = player.Name })
	print(string.format("[Race] %s joined lane %d", player.Name, lane))

	if getState() == "Idle" then
		tryStartJoinWindow()
	end
end

local function onCheckpointTouched(pad: BasePart, lane: number, kind: WallKind, otherPart: BasePart)
	if getState() ~= "Racing" then
		return
	end
	local character = otherPart.Parent
	if not character or not character:IsA("Model") then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local racer = Race.racers[lane]
	if not racer or racer.player ~= player or racer.finishTime then
		return
	end
	if racer.expecting ~= kind then
		return
	end

	racer.lengths += 1
	racer.expecting = if kind == "Turn" then "Finish" else "Turn"
	LapUpdateEvent:FireAllClients(lane, racer.lengths, TOTAL_LENGTHS)
	print(string.format("[Race] lane %d (%s) completed length %d/%d", lane, player.Name, racer.lengths, TOTAL_LENGTHS))

	local splash = pad:FindFirstChild("Splash")
	if splash and splash:IsA("ParticleEmitter") then
		splash:Emit(40)
	end

	if racer.lengths >= TOTAL_LENGTHS then
		local finishTime = workspace:GetServerTimeNow() - Race.startClock
		racer.finishTime = finishTime
		RaceFinishedEvent:FireAllClients(lane, player.Name, finishTime)
		print(string.format("[Race] lane %d (%s) finished in %.2fs", lane, player.Name, finishTime))
		finishRaceEarlyIfAllDone()
	end
end

for _, child in Pool:GetChildren() do
	if child:IsA("BasePart") then
		local lane = child:GetAttribute("Lane")
		local kind = child:GetAttribute("Kind")
		if typeof(lane) == "number" and kind == nil then
			-- Starting block for this lane: touch it to join.
			child.Touched:Connect(function(otherPart: BasePart)
				local character = otherPart.Parent
				if not character or not character:IsA("Model") then
					return
				end
				local player = Players:GetPlayerFromCharacter(character)
				if player then
					joinLane(player, lane)
				end
			end)
		end
	end
end

for _, child in Checkpoints:GetChildren() do
	if child:IsA("BasePart") then
		local lane = child:GetAttribute("Lane")
		local kind = child:GetAttribute("Kind")
		if typeof(lane) == "number" and (kind == "Turn" or kind == "Finish") then
			child.Touched:Connect(function(otherPart: BasePart)
				onCheckpointTouched(child, lane, kind :: WallKind, otherPart)
			end)
		end
	end
end

Players.PlayerRemoving:Connect(function(player: Player)
	for lane, racer in Race.racers do
		if racer.player == player then
			Race.racers[lane] = nil
		end
	end
end)
