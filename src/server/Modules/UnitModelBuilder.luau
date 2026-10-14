--[[
	UnitModelBuilder
	Builds a critter model out of simple parts (no assets needed), or clones
	ReplicatedStorage.Assets.Critters[<name>] if you made a custom model.

	Rig layout:
		HumanoidRootPart (invisible, root)
		  └─ Motor6D "Bounce" -> Head (main body; the client animates this motor for a cute waddle)
		Every other part is welded to Head.
		Humanoid (HipHeight computed so the feet touch the ground).

	Model attributes: StandOffset (height of the root above the ground).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Units = require(Shared.Config.Units)

local UnitModelBuilder = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(20, 20, 25)

local function newPart(props): BasePart
	local className = props.ClassName or "Part"
	local part = Instance.new(className) :: BasePart
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = true
	for key, value in props do
		if key ~= "ClassName" and key ~= "Paint" then
			(part :: any)[key] = value
		end
	end
	if props.Paint then
		part:SetAttribute("Paint", true)
	end
	return part
end

local function ball(name: string, diameter: number, cframe: CFrame, color: Color3, paint: boolean?): BasePart
	return newPart({
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * diameter,
		CFrame = cframe,
		Color = color,
		Paint = paint,
	})
end

local function block(name: string, size: Vector3, cframe: CFrame, color: Color3, paint: boolean?): BasePart
	return newPart({ Name = name, Size = size, CFrame = cframe, Color = color, Paint = paint })
end

local function wedge(name: string, size: Vector3, cframe: CFrame, color: Color3, paint: boolean?): BasePart
	return newPart({ ClassName = "WedgePart", Name = name, Size = size, CFrame = cframe, Color = color, Paint = paint })
end

-- Cylinders are aligned with the X axis; rotate them to stand upright.
local function disc(name: string, height: number, diameter: number, cframe: CFrame, color: Color3, paint: boolean?): BasePart
	return newPart({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = cframe * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Paint = paint,
	})
end

-- Every feature receives the scale and colours, returns the parts it created.
-- Positions are relative to the body centre; the body radius is 1.5 * s and the front is -Z.
local FEATURES = {}

function FEATURES.Ears(s: number, body: Color3, accent: Color3)
	return {
		wedge("EarL", Vector3.new(0.35, 1, 0.8) * s, CFrame.new(-0.7 * s, 1.55 * s, 0) * CFrame.Angles(0, 0, math.rad(15)), accent, true),
		wedge("EarR", Vector3.new(0.35, 1, 0.8) * s, CFrame.new(0.7 * s, 1.55 * s, 0) * CFrame.Angles(0, 0, math.rad(-15)), accent, true),
	}
end

function FEATURES.Horns(s: number)
	local ivory = Color3.fromRGB(245, 235, 210)
	return {
		wedge("HornL", Vector3.new(0.3, 0.9, 0.5) * s, CFrame.new(-0.65 * s, 1.6 * s, -0.25 * s) * CFrame.Angles(math.rad(-10), 0, math.rad(20)), ivory),
		wedge("HornR", Vector3.new(0.3, 0.9, 0.5) * s, CFrame.new(0.65 * s, 1.6 * s, -0.25 * s) * CFrame.Angles(math.rad(-10), 0, math.rad(-20)), ivory),
	}
end

function FEATURES.Antenna(s: number, body: Color3, accent: Color3)
	local tip = ball("AntennaTip", 0.45 * s, CFrame.new(0, 2.5 * s, 0), accent)
	tip.Material = Enum.Material.Neon
	return {
		disc("AntennaStick", 1.1 * s, 0.15 * s, CFrame.new(0, 1.9 * s, 0), BLACK),
		tip,
	}
end

function FEATURES.Spikes(s: number, body: Color3, accent: Color3)
	return {
		wedge("Spike1", Vector3.new(0.25, 0.7, 0.8) * s, CFrame.new(0, 1.45 * s, 0.35 * s), accent, true),
		wedge("Spike2", Vector3.new(0.25, 0.7, 0.8) * s, CFrame.new(0, 1.15 * s, 0.95 * s) * CFrame.Angles(math.rad(-35), 0, 0), accent, true),
		wedge("Spike3", Vector3.new(0.25, 0.6, 0.7) * s, CFrame.new(0, 0.55 * s, 1.4 * s) * CFrame.Angles(math.rad(-70), 0, 0), accent, true),
	}
end

function FEATURES.Wings(s: number, body: Color3, accent: Color3)
	local left = block("WingL", Vector3.new(0.15, 1.1, 1.7) * s, CFrame.new(-1.55 * s, 0.35 * s, 0.35 * s) * CFrame.Angles(0, 0, math.rad(-25)), accent, true)
	local right = block("WingR", Vector3.new(0.15, 1.1, 1.7) * s, CFrame.new(1.55 * s, 0.35 * s, 0.35 * s) * CFrame.Angles(0, 0, math.rad(25)), accent, true)
	left.Transparency = 0.15
	right.Transparency = 0.15
	return { left, right }
end

function FEATURES.Crown(s: number)
	local gold = Color3.fromRGB(255, 200, 40)
	local parts = { disc("CrownBand", 0.4 * s, 1.3 * s, CFrame.new(0, 1.55 * s, 0), gold) }
	for i = 0, 4 do
		local angle = math.rad(i * 72)
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 0.55 * s
		table.insert(parts, block("CrownPoint", Vector3.new(0.22, 0.4, 0.22) * s, CFrame.new(offset + Vector3.new(0, 1.9 * s, 0)), gold))
	end
	for _, part in parts do
		part.Material = Enum.Material.Foil
	end
	return parts
end

function FEATURES.TopHat(s: number)
	return {
		disc("HatBrim", 0.12 * s, 1.7 * s, CFrame.new(0, 1.45 * s, 0), BLACK),
		disc("HatTop", 1 * s, 1.05 * s, CFrame.new(0, 2 * s, 0), BLACK),
	}
end

function FEATURES.Halo(s: number)
	local halo = disc("Halo", 0.1 * s, 1.5 * s, CFrame.new(0, 2.4 * s, 0), Color3.fromRGB(255, 240, 150))
	halo.Material = Enum.Material.Neon
	halo.Transparency = 0.25
	halo.CastShadow = false
	return { halo }
end

function FEATURES.Tail(s: number, body: Color3, accent: Color3)
	return {
		block("Tail", Vector3.new(0.4, 0.4, 1.2) * s, CFrame.new(0, -0.5 * s, 1.75 * s) * CFrame.Angles(math.rad(25), 0, 0), accent, true),
	}
end

function FEATURES.Shell(s: number, body: Color3, accent: Color3)
	return {
		ball("Shell", 2 * s, CFrame.new(0, 0.6 * s, 0.9 * s), accent, true),
	}
end

function FEATURES.Beak(s: number)
	return {
		wedge("Beak", Vector3.new(0.6, 0.35, 0.6) * s, CFrame.new(0, 0, -1.65 * s), Color3.fromRGB(255, 160, 40)),
	}
end

function FEATURES.Fin(s: number, body: Color3, accent: Color3)
	return {
		wedge("Fin", Vector3.new(0.2, 1, 1.3) * s, CFrame.new(0, 1.75 * s, 0.25 * s), accent, true),
	}
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
		local head = model:FindFirstChild("Head")
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
	local head = model:FindFirstChild("Head")
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

local function buildProcedural(def: Units.UnitDef): Model
	local rarityInfo = Rarities.Info[def.Rarity]
	local s = rarityInfo.Scale
	local model = Instance.new("Model")
	model.Name = def.Name

	local rootSize = Vector3.new(2.6, 2.6, 2.6) * s
	local root = newPart({
		Name = "HumanoidRootPart",
		Size = rootSize,
		Transparency = 1,
		CanCollide = true,
		Massless = false,
		CastShadow = false,
		CFrame = CFrame.new(),
	})
	root.Parent = model
	model.PrimaryPart = root

	-- Named "Head" so every Humanoid feature that looks for a head is happy.
	local head = ball("Head", 3 * s, CFrame.new(), def.Body, true)
	head.Parent = model

	local bounce = Instance.new("Motor6D")
	bounce.Name = "Bounce"
	bounce.Part0 = root
	bounce.Part1 = head
	bounce.Parent = root

	local belly = def.Body:Lerp(WHITE, 0.4)
	local parts = {
		ball("Belly", 2.1 * s, CFrame.new(0, -0.4 * s, -0.55 * s), belly, true),
		ball("EyeL", 0.75 * s, CFrame.new(-0.5 * s, 0.45 * s, -1.2 * s), WHITE),
		ball("EyeR", 0.75 * s, CFrame.new(0.5 * s, 0.45 * s, -1.2 * s), WHITE),
		ball("PupilL", 0.4 * s, CFrame.new(-0.5 * s, 0.45 * s, -1.48 * s), BLACK),
		ball("PupilR", 0.4 * s, CFrame.new(0.5 * s, 0.45 * s, -1.48 * s), BLACK),
		ball("ShineL", 0.14 * s, CFrame.new(-0.44 * s, 0.53 * s, -1.66 * s), WHITE),
		ball("ShineR", 0.14 * s, CFrame.new(0.56 * s, 0.53 * s, -1.66 * s), WHITE),
		block("Mouth", Vector3.new(0.5, 0.12, 0.1) * s, CFrame.new(0, -0.05 * s, -1.47 * s), BLACK),
		ball("FootL", 0.8 * s, CFrame.new(-0.6 * s, -1.45 * s, -0.2 * s), def.Accent, true),
		ball("FootR", 0.8 * s, CFrame.new(0.6 * s, -1.45 * s, -0.2 * s), def.Accent, true),
	}

	for _, featureName in def.Features do
		local builder = FEATURES[featureName]
		if builder then
			for _, part in builder(s, def.Body, def.Accent) do
				table.insert(parts, part)
			end
		else
			warn(`[UnitModelBuilder] Unknown feature "{featureName}" on {def.Name}`)
		end
	end

	for _, part in parts do
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = part
		weld.Parent = part
	end

	-- Feet bottom is 1.85 * s below the root centre.
	local standOffset = 1.85 * s
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = standOffset - rootSize.Y / 2
	humanoid.Parent = model

	model:SetAttribute("StandOffset", standOffset)
	return model
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
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Info"
	billboard.Size = UDim2.fromScale(7, 3.6)
	billboard.StudsOffset = Vector3.new(0, standOffset + 2.6, 0)
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
		model = buildProcedural(def)
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
