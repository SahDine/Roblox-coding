--[[
	RebirthController
	Rebirth window: progress towards the next rebirth and what it gives.
]]

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

local RebirthController = {}

local player = Players.LocalPlayer
local Create = UIKit.Create

function RebirthController.Start()
	local screen = UIKit.Screen("Rebirth", 5)
	local window = UIKit.CreateWindow(screen, "Rebirth", "♻️ REBIRTH", Vector2.new(460, 340), UIKit.Colors.Purple)
	local content = window.Content

	local currentLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, 0, 0, 30), Parent = content })
	local nextLabel = UIKit.Label({
		Text = "",
		TextColor3 = Color3.fromRGB(140, 255, 140),
		Size = UDim2.new(1, 0, 0, 48),
		Position = UDim2.fromOffset(0, 36),
		TextWrapped = true,
		Parent = content,
	})
	UIKit.Label({
		Text = "Resets your cash. You keep all your critters!",
		TextColor3 = UIKit.Colors.SubText,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 90),
		StrokeThickness = 1,
		Parent = content,
	})

	local bar = Create("Frame", {
		Position = UDim2.fromOffset(0, 124),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = UIKit.Colors.Background,
		Parent = content,
	}, { UIKit.Corner(10), UIKit.Stroke(UIKit.Colors.Outline, 3) })
	local fill = Create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = bar,
	}, { UIKit.Corner(10), UIKit.Gradient(Color3.fromRGB(200, 140, 255), UIKit.Colors.Purple) })
	local progressLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromOffset(6, 3), ZIndex = 2, Parent = bar })

	local button
	button = UIKit.Button({
		Text = "REBIRTH",
		Color = UIKit.Colors.Purple,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(240, 58),
		Parent = content,
	}, function()
		local ok, message = Remotes.RequestRebirth:InvokeServer()
		NotificationController.Notify(message, if ok then "success" else "error")
	end)

	local function refresh()
		local rebirths = player:GetAttribute("Rebirths") or 0
		local cash = player:GetAttribute("Cash") or 0
		local cost = Economy.GetRebirthCost(rebirths)
		local current = Economy.GetRebirthMultiplier(rebirths)
		local nextMultiplier = Economy.GetRebirthMultiplier(rebirths + 1)
		local slots = GameConfig.Slots
		local slotBonus = if rebirths < slots.MaxFromRebirths / slots.PerRebirth then ` and +{slots.PerRebirth} slot` else ""

		currentLabel.Text = `Rebirths: {rebirths}  •  Cash bonus x{current}`
		nextLabel.Text = `Next: cash bonus x{nextMultiplier}{slotBonus}`

		local progress = math.clamp(cash / cost, 0, 1)
		TweenService:Create(fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(progress, 1) }):Play()
		progressLabel.Text = `{Format.Money(math.floor(cash))} / {Format.Money(cost)}`
		UIKit.SetButtonColor(button, if progress >= 1 then UIKit.Colors.Purple else UIKit.Colors.Disabled)
	end

	window.OnOpen = refresh
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		if window.IsOpen then
			refresh()
		end
	end)
	player:GetAttributeChangedSignal("Rebirths"):Connect(refresh)
	refresh()
end

return RebirthController
