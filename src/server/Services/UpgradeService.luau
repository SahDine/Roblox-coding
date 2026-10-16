--[[
	UpgradeService
	Base upgrades: players spend cash to raise their base level (1 .. GameConfig.BaseUpgrade.MaxLevel).
	Every level:
	  - boosts the income of every critter of the base (UnitService multiplier, see Economy.GetBaseIncomeMultiplier);
	  - makes the base lock last longer (PlotService.GetLockDuration);
	  - changes the look of the castle, seen by everybody (PlotService.SetLevel: tiers, gate gems).

	Saved in data.BaseLevel (kept through rebirths) and published as the player attribute "BaseLevel"
	for the HUD and the upgrade window (UpgradeController). The window is opened by the "Upgrade Base"
	station inside each base or by the HUD button; the purchase goes through Remotes.UpgradeBase.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)

local Notifier = require(script.Parent.Parent.Modules.Notifier)

local UpgradeService = {}

local UPGRADE = GameConfig.BaseUpgrade

local DataService, CurrencyService, PlotService, UnitService

local SAVE_DELAY = 4 -- seconds: upgrades bought in a row (one click per level) are saved together

local lastRequest: { [Player]: number } = {}
local saveScheduled: { [Player]: boolean } = {}

-- Saves soon after an upgrade. A DataStore key takes about one write per 6 s: one save per click
-- would pile up queued writes (and delay the final save when the player leaves).
local function scheduleSave(player: Player)
	if saveScheduled[player] then
		return
	end
	saveScheduled[player] = true
	task.delay(SAVE_DELAY, function()
		if saveScheduled[player] then
			saveScheduled[player] = nil
			DataService.SaveAsync(player) -- no-op once the player left (their final save covers it)
		end
	end)
end

-- Current base level of a player (1 while the data is not loaded).
function UpgradeService.GetLevel(player: Player): number
	local data = DataService.Get(player)
	return if data then Economy.SanitizeBaseLevel(data.BaseLevel) else 1
end

-- Shows the level everywhere: player attribute, castle looks, lock duration, income multiplier.
local function applyLevel(player: Player, level: number)
	player:SetAttribute("BaseLevel", level)
	local plot = PlotService.GetPlot(player)
	if plot then
		PlotService.SetLevel(plot, level)
	end
	UnitService.RefreshMultiplier(player)
end

--[[
	Buys the next level. `fromLevel` is the level the client saw when the player clicked: a click
	sent while an earlier upgrade was still on its way is refused instead of buying two levels.
	Returns (success, message for the player, current level).
]]
local function upgrade(player: Player, fromLevel: any): (boolean, string, number)
	local now = os.clock()
	if now - (lastRequest[player] or 0) < UPGRADE.Cooldown then
		return false, "Slow down!", UpgradeService.GetLevel(player)
	end
	lastRequest[player] = now

	local data = DataService.Get(player)
	local plot = PlotService.GetPlot(player)
	if not data or not plot or not player:GetAttribute("DataLoaded") then
		return false, "Still loading...", 1
	end

	local level = Economy.SanitizeBaseLevel(data.BaseLevel)
	if fromLevel ~= nil and (type(fromLevel) ~= "number" or fromLevel ~= level) then
		return false, `Your base is already level {level}`, level
	end
	local cost = Economy.GetBaseUpgradeCost(level)
	if not cost then
		return false, "👑 Your base is already at max level!", level
	end
	if not CurrencyService.TrySpend(player, cost) then
		return false, `You need {Format.Money(cost)} to upgrade your base`, level
	end

	local newLevel = level + 1
	local oldTier = Economy.GetBaseTier(level)
	local tierIndex, tier = Economy.GetBaseTier(newLevel)
	data.BaseLevel = newLevel
	applyLevel(player, newLevel)
	PlotService.PlayUpgradeEffect(plot)
	scheduleSave(player)

	if newLevel >= UPGRADE.AnnounceFromLevel then
		Notifier.All(`👑 {player.DisplayName}'s base reached level {newLevel}: {tier.Name}!`, "announce")
	end
	local bonus = `+{Economy.GetBaseIncomeBonusPercent(newLevel)}% income, {Economy.GetLockDuration(newLevel)}s lock`
	if tierIndex ~= oldTier then
		return true, `🏰 Base level {newLevel}: your castle became a {tier.Name}! {bonus}`, newLevel
	end
	return true, `🏰 Base upgraded to level {newLevel}! {bonus}`, newLevel
end

-- Lifecycle -------------------------------------------------------------------

function UpgradeService.Init(services)
	DataService = services.DataService
	CurrencyService = services.CurrencyService
	PlotService = services.PlotService
	UnitService = services.UnitService
end

-- Runs after PlotService (the plot exists) and before UnitService (its multiplier reads the level).
function UpgradeService.OnPlayerLoaded(player: Player, data)
	data.BaseLevel = Economy.SanitizeBaseLevel(data.BaseLevel)
	applyLevel(player, data.BaseLevel)
end

function UpgradeService.OnPlayerRemoving(player: Player)
	lastRequest[player] = nil
	saveScheduled[player] = nil -- DataService.ReleaseAsync saves the level
end

function UpgradeService.Start()
	Remotes.UpgradeBase.OnServerInvoke = function(player: Player, fromLevel: any)
		local ok, message, level = upgrade(player, fromLevel)
		return ok, message, level
	end
end

return UpgradeService
