--!strict
-- Personal audio direction for Aqua Sprint. This stays client-side so each
-- player gets clean, smooth fades independent of when they joined the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local RaceEvents = ReplicatedStorage:WaitForChild("RaceEvents")
local RaceStateChangedEvent = RaceEvents:WaitForChild("RaceStateChanged") :: RemoteEvent

-- Both are free Creator Store audio assets. Keeping the IDs here makes it easy
-- to audition or swap the mood later without touching the race code.
local ISLAND_AMBIENCE_ID = "rbxassetid://95278058289420" -- Island Breeze, Cadenza
local RACE_CROWD_ID = "rbxassetid://9119562631" -- Stadium Crowd 1, Pro Sound Effects

local FADE_TIME = 1.35
local EXPLORE_ISLAND_VOLUME = 0.20
local WAITING_ISLAND_VOLUME = 0.14
local RACING_ISLAND_VOLUME = 0.045
local RACE_CROWD_VOLUME = 0.32
local FINISH_CROWD_VOLUME = 0.22

local soundscape = Instance.new("Folder")
soundscape.Name = "AquaSprintSoundscape"
soundscape.Parent = SoundService

local function makeLoop(name: string, soundId: string): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Looped = true
	sound.Volume = 0
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = soundscape
	return sound
end

local islandAmbience = makeLoop("IslandAmbience", ISLAND_AMBIENCE_ID)
local raceCrowd = makeLoop("RaceCrowd", RACE_CROWD_ID)

local activeTweens: { [Sound]: Tween } = {}

local function fade(sound: Sound, targetVolume: number)
	local currentTween = activeTweens[sound]
	if currentTween then
		currentTween:Cancel()
	end

	-- Play at silence first so bringing a layer in never creates a hard cut.
	if targetVolume > 0 and not sound.IsPlaying then
		sound:Play()
	end

	local tween = TweenService:Create(
		sound,
		TweenInfo.new(FADE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Volume = targetVolume }
	)
	activeTweens[sound] = tween
	tween:Play()
end

local function setMood(state: string)
	if state == "Waiting" then
		-- The pool is waking up, but the relaxing island loop stays in front.
		fade(islandAmbience, WAITING_ISLAND_VOLUME)
		fade(raceCrowd, 0)
	elseif state == "Countdown" or state == "Racing" then
		-- Let the crowd arrive as racers line up and carry through the sprint.
		fade(islandAmbience, RACING_ISLAND_VOLUME)
		fade(raceCrowd, RACE_CROWD_VOLUME)
	elseif state == "Finished" then
		-- Keep a little celebration behind the finish fanfare before reset.
		fade(islandAmbience, WAITING_ISLAND_VOLUME)
		fade(raceCrowd, FINISH_CROWD_VOLUME)
	else
		-- Idle is the normal free-exploration island mood.
		fade(islandAmbience, EXPLORE_ISLAND_VOLUME)
		fade(raceCrowd, 0)
	end
end

-- There is no initial race-state packet for a player joining a quiet server,
-- so establish the exploration sound immediately.
setMood("Idle")

RaceStateChangedEvent.OnClientEvent:Connect(function(payload: { [string]: any })
	setMood(tostring(payload.state or "Idle"))
end)
