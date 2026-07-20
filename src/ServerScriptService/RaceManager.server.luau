--!strict
-- Server-authoritative swimming race. Players join by standing on a numbered
-- starting block. Once racing, they must reach the far wall (TurnZone) and swim
-- back to the near wall (FinishZone) to complete the two lengths; touching the
-- FinishZone on the way back seals their time. Invisible barriers confine
-- racers to the pool while a race is running.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")

local RaceEvents = ReplicatedStorage:WaitForChild("RaceEvents")
local RaceStateChangedEvent = RaceEvents:WaitForChild("RaceStateChanged") :: RemoteEvent
local LapUpdateEvent = RaceEvents:WaitForChild("LapUpdate") :: RemoteEvent
local RaceFinishedEvent = RaceEvents:WaitForChild("RaceFinished") :: RemoteEvent

local Pool = Workspace:WaitForChild("OlympicPool")
local TurnZone = Pool:WaitForChild("TurnZone") :: BasePart
local FinishZone = Pool:WaitForChild("FinishZone") :: BasePart
local Barriers = Pool:WaitForChild("Barriers")
local StartGate = Pool:WaitForChild("StartGate") :: BasePart

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

-- Mutable race state lives behind a table, not bare locals: task.spawn closures
-- below run long after they're created, and a getter call is opaque to the type
-- checker's flow analysis so it always yields the full RaceState union.
local Race = {
	state = "Idle" :: RaceState,
	racers = {} :: { [number]: Racer },
	startClock = 0,
}

local function getState(): RaceState
	return Race.state
end

-- Side/end walls + lane dividers: solid only while a race is running, so lanes
-- are locked and racers can't climb out mid-race.
local function setBarriers(enabled: boolean)
	for _, wall in Barriers:GetChildren() do
		if wall:IsA("BasePart") then
			wall.CanCollide = enabled
		end
	end
end

-- The start gate is raised the OPPOSITE way: solid during the join window and
-- countdown to prevent an early dive, and dropped at "GO".
local function setStartGate(raised: boolean)
	StartGate.CanCollide = raised
end

local function broadcastState(extra: { [string]: any }?)
	local payload: { [string]: any } = extra or {}
	payload.state = getState()
	RaceStateChangedEvent:FireAllClients(payload)
end

local function findRacerByPlayer(player: Player): Racer?
	for _, racer in Race.racers do
		if racer.player == player then
			return racer
		end
	end
	return nil
end

local function laneOf(target: Racer): number?
	for lane, racer in Race.racers do
		if racer == target then
			return lane
		end
	end
	return nil
end

local function resetRace()
	Race.state = "Idle"
	Race.racers = {}
	setBarriers(false)
	setStartGate(false)
	broadcastState()
	print("[Race] reset to Idle")
end

local function enterFinished()
	if getState() == "Finished" then
		return
	end
	Race.state = "Finished"
	setBarriers(false)
	broadcastState()
	FinishFanfare:Play()
	task.spawn(function()
		task.wait(RESET_DELAY_SECONDS)
		if getState() == "Finished" then
			resetRace()
		end
	end)
end

local function finishRaceEarlyIfAllDone()
	for _, racer in Race.racers do
		if not racer.finishTime then
			return
		end
	end
	enterFinished()
end

local function startCountdown()
	if getState() ~= "Waiting" then
		return
	end
	Race.state = "Countdown"
	broadcastState({ endTime = Workspace:GetServerTimeNow() + COUNTDOWN_SECONDS })

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
		Race.startClock = Workspace:GetServerTimeNow()
		setBarriers(true)
		setStartGate(false) -- drop the gate on GO so racers can dive in
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
				enterFinished()
			end
		end)
	end)
end

local function tryStartJoinWindow()
	if getState() ~= "Idle" then
		return
	end
	Race.state = "Waiting"
	setStartGate(true) -- raise the gate so nobody dives in before GO
	broadcastState({ endTime = Workspace:GetServerTimeNow() + JOIN_WINDOW_SECONDS })

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

-- Lane-agnostic checkpoint: whichever racer swims into a zone advances, as long
-- as it's the wall they're currently expecting (Turn at the far end, then Finish
-- back at the near end).
local function onZoneTouched(zone: BasePart, kind: WallKind, otherPart: BasePart)
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
	local racer = findRacerByPlayer(player)
	if not racer or racer.finishTime or racer.expecting ~= kind then
		return
	end

	local lane = laneOf(racer) or 0
	racer.lengths += 1
	racer.expecting = if kind == "Turn" then "Finish" else "Turn"
	LapUpdateEvent:FireAllClients(lane, racer.lengths, TOTAL_LENGTHS)
	print(
		string.format(
			"[Race] lane %d (%s) reached %s — length %d/%d",
			lane,
			player.Name,
			kind,
			racer.lengths,
			TOTAL_LENGTHS
		)
	)

	local splash = zone:FindFirstChild("Splash")
	if splash and splash:IsA("ParticleEmitter") then
		splash:Emit(40)
	end

	if racer.lengths >= TOTAL_LENGTHS then
		local finishTime = Workspace:GetServerTimeNow() - Race.startClock
		racer.finishTime = finishTime
		RaceFinishedEvent:FireAllClients(lane, player.Name, finishTime)
		print(string.format("[Race] lane %d (%s) FINISHED in %.2fs", lane, player.Name, finishTime))
		finishRaceEarlyIfAllDone()
	end
end

-- Starting blocks: touch one to join its lane.
for _, child in Pool:GetChildren() do
	if child:IsA("BasePart") then
		local lane = child:GetAttribute("Lane")
		local kind = child:GetAttribute("Kind")
		if typeof(lane) == "number" and kind == nil then
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

TurnZone.Touched:Connect(function(otherPart: BasePart)
	onZoneTouched(TurnZone, "Turn", otherPart)
end)
FinishZone.Touched:Connect(function(otherPart: BasePart)
	onZoneTouched(FinishZone, "Finish", otherPart)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	for lane, racer in Race.racers do
		if racer.player == player then
			Race.racers[lane] = nil
		end
	end
end)
