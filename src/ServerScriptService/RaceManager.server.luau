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

local function formatTime(seconds: number): string
	local minutes = math.floor(seconds / 60)
	local secs = seconds - minutes * 60
	return string.format("%d:%05.2f", minutes, secs)
end

-- Best-time statistic shown next to each player's name on the leaderboard.
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

local function ensureBestStat(player: Player): StringValue
	local ls = getOrMake(player, "leaderstats", "Folder")
	local existing = ls:FindFirstChild("Best Time")
	if existing and existing:IsA("StringValue") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local stat = Instance.new("StringValue")
	stat.Name = "Best Time"
	stat.Value = "—"
	stat.Parent = ls
	return stat
end

local function recordFinish(player: Player, finishTime: number)
	local prev = player:GetAttribute("BestTimeSeconds")
	if type(prev) ~= "number" or finishTime < prev then
		player:SetAttribute("BestTimeSeconds", finishTime)
		ensureBestStat(player).Value = formatTime(finishTime)
	end
end

Players.PlayerAdded:Connect(ensureBestStat)
for _, existing in Players:GetPlayers() do
	task.spawn(ensureBestStat, existing)
end

-- Champion ceremony: the server's fastest player is crowned on the 1st podium
-- with fireworks and sound whenever a race ends.
local CEREMONY_SOUNDS = { "CrowdCheer", "Anthem" }

local function fastestPlayer(): (Player?, number?)
	local bestPlayer: Player? = nil
	local bestTime: number? = nil
	for _, p in Players:GetPlayers() do
		local t = p:GetAttribute("BestTimeSeconds")
		if type(t) == "number" and (bestTime == nil or t < bestTime) then
			bestTime, bestPlayer = t, p
		end
	end
	return bestPlayer, bestTime
end

local function podiumTop(): Vector3?
	for _, d in Workspace:GetDescendants() do
		if d:IsA("Model") and d.Name == "1st Podium" then
			local cf, size = d:GetBoundingBox()
			return cf.Position + Vector3.new(0, size.Y / 2 + 3, 0)
		end
	end
	return nil
end

local function launchFireworks(duration: number)
	local fw = Workspace:FindFirstChild("Fireworks")
	if not fw then
		return
	end
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration do
			for _, launcher in fw:GetChildren() do
				local burst = launcher:FindFirstChild("Burst")
				if burst and burst:IsA("ParticleEmitter") then
					burst:Emit(60)
				end
			end
			task.wait(0.45)
			elapsed += 0.45
		end
	end)
end

local function ceremonySounds(play: boolean)
	for _, name in CEREMONY_SOUNDS do
		local s = SoundService:FindFirstChild(name)
		if s and s:IsA("Sound") then
			if play then
				s:Play()
			else
				s:Stop()
			end
		end
	end
end

local function runChampionCeremony()
	local champ, t = fastestPlayer()
	if not champ then
		return
	end
	broadcastState({ champion = champ.Name, championTime = if t then formatTime(t) else nil })
	local char = champ.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local top = podiumTop()
	if root and root:IsA("BasePart") and top then
		root.CFrame = CFrame.new(top)
	end
	launchFireworks(RESET_DELAY_SECONDS)
	ceremonySounds(true)
	print(string.format("[Race] champion %s crowned (%.2fs)", champ.Name, t or -1))
end

local function resetRace()
	Race.state = "Idle"
	Race.racers = {}
	setBarriers(false)
	setStartGate(false)
	ceremonySounds(false)
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
	runChampionCeremony()
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
		recordFinish(player, finishTime)
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
