--[[
	DailyController
	7-day login streak window.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)

local UIKit = require(script.Parent.Parent.UI.UIKit)
local NotificationController = require(script.Parent.NotificationController)

local DailyController = {}

local player = Players.LocalPlayer
local Create = UIKit.Create

function DailyController.Start()
	local screen = UIKit.Screen("Daily", 5)
	local window = UIKit.CreateWindow(screen, "Daily", "🎁 DAILY REWARDS", Vector2.new(640, 330), UIKit.Colors.Blue)
	local content = window.Content
	local rewards = GameConfig.Daily.Rewards

	local row = Create("Frame", {
		BackgroundTransparency = 1,
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

	local tiles = {}
	for day = 1, #rewards do
		local tile = Create("Frame", {
			LayoutOrder = day,
			Size = UDim2.new(1 / #rewards, -8, 1, 0),
			BackgroundColor3 = UIKit.Colors.Panel,
			Parent = row,
		}, { UIKit.Corner(12) })
		local stroke = UIKit.Stroke(UIKit.Colors.Outline, 3)
		stroke.Parent = tile
		UIKit.Label({ Text = `Day {day}`, Size = UDim2.new(1, -8, 0, 26), Position = UDim2.fromOffset(4, 6), Parent = tile })
		UIKit.Label({
			Text = if rewards[day].Rarity then "🎁" else "💵",
			Size = UDim2.new(1, 0, 0, 40),
			Position = UDim2.fromOffset(0, 36),
			Parent = tile,
		})
		local amount = UIKit.Label({
			Text = "",
			TextColor3 = Color3.fromRGB(140, 255, 140),
			TextWrapped = true,
			Size = UDim2.new(1, -8, 0, 52),
			Position = UDim2.fromOffset(4, 84),
			Parent = tile,
		})
		tiles[day] = { Frame = tile, Stroke = stroke, Amount = amount }
	end

	local statusLabel = UIKit.Label({
		Text = "",
		TextColor3 = UIKit.Colors.SubText,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 160),
		Parent = content,
	})

	local claimButton = UIKit.Button({
		Text = "CLAIM",
		Color = UIKit.Colors.Green,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(220, 54),
		Parent = content,
	}, function()
		local ok, message = Remotes.ClaimDaily:InvokeServer()
		NotificationController.Notify(message, if ok then "success" else "error")
	end)

	local function refresh()
		local nextDay = player:GetAttribute("DailyDay") or 1
		local nextAt = player:GetAttribute("DailyNextAt") or 0
		local income = player:GetAttribute("Income") or 0
		local currentIndex = ((nextDay - 1) % #rewards) + 1

		for day, tile in tiles do
			local cash, rarity = Economy.GetDailyReward(day, income)
			tile.Amount.Text = Format.Money(cash) .. (if rarity then ` + {rarity} critter` else "")
			local isCurrent = day == currentIndex
			tile.Stroke.Color = if isCurrent then UIKit.Colors.Gold else UIKit.Colors.Outline
			tile.Frame.BackgroundColor3 = if day < currentIndex then UIKit.Colors.Background else UIKit.Colors.Panel
		end

		local remaining = nextAt - workspace:GetServerTimeNow()
		if remaining > 0 then
			statusLabel.Text = `Next reward in {Format.Time(remaining)}`
			claimButton.Text = "COME BACK LATER"
			UIKit.SetButtonColor(claimButton, UIKit.Colors.Disabled)
		else
			statusLabel.Text = `Day {nextDay} reward is ready! Don't break your streak.`
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
