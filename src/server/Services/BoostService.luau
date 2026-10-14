--[[
	BoostService
	Server-wide luck boost bought with Robux. It benefits everybody in the
	server, which makes it a very social (and popular) purchase.
	State is replicated with ReplicatedStorage attributes:
	  ServerLuckMultiplier (number), ServerLuckEndsAt (server time).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Util.Format)

local Notifier = require(script.Parent.Parent.Modules.Notifier)

local BoostService = {}

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

function BoostService.AddServerLuck(seconds: number, buyer: Player?)
	local current = now()
	endsAt = math.min(math.max(endsAt, current) + seconds, current + GameConfig.ServerLuck.MaxDuration)
	ReplicatedStorage:SetAttribute("ServerLuckMultiplier", GameConfig.ServerLuck.Multiplier)
	ReplicatedStorage:SetAttribute("ServerLuckEndsAt", endsAt)

	local remaining = Format.Time(endsAt - current)
	if buyer then
		Notifier.All(`🍀 {buyer.DisplayName} activated {GameConfig.ServerLuck.Multiplier}x SERVER LUCK! ({remaining})`, "announce")
	else
		Notifier.All(`🍀 {GameConfig.ServerLuck.Multiplier}x SERVER LUCK is active! ({remaining})`, "announce")
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
