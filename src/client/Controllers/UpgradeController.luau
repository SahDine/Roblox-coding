--[[
	UpgradeController
	Base upgrade window: current level, what the next level gives (income bonus, longer lock,
	new castle look), its cost and the Upgrade button (Remotes.UpgradeBase).
	Opened by the HUD button and by the "Upgrade Base" station inside your base. The station's prompt
	(tag "UpgradeStation") is only shown to the owner of the base.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)

local UIKit = require(script.Parent.Parent.UI.UIKit)
local NotificationController = require(script.Parent.NotificationController)

local UpgradeController = {}

local player = Players.LocalPlayer
local Create = UIKit.Create

local UPGRADE = GameConfig.BaseUpgrade
local WINDOW = "Upgrade"
local NEXT_COLOR = Color3.fromRGB(140, 255, 140)

local function getLevel(): number
	return Economy.SanitizeBaseLevel(player:GetAttribute("BaseLevel"))
end

-- Station prompts: only the owner of the base sees them; they open the window.
local function setupStationPrompts()
	local registered: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any

	local function register(instance: Instance)
		if not instance:IsA("ProximityPrompt") or registered[instance] then
			return
		end
		local prompt = instance :: ProximityPrompt
		registered[prompt] = true
		local function apply()
			prompt.Enabled = prompt:GetAttribute("OwnerUserId") == player.UserId
		end
		apply()
		prompt:GetAttributeChangedSignal("OwnerUserId"):Connect(apply)
		prompt.Triggered:Connect(function(who)
			if who == player and prompt:GetAttribute("OwnerUserId") == player.UserId then
				UIKit.OpenWindow(WINDOW)
			end
		end)
	end

	for _, instance in CollectionService:GetTagged("UpgradeStation") do
		register(instance)
	end
	CollectionService:GetInstanceAddedSignal("UpgradeStation"):Connect(register)
end

function UpgradeController.Start()
	local screen = UIKit.Screen("Upgrade", 5)
	local window = UIKit.CreateWindow(screen, WINDOW, "🏰 BASE UPGRADE", Vector2.new(500, 440), UIKit.Colors.Gold)
	local content = window.Content

	-- Level + castle tier, and one pip per level.
	local levelLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, 0, 0, 34), StrokeThickness = 3, Parent = content })
	local levelScale = Create("UIScale", { Parent = levelLabel })

	local pipRow = Create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = content,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local pips: { Frame } = {}
	for index = 1, UPGRADE.MaxLevel do
		pips[index] = Create("Frame", {
			LayoutOrder = index,
			Size = UDim2.fromOffset(34, 20),
			BackgroundColor3 = UIKit.Colors.Background,
			Parent = pipRow,
		}, { UIKit.Corner(6), UIKit.Stroke(UIKit.Colors.Outline, 2) })
	end

	-- Benefits: now -> next level.
	local panel = Create("Frame", {
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 0, 128),
		BackgroundColor3 = UIKit.Colors.Panel,
		Parent = content,
	}, { UIKit.Corner(14), UIKit.Stroke(UIKit.Colors.Outline, 3) })

	local function benefitRow(order: number, title: string): (TextLabel, TextLabel)
		local y = 10 + (order - 1) * 38
		UIKit.Label({
			Text = title,
			TextColor3 = UIKit.Colors.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(14, y),
			Size = UDim2.new(0.4, -14, 0, 30),
			StrokeThickness = 1,
			Parent = panel,
		})
		local now = UIKit.Label({
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0.4, 0, 0, y),
			Size = UDim2.new(0.25, -4, 0, 30),
			Parent = panel,
		})
		local nextValue = UIKit.Label({
			Text = "",
			TextColor3 = NEXT_COLOR,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0.65, 4, 0, y),
			Size = UDim2.new(0.35, -18, 0, 30),
			Parent = panel,
		})
		return now, nextValue
	end
	local incomeNow, incomeNext = benefitRow(1, "💵 Income")
	local lockNow, lockNext = benefitRow(2, "🔒 Base lock")
	local lookNow, lookNext = benefitRow(3, "🏰 Castle")

	local noteLabel = UIKit.Label({
		Text = "",
		TextColor3 = UIKit.Colors.SubText,
		TextWrapped = true,
		Position = UDim2.fromOffset(0, 208),
		Size = UDim2.new(1, 0, 0, 40),
		StrokeThickness = 1,
		Parent = content,
	})

	-- Cash progress towards the next level.
	local bar = Create("Frame", {
		Position = UDim2.fromOffset(0, 256),
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = UIKit.Colors.Background,
		Parent = content,
	}, { UIKit.Corner(10), UIKit.Stroke(UIKit.Colors.Outline, 3) })
	local fill = Create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = bar,
	}, { UIKit.Corner(10), UIKit.Gradient(Color3.fromRGB(255, 225, 120), UIKit.Colors.Gold) })
	local progressLabel =
		UIKit.Label({ Text = "", Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromOffset(6, 3), ZIndex = 2, Parent = bar })

	local busy = false
	local refresh: () -> ()

	local button = UIKit.Button({
		Text = "UPGRADE",
		Color = UIKit.Colors.Gold,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(260, 58),
		Parent = content,
	}, function()
		if busy or getLevel() >= UPGRADE.MaxLevel then
			return
		end
		busy = true
		local ok, success, message = pcall(function()
			return Remotes.UpgradeBase:InvokeServer(getLevel())
		end)
		busy = false
		if not ok then
			NotificationController.Notify("Upgrade failed, please try again", "error")
		elseif type(message) == "string" then
			NotificationController.Notify(message, if success then "success" else "error")
		end
		refresh()
	end)

	refresh = function()
		local level = getLevel()
		local cash = player:GetAttribute("Cash") or 0
		local cost = Economy.GetBaseUpgradeCost(level)
		local tierIndex, tier = Economy.GetBaseTier(level)

		levelLabel.Text = `⭐ Level {level} / {UPGRADE.MaxLevel}  •  {tier.Name}`
		levelLabel.TextColor3 = tier.Color
		for index, pip in pips do
			local _, pipTier = Economy.GetBaseTier(index)
			pip.BackgroundColor3 = if index <= level then pipTier.Color else UIKit.Colors.Background
		end

		incomeNow.Text = `+{Economy.GetBaseIncomeBonusPercent(level)}%`
		lockNow.Text = `{Economy.GetLockDuration(level)}s`
		lookNow.Text = tier.Name
		lookNow.TextColor3 = tier.Color

		if not cost then
			incomeNext.Text, lockNext.Text, lookNext.Text = "MAX", "MAX", "MAX"
			noteLabel.Text = `👑 Your base is at max level. Everybody can see your {tier.Name}!`
			TweenService:Create(fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(1, 1) }):Play()
			progressLabel.Text = "Max level reached!"
			button.Text = "👑 MAX LEVEL"
			UIKit.SetButtonColor(button, UIKit.Colors.Disabled)
			return
		end

		local nextLevel = level + 1
		local nextTierIndex, nextTier = Economy.GetBaseTier(nextLevel)
		incomeNext.Text = `→ +{Economy.GetBaseIncomeBonusPercent(nextLevel)}%`
		lockNext.Text = `→ {Economy.GetLockDuration(nextLevel)}s`
		if nextTierIndex ~= tierIndex then
			lookNext.Text = `→ {nextTier.Name} ✨`
			noteLabel.Text = `New look at level {nextLevel}: {nextTier.Description}!`
		else
			lookNext.Text = "→ +1 gate gem"
			-- Next new look, if any.
			local upcoming = UPGRADE.Tiers[tierIndex + 1]
			noteLabel.Text = if upcoming
				then `Every level boosts all your critters. New look at level {upcoming.FromLevel}: {upcoming.Name}`
				else "Every level boosts all your critters."
		end

		local progress = math.clamp(cash / cost, 0, 1)
		TweenService:Create(fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(progress, 1) }):Play()
		progressLabel.Text = `{Format.Money(math.floor(cash))} / {Format.Money(cost)}`
		button.Text = `UPGRADE  {Format.Money(cost)}`
		UIKit.SetButtonColor(button, if cash >= cost then UIKit.Colors.Gold else UIKit.Colors.Disabled)
	end

	window.OnOpen = refresh
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		if window.IsOpen then
			refresh()
		end
	end)
	player:GetAttributeChangedSignal("BaseLevel"):Connect(function()
		refresh()
		if window.IsOpen then
			levelScale.Scale = 1.25
			TweenService:Create(levelScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end)
	refresh()

	setupStationPrompts()
end

return UpgradeController
