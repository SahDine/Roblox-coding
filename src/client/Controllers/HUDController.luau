--[[
	HUDController
	Always-visible UI: cash, income, slots, menu buttons, server luck timer
	and the "carrying a critter" banner. Reads the player attributes set by the server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local UIKit = require(script.Parent.Parent.UI.UIKit)

local HUDController = {}

local player = Players.LocalPlayer
local Create = UIKit.Create

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

function HUDController.Start()
	local screen = UIKit.Screen("HUD", 1)

	-- Left column: wallet + menu buttons ------------------------------------------
	local left = Create("Frame", {
		Name = "Left",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, -20),
		Size = UDim2.fromOffset(250, 330),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	UIKit.AttachScale(left)

	local wallet = Create("Frame", {
		Name = "Wallet",
		Size = UDim2.fromOffset(250, 118),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = left,
	}, {
		UIKit.Corner(16),
		UIKit.Stroke(UIKit.Colors.Outline, 3),
		UIKit.Gradient(UIKit.Colors.PanelLight, UIKit.Colors.Background),
	})

	local cashLabel = UIKit.Label({
		Text = "$0",
		TextColor3 = Color3.fromRGB(255, 230, 90),
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -28, 0, 52),
		StrokeThickness = 3,
		Parent = wallet,
	})
	local incomeLabel = UIKit.Label({
		Text = "+$0/s",
		TextColor3 = Color3.fromRGB(140, 255, 140),
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 58),
		Size = UDim2.new(0.62, -14, 0, 28),
		Parent = wallet,
	})
	local multiplierLabel = UIKit.Label({
		Text = "x1",
		TextColor3 = UIKit.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(0.62, 0, 0, 58),
		Size = UDim2.new(0.38, -14, 0, 28),
		Parent = wallet,
	})
	local slotsLabel = UIKit.Label({
		Text = "",
		TextColor3 = UIKit.Colors.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 88),
		Size = UDim2.new(1, -28, 0, 22),
		Parent = wallet,
	})

	local grid = Create("Frame", {
		Name = "Buttons",
		Position = UDim2.fromOffset(0, 128),
		Size = UDim2.fromOffset(250, 200),
		BackgroundTransparency = 1,
		Parent = left,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(121, 56),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local function menuButton(text: string, color: Color3, order: number, onClick: () -> ()): TextButton
		return UIKit.Button({ Text = text, Color = color, LayoutOrder = order, Parent = grid }, onClick)
	end

	menuButton("🛒 Store", UIKit.Colors.Gold, 1, function()
		UIKit.ToggleWindow("Store")
	end)
	menuButton("♻️ Rebirth", UIKit.Colors.Purple, 2, function()
		UIKit.ToggleWindow("Rebirth")
	end)
	local dailyButton = menuButton("🎁 Daily", UIKit.Colors.Blue, 3, function()
		UIKit.ToggleWindow("Daily")
	end)
	menuButton("🏷️ Codes", UIKit.Colors.Green, 4, function()
		UIKit.ToggleWindow("Codes")
	end)
	menuButton("🏠 Home", UIKit.Colors.Red, 5, function()
		Remotes.TeleportHome:FireServer()
	end)

	local dailyBadge = Create("TextLabel", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = UIKit.Colors.Red,
		Font = UIKit.Font,
		Text = "!",
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		Visible = false,
		ZIndex = 5,
		Parent = dailyButton,
	}, {
		UIKit.Corner(12),
		UIKit.Stroke(UIKit.Colors.Outline, 2),
	})

	-- Base upgrades (UpgradeController window), with a badge when the next level is affordable.
	local upgradeButton = menuButton("🏰 Upgrade", Color3.fromRGB(255, 140, 50), 6, function()
		UIKit.ToggleWindow("Upgrade")
	end)
	local upgradeBadge = Create("TextLabel", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = UIKit.Colors.Green,
		Font = UIKit.Font,
		Text = "↑",
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		Visible = false,
		ZIndex = 5,
		Parent = upgradeButton,
	}, {
		UIKit.Corner(12),
		UIKit.Stroke(UIKit.Colors.Outline, 2),
	})
	local function updateUpgradeBadge()
		local cost = Economy.GetBaseUpgradeCost(Economy.SanitizeBaseLevel(player:GetAttribute("BaseLevel")))
		upgradeBadge.Visible = cost ~= nil and (player:GetAttribute("Cash") or 0) >= cost
	end
	player:GetAttributeChangedSignal("Cash"):Connect(updateUpgradeBadge)
	player:GetAttributeChangedSignal("BaseLevel"):Connect(updateUpgradeBadge)
	updateUpgradeBadge()

	-- Server luck banner (top) ----------------------------------------------------
	local luckBanner = Create("Frame", {
		Name = "Luck",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(340, 44),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = screen,
	}, {
		UIKit.Corner(14),
		UIKit.Stroke(UIKit.Colors.Outline, 3),
		UIKit.Gradient(Color3.fromRGB(90, 220, 110), Color3.fromRGB(30, 130, 60)),
	})
	UIKit.AttachScale(luckBanner)
	local luckLabel = UIKit.Label({
		Text = "",
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		Parent = luckBanner,
	})

	-- Carry banner (bottom) -------------------------------------------------------
	local carryBanner = Create("Frame", {
		Name = "Carry",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -100),
		Size = UDim2.fromOffset(560, 50),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = screen,
	}, {
		UIKit.Corner(14),
		UIKit.Stroke(UIKit.Colors.Outline, 3),
		UIKit.Gradient(Color3.fromRGB(255, 110, 90), Color3.fromRGB(180, 40, 40)),
	})
	UIKit.AttachScale(carryBanner)
	local carryLabel = UIKit.Label({
		Text = "",
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		Parent = carryBanner,
	})

	-- Bindings ------------------------------------------------------------------------
	local lastCash: number? = nil

	local function popup(amount: number)
		local label = UIKit.Label({
			Text = "+" .. Format.Money(amount),
			TextColor3 = Color3.fromRGB(140, 255, 140),
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 14),
			Size = UDim2.fromOffset(140, 30),
			ZIndex = 3,
			Parent = wallet,
		})
		local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(label, info, { Position = UDim2.new(1, -14, 0, -30), TextTransparency = 1 }):Play()
		task.delay(0.9, label.Destroy, label)
	end

	local function updateCash()
		local cash = player:GetAttribute("Cash") or 0
		cashLabel.Text = Format.Money(math.floor(cash))
		if lastCash and cash - lastCash >= 1 then
			popup(cash - lastCash)
		end
		lastCash = cash
	end

	local function updateIncome()
		incomeLabel.Text = "+" .. Format.Money(player:GetAttribute("Income") or 0) .. "/s"
		local multiplier = player:GetAttribute("Multiplier") or 1
		-- + 1e-6: products like 1.5 (rebirth) x 1.4 (base level) are 2.0999999999999996 in floating point.
		multiplierLabel.Text = "x" .. Format.Number(math.floor(multiplier * 100 + 1e-6) / 100)
	end

	local function updateSlots()
		local used = player:GetAttribute("UsedSlots") or 0
		local max = player:GetAttribute("MaxSlots") or 0
		local storage = player:GetAttribute("StorageCount") or 0
		local text = `Slots {used}/{max}`
		if storage > 0 then
			text ..= ` • 📦 {storage} waiting`
		end
		slotsLabel.Text = text
		slotsLabel.TextColor3 = if used >= max and max > 0 then Color3.fromRGB(255, 120, 120) else UIKit.Colors.SubText
	end

	local function updateCarry()
		local carrying = player:GetAttribute("Carrying")
		carryBanner.Visible = carrying ~= nil
		if carrying then
			carryLabel.Text = `🏃 Carrying {carrying}! Run to your base!`
		end
	end

	player:GetAttributeChangedSignal("Cash"):Connect(updateCash)
	player:GetAttributeChangedSignal("Income"):Connect(updateIncome)
	player:GetAttributeChangedSignal("Multiplier"):Connect(updateIncome)
	for _, name in { "UsedSlots", "MaxSlots", "StorageCount" } do
		player:GetAttributeChangedSignal(name):Connect(updateSlots)
	end
	player:GetAttributeChangedSignal("Carrying"):Connect(updateCarry)
	updateCash()
	updateIncome()
	updateSlots()
	updateCarry()

	-- Timers (luck banner + daily badge).
	task.spawn(function()
		while true do
			local now = serverNow()
			local luckEnds = ReplicatedStorage:GetAttribute("ServerLuckEndsAt") or 0
			local multiplier = ReplicatedStorage:GetAttribute("ServerLuckMultiplier") or 1
			if luckEnds > now then
				luckBanner.Visible = true
				luckLabel.Text = `🍀 {multiplier}x SERVER LUCK  {Format.Time(luckEnds - now)}`
			else
				luckBanner.Visible = false
			end

			local dailyAt = player:GetAttribute("DailyNextAt")
			dailyBadge.Visible = dailyAt ~= nil and now >= dailyAt
			task.wait(0.5)
		end
	end)
end

return HUDController
