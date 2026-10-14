--[[
	Economy
	Formulas shared by the server (authoritative) and the client (display).
]]

local Config = script.Parent.Config
local GameConfig = require(Config.GameConfig)
local Units = require(Config.Units)
local Mutations = require(Config.Mutations)

local Economy = {}

function Economy.GetMutationMultiplier(mutation: string?): number
	return Mutations.Get(mutation).Multiplier
end

function Economy.GetUnitIncome(unitName: string, mutation: string?): number
	local def = Units.ByName[unitName]
	if not def then
		return 0
	end
	return def.Income * Economy.GetMutationMultiplier(mutation)
end

function Economy.GetUnitPrice(unitName: string, mutation: string?): number
	local def = Units.ByName[unitName]
	if not def then
		return 0
	end
	return def.Price * Economy.GetMutationMultiplier(mutation)
end

function Economy.GetSellValue(unitName: string, mutation: string?): number
	return math.floor(Economy.GetUnitPrice(unitName, mutation) * GameConfig.Economy.SellRefund)
end

function Economy.GetRebirthCost(rebirths: number): number
	local economy = GameConfig.Economy
	return economy.RebirthBaseCost * economy.RebirthCostGrowth ^ rebirths
end

function Economy.GetRebirthMultiplier(rebirths: number): number
	return 1 + rebirths * GameConfig.Economy.RebirthIncomeBonus
end

function Economy.GetMaxSlots(rebirths: number, hasExtraSlotsPass: boolean): number
	local slots = GameConfig.Slots
	local fromRebirths = math.min(rebirths * slots.PerRebirth, slots.MaxFromRebirths)
	return slots.Base + fromRebirths + (if hasExtraSlotsPass then slots.FromExtraSlotsPass else 0)
end

function Economy.GetCashPackAmount(product, incomePerSecond: number): number
	return math.max(product.BaseAmount or 0, math.floor(incomePerSecond * (product.IncomeSeconds or 0)))
end

-- Evolution ---------------------------------------------------------------------------------

function Economy.GetEvolutionTarget(unitName: string): string?
	local def = Units.ByName[unitName]
	return def and def.EvolvesTo
end

-- Seconds of XP needed before the critter can evolve (nil when it has no next form).
function Economy.GetEvolveTime(unitName: string): number?
	local target = Units.ByName[Economy.GetEvolutionTarget(unitName) or ""]
	if not target then
		return nil
	end
	return GameConfig.Evolution.TimeByRarity[target.Rarity] or 600
end

function Economy.GetEvolveCost(unitName: string, mutation: string?): number?
	local target = Economy.GetEvolutionTarget(unitName)
	if not target then
		return nil
	end
	return math.floor(Economy.GetUnitPrice(target, mutation) * GameConfig.Evolution.CostFraction)
end

-- Base upgrades -------------------------------------------------------------------------------

export type BaseTier = { FromLevel: number, Name: string, Description: string, Color: Color3 }

-- Any value (saved data, attribute, nil) -> a valid base level (1..MaxLevel).
function Economy.SanitizeBaseLevel(level: any): number
	if type(level) ~= "number" or level ~= level then
		return 1
	end
	return math.clamp(math.floor(level), 1, GameConfig.BaseUpgrade.MaxLevel)
end

-- Price to go from `level` to the next one, nil at max level.
function Economy.GetBaseUpgradeCost(level: number): number?
	local upgrade = GameConfig.BaseUpgrade
	local current = Economy.SanitizeBaseLevel(level)
	if current >= upgrade.MaxLevel then
		return nil
	end
	local costs = upgrade.Costs
	-- Levels past the end of the list (MaxLevel raised without new costs) keep growing x4.
	return costs[current] or costs[#costs] * 4 ^ (current - #costs)
end

-- Income multiplier of every critter of a base at this level (1 at level 1).
function Economy.GetBaseIncomeMultiplier(level: any): number
	return 1 + (Economy.SanitizeBaseLevel(level) - 1) * GameConfig.BaseUpgrade.IncomeBonusPerLevel
end

-- Income bonus in whole percents ("+30%"), avoids floating point noise in the UI.
function Economy.GetBaseIncomeBonusPercent(level: any): number
	return math.floor((Economy.GetBaseIncomeMultiplier(level) - 1) * 100 + 0.5)
end

-- Seconds the base lock lasts at this level.
function Economy.GetLockDuration(level: any): number
	return GameConfig.Lock.Duration + (Economy.SanitizeBaseLevel(level) - 1) * GameConfig.BaseUpgrade.LockBonusPerLevel
end

-- Index and definition of the castle tier (look) of a level.
function Economy.GetBaseTier(level: any): (number, BaseTier)
	local current = Economy.SanitizeBaseLevel(level)
	local tiers = GameConfig.BaseUpgrade.Tiers
	local index = 1
	for tierIndex, tier in tiers do
		if current >= tier.FromLevel then
			index = tierIndex
		end
	end
	return index, tiers[index]
end

-- day is 1-based and wraps around the reward list.
function Economy.GetDailyReward(day: number, incomePerSecond: number): (number, string?)
	local rewards = GameConfig.Daily.Rewards
	local reward = rewards[((day - 1) % #rewards) + 1]
	local cash = math.max(reward.Cash, math.floor(incomePerSecond * reward.IncomeSeconds))
	return cash, reward.Rarity
end

return Economy
