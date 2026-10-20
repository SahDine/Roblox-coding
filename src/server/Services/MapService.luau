--[[
	MapService
	Builds the fantasy world at server start, in the low-poly "made of triangles" style
	(props from Flora, Landmarks and Horizon, all drawn with LowPoly):
	  * terrain: meadow (top at y = 0), cobblestone plaza, dirt paths, spawn courtyard, ponds and a
	    ring of low hills hiding the map edges,
	  * the enchanted conveyor between its two portal arches,
	  * areas with their own character: the spawn plaza (fountain, guardian statues, banners, a ring
	    of crystals), the conveyor plaza (crystal lamps and pennant garlands at every path), the
	    gardens in front of the bases, the forest behind them, the ruins and lily ponds of the west
	    end, the lake garden, stone circle and crystal grove of the east end,
	  * the horizon: snowy mountains, clouds and floating islands with waterfalls,
	  * the fantasy lighting.
	Player bases are built by PlotService. The scenery stays out of their footprints (+ margin),
	their dirt paths, the conveyor plaza and the zones reserved for the boards (see isFree).
	Every random choice uses Decor.Rng, so all servers build exactly the same world.
]]

local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local Modules = script.Parent.Parent.Modules
local Decor = require(Modules.Decor)
local Flora = require(Modules.Flora)
local Horizon = require(Modules.Horizon)
local Landmarks = require(Modules.Landmarks)
local LowPoly = require(Modules.LowPoly)

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

local PLAZA_HALF = 18 -- the cobblestone plaza along the conveyor: |z| < 18
local PATH_HALF = 8 -- dirt paths from the plaza to the gates are 16 studs wide
local GATE_APRON = 7 -- the castle ramp sticks out of the base footprint towards the plaza
local BASE_MARGIN = 8 -- free ground kept around every base and path
local SPAWN_RADIUS = 30
local POND_RADIUS = 22
local PORTAL_X = HALF_CONVEYOR + 2
local CAMERA_REACH = 72 -- StarterPlayer.CameraMaxZoomDistance (64) plus a margin
local CHARACTER_CEILING = 50 -- no character gets higher (castle roofs ~24 studs + a jump + a mega slap)

local STONE = Color3.fromRGB(150, 145, 160)
local GOLD = Color3.fromRGB(255, 205, 80)
local MAGIC = Color3.fromRGB(170, 110, 255)
local BYE_PINK = Color3.fromRGB(255, 110, 150)
local CRYSTAL_COLORS = {
	Color3.fromRGB(120, 220, 255),
	Color3.fromRGB(200, 120, 255),
	Color3.fromRGB(255, 140, 220),
}
local CAP_COLORS = {
	Color3.fromRGB(230, 70, 90),
	Color3.fromRGB(150, 90, 240),
	Color3.fromRGB(70, 160, 240),
	Color3.fromRGB(250, 140, 200),
}
local PENNANTS = {
	Color3.fromRGB(255, 205, 80),
	Color3.fromRGB(170, 110, 255),
	Color3.fromRGB(255, 110, 150),
	Color3.fromRGB(110, 200, 255),
}

-- Ancient stone circle at the east end, on the conveyor's axis behind the BYE BYE portal.
local STONE_CIRCLE = Vector3.new(HALF_CONVEYOR + 62, 0, 0)
local STONE_CIRCLE_RADIUS = 9

local PONDS = {
	Vector3.new(HALF_CONVEYOR + 50, 0, 60),
	Vector3.new(HALF_CONVEYOR + 50, 0, -60),
	Vector3.new(-HALF_CONVEYOR - 50, 0, 70),
	Vector3.new(-HALF_CONVEYOR - 50, 0, -70),
}

local function newPart(props, parent: Instance): BasePart
	local part = Decor.Part(props, parent)
	if props.CollisionGroup == nil then
		part.CollisionGroup = "Default"
	end
	return part
end

MapService.NewPart = newPart

-- Keep-out zones ------------------------------------------------------------------------------

type Rect = { MinX: number, MaxX: number, MinZ: number, MaxZ: number }
type Circle = { Center: Vector3, Radius: number }

local blockedRects: { Rect } = {}
local blockedCircles: { Circle } = {}

local function block(x0: number, x1: number, z0: number, z1: number)
	table.insert(blockedRects, { MinX = math.min(x0, x1), MaxX = math.max(x0, x1), MinZ = math.min(z0, z1), MaxZ = math.max(z0, z1) })
end

-- Centres of the bases, computed like PlotService does.
local function baseCenters(): { Vector3 }
	local centers = {}
	local perSide = math.ceil(MAP.PlotCount / 2)
	for column = 0, perSide - 1 do
		local x = (column - (perSide - 1) / 2) * MAP.PlotSpacing
		for _, side in { 1, -1 } do
			table.insert(centers, Vector3.new(x, 0, side * MAP.PlotDistanceFromCenter))
		end
	end
	return centers
end

local function computeZones()
	table.clear(blockedRects)
	table.clear(blockedCircles)
	local halfWidth = MAP.PlotWidth / 2 + BASE_MARGIN
	for _, center in baseCenters() do
		local side = math.sign(center.Z)
		local gate = PLOT_FRONT - GATE_APRON
		block(center.X - halfWidth, center.X + halfWidth, side * (gate - BASE_MARGIN), side * (PLOT_BACK + BASE_MARGIN))
		block(center.X - PATH_HALF - BASE_MARGIN, center.X + PATH_HALF + BASE_MARGIN, side * PLAZA_HALF, side * gate)
	end
	block(-HALF_CONVEYOR - 22, HALF_CONVEYOR + 22, -PLAZA_HALF, PLAZA_HALF)
	-- Boards built by other services next to the spawn (rare spawn timers, global leaderboards).
	block(-232, -198, -38, -16)
	block(-288, -238, 18, 44)
	block(-288, -238, -44, -18)
	table.insert(blockedCircles, { Center = MapService.SpawnPosition, Radius = SPAWN_RADIUS })
	for _, pond in PONDS do
		table.insert(blockedCircles, { Center = pond, Radius = POND_RADIUS + 2 })
	end
	table.insert(blockedCircles, { Center = STONE_CIRCLE, Radius = STONE_CIRCLE_RADIUS + 4 })
end

-- True when a prop of this radius at (x, z) stays inside the playable area and out of every zone.
local function isFree(x: number, z: number, radius: number): boolean
	if math.abs(x) > MapService.HalfWidth - radius or math.abs(z) > MapService.HalfDepth - radius then
		return false
	end
	local r = math.max(radius, 0.1)
	for _, rect in blockedRects do
		local dx = math.max(rect.MinX - x, 0, x - rect.MaxX)
		local dz = math.max(rect.MinZ - z, 0, z - rect.MaxZ)
		if dx * dx + dz * dz < r * r then
			return false
		end
	end
	for _, circle in blockedCircles do
		local dx, dz = x - circle.Center.X, z - circle.Center.Z
		if dx * dx + dz * dz < (circle.Radius + r) ^ 2 then
			return false
		end
	end
	return true
end

-- Physics and lighting ------------------------------------------------------------------------

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
	-- Warm late afternoon: long soft shadows make the facets of the low-poly props read well.
	Lighting.ClockTime = 16.2
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(78, 66, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 135, 180)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25

	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end

	-- Lavender haze: the mountains fade into a pastel sky.
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.2
	atmosphere.Haze = 1.6
	atmosphere.Glare = 0.5
	atmosphere.Color = Color3.fromRGB(228, 206, 255)
	atmosphere.Decay = Color3.fromRGB(160, 120, 210)
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.55
	bloom.Size = 24
	bloom.Threshold = 1.25
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.15
	color.Contrast = 0.08
	color.Brightness = 0.02
	color.TintColor = Color3.fromRGB(255, 246, 255)
	color.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.07
	rays.Spread = 0.6
	rays.Parent = Lighting
end

-- Terrain -------------------------------------------------------------------------------------

type Hill = { Center: Vector3, Radius: number }
local hills: { Hill } = {}

-- Height of the ground at (x, z): 0 on the meadow, higher on the hills around the map.
local function groundHeight(x: number, z: number): number
	local height = 0
	for _, hill in hills do
		local dx, dz = x - hill.Center.X, z - hill.Center.Z
		local d2 = hill.Radius * hill.Radius - dx * dx - dz * dz
		if d2 > 0 then
			height = math.max(height, hill.Center.Y + math.sqrt(d2))
		end
	end
	return height
end

-- Pastel terrain palette matching the low-poly props (fresh meadow, lavender stone, warm dirt) and
-- calm turquoise water with small waves.
local function paintTerrain(terrain: Terrain)
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(114, 178, 86))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(92, 152, 80))
	terrain:SetMaterialColor(Enum.Material.Cobblestone, Color3.fromRGB(170, 162, 182))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(170, 128, 92))
	terrain:SetMaterialColor(Enum.Material.Pavement, Color3.fromRGB(190, 180, 206))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(140, 132, 158))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(228, 210, 168))
	terrain.WaterColor = Color3.fromRGB(64, 176, 214)
	terrain.WaterTransparency = 0.55
	terrain.WaterReflectance = 0.5
	terrain.WaterWaveSize = 0.08
	terrain.WaterWaveSpeed = 6
end

-- Dirt trail through `points` (terrain only, top at y = 0): overlapping discs every 2 studs. Terrain
-- voxels are 4 studs wide, so a trail narrower than ~5 studs would break up.
local function trail(terrain: Terrain, points: { Vector3 }, radius: number)
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local steps = math.max(1, math.ceil((b - a).Magnitude / 2))
		for step = 0, steps do
			local p = a:Lerp(b, step / steps)
			terrain:FillCylinder(CFrame.new(p.X, -2, p.Z), 4, radius, Enum.Material.Ground)
		end
	end
end

local function buildTerrain()
	local terrain = workspace.Terrain
	local halfW, halfD = MapService.HalfWidth, MapService.HalfDepth
	paintTerrain(terrain)

	-- Meadow (top surface exactly at y = 0), wide enough to reach the mountains.
	terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(halfW * 2 + 380, 12, halfD * 2 + 380), Enum.Material.Grass)

	-- Darker leafy ground under the forest behind the bases (it stops 2 studs before their margin).
	local floorRng = Decor.Rng(5)
	for x = -halfW - 10, halfW + 10, 22 do
		for _, side in { -1, 1 } do
			local radius = floorRng:NextNumber(13, 18)
			local z = side * (PLOT_BACK + BASE_MARGIN + 2 + radius + floorRng:NextNumber(0, 6))
			terrain:FillCylinder(CFrame.new(x + floorRng:NextNumber(-6, 6), -2, z), 4, radius, Enum.Material.LeafyGrass)
		end
	end

	-- Cobblestone plaza along the conveyor.
	terrain:FillBlock(CFrame.new(0, -2, 0), Vector3.new(MAP.ConveyorLength + 40, 4, PLAZA_HALF * 2), Enum.Material.Cobblestone)

	-- Dirt paths from the plaza to every base gate.
	for _, center in baseCenters() do
		local side = math.sign(center.Z)
		local length = PLOT_FRONT - PLAZA_HALF
		terrain:FillBlock(
			CFrame.new(center.X, -2, side * (PLAZA_HALF + length / 2)),
			Vector3.new(PATH_HALF * 2, 4, length),
			Enum.Material.Ground
		)
	end

	-- Spawn courtyard: pale paving edged with a ring of cobblestones.
	local courtyard = CFrame.new(MapService.SpawnPosition - Vector3.new(0, 2, 0))
	terrain:FillCylinder(courtyard, 4, SPAWN_RADIUS + 3, Enum.Material.Cobblestone)
	terrain:FillCylinder(courtyard, 4, SPAWN_RADIUS, Enum.Material.Pavement)

	-- Trails inviting players to explore: from the east end of the plaza (past the garden fences)
	-- to the bridge and the stepping stones, then on to the crystal groves; from the spawn
	-- courtyard (east of the leaderboards) round the north-west pond to the ruins.
	local east = HALF_CONVEYOR
	for _, side in { -1, 1 } do
		trail(terrain, {
			Vector3.new(east + 21, 0, side * 17),
			Vector3.new(east + 23, 0, side * 38),
			Vector3.new(east + 27, 0, side * 58),
		}, 2.6)
		trail(terrain, {
			Vector3.new(east + 76, 0, side * 62),
			Vector3.new(east + 72, 0, side * 90),
			Vector3.new(east + 56, 0, side * 110),
		}, 2.4)
	end
	local west = -HALF_CONVEYOR
	trail(terrain, {
		Vector3.new(west - 26, 0, 26),
		Vector3.new(west - 21, 0, 50),
		Vector3.new(west - 22, 0, 92),
		Vector3.new(west - 34, 0, 112),
		Vector3.new(west - 44, 0, 121),
	}, 2.4)
	-- Worn paving around the ruins and in the stone circle, which a trail links to the plaza.
	terrain:FillCylinder(CFrame.new(west - 48, -2, 130), 4, 9, Enum.Material.Cobblestone)
	trail(terrain, { Vector3.new(east + 20, 0, 0), STONE_CIRCLE }, 2.6)
	terrain:FillCylinder(CFrame.new(STONE_CIRCLE - Vector3.new(0, 2, 0)), 4, STONE_CIRCLE_RADIUS + 3, Enum.Material.Cobblestone)

	-- Ponds at both ends of the plaza (surface at y = 0) with a pale sandy shore.
	for _, pond in PONDS do
		terrain:FillCylinder(CFrame.new(pond - Vector3.new(0, 2, 0)), 4, POND_RADIUS + 3, Enum.Material.Sand)
		terrain:FillCylinder(CFrame.new(pond - Vector3.new(0, 3, 0)), 6, POND_RADIUS, Enum.Material.Water)
	end

	-- Low hills just outside the invisible walls: the ground rises at the edge of the map.
	local rng = Decor.Rng(7)
	table.clear(hills)
	local function hill(x: number, z: number)
		local radius = rng:NextNumber(34, 46)
		local center = Vector3.new(x, -radius * 0.38, z)
		table.insert(hills, { Center = center, Radius = radius })
		terrain:FillBall(center, radius, Enum.Material.Grass)
	end
	for x = -halfW - 40, halfW + 40, 40 do
		for _, side in { -1, 1 } do
			hill(x + rng:NextNumber(-8, 8), side * (halfD + rng:NextNumber(36, 44)))
		end
	end
	for z = -halfD, halfD, 40 do
		for _, side in { -1, 1 } do
			hill(side * (halfW + rng:NextNumber(36, 44)), z + rng:NextNumber(-8, 8))
		end
	end
end

-- Conveyor ------------------------------------------------------------------------------------

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
				CFrame = CFrame.new(x, MapService.BeltHeight + 0.03, side * MAP.ConveyorWidth * 0.17)
					* CFrame.Angles(0, math.rad(side * 35), 0),
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

	-- Crystal lamps at the edge of the plaza: a pair at the mouth of every dirt path with a pennant
	-- garland between them, a pair in the middle of the plaza and a pair near both portals.
	local edge = PLAZA_HALF - 1.5
	for _, center in baseCenters() do
		local side = math.sign(center.Z)
		local lampColor = if side > 0 then GOLD else MAGIC
		local spread = PATH_HALF + 3
		for _, dx in { -spread, spread } do
			Landmarks.PlazaLamp(belt, Vector3.new(center.X + dx, 0, side * edge), lampColor, Vector3.new(0, 0, -side))
		end
		-- The rope is tied to the sides of the two lamp posts (0.4 thick).
		Landmarks.Garland(
			belt,
			Vector3.new(center.X - spread + 0.25, 7.4, side * edge),
			Vector3.new(center.X + spread - 0.25, 7.4, side * edge),
			1.6,
			PENNANTS
		)
	end
	for _, x in { -HALF_CONVEYOR + 12, 0, HALF_CONVEYOR - 12 } do
		for _, side in { -1, 1 } do
			Landmarks.PlazaLamp(belt, Vector3.new(x, 0, side * edge), if side > 0 then GOLD else MAGIC, Vector3.new(0, 0, -side))
		end
	end

	local halfOpening = MAP.ConveyorWidth / 2 + 3
	Landmarks.Portal(folder, Vector3.new(-PORTAL_X, 0, 0), halfOpening, "NEW CRITTERS", MAGIC)
	Landmarks.Portal(folder, Vector3.new(PORTAL_X, 0, 0), halfOpening, "BYE BYE!", BYE_PINK)
end

-- Spawn plaza ---------------------------------------------------------------------------------

local function buildSpawn(folder: Folder)
	local plaza = Instance.new("Folder")
	plaza.Name = "SpawnPlaza"
	plaza.Parent = folder
	local origin = MapService.SpawnPosition

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MainSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(16, 1, 16)
	-- Characters spawn facing the pad's front: towards the NEW CRITTERS portal and the conveyor.
	local padCenter = origin + Vector3.new(0, 0.5, 0)
	spawn.CFrame = CFrame.lookAt(padCenter, padCenter + Vector3.xAxis)
	spawn.Color = Color3.fromRGB(120, 100, 180)
	spawn.Material = Enum.Material.Slate
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Neutral = true
	spawn.Duration = 2
	spawn.Parent = folder

	-- Inlay on the pad: a pale stone diamond around a small glowing one (four right triangles each,
	-- lying on the pad's top face, non-collidable so players stand on the pad itself).
	local padTop = origin + Vector3.new(0, 1, 0)
	for _, layer in
		{
			{ Radius = 6, Color = MAGIC:Lerp(Color3.new(1, 1, 1), 0.45), Material = Enum.Material.Slate, Lift = 0.03 },
			{ Radius = 2.4, Color = GOLD, Material = Enum.Material.Neon, Lift = 0.09 },
		}
	do
		local inlay = Decor.Facets("SpawnInlay", layer.Color, layer.Material)
		inlay.CastShadow = false
		inlay.Thickness = 0.06
		local center = padTop + Vector3.new(0, layer.Lift, 0)
		local radius = layer.Radius
		for k = 0, 3 do
			local a, b = k * math.pi / 2, (k + 1) * math.pi / 2
			LowPoly.Triangle(
				center,
				center + Vector3.new(math.cos(a), 0, math.sin(a)) * radius,
				center + Vector3.new(math.cos(b), 0, math.sin(b)) * radius,
				inlay,
				plaza
			)
		end
	end

	-- A compass star of flat gold and lavender triangles on the courtyard paving, starting at the
	-- edges and corners of the 16 x 16 pad (the western ray stops short of the fountain basin).
	for index = 0, 7 do
		local angle = index * math.pi / 4
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local across = Vector3.new(-outward.Z, 0, outward.X)
		local long = index % 2 == 0
		local foot = origin + outward * (if long then 8.1 else 11.4) + Vector3.new(0, 0.06, 0)
		local tip = origin + outward * (if long then 15 else 16.5) + Vector3.new(0, 0.06, 0)
		local width = if long then 3.2 else 2
		local ray = Decor.Facets("SpawnRay", if long then GOLD else MAGIC:Lerp(Color3.new(1, 1, 1), 0.35), Enum.Material.Slate)
		ray.CastShadow = false
		ray.Thickness = 0.12
		LowPoly.Triangle(foot + across * width, foot - across * width, tip, ray, plaza)
	end

	-- A ring of glowing crystal shards around the spawn pad.
	local shard = Decor.Facets("SpawnShard", MAGIC:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Neon)
	shard.CastShadow = false
	local rng = Decor.Rng(11)
	for index = 0, 7 do
		local angle = (index + 0.5) * math.pi / 4
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local foot = origin + outward * 11 - Vector3.new(0, 0.3, 0)
		local tip = foot + outward * 0.6 + Vector3.new(0, rng:NextNumber(2.2, 3.4), 0)
		LowPoly.DrawTriangles(LowPoly.ConeTriangles(foot, tip, 0.55, 4, false, Flora.RandomFlat(rng)), shard, plaza, 0.1)
	end

	-- Fountain behind the spawn, guarded by two statues and framed by banners.
	local fountain = origin + Vector3.new(-23, 0, 0)
	Landmarks.Fountain(plaza, fountain, MAGIC)
	for _, side in { -1, 1 } do
		Landmarks.GuardianStatue(plaza, fountain + Vector3.new(0, 0, side * 13), Vector3.xAxis, MAGIC)
		Landmarks.Banner(plaza, origin + Vector3.new(-10, 0, side * 15), 12, if side > 0 then MAGIC else BYE_PINK, Vector3.xAxis)
		Landmarks.Banner(plaza, fountain + Vector3.new(-11, 0, side * 8), 13, if side > 0 then BYE_PINK else MAGIC, Vector3.xAxis)
		Landmarks.PlazaLamp(plaza, origin + Vector3.new(13, 0, side * 9), MAGIC, Vector3.new(0, 0, -side))
		Flora.FlowerPatch(plaza, fountain + Vector3.new(-9, 0, side * 3.5), 2.2, 6, 30 + side)
		Flora.FlowerPatch(plaza, fountain + Vector3.new(5, 0, side * 10.5), 1.8, 5, 40 + side)
		Flora.Bush(plaza, fountain + Vector3.new(-6, 0, side * 13.5), 0.8, 50 + side)
	end

	-- Floating title.
	local titleAnchor = Decor.Part({
		Name = "Title",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(origin + Vector3.new(0, 26, 0)),
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

-- Gardens, forest and the two ends ------------------------------------------------------------

-- Bare-earth bed under a garden feature (terrain only: it costs no part).
local function gardenBed(x: number, z: number, radius: number)
	workspace.Terrain:FillCylinder(CFrame.new(x, -2, z), 4, radius, Enum.Material.Ground)
end

-- Gardens in the strip between the plaza and the bases, between the dirt paths.
local function buildGardens(decor: Folder)
	local gardens = Instance.new("Folder")
	gardens.Name = "Gardens"
	gardens.Parent = decor
	local spacing = MAP.PlotSpacing
	local perSide = math.ceil(MAP.PlotCount / 2)
	local seed = 100
	for column = 0, perSide do
		local x = (column - perSide / 2) * spacing
		for _, side in { -1, 1 } do
			seed += 10
			local z = side * 26
			if column > 0 and column < perSide then
				-- Centre piece: a cherry tree, a crystal tree or a round tree, on a round bed.
				gardenBed(x, z, 5.5)
				local kind = (column + (if side > 0 then 0 else 1)) % 3
				if kind == 0 then
					Flora.CherryTree(gardens, Vector3.new(x, 0, z), 1, seed)
				elseif kind == 1 then
					Flora.CrystalTree(gardens, Vector3.new(x, 0, z), 0.95, seed, CRYSTAL_COLORS[column % #CRYSTAL_COLORS + 1])
				else
					Flora.RoundTree(gardens, Vector3.new(x, 0, z), 1, seed)
				end
				for _, dx in { -1, 1 } do
					gardenBed(x + dx * 16, side * 23.5, 4)
					Flora.FlowerPatch(gardens, Vector3.new(x + dx * 16, 0, side * 23.5), 3, 9, seed + dx)
				end
				-- A bush on one side (alternating from one garden to the next).
				local flip = if (column + (if side > 0 then 1 else 0)) % 2 == 0 then 1 else -1
				Flora.Bush(gardens, Vector3.new(x + flip * 25, 0, side * 27), 1.1, seed + 3)
			else
				-- Outer gardens next to the portals: a fenced flower meadow and a cherry tree. On the
				-- spawn side the fence stops before the rare-spawn board and the spawn courtyard.
				local outward = math.sign(x)
				local from = HALF_CONVEYOR - 38
				local to = if outward > 0 then HALF_CONVEYOR + 18 else HALF_CONVEYOR - 8
				Landmarks.Fence(gardens, Vector3.new(outward * from, 0, side * 19.5), Vector3.new(outward * to, 0, side * 19.5), seed)
				Flora.CherryTree(gardens, Vector3.new(outward * (from + 12), 0, side * 26.5), 0.9, seed + 1)
				Flora.FlowerPatch(gardens, Vector3.new(outward * (from + 26), 0, side * 25), 3.5, 8, seed + 2)
				if outward > 0 then
					Flora.Bush(gardens, Vector3.new(outward * (to - 6), 0, side * 27), 1.1, seed + 3)
				end
			end
		end
	end
end

-- Forest between the backs of the bases and the hills: a loose double row of big trees with
-- undergrowth, then cheap pine silhouettes on the hills behind the invisible walls.
local function buildForest(decor: Folder)
	local forest = Instance.new("Folder")
	forest.Name = "Forest"
	forest.Parent = decor
	local rng = Decor.Rng(21)
	local index = 0
	for x = -MapService.HalfWidth + 16, MapService.HalfWidth - 16, 32 do
		for _, side in { -1, 1 } do
			index += 1
			local px = x + rng:NextNumber(-6, 6)
			local front = index % 4 < 2
			local pz = side * (if front then rng:NextNumber(143, 150) else rng:NextNumber(157, 165))
			if isFree(px, pz, 6) then
				local base = Vector3.new(px, groundHeight(px, pz), pz)
				local pick = index % 7
				if pick == 0 then
					Flora.Mushroom(forest, base, rng:NextNumber(1.2, 1.6), index, CAP_COLORS[index % #CAP_COLORS + 1])
				elseif pick == 3 then
					Flora.RoundTree(forest, base, rng:NextNumber(1.4, 1.8), index)
				elseif pick == 5 then
					Flora.CrystalCluster(forest, base, rng:NextNumber(1.1, 1.4), index, CRYSTAL_COLORS[index % #CRYSTAL_COLORS + 1])
				else
					-- Four-sided tiers on the back row (seen from further away) to save parts.
					Flora.Pine(forest, base, rng:NextNumber(1.5, 2.2), index, nil, if front then 5 else 4)
				end
			end
			-- Undergrowth between the trees, on the other row.
			if index % 4 == 1 then
				local bx = x + 14
				local bz = side * (if front then rng:NextNumber(157, 164) else rng:NextNumber(141, 146))
				if isFree(bx, bz, 3) then
					local base = Vector3.new(bx, groundHeight(bx, bz), bz)
					if index % 8 == 1 then
						Flora.Boulder(forest, base, Vector3.new(5.4, 4, 4.8), index, nil, true)
					else
						Flora.Bush(forest, base, 1.3, index)
					end
				end
			end
		end
	end

	-- Pine silhouettes on the hills behind the invisible walls.
	for x = -MapService.HalfWidth + 20, MapService.HalfWidth - 20, 56 do
		for _, side in { -1, 1 } do
			index += 1
			local px = x + rng:NextNumber(-12, 12)
			local pz = side * (MapService.HalfDepth + rng:NextNumber(10, 22))
			Flora.FarPine(forest, Vector3.new(px, groundHeight(px, pz) - 0.5, pz), rng:NextNumber(1.7, 2.3), index)
		end
	end
end

-- West end (spawn side): lily ponds and ruins. East end: lake garden with a bridge, stepping
-- stones, a stone circle and a crystal grove.
local function buildEnds(decor: Folder)
	local ends = Instance.new("Folder")
	ends.Name = "Ends"
	ends.Parent = decor

	for index, pond in PONDS do
		local seed = 300 + index * 20
		local east = pond.X > 0
		local outward = math.sign(pond.Z)
		local away = if east then 1 else -1
		-- The south-east pond is crossed on stepping stones, the north-east one on a bridge (lily
		-- pads float under it), the west ones have a jetty on their side facing the plaza.
		local stones, jetty = {}, {}
		local shore = pond - Vector3.new(0, 0, outward * (POND_RADIUS + 1.5))
		if east and outward < 0 then
			for k = 0, 7 do
				local t = k / 7
				table.insert(stones, pond + Vector3.new((t - 0.5) * 38, 0, math.sin(t * math.pi) * 5))
			end
		elseif not east then
			for k = 0, 3 do
				table.insert(jetty, shore + Vector3.new(0, 0, outward * (2 + k * 3)))
			end
		end
		Landmarks.LilyPads(ends, pond, POND_RADIUS - 4, 6, seed, if east then stones else jetty)
		-- Reeds and rocks on the rim, away from the bridge / stepping stones that cross the east
		-- ponds along X and from the jetty of the west ponds (on their side facing the plaza).
		local function rimPoint(angle: number, radius: number): Vector3
			local a = angle
			if east and math.abs(math.sin(a)) < 0.45 then
				a += if math.sin(a) >= 0 then 1 else -1
			elseif not east and math.sin(a) * outward < -0.75 then
				a += 1.4
			end
			return pond + Vector3.new(math.cos(a), 0, math.sin(a)) * radius
		end
		for k = 0, 1 do
			local angle = seed + k * 2.6
			Flora.Reeds(ends, rimPoint(angle, POND_RADIUS + 0.5), 2.4, 6, seed + k)
			Flora.Boulder(ends, rimPoint(angle + 1.1, POND_RADIUS + 1.5), Vector3.new(3.8, 2.4, 3.4), seed + k, nil, k == 0)
		end
		if #stones > 0 then
			Landmarks.SteppingStones(ends, stones, seed)
		elseif east then
			Landmarks.Bridge(ends, pond - Vector3.new(POND_RADIUS + 3, 0, 0), pond + Vector3.new(POND_RADIUS + 3, 0, 0), 5, 3.5)
		else
			Landmarks.Jetty(ends, shore, shore + Vector3.new(0, 0, outward * 11), 3.6, seed + 7)
		end
		-- A cherry tree and a pine on the outer side of the pond.
		local cherry = pond + Vector3.new(-14 * away, 0, 30 * outward)
		if isFree(cherry.X, cherry.Z, 5) then
			Flora.CherryTree(ends, cherry, 1.2, seed + 10)
		end
		local pine = pond + Vector3.new(30 * away, 0, 10 * outward)
		if isFree(pine.X, pine.Z, 5) then
			Flora.Pine(ends, pine, 1.6, seed + 11)
		end
	end

	-- Ruins in the west corners, a crystal grove in the east corners.
	local westX = -MapService.HalfWidth + 42
	Landmarks.Ruins(ends, Vector3.new(westX, 0, 130), math.rad(12), 501)
	Landmarks.BrokenArch(ends, Vector3.new(westX - 4, 0, -128), math.rad(-20), 502)
	Flora.Boulder(ends, Vector3.new(westX + 16, 0, -134), Vector3.new(6.4, 5.2, 5.4), 503, nil, true)
	Flora.Boulder(ends, Vector3.new(westX - 14, 0, 142), Vector3.new(5.4, 4.2, 5.8), 504, nil, true)
	Flora.Pine(ends, Vector3.new(westX + 22, 0, 112), 1.7, 505)
	Flora.RoundTree(ends, Vector3.new(westX - 16, 0, -112), 1.4, 507)

	-- The stone circle's trilithon faces the plaza and frames its floating crystal.
	Landmarks.StoneCircle(ends, STONE_CIRCLE, STONE_CIRCLE_RADIUS, -Vector3.xAxis, CRYSTAL_COLORS[3], 520)

	local eastX = MapService.HalfWidth - 40
	for _, side in { -1, 1 } do
		local grove = Vector3.new(eastX, 0, side * 130)
		Flora.CrystalTree(ends, grove, 1.4, 600 + side, CRYSTAL_COLORS[2])
		Flora.CrystalCluster(ends, grove + Vector3.new(-12, 0, side * -6), 1.3, 610 + side, CRYSTAL_COLORS[1])
		Flora.Mushroom(ends, grove + Vector3.new(14, 0, side * -14), 1.3, 630 + side, CAP_COLORS[2])
		Flora.Boulder(ends, grove + Vector3.new(-18, 0, side * 14), Vector3.new(5.4, 4, 4.8), 650 + side, nil, true)
		Flora.FlowerPatch(ends, grove + Vector3.new(4, 0, side * -12), 3.5, 7, 670 + side)
	end
end

-- Horizon -------------------------------------------------------------------------------------

local function buildHorizon(decor: Folder)
	local sky = Instance.new("Folder")
	sky.Name = "Horizon"
	sky.Parent = decor
	local rng = Decor.Rng(77)

	-- Mountain range on an ellipse around the map: wide five-sided peaks, the taller ones snowy.
	-- Each peak is pushed outwards until its foot clears the playable area and the ring of hills
	-- (the ellipse alone passes too close to the corners of the rectangular map).
	local clearX, clearZ = MapService.HalfWidth + 60, MapService.HalfDepth + 60
	-- Characters stay in the playable area (up to the top of the castles) and cameras within the
	-- maximum zoom of them, so the far side of every peak is never seen and is not built.
	local viewBox = {
		Min = Vector3.new(-MapService.HalfWidth, 0, -MapService.HalfDepth),
		Max = Vector3.new(MapService.HalfWidth, CHARACTER_CEILING, MapService.HalfDepth),
		Reach = CAMERA_REACH,
	}
	local count = 13
	for index = 0, count - 1 do
		local angle = (index + rng:NextNumber(-0.15, 0.15)) * math.pi * 2 / count
		local direction = Vector3.new(math.cos(angle) * 460, 0, math.sin(angle) * 340)
		local radius = rng:NextNumber(105, 125)
		local position = direction
		for _ = 1, 8 do
			local dx = math.max(math.abs(position.X) - clearX, 0)
			local dz = math.max(math.abs(position.Z) - clearZ, 0)
			local gap = math.sqrt(dx * dx + dz * dz) - radius * 1.12
			if gap >= 0 then
				break
			end
			position += direction.Unit * (-gap + 1)
		end
		local height = rng:NextNumber(95, 160)
		Horizon.Mountain(sky, position, radius, height, 900 + index, height > 115, 5, viewBox)
	end

	-- Big clouds drifting above the forest, in front of the mountains.
	for index, cloud in
		{
			Vector3.new(-150, 150, 205),
			Vector3.new(140, 160, -215),
			Vector3.new(330, 140, 120),
			Vector3.new(-340, 150, -130),
			Vector3.new(40, 172, 245),
			Vector3.new(-40, 165, -250),
		}
	do
		Horizon.Cloud(sky, cloud, rng:NextNumber(2.2, 2.8), 950 + index, viewBox)
	end

	-- Floating islands: two pour their waterfalls into the east ponds, two float over the forest.
	local northPond, southPond = PONDS[1], PONDS[2]
	Horizon.FloatingIsland(sky, northPond + Vector3.new(0, 62, 28), 0.9, 970, Vector3.new(0, 0, -1), 0, nil, viewBox)
	Horizon.FloatingIsland(sky, southPond + Vector3.new(0, 66, -28), 0.9, 971, Vector3.new(0, 0, 1), 0, nil, viewBox)
	-- The waterfalls of the forest islands land on the hills (the foot is ~16 studs out per unit of scale).
	local halfD = MapService.HalfDepth
	for index, island in
		{
			{ Center = Vector3.new(-120, 84, halfD + 40), Scale = 1.2, Fall = Vector3.new(0.6, 0, -0.8).Unit },
			{ Center = Vector3.new(80, 90, -halfD - 45), Scale = 1.3, Fall = Vector3.new(-0.5, 0, 0.85).Unit },
		}
	do
		local foot = island.Center + island.Fall * 16 * island.Scale
		Horizon.FloatingIsland(sky, island.Center, island.Scale, 971 + index, island.Fall, groundHeight(foot.X, foot.Z), nil, viewBox)
	end
end

local function buildDecor(folder: Folder)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = folder

	buildGardens(decor)
	buildForest(decor)
	buildEnds(decor)
	buildHorizon(decor)

	-- Fireflies over the gardens (between the dirt paths, clear of the rare-spawn board) and the forest.
	for _, x in { -180, -96, 0, 96, 180 } do
		for _, side in { -1, 1 } do
			Decor.Fireflies(decor, Vector3.new(x, 5, side * 25), Vector3.new(if math.abs(x) > 150 then 30 else 48, 6, 10))
		end
	end
	for x = -MapService.HalfWidth + 60, MapService.HalfWidth - 60, 115 do
		for _, side in { -1, 1 } do
			Decor.Fireflies(decor, Vector3.new(x, 6, side * (PLOT_BACK + 26)), Vector3.new(100, 8, 16))
		end
	end
end

function MapService.Init()
	registerCollisionGroups()
	setupLighting()
	computeZones()

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
