--[[
	RebirthService
	Rebirth = spend all your cash (when you have enough) for a permanent
	income bonus and an extra pedestal. Critters are kept.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local Notifier = require(script.Parent.Parent.Modules.Notifier)

local RebirthService = {}

local DataService, CurrencyService, UnitService

local lastRequest: { [Player]: number } = {}

local function rebirth(player: Player): (boolean, string)
	local now = os.clock()
	if now - (lastRequest[player] or 0) < 1 then
		return false, "Slow down!"
	end
	lastRequest[player] = now

	local data = DataService.Get(player)
	if not data or not player:GetAttribute("DataLoaded") then
		return false, "Still loading..."
	end

	local cost = Economy.GetRebirthCost(data.Rebirths)
	if data.Cash < cost then
		return false, `You need {Format.Money(cost)} to rebirth`
	end

	data.Rebirths += 1
	CurrencyService.Set(player, 0)
	UnitService.RefreshMultiplier(player)
	UnitService.RefreshSlots(player)

	local multiplier = Economy.GetRebirthMultiplier(data.Rebirths)
	Notifier.All(`♻️ {player.DisplayName} reached Rebirth {data.Rebirths}!`, "info")
	task.spawn(DataService.SaveAsync, player)
	return true, `Rebirth {data.Rebirths}! Cash x{multiplier} forever`
end

function RebirthService.Init(services)
	DataService = services.DataService
	CurrencyService = services.CurrencyService
	UnitService = services.UnitService
end

function RebirthService.OnPlayerRemoving(player: Player)
	lastRequest[player] = nil
end

function RebirthService.Start()
	Remotes.RequestRebirth.OnServerInvoke = function(player)
		local ok, message = rebirth(player)
		return ok, message
	end
end

return RebirthService
