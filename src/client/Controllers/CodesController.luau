--[[
	CodesController
	Promo code window (codes are defined in GameConfig.Codes on the server).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local UIKit = require(script.Parent.Parent.UI.UIKit)
local NotificationController = require(script.Parent.NotificationController)

local CodesController = {}

local Create = UIKit.Create

function CodesController.Start()
	local screen = UIKit.Screen("Codes", 5)
	local window = UIKit.CreateWindow(screen, "Codes", "🏷️ CODES", Vector2.new(420, 260), UIKit.Colors.Green)
	local content = window.Content

	UIKit.Label({
		Text = "Follow the game for new codes!",
		TextColor3 = UIKit.Colors.SubText,
		Size = UDim2.new(1, 0, 0, 24),
		StrokeThickness = 1,
		Parent = content,
	})

	local box = Create("TextBox", {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = UIKit.Colors.Background,
		Font = UIKit.Font,
		PlaceholderText = "Enter code...",
		PlaceholderColor3 = UIKit.Colors.SubText,
		Text = "",
		TextColor3 = UIKit.Colors.Text,
		TextScaled = true,
		ClearTextOnFocus = false,
		Parent = content,
	}, {
		UIKit.Corner(12),
		UIKit.Stroke(UIKit.Colors.Outline, 3),
		UIKit.Padding(10),
	})

	local busy = false
	UIKit.Button({
		Text = "REDEEM",
		Color = UIKit.Colors.Green,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(200, 54),
		Parent = content,
	}, function()
		if busy or box.Text == "" then
			return
		end
		busy = true
		local ok, message = Remotes.RedeemCode:InvokeServer(box.Text)
		NotificationController.Notify(message, if ok then "success" else "error")
		if ok then
			box.Text = ""
		end
		busy = false
	end)
end

return CodesController
