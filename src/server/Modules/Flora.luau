--[[
	Flora
	Low-poly nature props drawn with triangles (LowPoly): round trees, pines, cherry trees, crystal
	trees, bushes, boulders, crystal clusters, giant mushrooms, flower patches, grass and reeds.

	Every prop is a Model of anchored WedgeParts in the "Decor" collision group (critters walk
	through everything). Only what players should bump into collides: trunks, stems and boulders.
	Faces buried in the ground are not drawn. Each prop is placed on a ground point `base` and
	varies with its `seed` (deterministic: every server builds the same forest).
	Rough cost in parts is given for each prop (a triangle costs 1 or 2 WedgeParts).
]]

local LowPoly = require(script.Parent.LowPoly)
local Decor = require(script.Parent.Decor)

local Flora = {}

type Triangles = { LowPoly.TriangleWithInside }
type Rng = Decor.Rng

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local BARK = Color3.fromRGB(116, 82, 64)
local DARK_BARK = Color3.fromRGB(84, 62, 58)
local CHERRY_BARK = Color3.fromRGB(96, 64, 72)
local CRYSTAL_BARK = Color3.fromRGB(70, 58, 92)
local STEM = Color3.fromRGB(246, 236, 214)
local ROCK = Color3.fromRGB(150, 144, 162)
local MOSS = Color3.fromRGB(110, 164, 92)

Flora.LeafGreens = {
	Color3.fromRGB(96, 178, 84),
	Color3.fromRGB(122, 190, 78),
	Color3.fromRGB(72, 160, 104),
	Color3.fromRGB(150, 196, 82),
}
Flora.PineGreens = {
	Color3.fromRGB(46, 120, 84),
	Color3.fromRGB(40, 108, 98),
	Color3.fromRGB(60, 128, 74),
}
Flora.Blossoms = {
	Color3.fromRGB(255, 176, 210),
	Color3.fromRGB(250, 150, 196),
	Color3.fromRGB(255, 204, 226),
}
Flora.FlowerColors = {
	Color3.fromRGB(255, 120, 150),
	Color3.fromRGB(255, 214, 90),
	Color3.fromRGB(180, 130, 255),
	Color3.fromRGB(120, 200, 255),
	Color3.fromRGB(255, 255, 240),
	Color3.fromRGB(255, 150, 90),
}

local function newModel(name: string, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

-- Unit mesh scaled to `size` (full extents) and placed at `cframe`, as triangles.
local function meshTriangles(data: LowPoly.MeshData, cframe: CFrame, size: Vector3): Triangles
	return LowPoly.MeshTriangles(LowPoly.TransformMesh(data, cframe, size), cframe.Position)
end

-- A position turned by a random angle around the vertical axis.
local function yawed(position: Vector3, rng: Rng): CFrame
	return CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
end

-- Horizontal unit vector at a random angle (also used to turn the rings of cones).
local function randomFlat(rng: Rng): Vector3
	local angle = rng:NextNumber(0, math.pi * 2)
	return Vector3.new(math.cos(angle), 0, math.sin(angle))
end
Flora.RandomFlat = randomFlat

local function pick<T>(list: { T }, rng: Rng): T
	return list[rng:NextInteger(1, #list)]
end

-- Faceted pyramid trunk from just under the ground to `top` (hidden in the crown).
local function trunk(model: Model, base: Vector3, top: Vector3, radius: number, rng: Rng, color: Color3, sides: number, solid: boolean?)
	local triangles = LowPoly.ConeTriangles(base - Vector3.new(0, 0.6, 0), top, radius, sides, false, randomFlat(rng))
	Decor.DrawShaded(
		Decor.AboveGround(triangles, base.Y),
		Decor.Facets("Trunk", color, Enum.Material.SmoothPlastic, solid ~= false),
		model,
		Decor.Thickness(radius),
		rng,
		0.06
	)
end

local function blob(model: Model, name: string, data: LowPoly.MeshData, center: Vector3, size: Vector3, color: Color3, rng: Rng, groundY: number?)
	local triangles = meshTriangles(data, yawed(center, rng), size)
	if groundY then
		triangles = Decor.AboveGround(triangles, groundY)
	end
	local props = Decor.Facets(name, color)
	return Decor.DrawShaded(triangles, props, model, Decor.Thickness(math.min(size.X, size.Y, size.Z)), rng, 0.07)
end

-- Trees -------------------------------------------------------------------------------------

-- Round-canopy tree, ~8 studs tall at scale 1 (~40-60 parts).
function Flora.RoundTree(parent: Instance, base: Vector3, scale: number, seed: number, leafColor: Color3?): Model
	local rng = Decor.Rng(seed)
	local s = scale
	local model = newModel("RoundTree", parent)
	local leaf = leafColor or pick(Flora.LeafGreens, rng)
	local crown = base + Vector3.new(0, 7.5 * s, 0) + randomFlat(rng) * rng:NextNumber(0, 0.8) * s
	trunk(model, base, crown, 0.85 * s, rng, BARK, 4)
	local size = Vector3.new(rng:NextNumber(8, 9.4), rng:NextNumber(6.6, 7.6), rng:NextNumber(8, 9.4)) * s
	blob(model, "Leaves", LowPoly.Gyrobipyramid(), crown, size, leaf, rng)
	if s >= 0.9 then
		local side = randomFlat(rng)
		local center = crown + side * 3.6 * s + Vector3.new(0, -1.3 * s, 0)
		blob(model, "Leaves", LowPoly.Octahedron(), center, Vector3.new(5, 4.4, 5) * s, leaf:Lerp(BLACK, 0.1), rng)
	end
	return model
end

-- Pine with stacked cones, ~11 studs tall at scale 1 (36 parts with 5 sides, 42 with 6).
function Flora.Pine(parent: Instance, base: Vector3, scale: number, seed: number, needles: Color3?, sides: number?): Model
	local rng = Decor.Rng(seed)
	local s = scale
	local model = newModel("Pine", parent)
	local color = needles or pick(Flora.PineGreens, rng)
	trunk(model, base, base + Vector3.new(0, 4 * s, 0), 0.7 * s, rng, DARK_BARK, 3)
	local y = 2.2 * s
	local radius = rng:NextNumber(4.2, 4.9) * s
	for tier = 1, 3 do
		local height = (5.6 - tier * 0.6) * s
		local triangles = LowPoly.ConeTriangles(
			base + Vector3.new(0, y, 0),
			base + Vector3.new(0, y + height, 0),
			radius,
			sides or 5,
			false,
			randomFlat(rng)
		)
		Decor.DrawShaded(triangles, Decor.Facets("Needles", color:Lerp(WHITE, tier * 0.04)), model, Decor.Thickness(radius * 0.4), rng, 0.06)
		y += height * 0.55
		radius *= 0.72
	end
	return model
end

--[[
	Cheap pine silhouette for the hills behind the invisible walls, seen only from afar: two
	four-sided tiers and no trunk (16 parts).
]]
function Flora.FarPine(parent: Instance, base: Vector3, scale: number, seed: number): Model
	local rng = Decor.Rng(seed)
	local s = scale
	local model = newModel("FarPine", parent)
	local color = pick(Flora.PineGreens, rng):Lerp(BLACK, 0.06)
	local props = Decor.Facets("Needles", color)
	props.CastShadow = false
	local y, radius = 0.6 * s, rng:NextNumber(4.4, 5) * s
	for tier = 1, 2 do
		local height = (if tier == 1 then 7.4 else 5.8) * s
		local triangles = LowPoly.ConeTriangles(base + Vector3.new(0, y, 0), base + Vector3.new(0, y + height, 0), radius, 4, false, randomFlat(rng))
		props.Color = color:Lerp(WHITE, tier * 0.05)
		Decor.DrawShaded(triangles, props, model, Decor.Thickness(radius * 0.4), rng, 0.05)
		y += height * 0.5
		radius *= 0.66
	end
	return model
end

-- Pink cherry tree with falling petals, ~10 studs tall at scale 1 (~80 parts).
function Flora.CherryTree(parent: Instance, base: Vector3, scale: number, seed: number): Model
	local rng = Decor.Rng(seed)
	local s = scale
	local model = newModel("CherryTree", parent)
	local side = randomFlat(rng)
	local crown = base + Vector3.new(0, 7.5 * s, 0) - side * 0.8 * s
	trunk(model, base, crown + Vector3.new(0, 1 * s, 0), 0.8 * s, rng, CHERRY_BARK, 4)
	-- One branch leaning out under the side blob.
	local fork = base + Vector3.new(0, 3.6 * s, 0) - side * 0.3 * s
	local branchTip = crown + side * 3.6 * s - Vector3.new(0, 0.6 * s, 0)
	Decor.DrawShaded(
		LowPoly.ConeTriangles(fork, branchTip, 0.42 * s, 3, false, randomFlat(rng)),
		Decor.Facets("Branch", CHERRY_BARK),
		model,
		0.05,
		rng,
		0.05
	)
	local pink = pick(Flora.Blossoms, rng)
	local main = blob(model, "Blossom", LowPoly.Gyrobipyramid(), crown, Vector3.new(9, 6.2, 9) * s, pink, rng)
	blob(model, "Blossom", LowPoly.Octahedron(), branchTip + Vector3.new(0, 0.6 * s, 0), Vector3.new(5.6, 4.4, 5.6) * s, pink:Lerp(WHITE, 0.2), rng)
	blob(model, "Blossom", LowPoly.Octahedron(), crown - side * 3.4 * s + Vector3.new(0, 0.8 * s, 0), Vector3.new(5, 4, 5) * s, pink:Lerp(BLACK, 0.06), rng)

	-- Petals drifting down from the crown.
	local emitterPart = Decor.Part({
		Name = "Petals",
		Size = Vector3.new(8, 1, 8) * s,
		CFrame = CFrame.new(crown - Vector3.new(0, 2 * s, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	}, model)
	local petals = Instance.new("ParticleEmitter")
	petals.Color = ColorSequence.new(pink:Lerp(WHITE, 0.3))
	petals.Rate = 2
	petals.Lifetime = NumberRange.new(4, 7)
	petals.Speed = NumberRange.new(0.2, 0.6)
	petals.SpreadAngle = Vector2.new(180, 180)
	petals.Acceleration = Vector3.new(0.4, -1, 0.2)
	petals.Rotation = NumberRange.new(0, 360)
	petals.RotSpeed = NumberRange.new(-90, 90)
	petals.Size = NumberSequence.new(0.25)
	petals.Parent = emitterPart
	if main[1] then
		Decor.Light(main[1], pink, 10 * s, 0.5)
	end
	return model
end

-- Magic tree: dark trunk with glowing crystal leaves (~65 parts).
function Flora.CrystalTree(parent: Instance, base: Vector3, scale: number, seed: number, color: Color3): Model
	local rng = Decor.Rng(seed)
	local s = scale
	local model = newModel("CrystalTree", parent)
	local top = base + Vector3.new(0, 7 * s, 0) + randomFlat(rng) * 0.6 * s
	trunk(model, base, top, 0.85 * s, rng, CRYSTAL_BARK, 3)

	local tips = { top + Vector3.new(0, 0.4 * s, 0) }
	local angle = rng:NextNumber(0, math.pi * 2)
	for index = 1, 2 do
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local fork = base + Vector3.new(0, (3.6 + index * 0.9) * s, 0)
		local tip = fork + direction * 3.4 * s + Vector3.new(0, 2.2 * s, 0)
		Decor.DrawShaded(
			LowPoly.ConeTriangles(fork, tip, 0.4 * s, 3, false, randomFlat(rng)),
			Decor.Facets("Branch", CRYSTAL_BARK),
			model,
			0.05,
			rng,
			0.05
		)
		table.insert(tips, tip)
		angle += math.pi * rng:NextNumber(0.8, 1.2)
	end
	for index, tip in tips do
		local size = (if index == 1 then Vector3.new(2.6, 5, 2.6) else Vector3.new(2, 3.6, 2)) * s
		local center = tip + Vector3.new(0, size.Y * 0.3, 0)
		local frame = yawed(center, rng) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25))
		local props = Decor.Facets("CrystalLeaf", color:Lerp(WHITE, if index == 1 then 0 else 0.25), Enum.Material.Glass)
		props.Transparency = 0.15
		props.CastShadow = false
		local parts = LowPoly.DrawTriangles(meshTriangles(LowPoly.Bipyramid(4, -0.2), frame, size), props, model, 0.12)
		if index == 1 and parts[1] then
			Decor.Light(parts[1], color, 16 * s, 1.4)
		end
	end
	return model
end

-- Small props ---------------------------------------------------------------------------------

-- Leafy bush half sunk in the ground (~24 parts).
function Flora.Bush(parent: Instance, base: Vector3, scale: number, seed: number, color: Color3?): Model
	local rng = Decor.Rng(seed)
	local model = newModel("Bush", parent)
	local size = Vector3.new(rng:NextNumber(3.6, 4.6), rng:NextNumber(2.6, 3.2), rng:NextNumber(3.6, 4.6)) * scale
	local leaf = color or pick(Flora.LeafGreens, rng):Lerp(BLACK, 0.08)
	blob(model, "Bush", LowPoly.Gyrobipyramid(), base + Vector3.new(0, size.Y * 0.15, 0), size, leaf, rng, base.Y)
	return model
end

-- Irregular rock mesh: a gyrobipyramid (16 faces, cheaper than LowPoly.RockData's icosahedron)
-- with every vertex pushed in or out.
local function rockData(rng: Rng, roughness: number): LowPoly.MeshData
	local data = LowPoly.Gyrobipyramid()
	for index, vertex in data.Vertices do
		data.Vertices[index] = vertex * (1 + rng:NextNumber(-roughness, roughness))
	end
	return data
end

--[[
	Irregular boulder, 40 % of it buried so its lower pyramid is never drawn (~24 parts).
	size = full extents. Boulders taller than 2.5 studs collide; mossy ones get green facets on top.
]]
function Flora.Boulder(parent: Instance, base: Vector3, size: Vector3, seed: number, color: Color3?, mossy: boolean?): Model
	local rng = Decor.Rng(seed)
	local model = newModel("Boulder", parent)
	local center = base + Vector3.new(0, size.Y * 0.1, 0)
	local triangles = Decor.AboveGround(meshTriangles(rockData(rng, 0.2), yawed(center, rng), size), base.Y)
	local props = Decor.Facets("Boulder", color or ROCK, Enum.Material.SmoothPlastic, size.Y > 2.5)
	local tint = if mossy
		then function(normal: Vector3): Color3?
			return if normal.Y > 0.72 then MOSS else nil
		end
		else nil
	Decor.DrawShaded(triangles, props, model, Decor.Thickness(math.min(size.X, size.Y, size.Z)), rng, 0.06, tint)
	return model
end

-- Glowing crystal cluster: a big double-pointed shard and a few small ones (~40 parts).
function Flora.CrystalCluster(parent: Instance, base: Vector3, scale: number, seed: number, color: Color3): Model
	local rng = Decor.Rng(seed)
	local s = scale
	local model = newModel("CrystalCluster", parent)

	local mainSize = Vector3.new(2.2, 7, 2.2) * s
	local mainFrame = yawed(base + Vector3.new(0, mainSize.Y * 0.32, 0), rng)
		* CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12))
	local glow = Decor.Facets("Crystal", color:Lerp(BLACK, 0.25), Enum.Material.Neon)
	glow.Transparency = 0.1
	glow.CastShadow = false
	local main = LowPoly.DrawTriangles(
		Decor.AboveGround(meshTriangles(LowPoly.Bipyramid(4, -0.25), mainFrame, mainSize), base.Y),
		glow,
		model,
		0.15
	)
	if main[1] then
		Decor.Light(main[1], color, 16 * s, 1.3)
	end

	local glass = Decor.Facets("Crystal", color:Lerp(WHITE, 0.2), Enum.Material.Glass)
	glass.Transparency = 0.2
	glass.CastShadow = false
	local angle = rng:NextNumber(0, math.pi * 2)
	for _ = 1, 3 do
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local foot = base + direction * rng:NextNumber(1, 1.6) * s - Vector3.new(0, 0.4, 0)
		local axis = (Vector3.yAxis + direction * rng:NextNumber(0.35, 0.7)).Unit
		local tip = foot + axis * rng:NextNumber(2.6, 4.4) * s
		LowPoly.DrawTriangles(LowPoly.ConeTriangles(foot, tip, rng:NextNumber(0.55, 0.8) * s, 4, false, randomFlat(rng)), glass, model, 0.1)
		angle += math.pi * 2 / 3 + rng:NextNumber(-0.3, 0.3)
	end
	return model
end

--[[
	Giant glowing mushroom (~50 parts): faceted stem, two-ring cap with a few pale spot facets and a
	glowing underside.
]]
function Flora.Mushroom(parent: Instance, base: Vector3, scale: number, seed: number, capColor: Color3): Model
	local rng = Decor.Rng(seed)
	local s = scale
	local model = newModel("Mushroom", parent)
	local sides = 5
	local stemTop = 6.2 * s
	local lean = randomFlat(rng) * rng:NextNumber(0.2, 0.9) * s
	local capBase = base + Vector3.new(0, stemTop, 0) + lean
	trunk(model, base, capBase + Vector3.new(0, 1.2 * s, 0), 1.15 * s, rng, STEM, 5)

	local rimRadius = rng:NextNumber(4.2, 4.9) * s
	local twist = rng:NextNumber(0, math.pi * 2)
	local rim, upper = {}, {}
	for k = 0, sides - 1 do
		local a = twist + k * math.pi * 2 / sides
		local b = a + math.pi / sides
		rim[k] = capBase + Vector3.new(math.cos(a) * rimRadius, -0.3 * s, math.sin(a) * rimRadius)
		upper[k] = capBase + Vector3.new(math.cos(b) * rimRadius * 0.62, 1.9 * s, math.sin(b) * rimRadius * 0.62)
	end
	local top = capBase + Vector3.new(0, 3.1 * s, 0)
	local inside = capBase + Vector3.new(0, 0.8 * s, 0)
	local cap = {}
	for k = 0, sides - 1 do
		local k1 = (k + 1) % sides
		table.insert(cap, { A = rim[k], B = rim[k1], C = upper[k], Inside = inside })
		table.insert(cap, { A = rim[k1], B = upper[k1], C = upper[k], Inside = inside })
		table.insert(cap, { A = upper[k], B = upper[k1], C = top, Inside = inside })
	end
	local spots = { [rng:NextInteger(1, 5)] = true, [rng:NextInteger(6, 10)] = true, [rng:NextInteger(11, 15)] = true }
	local index = 0
	Decor.DrawShaded(cap, Decor.Facets("Cap", capColor), model, Decor.Thickness(rimRadius * 0.4), rng, 0.05, function(): Color3?
		index += 1
		return if spots[index] then capColor:Lerp(WHITE, 0.75) else nil
	end)

	-- Glowing gills under the cap.
	local gills = {}
	local hub = capBase - Vector3.new(0, 0.9 * s, 0)
	for k = 0, sides - 1 do
		table.insert(gills, { A = rim[k], B = rim[(k + 1) % sides], C = hub, Inside = inside })
	end
	local glow = Decor.Facets("Gills", capColor:Lerp(WHITE, 0.45), Enum.Material.Neon)
	glow.CastShadow = false
	local parts = LowPoly.DrawTriangles(gills, glow, model, 0.12)
	if parts[1] then
		Decor.Light(parts[1], capColor:Lerp(WHITE, 0.3), 14 * s, 1.2)
	end
	return model
end

--[[
	Patch of little flowers (~4 parts each): a leaf blade and three flat pinwheel petals, every
	triangle right-angled so it costs a single WedgePart.
]]
function Flora.FlowerPatch(parent: Instance, center: Vector3, radius: number, count: number, seed: number, palette: { Color3 }?): Model
	local rng = Decor.Rng(seed)
	local model = newModel("Flowers", parent)
	local colors = palette or Flora.FlowerColors
	local leaf = Decor.Facets("Leaf", Color3.fromRGB(84, 160, 80))
	leaf.CastShadow = false
	leaf.Thickness = 0.08
	for _ = 1, count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = math.sqrt(rng:NextNumber(0, 1)) * radius
		local foot = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local height = rng:NextNumber(0.9, 1.5)
		local side = randomFlat(rng)
		LowPoly.Triangle(foot, foot + side * 0.45, foot + Vector3.new(0, height, 0), leaf, model)

		local head = foot + Vector3.new(0, height, 0)
		local petal = Decor.Facets("Petal", pick(colors, rng))
		petal.CastShadow = false
		petal.Thickness = 0.08
		local size = rng:NextNumber(0.45, 0.65)
		local turn = rng:NextNumber(0, math.pi * 2)
		for k = 0, 2 do
			local a = turn + k * math.pi * 2 / 3
			local d1 = Vector3.new(math.cos(a), 0, math.sin(a))
			local d2 = Vector3.new(math.cos(a + math.pi / 2), 0, math.sin(a + math.pi / 2))
			LowPoly.Triangle(head, head + d1 * size, head + d2 * size, petal, model)
		end
	end
	return model
end

-- Tuft of grass blades (1 part per blade).
function Flora.Grass(parent: Instance, center: Vector3, radius: number, blades: number, seed: number, color: Color3?): Model
	local rng = Decor.Rng(seed)
	local model = newModel("Grass", parent)
	local props = Decor.Facets("Blade", color or Color3.fromRGB(104, 176, 82))
	props.CastShadow = false
	props.Thickness = 0.08
	for _ = 1, blades do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(0, radius)
		local foot = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local side = randomFlat(rng)
		local height = rng:NextNumber(0.9, 1.8)
		props.Color = (color or Color3.fromRGB(104, 176, 82)):Lerp(WHITE, rng:NextNumber(0, 0.15))
		LowPoly.Triangle(foot, foot + side * rng:NextNumber(0.35, 0.6), foot + Vector3.new(0, height, 0), props, model)
	end
	return model
end

-- Reeds and cattails for pond edges (2 parts per reed).
function Flora.Reeds(parent: Instance, center: Vector3, radius: number, count: number, seed: number): Model
	local rng = Decor.Rng(seed)
	local model = newModel("Reeds", parent)
	local blade = Decor.Facets("Reed", Color3.fromRGB(96, 150, 78))
	blade.CastShadow = false
	blade.Thickness = 0.08
	for _ = 1, count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(0, radius)
		local foot = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local side = randomFlat(rng)
		local height = rng:NextNumber(2.6, 4)
		LowPoly.Triangle(foot, foot + side * 0.4, foot + Vector3.new(0, height, 0), blade, model)
		Decor.Part({
			Name = "Cattail",
			Size = Vector3.new(0.3, 0.9, 0.3),
			CFrame = CFrame.new(foot + side * 0.08 + Vector3.new(0, height - 0.9, 0)),
			Color = Color3.fromRGB(110, 70, 50),
			CanCollide = false,
			CastShadow = false,
		}, model)
	end
	return model
end

return Flora
