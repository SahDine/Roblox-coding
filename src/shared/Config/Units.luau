--[[
	Units (critters)
	Price = cash price on the conveyor, Income = cash per second once in your base.
	Colours: Body, Accent, Belly, Extra (Belly/Accent/Extra are derived from Body if omitted).
	The 3D model of each critter is sculpted in ServerScriptService/Server/Modules/CritterDesigns
	(a critter without a design uses the "Generic" one).

	To use your own 3D model for a critter, see README.md ("Modèles personnalisés").
]]

export type UnitDef = {
	Name: string,
	Rarity: string,
	Price: number,
	Income: number,
	Body: Color3,
	Accent: Color3?,
	Belly: Color3?,
	Extra: Color3?,
	Weight: number?,
}

local rgb = Color3.fromRGB

local List: { UnitDef } = {
	-- Common
	{ Name = "Sproutle", Rarity = "Common", Price = 25, Income = 1, Body = rgb(110, 200, 170), Accent = rgb(70, 165, 90), Extra = rgb(50, 125, 75) },
	{ Name = "Embit", Rarity = "Common", Price = 60, Income = 2, Body = rgb(255, 145, 60), Belly = rgb(255, 225, 150) },
	{ Name = "Puddlet", Rarity = "Common", Price = 120, Income = 4, Body = rgb(120, 195, 240), Accent = rgb(175, 110, 60), Belly = rgb(245, 225, 160), Extra = rgb(120, 80, 45) },
	{ Name = "Puffloon", Rarity = "Common", Price = 200, Income = 6, Body = rgb(255, 180, 205) },

	-- Uncommon
	{ Name = "Zappip", Rarity = "Uncommon", Price = 500, Income = 12, Body = rgb(255, 215, 50), Accent = rgb(30, 28, 35), Extra = rgb(150, 90, 40) },
	{ Name = "Fennix", Rarity = "Uncommon", Price = 900, Income = 20, Body = rgb(185, 125, 65), Belly = rgb(250, 235, 195), Accent = rgb(110, 70, 40) },
	{ Name = "Quackle", Rarity = "Uncommon", Price = 1_500, Income = 32, Body = rgb(255, 215, 80), Belly = rgb(250, 230, 170) },
	{ Name = "Coinpurr", Rarity = "Uncommon", Price = 2_500, Income = 50, Body = rgb(245, 235, 205), Accent = rgb(130, 85, 50) },

	-- Rare
	{ Name = "Gloomer", Rarity = "Rare", Price = 5_000, Income = 90, Body = rgb(105, 70, 160) },
	{ Name = "Snoozor", Rarity = "Rare", Price = 9_000, Income = 150, Body = rgb(55, 105, 130), Belly = rgb(240, 225, 190), Extra = rgb(200, 170, 120) },
	{ Name = "Emberfox", Rarity = "Rare", Price = 15_000, Income = 240, Body = rgb(215, 95, 55), Accent = rgb(250, 165, 80), Belly = rgb(250, 215, 170), Extra = rgb(120, 60, 40) },
	{ Name = "Lagoonie", Rarity = "Rare", Price = 25_000, Income = 380, Body = rgb(90, 165, 235), Accent = rgb(200, 200, 210), Belly = rgb(240, 230, 190), Extra = rgb(150, 150, 165) },

	-- Epic
	{ Name = "Aurajack", Rarity = "Epic", Price = 50_000, Income = 700, Body = rgb(70, 125, 220), Accent = rgb(40, 40, 55), Belly = rgb(240, 215, 140) },
	{ Name = "Puffdrake", Rarity = "Epic", Price = 90_000, Income = 1_200, Body = rgb(250, 170, 70), Accent = rgb(90, 185, 160), Belly = rgb(250, 230, 170), Extra = rgb(220, 150, 60) },
	{ Name = "Moonfox", Rarity = "Epic", Price = 160_000, Income = 2_000, Body = rgb(40, 40, 55), Accent = rgb(255, 215, 80) },
	{ Name = "Blazewing", Rarity = "Epic", Price = 280_000, Income = 3_300, Body = rgb(240, 130, 50), Accent = rgb(60, 140, 150), Belly = rgb(250, 220, 150) },

	-- Legendary
	{ Name = "Frostwing", Rarity = "Legendary", Price = 600_000, Income = 6_500, Body = rgb(120, 185, 255), Accent = rgb(200, 230, 255), Belly = rgb(220, 240, 255) },
	{ Name = "Blazehound", Rarity = "Legendary", Price = 1_200_000, Income = 12_000, Body = rgb(240, 135, 55), Belly = rgb(250, 235, 195) },
	{ Name = "Psyclone", Rarity = "Legendary", Price = 2_500_000, Income = 23_000, Body = rgb(225, 215, 235), Accent = rgb(150, 90, 195) },

	-- Mythic
	{ Name = "Pinkling", Rarity = "Mythic", Price = 8_000_000, Income = 65_000, Body = rgb(255, 175, 210) },
	{ Name = "Skyserpent", Rarity = "Mythic", Price = 20_000_000, Income = 150_000, Body = rgb(55, 155, 90), Accent = rgb(255, 215, 60) },
	{ Name = "Abysswing", Rarity = "Mythic", Price = 50_000_000, Income = 350_000, Body = rgb(235, 238, 250), Accent = rgb(60, 90, 175), Belly = rgb(200, 210, 235) },

	-- Secret
	{ Name = "Glitchno", Rarity = "Secret", Price = 200_000_000, Income = 1_200_000, Body = rgb(90, 80, 200), Accent = rgb(255, 60, 140), Belly = rgb(230, 230, 240), Extra = rgb(40, 220, 180) },
	{ Name = "Primordeus", Rarity = "Secret", Price = 1_000_000_000, Income = 5_000_000, Body = rgb(245, 245, 240), Accent = rgb(255, 200, 60), Extra = rgb(150, 150, 160) },
}

-- Critters renamed in an update: old saves are converted automatically.
local Aliases: { [string]: string } = {
	["Pebble Pup"] = "Sproutle",
	["Mossy Toad"] = "Embit",
	["Sock Goblin"] = "Puddlet",
	["Bubble Snail"] = "Puffloon",
	["Toast Bunny"] = "Zappip",
	["Cactus Kitty"] = "Fennix",
	["Noodle Duck"] = "Quackle",
	["Disco Frog"] = "Coinpurr",
	["Pickle Knight"] = "Gloomer",
	["Waffle Bear"] = "Snoozor",
	["Cloud Sheep"] = "Emberfox",
	["Taco Dragon"] = "Lagoonie",
	["Ninja Penguin"] = "Aurajack",
	["Lava Lizard"] = "Puffdrake",
	["Cyber Corgi"] = "Moonfox",
	["Ghost Pepper"] = "Blazewing",
	["Thunder Yak"] = "Frostwing",
	["Crystal Fox"] = "Blazehound",
	["Golden Goose"] = "Psyclone",
	["Cosmic Whale"] = "Pinkling",
	["Phoenix Chick"] = "Skyserpent",
	["Void Kraken"] = "Abysswing",
	["Glitch Cat"] = "Glitchno",
	["Omega Blob"] = "Primordeus",
}

local ByName: { [string]: UnitDef } = {}
local ByRarity: { [string]: { UnitDef } } = {}

for _, def in List do
	assert(ByName[def.Name] == nil, "Duplicate unit name: " .. def.Name)
	ByName[def.Name] = def
	ByRarity[def.Rarity] = ByRarity[def.Rarity] or {}
	table.insert(ByRarity[def.Rarity], def)
end

-- Inside a rarity, cheaper critters show up more often (4, 3, 2, 1...).
for _, defs in ByRarity do
	for position, def in defs do
		def.Weight = def.Weight or (#defs - position + 1)
	end
end

local Units = {
	List = List,
	ByName = ByName,
	ByRarity = ByRarity,
	Aliases = Aliases,
}

-- Current name of a critter (handles renamed critters from old saves).
function Units.Resolve(name: string): string
	return Aliases[name] or name
end

function Units.PickFromRarity(rarity: string): UnitDef?
	local defs = ByRarity[rarity]
	if not defs or #defs == 0 then
		return nil
	end
	local total = 0
	for _, def in defs do
		total += def.Weight or 1
	end
	local roll = math.random() * total
	for _, def in defs do
		roll -= def.Weight or 1
		if roll <= 0 then
			return def
		end
	end
	return defs[#defs]
end

-- Chance of each critter inside a rarity (shown in the store: paid random items must disclose odds).
function Units.GetOdds(rarity: string): { { Name: string, Chance: number } }
	local defs = ByRarity[rarity] or {}
	local total = 0
	for _, def in defs do
		total += def.Weight or 1
	end
	local odds = {}
	for _, def in defs do
		table.insert(odds, { Name = def.Name, Chance = (def.Weight or 1) / total })
	end
	return odds
end

return Units
