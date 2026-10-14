--[[
	NotificationController
	Toasts at the top of the screen. Server messages arrive through the
	Notify remote; client code can call NotificationController.Notify directly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)

local UIKit = require(script.Parent.Parent.UI.UIKit)

local NotificationController = {}

local MAX_TOASTS = 5

local STYLES = {
	info = { Color = UIKit.Colors.Blue, Duration = 3.5 },
	success = { Color = UIKit.Colors.Green, Duration = 3.5 },
	error = { Color = UIKit.Colors.Red, Duration = 3 },
	alert = { Color = UIKit.Colors.Red, Duration = 5, Sound = true },
	announce = { Color = UIKit.Colors.Gold, Duration = 6, Sound = true, Big = true },
}

local container: Frame
local sound: Sound
local counter = 0

function NotificationController.Notify(message: string, kind: string?)
	if not container then
		return
	end
	local style = STYLES[kind or "info"] or STYLES.info

	local toasts = {}
	for _, child in container:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts >= MAX_TOASTS then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end

	local height = if style.Big then 54 else 40
	counter += 1
	local toast = UIKit.Create("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = UIKit.Colors.Background,
		BackgroundTransparency = 0.15,
		LayoutOrder = counter,
		Parent = container,
	}, {
		UIKit.Corner(12),
		UIKit.Stroke(style.Color, 3),
	})
	local label = UIKit.Label({
		Text = message,
		TextColor3 = if style.Big then UIKit.Colors.Gold else UIKit.Colors.Text,
		Size = UDim2.new(1, -20, 1, -10),
		Position = UDim2.fromOffset(10, 5),
		Parent = toast,
	})

	if style.Sound and sound then
		SoundService:PlayLocalSound(sound)
	end

	task.delay(style.Duration, function()
		if not toast.Parent then
			return
		end
		local fade = TweenInfo.new(0.4)
		TweenService:Create(toast, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		for _, child in toast:GetChildren() do
			if child:IsA("UIStroke") then
				TweenService:Create(child, fade, { Transparency = 1 }):Play()
			end
		end
		task.wait(0.4)
		toast:Destroy()
	end)
end

function NotificationController.Start()
	local screen = UIKit.Screen("Notifications", 10)
	container = UIKit.Create("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(560, 320),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		UIKit.Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})
	UIKit.AttachScale(container)

	sound = UIKit.Create("Sound", {
		SoundId = GameConfig.Sounds.Notify,
		Volume = 0.5,
		Parent = screen,
	})

	Remotes.Notify.OnClientEvent:Connect(function(message, kind)
		NotificationController.Notify(message, kind)
	end)
end

return NotificationController
