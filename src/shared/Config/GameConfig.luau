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

GameConfig.Lock = {
	Duration = 60,
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
