--[[
	Critter designs: Frostwing, Voltwing, Pyrowing, Wishstar, Skyserpent, Abysswing, Glitchno, Primordeus.
	See CritterBuilder for the toolkit. Ground at y = 0, the critter faces -Z.
	Triangle style: every surface is faceted (sculpted low-poly balls, tubes, pyramids and flat triangles), only
	the eyes and the mouths are round, and every moving part lives in a bone (heads, wings, tails, legs, arms,
	floating shards, the golden ring). The flyers hover (b.Hover) with their wings in Wing bones.
	The legendary bird trio shares one body plan (body, neck, legs, wing and tail helpers) so they read as a set.
]]

local LowPoly = require(script.Parent.Parent.LowPoly)

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
	opts.Detail (default 2), or opts.Ring = n for a cheaper bipyramid (n ring vertices at height opts.RingY, 2n facets);
	opts.Deform(v, index) moves the unit vertices (|v| = 1, -Z = front) before scaling; opts.Paint(normal, offset)
	returns the colour of a facet (nil = `color`), in design space. Returns a handle for the face helpers.
]]
local function sculpt(b, name: string, size: Vector3, position: Vector3, rot: Vector3?, color: any, opts: any?)
	local options = opts or {}
	local unit, faces
	if options.Ring then
		local data = LowPoly.Bipyramid(options.Ring, options.RingY, options.Twist)
		unit, faces = data.Vertices, data.Faces
	else
		unit, faces = ballData(options.Detail or 2)
	end
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

-- Deform: lowers the top vertex of a ball by `top` (a rounder dome instead of a pointed cap).
local function domed(top: number, after: any?)
	return function(v: Vector3, index: number): Vector3
		local w = if v.Y > 0.99 then v * top else v
		return if after then after(w, index) else w
	end
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

-- Point on the front of a shape at the design height y (x = offset from its centre), lifted outwards.
local function onFront(b, shape, x: number, y: number, lift: number): Vector3
	return (b:OnSurface(shape, x, y - shape.Center.Y) * CFrame.new(0, 0, -lift)).Position
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
	Feathered bird wing (right side, inside a Wing bone) in the plane P (see wingPlane): a bony arm along the
	leading edge `edge` ({a, c, lift} points), the covert strip between it and the feather roots `roots` (same
	count), then one long feather per root reaching tips[i] (the last one from the last root to the wing tip): a
	sawtooth trailing edge. With `tipColor`, the outer `tipAt` of every feather is drawn again on its front side in
	that colour. featherColor may be a list (one colour per feather, cycling).
]]
local function birdWing(
	b,
	P,
	normal: Vector3,
	edge,
	roots,
	tips,
	armColor: any,
	coverColor: any,
	featherColor: any,
	tipColor: any?,
	tipAt: number?,
	opts: any?
)
	local function at(p): Vector3
		return P(p[1], p[2], p[3] or 0)
	end
	local options = opts or THIN
	local wrist = math.max(2, #edge - 1)
	prong(b, "WingArm", at(edge[1]) - normal * 0.02, at(edge[wrist]), 0.24, 0.22, at(roots[wrist]) - at(edge[wrist]), armColor)
	prong(b, "WingHand", at(edge[wrist]), at(edge[#edge]), 0.18, 0.16, at(roots[#roots]) - at(edge[#edge]), armColor)
	for i = 1, #edge - 1 do
		b:Tri("Covert" .. i .. "A", at(edge[i]), at(edge[i + 1]), at(roots[i]), coverColor, options)
		b:Tri("Covert" .. i .. "B", at(edge[i + 1]), at(roots[i + 1]), at(roots[i]), coverColor, options)
	end
	local lift = normal * 0.05
	for i, tip in tips do
		local r1 = at(roots[i])
		local r2 = if roots[i + 1] then at(roots[i + 1]) else at(edge[#edge])
		local t = at(tip)
		local color = if type(featherColor) == "table" then featherColor[(i - 1) % #featherColor + 1] else featherColor
		b:Tri("Feather" .. i, r1, r2, t, color, options)
		if tipColor then
			local k = 1 - (tipAt or 0.4)
			b:Tri("FeatherTip" .. i, r1:Lerp(t, k) - lift, r2:Lerp(t, k) - lift, t - lift * 0.5, tipColor, options)
		end
	end
end

-- Legendary birds -----------------------------------------------------------------------------

local FROST_EYE = Color3.fromRGB(215, 40, 60)
local FROST_BEAK = Color3.fromRGB(150, 165, 190)
local FROST_LEG = Color3.fromRGB(120, 140, 175)

-- Shared body of the trio: an egg-shaped body leaning back (chest forwards), painted belly facets.
local function birdBody(b, belly: any?)
	local body = sculpt(b, "Body", V(1.3, 1.45, 2.0), V(0, 1.75, 0.2), V(34, 0, 0), "Body", {
		Paint = if belly
			then function(normal: Vector3): any
				return if normal:Dot(V(0, -0.15, -1).Unit) > 0.45 then belly else nil
			end
			else nil,
	})
	b:SetCore(body)
	return body
end

-- Shared dangling legs: feathered thigh, thin shank and three talons.
local function birdLegs(b, thighColor: any, legColor: any)
	b:MirrorBone("Leg", V(0.32, 1.2, 0.35), nil, function()
		prong(b, "Thigh", V(0.26, 1.42, 0.3), V(0.36, 0.78, 0.36), 0.46, 0.34, BACK, thighColor)
		prong(b, "Shank", V(0.33, 0.98, 0.33), V(0.38, 0.28, 0.14), 0.16, 0.13, BACK, legColor)
		for index, dx in { -0.13, 0, 0.13 } do
			feather(b, "Talon" .. index, V(0.38 + dx * 0.3, 0.32, 0.14), V(0.38 + dx * 1.5, 0.1, -0.22), 0.1, V(0, 0.6, -0.4), legColor)
		end
	end)
end

-- Icy bird: slim blue body with a pale chest, three tall crest plumes, red eyes, long pale-tipped wings
-- raised in a V and a very long twisting tail of three streamers (Articuno-like).
Designs["Frostwing"] = function(b)
	b.Hover = 1.5
	local body = birdBody(b, "Belly")
	birdLegs(b, "Body", FROST_LEG)

	b:Bone("Head", V(0, 2.3, -0.3), nil, function()
		local neck = tubeRings({ V(0, 2.0, -0.15), V(0, 2.62, -0.5), V(0, 3.0, -0.66) }, { 0.42, 0.34, 0.3 }, 4, FRONT)
		tubePart(b, "Neck", neck, 1, 3, facing(V(0, -0.2, -1), 0.5, "Belly", "Body"))
		local head = sculpt(b, "Head", V(0.86, 0.8, 1.0), V(0, 3.2, -0.74), nil, "Body", { Detail = 1 })
		prong(b, "Beak", V(0, 3.12, -1.08), V(0, 2.96, -1.52), 0.28, 0.2, DOWN, FROST_BEAK)
		b:Eyes(head, 0.25, 0.02, V(0.24, 0.27, 0.18), FROST_EYE, "Angry")
		-- Three tall plumes rising from the forehead, the middle one tallest.
		prong(b, "Crest1", V(0, 3.38, -0.95), V(0, 4.45, -1.12), 0.22, 0.2, BACK, "Body")
		prong(b, "Crest2", V(0.1, 3.42, -0.85), V(0.3, 4.22, -0.92), 0.2, 0.18, BACK, "Body")
		prong(b, "Crest3", V(-0.1, 3.42, -0.85), V(-0.3, 4.22, -0.92), 0.2, 0.18, BACK, "Body")
	end)

	-- Wings raised in a V, spread in front of the body so their faces show, feathers hanging down and out.
	b:MirrorBone("Wing", V(0.42, 2.3, 0.05), nil, function()
		local P, n = wingPlane(V(0.36, 2.28, 0.1), V(0.66, 0.74, 0.12), V(0.74, -0.66, 0.5))
		birdWing(
			b,
			P,
			n,
			{ { 0, -0.1, 0.06 }, { 1.0, -0.24, 0.1 }, { 1.95, -0.06, 0.08 }, { 2.6, 0.28, 0.03 } },
			{ { 0.1, 0.45 }, { 0.95, 0.52 }, { 1.8, 0.5 }, { 2.35, 0.55 } },
			{ { 0.4, 1.25, -0.08 }, { 1.2, 1.4, -0.12 }, { 1.95, 1.25, -0.1 }, { 2.75, 0.78, -0.06 } },
			"Body",
			"Body",
			"Body",
			"Accent",
			0.42
		)
	end)

	-- Long tail: three twisting streamers flowing back and down in a wave (they sway with the tail bone).
	b:Bone("Tail", V(0, 1.2, 0.9), nil, function()
		local function streamer(name: string, x: number, length: number, twist: number)
			local points = {
				V(x * 0.3, 1.3, 0.72),
				V(x * 0.7, 0.85, 1.3),
				V(x, 0.42, 1.25 + 0.7 * length),
				V(x * 1.2, 0.36, 1.25 + 1.25 * length),
				V(x * 1.35, 0.62, 1.25 + 1.6 * length),
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

-- TODO: Voltwing

-- TODO: Pyrowing

-- TODO: Wishstar

return Designs
