-- GameConfig
-- Every tunable number for Midnight Hatch, in one place. The server and the client both read it.
-- Nothing here is secret: what is inside an egg is rolled and kept on the server only.

local GameConfig = {}

GameConfig.Version = "0.1.0 (Round 1 first playable)"

GameConfig.CollisionGroups = {
	Guardian = "MH_Guardian", -- passes through trees, rocks and players
	Trees = "MH_Trees",
	Players = "MH_Players",
}

GameConfig.Player = {
	BaseWalkSpeed = 18, -- unencumbered (Roblox default is 16)
	StunWalkSpeed = 3,
	StunSeconds = 1.6,
	CatchImmunitySeconds = 3, -- the guardian ignores a player for this long after catching them
	GrabRange = 9, -- studs from the character to the egg's surface
	GrabRangeSlack = 3, -- extra allowance on the server check, for latency
	HelpRange = 14, -- studs from a Giant-egg carrier to join or keep helping
}

-- One server-wide loop with no lobby or results screen: 4 minutes of Dusk, then a 1-minute Midnight surge.
GameConfig.Cycle = {
	DuskSeconds = 240,
	MidnightSeconds = 60,
}

GameConfig.Variants = {
	MidnightChanceDusk = 0.01, -- chance a Dusk egg hatches the Midnight variant
	MidnightChanceMidnightEgg = 0.25, -- chance for an egg that glowed at Midnight
	MidnightShellsMultiplier = 1.5,
	MidnightPerkMultiplier = 1.5, -- Midnight pets do their job 50% better
}

GameConfig.EggOrder = { "Pebble", "Moss", "Giant" }

-- Odds weights sum to 100 per egg, so each weight reads as a percentage.
GameConfig.Eggs = {
	Pebble = {
		DisplayName = "Pebble Egg",
		Height = 2.4,
		Color = Color3.fromRGB(214, 208, 196),
		SpeckleColor = Color3.fromRGB(120, 112, 104),
		Speckles = 5,
		GrabNoise = 12,
		CarryNoisePerSecond = 2,
		CarrySpeed = 0.92, -- multiplier on walk speed while carrying
		Shells = 10,
		RespawnSeconds = 6,
		ThreatWeight = 2, -- how much the guardian prefers chasing this carrier
		Odds = {
			{ Id = "ToastMoth", Weight = 40 },
			{ Id = "Socktopus", Weight = 38 },
			{ Id = "Marshmole", Weight = 16 },
			{ Id = "Pumpkit", Weight = 5 },
			{ Id = "Moonbean", Weight = 1 },
		},
	},
	Moss = {
		DisplayName = "Moss Egg",
		Height = 3.4,
		Color = Color3.fromRGB(120, 168, 96),
		SpeckleColor = Color3.fromRGB(70, 110, 58),
		Speckles = 7,
		GrabNoise = 35,
		CarryNoisePerSecond = 8,
		CarrySpeed = 0.78,
		Shells = 30,
		RespawnSeconds = 12,
		ThreatWeight = 3,
		Odds = {
			{ Id = "ToastMoth", Weight = 18 },
			{ Id = "Socktopus", Weight = 18 },
			{ Id = "Marshmole", Weight = 30 },
			{ Id = "Pumpkit", Weight = 24 },
			{ Id = "Moonbean", Weight = 8 },
			{ Id = "Wispurr", Weight = 2 },
		},
	},
	Giant = {
		DisplayName = "Giant Moon Egg",
		Height = 7,
		Color = Color3.fromRGB(236, 226, 196),
		SpeckleColor = Color3.fromRGB(150, 128, 220),
		Speckles = 10,
		GrabNoise = 70,
		CarryNoisePerSecond = 18,
		CarrySpeed = 0.45, -- alone; every helper adds GiantCarry.PerHelper
		Shells = 100,
		RespawnSeconds = 30,
		ThreatWeight = 5,
		Odds = {
			{ Id = "ToastMoth", Weight = 4 },
			{ Id = "Socktopus", Weight = 4 },
			{ Id = "Marshmole", Weight = 20 },
			{ Id = "Pumpkit", Weight = 34 },
			{ Id = "Moonbean", Weight = 26 },
			{ Id = "Wispurr", Weight = 12 },
		},
	},
}

-- Giant eggs are a co-op job: friends who help carry get their own hatch from the same egg.
GameConfig.GiantCarry = {
	PerHelper = 0.15, -- carry speed added per helper (0.45 alone -> 0.90 with three)
	MaxHelpers = 3,
	HelperMinSeconds = 4, -- must help this long to share the hatch (stops door-step freeloading)
	LeaveAfterSeconds = 1, -- a helper who drifts out of range this long stops helping
}

GameConfig.Nest = {
	-- Egg slots around the nest centre. +Z points toward the hatchery.
	Slots = {
		{ Kind = "Giant", Offset = Vector3.new(0, 0, -1) },
		{ Kind = "Moss", Offset = Vector3.new(-8, 0, 3) },
		{ Kind = "Moss", Offset = Vector3.new(8, 0, 3) },
		{ Kind = "Pebble", Offset = Vector3.new(-12, 0, 9) },
		{ Kind = "Pebble", Offset = Vector3.new(0, 0, 10) },
		{ Kind = "Pebble", Offset = Vector3.new(12, 0, 9) },
	},
	-- Practice eggs on the trail near the hatchery, too far away for the guardian to hear.
	StraySlots = {
		Vector3.new(7, 0, 48),
		Vector3.new(5, 0, 24),
		Vector3.new(-6, 0, 6),
	},
	StrayRespawnSeconds = 20,
	StrayShellsMultiplier = 0.5,
	DroppedEggSeconds = 25, -- a dropped egg nobody picks up rolls back to its slot
	PickupLockSeconds = 0.75, -- nobody can grab a just-dropped egg for this long
}

-- Noise: one Pebble or Moss carrier never wakes her on their own (the meter also drains while you
-- carry); two Moss eggs at once can; a Giant egg always does, about 2 seconds after the grab.
-- tests/run.luau simulates this.
GameConfig.Guardian = {
	DisplayName = "Mama Moss",
	WakeThreshold = 100,
	NoiseDecayPerSecond = 5,
	NoiseRadius = 60, -- grabbing or carrying within this distance of the nest makes noise
	RestNoise = 35, -- the meter's value after she settles back to sleep
	WakeRoarSeconds = 1.6, -- fair warning before the chase starts
	ChaseSpeed = 19.5,
	MidnightChaseSpeed = 21,
	ReturnSpeed = 12,
	PatrolSpeed = 10,
	AggroRadius = 90,
	MidnightAggroRadius = 110,
	NoticeRadius = 30, -- while walking home she still turns on a carrier this close
	LeashRadius = 230, -- she never chases farther than this from her nest
	CatchRadius = 8,
	GloatSeconds = 1.2,
	LoseInterestSeconds = 3,
	ChaseBurstSeconds = 9, -- after chasing one player this long she stops to pant
	PantSeconds = 2.2,
	SafeZoneMargin = 2, -- she stops this far outside the hatchery fence
	PatrolRadius = 45,
}

GameConfig.Map = {
	Seed = 20261005, -- same forest on every server
	GroundSize = 420,
	PlayableHalfSize = 195,
	HatcheryCenter = Vector3.new(0, 0, 90),
	HatcheryRadius = 26, -- the fence; inside it is the safe zone
	NestCenter = Vector3.new(0, 0, -90),
	GuardianHomeOffset = Vector3.new(0, 0, -13),
	-- The trail from the hatchery gate to the front of the nest (X, Z points).
	Trail = {
		Vector3.new(0, 0, 66),
		Vector3.new(12, 0, 34),
		Vector3.new(-10, 0, 0),
		Vector3.new(8, 0, -36),
		Vector3.new(0, 0, -70),
	},
	TrailWidth = 14,
	TreeCount = 60,
	EdgeTreeCount = 36,
	BushCount = 34,
	MushroomCount = 28,
	RockCount = 18,
}

GameConfig.Security = {
	ActionsPerSecond = 8, -- remote requests per player (token bucket)
	ActionBurst = 8,
	SpeedTolerance = 1.5, -- carriers may move up to 1.5x their walk speed (lag spikes)
	SpeedSlackStuds = 5,
	TeleportFactor = 3, -- a single jump beyond 3x the allowance drops the egg at once
	MaxStrikes = 3,
	StrikeWindowSeconds = 2,
	MaxBankPace = 30, -- studs/s, straight line from pickup to the hatchery; faster is rejected
}

return GameConfig
