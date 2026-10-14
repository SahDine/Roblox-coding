--[[
	MonetizationService
	Game passes + developer products.

	Developer products follow Roblox's recommended ProcessReceipt pattern:
	  1. never grant twice: every PurchaseId is stored in the player's data;
	  2. only return PurchaseGranted once the data containing the grant is saved;
	  3. return NotProcessedYet on any doubt, Roblox will retry later (even on rejoin).

	Other services register a handler per product Kind with RegisterKindHandler.
	Handlers must NOT yield and must return true when the reward was granted.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Monetization = require(Shared.Config.Monetization)
local Signal = require(Shared.Util.Signal)

local Notifier = require(script.Parent.Parent.Modules.Notifier)

local MonetizationService = {}

-- Fired with (player, passKey) when a pass is bought during the session.
MonetizationService.PassGranted = Signal.new()

type PassState = { Ready: boolean, Owned: { [string]: boolean } }
type KindHandler = (player: Player, productKey: string, product: any, receipt: any) -> boolean

local passStates: { [Player]: PassState } = {}
local kindHandlers: { [string]: KindHandler } = {}
local robuxPrices: { [string]: number } = {}

local DataService, CurrencyService, UnitService

function MonetizationService.Init(services)
	DataService = services.DataService
	CurrencyService = services.CurrencyService
	UnitService = services.UnitService
end

-- Game passes ---------------------------------------------------------------

function MonetizationService.PrefetchPasses(player: Player)
	local state: PassState = { Ready = false, Owned = {} }
	passStates[player] = state

	task.spawn(function()
		local grantAll = RunService:IsStudio() and GameConfig.Debug.GrantAllPassesInStudio
		local pending = 0

		for key, pass in Monetization.GamePasses do
			if grantAll then
				state.Owned[key] = true
			elseif pass.Id ~= 0 then
				pending += 1
				task.spawn(function()
					for attempt = 1, 3 do
						local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
						if ok then
							state.Owned[key] = owns == true
							break
						end
						task.wait(attempt)
					end
					pending -= 1
				end)
			end
		end

		while pending > 0 do
			task.wait(0.1)
		end
		state.Ready = true
		for key, owned in state.Owned do
			player:SetAttribute("Pass_" .. key, owned)
		end
	end)
end

function MonetizationService.WaitForPasses(player: Player, timeout: number)
	local deadline = os.clock() + timeout
	local state = passStates[player]
	while state and not state.Ready and os.clock() < deadline do
		task.wait(0.1)
	end
end

function MonetizationService.OwnsPass(player: Player, passKey: string): boolean
	local state = passStates[player]
	return state ~= nil and state.Owned[passKey] == true
end

local function onPassPurchaseFinished(player: Player, passId: number, wasPurchased: boolean)
	if not wasPurchased then
		return
	end
	local key = Monetization.GetPassKeyById(passId)
	local state = passStates[player]
	if not key or not state or state.Owned[key] then
		return
	end

	local pass = Monetization.GamePasses[key]
	state.Owned[key] = true
	player:SetAttribute("Pass_" .. key, true)

	Notifier.Send(player, `Thanks for buying {pass.Name}! {pass.Icon}`, "success")
	Notifier.All(`{player.DisplayName} just bought {pass.Name} {pass.Icon}`, "info")
	MonetizationService.PassGranted:Fire(player, key)
end

-- Developer products --------------------------------------------------------

function MonetizationService.RegisterKindHandler(kind: string, handler: KindHandler)
	kindHandlers[kind] = handler
end

function MonetizationService.GetRobuxPrice(productKey: string): number
	local product = Monetization.Products[productKey]
	return robuxPrices[productKey] or (product and product.DisplayPrice) or 0
end

function MonetizationService.IsProductConfigured(productKey: string): boolean
	local product = Monetization.Products[productKey]
	return product ~= nil and product.Id ~= 0
end

function MonetizationService.PromptProduct(player: Player, productKey: string): boolean
	local product = Monetization.Products[productKey]
	if not product or product.Id == 0 then
		Notifier.Send(player, `"{productKey}" is not set up yet (see Monetization.luau)`, "error")
		return false
	end
	MarketplaceService:PromptProductPurchase(player, product.Id)
	return true
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Wait until the player is fully loaded (plot assigned, critters spawned...).
	local deadline = os.clock() + 20
	while not player:GetAttribute("DataLoaded") do
		if os.clock() > deadline or not player.Parent then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		task.wait(0.25)
	end

	local data = DataService.Get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Already granted earlier (the save might have failed): just make sure it is saved.
	if table.find(data.Receipts, receipt.PurchaseId) then
		if DataService.SaveAsync(player) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local key = Monetization.GetProductKeyById(receipt.ProductId)
	local product = key and Monetization.Products[key]
	local handler = product and kindHandlers[product.Kind]
	if not key or not handler then
		warn(`[MonetizationService] No handler for product {receipt.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Grant + record the receipt without yielding in between.
	local ok, granted = pcall(handler, player, key, product, receipt)
	if not ok then
		warn(`[MonetizationService] Handler for {key} errored: {granted}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if granted ~= true then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	table.insert(data.Receipts, receipt.PurchaseId)
	while #data.Receipts > GameConfig.Data.MaxStoredReceipts do
		table.remove(data.Receipts, 1)
	end
	data.Stats.RobuxSpent += receipt.CurrencySpent or 0

	if DataService.SaveAsync(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Lifecycle -----------------------------------------------------------------

function MonetizationService.OnPlayerRemoving(player: Player)
	passStates[player] = nil
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPassPurchaseFinished)

	-- Cash packs scale with the buyer's income so they stay worth it all game long.
	MonetizationService.RegisterKindHandler("Cash", function(player, _key, product)
		local amount = Economy.GetCashPackAmount(product, UnitService.GetIncomePerSecond(player))
		CurrencyService.Add(player, amount)
		Notifier.Send(player, `+{Format.Money(amount)} {product.Icon} Thank you!`, "success")
		return true
	end)

	-- Real Robux prices, shown on the conveyor critters.
	for key, product in Monetization.Products do
		if product.Id ~= 0 then
			task.spawn(function()
				local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, product.Id, Enum.InfoType.Product)
				if ok and info and info.PriceInRobux then
					robuxPrices[key] = info.PriceInRobux
				end
			end)
		end
	end
end

return MonetizationService
