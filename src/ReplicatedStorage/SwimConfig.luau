--!strict
-- Shared tuning for the swimming mechanics (breath + stroke styles) AND the
-- points-shop economy built on top of them.
--
-- Each style trades top speed against how long it takes to reach that speed
-- (the "startup" ramp) and how fast it burns air. Styles are now shop items:
-- `default` styles are free from the start; the rest cost `cost` points, earned
-- by racing (see the `points` block below).

export type Style = {
	name: string,
	topSpeed: number, -- max swim WalkSpeed once fully ramped
	startup: number, -- seconds of continuous swimming to reach topSpeed
	drain: number, -- breath drained per second while submerged
	cost: number, -- points to unlock in the shop (0 = free / default)
	default: boolean, -- unlocked for everyone from the start
	desc: string, -- one-line blurb shown in the shop
}

export type ImproveTier = {
	faster: number, -- seconds faster than your PREVIOUS race
	award: number, -- points granted when you beat it by this much
}

-- drain is tuned around the ~160-stud pool length: the cheap early strokes force
-- you to surface to breathe, while the expensive premium strokes are faster AND
-- sip less air, so the shop unlocks are a real upgrade. Typed as a [string]->Style
-- map so dynamic lookups (SwimConfig.styles[key]) and iteration stay type-safe.
local Styles: { [string]: Style } = {
	Freestyle = {
		name = "Freestyle",
		topSpeed = 26,
		startup = 0.8,
		drain = 16,
		cost = 0,
		default = true,
		desc = "The all-rounder. Free for everyone.",
	},
	Breaststroke = {
		name = "Breaststroke",
		topSpeed = 20,
		startup = 0.6,
		drain = 10,
		cost = 8,
		default = false,
		desc = "Endurance stroke — sips air, can hold a full length underwater.",
	},
	Butterfly = {
		name = "Butterfly",
		topSpeed = 36,
		startup = 2.6,
		drain = 30,
		cost = 20,
		default = false,
		desc = "Explosive top speed, but guzzles air and ramps up slowly.",
	},
	Riptide = {
		name = "Riptide",
		topSpeed = 42,
		startup = 1.2,
		drain = 12,
		cost = 45,
		default = false,
		desc = "Pro crawl: high speed, quick ramp, and easy on the lungs.",
	},
	Dolphin = {
		name = "Dolphin",
		topSpeed = 48,
		startup = 1.5,
		drain = 8,
		cost = 90,
		default = false,
		desc = "Elite dolphin kick — the fastest stroke, and it barely breathes.",
	},
}

local SwimConfig = {
	baseSwimSpeed = 12, -- swim speed with zero momentum (just pushed off)
	landSpeed = 16, -- normal on-foot WalkSpeed
	breathMax = 100,
	refillRate = 45, -- breath/sec regained at the surface or on land
	lowBreath = 18, -- recover from gasping once breath climbs back above this
	gaspMultiplier = 0.35, -- speed factor while out of breath
	momentumDecay = 0.7, -- seconds to bleed a full momentum bar when not swimming

	styles = Styles,

	-- selection order for the number hotkeys and the shop list
	order = { "Freestyle", "Breaststroke", "Butterfly", "Riptide", "Dolphin" },

	-- Points economy. You always earn `finish` for completing a race; if you beat
	-- your PREVIOUS race's time you earn the highest matching tier instead. Tiers
	-- are checked by "seconds faster", so tune these numbers to taste.
	points = {
		finish = 1,
		improveTiers = {
			{ faster = 1, award = 2 } :: ImproveTier,
			{ faster = 3, award = 3 } :: ImproveTier,
			{ faster = 5, award = 4 } :: ImproveTier,
		},
	},
}

return SwimConfig
