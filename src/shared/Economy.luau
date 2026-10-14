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

-- day is 1-based and wraps around the reward list.
function Economy.GetDailyReward(day: number, incomePerSecond: number): (number, string?)
	local rewards = GameConfig.Daily.Rewards
	local reward = rewards[((day - 1) % #rewards) + 1]
	local cash = math.max(reward.Cash, math.floor(incomePerSecond * reward.IncomeSeconds))
	return cash, reward.Rarity
end

return Economy
