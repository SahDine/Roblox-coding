--[[
	Landmarks
	The big low-poly set pieces of the map, drawn with triangles (LowPoly) plus a few plain parts
	for what players walk on or read: the conveyor portal arches, the spawn fountain, guardian
	statues, stone ruins, the pond bridge and stepping stones, the mountain ranges on the horizon
	and the floating islands with their waterfalls.

	Nothing here interpenetrates by accident: arch stones, pillars and signs meet face to face.
]]

local LowPoly = require(script.Parent.LowPoly)
local Decor = require(script.Parent.Decor)

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
		Decor.Torch(model, at(side * (outer + 1.7), 0, 3), 5)
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

return Landmarks
