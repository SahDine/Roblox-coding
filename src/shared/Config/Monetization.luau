--[[
	Monetization
	Paste the IDs of the game passes and developer products you create in the
	Creator Dashboard (see README.md, section "Monétisation").

	An Id of 0 means "not configured": the store shows "Not set up", Robux
	prompts on the conveyor are hidden and nothing can be bought.

	DisplayPrice is only a fallback label; the real Robux price is read from
	Roblox (MarketplaceService:GetProductInfo) so it is always accurate.
	Badge (optional) shows a ribbon on the store card ("POPULAR", "BEST VALUE"...).
]]

local Monetization = {}

Monetization.GamePasses = {
	VIP = {
		Id = 0,
		Name = "VIP",
		Description = "2x cash forever + VIP chat tag",
		Icon = "👑",
		DisplayPrice = 249,
		Badge = "POPULAR",
	},
	AutoCollect = {
		Id = 0,
		Name = "Auto Collect",
		Description = "Your critters' cash goes straight to your wallet",
		Icon = "🤖",
		DisplayPrice = 149,
	},
	ExtraSlots = {
		Id = 0,
		Name = "+4 Slots",
		Description = "4 more critter slots in your base",
		Icon = "📦",
		DisplayPrice = 199,
	},
	FastSteal = {
		Id = 0,
		Name = "Fast Thief",
		Description = "Steal 2x faster and run faster while carrying",
		Icon = "⚡",
		DisplayPrice = 179,
	},
	FastEvolve = {
		Id = 0,
		Name = "Fast Evolution",
		Description = "Your critters evolve 2x faster",
		Icon = "🧬",
		DisplayPrice = 149,
	},
	MegaSlap = {
		Id = 0,
		Name = "Mega Slap",
		Description = "Golden glove: huge knockback and range",
		Icon = "🥊",
		DisplayPrice = 99,
	},
}

Monetization.GamePassOrder = { "VIP", "AutoCollect", "ExtraSlots", "FastEvolve", "FastSteal", "MegaSlap" }

-- Kind decides which store tab shows the product and which handler grants it.
Monetization.Products = {
	CashSmall = {
		Id = 0,
		Kind = "Cash",
		Name = "Pile of Cash",
		Icon = "💵",
		BaseAmount = 1_000,
		IncomeSeconds = 600, -- or 10 minutes of your income, whichever is bigger
		DisplayPrice = 25,
	},
	CashMedium = {
		Id = 0,
		Kind = "Cash",
		Name = "Bag of Cash",
		Icon = "💰",
		BaseAmount = 6_000,
		IncomeSeconds = 2_400,
		DisplayPrice = 79,
	},
	CashLarge = {
		Id = 0,
		Kind = "Cash",
		Name = "Vault of Cash",
		Icon = "🏦",
		BaseAmount = 30_000,
		IncomeSeconds = 7_200,
		DisplayPrice = 199,
		Badge = "BEST VALUE",
	},
	CashHuge = {
		Id = 0,
		Kind = "Cash",
		Name = "Cash Tsunami",
		Icon = "🌊",
		BaseAmount = 150_000,
		IncomeSeconds = 21_600,
		DisplayPrice = 449,
	},
	ServerLuck = {
		Id = 0,
		Kind = "ServerLuck",
		Name = "2x Server Luck",
		Description = "Rare critter timers 2x faster + better odds for EVERYONE (15 min, stacks)",
		Icon = "🍀",
		Duration = 900,
		DisplayPrice = 99,
		Badge = "EVERYONE WINS",
	},
	BaseLock = {
		Id = 0,
		Kind = "BaseLock",
		Name = "Super Lock",
		Description = "Locks your base for 5 minutes",
		Icon = "🔒",
		Duration = 300,
		DisplayPrice = 39,
	},
	InstantEvolve = {
		Id = 0,
		Kind = "EvolveReady", -- bought from the "Ready now" prompt on one of your critters
		Name = "Instant Evolution",
		Description = "Your critter is instantly ready to evolve",
		Icon = "🧬",
		DisplayPrice = 39,
	},
	UnitEpic = {
		Id = 0,
		Kind = "Unit",
		Rarity = "Epic",
		Name = "Random Epic",
		Icon = "🟣",
		DisplayPrice = 49,
	},
	UnitLegendary = {
		Id = 0,
		Kind = "Unit",
		Rarity = "Legendary",
		Name = "Random Legendary",
		Icon = "🟡",
		DisplayPrice = 99,
	},
	UnitMythic = {
		Id = 0,
		Kind = "Unit",
		Rarity = "Mythic",
		Name = "Random Mythic",
		Icon = "🔴",
		DisplayPrice = 249,
	},
	UnitSecret = {
		Id = 0,
		Kind = "Unit",
		Rarity = "Secret",
		Name = "Random Secret",
		Icon = "💎",
		DisplayPrice = 499,
	},
}

Monetization.ProductOrder = {
	"CashSmall",
	"CashMedium",
	"CashLarge",
	"CashHuge",
	"ServerLuck",
	"BaseLock",
	"InstantEvolve",
	"UnitEpic",
	"UnitLegendary",
	"UnitMythic",
	"UnitSecret",
}

function Monetization.GetProductKeyById(productId: number): string?
	for key, info in Monetization.Products do
		if info.Id == productId and info.Id ~= 0 then
			return key
		end
	end
	return nil
end

function Monetization.GetPassKeyById(passId: number): string?
	for key, info in Monetization.GamePasses do
		if info.Id == passId and info.Id ~= 0 then
			return key
		end
	end
	return nil
end

return Monetization
