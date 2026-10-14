--[[
	RewardService
	Daily login streak and promo codes (both great for retention).
	Player attributes for the HUD: DailyDay (next day to claim), DailyNextAt (server time).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)
local Units = require(Shared.Config.Units)

local Notifier = require(script.Parent.Parent.Modules.Notifier)

local RewardService = {}

local DAILY = GameConfig.Daily

local DataService, CurrencyService, UnitService

local lastRequest: { [Player]: number } = {}

local function rateLimited(player: Player): boolean
	local now = os.clock()
	if now - (lastRequest[player] or 0) < 1 then
		return true
	end
	lastRequest[player] = now
	return false
end

-- Returns the day number that can be claimed next and when it becomes claimable.
local function getDailyState(data): (number, number)
	local last = data.Daily.LastClaim
	local streak = data.Daily.Streak
	if last > 0 and os.time() - last > DAILY.StreakResetAfter then
		streak = 0
	end
	local nextAt = if last == 0 then 0 else last + DAILY.Cooldown
	return streak + 1, nextAt
end

local function refreshDailyAttributes(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local day, nextAt = getDailyState(data)
	player:SetAttribute("DailyDay", day)
	player:SetAttribute("DailyNextAt", nextAt)
end

local function claimDaily(player: Player): (boolean, string)
	if rateLimited(player) then
		return false, "Slow down!"
	end
	local data = DataService.Get(player)
	if not data or not player:GetAttribute("DataLoaded") then
		return false, "Still loading..."
	end

	local day, nextAt = getDailyState(data)
	local now = os.time()
	if now < nextAt then
		return false, `Come back in {Format.Time(nextAt - now)}`
	end

	local cash, rarity = Economy.GetDailyReward(day, UnitService.GetIncomePerSecond(player))
	data.Daily.LastClaim = now
	data.Daily.Streak = day
	CurrencyService.Add(player, cash)

	local message = `Day {day} reward: +{Format.Money(cash)}`
	if rarity then
		local def = Units.PickFromRarity(rarity)
		if def then
			UnitService.GrantUnit(player, def.Name, "None")
			message ..= ` and a {rarity} {def.Name}!`
		end
	end

	refreshDailyAttributes(player)
	task.spawn(DataService.SaveAsync, player)
	return true, message
end

local function redeemCode(player: Player, rawCode: any): (boolean, string)
	if rateLimited(player) then
		return false, "Slow down!"
	end
	if type(rawCode) ~= "string" or #rawCode == 0 or #rawCode > 40 then
		return false, "Invalid code"
	end
	local data = DataService.Get(player)
	if not data or not player:GetAttribute("DataLoaded") then
		return false, "Still loading..."
	end

	local code = string.upper((string.gsub(rawCode, "%s", "")))
	local reward = GameConfig.Codes[code]
	if not reward then
		return false, "Invalid code"
	end
	if reward.ExpiresAt and os.time() > reward.ExpiresAt then
		return false, "This code has expired"
	end
	if data.RedeemedCodes[code] then
		return false, "You already redeemed this code"
	end
	if reward.Unit and not Units.ByName[reward.Unit] then
		warn(`[RewardService] Code {code} gives unknown unit {reward.Unit}`)
		return false, "Invalid code"
	end

	data.RedeemedCodes[code] = true
	local parts = {}
	if reward.Cash then
		CurrencyService.Add(player, reward.Cash)
		table.insert(parts, "+" .. Format.Money(reward.Cash))
	end
	if reward.Unit then
		UnitService.GrantUnit(player, reward.Unit, reward.Mutation or "None")
		table.insert(parts, reward.Unit)
	end
	task.spawn(DataService.SaveAsync, player)
	return true, "Code redeemed! " .. table.concat(parts, " + ")
end

function RewardService.Init(services)
	DataService = services.DataService
	CurrencyService = services.CurrencyService
	UnitService = services.UnitService
end

function RewardService.OnPlayerLoaded(player: Player, data)
	refreshDailyAttributes(player)
	local _, nextAt = getDailyState(data)
	if os.time() >= nextAt then
		task.delay(5, Notifier.Send, player, "🎁 Your daily reward is ready!", "info")
	end
end

function RewardService.OnPlayerRemoving(player: Player)
	lastRequest[player] = nil
end

function RewardService.Start()
	Remotes.ClaimDaily.OnServerInvoke = function(player)
		local ok, message = claimDaily(player)
		return ok, message
	end
	Remotes.RedeemCode.OnServerInvoke = function(player, code)
		local ok, message = redeemCode(player, code)
		return ok, message
	end
end

return RewardService
