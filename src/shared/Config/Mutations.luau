--[[
	Mutations
	A critter can spawn with a mutation that multiplies its price and income.
	Luck multiplies the chances.
]]

local Mutations = {}

-- Rolled from rarest to most common.
Mutations.RollOrder = { "Galaxy", "Rainbow", "Diamond", "Gold" }

Mutations.Info = {
	None = {
		Multiplier = 1,
		Chance = 0,
		TextColor = Color3.fromRGB(255, 255, 255),
	},
	Gold = {
		Multiplier = 2,
		Chance = 0.06,
		Color = Color3.fromRGB(255, 200, 40),
		Material = Enum.Material.Foil,
		TextColor = Color3.fromRGB(255, 210, 60),
	},
	Diamond = {
		Multiplier = 3,
		Chance = 0.02,
		Color = Color3.fromRGB(150, 235, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.1,
		TextColor = Color3.fromRGB(150, 235, 255),
	},
	Rainbow = {
		Multiplier = 5,
		Chance = 0.006,
		Color = Color3.fromRGB(255, 80, 80),
		Material = Enum.Material.SmoothPlastic,
		Animated = true, -- Colours are cycled on the client.
		TextColor = Color3.fromRGB(255, 120, 220),
	},
	Galaxy = {
		Multiplier = 10,
		Chance = 0.0015,
		Color = Color3.fromRGB(70, 30, 130),
		Material = Enum.Material.Glass,
		Stars = true,
		TextColor = Color3.fromRGB(190, 140, 255),
	},
}

function Mutations.Get(name: string?)
	return Mutations.Info[name or "None"] or Mutations.Info.None
end

function Mutations.Roll(luck: number): string
	for _, name in Mutations.RollOrder do
		local chance = math.min(0.5, Mutations.Info[name].Chance * luck)
		if math.random() < chance then
			return name
		end
	end
	return "None"
end

return Mutations
