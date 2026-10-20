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
	EvolvesTo: string?, -- next form (see GameConfig.Evolution)
	Weight: number?,
}

local rgb = Color3.fromRGB

-- Sorted by price. Evolution lines: Sproutle > Bloomtoad > Floradon, Embit > Emberclaw > Blazewing,
-- Puddlet > Shellwave > Cannontoise, Ghastling > Hauntling > Gloomer, Drakelet > Serpendrake > Puffdrake...
local List: { UnitDef } = {
	-- Common
	{
		Name = "Flopfish",
		Rarity = "Common",
		Price = 20,
		Income = 1,
		Body = rgb(240, 100, 60),
		Accent = rgb(250, 240, 220),
		Extra = rgb(255, 215, 90),
		EvolvesTo = "Tidewyrm",
	},
	{
		Name = "Pebbit",
		Rarity = "Common",
		Price = 30,
		Income = 1,
		Body = rgb(150, 140, 130),
		Accent = rgb(115, 105, 95),
		EvolvesTo = "Bouldron",
	},
	{
		Name = "Sproutle",
		Rarity = "Common",
		Price = 45,
		Income = 2,
		Body = rgb(110, 200, 170),
		Accent = rgb(70, 165, 90),
		Extra = rgb(50, 125, 75),
		EvolvesTo = "Bloomtoad",
	},
	{
		Name = "Embit",
		Rarity = "Common",
		Price = 60,
		Income = 2,
		Body = rgb(255, 145, 60),
		Belly = rgb(255, 225, 150),
		EvolvesTo = "Emberclaw",
	},
	{
		Name = "Puddlet",
		Rarity = "Common",
		Price = 85,
		Income = 3,
		Body = rgb(120, 195, 240),
		Accent = rgb(175, 110, 60),
		Belly = rgb(245, 225, 160),
		Extra = rgb(120, 80, 45),
		EvolvesTo = "Shellwave",
	},
	{
		Name = "Ghastling",
		Rarity = "Common",
		Price = 110,
		Income = 4,
		Body = rgb(45, 35, 65),
		Accent = rgb(170, 100, 230),
		EvolvesTo = "Hauntling",
	},
	{
		Name = "Drakelet",
		Rarity = "Common",
		Price = 150,
		Income = 5,
		Body = rgb(110, 150, 240),
		Belly = rgb(250, 245, 230),
		Accent = rgb(240, 240, 255),
		EvolvesTo = "Serpendrake",
	},
	{ Name = "Puffloon", Rarity = "Common", Price = 220, Income = 7, Body = rgb(255, 180, 205), EvolvesTo = "Puffluxe" },

	-- Uncommon
	{
		Name = "Zappip",
		Rarity = "Uncommon",
		Price = 400,
		Income = 11,
		Body = rgb(255, 215, 50),
		Accent = rgb(30, 28, 35),
		Extra = rgb(150, 90, 40),
		EvolvesTo = "Voltmouse",
	},
	{
		Name = "Fennix",
		Rarity = "Uncommon",
		Price = 480,
		Income = 12,
		Body = rgb(185, 125, 65),
		Belly = rgb(250, 235, 195),
		Accent = rgb(110, 70, 40),
		EvolvesTo = "Moonfox",
	},
	{
		Name = "Quackle",
		Rarity = "Uncommon",
		Price = 580,
		Income = 14,
		Body = rgb(255, 215, 80),
		Belly = rgb(250, 230, 170),
		EvolvesTo = "Mystduck",
	},
	{
		Name = "Coinpurr",
		Rarity = "Uncommon",
		Price = 690,
		Income = 17,
		Body = rgb(245, 235, 205),
		Accent = rgb(130, 85, 50),
		EvolvesTo = "Regalynx",
	},
	{
		Name = "Growlpup",
		Rarity = "Uncommon",
		Price = 830,
		Income = 20,
		Body = rgb(245, 145, 60),
		Belly = rgb(250, 235, 195),
		Extra = rgb(30, 30, 35),
		EvolvesTo = "Blazehound",
	},
	{
		Name = "Pupjack",
		Rarity = "Uncommon",
		Price = 1_000,
		Income = 23,
		Body = rgb(80, 140, 230),
		Accent = rgb(30, 30, 45),
		Belly = rgb(240, 215, 140),
		EvolvesTo = "Aurajack",
	},
	{
		Name = "Munchling",
		Rarity = "Uncommon",
		Price = 1_200,
		Income = 27,
		Body = rgb(40, 80, 110),
		Belly = rgb(240, 225, 190),
		EvolvesTo = "Snoozor",
	},
	{
		Name = "Bloomtoad",
		Rarity = "Uncommon",
		Price = 1_400,
		Income = 31,
		Body = rgb(100, 190, 170),
		Accent = rgb(240, 110, 160),
		Extra = rgb(60, 140, 80),
		EvolvesTo = "Floradon",
	},
	{
		Name = "Emberclaw",
		Rarity = "Uncommon",
		Price = 1_700,
		Income = 36,
		Body = rgb(225, 85, 60),
		Belly = rgb(250, 220, 150),
		EvolvesTo = "Blazewing",
	},
	{
		Name = "Shellwave",
		Rarity = "Uncommon",
		Price = 2_100,
		Income = 44,
		Body = rgb(130, 170, 240),
		Accent = rgb(170, 110, 60),
		Belly = rgb(245, 225, 160),
		Extra = rgb(240, 240, 255),
		EvolvesTo = "Cannontoise",
	},
	{
		Name = "Hauntling",
		Rarity = "Uncommon",
		Price = 2_500,
		Income = 51,
		Body = rgb(120, 80, 180),
		Accent = rgb(90, 60, 140),
		EvolvesTo = "Gloomer",
	},
	{ Name = "Puffluxe", Rarity = "Uncommon", Price = 3_000, Income = 60, Body = rgb(255, 190, 210), Belly = rgb(255, 240, 245) },

	-- Rare
	{
		Name = "Lagoonie",
		Rarity = "Rare",
		Price = 5_000,
		Income = 91,
		Body = rgb(90, 165, 235),
		Accent = rgb(200, 200, 210),
		Belly = rgb(240, 230, 190),
		Extra = rgb(150, 150, 165),
	},
	{
		Name = "Emberfox",
		Rarity = "Rare",
		Price = 6_000,
		Income = 110,
		Body = rgb(215, 95, 55),
		Accent = rgb(250, 165, 80),
		Belly = rgb(250, 215, 170),
		Extra = rgb(120, 60, 40),
		EvolvesTo = "Novafox",
	},
	{
		Name = "Bouldron",
		Rarity = "Rare",
		Price = 7_200,
		Income = 120,
		Body = rgb(150, 135, 115),
		Accent = rgb(100, 95, 90),
		Belly = rgb(200, 180, 140),
	},
	{
		Name = "Snoozor",
		Rarity = "Rare",
		Price = 8_600,
		Income = 150,
		Body = rgb(55, 105, 130),
		Belly = rgb(240, 225, 190),
		Extra = rgb(200, 170, 120),
	},
	{
		Name = "Voltmouse",
		Rarity = "Rare",
		Price = 10_000,
		Income = 170,
		Body = rgb(240, 150, 50),
		Belly = rgb(255, 235, 190),
		Accent = rgb(60, 40, 20),
		Extra = rgb(255, 215, 60),
	},
	{
		Name = "Mystduck",
		Rarity = "Rare",
		Price = 12_000,
		Income = 200,
		Body = rgb(70, 140, 220),
		Accent = rgb(230, 60, 60),
		Belly = rgb(250, 230, 150),
	},
	{
		Name = "Regalynx",
		Rarity = "Rare",
		Price = 15_000,
		Income = 240,
		Body = rgb(245, 230, 190),
		Accent = rgb(220, 40, 60),
		Extra = rgb(60, 45, 40),
	},
	{
		Name = "Serpendrake",
		Rarity = "Rare",
		Price = 18_000,
		Income = 280,
		Body = rgb(90, 140, 240),
		Belly = rgb(250, 250, 255),
		Accent = rgb(120, 200, 255),
		EvolvesTo = "Puffdrake",
	},
	{
		Name = "Floradon",
		Rarity = "Rare",
		Price = 21_000,
		Income = 320,
		Body = rgb(90, 170, 150),
		Accent = rgb(240, 90, 110),
		Extra = rgb(60, 130, 70),
		Belly = rgb(250, 220, 110),
	},
	{
		Name = "Cannontoise",
		Rarity = "Rare",
		Price = 25_000,
		Income = 370,
		Body = rgb(80, 130, 210),
		Accent = rgb(160, 100, 50),
		Belly = rgb(240, 220, 150),
		Extra = rgb(170, 170, 180),
	},
	{ Name = "Gloomer", Rarity = "Rare", Price = 30_000, Income = 440, Body = rgb(105, 70, 160) },

	-- Epic
	{
		Name = "Aurajack",
		Rarity = "Epic",
		Price = 50_000,
		Income = 690,
		Body = rgb(70, 125, 220),
		Accent = rgb(40, 40, 55),
		Belly = rgb(240, 215, 140),
	},
	{ Name = "Moonfox", Rarity = "Epic", Price = 72_000, Income = 960, Body = rgb(40, 40, 55), Accent = rgb(255, 215, 80) },
	{
		Name = "Novafox",
		Rarity = "Epic",
		Price = 100_000,
		Income = 1_300,
		Body = rgb(250, 235, 180),
		Accent = rgb(255, 170, 90),
		Extra = rgb(230, 90, 60),
	},
	{
		Name = "Tidewyrm",
		Rarity = "Epic",
		Price = 150_000,
		Income = 1_900,
		Body = rgb(60, 120, 220),
		Belly = rgb(250, 235, 170),
		Accent = rgb(240, 240, 255),
		Extra = rgb(220, 60, 60),
	},
	{
		Name = "Puffdrake",
		Rarity = "Epic",
		Price = 210_000,
		Income = 2_500,
		Body = rgb(250, 170, 70),
		Accent = rgb(90, 185, 160),
		Belly = rgb(250, 230, 170),
		Extra = rgb(220, 150, 60),
	},
	{
		Name = "Blazewing",
		Rarity = "Epic",
		Price = 300_000,
		Income = 3_500,
		Body = rgb(240, 130, 50),
		Accent = rgb(60, 140, 150),
		Belly = rgb(250, 220, 150),
	},

	-- Legendary
	{
		Name = "Frostwing",
		Rarity = "Legendary",
		Price = 600_000,
		Income = 6_500,
		Body = rgb(120, 185, 255),
		Accent = rgb(200, 230, 255),
		Belly = rgb(220, 240, 255),
	},
	{
		Name = "Voltwing",
		Rarity = "Legendary",
		Price = 900_000,
		Income = 9_300,
		Body = rgb(255, 215, 50),
		Accent = rgb(40, 35, 40),
		Extra = rgb(255, 150, 40),
	},
	{
		Name = "Pyrowing",
		Rarity = "Legendary",
		Price = 1_300_000,
		Income = 13_000,
		Body = rgb(255, 180, 60),
		Accent = rgb(255, 90, 30),
		Extra = rgb(200, 110, 40),
	},
	{ Name = "Blazehound", Rarity = "Legendary", Price = 2_000_000, Income = 19_000, Body = rgb(240, 135, 55), Belly = rgb(250, 235, 195) },
	{ Name = "Psyclone", Rarity = "Legendary", Price = 3_000_000, Income = 27_000, Body = rgb(225, 215, 235), Accent = rgb(150, 90, 195) },

	-- Mythic
	{
		Name = "Wishstar",
		Rarity = "Mythic",
		Price = 8_000_000,
		Income = 66_000,
		Body = rgb(250, 250, 245),
		Accent = rgb(255, 215, 60),
		Extra = rgb(100, 190, 240),
	},
	{ Name = "Pinkling", Rarity = "Mythic", Price = 15_000_000, Income = 120_000, Body = rgb(255, 175, 210) },
	{ Name = "Skyserpent", Rarity = "Mythic", Price = 27_000_000, Income = 200_000, Body = rgb(55, 155, 90), Accent = rgb(255, 215, 60) },
	{
		Name = "Abysswing",
		Rarity = "Mythic",
		Price = 50_000_000,
		Income = 340_000,
		Body = rgb(235, 238, 250),
		Accent = rgb(60, 90, 175),
		Belly = rgb(200, 210, 235),
	},

	-- Secret
	{
		Name = "Glitchno",
		Rarity = "Secret",
		Price = 200_000_000,
		Income = 1_200_000,
		Body = rgb(90, 80, 200),
		Accent = rgb(255, 60, 140),
		Belly = rgb(230, 230, 240),
		Extra = rgb(40, 220, 180),
	},
	{
		Name = "Primordeus",
		Rarity = "Secret",
		Price = 1_000_000_000,
		Income = 5_000_000,
		Body = rgb(245, 245, 240),
		Accent = rgb(255, 200, 60),
		Extra = rgb(150, 150, 160),
	},
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

for _, def in List do
	if def.EvolvesTo then
		local target = ByName[def.EvolvesTo]
		assert(target, `{def.Name} evolves into unknown critter {def.EvolvesTo}`)
		assert(target.Price > def.Price, `{def.Name} must evolve into a more valuable critter`)
	end
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

-- Form that evolves into `name` (nil for base forms).
function Units.GetPreviousForm(name: string): string?
	for _, def in List do
		if def.EvolvesTo == name then
			return def.Name
		end
	end
	return nil
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
