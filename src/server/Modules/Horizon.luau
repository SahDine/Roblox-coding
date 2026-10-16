--[[
	Horizon
	The far scenery, drawn with big low-poly triangles: snowy mountain ranges around the map,
	clouds and floating islands with waterfalls. All of it is out of reach (non-collidable) and
	casts no shadow, so it costs nothing to the physics and little to the renderer.
]]

local LowPoly = require(script.Parent.LowPoly)
local Decor = require(script.Parent.Decor)
local Flora = require(script.Parent.Flora)

local Horizon = {}

type Triangles = { LowPoly.TriangleWithInside }

local WHITE = Color3.new(1, 1, 1)
local SNOW = Color3.fromRGB(246, 244, 255)
local MOUNTAIN_ROCK = Color3.fromRGB(132, 118, 160)
local MOUNTAIN_FOOT = Color3.fromRGB(96, 142, 110)
local CLOUD = Color3.fromRGB(255, 252, 255)
local CLOUD_SHADE = Color3.fromRGB(214, 206, 236)
local ISLAND_GRASS = Color3.fromRGB(112, 190, 96)
local ISLAND_EARTH = Color3.fromRGB(128, 94, 76)
local ISLAND_ROCK = Color3.fromRGB(122, 112, 140)
local WATER = Color3.fromRGB(150, 214, 255)

local function newModel(name: string, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

local function farProps(name: string, color: Color3): LowPoly.PartProps
	local props = Decor.Facets(name, color)
	props.CastShadow = false
	return props
end

local function ring(center: Vector3, count: number, radius: number, y: number, twist: number, rng: Decor.Rng, jitter: number): { [number]: Vector3 }
	local points = {}
	for k = 0, count - 1 do
		local angle = twist + (k + rng:NextNumber(-jitter, jitter)) * math.pi * 2 / count
		local r = radius * rng:NextNumber(1 - jitter, 1 + jitter * 0.5)
		points[k] = center + Vector3.new(math.cos(angle) * r, y, math.sin(angle) * r)
	end
	return points
end

--[[
	Mountain on the ground point `base`: a jagged base ring, a shoulder ring, a summit ring and a
	peak (5 * sides triangles). Snowy mountains get a zig-zag snow cap.
]]
function Horizon.Mountain(parent: Instance, base: Vector3, radius: number, height: number, seed: number, snowy: boolean, sides: number?): Model
	local rng = Decor.Rng(seed)
	local model = newModel("Mountain", parent)
	local n = sides or 6
	local step = math.pi * 2 / n
	local twist = rng:NextNumber(0, math.pi * 2)
	local foot = ring(base, n, radius, -8, twist, rng, 0.18)
	local shoulder = ring(base, n, radius * rng:NextNumber(0.5, 0.6), height * rng:NextNumber(0.4, 0.5), twist + step / 2, rng, 0.15)
	local summit = ring(base, n, radius * rng:NextNumber(0.2, 0.27), height * rng:NextNumber(0.72, 0.8), twist + step, rng, 0.12)
	local peak = base + Vector3.new(rng:NextNumber(-0.06, 0.06) * radius, height, rng:NextNumber(-0.06, 0.06) * radius)
	local inside = base + Vector3.new(0, height * 0.3, 0)

	local lower, upper, snow = {}, {}, {}
	local function add(list: Triangles, a: Vector3, b: Vector3, c: Vector3)
		table.insert(list, { A = a, B = b, C = c, Inside = inside })
	end
	for k = 0, n - 1 do
		local k1 = (k + 1) % n
		add(lower, foot[k], foot[k1], shoulder[k])
		add(lower, shoulder[k], foot[k1], shoulder[k1])
		-- summit[k] sits between shoulder[k] and shoulder[k1].
		add(upper, shoulder[k], shoulder[k1], summit[k])
		add(if snowy then snow else upper, summit[k], shoulder[k1], summit[k1])
		add(if snowy then snow else upper, summit[k], summit[k1], peak)
	end
	local thickness = 1
	Decor.DrawShaded(lower, farProps("Slope", MOUNTAIN_FOOT), model, thickness, rng, 0.06, function(normal: Vector3): Color3?
		-- Steep facets are bare rock, gentle ones stay green.
		return if normal.Y < 0.55 then MOUNTAIN_ROCK:Lerp(MOUNTAIN_FOOT, 0.35) else nil
	end)
	Decor.DrawShaded(upper, farProps("Rock", MOUNTAIN_ROCK), model, thickness, rng, 0.07)
	Decor.DrawShaded(snow, farProps("Snow", SNOW), model, thickness, rng, 0.03)
	return model
end

-- Puffy low-poly cloud: an icosahedron and two smaller flat puffs, shaded lavender underneath (~72 parts).
function Horizon.Cloud(parent: Instance, center: Vector3, scale: number, seed: number): Model
	local rng = Decor.Rng(seed)
	local model = newModel("Cloud", parent)
	local s = scale
	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local puffs = {
		{ LowPoly.Icosahedron(), Vector3.zero, Vector3.new(16, 8, 12) },
		{ LowPoly.Octahedron(), Vector3.new(9.5, -1.6, rng:NextNumber(-2, 2)), Vector3.new(11, 5.4, 8.5) },
		{ LowPoly.Octahedron(), Vector3.new(-9, -2, rng:NextNumber(-2, 2)), Vector3.new(10, 4.8, 8) },
	}
	for _, puff in puffs do
		local frame = CFrame.new(center) * yaw * CFrame.new(puff[2] * s) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local triangles = LowPoly.MeshTriangles(LowPoly.TransformMesh(puff[1], frame, puff[3] * s), frame.Position)
		Decor.DrawShaded(triangles, farProps("Cloud", CLOUD), model, 0.6, rng, 0.02, function(normal: Vector3): Color3?
			return if normal.Y < -0.3 then CLOUD_SHADE else nil
		end)
	end
	return model
end

--[[
	Floating island centred on `center` (its grass top): a grass fan, an earth band and a long rock
	spike underneath, with a tree and crystals on top and a waterfall pouring off the rim towards
	`fallTo` (a world height; the water ends in a cloud of mist there).
	fallSide: horizontal direction of the waterfall. crystalColor (optional): adds a glowing crystal
	cluster next to the tree.
]]
function Horizon.FloatingIsland(
	parent: Instance,
	center: Vector3,
	scale: number,
	seed: number,
	fallSide: Vector3,
	fallTo: number,
	crystalColor: Color3?
): Model
	local rng = Decor.Rng(seed)
	local model = newModel("FloatingIsland", parent)
	local s = scale
	local n = 7
	local step = math.pi * 2 / n
	local radius = 14 * s
	local twist = math.atan2(fallSide.Z, fallSide.X) -- a rim vertex faces the waterfall
	local rim = {}
	for k = 0, n - 1 do
		local angle = twist + k * step
		local r = if k == 0 then radius else radius * rng:NextNumber(0.82, 1.08)
		rim[k] = center + Vector3.new(math.cos(angle) * r, rng:NextNumber(-0.4, 0.2) * s, math.sin(angle) * r)
	end
	local earth = ring(center, n, radius * 0.86, -3.2 * s, twist + step / 2, rng, 0.06)
	local belly = ring(center, n, radius * 0.5, -10 * s, twist, rng, 0.1)
	local tip = center + Vector3.new(rng:NextNumber(-2, 2) * s, -22 * s, rng:NextNumber(-2, 2) * s)
	local top = center + Vector3.new(0, 0.8 * s, 0)
	local inside = center - Vector3.new(0, 5 * s, 0)

	local grass, dirt, rock = {}, {}, {}
	for k = 0, n - 1 do
		local k1 = (k + 1) % n
		table.insert(grass, { A = rim[k], B = rim[k1], C = top, Inside = inside })
		table.insert(dirt, { A = rim[k], B = earth[k], C = rim[k1], Inside = inside })
		table.insert(dirt, { A = rim[k1], B = earth[k], C = earth[k1], Inside = inside })
		-- belly[k1] sits between earth[k] and earth[k1].
		table.insert(rock, { A = earth[k], B = belly[k1], C = earth[k1], Inside = inside })
		table.insert(rock, { A = earth[k], B = belly[k], C = belly[k1], Inside = inside })
		table.insert(rock, { A = belly[k], B = tip, C = belly[k1], Inside = inside })
	end
	Decor.DrawShaded(grass, farProps("IslandGrass", ISLAND_GRASS), model, 0.8, rng, 0.05)
	Decor.DrawShaded(dirt, farProps("IslandEarth", ISLAND_EARTH), model, 0.8, rng, 0.06)
	Decor.DrawShaded(rock, farProps("IslandRock", ISLAND_ROCK), model, 0.8, rng, 0.07)

	-- Something growing on top (props stand on the slightly domed grass).
	local side = Vector3.new(-fallSide.Z, 0, fallSide.X)
	local ground = center + Vector3.new(0, 0.3 * s, 0)
	if seed % 2 == 0 then
		Flora.Pine(model, ground - fallSide * 4 * s + side * 3 * s, 1.1 * s, seed + 1, nil, 5)
	else
		Flora.RoundTree(model, ground - fallSide * 4 * s + side * 3 * s, 0.9 * s, seed + 1)
	end
	if crystalColor then
		Flora.CrystalCluster(model, ground - side * 5 * s, 0.6 * s, seed + 2, crystalColor)
	end

	-- Waterfall: a stream over the grass, then a straight sheet of water down to `fallTo`.
	local lip = rim[0] + fallSide * 0.3 * s
	local width = 3 * s
	local across = side.Unit * (width / 2)
	local water = farProps("Waterfall", WATER)
	water.Material = Enum.Material.Glass
	water.Transparency = 0.3
	water.Thickness = 0.3
	local source = center + fallSide * radius * 0.35 + Vector3.new(0, 0.85 * s, 0)
	LowPoly.Triangle(source + across, source - across, lip + across, water, model)
	LowPoly.Triangle(source - across, lip - across, lip + across, water, model)
	local bottom = Vector3.new(lip.X, fallTo, lip.Z) + fallSide * 1.5 * s
	LowPoly.Triangle(lip + across, lip - across, bottom + across * 1.4, water, model)
	LowPoly.Triangle(lip - across, bottom - across * 1.4, bottom + across * 1.4, water, model)

	local mist = Decor.Part({
		Name = "Mist",
		Size = Vector3.new(width * 2, 1, width * 2),
		CFrame = CFrame.new(bottom),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	}, model)
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(WHITE)
	spray.LightEmission = 0.3
	spray.Transparency = NumberSequence.new(0.4, 1)
	spray.Rate = 14
	spray.Lifetime = NumberRange.new(1.5, 2.5)
	spray.Speed = NumberRange.new(2, 4)
	spray.SpreadAngle = Vector2.new(70, 70)
	spray.Acceleration = Vector3.new(0, 1.5, 0)
	spray.Size = NumberSequence.new(1.5 * s, 4 * s)
	spray.Parent = mist
	return model
end

return Horizon
