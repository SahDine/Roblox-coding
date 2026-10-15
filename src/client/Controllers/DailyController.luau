--[[
	DailyController
	7-day login streak window. One tile per day: claimed days are ticked, the next day is outlined
	in gold and the day-7 jackpot has a ribbon. The status line teases the next reward.
	Amounts use Economy.GetDailyReward with the player's current income, exactly like the server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)

local UIKit = require(script.Parent.Parent.UI.UIKit)
local NotificationController = require(script.Parent.NotificationController)

local DailyController = {}

local player = Players.LocalPlayer
local Create = UIKit.Create

local CLAIMED_COLOR = Color3.fromRGB(120, 230, 120)

type Tile = {
	Frame: Frame,
	Stroke: UIStroke,
	Icon: TextLabel,
	Check: TextLabel,
	Amount: TextLabel,
}

-- Small days get a bill, bigger ones a bag, the critter day a gift.
local function iconFor(reward: { Cash: number, Rarity: string? }): string
	if reward.Rarity then
		return "🎁"
	end
	return if reward.Cash >= 1_000 then "💰" else "💵"
end

function DailyController.Start()
	local screen = UIKit.Screen("Daily", 5)
	local window = UIKit.CreateWindow(screen, "Daily", "🎁 DAILY REWARDS", Vector2.new(640, 340), UIKit.Colors.Blue)
	local content = window.Content
	local rewards = GameConfig.Daily.Rewards

	local row = Create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 150),
		Parent = content,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local tiles: { Tile } = {}
	for day, reward in rewards do
		local tile = Create("Frame", {
			LayoutOrder = day,
			Size = UDim2.new(1 / #rewards, -8, 1, 0),
			BackgroundColor3 = UIKit.Colors.Panel,
			Parent = row,
		}, { UIKit.Corner(12) })
		local stroke = UIKit.Stroke(UIKit.Colors.Outline, 3)
		stroke.Parent = tile

		UIKit.Label({ Text = `DAY {day}`, Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 10), Parent = tile })
		local icon = UIKit.Label({
			Text = iconFor(reward),
			Size = UDim2.new(1, 0, 0, 38),
			Position = UDim2.fromOffset(0, 38),
			Parent = tile,
		})
		local check = UIKit.Label({
			Text = "✔",
			TextColor3 = CLAIMED_COLOR,
			Visible = false,
			Size = UDim2.new(1, 0, 0, 38),
			Position = UDim2.fromOffset(0, 38),
			Parent = tile,
		})
		local amount = UIKit.Label({
			Text = "",
			TextColor3 = Color3.fromRGB(140, 255, 140),
			Size = UDim2.new(1, -10, 0, 26),
			Position = UDim2.fromOffset(5, 82),
			Parent = tile,
		})
		if reward.Rarity then
			local info = Rarities.Info[reward.Rarity]
			UIKit.Label({
				Text = `+ {reward.Rarity} critter`,
				TextColor3 = if info then info.Color else UIKit.Colors.Purple,
				TextWrapped = true,
				Size = UDim2.new(1, -10, 0, 34),
				Position = UDim2.fromOffset(5, 110),
				Parent = tile,
			})
			-- Jackpot ribbon on the critter day.
			local ribbon = Create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.new(1, 4, 0, 20),
				BackgroundColor3 = UIKit.Colors.Gold,
				ZIndex = 3,
				Parent = tile,
			}, {
				UIKit.Corner(8),
				UIKit.Stroke(UIKit.Colors.Outline, 2),
			})
			UIKit.Label({
				Text = "JACKPOT",
				Size = UDim2.new(1, -6, 1, -4),
				Position = UDim2.fromOffset(3, 2),
				ZIndex = 4,
				Parent = ribbon,
			})
		end
		tiles[day] = { Frame = tile, Stroke = stroke, Icon = icon, Check = check, Amount = amount }
	end

	local statusLabel = UIKit.Label({
		Text = "",
		TextColor3 = UIKit.Colors.SubText,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 172),
		Parent = content,
	})

	local refresh: () -> ()
	local busy = false
	local claimButton = UIKit.Button({
		Text = "CLAIM",
		Color = UIKit.Colors.Green,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(220, 54),
		Parent = content,
	}, function()
		if busy then
			return
		end
		busy = true
		local ok, success, message = pcall(function()
			return Remotes.ClaimDaily:InvokeServer()
		end)
		busy = false
		if ok then
			NotificationController.Notify(tostring(message), if success then "success" else "error")
		else
			NotificationController.Notify("Could not reach the server, try again!", "error")
		end
		refresh()
	end)

	refresh = function()
		local nextDay = player:GetAttribute("DailyDay") or 1
		local nextAt = player:GetAttribute("DailyNextAt") or 0
		local income = player:GetAttribute("Income") or 0
		local currentIndex = ((nextDay - 1) % #rewards) + 1

		for day, tile in tiles do
			local cash = Economy.GetDailyReward(day, income)
			local claimed = day < currentIndex
			local isCurrent = day == currentIndex
			tile.Amount.Text = Format.Money(cash)
			tile.Amount.TextColor3 = if claimed then UIKit.Colors.SubText else Color3.fromRGB(140, 255, 140)
			tile.Icon.Visible = not claimed
			tile.Check.Visible = claimed
			tile.Stroke.Color = if isCurrent then UIKit.Colors.Gold else UIKit.Colors.Outline
			tile.Stroke.Thickness = if isCurrent then 4 else 3
			tile.Frame.BackgroundColor3 = if claimed
				then UIKit.Colors.Background
				elseif isCurrent then UIKit.Colors.PanelLight
				else UIKit.Colors.Panel
		end

		local nextCash = Economy.GetDailyReward(currentIndex, income)
		local remaining = nextAt - workspace:GetServerTimeNow()
		if remaining > 0 then
			statusLabel.Text = `Next: Day {currentIndex} ({Format.Money(nextCash)}) in {Format.Time(remaining)}`
			claimButton.Text = "COME BACK LATER"
			UIKit.SetButtonColor(claimButton, UIKit.Colors.Disabled)
		else
			local streak = nextDay - 1
			statusLabel.Text = if streak > 0
				then `Day {currentIndex} reward is ready! {streak}-day streak, don't break it!`
				else `Day {currentIndex} reward is ready! Come back every day for bigger rewards.`
			claimButton.Text = "CLAIM"
			UIKit.SetButtonColor(claimButton, UIKit.Colors.Green)
		end
	end

	window.OnOpen = refresh
	task.spawn(function()
		while true do
			if window.IsOpen then
				refresh()
			end
			task.wait(1)
		end
	end)
end

return DailyController
