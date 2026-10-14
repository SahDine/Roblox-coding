--[[
	CurrencyService
	Owns the Cash balance: leaderstats, player attributes read by the HUD,
	and every cash mutation (add / spend).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)

local CurrencyService = {}

local DataService

function CurrencyService.Init(services)
	DataService = services.DataService
end

function CurrencyService.Refresh(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	player:SetAttribute("Cash", data.Cash)
	player:SetAttribute("Rebirths", data.Rebirths)

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local cash = leaderstats:FindFirstChild("Cash") :: StringValue?
		local rebirths = leaderstats:FindFirstChild("Rebirths") :: IntValue?
		local steals = leaderstats:FindFirstChild("Steals") :: IntValue?
		if cash then
			cash.Value = Format.Money(math.floor(data.Cash))
		end
		if rebirths then
			rebirths.Value = data.Rebirths
		end
		if steals then
			steals.Value = data.Stats.Steals
		end
	end
end

function CurrencyService.Get(player: Player): number
	local data = DataService.Get(player)
	return if data then data.Cash else 0
end

function CurrencyService.Add(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data or amount ~= amount or amount <= 0 then
		return
	end
	data.Cash += amount
	data.TotalEarned += amount
	CurrencyService.Refresh(player)
end

function CurrencyService.TrySpend(player: Player, amount: number): boolean
	local data = DataService.Get(player)
	if not data or amount ~= amount or amount < 0 or data.Cash < amount then
		return false
	end
	data.Cash -= amount
	CurrencyService.Refresh(player)
	return true
end

function CurrencyService.Set(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.Cash = math.max(0, amount)
	CurrencyService.Refresh(player)
end

function CurrencyService.OnPlayerLoaded(player: Player, _data)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	-- A StringValue keeps big numbers readable ($1.2M instead of 1200000).
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Parent = leaderstats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = leaderstats

	local steals = Instance.new("IntValue")
	steals.Name = "Steals"
	steals.Parent = leaderstats

	leaderstats.Parent = player
	CurrencyService.Refresh(player)
end

return CurrencyService
