--[[
	WorldController
	Client-side world logic:
	- shows only the prompts that make sense for you (Sell on yours, Steal on others');
	- base barriers: owners walk through, intruders are blocked, thieves inside can leave;
	- critter waddle/idle animation and rainbow mutation colours (purely visual);
	- beam + marker guiding you to your base;
	- slap knockback and the [VIP] chat tag.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)

local UIKit = require(script.Parent.Parent.UI.UIKit)

local WorldController = {}

local player = Players.LocalPlayer
local STEAL = GameConfig.Steal

-- Prompts -------------------------------------------------------------------------

local stealPrompts: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local evolvePrompts: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function applyPrompt(prompt: ProximityPrompt)
	local kind = prompt:GetAttribute("Kind")
	local ownerId = prompt:GetAttribute("OwnerUserId")
	if kind == "Sell" or kind == "Lock" then
		prompt.Enabled = ownerId == player.UserId
	elseif kind == "Evolve" or kind == "EvolveRobux" then
		-- "Evolve" once the critter is ready, "Ready now (Robux)" while it is still growing.
		local evolveAt = prompt:GetAttribute("EvolveAt")
		local ready = evolveAt ~= nil and workspace:GetServerTimeNow() >= evolveAt
		local wanted = if kind == "Evolve" then ready else evolveAt ~= nil and not ready
		prompt.Enabled = ownerId == player.UserId and wanted
	elseif kind == "Steal" then
		prompt.Enabled = ownerId ~= player.UserId
		prompt.HoldDuration = if player:GetAttribute("Pass_FastSteal") then STEAL.FastStealHoldDuration else STEAL.HoldDuration
	end
end

local function registerPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") or not prompt:GetAttribute("Kind") then
		return
	end
	applyPrompt(prompt)
	local kind = prompt:GetAttribute("Kind")
	if kind == "Steal" then
		stealPrompts[prompt] = true
	elseif kind == "Evolve" or kind == "EvolveRobux" then
		evolvePrompts[prompt] = true
		prompt:GetAttributeChangedSignal("EvolveAt"):Connect(function()
			applyPrompt(prompt)
		end)
	end
	prompt:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		applyPrompt(prompt)
	end)
end

local function setupPrompts()
	for _, descendant in workspace:GetDescendants() do
		registerPrompt(descendant)
	end
	workspace.DescendantAdded:Connect(registerPrompt)
	player:GetAttributeChangedSignal("Pass_FastSteal"):Connect(function()
		for prompt in stealPrompts do
			if prompt.Parent then
				applyPrompt(prompt)
			end
		end
	end)
end

-- Evolution timers ------------------------------------------------------------------

-- Updates the "EvolveTimer" line of every critter billboard and the evolve prompts.
local function updateEvolution()
	local now = workspace:GetServerTimeNow()
	for prompt in evolvePrompts do
		if prompt.Parent then
			applyPrompt(prompt)
		end
	end
	for _, model in CollectionService:GetTagged("Critter") do
		local evolveAt = model:GetAttribute("EvolveAt")
		local root = model:FindFirstChild("HumanoidRootPart")
		local info = root and root:FindFirstChild("Info")
		local label = info and info:FindFirstChild("EvolveTimer") :: TextLabel?
		if label and evolveAt then
			local target = model:GetAttribute("EvolveTarget") or "?"
			local remaining = evolveAt - now
			if remaining > 0 then
				label.Text = `🧬 {target} in {Format.Time(remaining)}`
				label.TextColor3 = Color3.fromRGB(150, 220, 255)
			else
				label.Text = `🧬 READY TO EVOLVE!`
				label.TextColor3 = Color3.fromRGB(255, 220, 80)
			end
		end
	end
end

-- Barriers ------------------------------------------------------------------------

local insideState: { [Instance]: boolean } = {}

local function updateBarriers()
	local plots = workspace:FindFirstChild("Plots")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not plots then
		return
	end

	for _, plot in plots:GetChildren() do
		local barrier = plot:FindFirstChild("Barrier") :: BasePart?
		local floor = plot:FindFirstChild("Floor") :: BasePart?
		if barrier and floor then
			local inside = false
			if root then
				-- Hysteresis: once inside you count as inside until you are fully past the barrier.
				local localPosition = floor.CFrame:PointToObjectSpace(root.Position)
				local frontMargin = if insideState[plot] then -3 else 1.5
				inside = math.abs(localPosition.X) <= floor.Size.X / 2
					and localPosition.Z <= floor.Size.Z / 2
					and localPosition.Z >= -floor.Size.Z / 2 + frontMargin
					and math.abs(localPosition.Y) < 30
			end
			insideState[plot] = inside

			local locked = barrier:GetAttribute("Locked") == true
			local isOwner = barrier:GetAttribute("OwnerUserId") == player.UserId
			barrier.CanCollide = locked and not isOwner and not inside
		end
	end
end

-- Home marker + carry beam --------------------------------------------------------------

local function getHomeMarker(): BasePart?
	local index = player:GetAttribute("PlotIndex")
	local plots = workspace:FindFirstChild("Plots")
	local plot = index and plots and plots:FindFirstChild("Plot_" .. index)
	return plot and plot:FindFirstChild("SpawnMarker") :: BasePart?
end

local function setupHomeGuides()
	local homeBillboard = UIKit.Create("BillboardGui", {
		Name = "YourBase",
		Size = UDim2.fromOffset(200, 50),
		StudsOffset = Vector3.new(0, 14, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	UIKit.Label({
		Text = "⭐ YOUR BASE",
		TextColor3 = UIKit.Colors.Gold,
		Size = UDim2.fromScale(1, 1),
		StrokeThickness = 3,
		Parent = homeBillboard,
	})

	local beam: Beam? = nil
	local beamAttachment: Attachment? = nil

	local function clearBeam()
		if beam then
			beam:Destroy()
			beam = nil
		end
		if beamAttachment then
			beamAttachment:Destroy()
			beamAttachment = nil
		end
	end

	local function refresh()
		local marker = getHomeMarker()
		homeBillboard.Adornee = marker
		homeBillboard.Enabled = marker ~= nil

		clearBeam()
		local carrying = player:GetAttribute("Carrying")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local target = marker and marker:FindFirstChild("Target") :: Attachment?
		if carrying and root and target then
			beamAttachment = UIKit.Create("Attachment", { Name = "HomeBeam", Parent = root })
			beam = UIKit.Create("Beam", {
				Attachment0 = beamAttachment,
				Attachment1 = target,
				Color = ColorSequence.new(Color3.fromRGB(120, 255, 120), Color3.fromRGB(255, 230, 80)),
				LightEmission = 1,
				FaceCamera = true,
				Width0 = 0.8,
				Width1 = 0.8,
				Transparency = NumberSequence.new(0.2),
				Parent = root,
			})
		end
	end

	player:GetAttributeChangedSignal("PlotIndex"):Connect(refresh)
	player:GetAttributeChangedSignal("Carrying"):Connect(refresh)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		refresh()
	end)
	refresh()
end

-- Knockback -----------------------------------------------------------------------------

local function setupKnockback()
	local generation = 0
	Remotes.Knockback.OnClientEvent:Connect(function(velocity: Vector3, stunTime: number)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid then
			return
		end
		generation += 1
		local myGeneration = generation
		humanoid.PlatformStand = true
		root.AssemblyLinearVelocity = velocity
		root.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-4, 4), math.random(-8, 8))
		task.delay(stunTime, function()
			if generation == myGeneration and humanoid.Parent then
				humanoid.PlatformStand = false
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	end)
end

-- VIP chat tag ----------------------------------------------------------------------------

local function setupChatTags()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local properties = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		local sender = source and Players:GetPlayerByUserId(source.UserId)
		if sender and sender:GetAttribute("Pass_VIP") then
			properties.PrefixText = `<font color="#FFD24A">[VIP]</font> {message.PrefixText}`
		end
		return properties
	end
end

function WorldController.Start()
	setupPrompts()
	setupHomeGuides()
	setupKnockback()
	setupChatTags()

	task.spawn(function()
		while true do
			updateBarriers()
			task.wait(0.1)
		end
	end)
	task.spawn(function()
		while true do
			updateEvolution()
			task.wait(0.5)
		end
	end)
end

return WorldController
