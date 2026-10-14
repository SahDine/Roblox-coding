--[[
	UnitModelBuilder
	Builds critter models: the sculpted design from CritterDesigns, or
	ReplicatedStorage.Assets.Critters[<name>] if you made a custom model.

	Rig layout:
		HumanoidRootPart (invisible, root)
		  └─ Motor6D "Bounce" -> Body (the client animates this motor for a cute waddle)
		Every other part is welded to Body.
		Humanoid (HipHeight computed so the feet touch the ground).

	Model attributes: StandOffset (height of the root above the ground), Scale, Height, Floats.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Units = require(Shared.Config.Units)

local CritterBuilder = require(script.Parent.CritterBuilder)
local CritterDesigns = require(script.Parent.CritterDesigns)

local UnitModelBuilder = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

-- Main body part (the one animated by the client).
local function getCore(model: Model): BasePart?
	local root = model.PrimaryPart
	local bounce = root and root:FindFirstChild("Bounce")
	if bounce and bounce:IsA("Motor6D") and bounce.Part1 then
		return bounce.Part1
	end
	local fallback = model:FindFirstChild("Body") or model:FindFirstChild("Head")
	if fallback and fallback:IsA("BasePart") then
		return fallback
	end
	return root
end

local function applyMutation(model: Model, mutation: string)
	local info = Mutations.Get(mutation)
	if mutation == "None" or not info.Color then
		return
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("Paint") then
			part.Color = info.Color
			part.Material = info.Material or part.Material
			if info.Transparency then
				part.Transparency = math.max(part.Transparency, info.Transparency)
			end
		end
	end
	if info.Stars then
		local head = getCore(model)
		if head then
			local stars = Instance.new("ParticleEmitter")
			stars.Name = "Stars"
			stars.Color = ColorSequence.new(Color3.fromRGB(220, 200, 255))
			stars.LightEmission = 1
			stars.Rate = 8
			stars.Lifetime = NumberRange.new(1, 2)
			stars.Speed = NumberRange.new(0.5, 1.5)
			stars.Size = NumberSequence.new(0.25, 0)
			stars.Parent = head
		end
	end
end

local function addRarityEffects(model: Model, rarity: string)
	local info = Rarities.Info[rarity]
	local head = getCore(model)
	if not head then
		return
	end
	if info.Glow then
		local light = Instance.new("PointLight")
		light.Color = info.Color
		light.Brightness = 1.5
		light.Range = 10
		light.Parent = head
	end
	if info.Sparkles then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "Sparkles"
		sparkles.Color = ColorSequence.new(info.Color)
		sparkles.LightEmission = 0.8
		sparkles.Rate = if rarity == "Secret" then 14 else 6
		sparkles.Lifetime = NumberRange.new(0.8, 1.4)
		sparkles.Speed = NumberRange.new(1, 3)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.35, 0)
		sparkles.Parent = head
	end
end

local function buildDesigned(def: Units.UnitDef): Model
	local accent = def.Accent or def.Body:Lerp(BLACK, 0.3)
	local palette = {
		Body = def.Body,
		Accent = accent,
		Belly = def.Belly or def.Body:Lerp(WHITE, 0.55),
		Extra = def.Extra or accent:Lerp(BLACK, 0.2),
	}
	local builder = CritterBuilder.new(def.Name, Rarities.Info[def.Rarity].Scale, palette)
	local design = CritterDesigns[def.Name] or CritterDesigns.Generic
	design(builder)
	return builder:Finish()
end

local function buildFromTemplate(template: Model): Model?
	local model = template:Clone()
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		warn(`[UnitModelBuilder] Custom model "{template.Name}" needs a part named HumanoidRootPart`)
		return nil
	end
	model.PrimaryPart = root

	local cframe, size = model:GetBoundingBox()
	local standOffset = root.Position.Y - (cframe.Position.Y - size.Y / 2)

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = part == root
			part.Massless = part ~= root
		end
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid") or Instance.new("Humanoid")
	humanoid.HipHeight = standOffset - root.Size.Y / 2
	humanoid.Parent = model

	model:SetAttribute("StandOffset", standOffset)
	model:SetAttribute("Scale", 1)
	model:SetAttribute("Height", standOffset + (cframe.Position.Y + size.Y / 2 - root.Position.Y))
	return model
end

local function makeLabel(name: string, text: string, color: Color3, order: number, height: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, height)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.LayoutOrder = order
	return label
end

-- Billboard above the critter: mutation, name, rarity, income and optional price.
function UnitModelBuilder.CreateInfoBillboard(model: Model, unitName: string, mutation: string, priceText: string?, robuxText: string?)
	local def = Units.ByName[unitName]
	local root = model.PrimaryPart
	if not def or not root then
		return
	end

	local old = root:FindFirstChild("Info")
	if old then
		old:Destroy()
	end

	local standOffset = model:GetAttribute("StandOffset") or 2
	local height = model:GetAttribute("Height") or standOffset * 2
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Info"
	billboard.Size = UDim2.fromScale(7, 3.6)
	billboard.StudsOffset = Vector3.new(0, height - standOffset + 1.9, 0)
	billboard.MaxDistance = 70
	billboard.LightInfluence = 0

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = billboard

	local mutationInfo = Mutations.Get(mutation)
	if mutation ~= "None" then
		makeLabel("Mutation", string.upper(mutation), mutationInfo.TextColor, 1, 0.18).Parent = billboard
	end
	makeLabel("UnitName", unitName, Color3.new(1, 1, 1), 2, 0.24).Parent = billboard
	makeLabel("Rarity", def.Rarity, Rarities.Info[def.Rarity].Color, 3, 0.17).Parent = billboard

	local income = def.Income * mutationInfo.Multiplier
	makeLabel("Income", Format.Money(income) .. "/s", Color3.fromRGB(110, 255, 110), 4, 0.17).Parent = billboard

	if priceText then
		makeLabel("Price", priceText, Color3.fromRGB(255, 220, 70), 5, 0.2).Parent = billboard
	end
	if robuxText then
		makeLabel("Robux", robuxText, Color3.fromRGB(120, 255, 160), 6, 0.16).Parent = billboard
	end

	billboard.Parent = root
end

function UnitModelBuilder.Build(unitName: string, mutation: string): Model?
	local def = Units.ByName[unitName]
	if not def then
		warn(`[UnitModelBuilder] Unknown unit "{unitName}"`)
		return nil
	end

	local model: Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local critters = assets and assets:FindFirstChild("Critters")
	local template = critters and critters:FindFirstChild(unitName)
	if template and template:IsA("Model") then
		model = buildFromTemplate(template)
	end
	if not model then
		model = buildDesigned(def)
	end
	assert(model, "unreachable")

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	-- R15 honours HipHeight for rigs without legs: the root floats HipHeight above the ground.
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.AutoJumpEnabled = false
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	for _, state in
		{
			Enum.HumanoidStateType.Dead,
			Enum.HumanoidStateType.FallingDown,
			Enum.HumanoidStateType.Ragdoll,
			Enum.HumanoidStateType.Climbing,
			Enum.HumanoidStateType.Swimming,
			Enum.HumanoidStateType.Seated,
			Enum.HumanoidStateType.Jumping,
			Enum.HumanoidStateType.Flying,
		}
	do
		humanoid:SetStateEnabled(state, false)
	end

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Critters"
		end
	end

	applyMutation(model, mutation)
	addRarityEffects(model, def.Rarity)

	-- Stream the whole critter at once if StreamingEnabled is turned on.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("UnitName", unitName)
	model:SetAttribute("Mutation", mutation)
	model:SetAttribute("Rarity", def.Rarity)
	CollectionService:AddTag(model, "Critter")

	return model
end

-- CFrame of the root so that the critter stands on `groundPosition`, facing `lookDirection`.
function UnitModelBuilder.GetStandingCFrame(model: Model, groundPosition: Vector3, lookDirection: Vector3): CFrame
	local offset = model:GetAttribute("StandOffset") or 2
	local position = groundPosition + Vector3.new(0, offset, 0)
	local flat = Vector3.new(lookDirection.X, 0, lookDirection.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(position, position + flat.Unit)
end

-- Anchored = sits still on a pedestal. Unanchored = walks with its Humanoid.
function UnitModelBuilder.SetAnchored(model: Model, anchored: boolean)
	local root = model.PrimaryPart
	if not root then
		return
	end
	root.Anchored = anchored
	if not anchored and root:IsDescendantOf(workspace) then
		pcall(root.SetNetworkOwner, root, nil)
	end
end

-- Used while a critter is carried by a thief: physics off, weightless.
function UnitModelBuilder.SetCarried(model: Model, carried: boolean)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = carried
		humanoid.EvaluateStateMachine = not carried
	end
	local root = model.PrimaryPart
	if root then
		root.Massless = carried
		root.CanCollide = not carried
	end
end

return UnitModelBuilder
