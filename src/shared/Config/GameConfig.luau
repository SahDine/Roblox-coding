--[[
	GameConfig
	Every gameplay tuning value lives here so the game can be balanced
	without touching the systems themselves.
]]

local GameConfig = {}

GameConfig.GameName = "Steal a Critter"

GameConfig.Player = {
	WalkSpeed = 18,
	StartingCash = 100,
}

GameConfig.Data = {
	-- Changing the store name wipes everybody's progress (new DataStore).
	StoreName = "PlayerData_v1",
	AutoSaveInterval = 90,
	-- A session lock older than this is considered dead (server crash).
	SessionLockExpiry = 600,
	LoadAttempts = 6,
	LoadRetryDelay = 5,
	MaxStoredReceipts = 50,
}

GameConfig.Map = {
	PlotCount = 8, -- Set "Max Players" to 8 in Game Settings so everybody gets a base.
	PlotWidth = 72,
	PlotDepth = 76,
	PlotSpacing = 96, -- distance between two neighbouring bases (centre to centre)
	PlotDistanceFromCenter = 86, -- distance from the conveyor to the centre of a base
	ConveyorLength = 400,
	ConveyorWidth = 12,
}

-- Base + MaxFromRebirths + FromExtraSlotsPass must stay <= 16 (4x4 pedestal grid).
GameConfig.Slots = {
	Base = 8,
	PerRebirth = 1,
	MaxFromRebirths = 4,
	FromExtraSlotsPass = 4,
}

GameConfig.Economy = {
	SellRefund = 0.5, -- Selling gives back 50% of the purchase price.
	RebirthBaseCost = 250_000,
	RebirthCostGrowth = 4,
	RebirthIncomeBonus = 0.5, -- +50% income per rebirth.
	VipMultiplier = 2,
	PremiumBonus = 0.1, -- Roblox Premium members get +10% (boosts Premium payouts).
	FriendBonusPerFriend = 0.1,
	FriendBonusMax = 0.5,
	OfflineRate = 0.25, -- 25% of income while offline...
	OfflineMaxSeconds = 3 * 3600, -- ...for up to 3 hours.
}

GameConfig.Conveyor = {
	SpawnInterval = 6, -- seconds between two critters
	WalkSpeed = 4, -- studs per second on the conveyor (~100 s from one end to the other)
	MaxCritters = 20,
	DeliverySpeed = 10, -- walk speed of a bought critter heading to its new base
}

-- Legendary, Mythic and Secret critters never come from the random conveyor roll: each rarity
-- spawns on its own server-wide timer, shown on the "RARE CRITTERS" board next to the NEW CRITTERS
-- portal. 2x Server Luck makes these timers run 2x faster. Mutations still roll for these critters.
-- Times are in seconds. First = random delay { min, max } before the first one after a server start.
-- WarnBefore (optional) = server-wide heads-up this many seconds before the spawn.
GameConfig.RareSpawns = {
	Order = { "Legendary", "Mythic", "Secret" }, -- board rows, top to bottom
	Timers = {
		Legendary = { Interval = 8 * 60, First = { 3 * 60, 5 * 60 } },
		Mythic = { Interval = 25 * 60, First = { 10 * 60, 14 * 60 }, WarnBefore = 60 },
		Secret = { Interval = 60 * 60, First = { 25 * 60, 35 * 60 }, WarnBefore = 60 },
	} :: { [string]: { Interval: number, First: { number }, WarnBefore: number? } },
	MinGap = 3, -- seconds between a timed critter and the previous conveyor critter (keeps them apart)
}

GameConfig.Steal = {
	Enabled = true,
	HoldDuration = 2,
	FastStealHoldDuration = 1,
	CarryWalkSpeed = 14,
	FastStealCarryWalkSpeed = 19,
	CarryTimeout = 90,
	Cooldown = 4,
	AnnounceFromRarity = "Legendary", -- Server-wide message when this rarity or better is stolen.
}

-- Evolution: a critter placed in a base gains 1 XP per second. When its XP reaches the time
-- below (chosen by the rarity of the NEXT form) the owner can evolve it for a share of the next
-- form's price. Mutations are kept. XP is kept when a critter is stolen.
GameConfig.Evolution = {
	CostFraction = 0.5, -- evolving costs 50% of the evolved form's price
	TimeByRarity = {
		Uncommon = 90,
		Rare = 180,
		Epic = 420,
		Legendary = 900,
		Mythic = 1_800,
		Secret = 3_600,
	},
	FastEvolveMultiplier = 2, -- XP speed with the "Fast Evolution" game pass
	AnnounceFromRarity = "Epic", -- server-wide message when evolving into this rarity or better
}

GameConfig.Lock = {
	Duration = 60, -- seconds at base level 1 (+ BaseUpgrade.LockBonusPerLevel per level)
}

-- Base upgrades (the "Upgrade Base" station near the gate and the HUD button). The level is saved,
-- kept through rebirths, and every level boosts the income of every critter of the base, makes
-- the base lock last longer and changes the look of the castle (tiers below, seen by everybody).
GameConfig.BaseUpgrade = {
	MaxLevel = 10,
	-- Costs[n] = price to go from level n to level n + 1.
	Costs = { 1_000, 5_000, 25_000, 100_000, 400_000, 1_500_000, 6_000_000, 25_000_000, 100_000_000 },
	IncomeBonusPerLevel = 0.1, -- +10% income per level above 1 (level 10 = x1.9)
	LockBonusPerLevel = 5, -- +5 s of base lock per level above 1 (level 10 = 105 s)
	Cooldown = 0.5, -- seconds between two upgrade requests of a player
	AnnounceFromLevel = 10, -- server-wide message when a base reaches this level
	-- Looks of the castle. A tier starts at FromLevel and lasts until the next one.
	Tiers = {
		{ FromLevel = 1, Name = "Stone Keep", Description = "Wood and stone", Color = Color3.fromRGB(205, 185, 160) },
		{ FromLevel = 4, Name = "Royal Castle", Description = "Polished stone, banners, bigger flags", Color = Color3.fromRGB(110, 175, 255) },
		{ FromLevel = 7, Name = "Crystal Citadel", Description = "Glowing crystals and magic walls", Color = Color3.fromRGB(150, 235, 255) },
		{ FromLevel = 10, Name = "Golden Palace", Description = "Gold everywhere and a royal crown", Color = Color3.fromRGB(255, 205, 70) },
	},
}

GameConfig.Slap = {
	Cooldown = 0.9,
	Range = 9,
	Knockback = 55,
	MegaRange = 13,
	MegaKnockback = 95,
	StunTime = 0.9,
}

GameConfig.ServerLuck = {
	Multiplier = 2,
	MaxDuration = 2 * 3600,
}

GameConfig.Home = {
	TeleportCooldown = 10,
}

GameConfig.Daily = {
	Cooldown = 20 * 3600,
	StreakResetAfter = 48 * 3600,
	-- Cash = max(Cash, IncomeSeconds * income per second). Rarity grants a random critter.
	Rewards = {
		{ Cash = 250, IncomeSeconds = 300 },
		{ Cash = 500, IncomeSeconds = 450 },
		{ Cash = 1_000, IncomeSeconds = 600 },
		{ Cash = 2_000, IncomeSeconds = 900 },
		{ Cash = 4_000, IncomeSeconds = 1_200 },
		{ Cash = 8_000, IncomeSeconds = 1_500 },
		{ Cash = 15_000, IncomeSeconds = 1_800, Rarity = "Epic" },
	},
}

-- Promo codes (case-insensitive). Each player can redeem a code once.
-- Optional field: ExpiresAt = os.time() timestamp.
GameConfig.Codes = {
	RELEASE = { Cash = 1_000 },
	CRITTERS = { Unit = "Coinpurr" },
	LUCKY = { Cash = 5_000 },
}

GameConfig.Sounds = {
	Notify = "rbxasset://sounds/electronicpingshort.wav",
	Slap = "rbxasset://sounds/swordslash.wav",
}

GameConfig.Debug = {
	-- Studio only: use an in-memory store instead of DataStores.
	UseMockDataInStudio = false,
	-- Studio only: pretend the tester owns every game pass.
	GrantAllPassesInStudio = false,
	-- Studio only: overrides the cash of every player when they join (nil = disabled).
	StudioStartingCash = nil :: number?,
}

return GameConfig
