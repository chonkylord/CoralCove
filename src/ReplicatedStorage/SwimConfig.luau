--!strict
-- Shared tuning for the swimming mechanics (breath + stroke styles).
-- Each style trades top speed against how long it takes to reach that speed
-- (the "startup" ramp) and how fast it burns air.

export type Style = {
	name: string,
	topSpeed: number, -- max swim WalkSpeed once fully ramped
	startup: number, -- seconds of continuous swimming to reach topSpeed
	drain: number, -- breath drained per second while submerged
}

local SwimConfig = {
	baseSwimSpeed = 12, -- swim speed with zero momentum (just pushed off)
	landSpeed = 16, -- normal on-foot WalkSpeed
	breathMax = 100,
	refillRate = 45, -- breath/sec regained at the surface or on land
	lowBreath = 18, -- recover from gasping once breath climbs back above this
	gaspMultiplier = 0.35, -- speed factor while out of breath
	momentumDecay = 0.7, -- seconds to bleed a full momentum bar when not swimming

	-- drain is tuned so you CAN'T cross a full pool length (~160 studs) underwater
	-- on the fast strokes: Butterfly empties in ~3.3s (must surface mid-lane),
	-- Freestyle ~6s (about one length then breathe), Breaststroke ~10s (the
	-- endurance stroke that can hold a length).
	styles = {
		Freestyle = { name = "Freestyle", topSpeed = 26, startup = 0.8, drain = 16 } :: Style,
		Butterfly = { name = "Butterfly", topSpeed = 36, startup = 2.6, drain = 30 } :: Style,
		Breaststroke = { name = "Breaststroke", topSpeed = 20, startup = 0.6, drain = 10 } :: Style,
	},

	-- selection order for the 1/2/3 hotkeys and the HUD
	order = { "Freestyle", "Butterfly", "Breaststroke" },
}

return SwimConfig
