--[[
	StoreController
	Robux store with 4 tabs: game passes, cash packs, boosts and critters.
	Prices are read live from Roblox; IDs come from Shared/Config/Monetization.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)
local Monetization = require(Shared.Config.Monetization)
local Rarities = require(Shared.Config.Rarities)
local Units = require(Shared.Config.Units)

local UIKit = require(script.Parent.Parent.UI.UIKit)
local NotificationController = require(script.Parent.NotificationController)

local StoreController = {}

local player = Players.LocalPlayer
local Create = UIKit.Create

local TABS = {
	{ Name = "Passes", Label = "⭐ Passes", Color = UIKit.Colors.Gold },
	{ Name = "Cash", Label = "💵 Cash", Color = UIKit.Colors.Green },
	{ Name = "Boosts", Label = "🍀 Boosts", Color = UIKit.Colors.Blue },
	{ Name = "Critters", Label = "💎 Critters", Color = UIKit.Colors.Purple },
}

local KIND_TO_TAB = {
	Cash = "Cash",
	ServerLuck = "Boosts",
	BaseLock = "Boosts",
	Unit = "Critters",
}

local priceCache: { [string]: number } = {}

local function fetchPrice(id: number, infoType: Enum.InfoType, callback: (number) -> ())
	local cacheKey = tostring(infoType) .. id
	if priceCache[cacheKey] then
		callback(priceCache[cacheKey])
		return
	end
	task.spawn(function()
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
		if ok and info and info.PriceInRobux then
			priceCache[cacheKey] = info.PriceInRobux
			callback(info.PriceInRobux)
		end
	end)
end

local function makeCard(parent: Instance, order: number, icon: string, title: string, badge: string?): (Frame, TextLabel, TextButton)
	local card = Create("Frame", {
		LayoutOrder = order,
		BackgroundColor3 = UIKit.Colors.Panel,
		Parent = parent,
	}, {
		UIKit.Corner(14),
		UIKit.Stroke(UIKit.Colors.Outline, 3),
	})
	UIKit.Label({ Text = icon, Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 8), Parent = card })
	UIKit.Label({
		Text = title,
		TextColor3 = UIKit.Colors.Gold,
		Size = UDim2.new(1, -12, 0, 26),
		Position = UDim2.fromOffset(6, 60),
		Parent = card,
	})
	local description = UIKit.Label({
		Text = "",
		TextColor3 = UIKit.Colors.SubText,
		TextWrapped = true,
		Size = UDim2.new(1, -14, 0, 56),
		Position = UDim2.fromOffset(7, 88),
		StrokeThickness = 1,
		Parent = card,
	})
	local button = UIKit.Button({
		Text = "R$ ...",
		Color = UIKit.Colors.Robux,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -16, 0, 42),
		Parent = card,
	})
	if badge then
		local ribbon = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(120, 24),
			BackgroundColor3 = UIKit.Colors.Red,
			ZIndex = 3,
			Parent = card,
		}, {
			UIKit.Corner(8),
			UIKit.Stroke(UIKit.Colors.Outline, 2),
		})
		UIKit.Label({ Text = badge, Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2), ZIndex = 4, Parent = ribbon })
	end
	return card, description, button
end

function StoreController.Start()
	local screen = UIKit.Screen("Store", 5)
	local window = UIKit.CreateWindow(screen, "Store", "🛒 STORE", Vector2.new(690, 450))
	local content = window.Content

	local tabBar = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 46),
		Parent = content,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local pages: { [string]: ScrollingFrame } = {}
	local tabButtons: { [string]: TextButton } = {}
	local refreshers: { () -> () } = {}

	local function showTab(name: string)
		for tabName, page in pages do
			page.Visible = tabName == name
		end
		for _, tab in TABS do
			UIKit.SetButtonColor(tabButtons[tab.Name], if tab.Name == name then tab.Color else UIKit.Colors.Disabled)
		end
		for _, refresh in refreshers do
			refresh()
		end
	end

	for order, tab in TABS do
		tabButtons[tab.Name] = UIKit.Button({
			Text = tab.Label,
			Color = tab.Color,
			LayoutOrder = order,
			Size = UDim2.new(0.25, -6, 1, 0),
			Parent = tabBar,
		}, function()
			showTab(tab.Name)
		end)

		pages[tab.Name] = Create("ScrollingFrame", {
			Name = tab.Name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 56),
			Size = UDim2.new(1, 0, 1, -56),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 6,
			Visible = false,
			Parent = content,
		}, {
			Create("UIGridLayout", {
				CellSize = UDim2.fromOffset(152, 220),
				CellPadding = UDim2.fromOffset(10, 16),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Create("UIPadding", {
				PaddingTop = UDim.new(0, 14),
				PaddingLeft = UDim.new(0, 4),
			}),
		})
	end

	-- Game passes.
	for order, key in Monetization.GamePassOrder do
		local pass = Monetization.GamePasses[key]
		local _, description, button = makeCard(pages.Passes, order, pass.Icon, pass.Name, pass.Badge)
		description.Text = pass.Description

		local price = pass.DisplayPrice
		local function refresh()
			if player:GetAttribute("Pass_" .. key) then
				button.Text = "✅ OWNED"
				UIKit.SetButtonColor(button, UIKit.Colors.Disabled)
			elseif pass.Id == 0 then
				button.Text = "Not set up"
				UIKit.SetButtonColor(button, UIKit.Colors.Disabled)
			else
				button.Text = "R$ " .. price
				UIKit.SetButtonColor(button, UIKit.Colors.Robux)
			end
		end
		if pass.Id ~= 0 then
			fetchPrice(pass.Id, Enum.InfoType.GamePass, function(robux)
				price = robux
				refresh()
			end)
		end
		player:GetAttributeChangedSignal("Pass_" .. key):Connect(refresh)
		table.insert(refreshers, refresh)
		refresh()

		button.Activated:Connect(function()
			if player:GetAttribute("Pass_" .. key) then
				return
			end
			if pass.Id == 0 then
				NotificationController.Notify(`Set the {key} game pass Id in Monetization.luau`, "error")
				return
			end
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		end)
	end

	-- Developer products.
	for order, key in Monetization.ProductOrder do
		local product = Monetization.Products[key]
		local tabName = KIND_TO_TAB[product.Kind]
		if not tabName then
			continue
		end
		local _, description, button = makeCard(pages[tabName], order, product.Icon, product.Name, product.Badge)

		local price = product.DisplayPrice
		local function refresh()
			if product.Kind == "Cash" then
				local amount = Economy.GetCashPackAmount(product, player:GetAttribute("Income") or 0)
				description.Text = "+" .. Format.Money(amount)
				description.TextColor3 = Color3.fromRGB(140, 255, 140)
			elseif product.Kind == "Unit" then
				-- Paid random item: Roblox requires the odds to be shown before purchase.
				local lines = {}
				for _, entry in Units.GetOdds(product.Rarity) do
					table.insert(lines, `{entry.Name} {math.floor(entry.Chance * 1000 + 0.5) / 10}%`)
				end
				description.Text = table.concat(lines, "\n")
				description.TextColor3 = Rarities.Info[product.Rarity].Color
			else
				description.Text = product.Description or ""
			end
			if product.Id == 0 then
				button.Text = "Not set up"
				UIKit.SetButtonColor(button, UIKit.Colors.Disabled)
			else
				button.Text = "R$ " .. price
			end
		end
		if product.Id ~= 0 then
			fetchPrice(product.Id, Enum.InfoType.Product, function(robux)
				price = robux
				refresh()
			end)
		end
		table.insert(refreshers, refresh)
		refresh()

		button.Activated:Connect(function()
			if product.Id == 0 then
				NotificationController.Notify(`Set the {key} product Id in Monetization.luau`, "error")
				return
			end
			MarketplaceService:PromptProductPurchase(player, product.Id)
		end)
	end

	window.OnOpen = function()
		for _, refresh in refreshers do
			refresh()
		end
	end
	showTab("Passes")
end

return StoreController
