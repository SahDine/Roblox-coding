--[[
	Server entry point.
	1. Requires every service, then calls Init (wire dependencies) and Start (begin loops) in order.
	2. Drives the player lifecycle so that services always run in a known order:
	     join  -> load data -> OnPlayerLoaded(player, data) for each service -> DataLoaded attribute
	     leave -> OnPlayerRemoving(player) for each service -> final save (DataService.ReleaseAsync)
]]

local Players = game:GetService("Players")

local Services = script.Parent.Services

local ORDER = {
	"DataService",
	"MapService",
	"MonetizationService",
	"CurrencyService",
	"BoostService",
	"PlotService",
	"UnitService",
	"StealService",
	"ConveyorService",
	"CombatService",
	"RebirthService",
	"RewardService",
	"UpgradeService",
	"LeaderboardService",
}

-- Order matters: plot before critters, critters before rewards.
local LOAD_ORDER = {
	"CurrencyService",
	"PlotService",
	"UpgradeService",
	"UnitService",
	"CombatService",
	"RewardService",
}

-- Order matters: cancel steals before destroying critters, critters before freeing the plot.
local REMOVE_ORDER = {
	"StealService",
	"ConveyorService",
	"UnitService",
	"CombatService",
	"RebirthService",
	"RewardService",
	"UpgradeService",
	"LeaderboardService",
	"PlotService",
	"MonetizationService",
}

local services = {}
for _, name in ORDER do
	services[name] = require(Services:FindFirstChild(name))
end

for _, name in ORDER do
	local service = services[name]
	if service.Init then
		service.Init(services)
	end
end

for _, name in ORDER do
	local service = services[name]
	if service.Start then
		service.Start()
	end
end

local DataService = services.DataService
local MonetizationService = services.MonetizationService

local function callAll(order: { string }, method: string, ...: any)
	for _, name in order do
		local service = services[name]
		local callback = service[method]
		if callback then
			local ok, err = pcall(callback, ...)
			if not ok then
				warn(`[Main] {name}.{method} failed: {err}`)
			end
		end
	end
end

local function onPlayerAdded(player: Player)
	MonetizationService.PrefetchPasses(player)

	local data = DataService.LoadAsync(player)
	if not data or not player.Parent then
		return
	end

	MonetizationService.WaitForPasses(player, 10)
	if not player.Parent then
		return
	end

	callAll(LOAD_ORDER, "OnPlayerLoaded", player, data)
	player:SetAttribute("DataLoaded", true)
end

local function onPlayerRemoving(player: Player)
	player:SetAttribute("DataLoaded", nil)
	callAll(REMOVE_ORDER, "OnPlayerRemoving", player)
	DataService.ReleaseAsync(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Players who joined before this script ran (common in Studio).
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
