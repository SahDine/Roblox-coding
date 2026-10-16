--[[
	Landmarks
	The big low-poly set pieces of the map, drawn with triangles (LowPoly) plus a few plain parts
	for what players walk on or read: the conveyor portal arches, the spawn fountain, guardian
	statues and banners, the plaza lamps and pennant garlands, wooden fences, stone ruins, the pond
	bridge, stepping stones and lily pads.

	Nothing here interpenetrates by accident: arch stones, pillars and signs meet face to face.
]]

local LowPoly = require(script.Parent.LowPoly)
local Decor = require(script.Parent.Decor)
local Flora = require(script.Parent.Flora)

local Landmarks = {}

type Triangles = { LowPoly.TriangleWithInside }

local STONE = Color3.fromRGB(168, 160, 182)
local STONE_DARK = Color3.fromRGB(120, 112, 140)
local KEYSTONE = Color3.fromRGB(205, 196, 214)
local GOLD = Color3.fromRGB(255, 205, 80)
local WHITE = Color3.new(1, 1, 1)
local SIGN_BOARD = Color3.fromRGB(40, 35, 55)

local function facets(name: string, color: Color3, material: Enum.Material?, solid: boolean?): LowPoly.PartProps
	return {
		Name = name,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		CanCollide = solid == true,
		CollisionGroup = "Decor",
	}
end

local function addQuad(list: Triangles, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3)
	table.insert(list, { A = a, B = b, C = c, Inside = inside })
	table.insert(list, { A = a, B = c, C = d, Inside = inside })
end

--[[
	Closed six-faced block from its 8 corners, ordered like LowPoly.BoxTriangles:
	1 (-,-,-) 2 (+,-,-) 3 (+,+,-) 4 (-,+,-) 5 (-,-,+) 6 (+,-,+) 7 (+,+,+) 8 (-,+,+).
	skip: faces left open because they are hidden ("Back", "Front", "MinX", "MaxX", "Top", "Bottom").
]]
local HEXA_FACES = {
	Back = { 1, 2, 3, 4 },
	Front = { 6, 5, 8, 7 },
	MinX = { 5, 1, 4, 8 },
	MaxX = { 2, 6, 7, 3 },
	Top = { 4, 3, 7, 8 },
	Bottom = { 5, 6, 2, 1 },
}
local function hexahedron(corners: { Vector3 }, skip: { [string]: boolean }?): Triangles
	local center = Vector3.zero
	for _, corner in corners do
		center += corner
	end
	center /= #corners
	local triangles = {}
	for name, face in HEXA_FACES do
		if not (skip and skip[name]) then
			addQuad(triangles, corners[face[1]], corners[face[2]], corners[face[3]], corners[face[4]], center)
		end
	end
	return triangles
end
Landmarks.Hexahedron = hexahedron

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

-- Portal arches ------------------------------------------------------------------------------

local ARCH_STONES = 9 -- voussoirs (odd: the middle one is the keystone)
local ARCH_RING = 2.6 -- radial thickness of the arch stones
local ARCH_DEPTH = 3.4 -- thickness of the arch along the conveyor
local ARCH_SPRING = 8 -- height of the pillars, where the arch starts
local JOINT = 0.12 -- mortar joint between two stones
local CAPITAL_HEIGHT = 0.9
local PLINTH_HEIGHT = 1.2
local DISC_BOTTOM = 1.3 -- the disc stays above the conveyor borders

--[[
	Stone arch over the conveyor with a faceted magic disc in its opening. Critters walk through
	the opening (halfOpening on each side of the belt's centre line, ARCH_SPRING + halfOpening
	high). position: ground point under the middle of the opening.

	Layout (u = across the conveyor, v = up, w = along the conveyor):
	  plinth -> two shaft blocks -> capital -> nine voussoirs (keystone in the middle) -> sign.
	Every piece rests exactly on the one below it; voussoirs are separated by thin joints.
]]
function Landmarks.Portal(parent: Instance, position: Vector3, halfOpening: number, text: string, color: Color3): Model
	local model = Instance.new("Model")
	model.Name = "Portal"
	model.Parent = parent

	-- u -> world Z, v -> world Y, w -> world -X.
	local frame = CFrame.fromMatrix(position, Vector3.zAxis, Vector3.yAxis)
	local function at(u: number, v: number, w: number): Vector3
		return frame:PointToWorldSpace(Vector3.new(u, v, w))
	end
	local function block(name: string, size: Vector3, u: number, v: number, w: number, tint: Color3, material: Enum.Material?)
		Decor.Part({
			Name = name,
			Size = size,
			CFrame = frame * CFrame.new(u, v, w),
			Color = tint,
			Material = material or Enum.Material.Slate,
		}, model)
	end

	local inner = halfOpening
	local outer = inner + ARCH_RING
	local half = ARCH_DEPTH / 2

	-- Pillars: the shaft has exactly the arch's cross-section, so the first and last voussoirs
	-- sit flush on the capitals.
	local shaftTop = ARCH_SPRING - CAPITAL_HEIGHT
	local shaftSplit = PLINTH_HEIGHT + (shaftTop - PLINTH_HEIGHT) / 2
	for _, side in { -1, 1 } do
		local u = side * (inner + ARCH_RING / 2)
		block("Plinth", Vector3.new(ARCH_RING + 1, PLINTH_HEIGHT, ARCH_DEPTH + 1), u, PLINTH_HEIGHT / 2, 0, STONE_DARK)
		local lowHeight = shaftSplit - JOINT / 2 - PLINTH_HEIGHT
		block("Pillar", Vector3.new(ARCH_RING, lowHeight, ARCH_DEPTH), u, PLINTH_HEIGHT + lowHeight / 2, 0, STONE)
		local highHeight = shaftTop - shaftSplit - JOINT / 2
		block("Pillar", Vector3.new(ARCH_RING, highHeight, ARCH_DEPTH), u, shaftTop - highHeight / 2, 0, STONE_DARK)
		block("Capital", Vector3.new(ARCH_RING + 0.8, CAPITAL_HEIGHT, ARCH_DEPTH + 0.8), u, shaftTop + CAPITAL_HEIGHT / 2, 0, KEYSTONE)
		Landmarks.Brazier(model, at(side * (outer + 1.7), 0, 3), 5, color)
	end

	-- Voussoirs: wedge-shaped stones between two radial planes, edge to edge around the opening.
	local function ringPoint(radius: number, angle: number, w: number): Vector3
		return at(math.cos(angle) * radius, ARCH_SPRING + math.sin(angle) * radius, w)
	end
	local gap = JOINT / 2 / inner
	local keyIndex = (ARCH_STONES - 1) / 2
	local keyTop = 0
	for index = 0, ARCH_STONES - 1 do
		local a0 = math.pi * index / ARCH_STONES + (if index > 0 then gap else 0)
		local a1 = math.pi * (index + 1) / ARCH_STONES - (if index < ARCH_STONES - 1 then gap else 0)
		local isKey = index == keyIndex
		local out = if isKey then outer + 1 else outer
		local depth = if isKey then half + 0.3 else half
		if isKey then
			keyTop = ARCH_SPRING + math.sin(a0) * out
		end
		local corners = {
			ringPoint(inner, a0, -depth),
			ringPoint(inner, a1, -depth),
			ringPoint(out, a1, -depth),
			ringPoint(out, a0, -depth),
			ringPoint(inner, a0, depth),
			ringPoint(inner, a1, depth),
			ringPoint(out, a1, depth),
			ringPoint(out, a0, depth),
		}
		-- The end faces resting on the capitals are hidden.
		local skip = { MinX = index == 0, MaxX = index == ARCH_STONES - 1 }
		local tint = if isKey then KEYSTONE elseif index % 2 == 0 then STONE else STONE_DARK
		LowPoly.DrawTriangles(hexahedron(corners, skip), facets("ArchStone", tint, Enum.Material.Slate, true), model, 0.3)
	end

	-- Rune gems on both faces of the keystone.
	for _, side in { -1, 1 } do
		local w = side * (half + 0.3)
		local y = ARCH_SPRING + outer - 0.6
		LowPoly.DrawTriangles({
			{ A = at(0, y + 1, w), B = at(-0.8, y, w), C = at(0, y - 1, w) },
			{ A = at(0, y + 1, w), B = at(0, y - 1, w), C = at(0.8, y, w) },
		}, {
			Name = "KeystoneRune",
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
			CollisionGroup = "Decor",
		}, model, 0.12)
	end

	-- Magic disc: a fan of glowing facets inside the opening (a smaller copy of the intrados).
	local discRadius = inner - 0.6
	local outline = { at(discRadius, DISC_BOTTOM, 0), at(discRadius, ARCH_SPRING, 0) }
	for step = 1, ARCH_STONES - 1 do
		local angle = math.pi * step / ARCH_STONES
		table.insert(outline, at(math.cos(angle) * discRadius, ARCH_SPRING + math.sin(angle) * discRadius, 0))
	end
	table.insert(outline, at(-discRadius, ARCH_SPRING, 0))
	table.insert(outline, at(-discRadius, DISC_BOTTOM, 0))
	table.insert(outline, at(0, DISC_BOTTOM, 0))
	local hub = at(0, ARCH_SPRING - 1, 0)
	local light = color:Lerp(WHITE, 0.4)
	for index, point in outline do
		local nextPoint = outline[index % #outline + 1]
		LowPoly.DrawTriangles({ { A = hub, B = point, C = nextPoint } }, {
			Name = "MagicDisc",
			Color = if index % 2 == 0 then color else light,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			CanCollide = false,
			CastShadow = false,
			CollisionGroup = "Decor",
		}, model, 0.15)
	end
	local core = Decor.Part({
		Name = "MagicCore",
		Size = Vector3.new(discRadius * 2, ARCH_SPRING + discRadius - DISC_BOTTOM, 0.4),
		CFrame = frame * CFrame.new(0, (DISC_BOTTOM + ARCH_SPRING + discRadius) / 2, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	}, model)
	Decor.Light(core, color, 28, 2)
	local swirl = Instance.new("ParticleEmitter")
	swirl.Color = ColorSequence.new(color, WHITE)
	swirl.LightEmission = 1
	swirl.Rate = 25
	swirl.Lifetime = NumberRange.new(1, 2)
	swirl.Speed = NumberRange.new(1, 3)
	swirl.SpreadAngle = Vector2.new(180, 180)
	swirl.Size = NumberSequence.new(0.6, 0)
	swirl.Parent = core

	-- Sign resting on the keystone: bottom trim, board, top trim, finials and a gem.
	local signWidth = halfOpening * 1.5
	block("SignTrim", Vector3.new(signWidth + 0.6, 0.4, 0.9), 0, keyTop + 0.2, 0, GOLD, Enum.Material.Metal)
	local board = Decor.Part({
		Name = "PortalSign",
		Size = Vector3.new(signWidth, 3.6, 0.7),
		CFrame = frame * CFrame.new(0, keyTop + 0.4 + 1.8, 0),
		Color = SIGN_BOARD,
	}, model)
	makeSurfaceText(board, Enum.NormalId.Front, text, color:Lerp(WHITE, 0.25))
	makeSurfaceText(board, Enum.NormalId.Back, text, color:Lerp(WHITE, 0.25))
	local trimTop = keyTop + 4
	block("SignTrim", Vector3.new(signWidth + 0.6, 0.4, 0.9), 0, trimTop + 0.2, 0, GOLD, Enum.Material.Metal)
	local gold = facets("SignFinial", GOLD, Enum.Material.Metal)
	local top = trimTop + 0.4
	for _, side in { -1, 1 } do
		local u = side * (signWidth / 2 + 0.3)
		LowPoly.Triangle(at(u, top, 0), at(u - side * 1.4, top, 0), at(u, top + 1.4, 0), gold, model)
	end
	local gemProps = facets("SignGem", color, Enum.Material.Neon)
	gemProps.CastShadow = false
	LowPoly.Ball(CFrame.new(at(0, top + 1.1, 0)), Vector3.new(1.4, 2, 1.4), gemProps, model, 0)

	return model
end

-- Shared helpers -----------------------------------------------------------------------------

local WOOD = Color3.fromRGB(150, 104, 70)
local WOOD_DARK = Color3.fromRGB(112, 76, 54)
local IRON = Color3.fromRGB(52, 46, 64)
local WATER = Color3.fromRGB(110, 190, 245)
local LILY = Color3.fromRGB(86, 168, 92)

local function newModel(name: string, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

local function invisibleAnchor(name: string, cframe: CFrame, size: Vector3, parent: Instance): BasePart
	return Decor.Part({
		Name = name,
		Size = size,
		CFrame = cframe,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	}, parent)
end

local function glowProps(name: string, color: Color3): LowPoly.PartProps
	local props = facets(name, color, Enum.Material.Neon)
	props.CastShadow = false
	return props
end

-- Unit mesh scaled to `size` and placed at `cframe`, as triangles.
local function meshTriangles(data: LowPoly.MeshData, cframe: CFrame, size: Vector3): Triangles
	return LowPoly.MeshTriangles(LowPoly.TransformMesh(data, cframe, size), cframe.Position)
end

-- Side band of a prism from `bottom` to `top` (no caps): the top ring is turned by half a step so
-- every facet is a triangle.
local function prismSides(bottom: Vector3, top: Vector3, radius: number, topRadius: number, sides: number, twist: number): (Triangles, { [number]: Vector3 })
	local axis = (top - bottom).Unit
	local u, v = LowPoly.Perpendiculars(axis, Vector3.new(math.cos(twist), 0, math.sin(twist)))
	local low, high = {}, {}
	for k = 0, sides - 1 do
		local a = k * math.pi * 2 / sides
		local b = a + math.pi / sides
		low[k] = bottom + u * (math.cos(a) * radius) + v * (math.sin(a) * radius)
		high[k] = top + u * (math.cos(b) * topRadius) + v * (math.sin(b) * topRadius)
	end
	local inside = (bottom + top) / 2
	local triangles = {}
	for k = 0, sides - 1 do
		local k1 = (k + 1) % sides
		table.insert(triangles, { A = low[k], B = low[k1], C = high[k], Inside = inside })
		table.insert(triangles, { A = low[k1], B = high[k1], C = high[k], Inside = inside })
	end
	return triangles, high
end

-- Braziers ----------------------------------------------------------------------------------

--[[
	Fire brazier: a slim iron post carrying a faceted bowl (an upside-down pentagonal pyramid whose
	tip rests on the post) with a fire and a warm light (~12 parts). Non-collidable.
]]
function Landmarks.Brazier(parent: Instance, base: Vector3, height: number, accent: Color3): Model
	local model = newModel("Brazier", parent)
	Decor.Part({
		Name = "BrazierPost",
		Size = Vector3.new(0.45, height, 0.45),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, math.rad(45), 0),
		Color = IRON,
		Material = Enum.Material.Metal,
		CanCollide = false,
	}, model)
	local rim = base + Vector3.new(0, height + 1, 0)
	local bowl = facets("BrazierBowl", IRON:Lerp(accent, 0.25), Enum.Material.Metal)
	local parts = LowPoly.DrawTriangles(LowPoly.ConeTriangles(rim, base + Vector3.new(0, height, 0), 1.1, 5, false), bowl, model, 0.1)
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 6
	fire.Color = Color3.fromRGB(255, 140, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 90)
	fire.Parent = invisibleAnchor("BrazierFire", CFrame.new(rim + Vector3.new(0, 0.2, 0)), Vector3.new(1, 0.4, 1), model)
	if parts[1] then
		Decor.Light(parts[1], Color3.fromRGB(255, 170, 80), 16, 1.8)
	end
	return model
end

-- Spawn fountain ------------------------------------------------------------------------------

--[[
	Octagonal stone basin with a pyramid spout, a raised bowl and a floating magic crystal
	(~150 parts). center: ground point in the middle.
]]
function Landmarks.Fountain(parent: Instance, center: Vector3, color: Color3): Model
	local model = newModel("Fountain", parent)
	local sides = 8
	local inner, outer, height = 6, 7.4, 1.5
	local function at(radius: number, angle: number, y: number): Vector3
		return center + Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
	end

	local wall = {}
	for k = 0, sides - 1 do
		local a0, a1 = k * math.pi * 2 / sides, (k + 1) * math.pi * 2 / sides
		local mid = at((inner + outer) / 2, (a0 + a1) / 2, height / 2)
		local corners = {
			at(inner, a0, 0),
			at(inner, a1, 0),
			at(outer, a1, 0),
			at(outer, a0, 0),
			at(inner, a0, height),
			at(inner, a1, height),
			at(outer, a1, height),
			at(outer, a0, height),
		}
		-- Outer face, inner face and top; the ends touch the neighbouring segments.
		addQuad(wall, corners[4], corners[3], corners[7], corners[8], mid)
		addQuad(wall, corners[2], corners[1], corners[5], corners[6], mid)
		addQuad(wall, corners[5], corners[8], corners[7], corners[6], mid)
	end
	LowPoly.DrawTriangles(wall, facets("Basin", STONE, Enum.Material.Slate, true), model, 0.3)

	-- Water surfaces (a fan in the basin and one in the bowl).
	local water = facets("Water", WATER, Enum.Material.Glass)
	water.Transparency = 0.3
	water.CastShadow = false
	local function pool(y: number, radius: number): { BasePart }
		local triangles = {}
		local hub = center + Vector3.new(0, y, 0)
		for k = 0, sides - 1 do
			local a0, a1 = k * math.pi * 2 / sides, (k + 1) * math.pi * 2 / sides
			table.insert(triangles, { A = hub, B = at(radius, a0, y), C = at(radius, a1, y), Inside = hub - Vector3.yAxis })
		end
		return LowPoly.DrawTriangles(triangles, water, model, 0.2)
	end
	pool(1.05, inner + 0.05)

	-- Spout and raised bowl.
	LowPoly.DrawTriangles(
		LowPoly.ConeTriangles(center, center + Vector3.new(0, 6, 0), 1.6, 6, false),
		facets("Spout", STONE_DARK, Enum.Material.Slate, true),
		model,
		0.2
	)
	local bowlTop, bowlBottom, bowlRadius = 5.6, 4.2, 3.2
	LowPoly.DrawTriangles(
		-- Ring turned like the water fans (first vertex towards +X).
		LowPoly.ConeTriangles(center + Vector3.new(0, bowlTop, 0), center + Vector3.new(0, bowlBottom, 0), bowlRadius, sides, false, Vector3.xAxis),
		facets("Bowl", STONE, Enum.Material.Slate),
		model,
		0.2
	)
	local bowlWater = pool(5.35, bowlRadius * (5.35 - bowlBottom) / (bowlTop - bowlBottom))
	if bowlWater[1] then
		local drops = Instance.new("ParticleEmitter")
		drops.Color = ColorSequence.new(Color3.fromRGB(190, 230, 255))
		drops.LightEmission = 0.4
		drops.Rate = 40
		drops.Lifetime = NumberRange.new(0.7, 0.9)
		drops.Speed = NumberRange.new(4, 5)
		drops.SpreadAngle = Vector2.new(25, 180)
		drops.EmissionDirection = Enum.NormalId.Top
		drops.Acceleration = Vector3.new(0, -22, 0)
		drops.Size = NumberSequence.new(0.35, 0.1)
		drops.Parent = bowlWater[1]
	end

	-- Floating crystal.
	local crystalFrame = CFrame.new(center + Vector3.new(0, 9.2, 0)) * CFrame.Angles(0, math.rad(15), 0)
	LowPoly.DrawTriangles(
		meshTriangles(LowPoly.Bipyramid(6, 0), crystalFrame, Vector3.new(2.2, 4.4, 2.2)),
		glowProps("FountainCrystal", color),
		model,
		0.15
	)
	local core = invisibleAnchor("FountainGlow", crystalFrame, Vector3.new(2, 2, 2), model)
	Decor.Light(core, color, 30, 2)
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(color, Color3.fromRGB(120, 220, 255))
	sparkle.LightEmission = 1
	sparkle.Rate = 12
	sparkle.Lifetime = NumberRange.new(1.5, 2.5)
	sparkle.Speed = NumberRange.new(2, 4)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Acceleration = Vector3.new(0, -3, 0)
	sparkle.Size = NumberSequence.new(0.4, 0)
	sparkle.Parent = core
	return model
end

-- Spawn statues and banners ------------------------------------------------------------------

--[[
	Stone guardian (a sitting fox-like critter) with glowing eyes on a faceted plinth (~130 parts).
	base: ground point, facing: horizontal direction the statue looks at.
]]
function Landmarks.GuardianStatue(parent: Instance, base: Vector3, facing: Vector3, accent: Color3): Model
	local model = newModel("GuardianStatue", parent)
	local frame = CFrame.lookAt(base, base + Vector3.new(facing.X, 0, facing.Z))
	local function at(x: number, y: number, z: number): Vector3
		return frame:PointToWorldSpace(Vector3.new(x, y, z))
	end

	-- Plinth: a frustum (5 x 5 at the ground, 4.2 x 4.2 on top) with a gold band.
	local lowHalf, topHalf, plinthTop = 2.5, 2.1, 2.2
	local plinth = Landmarks.Hexahedron({
		at(-lowHalf, 0, -lowHalf),
		at(lowHalf, 0, -lowHalf),
		at(topHalf, plinthTop, -topHalf),
		at(-topHalf, plinthTop, -topHalf),
		at(-lowHalf, 0, lowHalf),
		at(lowHalf, 0, lowHalf),
		at(topHalf, plinthTop, topHalf),
		at(-topHalf, plinthTop, topHalf),
	}, { Bottom = true })
	LowPoly.DrawTriangles(plinth, facets("Plinth", STONE_DARK, Enum.Material.Slate, true), model, 0.3)
	Decor.Part({
		Name = "PlinthBand",
		Size = Vector3.new(topHalf * 2 + 0.3, 0.3, topHalf * 2 + 0.3),
		CFrame = frame * CFrame.new(0, plinthTop + 0.15, 0),
		Color = GOLD,
		Material = Enum.Material.Metal,
	}, model)

	local y0 = plinthTop + 0.3
	local stone = facets("Statue", KEYSTONE)
	local function shape(data: LowPoly.MeshData, cframe: CFrame, size: Vector3)
		LowPoly.DrawTriangles(meshTriangles(data, cframe, size), stone, model, 0.2)
	end
	-- Body, head, snout, ears and a big tail curling up behind.
	shape(LowPoly.Gyrobipyramid(), frame * CFrame.new(0, y0 + 1.9, 0.3), Vector3.new(3.2, 4, 2.8))
	local head = frame * CFrame.new(0, y0 + 4.7, -0.4)
	local headMesh = LowPoly.TransformMesh(LowPoly.Icosahedron(), head, Vector3.new(2.9, 2.6, 2.7))
	LowPoly.DrawTriangles(LowPoly.MeshTriangles(headMesh, head.Position), stone, model, 0.2)
	LowPoly.DrawTriangles(
		LowPoly.ConeTriangles(at(0, y0 + 4.3, -1), at(0, y0 + 4.1, -2.6), 0.7, 4, false),
		stone,
		model,
		0.15
	)
	for _, side in { -1, 1 } do
		LowPoly.DrawTriangles(
			LowPoly.ConeTriangles(at(side * 0.7, y0 + 5.2, -0.3), at(side * 1.2, y0 + 7, -0.1), 0.5, 3, true),
			stone,
			model,
			0.12
		)
	end
	-- Glowing eyes: shrunken copies of the two upper front facets of the head (faces 2 and 18 of
	-- the icosahedron, on each side of its front vertex), just in front of them.
	local eyeProps = glowProps("Eye", accent)
	for _, faceIndex in { 2, 18 } do
		local face = headMesh.Faces[faceIndex]
		local a, b, c = headMesh.Vertices[face[1]], headMesh.Vertices[face[2]], headMesh.Vertices[face[3]]
		local centroid = (a + b + c) / 3
		local normal = (b - a):Cross(c - a).Unit
		if (centroid - head.Position):Dot(normal) < 0 then
			normal = -normal
		end
		local function shrink(point: Vector3): Vector3
			return centroid + (point - centroid) * 0.32 + normal * 0.06
		end
		LowPoly.Triangle(shrink(a), shrink(b), shrink(c), eyeProps, model)
	end
	shape(
		LowPoly.Bipyramid(4, 0),
		frame * CFrame.new(1, y0 + 1.8, 1.9) * CFrame.Angles(math.rad(-25), 0, math.rad(-20)),
		Vector3.new(1.6, 4.6, 1.6)
	)
	return model
end

--[[
	Tall banner: pole, gold finial, crossbar and a swallow-tailed cloth with a gold emblem on both
	sides (~18 parts). facing: the direction the cloth faces.
]]
function Landmarks.Banner(parent: Instance, base: Vector3, height: number, color: Color3, facing: Vector3): Model
	local model = newModel("Banner", parent)
	local frame = CFrame.lookAt(base, base + Vector3.new(facing.X, 0, facing.Z))
	local function at(x: number, y: number, z: number): Vector3
		return frame:PointToWorldSpace(Vector3.new(x, y, z))
	end
	Decor.Part({
		Name = "Pole",
		Size = Vector3.new(0.4, height, 0.4),
		CFrame = frame * CFrame.new(0, height / 2, 0),
		Color = IRON,
		Material = Enum.Material.Metal,
	}, model)
	LowPoly.DrawTriangles(
		LowPoly.ConeTriangles(at(0, height, 0), at(0, height + 1.3, 0), 0.45, 4, true),
		facets("Finial", GOLD, Enum.Material.Metal),
		model,
		0.1
	)
	local width, top, length, tail = 2.8, height - 0.7, 5.2, 1.4
	Decor.Part({
		Name = "Crossbar",
		Size = Vector3.new(width + 0.6, 0.25, 0.25),
		CFrame = frame * CFrame.new(0, top + 0.12, -0.35),
		Color = GOLD,
		Material = Enum.Material.Metal,
		CanCollide = false,
	}, model)
	local cloth = facets("Cloth", color, Enum.Material.Fabric)
	cloth.Thickness = 0.12
	local z = -0.35
	local half = width / 2
	local bottom = top - length
	-- Rectangle (two right triangles) and the swallow tail (two more).
	LowPoly.Triangle(at(-half, top, z), at(half, top, z), at(-half, bottom, z), cloth, model)
	LowPoly.Triangle(at(half, top, z), at(half, bottom, z), at(-half, bottom, z), cloth, model)
	LowPoly.Triangle(at(-half, bottom, z), at(0, bottom, z), at(-half, bottom - tail, z), cloth, model)
	LowPoly.Triangle(at(0, bottom, z), at(half, bottom, z), at(half, bottom - tail, z), cloth, model)
	local emblem = facets("Emblem", GOLD, Enum.Material.Metal)
	emblem.Thickness = 0.06
	for _, side in { -1, 1 } do
		local ez = z + side * 0.1
		LowPoly.Triangle(at(-0.9, top - 1.2, ez), at(0.9, top - 1.2, ez), at(0, top - 3.2, ez), emblem, model)
	end
	return model
end

-- Plaza lamps and garlands -------------------------------------------------------------------

--[[
	Iron lamp post with a glowing crystal held by a gold cradle (~20 parts). Non-collidable: the
	plaza must stay free to run across.
]]
function Landmarks.PlazaLamp(parent: Instance, base: Vector3, color: Color3, facing: Vector3?): Model
	local model = newModel("PlazaLamp", parent)
	local look = facing or Vector3.xAxis
	local frame = CFrame.lookAt(base, base + Vector3.new(look.X, 0, look.Z))
	local postHeight = 7
	Decor.Part({
		Name = "LampFoot",
		Size = Vector3.new(1.3, 0.7, 1.3),
		CFrame = frame * CFrame.new(0, 0.35, 0) * CFrame.Angles(0, math.rad(45), 0),
		Color = STONE_DARK,
		Material = Enum.Material.Slate,
		CanCollide = false,
	}, model)
	Decor.Part({
		Name = "LampPost",
		Size = Vector3.new(0.4, postHeight, 0.4),
		CFrame = frame * CFrame.new(0, 0.7 + postHeight / 2, 0),
		Color = IRON,
		Material = Enum.Material.Metal,
		CanCollide = false,
	}, model)
	local top = frame * CFrame.new(0, 0.7 + postHeight, 0)
	local gold = facets("LampCradle", GOLD, Enum.Material.Metal)
	gold.Thickness = 0.1
	for _, side in { -1, 1 } do
		local p0 = top.Position
		local p1 = top:PointToWorldSpace(Vector3.new(side * 0.9, 0, 0))
		LowPoly.Triangle(p0, p1, p1 + Vector3.new(0, 1.3, 0), gold, model)
	end
	local crystalFrame = top * CFrame.new(0, 1.5, 0)
	local crystal = LowPoly.DrawTriangles(
		meshTriangles(LowPoly.Bipyramid(4, 0), crystalFrame, Vector3.new(1.3, 2.4, 1.3)),
		glowProps("LampCrystal", color),
		model,
		0.1
	)
	if crystal[1] then
		Decor.Light(crystal[1], color, 18, 1.4)
	end
	return model
end

-- Rope with little triangular pennants sagging between two points (~1 part per pennant).
function Landmarks.Garland(parent: Instance, from: Vector3, to: Vector3, sag: number, colors: { Color3 }): Model
	local model = newModel("Garland", parent)
	local middle = (from + to) / 2 - Vector3.new(0, sag, 0)
	for _, pair in { { from, middle }, { middle, to } } do
		local length = (pair[2] - pair[1]).Magnitude
		Decor.Part({
			Name = "Rope",
			Size = Vector3.new(0.12, 0.12, length),
			CFrame = CFrame.lookAt((pair[1] + pair[2]) / 2, pair[2]),
			Color = Color3.fromRGB(235, 225, 200),
			CanCollide = false,
			CastShadow = false,
		}, model)
	end
	local count = math.max(2, math.floor((to - from).Magnitude / 2.6))
	for index = 1, count do
		local t = (index - 0.5) / count
		local p = if t < 0.5 then from:Lerp(middle, t * 2) else middle:Lerp(to, t * 2 - 1)
		local along = Vector3.new(to.X - from.X, 0, to.Z - from.Z).Unit
		local props = facets("Pennant", colors[(index - 1) % #colors + 1], Enum.Material.Fabric)
		props.Thickness = 0.06
		props.CastShadow = false
		LowPoly.Triangle(p, p + along * 1, p - Vector3.new(0, 1.3, 0), props, model)
	end
	return model
end

-- Fences -------------------------------------------------------------------------------------

--[[
	Rustic wooden fence from `from` to `to` (ground points): slightly uneven posts with two rails
	(3 parts per section). Decorative: players and critters pass through.
]]
function Landmarks.Fence(parent: Instance, from: Vector3, to: Vector3, seed: number): Model
	local rng = Decor.Rng(seed)
	local model = newModel("Fence", parent)
	local length = (to - from).Magnitude
	local sections = math.max(1, math.ceil(length / 4.5))
	local tops = {}
	for index = 0, sections do
		local foot = from:Lerp(to, index / sections)
		local height = rng:NextNumber(2.2, 2.6)
		Decor.Part({
			Name = "FencePost",
			Size = Vector3.new(0.45, height, 0.45),
			CFrame = CFrame.new(foot + Vector3.new(0, height / 2 - 0.1, 0))
				* CFrame.Angles(rng:NextNumber(-0.05, 0.05), rng:NextNumber(0, 1.5), rng:NextNumber(-0.05, 0.05)),
			Color = WOOD_DARK,
			Material = Enum.Material.Wood,
			CanCollide = false,
		}, model)
		tops[index] = foot
	end
	for index = 0, sections - 1 do
		for _, y in { 0.8, 1.7 } do
			local a = tops[index] + Vector3.new(0, y + rng:NextNumber(-0.08, 0.08), 0)
			local b = tops[index + 1] + Vector3.new(0, y + rng:NextNumber(-0.08, 0.08), 0)
			Decor.Part({
				Name = "FenceRail",
				Size = Vector3.new(0.18, 0.32, (b - a).Magnitude + 0.3),
				CFrame = CFrame.lookAt((a + b) / 2, b),
				Color = WOOD,
				Material = Enum.Material.Wood,
				CanCollide = false,
			}, model)
		end
	end
	return model
end

-- Ruins --------------------------------------------------------------------------------------

-- Small octahedron stone lying on the ground (~12 parts).
local function rubble(model: Model, position: Vector3, size: Vector3, rng: Decor.Rng, color: Color3)
	local frame = CFrame.new(position + Vector3.new(0, size.Y * 0.2, 0))
		* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.3, 0.3))
	local triangles = Decor.AboveGround(meshTriangles(LowPoly.Octahedron(), frame, size), position.Y)
	Decor.DrawShaded(triangles, facets("Rubble", color, Enum.Material.Slate), model, 0.2, rng, 0.06)
end

--[[
	Column standing on the ground point `base` (~25 parts + base and capital blocks). A broken
	column ends in a jagged point instead of a capital.
]]
local function column(model: Model, base: Vector3, height: number, broken: boolean, rng: Decor.Rng)
	local sides = 5
	Decor.Part({
		Name = "ColumnBase",
		Size = Vector3.new(2.6, 0.8, 2.6),
		CFrame = CFrame.new(base + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, rng:NextNumber(-0.1, 0.1), 0),
		Color = STONE_DARK,
		Material = Enum.Material.Slate,
	}, model)
	local bottom = base + Vector3.new(0, 0.8, 0)
	local top = base + Vector3.new(0, height, 0)
	local triangles, ring = prismSides(bottom, top, 0.95, 0.85, sides, rng:NextNumber(0, math.pi * 2))
	if broken then
		local peak = top + Vector3.new(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0.4, 1.1), rng:NextNumber(-0.4, 0.4))
		for k = 0, sides - 1 do
			local k1 = (k + 1) % sides
			table.insert(triangles, { A = ring[k], B = ring[k1], C = peak, Inside = top - Vector3.new(0, 1, 0) })
		end
	else
		Decor.Part({
			Name = "Capital",
			Size = Vector3.new(2.5, 0.7, 2.5),
			CFrame = CFrame.new(top + Vector3.new(0, 0.35, 0)),
			Color = KEYSTONE,
			Material = Enum.Material.Slate,
		}, model)
	end
	Decor.DrawShaded(triangles, facets("Column", STONE, Enum.Material.Slate, true), model, 0.2, rng, 0.05)
end

--[[
	Ruined shrine: four columns (two still carrying a lintel, two broken), cracked floor slabs, a
	fallen drum and rubble (~200 parts). yaw: rotation around the vertical axis (radians).
]]
function Landmarks.Ruins(parent: Instance, center: Vector3, yaw: number, seed: number): Model
	local rng = Decor.Rng(seed)
	local model = newModel("Ruins", parent)
	local frame = CFrame.new(center) * CFrame.Angles(0, yaw, 0)
	local function at(x: number, z: number): Vector3
		return frame:PointToWorldSpace(Vector3.new(x, 0, z))
	end

	for _, slab in { { -2.6, -2.4, 5.4, 4.6 }, { 2.7, -2.2, 5, 5 }, { -2.4, 2.8, 5.2, 5.2 } } do
		Decor.Part({
			Name = "FloorSlab",
			Size = Vector3.new(slab[3], 0.5, slab[4]),
			CFrame = frame
				* CFrame.new(slab[1], 0.1, slab[2])
				* CFrame.Angles(rng:NextNumber(-0.04, 0.04), rng:NextNumber(-0.15, 0.15), rng:NextNumber(-0.04, 0.04)),
			Color = STONE:Lerp(STONE_DARK, rng:NextNumber(0, 0.5)),
			Material = Enum.Material.Slate,
		}, model)
	end

	local height = 9.5
	column(model, at(-4.5, -4.5), height, false, rng)
	column(model, at(4.5, -4.5), height, false, rng)
	column(model, at(-4.5, 4.5), 5.2, true, rng)
	column(model, at(4.5, 4.5), 2.6, true, rng)
	-- Lintel resting on the two capitals.
	Decor.Part({
		Name = "Lintel",
		Size = Vector3.new(11.6, 1.2, 2.3),
		CFrame = frame * CFrame.new(0, height + 0.7 + 0.6, -4.5),
		Color = STONE,
		Material = Enum.Material.Slate,
	}, model)
	local vine = facets("Vine", Color3.fromRGB(92, 160, 84))
	vine.Thickness = 0.06
	vine.CastShadow = false
	for _, x in { -3, 1.5 } do
		local p = frame:PointToWorldSpace(Vector3.new(x, height + 0.7, -5.7))
		LowPoly.Triangle(p, p + frame.RightVector * 1.4, p - Vector3.new(0, 2.6, 0), vine, model)
	end

	-- Fallen column drum lying on the ground, closed at both ends.
	local a, b = at(7.5, 1), at(8.5, 7.2)
	local lift = Vector3.new(0, 0.8, 0)
	local drum, ringB = prismSides(a + lift, b + lift, 0.85, 0.85, 5, 0.4)
	local _, ringA = prismSides(b + lift, a + lift, 0.85, 0.85, 5, 0.4)
	for k = 0, 4 do
		local k1 = (k + 1) % 5
		table.insert(drum, { A = ringB[k], B = ringB[k1], C = b + lift, Inside = (a + b) / 2 + lift })
		table.insert(drum, { A = ringA[k], B = ringA[k1], C = a + lift, Inside = (a + b) / 2 + lift })
	end
	Decor.DrawShaded(drum, facets("FallenColumn", STONE, Enum.Material.Slate, true), model, 0.2, rng, 0.05)

	for _ = 1, 4 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(6.5, 9)
		local position = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		rubble(model, position, Vector3.new(rng:NextNumber(1.2, 2), rng:NextNumber(0.8, 1.3), rng:NextNumber(1.2, 2)), rng, STONE)
	end
	Flora.Grass(model, at(0, 0), 7, 7, seed + 5)
	return model
end

--[[
	What is left of an old arch: one complete pillar carrying three voussoirs, a broken pillar and
	a fallen stone (~120 parts).
]]
function Landmarks.BrokenArch(parent: Instance, center: Vector3, yaw: number, seed: number): Model
	local rng = Decor.Rng(seed)
	local model = newModel("BrokenArch", parent)
	local frame = CFrame.new(center) * CFrame.Angles(0, yaw, 0)
	local inner, ring, depth, spring = 4.5, 1.8, 2.2, 6
	local half = depth / 2
	local function at(u: number, v: number, w: number): Vector3
		return frame:PointToWorldSpace(Vector3.new(u, v, w))
	end
	local u = -(inner + ring / 2)
	Decor.Part({
		Name = "Pillar",
		Size = Vector3.new(ring, spring, depth),
		CFrame = frame * CFrame.new(u, spring / 2, 0),
		Color = STONE,
		Material = Enum.Material.Slate,
	}, model)
	Decor.Part({
		Name = "Pillar",
		Size = Vector3.new(ring, 2.6, depth),
		CFrame = frame * CFrame.new(-u, 1.3, 0) * CFrame.Angles(0, 0, math.rad(4)),
		Color = STONE_DARK,
		Material = Enum.Material.Slate,
	}, model)
	local stones = 7
	local gap = JOINT / 2 / inner
	local function ringPoint(radius: number, angle: number, w: number): Vector3
		-- Angle 0 points to the broken side (+u); the surviving stones start at angle pi.
		return at(math.cos(angle) * radius, spring + math.sin(angle) * radius, w)
	end
	for index = 0, 2 do
		local a1 = math.pi - math.pi * index / stones - (if index > 0 then gap else 0)
		local a0 = math.pi - math.pi * (index + 1) / stones + gap
		local outer = inner + ring
		local corners = {
			ringPoint(inner, a0, -half),
			ringPoint(inner, a1, -half),
			ringPoint(outer, a1, -half),
			ringPoint(outer, a0, -half),
			ringPoint(inner, a0, half),
			ringPoint(inner, a1, half),
			ringPoint(outer, a1, half),
			ringPoint(outer, a0, half),
		}
		LowPoly.DrawTriangles(
			hexahedron(corners, { MaxX = index == 0 }),
			facets("ArchStone", if index % 2 == 0 then STONE else STONE_DARK, Enum.Material.Slate, true),
			model,
			0.25
		)
	end
	rubble(model, at(1.5, 0, 2.6), Vector3.new(2.2, 1.6, 1.8), rng, STONE)
	rubble(model, at(4, 0, -2.4), Vector3.new(1.4, 1, 1.4), rng, STONE_DARK)
	Flora.Grass(model, at(0, 0, 0), 4, 5, seed + 3)
	return model
end

-- Water features -----------------------------------------------------------------------------

--[[
	Arched wooden footbridge from `from` to `to` (ground points on both shores): plank deck you can
	walk on, posts and hand rails (~45 parts).
]]
function Landmarks.Bridge(parent: Instance, from: Vector3, to: Vector3, width: number, rise: number): Model
	local model = newModel("Bridge", parent)
	local along = Vector3.new(to.X - from.X, 0, to.Z - from.Z).Unit
	local across = along:Cross(Vector3.yAxis)
	local function arc(t: number): Vector3
		return from:Lerp(to, t) + Vector3.new(0, rise * 4 * t * (1 - t), 0)
	end
	local planks = 12
	for index = 0, planks - 1 do
		local p0, p1 = arc(index / planks), arc((index + 1) / planks)
		Decor.Part({
			Name = "Plank",
			Size = Vector3.new(width, 0.45, (p1 - p0).Magnitude + 0.08),
			CFrame = CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.new(0, -0.2, 0),
			Color = if index % 2 == 0 then WOOD else WOOD:Lerp(WOOD_DARK, 0.4),
			Material = Enum.Material.WoodPlanks,
		}, model)
	end
	local posts = 6
	for _, side in { -1, 1 } do
		local offset = across * side * (width / 2 - 0.25)
		local previous: Vector3? = nil
		for index = 0, posts - 1 do
			local foot = arc(index / (posts - 1)) + offset
			Decor.Part({
				Name = "Post",
				Size = Vector3.new(0.4, 2.8, 0.4),
				CFrame = CFrame.new(foot + Vector3.new(0, 1.2, 0)),
				Color = WOOD_DARK,
				Material = Enum.Material.Wood,
			}, model)
			local railPoint = foot + Vector3.new(0, 2.5, 0)
			if previous then
				Decor.Part({
					Name = "HandRail",
					Size = Vector3.new(0.3, 0.3, (railPoint - previous).Magnitude + 0.3),
					CFrame = CFrame.lookAt((previous + railPoint) / 2, railPoint),
					Color = WOOD,
					Material = Enum.Material.Wood,
				}, model)
			end
			previous = railPoint
		end
	end
	return model
end

--[[
	Stones to hop across a pond (`points` on the water surface): an almost flat, walkable top (a very
	shallow pyramid 0.35-0.55 above the water) on a steep skirt plunging into the water (2 triangles
	per side, ~20-24 parts each). Collidable; a few top facets are mossy.
]]
function Landmarks.SteppingStones(parent: Instance, points: { Vector3 }, seed: number): Model
	local rng = Decor.Rng(seed)
	local model = newModel("SteppingStones", parent)
	local props = facets("SteppingStone", STONE, Enum.Material.Slate, true)
	for _, point in points do
		local sides = rng:NextInteger(5, 6)
		local radius = rng:NextNumber(1.6, 1.9)
		local twist = rng:NextNumber(0, math.pi * 2)
		local rim = {}
		for k = 0, sides - 1 do
			local angle = twist + k * math.pi * 2 / sides
			local r = radius * rng:NextNumber(0.9, 1.08)
			rim[k] = point + Vector3.new(math.cos(angle) * r, rng:NextNumber(0.32, 0.4), math.sin(angle) * r)
		end
		local top = point + Vector3.new(rng:NextNumber(-0.2, 0.2), 0.55, rng:NextNumber(-0.2, 0.2))
		local bottom = point - Vector3.new(0, 1.8, 0)
		local inside = point - Vector3.new(0, 0.3, 0)
		local triangles = {}
		for k = 0, sides - 1 do
			local k1 = (k + 1) % sides
			table.insert(triangles, { A = rim[k], B = rim[k1], C = top, Inside = inside })
			table.insert(triangles, { A = rim[k1], B = rim[k], C = bottom, Inside = inside })
		end
		Decor.DrawShaded(triangles, props, model, 0.2, rng, 0.07, function(normal: Vector3): Color3?
			return if normal.Y > 0.9 and rng:NextNumber(0, 1) < 0.35 then Color3.fromRGB(120, 160, 104) else nil
		end)
	end
	return model
end

--[[
	Lily pads floating on a pond: three right-angled quarter facets around the stem with the
	classic notch in the fourth quarter (3 parts each); every other pad carries a water lily (four
	pointed petals around a glowing heart, 9 parts).
]]
function Landmarks.LilyPads(parent: Instance, center: Vector3, radius: number, count: number, seed: number): Model
	local rng = Decor.Rng(seed)
	local model = newModel("LilyPads", parent)
	local petal = facets("Lily", Color3.fromRGB(255, 196, 224))
	petal.CastShadow = false
	petal.Thickness = 0.06
	local heart = glowProps("LilyHeart", Color3.fromRGB(255, 226, 120))
	heart.Thickness = 0.06
	for index = 1, count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = math.sqrt(rng:NextNumber(0, 1)) * radius
		local hub = center + Vector3.new(math.cos(angle) * distance, 0.08, math.sin(angle) * distance)
		local size = rng:NextNumber(1.3, 2)
		local turn = rng:NextNumber(0, math.pi * 2)
		local pad = facets("LilyPad", LILY:Lerp(WHITE, rng:NextNumber(0, 0.12)))
		pad.CastShadow = false
		pad.Thickness = 0.06
		for k = 0, 2 do
			local a = turn + k * math.pi / 2
			local d1 = Vector3.new(math.cos(a), 0, math.sin(a))
			local d2 = Vector3.new(-d1.Z, 0, d1.X)
			LowPoly.Triangle(hub, hub + d1 * size, hub + d2 * size * rng:NextNumber(0.9, 1.05), pad, model)
		end
		if index % 2 == 0 then
			-- Petals rising around the heart, their tips leaning outwards.
			local head = hub + Vector3.new(0, 0.06, 0)
			for k = 0, 3 do
				local a = turn + (k + 0.5) * math.pi / 2
				local out = Vector3.new(math.cos(a), 0, math.sin(a))
				local side = Vector3.new(-out.Z, 0, out.X)
				LowPoly.Triangle(head + side * 0.3, head - side * 0.3, head + out * 0.75 + Vector3.new(0, 0.55, 0), petal, model)
			end
			LowPoly.Triangle(head, head + Vector3.new(0.25, 0, 0), head + Vector3.new(0, 0.3, 0.25), heart, model)
		end
	end
	return model
end

return Landmarks
