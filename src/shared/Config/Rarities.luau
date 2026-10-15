--[[
	Rarities
	Spawn weights on the conveyor, colours and Robux "instant buy" products.
	Luck (server luck boost) multiplies the weight of every rarity with LuckAffected = true.
	Rarities with a timer in GameConfig.RareSpawns (Legendary, Mythic, Secret) are never rolled:
	ConveyorService spawns them on a public server-wide timer instead. Their Weight is only used
	if their timer is removed from GameConfig.RareSpawns.Timers.
]]

local GameConfig = require(script.Parent.GameConfig)

local Rarities = {}

Rarities.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

Rarities.Info = {
	Common = {
		Color = Color3.fromRGB(200, 200, 200),
		Weight = 50,
		Scale = 0.9,
	},
	Uncommon = {
		Color = Color3.fromRGB(90, 220, 90),
		Weight = 28,
		Scale = 1,
	},
	Rare = {
		Color = Color3.fromRGB(70, 160, 255),
		Weight = 14,
		Scale = 1.1,
		LuckAffected = true,
	},
	Epic = {
		Color = Color3.fromRGB(180, 90, 255),
		Weight = 8,
		Scale = 1.2,
		LuckAffected = true,
		Glow = true,
		RobuxProduct = "UnitEpic",
	},
	Legendary = {
		Color = Color3.fromRGB(255, 190, 40),
		Weight = 3, -- unused while timed (GameConfig.RareSpawns)
		Scale = 1.35,
		LuckAffected = true,
		Glow = true,
		Sparkles = true,
		Announce = true,
		RobuxProduct = "UnitLegendary",
	},
	Mythic = {
		Color = Color3.fromRGB(255, 70, 110),
		Weight = 0.9, -- unused while timed (GameConfig.RareSpawns)
		Scale = 1.5,
		LuckAffected = true,
		Glow = true,
		Sparkles = true,
		Announce = true,
		RobuxProduct = "UnitMythic",
	},
	Secret = {
		Color = Color3.fromRGB(30, 255, 200),
		Weight = 0.15, -- unused while timed (GameConfig.RareSpawns)
		Scale = 1.65,
		LuckAffected = true,
		Glow = true,
		Sparkles = true,
		Announce = true,
		RobuxProduct = "UnitSecret",
	},
}

function Rarities.GetIndex(rarity: string): number
	return table.find(Rarities.Order, rarity) or 1
end

function Rarities.IsAtLeast(rarity: string, minimum: string): boolean
	return Rarities.GetIndex(rarity) >= Rarities.GetIndex(minimum)
end

-- True when this rarity spawns on a server-wide timer instead of the random roll.
function Rarities.IsTimed(rarity: string): boolean
	return GameConfig.RareSpawns.Timers[rarity] ~= nil
end

-- Random rarity of a conveyor critter (timed rarities excluded).
function Rarities.Roll(luck: number): string
	local total = 0
	local weights = {}
	for index, name in Rarities.Order do
		local info = Rarities.Info[name]
		local weight = if Rarities.IsTimed(name) then 0 else info.Weight
		if info.LuckAffected then
			weight *= luck
		end
		weights[index] = weight
		total += weight
	end

	local roll = math.random() * total
	for index, name in Rarities.Order do
		if weights[index] > 0 then
			roll -= weights[index]
			if roll <= 0 then
				return name
			end
		end
	end
	return Rarities.Order[1]
end

return Rarities
