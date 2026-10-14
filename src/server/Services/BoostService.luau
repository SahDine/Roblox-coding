--[[
	BoostService
	Server-wide luck boost bought with Robux. It benefits everybody in the
	server, which makes it a very social (and popular) purchase.
	While active: better Rare / Epic / mutation odds on the conveyor, and the public
	Legendary / Mythic / Secret spawn timers (ConveyorService) run Multiplier times faster.
	State is replicated with ReplicatedStorage attributes:
	  ServerLuckMultiplier (number), ServerLuckEndsAt (server time).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Util.Format)
local Signal = require(Shared.Util.Signal)

local Notifier = require(script.Parent.Parent.Modules.Notifier)

local BoostService = {}

-- Fired (no arguments) right after the luck boost was extended.
BoostService.LuckChanged = Signal.new()

local MonetizationService

local endsAt = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

function BoostService.Init(services)
	MonetizationService = services.MonetizationService
end

function BoostService.GetServerLuck(): number
	if now() < endsAt then
		return GameConfig.ServerLuck.Multiplier
	end
	return 1
end

-- End of the current boost (server time, in the past when none) and its multiplier, for
-- systems that must predict the future (rare spawn timers).
function BoostService.GetServerLuckWindow(): (number, number)
	return endsAt, math.max(1, GameConfig.ServerLuck.Multiplier)
end

function BoostService.AddServerLuck(seconds: number, buyer: Player?)
	local current = now()
	endsAt = math.min(math.max(endsAt, current) + seconds, current + GameConfig.ServerLuck.MaxDuration)
	ReplicatedStorage:SetAttribute("ServerLuckMultiplier", GameConfig.ServerLuck.Multiplier)
	ReplicatedStorage:SetAttribute("ServerLuckEndsAt", endsAt)
	BoostService.LuckChanged:Fire()

	local multiplier = GameConfig.ServerLuck.Multiplier
	local remaining = Format.Time(endsAt - current)
	if buyer then
		Notifier.All(`🍀 {buyer.DisplayName} activated {multiplier}x SERVER LUCK! Rare timers {multiplier}x faster ({remaining})`, "announce")
	else
		Notifier.All(`🍀 {multiplier}x SERVER LUCK is active! Rare timers {multiplier}x faster ({remaining})`, "announce")
	end
end

function BoostService.Start()
	ReplicatedStorage:SetAttribute("ServerLuckMultiplier", 1)
	ReplicatedStorage:SetAttribute("ServerLuckEndsAt", 0)

	MonetizationService.RegisterKindHandler("ServerLuck", function(player, _key, product)
		BoostService.AddServerLuck(product.Duration, player)
		return true
	end)
end

return BoostService
