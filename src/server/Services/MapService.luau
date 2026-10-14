--[[
	MapService
	Builds the fantasy world at server start: terrain (meadow, plaza, paths,
	ponds, hills), the enchanted conveyor with its portals, the spawn,
	decorations (giant mushrooms, crystals, magic trees, floating islands,
	fireflies) and the lighting. Player bases are built by PlotService.
]]

local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local Decor = require(script.Parent.Parent.Modules.Decor)

local MapService = {}

local MAP = GameConfig.Map
local HALF_CONVEYOR = MAP.ConveyorLength / 2
local PLOT_FRONT = MAP.PlotDistanceFromCenter - MAP.PlotDepth / 2
local PLOT_BACK = MAP.PlotDistanceFromCenter + MAP.PlotDepth / 2

-- Playable area (invisible walls on its edges).
MapService.HalfWidth = HALF_CONVEYOR + 90
MapService.HalfDepth = PLOT_BACK + 50

MapService.BeltHeight = 0.4
MapService.ConveyorStart = Vector3.new(-HALF_CONVEYOR, MapService.BeltHeight, 0)
MapService.ConveyorEnd = Vector3.new(HALF_CONVEYOR, MapService.BeltHeight, 0)
MapService.SpawnPosition = Vector3.new(-HALF_CONVEYOR - 45, 0, 0)

local STONE = Color3.fromRGB(150, 145, 160)
local DARK_STONE = Color3.fromRGB(70, 65, 85)
local GOLD = Color3.fromRGB(255, 205, 80)
local MAGIC = Color3.fromRGB(170, 110, 255)

local function newPart(props, parent: Instance): BasePart
	local part = Decor.Part(props, parent)
	if props.CollisionGroup == nil then
		part.CollisionGroup = "Default"
	end
	return part
end

MapService.NewPart = newPart

local function registerCollisionGroups()
	for _, name in { "Players", "Critters", "Decor" } do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	-- Critters walk through players, each other and props; they only stand on the ground.
	PhysicsService:CollisionGroupSetCollidable("Critters", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("Critters", "Critters", false)
	PhysicsService:CollisionGroupSetCollidable("Critters", "Decor", false)
end

local function setupLighting()
	Lighting.ClockTime = 16.6
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(70, 60, 90)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 135, 175)
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 0.7
	Lighting.GlobalShadows = true

	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.15
	atmosphere.Haze = 1.2
	atmosphere.Glare = 0.4
	atmosphere.Color = Color3.fromRGB(225, 200, 255)
	atmosphere.Decay = Color3.fromRGB(150, 110, 200)
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 26
	bloom.Threshold = 1.3
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.18
	color.Contrast = 0.05
	color.TintColor = Color3.fromRGB(255, 245, 255)
	color.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	rays.Parent = Lighting
end

local function buildTerrain()
	local terrain = workspace.Terrain
	local width = MapService.HalfWidth * 2 + 160
	local depth = MapService.HalfDepth * 2 + 160

	-- Meadow (top surface exactly at y = 0).
	terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(width, 12, depth), Enum.Material.Grass)

	-- Cobblestone plaza along the conveyor.
	terrain:FillBlock(CFrame.new(0, -2, 0), Vector3.new(MAP.ConveyorLength + 40, 4, 36), Enum.Material.Cobblestone)

	-- Dirt paths from the plaza to every base gate.
	local perSide = math.ceil(MAP.PlotCount / 2)
	for column = 0, perSide - 1 do
		local x = (column - (perSide - 1) / 2) * MAP.PlotSpacing
		for _, side in { -1, 1 } do
			local length = PLOT_FRONT - 18
			terrain:FillBlock(CFrame.new(x, -2, side * (18 + length / 2)), Vector3.new(16, 4, length), Enum.Material.Ground)
		end
	end

	-- Spawn courtyard.
	terrain:FillCylinder(
		CFrame.new(MapService.SpawnPosition - Vector3.new(0, 2, 0)),
		4,
		30,
		Enum.Material.Pavement
	)

	-- Ponds at both ends of the plaza.
	for _, position in
		{
			Vector3.new(HALF_CONVEYOR + 50, 0, 60),
			Vector3.new(HALF_CONVEYOR + 50, 0, -60),
			Vector3.new(-HALF_CONVEYOR - 50, 0, 70),
			Vector3.new(-HALF_CONVEYOR - 50, 0, -70),
		}
	do
		terrain:FillCylinder(CFrame.new(position - Vector3.new(0, 3, 0)), 6, 22, Enum.Material.Water)
		for index = 1, 6 do
			local angle = index * 1.05
			terrain:FillBall(position + Vector3.new(math.cos(angle) * 24, -1, math.sin(angle) * 24), 4, Enum.Material.Rock)
		end
	end

	-- Hills and cliffs around the playable area (the horizon).
	local random = Random.new(7)
	local halfW, halfD = MapService.HalfWidth, MapService.HalfDepth
	for x = -halfW - 40, halfW + 40, 45 do
		for _, side in { -1, 1 } do
			local position = Vector3.new(x + random:NextNumber(-10, 10), random:NextNumber(-12, 4), side * (halfD + random:NextNumber(30, 55)))
			local radius = random:NextNumber(32, 52)
			terrain:FillBall(position, radius, Enum.Material.Grass)
			terrain:FillBall(position + Vector3.new(0, radius * 0.55, 0), radius * 0.45, Enum.Material.Rock)
		end
	end
	for z = -halfD, halfD, 45 do
		for _, side in { -1, 1 } do
			local position = Vector3.new(side * (halfW + random:NextNumber(30, 55)), random:NextNumber(-12, 4), z + random:NextNumber(-10, 10))
			local radius = random:NextNumber(32, 52)
			terrain:FillBall(position, radius, Enum.Material.Grass)
			terrain:FillBall(position + Vector3.new(0, radius * 0.55, 0), radius * 0.45, Enum.Material.Rock)
		end
	end
end

local function makeSurfaceText(part: BasePart, face: Enum.NormalId, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Parent = gui
	gui.Parent = part
end

-- Stone arch with a swirling magic disc where critters appear / leave.
local function buildPortal(folder: Folder, x: number, text: string, color: Color3)
	local portal = Instance.new("Model")
	portal.Name = "Portal"
	portal.Parent = folder
	local radius = MAP.ConveyorWidth / 2 + 5
	local center = Vector3.new(x, radius, 0)

	for index = 0, 12 do
		local angle = math.pi * index / 12
		local position = center + Vector3.new(0, math.sin(angle) * radius, math.cos(angle) * radius)
		Decor.Part({
			Name = "ArchStone",
			Size = Vector3.new(3.2, 3.2, 3.6),
			CFrame = CFrame.new(position) * CFrame.Angles(angle, 0, 0),
			Color = if index % 2 == 0 then STONE else DARK_STONE,
			Material = Enum.Material.Slate,
		}, portal)
	end
	for _, side in { -1, 1 } do
		Decor.Part({
			Name = "Pillar",
			Size = Vector3.new(4, radius + 2, 4),
			CFrame = CFrame.new(x, (radius + 2) / 2 - 1, side * radius),
			Color = DARK_STONE,
			Material = Enum.Material.Slate,
		}, portal)
		Decor.Torch(portal, Vector3.new(x - 3, 0, side * (radius + 3)), 5)
	end

	local disc = Decor.Part({
		Name = "MagicDisc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, radius * 2 - 2, radius * 2 - 2),
		CFrame = CFrame.new(center),
		Color = color,
		Material = Enum.Material.ForceField,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	}, portal)
	Decor.Light(disc, color, 28, 2)
	local swirl = Instance.new("ParticleEmitter")
	swirl.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	swirl.LightEmission = 1
	swirl.Rate = 25
	swirl.Lifetime = NumberRange.new(1, 2)
	swirl.Speed = NumberRange.new(2, 4)
	swirl.Size = NumberSequence.new(0.6, 0)
	swirl.Parent = disc

	local sign = Decor.Part({
		Name = "PortalSign",
		Size = Vector3.new(1, 3.5, radius * 1.6),
		CFrame = CFrame.new(center + Vector3.new(0, radius + 3.5, 0)),
		Color = Color3.fromRGB(40, 35, 55),
	}, portal)
	makeSurfaceText(sign, Enum.NormalId.Left, text, color)
	makeSurfaceText(sign, Enum.NormalId.Right, text, color)
end

local function buildConveyor(folder: Folder)
	local belt = Instance.new("Folder")
	belt.Name = "Conveyor"
	belt.Parent = folder

	newPart({
		Name = "Belt",
		Size = Vector3.new(MAP.ConveyorLength + 8, MapService.BeltHeight, MAP.ConveyorWidth),
		CFrame = CFrame.new(0, MapService.BeltHeight / 2, 0),
		Color = Color3.fromRGB(55, 45, 80),
		Material = Enum.Material.Slate,
	}, belt)

	-- Glowing runes pointing in the walking direction.
	for x = -HALF_CONVEYOR + 6, HALF_CONVEYOR - 6, 10 do
		for _, side in { -1, 1 } do
			Decor.Part({
				Name = "Rune",
				Size = Vector3.new(0.6, 0.06, MAP.ConveyorWidth * 0.35),
				CFrame = CFrame.new(x, MapService.BeltHeight + 0.03, side * MAP.ConveyorWidth * 0.17) * CFrame.Angles(0, math.rad(side * 35), 0),
				Color = MAGIC,
				Material = Enum.Material.Neon,
				CanCollide = false,
				CastShadow = false,
			}, belt)
		end
	end

	-- Low stone borders with a golden trim (players can step over them).
	for _, side in { -1, 1 } do
		local z = side * (MAP.ConveyorWidth / 2 + 0.6)
		Decor.Part({
			Name = "Border",
			Size = Vector3.new(MAP.ConveyorLength + 8, 0.9, 1.2),
			CFrame = CFrame.new(0, 0.45, z),
			Color = STONE,
			Material = Enum.Material.Cobblestone,
			CanCollide = false,
		}, belt)
		Decor.Part({
			Name = "Trim",
			Size = Vector3.new(MAP.ConveyorLength + 8, 0.12, 0.4),
			CFrame = CFrame.new(0, 0.96, z),
			Color = GOLD,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
		}, belt)
	end

	-- Lanterns along the plaza.
	for x = -HALF_CONVEYOR + 20, HALF_CONVEYOR - 20, 40 do
		for _, side in { -1, 1 } do
			Decor.Lantern(belt, Vector3.new(x, 0, side * 15), if side > 0 then GOLD else MAGIC)
		end
	end

	buildPortal(folder, -HALF_CONVEYOR - 2, "NEW CRITTERS", MAGIC)
	buildPortal(folder, HALF_CONVEYOR + 2, "BYE BYE!", Color3.fromRGB(255, 110, 150))
end

local function buildSpawn(folder: Folder)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MainSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(16, 1, 16)
	spawn.CFrame = CFrame.new(MapService.SpawnPosition + Vector3.new(0, 0.5, 0))
	spawn.Color = Color3.fromRGB(120, 100, 180)
	spawn.Material = Enum.Material.Slate
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Neutral = true
	spawn.Duration = 2
	spawn.Parent = folder

	-- Magic fountain behind the spawn.
	local fountainBase = MapService.SpawnPosition + Vector3.new(-18, 0, 0)
	Decor.Column("FountainBasin", 2, 14, fountainBase, STONE, folder, { Material = Enum.Material.Cobblestone })
	Decor.Column("FountainWater", 0.3, 12, fountainBase + Vector3.new(0, 1.8, 0), Color3.fromRGB(120, 200, 255), folder, {
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		CanCollide = false,
	})
	Decor.Column("FountainPillar", 7, 2.5, fountainBase, STONE, folder, { Material = Enum.Material.Cobblestone })
	local orb = Decor.Ellipsoid("FountainOrb", Vector3.new(3.5, 3.5, 3.5), CFrame.new(fountainBase + Vector3.new(0, 9, 0)), MAGIC, folder, {
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	Decor.Light(orb, MAGIC, 30, 2)
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(MAGIC, Color3.fromRGB(120, 220, 255))
	sparkle.LightEmission = 1
	sparkle.Rate = 15
	sparkle.Lifetime = NumberRange.new(1.5, 2.5)
	sparkle.Speed = NumberRange.new(3, 6)
	sparkle.SpreadAngle = Vector2.new(40, 40)
	sparkle.Acceleration = Vector3.new(0, -6, 0)
	sparkle.Size = NumberSequence.new(0.4, 0)
	sparkle.Parent = orb

	-- Floating title.
	local titleAnchor = Decor.Part({
		Name = "Title",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(MapService.SpawnPosition + Vector3.new(0, 26, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, folder)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(50, 11)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 500
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Text = string.upper(GameConfig.GameName)
	title.TextColor3 = GOLD
	title.TextStrokeTransparency = 0
	title.Parent = billboard
	billboard.Parent = titleAnchor
end

local function buildDecor(folder: Folder)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = folder

	local random = Random.new(42)
	local capColors = {
		Color3.fromRGB(230, 70, 80),
		Color3.fromRGB(150, 90, 240),
		Color3.fromRGB(70, 160, 240),
		Color3.fromRGB(250, 140, 200),
	}
	local crystalColors = {
		Color3.fromRGB(120, 220, 255),
		Color3.fromRGB(200, 120, 255),
		Color3.fromRGB(255, 140, 220),
	}

	-- Between the bases (gaps between plots), on both sides of the plaza.
	local perSide = math.ceil(MAP.PlotCount / 2)
	local gapCount = 0
	for column = 0, perSide do
		local x = (column - perSide / 2) * MAP.PlotSpacing
		for _, side in { -1, 1 } do
			gapCount += 1
			local z = side * (PLOT_FRONT + 8)
			if gapCount % 2 == 0 then
				Decor.Mushroom(decor, Vector3.new(x, 0, z), random:NextNumber(0.9, 1.3), capColors[gapCount % #capColors + 1])
			else
				Decor.Crystal(decor, Vector3.new(x, 0, z), random:NextNumber(0.9, 1.3), crystalColors[gapCount % #crystalColors + 1])
			end
			Decor.Tree(decor, Vector3.new(x, 0, side * (PLOT_FRONT + 40)), random:NextNumber(0.85, 1.05), gapCount)
			Decor.Flowers(decor, Vector3.new(x, 0, side * (PLOT_FRONT + 22)), 8, 14, gapCount)
		end
	end

	-- Forest behind the bases.
	local tree = 0
	for x = -MapService.HalfWidth + 15, MapService.HalfWidth - 15, 34 do
		for _, side in { -1, 1 } do
			tree += 1
			local z = side * (PLOT_BACK + random:NextNumber(14, 34))
			if tree % 4 == 0 then
				Decor.Mushroom(decor, Vector3.new(x, 0, z), random:NextNumber(1.2, 1.8), capColors[tree % #capColors + 1])
			elseif tree % 5 == 0 then
				Decor.Crystal(decor, Vector3.new(x, 0, z), random:NextNumber(1.3, 1.9), crystalColors[tree % #crystalColors + 1])
			else
				Decor.Tree(decor, Vector3.new(x, 0, z), random:NextNumber(1.3, 2), tree)
			end
		end
	end

	-- Ends of the map (around the ponds and portals).
	for index, position in
		{
			Vector3.new(MapService.HalfWidth - 20, 0, 25),
			Vector3.new(MapService.HalfWidth - 20, 0, -25),
			Vector3.new(MapService.HalfWidth - 15, 0, 100),
			Vector3.new(MapService.HalfWidth - 15, 0, -100),
			Vector3.new(-MapService.HalfWidth + 15, 0, 110),
			Vector3.new(-MapService.HalfWidth + 15, 0, -110),
		}
	do
		if index % 2 == 0 then
			Decor.Mushroom(decor, position, 1.6, capColors[index % #capColors + 1])
		else
			Decor.Crystal(decor, position, 1.5, crystalColors[index % #crystalColors + 1])
		end
	end

	-- Floating islands in the sky.
	for index, position in
		{
			Vector3.new(-170, 95, MapService.HalfDepth + 40),
			Vector3.new(60, 120, MapService.HalfDepth + 70),
			Vector3.new(220, 90, -MapService.HalfDepth - 40),
			Vector3.new(-60, 110, -MapService.HalfDepth - 60),
			Vector3.new(MapService.HalfWidth + 60, 80, 0),
			Vector3.new(-MapService.HalfWidth - 70, 100, 40),
		}
	do
		Decor.FloatingIsland(decor, position, 1 + (index % 3) * 0.3, index)
	end

	-- Fireflies over the whole meadow.
	for x = -MapService.HalfWidth + 40, MapService.HalfWidth - 40, 80 do
		for _, z in { -PLOT_FRONT + 10, PLOT_FRONT - 10, -PLOT_BACK - 20, PLOT_BACK + 20 } do
			Decor.Fireflies(decor, Vector3.new(x, 6, z), Vector3.new(60, 8, 24))
		end
	end
end

function MapService.Init()
	registerCollisionGroups()
	setupLighting()

	-- The default template parts would overlap the generated map.
	for _, name in { "Baseplate", "SpawnLocation" } do
		local existing = workspace:FindFirstChild(name)
		if existing and existing:IsA("BasePart") then
			existing:Destroy()
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "Map"
	folder.Parent = workspace

	buildTerrain()

	-- Invisible boundary walls.
	local halfW, halfD = MapService.HalfWidth, MapService.HalfDepth
	for _, wall in
		{
			{ Vector3.new(halfW * 2, 120, 2), Vector3.new(0, 60, halfD + 1) },
			{ Vector3.new(halfW * 2, 120, 2), Vector3.new(0, 60, -halfD - 1) },
			{ Vector3.new(2, 120, halfD * 2), Vector3.new(halfW + 1, 60, 0) },
			{ Vector3.new(2, 120, halfD * 2), Vector3.new(-halfW - 1, 60, 0) },
		}
	do
		newPart({ Name = "Boundary", Size = wall[1], CFrame = CFrame.new(wall[2]), Transparency = 1, CastShadow = false }, folder)
	end

	buildConveyor(folder)
	buildSpawn(folder)
	buildDecor(folder)

	-- Folder for critters walking on the conveyor.
	local conveyorUnits = Instance.new("Folder")
	conveyorUnits.Name = "ConveyorCritters"
	conveyorUnits.Parent = workspace
	MapService.ConveyorFolder = conveyorUnits
end

return MapService
