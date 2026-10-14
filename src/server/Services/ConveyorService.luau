--[[
	ConveyorService
	Critters keep walking along the conveyor. Anyone can buy one with cash
	(first come, first served) or instantly with Robux for Epic+ rarities.
	Rare spawns are announced to the whole server to create hype.
]]

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Units = require(Shared.Config.Units)

local Modules = script.Parent.Parent.Modules
local Notifier = require(Modules.Notifier)
local UnitModelBuilder = require(Modules.UnitModelBuilder)
local Walker = require(Modules.Walker)

local ConveyorService = {}

type Entry = {
	Id: string,
	UnitName: string,
	Rarity: string,
	Mutation: string,
	Model: Model,
	Token: Walker.Token,
	Prompts: { ProximityPrompt },
	Sold: boolean,
}

type PendingRobux = { EntryId: string, UnitName: string, Mutation: string, Rarity: string, Time: number }

local CONVEYOR = GameConfig.Conveyor

local MapService, UnitService, CurrencyService, MonetizationService, BoostService, PlotService

local entries: { [string]: Entry } = {}
local entryCount = 0
local pendingRobux: { [Player]: PendingRobux } = {}

local function removeEntry(entry: Entry)
	if entries[entry.Id] then
		entries[entry.Id] = nil
		entryCount -= 1
	end
	entry.Token.Cancelled = true
	for _, prompt in entry.Prompts do
		prompt:Destroy()
	end
	table.clear(entry.Prompts)
end

-- Hands the conveyor critter to the buyer: it walks to their base.
local function deliver(entry: Entry, player: Player)
	entry.Sold = true
	removeEntry(entry)
	UnitService.GrantUnit(player, entry.UnitName, entry.Mutation, { Model = entry.Model, Walk = true })
end

local function tryBuyWithCash(player: Player, entry: Entry)
	if entry.Sold or not player:GetAttribute("DataLoaded") or not PlotService.GetPlot(player) then
		return
	end
	if not UnitService.HasFreeSlot(player) then
		Notifier.Send(player, "Your base is full! Sell a critter or rebirth for more slots.", "error")
		return
	end
	local price = Economy.GetUnitPrice(entry.UnitName, entry.Mutation)
	if not CurrencyService.TrySpend(player, price) then
		Notifier.Send(player, `Not enough cash! You need {Format.Money(price)}`, "error")
		return
	end
	deliver(entry, player)
	Notifier.Send(player, `You bought {entry.UnitName}! It's walking to your base.`, "success")
end

local function tryBuyWithRobux(player: Player, entry: Entry)
	local productKey = Rarities.Info[entry.Rarity].RobuxProduct
	if entry.Sold or not productKey or not player:GetAttribute("DataLoaded") then
		return
	end
	pendingRobux[player] = {
		EntryId = entry.Id,
		UnitName = entry.UnitName,
		Mutation = entry.Mutation,
		Rarity = entry.Rarity,
		Time = os.clock(),
	}
	MonetizationService.PromptProduct(player, productKey)
end

local function spawnCritter(unitName: string, mutation: string)
	local def = Units.ByName[unitName]
	local model = UnitModelBuilder.Build(unitName, mutation)
	if not def or not model then
		return
	end
	local root = model.PrimaryPart :: BasePart
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid

	local entry: Entry = {
		Id = HttpService:GenerateGUID(false),
		UnitName = unitName,
		Rarity = def.Rarity,
		Mutation = mutation,
		Model = model,
		Token = Walker.NewToken(),
		Prompts = {},
		Sold = false,
	}

	local price = Economy.GetUnitPrice(unitName, mutation)
	local productKey = Rarities.Info[def.Rarity].RobuxProduct
	local robuxEnabled = productKey ~= nil and MonetizationService.IsProductConfigured(productKey)
	local robuxText = if robuxEnabled and productKey then `or R$ {MonetizationService.GetRobuxPrice(productKey)}` else nil
	UnitModelBuilder.CreateInfoBillboard(model, unitName, mutation, Format.Money(price), robuxText)

	local start = MapService.ConveyorStart
	model:PivotTo(UnitModelBuilder.GetStandingCFrame(model, start, Vector3.new(1, 0, 0)))
	model.Parent = MapService.ConveyorFolder
	UnitModelBuilder.SetAnchored(model, false)
	humanoid.WalkSpeed = CONVEYOR.WalkSpeed

	local buyPrompt = Instance.new("ProximityPrompt")
	buyPrompt.Name = "BuyPrompt"
	buyPrompt.ActionText = "Buy " .. Format.Money(price)
	buyPrompt.ObjectText = (if mutation ~= "None" then mutation .. " " else "") .. unitName
	buyPrompt.HoldDuration = 0
	buyPrompt.MaxActivationDistance = 12
	buyPrompt.RequiresLineOfSight = false
	buyPrompt.KeyboardKeyCode = Enum.KeyCode.E
	buyPrompt:SetAttribute("Kind", "Buy")
	buyPrompt.Triggered:Connect(function(player)
		tryBuyWithCash(player, entry)
	end)
	buyPrompt.Parent = root
	table.insert(entry.Prompts, buyPrompt)

	if robuxEnabled and productKey then
		local robuxPrompt = Instance.new("ProximityPrompt")
		robuxPrompt.Name = "RobuxPrompt"
		robuxPrompt.ActionText = `Instant buy R$ {MonetizationService.GetRobuxPrice(productKey)}`
		robuxPrompt.ObjectText = def.Rarity
		robuxPrompt.HoldDuration = 0
		robuxPrompt.MaxActivationDistance = 12
		robuxPrompt.RequiresLineOfSight = false
		robuxPrompt.KeyboardKeyCode = Enum.KeyCode.F
		robuxPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
		robuxPrompt:SetAttribute("Kind", "Robux")
		robuxPrompt.Triggered:Connect(function(player)
			tryBuyWithRobux(player, entry)
		end)
		robuxPrompt.Parent = root
		table.insert(entry.Prompts, robuxPrompt)
	end

	entries[entry.Id] = entry
	entryCount += 1

	if Rarities.Info[def.Rarity].Announce or (mutation ~= "None" and Mutations.Get(mutation).Multiplier >= 5) then
		local label = (if mutation ~= "None" then mutation .. " " else "") .. unitName
		Notifier.All(`✨ A {string.upper(def.Rarity)} {label} appeared on the conveyor!`, "announce")
	end

	task.spawn(function()
		local result = Walker.Walk(humanoid, { MapService.ConveyorEnd }, entry.Token, 120)
		if result ~= "Cancelled" and not entry.Sold then
			removeEntry(entry)
			model:Destroy()
		end
	end)
end

local function spawnRandom()
	local luck = BoostService.GetServerLuck()
	local rarity = Rarities.Roll(luck)
	local def = Units.PickFromRarity(rarity)
	if def then
		spawnCritter(def.Name, Mutations.Roll(luck))
	end
end

-- Robux "Unit" products: the critter the player clicked on, or a random one of that rarity.
local function grantRobuxUnit(player: Player, _productKey: string, product): boolean
	local rarity = product.Rarity
	local pending = pendingRobux[player]
	pendingRobux[player] = nil

	-- Bought from the conveyor: you always get exactly the critter you clicked on.
	if pending and pending.Rarity == rarity and os.clock() - pending.Time < 300 then
		local entry = entries[pending.EntryId]
		if entry and not entry.Sold then
			deliver(entry, player)
			Notifier.Send(player, `💎 {entry.UnitName} is yours! It's walking to your base.`, "success")
		else
			-- Someone bought it with cash while the prompt was open: give an identical one.
			UnitService.GrantUnit(player, pending.UnitName, pending.Mutation)
			Notifier.Send(player, `💎 {pending.UnitName} is yours!`, "success")
		end
		return true
	end

	-- Bought from the store: random critter of that rarity (odds are shown in the store).
	local def = Units.PickFromRarity(rarity)
	if not def then
		return false
	end
	UnitService.GrantUnit(player, def.Name, "None")
	Notifier.Send(player, `💎 You got a {rarity} {def.Name}!`, "success")
	return true
end

function ConveyorService.Init(services)
	MapService = services.MapService
	UnitService = services.UnitService
	CurrencyService = services.CurrencyService
	MonetizationService = services.MonetizationService
	BoostService = services.BoostService
	PlotService = services.PlotService
end

function ConveyorService.OnPlayerRemoving(player: Player)
	pendingRobux[player] = nil
end

function ConveyorService.Start()
	MonetizationService.RegisterKindHandler("Unit", grantRobuxUnit)

	-- A cancelled conveyor prompt must not affect a later store purchase.
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _productId, isPurchased)
		local player = Players:GetPlayerByUserId(userId)
		if player and not isPurchased then
			pendingRobux[player] = nil
		end
	end)

	task.spawn(function()
		while true do
			task.wait(CONVEYOR.SpawnInterval)
			if entryCount < CONVEYOR.MaxCritters then
				local ok, err = pcall(spawnRandom)
				if not ok then
					warn("[ConveyorService] Spawn failed: " .. tostring(err))
				end
			end
		end
	end)
end

-- Exposed for admin tools / live events.
ConveyorService.SpawnCritter = spawnCritter

return ConveyorService
