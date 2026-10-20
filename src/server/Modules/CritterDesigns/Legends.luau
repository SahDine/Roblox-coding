--[[
	Critter designs: Frostwing, Voltwing, Pyrowing, Wishstar, Skyserpent, Abysswing, Glitchno, Primordeus.
	See CritterBuilder for the toolkit. Ground at y = 0, the critter faces -Z.
	Triangle style: every surface is faceted (sculpted low-poly balls, tubes, pyramids and flat triangles), only
	the eyes and the mouths are round, and every moving part lives in a bone (heads, wings, tails, legs, arms,
	floating shards, the golden ring). The flyers hover (b.Hover) with their wings in Wing bones.
	The legendary bird trio shares one body plan (body, neck, legs, wing and tail helpers) so they read as a set.
]]

local V = Vector3.new

local Designs = {}

local TAU = math.pi * 2
local UP = V(0, 1, 0)
local DOWN = V(0, -1, 0)
local SIDE = V(1, 0, 0)
local FRONT = V(0, 0, -1)
local BACK = V(0, 0, 1)
-- Thin plates for flat triangles and small pointed shapes (thick plates poke through near the tips).
local THIN = { Thickness = 0.06 }
-- Tube segments: thin plates so they do not poke out of the next segment where the body bends.
local SKIN = { Thickness = 0.08 }

-- Geometry helpers ----------------------------------------------------------------------------

-- Unit low-poly ball with the toolkit's layout: detail 2 = icosahedron (20 facets), 1 = 16 facets,
-- 0 = octahedron (8 facets). A vertex on top, the first ring vertex at the front (-Z).
local function ballData(detail: number): ({ Vector3 }, { { number } })
	local vertices, faces = {}, {}
	if detail <= 0 then
		vertices = { V(0, 1, 0), V(1, 0, 0), V(0, 0, 1), V(-1, 0, 0), V(0, 0, -1), V(0, -1, 0) }
		for i = 0, 3 do
			local r1, r2 = 2 + i, 2 + (i + 1) % 4
			table.insert(faces, { 1, r1, r2 })
			table.insert(faces, { 6, r2, r1 })
		end
		return vertices, faces
	end
	local n = if detail >= 2 then 5 else 4
	local ringY = if detail >= 2 then 1 / math.sqrt(5) else 0.36
	local ringR = if detail >= 2 then 2 / math.sqrt(5) else 0.93
	vertices[1] = V(0, 1, 0)
	for ring = 0, 1 do
		for i = 0, n - 1 do
			local angle = (i + ring * 0.5) * TAU / n
			table.insert(vertices, V(math.sin(angle) * ringR, if ring == 0 then ringY else -ringY, -math.cos(angle) * ringR))
		end
	end
	local bottom = 2 * n + 2
	table.insert(vertices, V(0, -1, 0))
	for i = 0, n - 1 do
		local u1, u2 = 2 + i, 2 + (i + 1) % n
		local l1, l2 = 2 + n + i, 2 + n + (i + 1) % n
		table.insert(faces, { 1, u1, u2 })
		table.insert(faces, { u1, l1, u2 })
		table.insert(faces, { u2, l1, l2 })
		table.insert(faces, { bottom, l2, l1 })
	end
	return vertices, faces
end

-- Groups faces by colour and draws one mesh per colour; returns one handle covering every facet.
local function paintedMesh(
	b,
	name: string,
	vertices: { Vector3 },
	faces: { { number } },
	colorOf,
	center: Vector3,
	size: Vector3,
	opts: any?
)
	local groups, order = {}, {}
	for index, face in faces do
		local color = colorOf(index, face)
		if not groups[color] then
			groups[color] = {}
			table.insert(order, color)
		end
		table.insert(groups[color], face)
	end
	local tris, first = {}, nil
	for index, color in order do
		local options = if type(opts) == "function" then opts(color) else opts
		local handle = b:Mesh(name .. (if index > 1 then tostring(index) else ""), vertices, groups[color], color, options)
		first = first or handle.Part
		for _, triangle in handle.Tris do
			table.insert(tris, triangle)
		end
	end
	return { Part = first, Center = center, Size = size, Tris = tris }
end

--[[
	Low-poly ball like b:Ball (same part cost) that can be sculpted and painted facet by facet.
	opts.Detail (default 2); opts.Deform(v, index) moves the unit vertices (|v| = 1, -Z = front) before scaling; opts.Paint(normal, offset)
	returns the colour of a facet (nil = `color`), in design space. Returns a handle for the face helpers.
]]
local function sculpt(b, name: string, size: Vector3, position: Vector3, rot: Vector3?, color: any, opts: any?)
	local options = opts or {}
	local unit, faces = ballData(options.Detail or 2)
	local frame = CFrame.new(position)
	if rot then
		frame *= CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	end
	local vertices = {}
	for index, v in unit do
		local shaped = if options.Deform then options.Deform(v, index) else v
		vertices[index] = frame:PointToWorldSpace(shaped * size / 2)
	end
	return paintedMesh(b, name, vertices, faces, function(_, face)
		if not options.Paint then
			return color
		end
		local a, c, d = vertices[face[1]], vertices[face[2]], vertices[face[3]]
		local centre = (a + c + d) / 3
		local normal = (c - a):Cross(d - a).Unit
		if normal:Dot(centre - position) < 0 then
			normal = -normal
		end
		return options.Paint(normal, centre - position) or color
	end, position, size, options.Mesh)
end

-- Deform: pushes the lower front vertices forwards (a muzzle), widened / lowered, the chin a little, and with
-- `bridge` the upper front vertex too (a longer snout).
local function snout(forward: number, widen: number?, drop: number?, bridge: number?)
	return function(v: Vector3): Vector3
		if v.Z < -0.5 and v.Y < 0.1 then
			return V(v.X * (widen or 1), v.Y - (drop or 0), v.Z - forward)
		elseif v.Y < -0.99 then
			return V(v.X, v.Y, v.Z - forward * 0.45)
		elseif bridge and v.Z < -0.85 and v.Y > 0 then
			return V(v.X, v.Y - bridge * 0.3, v.Z - bridge)
		end
		return v
	end
end

--[[
	Pyramid from `base` to `tip` whose bulk lies on the `down` side of the base-tip edge: two of its three
	faces are right-angled triangles (one part each), 4 parts in all (horns, crests, beaks, claws, plates).
	Sink the base into the parent shape.
]]
local function prong(b, name: string, base: Vector3, tip: Vector3, width: number, depth: number, down: Vector3, color: any, opts: any?)
	local d = (tip - base).Unit
	local dn = down - d * down:Dot(d)
	if dn.Magnitude < 1e-3 then
		dn = UP - d * d.Y
		if dn.Magnitude < 1e-3 then
			dn = SIDE - d * d.X
		end
	end
	dn = dn.Unit
	local across = d:Cross(dn) * (width / 2)
	local low = base + dn * depth
	return b:Mesh(name, { base, low + across, low - across, tip }, { { 1, 2, 4 }, { 1, 3, 4 }, { 2, 3, 4 } }, color, opts or THIN)
end

-- Flat right-angled triangle (1 part) from `base` to `tip`, `width` wide at the base, facing `facing`
-- (feathers, talons, fins). A negative width puts the wide side on the other edge.
local function feather(b, name: string, base: Vector3, tip: Vector3, width: number, facing: Vector3, color: any, opts: any?)
	local axis = tip - base
	local across = axis:Cross(facing)
	if across.Magnitude < 1e-4 then
		across = axis:Cross(UP)
	end
	return b:Tri(name, base, base + across.Unit * width, tip, color, opts or THIN)
end

--[[
	Four-sided pyramid from `base` to `tip` with a diamond section: `width` across (perpendicular to the axis and to
	`front`), `depth` along `front`. 4 facets (~8 parts): star points, plates, gems. Sink the base.
]]
local function pyramid(b, name: string, base: Vector3, tip: Vector3, width: number, depth: number, front: Vector3, color: any, opts: any?)
	local d = (tip - base).Unit
	local f = front - d * front:Dot(d)
	f = if f.Magnitude < 1e-3 then (SIDE - d * d.X).Unit else f.Unit
	local across = d:Cross(f)
	local vertices = { base - across * (width / 2), base + f * (depth / 2), base + across * (width / 2), base - f * (depth / 2), tip }
	return b:Mesh(name, vertices, { { 1, 2, 5 }, { 2, 3, 5 }, { 3, 4, 5 }, { 4, 1, 5 } }, color, opts or THIN)
end

-- Creased vane (feathers, fins, tags): two flat triangles from a base `width` wide to `tip`, folded along the
-- middle so the spine stands `ridge` towards `up` (never one flat panel). ~4 parts.
local function vane(b, name: string, base: Vector3, tip: Vector3, width: number, up: Vector3, ridge: number, color: any, opts: any?)
	local d = (tip - base).Unit
	local n = up - d * up:Dot(d)
	n = if n.Magnitude < 1e-3 then (SIDE - d * d.X).Unit else n.Unit
	local across = d:Cross(n) * (width / 2)
	local spine = base + n * ridge
	b:Tri(name .. "A", base - across, spine, tip, color, opts or THIN)
	return b:Tri(name .. "B", spine, base + across, tip, color, opts or THIN)
end

--[[
	Tube body: rings along a curve (rotation-minimising frames, every ring turned half a step so each facet is a
	real triangle). radii[i] = 0 makes that end a point. The rings are computed once for the whole curve, then
	sections are drawn inside different bones with tubePart, so the body is continuous at rest and bends at the
	bone pivots.
]]
local function tubeRings(points: { Vector3 }, radii: { number }, sides: number, hint: Vector3?, flatten: number?)
	local count = #points
	local tangents = {}
	for i = 1, count do
		tangents[i] = (points[math.min(count, i + 1)] - points[math.max(1, i - 1)]).Unit
	end
	local u = hint or FRONT
	u = u - tangents[1] * u:Dot(tangents[1])
	if u.Magnitude < 1e-3 then
		u = SIDE - tangents[1] * SIDE:Dot(tangents[1])
	end
	local data = {}
	for i = 1, count do
		local t = tangents[i]
		u = (u - t * u:Dot(t)).Unit
		local v = t:Cross(u)
		local ring = {}
		for k = 0, sides - 1 do
			local a = (k + (i - 1) * 0.5) * TAU / sides
			ring[k + 1] = points[i] + (u * math.cos(a) + v * math.sin(a) * (flatten or 1)) * radii[i]
		end
		data[i] = { Center = points[i], Radius = radii[i], Ring = ring }
	end
	return { Rings = data, Sides = sides }
end

--[[
	Draws the segments between rings first..last of a tube (one closed faceted mesh per segment and colour).
	paint(normal, segment) -> colour of a facet. The first ring is left open: start the curve inside the shape it
	grows from. With `overlap`, a section that starts mid-body (in a child bone) begins that far inside the
	previous one so no gap opens when the bone turns.
]]
local function tubePart(b, name: string, body, first: number, last: number, paint, overlap: number?, opts: any?)
	local rings, sides = body.Rings, body.Sides
	local tris = {}
	for i = first, last - 1 do
		local r1, r2 = rings[i], rings[i + 1]
		local vertices = table.clone(r1.Ring)
		if i == first and overlap and i > 1 then
			local back = (rings[i - 1].Center - r1.Center).Unit * overlap
			for k, point in vertices do
				vertices[k] = r1.Center + back + (point - r1.Center) * 0.93
			end
		end
		local faces = {}
		if r2.Radius <= 1e-4 then
			table.insert(vertices, r2.Center)
			for k = 1, sides do
				table.insert(faces, { k, k % sides + 1, sides + 1 })
			end
		else
			for k = 1, sides do
				table.insert(vertices, r2.Ring[k])
			end
			for k = 1, sides do
				local k1 = k % sides + 1
				table.insert(faces, { k, sides + k, k1 })
				table.insert(faces, { sides + k, sides + k1, k1 })
			end
		end
		local mid = (r1.Center + r2.Center) / 2
		local handle = paintedMesh(b, name .. i, vertices, faces, function(_, face)
			local a, c, d = vertices[face[1]], vertices[face[2]], vertices[face[3]]
			local normal = (c - a):Cross(d - a).Unit
			if normal:Dot((a + c + d) / 3 - mid) < 0 then
				normal = -normal
			end
			return paint(normal, i)
		end, mid, V(1, 1, 1), opts or SKIN)
		for _, triangle in handle.Tris do
			table.insert(tris, triangle)
		end
	end
	local a, c = rings[first].Center, rings[last].Center
	return { Part = nil, Center = (a + c) / 2, Size = V(1, 1, 1) + (c - a) * V(1, 1, 1), Tris = tris }
end

-- Facet painter: facets facing `dir` (within the threshold cosine) get `belly`, the others `body`.
local function facing(dir: Vector3, threshold: number, belly: any, body: any)
	local unit = dir.Unit
	return function(normal: Vector3): any
		return if normal:Dot(unit) > threshold then belly else body
	end
end

--[[
	Twisting ribbon (tail streamers): stations along `points` with half widths `widths` across `across[i]`
	(the ribbon turns with it, so every quad is two real facets, never a flat panel). A width of 0 ends in a point.
]]
local function ribbon(b, name: string, points: { Vector3 }, widths: { number }, across: { Vector3 }, colors: { any }, opts: any?)
	for i = 1, #points - 1 do
		local color = colors[math.min(i, #colors)]
		local a1, a2 = points[i], points[i + 1]
		local x1, x2 = across[i].Unit * widths[i], across[i + 1].Unit * widths[i + 1]
		if widths[i + 1] <= 1e-4 then
			b:Tri(name .. i, a1 - x1, a1 + x1, a2, color, opts or THIN)
		else
			b:Tri(name .. i .. "A", a1 - x1, a1 + x1, a2 + x2, color, opts or THIN)
			b:Tri(name .. i .. "B", a1 - x1, a2 + x2, a2 - x2, color, opts or THIN)
		end
	end
end

-- Point generator in a wing's plane: root (shoulder), `out` along the wing, `back` towards its trailing edge.
-- P(a, c, lift): `a` along the wing, `c` backwards, `lift` above its upper side.
local function wingPlane(root: Vector3, out: Vector3, back: Vector3)
	local u = out.Unit
	local w = (back - u * back:Dot(u)).Unit
	local n = w:Cross(u)
	return function(a: number, c: number, lift: number?): Vector3
		return root + u * a + w * c + n * (lift or 0)
	end, n
end

--[[
	Feathered bird wing (right side, inside a Wing bone) in the plane P (see wingPlane). spec:
	  Edge  = leading edge points {a, c, lift} (a bony arm runs along it), Roots = feather roots (same count),
	  Tips  = one feather per root (the last one from the last root to the wing tip): a sawtooth trailing edge.
	  Arm / Cover / Feather (a colour or a list cycling per feather) colours, Opts (default THIN).
	  Tip = colour drawn again over the outer TipAt of every feather (TipOpts: e.g. neon flames).
	  Tongue = { colour, length, opts }: a flat flame licking out of every feather tip.
	  Span scales every point along the wing (default 1).
]]
local function birdWing(b, P, normal: Vector3, spec)
	local span = spec.Span or 1
	local function at(p): Vector3
		return P(p[1] * span, p[2], p[3] or 0)
	end
	local options = spec.Opts or THIN
	local edge, roots, tips = spec.Edge, spec.Roots, spec.Tips
	local wrist = math.max(2, #edge - 1)
	prong(b, "WingArm", at(edge[1]) - normal * 0.02, at(edge[wrist]), 0.24, 0.22, at(roots[wrist]) - at(edge[wrist]), spec.Arm)
	prong(b, "WingHand", at(edge[wrist]), at(edge[#edge]), 0.18, 0.16, at(roots[#roots]) - at(edge[#edge]), spec.Arm)
	for i = 1, #edge - 1 do
		b:Tri("Covert" .. i .. "A", at(edge[i]), at(edge[i + 1]), at(roots[i]), spec.Cover, options)
		b:Tri("Covert" .. i .. "B", at(edge[i + 1]), at(roots[i + 1]), at(roots[i]), spec.Cover, options)
	end
	local lift = normal * 0.05
	for i, tip in tips do
		local r1 = at(roots[i])
		local r2 = if roots[i + 1] then at(roots[i + 1]) else at(edge[#edge])
		local t = at(tip)
		local color = if type(spec.Feather) == "table" then spec.Feather[(i - 1) % #spec.Feather + 1] else spec.Feather
		b:Tri("Feather" .. i, r1, r2, t, color, options)
		if spec.Tip then
			local k = 1 - (spec.TipAt or 0.4)
			b:Tri("FeatherTip" .. i, r1:Lerp(t, k) - lift, r2:Lerp(t, k) - lift, t - lift * 0.5, spec.Tip, spec.TipOpts or options)
		end
		if spec.Tongue then
			local out = (t - (r1 + r2) / 2).Unit
			local base = t - out * 0.3 - lift * 0.8
			b:Blade("Tongue" .. i, base, t + out * spec.Tongue[2] - lift * 0.8, 0.2, spec.Tongue[1], spec.Tongue[3], normal)
		end
	end
end

-- Legendary birds -----------------------------------------------------------------------------
-- One body plan for the trio: egg-shaped body leaning back, neck + head bone, wings raised in a V, dangling legs.

local FROST_EYE = Color3.fromRGB(215, 40, 60)
local FROST_BEAK = Color3.fromRGB(150, 165, 190)
local FROST_LEG = Color3.fromRGB(120, 140, 175)
local WING_ROOT = V(0.36, 2.28, 0.1)

-- Body; paint(normal) -> colour of a facet (nil = Body).
local function birdBody(b, paint: any?)
	local body = sculpt(b, "Body", V(1.3, 1.45, 2.0), V(0, 1.75, 0.2), V(34, 0, 0), "Body", { Paint = paint })
	b:SetCore(body)
	return body
end

-- Belly painter: facets facing `dir` (within the threshold cosine) get `color`.
local function bellyPaint(dir: Vector3, threshold: number, color: any)
	local unit = dir.Unit
	return function(normal: Vector3): any
		return if normal:Dot(unit) > threshold then color else nil
	end
end

-- Dangling legs: feathered thigh, thin shank and three talons. extra(): more parts in the leg bone.
local function birdLegs(b, thighColor: any, legColor: any, extra: (() -> ())?)
	b:MirrorBone("Leg", V(0.32, 1.2, 0.35), nil, function()
		prong(b, "Thigh", V(0.26, 1.42, 0.3), V(0.36, 0.78, 0.36), 0.46, 0.34, BACK, thighColor)
		prong(b, "Shank", V(0.33, 0.98, 0.33), V(0.38, 0.28, 0.14), 0.16, 0.13, BACK, legColor)
		for index, dx in { -0.13, 0, 0.13 } do
			feather(b, "Talon" .. index, V(0.38 + dx * 0.3, 0.32, 0.14), V(0.38 + dx * 1.5, 0.1, -0.22), 0.1, V(0, 0.6, -0.4), legColor)
		end
		if extra then
			extra()
		end
	end)
end

--[[
	Head bone: neck (belly-coloured front), head, beak and eyes. spec: Neck (facet painter), Beak (colour),
	BeakLength, BeakDrop, Eye (iris colour), Crest(head) adds the signature crest inside the head bone.
]]
local function birdHead(b, spec)
	local head
	b:Bone("Head", V(0, 2.3, -0.3), nil, function()
		local neck = tubeRings({ V(0, 2.0, -0.15), V(0, 2.62, -0.5), V(0, 3.0, -0.66) }, { 0.42, 0.34, 0.3 }, 4, FRONT)
		tubePart(b, "Neck", neck, 1, 3, spec.Neck or function(): any
			return "Body"
		end)
		head = sculpt(b, "Head", V(0.86, 0.8, 1.0), V(0, 3.2, -0.74), nil, "Body", { Detail = 1 })
		local length = spec.BeakLength or 0.44
		prong(b, "Beak", V(0, 3.12, -1.08), V(0, 3.12 - (spec.BeakDrop or 0.16), -1.08 - length), 0.28, 0.2, DOWN, spec.Beak)
		b:Eyes(head, 0.25, 0.02, V(0.24, 0.27, 0.18), spec.Eye, "Angry")
		if spec.Crest then
			spec.Crest(head)
		end
	end)
	return head
end

-- Icy bird: slim blue body with a pale chest, three tall crest plumes, red eyes, long pale-tipped wings
-- raised in a V and a very long twisting tail of three streamers (Articuno-like).
Designs["Frostwing"] = function(b)
	b.Hover = 1.5
	local body = birdBody(b, bellyPaint(V(0, -0.15, -1), 0.45, "Belly"))
	birdLegs(b, "Body", FROST_LEG)
	birdHead(b, {
		Neck = facing(V(0, -0.2, -1), 0.5, "Belly", "Body"),
		Beak = FROST_BEAK,
		Eye = FROST_EYE,
		Crest = function()
			-- Three tall plumes rising from the forehead, the middle one tallest.
			prong(b, "Crest1", V(0, 3.38, -0.95), V(0, 4.45, -1.12), 0.22, 0.2, BACK, "Body")
			prong(b, "Crest2", V(0.1, 3.42, -0.85), V(0.3, 4.22, -0.92), 0.2, 0.18, BACK, "Body")
			prong(b, "Crest3", V(-0.1, 3.42, -0.85), V(-0.3, 4.22, -0.92), 0.2, 0.18, BACK, "Body")
		end,
	})

	-- Wings raised in a V, spread in front of the body so their faces show, feathers hanging down and out.
	b:MirrorBone("Wing", V(0.42, 2.3, 0.05), nil, function()
		local P, n = wingPlane(WING_ROOT, V(0.66, 0.74, 0.12), V(0.74, -0.66, 0.5))
		birdWing(b, P, n, {
			Edge = { { 0, -0.1, 0.06 }, { 1.0, -0.24, 0.1 }, { 1.95, -0.06, 0.08 }, { 2.6, 0.28, 0.03 } },
			Roots = { { 0.1, 0.45 }, { 0.95, 0.52 }, { 1.8, 0.5 }, { 2.35, 0.55 } },
			Tips = { { 0.4, 1.25, -0.08 }, { 1.2, 1.4, -0.12 }, { 1.95, 1.25, -0.1 }, { 2.75, 0.78, -0.06 } },
			Arm = "Body",
			Cover = "Body",
			Feather = "Body",
			Tip = "Accent",
			TipAt = 0.42,
			Span = 0.92,
		})
	end)

	-- Long tail: three twisting streamers flowing back and down in a wave (they sway with the tail bone).
	b:Bone("Tail", V(0, 1.2, 0.9), nil, function()
		local function streamer(name: string, x: number, length: number, twist: number)
			local points = {
				V(x * 0.3, 1.3, 0.72),
				V(x * 0.7, 0.88, 1.3),
				V(x, 0.5, 1.2 + 0.65 * length),
				V(x * 1.2, 0.62, 1.2 + 1.15 * length),
				V(x * 1.4, 1.2, 1.2 + 1.45 * length),
			}
			local across = {}
			for i = 1, #points do
				local a = math.rad(twist * (i - 1))
				across[i] = V(math.cos(a), math.sin(a), 0)
			end
			ribbon(b, name, points, { 0.1, 0.17, 0.18, 0.13, 0 }, across, { "Body", "Body", "Accent", "Accent" })
		end
		streamer("TailMid", 0, 1, 28)
		streamer("TailR", 0.34, 0.8, -32)
		streamer("TailL", -0.34, 0.8, 32)
	end)

	b:Particles(body, Color3.fromRGB(220, 240, 255), 8, 0.35)
end

-- Thunder bird: spiky yellow plumage everywhere (jagged crest, saw-toothed wings with spikes on the leading
-- edge, a fan of spiky tail feathers, spiky thighs), black lower body, long pointed orange beak and legs.
Designs["Voltwing"] = function(b)
	b.Hover = 1.5
	local body = birdBody(b, bellyPaint(V(0, -1, 0.2), 0.5, "Accent"))
	birdLegs(b, "Accent", "Extra", function()
		prong(b, "ThighSpike", V(0.42, 1.25, 0.3), V(0.85, 1.05, 0.55), 0.22, 0.16, DOWN, "Body")
	end)
	birdHead(b, {
		Beak = "Extra",
		BeakLength = 0.62,
		BeakDrop = 0.1,
		Eye = "Black",
		Crest = function()
			-- Jagged crown of spikes radiating backwards from the forehead.
			prong(b, "Crest1", V(0, 3.42, -0.92), V(0, 4.3, -0.72), 0.24, 0.2, BACK, "Body")
			prong(b, "Crest2", V(0, 3.5, -0.7), V(0, 4.15, 0.05), 0.24, 0.2, DOWN, "Body")
			for _, x in { -1, 1 } do
				prong(b, "Crest3", V(x * 0.14, 3.42, -0.72), V(x * 0.55, 3.98, -0.05), 0.22, 0.18, DOWN, "Body")
				prong(b, "Crest4", V(x * 0.28, 3.25, -0.62), V(x * 0.85, 3.32, 0.02), 0.2, 0.16, DOWN, "Body")
			end
		end,
	})

	b:MirrorBone("Wing", V(0.42, 2.3, 0.05), nil, function()
		local P, n = wingPlane(WING_ROOT, V(0.74, 0.64, 0.12), V(0.64, -0.74, 0.5))
		birdWing(b, P, n, {
			Edge = { { 0, -0.1, 0.06 }, { 1.0, -0.2, 0.1 }, { 1.95, -0.04, 0.08 }, { 2.55, 0.3, 0.03 } },
			Roots = { { 0.1, 0.42 }, { 0.95, 0.45 }, { 1.75, 0.45 }, { 2.25, 0.5 } },
			Tips = { { 0.25, 1.55, -0.08 }, { 1.05, 1.75, -0.12 }, { 1.9, 1.6, -0.1 }, { 2.95, 1.05, -0.06 } },
			Arm = "Body",
			Cover = "Body",
			Feather = "Body",
			Span = 0.88,
		})
		-- Saw-toothed leading edge: flat jags leaning out along the wing.
		for index, a in { 0.55, 1.2, 1.8 } do
			b:Tri("EdgeJag" .. index, P(a - 0.3, -0.05, 0.03), P(a + 0.3, -0.12, 0.03), P(a + 0.42, -0.62, 0.03), "Body", THIN)
		end
	end)

	-- Fan of spiky tail feathers pointing back.
	b:Bone("Tail", V(0, 1.2, 0.9), nil, function()
		vane(b, "Tail1", V(0, 1.32, 0.78), V(0, 1.2, 2.45), 0.5, UP, 0.12, "Body")
		for _, x in { -1, 1 } do
			vane(b, "Tail2", V(x * 0.1, 1.32, 0.78), V(x * 0.62, 1.12, 2.28), 0.46, V(x * 0.3, 1, 0), 0.1, "Body")
			vane(b, "Tail3", V(x * 0.15, 1.36, 0.76), V(x * 1.02, 1.36, 1.9), 0.42, V(x * 0.5, 1, 0), 0.1, "Body")
		end
	end)

	b:Particles(body, Color3.fromRGB(255, 245, 140), 10, 0.3)
end

-- Fire bird: golden-orange body, a burning crest on the head, wings whose feathers end in flames and a long
-- tail of flames (Moltres-like).
Designs["Pyrowing"] = function(b)
	b.Hover = 1.5
	local flame = { Neon = true, Thickness = 0.06 }
	local body = birdBody(b, nil)
	birdLegs(b, "Body", "Extra")
	birdHead(b, {
		Beak = "Extra",
		BeakLength = 0.5,
		Eye = "Black",
		Crest = function()
			-- Burning crest sweeping back from the forehead: crossed flame triangles.
			for index, spec in { { 0, 4.45, 0.1, 0.62 }, { 0.22, 4.1, 0.35, 0.48 }, { -0.22, 4.1, 0.35, 0.48 } } do
				local base, tip = V(spec[1] * 0.4, 3.38, -0.82), V(spec[1], spec[2], spec[3])
				b:Blade("CrestFlame" .. index, base, tip, spec[4], "Accent", flame, SIDE)
				b:Blade("CrestCore" .. index, base + V(0, 0.05, 0), base:Lerp(tip, 0.65), spec[4] * 0.5, "FlameCore", flame, SIDE)
			end
		end,
	})

	b:MirrorBone("Wing", V(0.42, 2.3, 0.05), nil, function()
		local P, n = wingPlane(WING_ROOT, V(0.7, 0.7, 0.12), V(0.7, -0.7, 0.5))
		birdWing(b, P, n, {
			Edge = { { 0, -0.1, 0.06 }, { 1.0, -0.22, 0.1 }, { 1.95, -0.05, 0.08 }, { 2.6, 0.3, 0.03 } },
			Roots = { { 0.1, 0.45 }, { 0.95, 0.5 }, { 1.8, 0.5 }, { 2.35, 0.55 } },
			Tips = { { 0.35, 1.4, -0.08 }, { 1.15, 1.6, -0.12 }, { 1.95, 1.45, -0.1 }, { 2.9, 0.95, -0.06 } },
			Arm = "Body",
			Cover = "Body",
			Feather = "Body",
			Tip = "Accent",
			TipAt = 0.6,
			TipOpts = flame,
			Tongue = { "FlameCore", 0.35, flame },
			Span = 0.82,
		})
	end)

	-- Tail of flames streaming back, a real fire at its root.
	b:Bone("Tail", V(0, 1.2, 0.9), nil, function()
		for index, spec in { { 0, 1.0, 2.6, 0.7 }, { 0.5, 1.15, 2.3, 0.55 }, { -0.5, 1.15, 2.3, 0.55 } } do
			local base, tip = V(spec[1] * 0.2, 1.3, 0.8), V(spec[1], spec[2], spec[3])
			b:Blade("TailFlame" .. index, base, tip, spec[4], "Accent", flame, UP)
			b:Blade("TailCore" .. index, base, base:Lerp(tip, 0.6), spec[4] * 0.5, "FlameCore", flame, UP)
		end
		b:Flame("TailFire", V(0, 1.3, 1.25), 0.4)
	end)

	b:Particles(body, Color3.fromRGB(255, 170, 60), 10, 0.35)
end

-- Wish maker -----------------------------------------------------------------------------------

local STREAMER = Color3.fromRGB(240, 236, 170)

-- Small white wish maker: big round head crowned by a three-pointed golden star with blue wish tags at the
-- tips, big eyes with blue tear marks, a seam on the belly, stubby arms and feet and two long streamers
-- fluttering from its back (Jirachi-like).
Designs["Wishstar"] = function(b)
	b.Hover = 1.3
	local torso = sculpt(b, "Body", V(0.95, 1.05, 0.85), V(0, 0.95, 0.02), nil, "Body")
	b:SetCore(torso)
	-- The closed third eye: a thin seam across the belly.
	b:FaceDot("Seam", torso, 0, -0.1, V(0.36, 0.07, 0.06), "Dark")

	b:MirrorBone("Leg", V(0.22, 0.62, 0.02), nil, function()
		b:Limb("Leg", V(0.2, 0.8, 0.02), V(0.29, 0.1, -0.06), 0.38, "Body", { RingAt = 0.55, Thickness = 0.06 })
		prong(b, "Toe", V(0.29, 0.2, 0.02), V(0.32, 0.02, -0.36), 0.32, 0.16, UP, "Body")
	end)
	b:MirrorBone("Arm", V(0.38, 1.22, -0.02), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.28, 1.27, 0), V(0.79, 1.48, -0.22), 0.3, "Body", { RingAt = 0.55, Thickness = 0.06 })
		-- Stubby three-fingered hand.
		b:Ball("Hand", V(0.34, 0.34, 0.3), V(0.84, 1.5, -0.24), nil, "Body", { Detail = 0, Thickness = 0.04 })
	end)

	-- Streamers flowing down from the back, twisting as they fall.
	b:MirrorBone("Wing", V(0.15, 1.3, 0.32), nil, function()
		local points = { V(0.1, 1.38, 0.24), V(0.38, 1.0, 0.68), V(0.62, 0.45, 0.86), V(0.72, -0.05, 0.76), V(0.6, -0.42, 0.55) }
		local across = {}
		for i = 1, #points do
			local a = math.rad(-25 + 22 * i)
			across[i] = V(math.cos(a), 0.15, math.sin(a))
		end
		ribbon(b, "Streamer", points, { 0.1, 0.2, 0.22, 0.16, 0 }, across, { STREAMER })
	end)

	b:Bone("Head", V(0, 1.35, 0), nil, function()
		local center = V(0, 1.9, -0.04)
		local head = sculpt(b, "Head", V(1.55, 1.25, 1.2), center, nil, "Body")
		b:Eyes(head, 0.3, -0.02, V(0.34, 0.42, 0.26), "Black", "Cute")
		b:Mouth(head, -0.36, 0.24, true)
		-- Blue tear marks under the eyes.
		for _, x in { -1, 1 } do
			b:FaceDot("Tear" .. x, head, x * 0.36, -0.27, V(0.12, 0.26, 0.08), "Extra")
		end
		-- Three-pointed star crown, a creased wish tag hanging from every point.
		for index, angle in { 0, 58, -58 } do
			local a = math.rad(angle)
			local dir = V(math.sin(a), math.cos(a), 0)
			local base, tip = center + dir * 0.4, center + dir * (if angle == 0 then 1.42 else 1.32)
			pyramid(b, "StarPoint" .. index, base, tip, 0.9, 0.5, FRONT, "Accent")
			local top = tip - dir * 0.06 + V(0, 0, -0.03)
			vane(b, "Tag" .. index, top, top + V(0, -0.56, 0), 0.34, FRONT, 0.05, "Extra")
		end
	end)

	b:Particles(torso, Color3.fromRGB(255, 240, 150), 6, 0.25)
end

-- Sky serpent ------------------------------------------------------------------------------------

local SERPENT_EYE = Color3.fromRGB(255, 215, 60)
local SERPENT_MOUTH = Color3.fromRGB(215, 45, 55)

-- Emerald sky dragon coiled in the air: a long serpent body (a chain of tail bones that waves) with yellow
-- markings, a long head with two pairs of swept-back horns, a snapping jaw, small clawed arms, pairs of fins
-- along the body and a three-pointed tail fin (Rayquaza-like).
Designs["Skyserpent"] = function(b)
	b.Hover = 1.0
	local points = {
		V(0, 3.32, -0.6),
		V(0, 2.72, -0.38),
		V(0.25, 2.14, -0.05),
		V(0.9, 1.74, 0.32),
		V(1.1, 1.3, 1.0),
		V(0.5, 1.0, 1.45),
		V(-0.4, 0.82, 1.35),
		V(-1.05, 0.65, 0.65),
		V(-0.95, 0.52, -0.2),
		V(-0.2, 0.55, -0.62),
		V(0.6, 0.85, -0.6),
	}
	local radii = { 0.3, 0.34, 0.37, 0.37, 0.35, 0.33, 0.3, 0.26, 0.21, 0.15, 0.08 }
	local body = tubeRings(points, radii, 4, UP)
	-- Yellow markings: the upper facets of every other segment.
	local function paint(normal: Vector3, segment: number): any
		return if segment % 2 == 0 and normal.Y > 0.3 then "Accent" else "Body"
	end
	-- A pair of fins on both sides of ring i, swept back along the body.
	local function finPair(name: string, i: number, length: number)
		local c, r = points[i], radii[i]
		local t = (points[i + 1] - points[i - 1]).Unit
		local side = t:Cross(UP).Unit
		for _, s in { -1, 1 } do
			local at = c + side * (s * r * 0.7) + UP * (r * 0.25)
			local out = (side * (s * 0.75) + UP * 0.4 + t * 0.55).Unit
			b:Bone(name, at, { Role = "Fin", Phase = if s > 0 then 0 else 0.5 }, function()
				vane(b, "Fin", at, at + out * length, 0.42, UP, 0.08, "Body")
				vane(b, "FinTip", at + out * (length * 0.55), at + out * (length * 1.08), 0.24, UP, 0.05, "Accent")
			end)
		end
	end

	local chest = tubePart(b, "Body", body, 1, 4, paint)
	b:SetCore(chest)
	b:MirrorBone("Arm", V(0.42, 2.2, -0.12), { Phase = 0.5 }, function()
		prong(b, "Arm", V(0.36, 2.24, -0.08), V(0.72, 1.92, -0.55), 0.2, 0.16, DOWN, "Body")
		for index, dx in { -0.08, 0.04, 0.14 } do
			feather(b, "Claw" .. index, V(0.7 + dx * 0.4, 1.95, -0.52), V(0.72 + dx, 1.86, -0.72), 0.07, UP, "Body")
		end
	end)
	finPair("FinFront", 4, 0.95)

	b:Bone("Tail", points[4], { Amp = 0.35 }, function()
		tubePart(b, "Tail", body, 4, 7, paint, 0.12)
		b:Bone("Tail2", points[7], { Role = "Tail", Amp = 0.35, Phase = 0.2 }, function()
			tubePart(b, "Tail", body, 7, 9, paint, 0.1)
			finPair("FinMid", 7, 0.7)
			b:Bone("Tail3", points[9], { Role = "Tail", Amp = 0.4, Phase = 0.4 }, function()
				tubePart(b, "Tail", body, 9, 11, paint, 0.08)
				-- Three-pointed tail fin.
				local tip = points[11]
				vane(b, "TailFin1", tip - V(0.1, 0.15, 0), tip + V(0.35, 0.75, -0.05), 0.34, FRONT, 0.06, "Body")
				vane(b, "TailFin2", tip - V(0.1, 0.1, 0), tip + V(0.65, 0.2, 0.1), 0.3, FRONT, 0.05, "Accent")
				vane(b, "TailFin3", tip - V(0.1, 0.1, 0), tip + V(-0.15, 0.6, 0.15), 0.26, FRONT, 0.05, "Accent")
			end)
		end)
	end)

	b:Bone("Head", points[1], nil, function()
		local head = sculpt(b, "Head", V(0.82, 0.7, 1.4), V(0, 3.5, -0.92), nil, "Body", { Deform = snout(0.28, 0.85, 0.04, 0.12) })
		b:Eyes(head, 0.25, 0.12, V(0.2, 0.17, 0.14), SERPENT_EYE, "Angry")
		-- Long horns sweeping back from the top of the head, shorter fins behind the jaw.
		for _, x in { -1, 1 } do
			prong(b, "Horn", V(x * 0.18, 3.74, -0.72), V(x * 0.5, 4.05, 0.45), 0.24, 0.16, DOWN, "Body")
			prong(b, "HornTip", V(x * 0.4, 3.97, 0.12), V(x * 0.52, 4.07, 0.5), 0.12, 0.08, DOWN, "Accent")
			prong(b, "Cheek", V(x * 0.3, 3.38, -0.82), V(x * 0.78, 3.26, -0.2), 0.22, 0.14, DOWN, "Body")
		end
		b:Bone("Jaw", V(0, 3.3, -0.62), nil, function()
			prong(b, "Jaw", V(0, 3.3, -0.55), V(0, 3.2, -1.6), 0.5, 0.18, DOWN, "Body")
			b:Tri("Tongue", V(-0.12, 3.29, -0.9), V(0.12, 3.29, -0.9), V(0, 3.27, -1.4), SERPENT_MOUTH, THIN)
		end)
	end)

	b:Particles(chest, Color3.fromRGB(120, 255, 160), 6, 0.35)
end

-- Guardian of the deep -------------------------------------------------------------------------------

local ABYSS_EYE = Color3.fromRGB(110, 175, 255)

-- Silver sea guardian: big rounded body with a pale blue belly, a long neck, a sleek head with dark blue eye
-- masks, blue plates down the back, hand-like wings with five finger feathers, short legs and a long tail
-- ending in two blue fins (Lugia-like).
Designs["Abysswing"] = function(b)
	b.Hover = 1.5
	local body = sculpt(b, "Body", V(1.4, 1.75, 1.7), V(0, 1.85, 0.2), V(16, 0, 0), "Body", {
		Paint = bellyPaint(V(0, -0.35, -1), 0.4, "Belly"),
	})
	b:SetCore(body)
	-- Blue plates down the back.
	for index, spec in { { 2.72, 0.42, 0.42 }, { 2.32, 0.88, 0.5 }, { 1.82, 1.12, 0.42 }, { 1.32, 1.12, 0.32 } } do
		local base = V(0, spec[1], spec[2])
		prong(b, "Plate" .. index, base, base + V(0, 0.18, 0.12) + V(0, 0.4, 0.35) * spec[3] * 2, 0.34, 0.3, V(0, -0.4, -1), "Accent")
	end

	-- Short legs with three toes, dangling under the body.
	b:MirrorBone("Leg", V(0.4, 1.25, 0.3), nil, function()
		prong(b, "Thigh", V(0.34, 1.45, 0.3), V(0.48, 0.7, 0.2), 0.48, 0.36, BACK, "Body")
		for index, dx in { -0.12, 0, 0.12 } do
			feather(b, "Toe" .. index, V(0.48 + dx * 0.3, 0.82, 0.18), V(0.48 + dx * 1.4, 0.6, -0.12), 0.12, V(0, 0.6, -0.4), "Belly")
		end
	end)

	-- Hand-like wings: a strong arm, a broad palm and five finger feathers spread at the tip.
	b:MirrorBone("Wing", V(0.52, 2.5, 0.15), nil, function()
		local S, E, W = V(0.5, 2.5, 0.15), V(1.12, 3.05, 0.24), V(1.62, 3.2, 0.3)
		local T1, T2 = V(0.62, 1.9, 0.22), V(1.3, 2.3, 0.3)
		prong(b, "WingArm", S, E, 0.32, 0.26, V(0.3, -1, 0.3), "Body")
		prong(b, "WingHand", E - V(0.05, 0, 0), W, 0.26, 0.22, V(0, -1, 0.3), "Body")
		b:Tri("Palm1", S, E, T1, "Body", THIN)
		b:Tri("Palm2", E, T2, T1, "Belly", THIN)
		b:Tri("Palm3", E, W, T2, "Body", THIN)
		-- Five broad, blunt finger feathers fanning out from the wrist like a hand.
		for index = 1, 5 do
			local a = math.rad(58 - (index - 1) * 27)
			local root = W:Lerp(T2, (index - 1) / 4) + V(-0.06, 0, 0)
			local dir = V(math.cos(a), math.sin(a), 0)
			local across = V(-dir.Y, dir.X, 0)
			local tip = root + dir * (if index == 5 then 0.62 else 0.8)
			local color = if index == 5 then "Belly" else "Body"
			b:Tri("Finger" .. index .. "A", root - across * 0.2, root + across * 0.2, tip + across * 0.12 + BACK * 0.05, color, THIN)
			b:Tri("Finger" .. index .. "B", root - across * 0.2, tip + across * 0.12 + BACK * 0.05, tip - across * 0.1, color, THIN)
		end
	end)

	-- Long tail sweeping back and down, ending in two blue fins.
	local tail = tubeRings({ V(0, 1.55, 0.75), V(0, 1.05, 1.3), V(0, 0.82, 1.8), V(0, 0.9, 2.2) }, { 0.42, 0.3, 0.2, 0.1 }, 3, UP)
	b:Bone("Tail", V(0, 1.4, 0.9), nil, function()
		tubePart(b, "Tail", tail, 1, 3, function()
			return "Body"
		end)
		b:Bone("Tail2", V(0, 0.82, 1.8), { Role = "Tail", Phase = 0.2 }, function()
			tubePart(b, "Tail", tail, 3, 4, function()
				return "Body"
			end, 0.1)
			for _, x in { -1, 1 } do
				vane(b, "TailFin", V(0, 0.88, 2.02), V(x * 0.62, 1.0, 2.55), 0.38, UP, 0.06, "Accent")
			end
		end)
	end)

	b:Bone("Head", V(0, 2.55, -0.25), nil, function()
		local neck = tubeRings({ V(0, 2.3, -0.1), V(0, 2.95, -0.42), V(0, 3.5, -0.62) }, { 0.42, 0.3, 0.26 }, 4, FRONT)
		tubePart(b, "Neck", neck, 1, 3, facing(V(0, -0.2, -1), 0.5, "Belly", "Body"))
		local center = V(0, 3.68, -0.8)
		local head = sculpt(b, "Head", V(0.8, 0.68, 1.2), center, nil, "Body", {
			Detail = 2,
			Deform = function(v: Vector3): Vector3
				-- Pointed snout in front, the back of the head drawn out into a point.
				if v.Z > 0.85 then
					return V(v.X, v.Y + 0.1, v.Z + 0.45)
				elseif v.Z < -0.5 and v.Y < 0.1 then
					return V(v.X * 0.8, v.Y, v.Z - 0.25)
				end
				return v
			end,
			-- Dark blue mask around the eyes, running back along the sides of the head.
			Paint = function(normal: Vector3, offset: Vector3): any
				return if math.abs(offset.X) > 0.12 and offset.Y > -0.02 and offset.Y < 0.16 and offset.Z < 0.5 then "Accent" else nil
			end,
		})
		b:Eyes(head, 0.25, 0.1, V(0.17, 0.2, 0.1), ABYSS_EYE, "Cute")
	end)

	b:Particles(body, Color3.fromRGB(140, 200, 255), 6, 0.4)
end

-- Glitch -------------------------------------------------------------------------------------------

local GLITCH_GLOW = Color3.fromRGB(60, 255, 200)
local GLITCH_HOT = Color3.fromRGB(255, 80, 200)

-- Repeatable noise in [0, 1) from a position (glitch colours and jitter).
local function noise(x: number, y: number, k: number?): number
	local v = math.sin(x * 12.9898 + y * 78.233 + (k or 0) * 37.719) * 43758.5453
	return v - math.floor(v)
end

-- Mesh options of a glitch colour: the bright ones glow.
local function glitchOpts(color: any): any
	return if color == GLITCH_GLOW or color == GLITCH_HOT then { Neon = true, Thickness = 0.06 } else THIN
end

--[[
	Pixel slab: a block of nx * ny pixels starting at `corner` (its +X bottom front corner, columns run towards -X).
	The front is a grid of triangles (every pixel split along a diagonal, every vertex pushed in or out a little so
	no two triangles share a plane) painted pixel by pixel with colorOf(column, row, half); the back closes on a
	faceted point. Vertices depend only on their position, so two slabs sharing an edge meet seamlessly.
]]
local function slab(b, name: string, corner: Vector3, nx: number, ny: number, cell: number, depth: number, colorOf)
	local vertices, index = {}, {}
	for i = 0, nx do
		index[i] = {}
		for j = 0, ny do
			local x, y = corner.X - i * cell, corner.Y + j * cell
			table.insert(vertices, V(x, y, corner.Z - depth + (noise(x, y) - 0.5) * 0.18))
			index[i][j] = #vertices
		end
	end
	local center = V(corner.X - nx * cell / 2, corner.Y + ny * cell / 2, corner.Z)
	table.insert(vertices, center + V(0, 0, depth * 1.6))
	local apex = #vertices
	local faces, colors = {}, {}
	for i = 1, nx do
		for j = 1, ny do
			local a, c, d, e = index[i - 1][j - 1], index[i][j - 1], index[i - 1][j], index[i][j]
			local halves = if (i + j) % 2 == 0 then { { a, c, e }, { a, e, d } } else { { a, c, d }, { c, e, d } }
			for h, face in halves do
				table.insert(faces, face)
				colors[#faces] = colorOf(i, j, h)
			end
		end
	end
	local loop = {}
	for i = 0, nx - 1 do
		table.insert(loop, index[i][0])
	end
	for j = 0, ny - 1 do
		table.insert(loop, index[nx][j])
	end
	for i = nx, 1, -1 do
		table.insert(loop, index[i][ny])
	end
	for j = ny, 1, -1 do
		table.insert(loop, index[0][j])
	end
	for k = 1, #loop do
		table.insert(faces, { loop[k], loop[k % #loop + 1], apex })
		colors[#faces] = colorOf(k, 0, 3)
	end
	return paintedMesh(b, name, vertices, faces, function(face: number): any
		return colors[face] or "Body"
	end, center, V(nx * cell, ny * cell, depth * 2), glitchOpts)
end

--[[
	Glitch pixel: a tetrahedron whose front view is a square (two triangles folded along a diagonal, the back
	edge crossing the other way): a closed "pixel" made of 4 triangles (~8 parts). colors: front halves, back.
]]
local function pixel(b, name: string, center: Vector3, half: number, depth: number, colors: { any }, flip: boolean)
	local sx = if flip then -1 else 1
	local vertices = {
		center + V(sx * half, half, depth),
		center + V(sx * half, -half, -depth),
		center + V(-sx * half, half, -depth),
		center + V(-sx * half, -half, depth),
	}
	local faces = { { 1, 2, 3 }, { 2, 3, 4 }, { 1, 2, 4 }, { 1, 3, 4 } }
	return paintedMesh(b, name, vertices, faces, function(face: number): any
		return colors[math.min(face, 3)]
	end, center, V(half * 2, half * 2, depth * 2), glitchOpts)
end

-- Broken data creature: a backwards-L block of scrambled pixels (a mosaic of jittered triangles in random
-- glitch colours, some glowing), pixels torn out of its sides, stray pixels floating around it, scanline
-- slivers and wide dazed eyes (MissingNo-like).
Designs["Glitchno"] = function(b)
	b.Hover = 1.0
	local cell = 0.46
	local picks = { "Body", "Body", "Belly", "Body", "Accent", "Belly", "Extra", "Body", GLITCH_GLOW, "Belly", GLITCH_HOT }
	local backs = { "Body", "Body", "Body", "Accent", "Body", "Extra", "Body", GLITCH_HOT }
	-- Front pixels in random glitch colours; the back facets (h = 3) mostly Body with a few stray colours.
	local function colorOf(offset: number)
		return function(i: number, j: number, h: number): any
			local list = if h == 3 then backs else picks
			return list[math.floor(noise(i + offset, j, h) * #list) + 1]
		end
	end
	-- Tall column on the left side (the viewer's right), a lower block beside it: a backwards L.
	local column = slab(b, "Column", V(0, 0.25, 0), 2, 8, cell, 0.3, colorOf(0))
	b:SetCore(column)
	slab(b, "Foot", V(2 * cell, 0.25, 0), 2, 4, cell, 0.3, colorOf(5))
	-- Two rows of pixels slipped sideways out of the block, like a corrupted picture (they jitter up and down).
	b:Bone("FloatSlip1", V(-0.8, 0.25 + 4.5 * cell, -0.3), { Amp = 0.3, Phase = 0.1 }, function()
		slab(b, "Slip1", V(-0.34, 0.25 + 4 * cell, -0.36), 2, 1, cell, 0.07, colorOf(11))
	end)
	b:Bone("FloatSlip2", V(1.0, 0.25 + 1.5 * cell, -0.3), { Amp = 0.3, Phase = 0.6 }, function()
		slab(b, "Slip2", V(2 * cell + 0.32, 0.25 + 1 * cell, -0.36), 2, 1, cell, 0.07, colorOf(17))
	end)

	-- Face near the top of the column: wide dazed eyes and a little open mouth.
	local face = { Part = nil, Center = V(-cell, 0.25 + 6.6 * cell, 0), Size = column.Size, Tris = column.Tris }
	b:Eyes(face, cell * 0.5, 0, V(0.3, 0.36, 0.22), "Black", "Dazed")
	b:Mouth(face, -cell * 0.9, 0.22, true)

	-- Pixels torn out of the sides (sunk in the block) and stray pixels floating around it.
	pixel(b, "Torn1", V(-2 * cell - 0.12, 0.25 + 5.5 * cell, -0.1), cell / 2, 0.22, { "Extra", "Accent", "Body" }, false)
	pixel(b, "Torn2", V(2 * cell + 0.1, 0.25 + 2.5 * cell, -0.12), cell / 2, 0.22, { "Belly", GLITCH_HOT, "Body" }, true)
	pixel(b, "Torn3", V(0.5 * cell + 0.08, 0.25 + 4.35 * cell, -0.08), cell / 2, 0.22, { "Accent", "Belly", "Body" }, false)
	for index, spec in
		{
			{ V(0.85, 3.3, 0.05), GLITCH_GLOW },
			{ V(-1.35, 2.3, -0.05), "Accent" },
			{ V(1.35, 2.75, 0.1), "Belly" },
			{ V(-1.3, 0.9, 0.1), GLITCH_HOT },
		}
	do
		b:Bone("Float" .. index, spec[1], { Phase = index * 0.23 }, function()
			pixel(b, "Stray" .. index, spec[1], cell * 0.32, 0.16, { spec[2], "Body", "Body" }, index % 2 == 0)
		end)
	end
	-- Scanline slivers sticking out of the sides.
	local glow = { Neon = true, Thickness = 0.05 }
	b:Tri("ScanA", V(0.6, 1.62, -0.25), V(1.55, 1.59, -0.25), V(0.6, 1.53, -0.25), GLITCH_GLOW, glow)
	b:Tri("ScanB", V(-0.6, 3.0, -0.25), V(-1.7, 2.97, -0.25), V(-0.6, 2.92, -0.25), GLITCH_HOT, glow)

	b:Particles(column, Color3.fromRGB(0, 255, 160), 12, 0.35)
end

-- Creator ------------------------------------------------------------------------------------------

local CREATOR_EYE = Color3.fromRGB(60, 200, 110)
local CREATOR_GEM = Color3.fromRGB(80, 230, 140)

-- The creator: white celestial horse with a grey face and belly, a tall swept-back crest, a pointed collar,
-- a spiky mane down the back, thin legs on golden pointed hooves and a golden cross-wheel with four jewels
-- spinning around its waist (Arceus-like).
Designs["Primordeus"] = function(b)
	local body = sculpt(b, "Body", V(1.3, 1.25, 2.2), V(0, 1.88, 0.2), V(-4, 0, 0), "Body", {
		Paint = function(normal: Vector3): any
			return if normal.Y < -0.45 then "Extra" else nil
		end,
	})
	b:SetCore(body)

	for index, z in { -0.48, 0.9 } do
		b:MirrorBone(if index == 1 then "LegFront" else "LegBack", V(0.4, 1.6, z), { Phase = if index == 1 then 0 else 0.5 }, function()
			prong(b, "Thigh", V(0.38, 1.9, z), V(0.43, 0.85, z + 0.06), 0.5, 0.38, if index == 1 then BACK else FRONT, "Body")
			prong(b, "Shin", V(0.43, 1.05, z + 0.03), V(0.43, 0.3, z), 0.26, 0.2, BACK, "Extra")
			-- Golden pointed hoof.
			b:Cone("Hoof", V(0.43, 0.42, z), V(0.43, 0.0, z - 0.04), 0.21, "Accent", { Sides = 3 })
		end)
	end

	-- Spiky white mane down the back and a tail ending in a point.
	for index, spec in
		{ { V(0, 2.42, -0.15), V(0, 3.05, 0.42) }, { V(0, 2.42, 0.42), V(0, 2.92, 1.02) }, { V(0, 2.26, 0.9), V(0, 2.58, 1.5) } }
	do
		prong(b, "Mane" .. index, spec[1], spec[2], 0.46, 0.32, V(0, -1, -0.4), "Body")
	end
	b:Bone("Tail", V(0, 1.95, 1.2), nil, function()
		prong(b, "Tail", V(0, 2.0, 1.12), V(0, 1.5, 2.25), 0.44, 0.32, UP, "Body")
	end)

	b:Bone("Head", V(0, 2.45, -0.65), nil, function()
		local neck = tubeRings({ V(0, 2.1, -0.5), V(0, 2.8, -0.85), V(0, 3.3, -1.0) }, { 0.48, 0.38, 0.32 }, 4, FRONT)
		tubePart(b, "Neck", neck, 1, 3, function()
			return "Body"
		end)
		-- Pointed white collar under the throat.
		for index, x in { -1, 1 } do
			prong(b, "Collar" .. index, V(x * 0.12, 2.82, -1.02), V(x * 0.36, 2.12, -1.22), 0.42, 0.3, BACK, "Body")
		end
		local head = sculpt(b, "Head", V(0.72, 0.68, 1.08), V(0, 3.42, -1.18), nil, "Extra", { Detail = 1, Deform = snout(0.22, 0.8) })
		b:Eyes(head, 0.2, 0.08, V(0.18, 0.2, 0.13), CREATOR_EYE, "Angry")
		-- Tall white crest sweeping back from the forehead, white frills behind the cheeks.
		pyramid(b, "Crest", V(0, 3.62, -1.12), V(0, 4.6, -0.12), 0.56, 0.4, UP, "Body")
		for _, x in { -1, 1 } do
			prong(b, "Frill", V(x * 0.24, 3.42, -0.98), V(x * 0.62, 3.62, -0.36), 0.32, 0.22, DOWN, "Body")
		end
	end)

	-- Golden cross-wheel around the waist with four jewels, spinning slowly.
	local center = V(0, 1.98, 0.2)
	b:Bone("Spin", center, { Amp = 0.5 }, function()
		local ring, radii = {}, {}
		for index = 0, 8 do
			local a = index / 8 * TAU
			table.insert(ring, center + V(math.sin(a) * 1.42, 0, math.cos(a) * 1.42))
			table.insert(radii, 0.13)
		end
		local wheel = tubeRings(ring, radii, 3, UP)
		tubePart(b, "Wheel", wheel, 1, 9, function()
			return "Accent"
		end, nil, { Thickness = 0.06, Material = Enum.Material.Foil })
		for index = 1, 4 do
			local a = (index - 0.5) / 4 * TAU
			local out = V(math.sin(a), 0, math.cos(a))
			b:Cone(
				"Jewel" .. index,
				center + out * 1.32,
				center + out * 1.7,
				0.17,
				CREATOR_GEM,
				{ Sides = 3, Neon = true, Thickness = 0.05 }
			)
		end
	end)

	b:Particles(body, Color3.fromRGB(255, 230, 140), 10, 0.45)
end

return Designs
