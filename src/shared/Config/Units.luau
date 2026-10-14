--[[
	Units (critters)
	Price = cash price on the conveyor, Income = cash per second once in your base.
	Features are the procedural body parts used by UnitModelBuilder:
	Ears, Horns, Antenna, Spikes, Wings, Crown, TopHat, Halo, Tail, Shell, Beak, Fin.

	To use your own 3D model for a critter, see README.md ("Modèles personnalisés").
]]

export type UnitDef = {
	Name: string,
	Rarity: string,
	Price: number,
	Income: number,
	Body: Color3,
	Accent: Color3,
	Features: { string },
	Weight: number?,
}

local List: { UnitDef } = {
	-- Common
	{ Name = "Pebble Pup", Rarity = "Common", Price = 25, Income = 1, Body = Color3.fromRGB(163, 162, 165), Accent = Color3.fromRGB(99, 95, 98), Features = { "Ears" } },
	{ Name = "Mossy Toad", Rarity = "Common", Price = 60, Income = 2, Body = Color3.fromRGB(116, 166, 84), Accent = Color3.fromRGB(75, 110, 55), Features = {} },
	{ Name = "Sock Goblin", Rarity = "Common", Price = 120, Income = 4, Body = Color3.fromRGB(235, 235, 235), Accent = Color3.fromRGB(220, 60, 60), Features = { "Ears", "Tail" } },
	{ Name = "Bubble Snail", Rarity = "Common", Price = 200, Income = 6, Body = Color3.fromRGB(255, 190, 210), Accent = Color3.fromRGB(170, 120, 80), Features = { "Antenna", "Shell" } },

	-- Uncommon
	{ Name = "Toast Bunny", Rarity = "Uncommon", Price = 500, Income = 12, Body = Color3.fromRGB(222, 170, 100), Accent = Color3.fromRGB(140, 90, 40), Features = { "Ears" } },
	{ Name = "Cactus Kitty", Rarity = "Uncommon", Price = 900, Income = 20, Body = Color3.fromRGB(90, 170, 90), Accent = Color3.fromRGB(250, 120, 180), Features = { "Ears", "Spikes" } },
	{ Name = "Noodle Duck", Rarity = "Uncommon", Price = 1_500, Income = 32, Body = Color3.fromRGB(255, 220, 90), Accent = Color3.fromRGB(255, 140, 40), Features = { "Beak", "Tail" } },
	{ Name = "Disco Frog", Rarity = "Uncommon", Price = 2_500, Income = 50, Body = Color3.fromRGB(60, 220, 200), Accent = Color3.fromRGB(255, 80, 200), Features = { "Antenna" } },

	-- Rare
	{ Name = "Pickle Knight", Rarity = "Rare", Price = 5_000, Income = 90, Body = Color3.fromRGB(110, 160, 60), Accent = Color3.fromRGB(190, 190, 200), Features = { "Horns" } },
	{ Name = "Waffle Bear", Rarity = "Rare", Price = 9_000, Income = 150, Body = Color3.fromRGB(205, 150, 80), Accent = Color3.fromRGB(120, 75, 35), Features = { "Ears", "Tail" } },
	{ Name = "Cloud Sheep", Rarity = "Rare", Price = 15_000, Income = 240, Body = Color3.fromRGB(245, 245, 255), Accent = Color3.fromRGB(150, 170, 220), Features = { "Wings" } },
	{ Name = "Taco Dragon", Rarity = "Rare", Price = 25_000, Income = 380, Body = Color3.fromRGB(250, 190, 70), Accent = Color3.fromRGB(220, 60, 50), Features = { "Horns", "Spikes", "Tail" } },

	-- Epic
	{ Name = "Ninja Penguin", Rarity = "Epic", Price = 50_000, Income = 700, Body = Color3.fromRGB(45, 45, 55), Accent = Color3.fromRGB(230, 50, 60), Features = { "Beak", "Wings" } },
	{ Name = "Lava Lizard", Rarity = "Epic", Price = 90_000, Income = 1_200, Body = Color3.fromRGB(230, 90, 30), Accent = Color3.fromRGB(255, 200, 40), Features = { "Spikes", "Tail" } },
	{ Name = "Cyber Corgi", Rarity = "Epic", Price = 160_000, Income = 2_000, Body = Color3.fromRGB(240, 160, 70), Accent = Color3.fromRGB(0, 255, 255), Features = { "Ears", "Antenna" } },
	{ Name = "Ghost Pepper", Rarity = "Epic", Price = 280_000, Income = 3_300, Body = Color3.fromRGB(200, 30, 40), Accent = Color3.fromRGB(60, 150, 60), Features = { "Fin" } },

	-- Legendary
	{ Name = "Thunder Yak", Rarity = "Legendary", Price = 600_000, Income = 6_500, Body = Color3.fromRGB(90, 80, 140), Accent = Color3.fromRGB(255, 230, 60), Features = { "Horns", "Antenna" } },
	{ Name = "Crystal Fox", Rarity = "Legendary", Price = 1_200_000, Income = 12_000, Body = Color3.fromRGB(120, 220, 255), Accent = Color3.fromRGB(255, 255, 255), Features = { "Ears", "Tail" } },
	{ Name = "Golden Goose", Rarity = "Legendary", Price = 2_500_000, Income = 23_000, Body = Color3.fromRGB(255, 215, 70), Accent = Color3.fromRGB(255, 150, 40), Features = { "Beak", "Wings", "Crown" } },

	-- Mythic
	{ Name = "Cosmic Whale", Rarity = "Mythic", Price = 8_000_000, Income = 65_000, Body = Color3.fromRGB(40, 60, 160), Accent = Color3.fromRGB(170, 120, 255), Features = { "Fin", "Tail", "Halo" } },
	{ Name = "Phoenix Chick", Rarity = "Mythic", Price = 20_000_000, Income = 150_000, Body = Color3.fromRGB(255, 110, 40), Accent = Color3.fromRGB(255, 230, 80), Features = { "Beak", "Wings", "Crown" } },
	{ Name = "Void Kraken", Rarity = "Mythic", Price = 50_000_000, Income = 350_000, Body = Color3.fromRGB(60, 20, 90), Accent = Color3.fromRGB(190, 60, 255), Features = { "Horns", "Spikes" } },

	-- Secret
	{ Name = "Glitch Cat", Rarity = "Secret", Price = 200_000_000, Income = 1_200_000, Body = Color3.fromRGB(25, 25, 25), Accent = Color3.fromRGB(0, 255, 120), Features = { "Ears", "Tail", "Halo" } },
	{ Name = "Omega Blob", Rarity = "Secret", Price = 1_000_000_000, Income = 5_000_000, Body = Color3.fromRGB(250, 250, 250), Accent = Color3.fromRGB(255, 60, 60), Features = { "Crown", "Wings", "Halo" } },
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
}

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
