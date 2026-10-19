--[[
	Critter designs: Drakelet, Serpendrake, Puffdrake, Pebbit, Bouldron, Emberfox, Novafox, Lagoonie.
	See CritterBuilder for the toolkit. Ground at y = 0, the critter faces -Z.
	Triangle style: every surface is faceted, only the eyes and the mouths are round, and every moving part
	lives in a bone (legs, arms, head, ears, tails, wings, flippers). Local helpers sculpt low-poly balls
	(snouts, lumpy rocks, pear bodies) and paint some of their facets (bellies, rock patches) without extra
	parts, draw serpent bodies that bend at several bones, and build pointed shapes out of right-angled
	triangles (one part each instead of two) so the budget goes into the silhouette.
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
-- Thin plates for small or pointed shapes (thick plates poke through the facets near the tips).
local THIN = { Thickness = 0.06 }
local CLAW = { Thickness = 0.05 }
-- Serpent / tube segments: thin plates so they do not poke out of the next segment where the body bends.
local SKIN = { Thickness = 0.08 }

local DRATINI_EYE = Color3.fromRGB(95, 45, 140)
local DRAGONAIR_EYE = Color3.fromRGB(70, 40, 120)
local FOX_EYE = Color3.fromRGB(120, 60, 25)
local NINE_EYE = Color3.fromRGB(215, 40, 50)
local GOLEM_EYE = Color3.fromRGB(225, 55, 40)
local CRYSTAL = { Detail = 0, Material = Enum.Material.Glass, Thickness = 0.05 }

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

-- Lowest point of the boxes of the wedges that draw triangle (a, c, d): the builder measures a critter's
-- feet with these boxes, and a long sloped facet's box can reach well below the facet itself.
local function wedgeBottom(a: Vector3, c: Vector3, d: Vector3, inside: Vector3): number
	local low = math.huge
	for _, wedge in LowPoly.TriangleWedges(a, c, d, 0.1, inside) do
		local cf, size = wedge.CFrame, wedge.Size
		local half = math.abs(cf.XVector.Y) * size.X / 2 + math.abs(cf.YVector.Y) * size.Y / 2 + math.abs(cf.ZVector.Y) * size.Z / 2
		low = math.min(low, cf.Position.Y - half)
	end
	return low
end

--[[
	Faces of a mesh resting on the ground: every facet whose wedge boxes would dip below `floor` is split at
	the midpoint of its longest edge (new vertices are appended to `vertices`), so the critter's measured
	bottom stays on the ground. Only a few facets near the ground are split (2 more parts each).
]]
local function groundSafe(vertices: { Vector3 }, faces: { { number } }, floor: number): { { number } }
	local inside = Vector3.zero
	for _, vertex in vertices do
		inside += vertex
	end
	inside /= #vertices
	local out = {}
	local function add(face: { number }, depth: number)
		local i, j, k = face[1], face[2], face[3]
		local a, c, d = vertices[i], vertices[j], vertices[k]
		if depth >= 3 or math.min(a.Y, c.Y, d.Y) < floor or wedgeBottom(a, c, d, inside) >= floor then
			table.insert(out, face)
			return
		end
		-- Apex p opposite the longest edge q-r.
		local ac, cd, da = (c - a).Magnitude, (d - c).Magnitude, (a - d).Magnitude
		local p, q, r = k, i, j
		if cd >= ac and cd >= da then
			p, q, r = i, j, k
		elseif da >= ac and da >= cd then
			p, q, r = j, k, i
		end
		table.insert(vertices, (vertices[q] + vertices[r]) / 2)
		local m = #vertices
		add({ p, q, m }, depth + 1)
		add({ p, m, r }, depth + 1)
	end
	for _, face in faces do
		add(face, 0)
	end
	return out
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
		local handle = b:Mesh(name .. (if index > 1 then tostring(index) else ""), vertices, groups[color], color, opts)
		first = first or handle.Part
		for _, triangle in handle.Tris do
			table.insert(tris, triangle)
		end
	end
	return { Part = first, Center = center, Size = size, Tris = tris }
end

--[[
	Low-poly ball like b:Ball (same part cost) that can be sculpted and painted facet by facet.
	opts.Detail (default 2), or opts.Ring = n for a cheaper bipyramid (n ring vertices at height opts.RingY,
	2n facets; index 1 = top, n + 2 = bottom); opts.Deform(v, index) moves the unit vertices (|v| = 1, -Z = front) before
	scaling; opts.Floor: resting on the ground (see groundSafe); opts.Paint(normal, offset, index) returns the colour of a facet (nil = `color`): normal and
	offset (facet centre - position) in design space. Returns a handle for the face helpers.
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
	if options.Floor then
		faces = groundSafe(vertices, faces, options.Floor)
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
		return options.Paint(normal, centre - position, face) or color
	end, position, size, options.Mesh)
end

-- Deform: pushes the lower front vertices forwards (a muzzle), widened / lowered, the chin a little,
-- and with `bridge` the upper front vertex too (a longer snout).
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

-- Deform: lowers the top vertex of a ball by `top` (a rounder dome instead of a pointed cap), then
-- applies `after` (another deform) if given.
local function domed(top: number, after)
	return function(v: Vector3, index: number): Vector3
		local w = if v.Y > 0.99 then v * top else v
		return if after then after(w, index) else w
	end
end

-- Nearest facet of a shape hit by a ray: point and outward normal.
local function cast(handle, origin: Vector3, direction: Vector3): (Vector3?, Vector3?)
	local best, hit = math.huge, nil
	for _, tri in handle.Tris do
		local e1, e2 = tri.B - tri.A, tri.C - tri.A
		local p = direction:Cross(e2)
		local det = e1:Dot(p)
		if math.abs(det) > 1e-9 then
			local tv = origin - tri.A
			local q = tv:Cross(e1)
			local u, v, t = tv:Dot(p) / det, direction:Dot(q) / det, e2:Dot(q) / det
			if u >= 0 and v >= 0 and u + v <= 1 and t > 0 and t < best then
				best, hit = t, tri
			end
		end
	end
	if not hit then
		return nil, nil
	end
	local point = origin + direction * best
	local normal = (hit.B - hit.A):Cross(hit.C - hit.A).Unit
	if (point - (hit.Inside or handle.Center)):Dot(normal) < 0 then
		normal = -normal
	end
	return point, normal
end

-- Point on the front of a shape at the design height y (x = offset from its centre), lifted outwards.
local function onFront(b, shape, x: number, y: number, lift: number): Vector3
	return (b:OnSurface(shape, x, y - shape.Center.Y) * CFrame.new(0, 0, -lift)).Position
end

--[[
	Pyramid from `base` to `tip` whose bulk lies on the `down` side of the base-tip edge: two of its three
	faces are right-angled triangles (one part each), 4 parts in all (horns, ears, claws, tails, brows).
	Sink the base into the parent shape.
]]
local function prongPoints(base: Vector3, tip: Vector3, width: number, depth: number, down: Vector3): (Vector3, Vector3)
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
	return low + across, low - across
end

local function prong(b, name: string, base: Vector3, tip: Vector3, width: number, depth: number, down: Vector3, color: any, opts: any?)
	local left, right = prongPoints(base, tip, width, depth, down)
	return b:Mesh(name, { base, left, right, tip }, { { 1, 2, 4 }, { 1, 3, 4 }, { 2, 3, 4 } }, color, opts or THIN)
end

--[[
	Fluffy tail / lock: a three-sided spindle from `root` through a ring of radius `radius` around `ring` to
	`tip` (the tip may bend away from the root-ring line: a curl). Root half in rootColor, tip half in
	tipColor, ~12 parts. `up` turns the ring (one ridge towards it).
]]
local function plume(
	b,
	name: string,
	root: Vector3,
	ring: Vector3,
	tip: Vector3,
	radius: number,
	rootColor: any,
	tipColor: any,
	up: Vector3?
)
	local u, v = LowPoly.Perpendiculars(ring - root, up)
	local vertices = { root, tip }
	for k = 0, 2 do
		local a = k * TAU / 3
		table.insert(vertices, ring + (u * math.cos(a) + v * math.sin(a)) * radius)
	end
	b:Mesh(name, vertices, { { 1, 3, 4 }, { 1, 4, 5 }, { 1, 5, 3 } }, rootColor, THIN)
	return b:Mesh(name .. "Tip", vertices, { { 2, 4, 3 }, { 2, 5, 4 }, { 2, 3, 5 } }, tipColor, THIN)
end

-- Flat right-angled triangle (1 part) from `base` to `tip`, `width` wide at the base, facing `facing`
-- (feathers, fins, claws). A negative width puts the wide side on the other edge.
local function feather(b, name: string, base: Vector3, tip: Vector3, width: number, facing: Vector3, color: any, opts: any?)
	local axis = tip - base
	local across = axis:Cross(facing)
	if across.Magnitude < 1e-4 then
		across = axis:Cross(UP)
	end
	return b:Tri(name, base, base + across.Unit * width, tip, color, opts or THIN)
end

-- `count` claws (1 part each) spread along `across` around `at`, pointing along `direction`.
local function claws(
	b,
	name: string,
	at: Vector3,
	direction: Vector3,
	across: Vector3,
	count: number,
	spread: number,
	size: number,
	color: any?
)
	local side = across.Unit
	local facing = direction:Cross(side)
	for index = 1, count do
		local offset = (index - (count + 1) / 2) * spread
		local base = at + side * offset
		local dir = (direction.Unit + side * offset * 0.4).Unit
		feather(b, name .. index, base - side * (size * 0.22), base + dir * size, size * 0.45, facing, color or "White", CLAW)
	end
end

--[[
	Serpent body: rings along a curve (rotation-minimising frames, every ring turned half a step so each
	facet is a real triangle). radii[i] = 0 makes that end a point. The rings are computed once for the
	whole curve, then sections of it are drawn inside different bones with serpentPart, so the body is
	continuous at rest and bends at the bone pivots. Rings that reach down to `floor` are squashed
	vertically by `squash` and their points below the floor are lifted onto it.
]]
local function serpentRings(points: { Vector3 }, radii: { number }, sides: number, hint: Vector3?, floor: number?, squash: number?)
	local count = #points
	local tangents = {}
	for i = 1, count do
		local before = points[math.max(1, i - 1)]
		local after = points[math.min(count, i + 1)]
		tangents[i] = (after - before).Unit
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
			local offset = (u * math.cos(a) + v * math.sin(a)) * radii[i]
			-- Rings resting on the ground are squashed (wider than tall) with a flat underside.
			if floor and points[i].Y - radii[i] < floor + 0.15 then
				offset = V(offset.X, offset.Y * (squash or 1), offset.Z)
			end
			local point = points[i] + offset
			if floor and point.Y < floor then
				point = V(point.X, floor, point.Z)
			end
			ring[k + 1] = point
		end
		data[i] = { Center = points[i], Radius = radii[i], Ring = ring }
	end
	return { Rings = data, Sides = sides, Floor = if floor then floor - 0.1 else nil }
end

--[[
	Draws the segments between rings first..last of a serpent (one closed faceted mesh per segment and
	colour, so every plate is pushed towards its own segment). paint(normal, segment) -> colour of a facet.
	The first ring is left open: start the curve inside the shape it grows from (a head, a body). With
	`overlap`, a section that starts mid-body (in a child bone) begins that far inside the previous one.
]]
local function serpentPart(b, name: string, body, first: number, last: number, paint, overlap: number?)
	local rings, sides = body.Rings, body.Sides
	local tris = {}
	for i = first, last - 1 do
		local r1, r2 = rings[i], rings[i + 1]
		local vertices = table.clone(r1.Ring)
		if i == first and overlap and i > 1 then
			-- Start a little inside the previous section (pulled back along that section's last segment and
			-- slightly shrunk) so no gap opens when this bone turns, even at a sharp bend.
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
		if body.Floor then
			faces = groundSafe(vertices, faces, body.Floor)
		end
		local mid = (r1.Center + r2.Center) / 2
		local handle = paintedMesh(b, name, vertices, faces, function(_, face)
			local a, c, d = vertices[face[1]], vertices[face[2]], vertices[face[3]]
			local normal = (c - a):Cross(d - a).Unit
			if normal:Dot((a + c + d) / 3 - mid) < 0 then
				normal = -normal
			end
			return paint(normal, i)
		end, mid, V(1, 1, 1), SKIN)
		for _, triangle in handle.Tris do
			table.insert(tris, triangle)
		end
	end
	local a, c = rings[first].Center, rings[last].Center
	return { Part = nil, Center = (a + c) / 2, Size = V(1, 1, 1) + (c - a) * V(1, 1, 1), Tris = tris }
end

-- Facet painter: facets facing `dir` (within the threshold cosine) are cream, the others body colour.
local function bellyFacing(dir: Vector3, threshold: number?, belly: any?, body: any?)
	local unit = dir.Unit
	return function(normal: Vector3): any
		return if normal:Dot(unit) > (threshold or 0.55) then belly or "Belly" else body or "Body"
	end
end

-- Lathe frame lying along the body (quadrupeds): local +Y = front (-Z), local +Z = up.
local SIDEWAYS = CFrame.Angles(math.rad(-90), 0, 0)

--[[
	Closed faceted solid around the local Y axis of `frame` (bodies): rings { y, rx, rz?, dz? } listed from the
	bottom up, `sides` vertices per ring, each ring turned half a step from the one below so every facet is a
	triangle, pointed ends at the local points `bottom` / `top` (nil leaves that end open: only when it is buried in
	another shape). `color` is a colour or function(facetCentre) -> colour. 2 * sides triangles per ring gap plus
	`sides` per closed end, ~2 parts each.
]]
local function lathe(
	b,
	name: string,
	frame: CFrame,
	rings: { { number } },
	sides: number,
	bottom: Vector3?,
	top: Vector3?,
	color: any,
	opts: any?,
	twist: number?
)
	local vertices, faces = {}, {}
	for i, ring in rings do
		local y, rx = ring[1], ring[2]
		local rz, dz = ring[3] or rx, ring[4] or 0
		for k = 0, sides - 1 do
			local a = (k + (i - 1) * 0.5 + (twist or 0)) * TAU / sides
			table.insert(vertices, frame:PointToWorldSpace(V(math.sin(a) * rx, y, -math.cos(a) * rz + dz)))
		end
	end
	local function at(i: number, k: number): number
		return (i - 1) * sides + (k % sides) + 1
	end
	for i = 1, #rings - 1 do
		for k = 0, sides - 1 do
			table.insert(faces, { at(i, k), at(i, k + 1), at(i + 1, k) })
			table.insert(faces, { at(i + 1, k), at(i, k + 1), at(i + 1, k + 1) })
		end
	end
	for _, cap in { { bottom, 1 }, { top, #rings } } do
		local point, ring = cap[1], cap[2]
		if point then
			table.insert(vertices, frame:PointToWorldSpace(point))
			local apex = #vertices
			for k = 0, sides - 1 do
				table.insert(faces, { at(ring, k), at(ring, k + 1), apex })
			end
		end
	end
	local low, high = vertices[1], vertices[1]
	for _, v in vertices do
		low = V(math.min(low.X, v.X), math.min(low.Y, v.Y), math.min(low.Z, v.Z))
		high = V(math.max(high.X, v.X), math.max(high.Y, v.Y), math.max(high.Z, v.Z))
	end
	return paintedMesh(b, name, vertices, faces, function(_, face)
		if type(color) ~= "function" then
			return color
		end
		return color((vertices[face[1]] + vertices[face[2]] + vertices[face[3]]) / 3)
	end, (low + high) / 2, high - low, opts)
end

--[[
	Leg column: a twisted triangular tube through `points` (top first, buried in the body), one radius per point
	and one colour per segment, the last ring on the ground with its front corner pushed out by `toe` (the paw).
	The sole is left open (it lies on the ground). 6 facets per segment (~12 parts).
]]
local function column(b, name: string, points: { Vector3 }, radii: { number }, colors: { any }, toe: number?, opts: any?)
	local n = #points
	local rings = {}
	for i = 1, n do
		local ring = {}
		for k = 0, 2 do
			local a = (k + (i - n) * 0.5) * TAU / 3
			local r = radii[i] * (if i == n and k == 0 then toe or 1 else 1)
			ring[k + 1] = points[i] + V(math.sin(a) * r, 0, -math.cos(a) * r)
		end
		rings[i] = ring
	end
	for i = 1, n - 1 do
		local r1, r2 = rings[i], rings[i + 1]
		local faces = {}
		for k = 1, 3 do
			local k1 = k % 3 + 1
			table.insert(faces, { k, k1, k + 3 })
			table.insert(faces, { k + 3, k1, k1 + 3 })
		end
		b:Mesh(name .. i, { r1[1], r1[2], r1[3], r2[1], r2[2], r2[3] }, faces, colors[math.min(i, #colors)], opts)
	end
end

--[[
	Slim leg from `top` to `bottom`: a spindle whose front edge is straight (on the axis) and whose bulk lies towards
	`back`, widest at `ringAt`. Four of its six faces are right-angled (one part each): ~8 parts.
]]
local function strut(
	b,
	name: string,
	top: Vector3,
	bottom: Vector3,
	width: number,
	depth: number,
	back: Vector3,
	color: any,
	ringAt: number?
)
	local axis = bottom - top
	local d = axis.Unit
	local dn = (back - d * back:Dot(d)).Unit
	local across = d:Cross(dn) * (width / 2)
	local ring = top + axis * (ringAt or 0.4)
	local low = ring + dn * depth
	local faces = { { 5, 2, 1 }, { 5, 3, 1 }, { 2, 3, 1 }, { 5, 2, 4 }, { 5, 3, 4 }, { 2, 3, 4 } }
	return b:Mesh(name, { top, low + across, low - across, bottom, ring }, faces, color, THIN)
end

-- Small flat triangle on the front of a shape at (x, y) from its centre, point down, lifted `lift` off it (noses).
local function faceTri(b, name: string, shape, x: number, y: number, width: number, height: number, color: any, lift: number?)
	local frame = b:OnSurface(shape, x, y) * CFrame.new(0, 0, -(lift or 0.03))
	return b:Tri(
		name,
		frame * V(-width / 2, height / 2, 0),
		frame * V(width / 2, height / 2, 0),
		frame * V(0, -height / 2, -0.02),
		color,
		{ Thickness = 0.05 }
	)
end

-- Same frame as CritterBuilder's Spike: +Y along the spike, Z towards the hint.
local function spikeFrame(base: Vector3, tip: Vector3, hint: Vector3?): (Vector3, Vector3, Vector3)
	local y = (tip - base).Unit
	local z = hint or FRONT
	z = z - y * z:Dot(y)
	if z.Magnitude < 1e-3 then
		z = SIDE - y * y.X
	end
	z = z.Unit
	return y:Cross(z), y, z
end

-- Flat triangle lying on the face of a Spike pyramid opposite its ridge (inner ears), shrunk by `scale`.
local function innerFace(
	b,
	name: string,
	base: Vector3,
	tip: Vector3,
	width: number,
	depth: number,
	hint: Vector3?,
	scale: number,
	color: any
)
	local x, _, z = spikeFrame(base, tip, hint)
	local front = base + z * (depth * 0.6)
	local left = base - x * (width / 2) - z * (depth * 0.4)
	local right = base + x * (width / 2) - z * (depth * 0.4)
	local centre = (left + right + tip) / 3
	local normal = (right - left):Cross(tip - left).Unit
	if normal:Dot(centre - front) < 0 then
		normal = -normal
	end
	local offset = normal * 0.035
	local function shrink(point: Vector3): Vector3
		return centre + (point - centre) * scale + offset
	end
	return b:Tri(name, shrink(left), shrink(right), shrink(tip), color, THIN)
end

-- Dragon line ------------------------------------------------------------------------------------

-- Wing-like ear fins of the dragon line: right-angled feathers fanning backwards from the side of the
-- head, joined by a web. Give the right side (inside a mirrored bone).
local function finEar(b, root: Vector3, tips: { Vector3 }, width: number, facing: Vector3, color: any)
	for index, tip in tips do
		local base = root + V(0, (2 - index) * 0.1, (index - 2) * 0.05)
		feather(b, "Fin" .. index, base, tip, -width, facing, color)
	end
	b:Tri("FinWeb", root + V(-0.04, 0.16, -0.06), root + V(-0.02, -0.18, 0.06), root:Lerp(tips[2], 0.55), color, THIN)
end

-- Little blue serpent: the front of its body rises in an S like a cobra, the rest lies coiled on the
-- ground behind it. Big round head, huge purple eyes, white three-pointed fin ears and forehead nub,
-- cream belly scales along the front.
Designs["Drakelet"] = function(b)
	local path = {
		V(0, 2.62, -0.45),
		V(0, 1.74, -0.1),
		V(0.04, 0.84, -0.32),
		V(0.98, 0.42, 0.05),
		V(0.62, 0.4, 1.2),
		V(-0.7, 0.38, 1.05),
		V(-1.02, 1.1, -0.32),
	}
	local body = serpentRings(path, { 0.38, 0.45, 0.52, 0.5, 0.44, 0.32, 0 }, 5, FRONT, 0.03, 0.85)
	local neckPaint = bellyFacing(V(0, -0.15, -1), 0.5)
	local coilPaint = bellyFacing(V(0, -1, 0), 0.6)

	local core = serpentPart(b, "Body", body, 3, 4, function(normal: Vector3): any
		return if normal.Z < -0.8 or normal.Y < -0.6 then "Belly" else "Body"
	end)
	b:SetCore(core)

	-- The coil sways on the ground in two steps.
	b:Bone("Tail", path[4], { Amp = 0.5 }, function()
		serpentPart(b, "Tail", body, 4, 6, coilPaint, 0.2)
		b:Bone("Tail2", path[6], { Phase = 0.2 }, function()
			serpentPart(b, "TailTip", body, 6, 7, coilPaint, 0.2)
		end)
	end)

	-- The raised neck sways like a cobra, the head looks around on top of it.
	b:Bone("Neck", path[3], { Role = "Head", Amp = 0.45 }, function()
		serpentPart(b, "Neck", body, 1, 3, neckPaint)
		b:Bone("Head", V(0, 2.35, -0.42), nil, function()
			local head =
				sculpt(b, "Head", V(1.62, 1.5, 1.5), V(0, 2.98, -0.5), nil, "Body", { Deform = domed(0.86, snout(0.16, 1.08, 0.02)) })
			b:Eyes(head, 0.38, 0.08, V(0.44, 0.54, 0.26), DRATINI_EYE)
			b:Mouth(head, -0.3, 0.36)
			-- Small white nub on the forehead.
			local nub = onFront(b, head, 0, 3.44, -0.12)
			prong(b, "Nub", nub, nub + V(0, 0.3, -0.12), 0.3, 0.24, BACK, "Accent")
			b:MirrorBone("Ear", V(0.68, 3.05, -0.48), nil, function()
				finEar(
					b,
					V(0.64, 3.06, -0.48),
					{ V(1.28, 3.62, -0.26), V(1.55, 3.1, -0.12), V(1.3, 2.6, 0.02) },
					0.3,
					V(0.35, 0.1, -1),
					"Accent"
				)
			end)
		end)
	end)
end

-- Elegant serpent floating in an S-curve: slim blue body with a white underside, long rounded snout, white
-- unicorn horn, small white feathered wings on the sides of its head, a crystal orb on its throat and two near
-- the tip of its tail.
Designs["Serpendrake"] = function(b)
	b.Hover = 1.2
	-- The body falls from the head in an S that also swings back and forth (an S seen from the front and from the
	-- side), and the tail curls up again on the left.
	local path = {
		V(0, 4.45, -0.82),
		V(-0.5, 3.6, -0.4),
		V(-0.15, 2.72, 0.3),
		V(0.9, 2.1, 0.22),
		V(1.0, 1.05, -0.3),
		V(-0.2, 0.55, -0.12),
		V(-1.4, 1.05, 0.62),
	}
	local body = serpentRings(path, { 0.38, 0.44, 0.5, 0.52, 0.46, 0.34, 0 }, 5, FRONT)
	local neckPaint = bellyFacing(V(0, -0.2, -1), 0.62)
	local bodyPaint = bellyFacing(V(0, -1, -0.5), 0.6)

	local core = serpentPart(b, "Body", body, 3, 4, bodyPaint)
	b:SetCore(core)

	-- The body waves in two steps; crystal beads on the thin end of the tail.
	b:Bone("Tail", path[4], { Amp = 0.45 }, function()
		serpentPart(b, "Tail", body, 4, 6, bodyPaint, 0.2)
		b:Bone("Tail2", path[6], { Phase = 0.2, Amp = 0.6 }, function()
			serpentPart(b, "TailTip", body, 6, 7, bodyPaint, 0.2)
			sculpt(b, "TailOrb1", V(0.56, 0.62, 0.56), path[6]:Lerp(path[7], 0.32), nil, "Accent", { Ring = 3, Mesh = CRYSTAL })
			sculpt(b, "TailOrb2", V(0.46, 0.52, 0.46), path[6]:Lerp(path[7], 0.62), nil, "Accent", { Ring = 3, Mesh = CRYSTAL })
		end)
	end)

	b:Bone("Neck", path[3], { Role = "Head", Amp = 0.4 }, function()
		serpentPart(b, "Neck", body, 1, 3, neckPaint)
		-- Crystal orb on the throat.
		b:Ball("NeckOrb", V(0.52, 0.52, 0.44), V(-0.44, 3.45, -0.86), nil, "Accent", CRYSTAL)
		b:Bone("Head", V(0, 4.0, -0.7), nil, function()
			local head =
				sculpt(b, "Head", V(1.44, 1.28, 1.76), V(0, 4.56, -0.96), nil, "Body", { Deform = domed(0.9, snout(0.36, 0.86, 0.06)) })
			b:Eyes(head, 0.34, 0.14, V(0.36, 0.44, 0.26), DRAGONAIR_EYE)
			b:Mouth(head, -0.26, 0.3)
			-- White unicorn horn on the forehead.
			local hornBase = onFront(b, head, 0, 4.98, -0.14)
			prong(b, "Horn", hornBase, hornBase + V(0, 0.66, -0.06), 0.3, 0.26, BACK, "Belly")
			-- Feathered head wings (they flap while it hovers).
			b:MirrorBone("Wing", V(0.54, 4.62, -0.8), nil, function()
				finEar(
					b,
					V(0.52, 4.62, -0.82),
					{ V(0.92, 5.55, -0.42), V(1.26, 5.24, -0.08), V(1.3, 4.82, 0.22) },
					0.3,
					V(0.25, 0.15, -1),
					"Belly"
				)
			end)
		end)
	end)
end

-- Big friendly flying dragon: chubby pear-shaped orange body, ribbed cream belly, thick neck, rounded snout,
-- curled antennae, small horns, stubby clawed arms, small teal wings, thick legs dangling while it hovers.
Designs["Puffdrake"] = function(b)
	b.Hover = 1.1
	local body = sculpt(b, "Body", V(2.5, 2.55, 2.2), V(0, 1.78, 0.1), nil, "Body", {
		-- Pear shaped: wide belly and hips, narrower shoulders.
		Deform = function(v: Vector3): Vector3
			return V(v.X * (1 - v.Y * 0.14), v.Y, v.Z * (1 - v.Y * 0.08) - (if v.Z < -0.5 and v.Y < 0.5 then 0.06 else 0))
		end,
		Paint = function(normal: Vector3): any
			return if normal.Z < -0.4 and math.abs(normal.X) < 0.72 then "Belly" else nil
		end,
	})
	b:SetCore(body)
	-- Ribs across the belly: thin darker bands (two right-angled slivers each) lying on its facets.
	for index, y in { 1.28, 1.74, 2.2 } do
		local half = 0.66 - math.abs(y - 1.74) * 0.3
		local centre = onFront(b, body, 0, y, 0.07)
		for _, side in { -1, 1 } do
			feather(b, "Rib" .. index, centre, onFront(b, body, side * half, y, 0.05), side * 0.12, FRONT, "Extra")
		end
	end
	local neck = serpentRings({ V(0, 2.62, -0.1), V(0, 3.62, -0.34) }, { 0.66, 0.5 }, 4, FRONT)
	serpentPart(b, "Neck", neck, 1, 2, bellyFacing(FRONT, 0.6))

	-- Stubby arms with three claws.
	b:MirrorBone("Arm", V(0.92, 2.45, -0.38), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.76, 2.5, -0.3), V(1.14, 1.9, -1.12), 0.52, "Body", { RingAt = 0.4 })
		claws(b, "Claw", V(1.15, 1.88, -1.14), V(0.1, -0.55, -0.85), V(1, 0, -0.2), 3, 0.11, 0.24, "Belly")
	end)
	-- Thick legs with big three-toed feet (they dangle and paddle while it hovers).
	b:MirrorBone("Leg", V(0.68, 1.0, 0.12), nil, function()
		b:Limb("Leg", V(0.64, 1.4, 0.16), V(0.76, 0.24, -0.02), 1.0, "Body", { RingAt = 0.36 })
		prong(b, "Foot", V(0.76, 0.4, 0.2), V(0.8, 0.03, -0.66), 0.96, 0.4, V(0, -0.85, 0.5), "Body")
		claws(b, "Toe", V(0.8, 0.14, -0.3), V(0, -0.3, -1), SIDE, 3, 0.14, 0.2, "Belly")
	end)

	-- Small wings on the back: an orange spar and a teal membrane.
	b:MirrorBone("Wing", V(0.42, 2.62, 0.72), nil, function()
		prong(b, "WingSpar", V(0.36, 2.6, 0.7), V(2.25, 4.1, 1.0), 0.22, 0.18, DOWN, "Body")
		b:Tri("Membrane1", V(0.42, 2.6, 0.78), V(2.21, 4.06, 1.02), V(1.9, 2.86, 1.26), "Accent", THIN)
		b:Tri("Membrane2", V(0.42, 2.6, 0.78), V(1.9, 2.86, 1.26), V(1.05, 2.1, 1.12), "Accent", THIN)
	end)

	-- Thick tail tapering behind (it hangs down while it hovers).
	b:Bone("Tail", V(0, 1.15, 0.92), nil, function()
		local tail = serpentRings({ V(0, 1.2, 0.8), V(0, 0.62, 1.72), V(0, 0.42, 2.55) }, { 0.62, 0.42, 0 }, 4, UP)
		serpentPart(b, "Tail", tail, 1, 3, bellyFacing(DOWN, 0.6))
	end)

	b:Bone("Head", V(0, 3.5, -0.32), nil, function()
		local head =
			sculpt(b, "Head", V(1.62, 1.42, 1.48), V(0, 4.02, -0.44), nil, "Body", { Deform = domed(0.86, snout(0.46, 1.02, 0.04, 0.2)) })
		b:Eyes(head, 0.34, 0.26, V(0.3, 0.36, 0.22), "Black")
		b:Mouth(head, -0.34, 0.42, true)
		-- Small horns on the sides of the head.
		for _, side in { -1, 1 } do
			prong(
				b,
				"Horn" .. (if side < 0 then "L" else "R"),
				V(side * 0.52, 4.28, -0.28),
				V(side * 0.7, 4.7, -0.02),
				0.22,
				0.18,
				BACK,
				"Body"
			)
		end
		-- Thin antennae arching up from the forehead, tips bending forwards (they twitch like ears).
		b:MirrorBone("Ear", V(0.17, 4.5, -0.72), nil, function()
			prong(b, "Antenna", V(0.16, 4.46, -0.7), V(0.32, 5.3, -0.86), 0.14, 0.11, BACK, "Body")
			prong(b, "AntennaTip", V(0.31, 5.25, -0.85), V(0.52, 5.58, -0.56), 0.12, 0.09, BACK, "Body")
		end)
	end)
end

-- Rock ------------------------------------------------------------------------------------------

-- Lumpy rock deform: each icosahedron vertex pushed in / out by its bump.
local function lumps(bumps: { number })
	return function(v: Vector3, index: number): Vector3
		return v * (bumps[index] or 1)
	end
end

-- Weathered stone: about a third of the facets (picked from their vertex indices and `seed`) in the darker
-- colour, except those facing `clear` (the face).
local function stonePaint(dark: any, clear: Vector3?, seed: number?)
	return function(normal: Vector3, _offset: Vector3, face: { number }): any
		if clear and normal:Dot(clear) > 0.6 then
			return nil
		end
		return if (face[1] * 7 + face[2] * 3 + face[3] + (seed or 0)) % 3 == 0 then dark else nil
	end
end

-- Living rock flexing two strong arms: lumpy round body with darker stone patches, heavy rock brows over
-- determined eyes, a grumpy mouth, bent muscular arms ending in big rocky fists.
Designs["Pebbit"] = function(b)
	local bumps = { 0.92, 1.05, 0.97, 1.08, 1.02, 0.96, 1.04, 0.98, 1.07, 0.95, 1.03, 0.94 }
	local body = sculpt(b, "Body", V(2.3, 2.1, 2.1), V(0, 1.02, 0), nil, "Body", {
		Deform = lumps(bumps),
		Paint = stonePaint("Accent", FRONT, 2),
		Floor = -0.1,
	})
	b:SetCore(body)
	b:Eyes(body, 0.4, 0.18, V(0.4, 0.4, 0.26), "White")
	-- Heavy rock brows slanting down towards the nose (determined look).
	for _, side in { -1, 1 } do
		local outer = onFront(b, body, side * 0.8, 1.6, -0.02)
		local inner = onFront(b, body, side * 0.06, 1.42, 0.08)
		prong(b, "Brow" .. (if side < 0 then "L" else "R"), outer, inner, 0.4, 0.34, V(0, -0.3, 1), "Accent")
	end
	-- Wide clenched grin: a dark slit with a row of teeth in front of it.
	b:Mouth(body, -0.3, 0.7)
	b:Tri("Teeth", onFront(b, body, -0.26, 0.74, 0.07), onFront(b, body, 0.26, 0.74, 0.07), onFront(b, body, 0, 0.66, 0.08), "White", THIN)

	-- Bent arms flexing big fists: a bulging upper arm and a forearm widening towards the wrist, overlapping at
	-- the elbow.
	b:MirrorBone("Arm", V(1.0, 1.12, 0.0), { Phase = 0.5 }, function()
		b:Limb("UpperArm", V(0.55, 1.06, 0.06), V(2.3, 1.22, -0.02), 0.74, "Body", { RingAt = 0.6, Sides = 4, Thickness = 0.07 })
		b:Limb("Forearm", V(2.04, 1.02, 0.02), V(2.02, 2.36, -0.24), 0.8, "Body", { RingAt = 0.45, Thickness = 0.07, Up = BACK })
		-- Big lumpy rock fist.
		sculpt(b, "Fist", V(1.0, 0.92, 0.94), V(2.02, 2.42, -0.28), V(0, 20, 0), "Body", {
			Detail = 1,
			Deform = lumps({ 1.05, 0.95, 1.08, 0.97, 1.04, 0.94, 1.06, 0.98, 1.02, 0.95 }),
			Paint = stonePaint("Accent"),
			Mesh = { Thickness = 0.1 },
		})
	end)
end

-- Big round boulder of rock plates standing on short stubby legs: the tan reptile head peeks out of its upper front
-- under a heavy rock brow, thick arms with three-clawed hands stick out of its sides, rocky crags all over the shell.
Designs["Bouldron"] = function(b)
	local bumps = { 1.0, 0.95, 1.1, 0.96, 1.07, 0.97, 1.06, 0.95, 1.08, 0.97, 1.04, 0.92 }
	local shell = sculpt(b, "Shell", V(3.3, 3.0, 3.1), V(0, 1.9, 0.22), nil, "Body", {
		Deform = domed(0.86, lumps(bumps)),
		Paint = stonePaint("Accent", nil, 1),
	})
	b:SetCore(shell)
	-- Rocky crags jutting out of the shell (top, shoulders, back), leaning backwards.
	for index, spot in { V(0.55, 3.4, 0.2), V(-0.7, 3.3, 0.55), V(1.3, 2.6, 0.7), V(-1.1, 2.3, 1.25) } do
		local point, normal = cast(shell, spot + (spot - shell.Center).Unit * 4, (shell.Center - spot).Unit)
		if point and normal then
			local base = point - normal * 0.3
			local tip = point + (normal + V(0, 0.1, 0.35)).Unit * 0.42
			b:Cone("Crag" .. index, base, tip, 0.62, "Body", { Sides = 3, Thickness = 0.1, Up = BACK })
		end
	end

	-- Short stubby legs on wide rounded feet with three white claws.
	b:MirrorBone("Leg", V(0.85, 1.05, 0.3), { Amp = 0.6 }, function()
		b:Limb("Leg", V(0.82, 1.45, 0.32), V(0.9, 0.24, 0.2), 1.0, "Belly", { RingAt = 0.55, Thickness = 0.08 })
		b:Ball("Foot", V(1.05, 0.56, 1.2), V(0.92, 0.28, 0.12), nil, "Belly", { Detail = 0 })
		claws(b, "Toe", V(0.92, 0.16, -0.42), V(0, -0.12, -1), SIDE, 3, 0.24, 0.3)
	end)
	-- Thick short arms out of the sides of the shell, hands with three stubby fingers.
	b:MirrorBone("Arm", V(1.35, 2.1, -0.1), { Phase = 0.5 }, function()
		local wrist = V(2.0, 1.52, -0.6)
		b:Limb("Arm", V(1.1, 2.2, -0.05), wrist + V(0.02, -0.06, -0.06), 0.9, "Belly", { RingAt = 0.4, Thickness = 0.08 })
		for index, dir in { V(0.32, -0.62, -0.72), V(0.02, -0.66, -0.75), V(-0.28, -0.6, -0.75) } do
			prong(b, "Finger" .. index, wrist + dir * 0.1, wrist + dir.Unit * 0.6, 0.42, 0.42, V(0, 0.6, 1), "Belly")
		end
	end)

	b:Bone("Head", V(0, 2.25, -0.85), nil, function()
		local head = sculpt(
			b,
			"Head",
			V(1.62, 1.26, 1.4),
			V(0, 2.34, -1.18),
			nil,
			"Belly",
			{ Detail = 1, Deform = domed(0.9, snout(0.16, 1.12, 0.02)) }
		)
		b:Eyes(head, 0.34, 0.1, V(0.3, 0.28, 0.2), GOLEM_EYE)
		b:Mouth(head, -0.3, 0.74)
		-- Heavy rock brow over the eyes, the same stone as the shell (it reads as the shell's front lip).
		for _, side in { -1, 1 } do
			prong(
				b,
				"Brow" .. (if side < 0 then "L" else "R"),
				V(side * 0.82, 2.98, -0.8),
				V(side * 0.02, 2.72, -1.94),
				0.46,
				0.42,
				V(0, -0.2, 1),
				"Body"
			)
		end
	end)
end

-- Fox line ----------------------------------------------------------------------------------------

-- Fox cub: big head with huge dark-lined ears and a tuft of three orange curls on the forehead, small body with a cream
-- chest, short legs, and six fluffy tails rising behind it in a bouquet, each tail curling over at its light orange tip.
Designs["Emberfox"] = function(b)
	local body = lathe(
		b,
		"Body",
		CFrame.new(0, 0.78, 0.32) * SIDEWAYS,
		{ { -0.05, 0.54, 0.52, 0.02 } },
		4,
		V(0, -0.82, 0.12),
		V(0, 0.75, 0.2),
		function(c: Vector3): any
			return if c.Y < 0.66 or c.Z < -0.2 then "Belly" else "Body"
		end,
		THIN,
		0.5
	)
	b:SetCore(body)
	for index, z in { 0, 0.7 } do
		b:MirrorBone(if index == 1 then "LegFront" else "LegBack", V(0.27, 0.62, z), { Phase = if index == 1 then 0 else 0.5 }, function()
			column(b, "Leg", { V(0.26, 0.75, z), V(0.3, 0, z - 0.06) }, { 0.24, 0.15 }, { "Body" }, 1.6, THIN)
		end)
	end

	-- Six fluffy tails rising behind in a bouquet (angle around the back axis, 0 = up), each its own bone so they sway
	-- one after the other; every tail bends over at its tip into a light orange curl.
	for index, theta in { -44, -26, -9, 9, 26, 44 } do
		local t = math.rad(theta)
		-- The outer tails lean further back, the inner ones stand taller: a rounded bouquet, not a flat fan.
		local lean = math.rad(16 + math.abs(theta) * 0.75)
		local dir = V(math.sin(t) * math.cos(lean), math.cos(t) * math.cos(lean), math.sin(lean))
		local out = V(math.sin(t), 0, 0.6)
		local root = V(math.sin(t) * 0.12, 0.92, 0.82)
		local ring = root + dir * (1.32 - math.abs(theta) * 0.007)
		-- The curl: the tip bends over outwards / backwards and down.
		local tip = ring + (dir * 0.3 + out + V(0, -0.95, 0)).Unit * 0.85
		b:Bone("Tail" .. index, root, { Phase = index / 6, Amp = 0.55 }, function()
			plume(b, "Tail", root, ring, tip, 0.5, "Body", "Accent", out)
		end)
	end

	b:Bone("Head", V(0, 1.12, -0.24), nil, function()
		local head = sculpt(b, "Head", V(1.72, 1.5, 1.52), V(0, 1.66, -0.42), nil, "Body", { Deform = domed(0.92, snout(0.26, 0.8, 0.04)) })
		b:Eyes(head, 0.4, 0.04, V(0.44, 0.52, 0.28), FOX_EYE)
		faceTri(b, "Nose", head, 0, -0.24, 0.16, 0.1, "Black")
		b:Mouth(head, -0.4, 0.24)
		-- Tuft of three orange curls on the forehead, swept forwards over it (the middle one tallest).
		prong(b, "Curl", V(0, 2.0, -0.6), V(0, 2.72, -1.08), 0.56, 0.42, V(0, -0.2, 1), "Accent")
		for _, side in { -1, 1 } do
			prong(b, "CurlSide" .. side, V(side * 0.24, 1.98, -0.62), V(side * 0.46, 2.5, -1.12), 0.44, 0.34, V(0, -0.2, 1), "Accent")
		end
		b:MirrorBone("Ear", V(0.45, 2.1, -0.38), nil, function()
			local base, tip = V(0.42, 2.02, -0.38), V(1.12, 3.1, -0.26)
			b:Spike("Ear", base, tip, 0.86, 0.34, "Body", THIN, BACK)
			innerFace(b, "EarInner", base, tip, 0.86, 0.34, BACK, 0.62, "Extra")
		end)
	end)
end

-- Elegant golden fox standing tall: slim body, a fluffy ruff cascading down the chest, a long pointed muzzle with calm
-- red eyes, a big crest of fur swept back from the forehead, slender legs and nine long fluffy tails fanned out behind
-- it like a halo, each tip curling outwards in orange.
Designs["Novafox"] = function(b)
	-- Slim body; its front point rises into the neck (hidden by the ruff).
	local body = lathe(
		b,
		"Body",
		CFrame.new(0, 1.62, 0.35) * SIDEWAYS,
		{ { -0.15, 0.58, 0.6, 0.03 } },
		5,
		V(0, -1.2, 0.12),
		V(0, 1.22, 1.22),
		"Body",
		THIN
	)
	b:SetCore(body)
	-- Slender legs: the front ones with small paws, the back ones (behind the tails) lighter struts.
	b:MirrorBone("LegFront", V(0.3, 1.4, -0.2), nil, function()
		column(b, "Leg", { V(0.28, 1.65, -0.2), V(0.32, 0, -0.28) }, { 0.26, 0.13 }, { "Body" }, 1.8, THIN)
	end)
	b:MirrorBone("LegBack", V(0.3, 1.4, 0.92), { Phase = 0.5 }, function()
		strut(b, "Leg", V(0.28, 1.7, 0.96), V(0.33, 0, 0.8), 0.46, 0.4, V(0.3, 0, 1), "Body", 0.3)
	end)
	-- Fluffy ruff cascading down the chest: wide locks of fur hanging from the neck, the middle one longest.
	for index, spec in { { 0, 1.05, 0.98 }, { 0.42, 0.86, 0.86 }, { -0.42, 0.86, 0.86 } } do
		local x, drop, width = spec[1], spec[2], spec[3]
		local base = V(x * 0.75, 2.62, -0.62 + math.abs(x) * 0.3)
		prong(b, "Ruff" .. index, base, base + V(x * 0.9, -drop - 0.1, -0.26 + math.abs(x) * 0.2), width, 0.62, BACK, "Body")
	end

	-- Nine long fluffy tails fanned out behind it like a halo (angle around the back axis, 0 = up; lean back), the
	-- orange tips curling outwards. Each tail is its own bone so they ripple one after the other.
	local tails = {
		{ -92, 26, 2.2 },
		{ -46, 28, 2.3 },
		{ 0, 28, 2.4 },
		{ 46, 28, 2.3 },
		{ 92, 26, 2.2 },
		{ -69, 50, 1.95 },
		{ -23, 54, 2.05 },
		{ 23, 54, 2.05 },
		{ 69, 50, 1.95 },
	}
	for index, spec in tails do
		local theta, lean, length = math.rad(spec[1]), math.rad(spec[2]), spec[3]
		local dir = V(math.sin(theta) * math.cos(lean), math.cos(theta) * math.cos(lean), math.sin(lean))
		local out = V(math.sin(theta), math.cos(theta) * 0.5, 0)
		local root = V(math.sin(theta) * 0.1, 1.8, 1.05)
		local ring = root + dir * (length * 0.6)
		local tip = ring + (dir + out * 0.9).Unit * (length * 0.45)
		b:Bone("Tail" .. index, root, { Phase = index / 9, Amp = 0.4 }, function()
			plume(b, "Tail", root, ring, tip, 0.46, "Body", "Accent", out)
		end)
	end

	b:Bone("Head", V(0, 2.5, -0.62), nil, function()
		local head =
			sculpt(b, "Head", V(1.46, 1.28, 1.48), V(0, 3.08, -0.92), nil, "Body", { Deform = domed(0.9, snout(0.62, 0.6, 0.1, 0.12)) })
		b:Eyes(head, 0.34, 0.14, V(0.34, 0.38, 0.24), NINE_EYE)
		faceTri(b, "Nose", head, 0, -0.3, 0.15, 0.1, "Black")
		-- Big crest of fur swept back from the forehead.
		prong(b, "Crest", V(0, 3.4, -1.15), V(0, 4.05, 0.1), 0.56, 0.4, DOWN, "Body")
		-- Tall thin ears (flat plates) with orange insides.
		b:MirrorBone("Ear", V(0.38, 3.4, -0.82), nil, function()
			local base, tip = V(0.36, 3.32, -0.84), V(0.86, 4.4, -0.66)
			b:Spike("Ear", base, tip, 0.64, 0.12, "Body", { Thickness = 0.12 }, V(0, 0.2, -1))
			b:Spike("EarInner", base + V(0.02, 0.1, -0.08), tip + V(-0.04, -0.2, -0.07), 0.4, 0.06, "Accent", THIN, V(0, 0.2, -1))
		end)
	end)
end

-- Sea ---------------------------------------------------------------------------------------------

-- Gentle sea creature: long neck with a cream front, curled horn, grey studded shell, four paddle flippers.
Designs["Lagoonie"] = function(b)
	local body = sculpt(b, "Body", V(2.6, 1.45, 2.9), V(0, 0.78, 0.35), nil, "Body", { Detail = 1 })
	b:SetCore(body)
	-- Wide low shell dome covering the back.
	local shell = sculpt(b, "Shell", V(3.0, 1.55, 3.0), V(0, 1.16, 0.68), nil, "Accent", {
		Deform = function(v: Vector3): Vector3
			return if v.Y < 0 then V(v.X, v.Y * 0.45, v.Z) elseif v.Y > 0.99 then V(0, 1.12, 0.05) else v
		end,
	})
	-- Blunt knobs on the shell.
	for index, spot in { V(0.62, 0, 0.18), V(-0.62, 0, 0.18), V(0.78, 0, 1.05), V(-0.78, 0, 1.05), V(0, 0, 1.62) } do
		local point, normal = cast(shell, spot + V(0, 4, 0), DOWN)
		if point and normal then
			b:Spike("Knob" .. index, point - normal * 0.12, point + (normal + UP).Unit * 0.3, 0.62, 0.56, "Extra", THIN, BACK)
		end
	end

	-- Paddle flippers (they row while it walks).
	for index, spec in { { V(0.95, 0.55, -0.35), V(2.05, 0.08, -0.95), 0.75 }, { V(0.85, 0.5, 1.2), V(1.75, 0.08, 1.75), 0.6 } } do
		b:MirrorBone(if index == 1 then "FinFront" else "FinBack", spec[1], { Phase = if index == 1 then 0 else 0.5 }, function()
			local root, tip, width = spec[1], spec[2], spec[3]
			local across = (tip - root):Cross(UP).Unit * (width / 2)
			local mid = root:Lerp(tip, 0.45) + V(0, 0.08, 0)
			b:Tri("FlipperA", root, mid + across, tip, "Body", { Thickness = 0.1 })
			b:Tri("FlipperB", root, tip, mid - across, "Body", { Thickness = 0.1 })
		end)
	end

	b:Bone("Neck", V(0, 1.1, -0.75), { Role = "Tail", Amp = 0.25 }, function()
		local neck = serpentRings({ V(0, 0.9, -0.55), V(0, 2.02, -0.88), V(0, 2.92, -1.26) }, { 0.58, 0.46, 0.4 }, 5, FRONT)
		serpentPart(b, "Neck", neck, 1, 3, bellyFacing(V(0, -0.1, -1), 0.5))
		b:Bone("Head", V(0, 2.9, -1.1), nil, function()
			local head =
				sculpt(b, "Head", V(1.52, 1.32, 1.7), V(0, 3.45, -1.32), nil, "Body", { Deform = domed(0.9, snout(0.32, 0.9, 0.04)) })
			b:Eyes(head, 0.36, 0.14, V(0.38, 0.46, 0.26), "Black")
			b:Mouth(head, -0.3, 0.46)
			-- Horn curling backwards.
			prong(b, "Horn", V(0, 3.95, -1.5), V(0, 4.5, -1.42), 0.32, 0.26, BACK, "Body")
			prong(b, "HornTip", V(0, 4.4, -1.42), V(0, 4.62, -1.05), 0.24, 0.2, DOWN, "Body")
			-- Ear flaps swept back.
			b:MirrorBone("Ear", V(0.52, 3.74, -1.18), nil, function()
				prong(b, "Ear", V(0.52, 3.68, -1.2), V(1.02, 3.92, -0.5), 0.46, 0.24, DOWN, "Body")
			end)
		end)
	end)
end

return Designs
