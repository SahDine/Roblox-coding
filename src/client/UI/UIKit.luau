--[[
	UIKit
	Small helpers to build a consistent, cartoony UI from code:
	instance factory, buttons with press feedback, responsive scaling and
	a window manager (only one window open at a time).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UIKit = {}

UIKit.Font = Enum.Font.FredokaOne

UIKit.Colors = {
	Background = Color3.fromRGB(28, 30, 46),
	Panel = Color3.fromRGB(40, 43, 64),
	PanelLight = Color3.fromRGB(58, 62, 92),
	Outline = Color3.fromRGB(15, 16, 26),
	Text = Color3.fromRGB(255, 255, 255),
	SubText = Color3.fromRGB(190, 195, 220),
	Green = Color3.fromRGB(70, 205, 95),
	Blue = Color3.fromRGB(60, 150, 255),
	Gold = Color3.fromRGB(255, 195, 45),
	Red = Color3.fromRGB(235, 70, 80),
	Purple = Color3.fromRGB(160, 90, 255),
	Robux = Color3.fromRGB(0, 176, 111),
	Disabled = Color3.fromRGB(95, 98, 120),
}

local player = Players.LocalPlayer

function UIKit.Create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local Create = UIKit.Create

function UIKit.Corner(radius: number?): UICorner
	return Create("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function UIKit.Stroke(color: Color3?, thickness: number?): UIStroke
	return Create("UIStroke", {
		Color = color or UIKit.Colors.Outline,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UIKit.TextStroke(thickness: number?): UIStroke
	return Create("UIStroke", {
		Color = UIKit.Colors.Outline,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function UIKit.Padding(pixels: number): UIPadding
	local padding = UDim.new(0, pixels)
	return Create("UIPadding", {
		PaddingTop = padding,
		PaddingBottom = padding,
		PaddingLeft = padding,
		PaddingRight = padding,
	})
end

function UIKit.Gradient(top: Color3, bottom: Color3): UIGradient
	return Create("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
	})
end

function UIKit.Label(props: { [string]: any }): TextLabel
	local label = Create("TextLabel", {
		BackgroundTransparency = 1,
		Font = UIKit.Font,
		TextColor3 = UIKit.Colors.Text,
		TextScaled = true,
	}, { UIKit.TextStroke(props.StrokeThickness) })
	for key, value in props do
		if key ~= "StrokeThickness" then
			if key == "Parent" then
				continue
			end
			(label :: any)[key] = value
		end
	end
	if props.Parent then
		label.Parent = props.Parent
	end
	return label
end

-- Coloured button with a darker gradient, outline and a squash animation.
function UIKit.Button(props: { [string]: any }, onClick: (() -> ())?): TextButton
	local color = props.Color or UIKit.Colors.Blue
	local button = Create("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Font = UIKit.Font,
		TextColor3 = UIKit.Colors.Text,
		TextScaled = true,
		Text = "",
	}, {
		UIKit.Corner(props.CornerRadius or 12),
		UIKit.Stroke(),
		Create("UIGradient", {
			Name = "Fill",
			Color = ColorSequence.new(color, color:Lerp(Color3.new(0, 0, 0), 0.25)),
			Rotation = 90,
		}),
		Create("UIPadding", {
			PaddingTop = UDim.new(0.12, 0),
			PaddingBottom = UDim.new(0.12, 0),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
		UIKit.TextStroke(2),
	})
	local scale = Create("UIScale", { Parent = button })

	for key, value in props do
		if key ~= "Color" and key ~= "CornerRadius" and key ~= "Parent" then
			(button :: any)[key] = value
		end
	end

	local pressInfo = TweenInfo.new(0.08, Enum.EasingStyle.Quad)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, pressInfo, { Scale = 0.9 }):Play()
	end)
	local function release()
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	if onClick then
		button.Activated:Connect(onClick)
	end

	if props.Parent then
		button.Parent = props.Parent
	end
	return button
end

function UIKit.SetButtonColor(button: TextButton, color: Color3)
	local fill = button:FindFirstChild("Fill") :: UIGradient?
	if fill then
		fill.Color = ColorSequence.new(color, color:Lerp(Color3.new(0, 0, 0), 0.25))
	end
end

-- Screen ----------------------------------------------------------------------

function UIKit.Screen(name: string, displayOrder: number?): ScreenGui
	return Create("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 0,
		Parent = player:WaitForChild("PlayerGui"),
	})
end

-- Keeps the UI readable on phones and not huge on big monitors.
local scales: { UIScale } = {}

local function computeScale(): number
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.55, 1.15)
end

function UIKit.AttachScale(guiObject: GuiObject): UIScale
	local scale = Create("UIScale", { Scale = computeScale(), Parent = guiObject })
	table.insert(scales, scale)
	return scale
end

local function hookViewport()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local value = computeScale()
			for _, scale in scales do
				scale.Scale = value
			end
		end)
	end
end
hookViewport()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookViewport)

-- Windows -----------------------------------------------------------------------

export type Window = {
	Name: string,
	Frame: Frame,
	Content: Frame,
	BaseSize: UDim2,
	OnOpen: (() -> ())?,
	IsOpen: boolean,
}

local windows: { [string]: Window } = {}

function UIKit.CreateWindow(screen: ScreenGui, name: string, title: string, size: Vector2, accent: Color3?): Window
	local frame = Create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = screen,
	}, {
		UIKit.Corner(18),
		UIKit.Stroke(UIKit.Colors.Outline, 4),
		UIKit.Gradient(UIKit.Colors.PanelLight, UIKit.Colors.Background),
	})
	UIKit.AttachScale(frame)

	UIKit.Label({
		Name = "Title",
		Text = title,
		TextColor3 = accent or UIKit.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(18, 8),
		Size = UDim2.new(1, -80, 0, 44),
		StrokeThickness = 3,
		Parent = frame,
	})

	local window: Window = {
		Name = name,
		Frame = frame,
		Content = Create("Frame", {
			Name = "Content",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(14, 60),
			Size = UDim2.new(1, -28, 1, -74),
			Parent = frame,
		}),
		BaseSize = UDim2.fromOffset(size.X, size.Y),
		IsOpen = false,
	}

	UIKit.Button({
		Name = "Close",
		Text = "X",
		Color = UIKit.Colors.Red,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(42, 42),
		Parent = frame,
	}, function()
		UIKit.CloseWindow(name)
	end)

	windows[name] = window
	return window
end

function UIKit.OpenWindow(name: string)
	for otherName, other in windows do
		if otherName ~= name and other.IsOpen then
			UIKit.CloseWindow(otherName)
		end
	end
	local window = windows[name]
	if not window or window.IsOpen then
		return
	end
	window.IsOpen = true
	if window.OnOpen then
		task.spawn(window.OnOpen)
	end
	local frame = window.Frame
	local target = window.BaseSize
	frame.Size = UDim2.fromOffset(target.X.Offset * 0.85, target.Y.Offset * 0.85)
	frame.Visible = true
	TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = target }):Play()
end

function UIKit.CloseWindow(name: string)
	local window = windows[name]
	if window and window.IsOpen then
		window.IsOpen = false
		window.Frame.Visible = false
	end
end

function UIKit.ToggleWindow(name: string)
	local window = windows[name]
	if window and window.IsOpen then
		UIKit.CloseWindow(name)
	else
		UIKit.OpenWindow(name)
	end
end

function UIKit.GetWindow(name: string): Window?
	return windows[name]
end

return UIKit
