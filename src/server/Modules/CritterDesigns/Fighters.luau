--[[
	Critter designs: Growlpup, Blazehound, Pupjack, Aurajack, Munchling, Snoozor, Psyclone, Pinkling.
	See CritterBuilder for the toolkit. Ground at y = 0, the critter faces -Z.
	Triangle style: every surface is faceted, only the eyes and the mouths are round, and every moving part
	lives in a bone (legs, arms, head, ears, tails, aura locks, floating orbs). Local helpers sculpt low-poly
	balls and lathes and paint some of their facets (bellies, masks, faces) without extra parts.
]]

local LowPoly = require(script.Parent.Parent.LowPoly)

local V = Vector3.new
local V2 = Vector2.new

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
-- Lathe frame lying along the body (quadrupeds): local +Y = front (-Z), local +Z = up.
local SIDEWAYS = CFrame.Angles(math.rad(-90), 0, 0)

local DOG_EYE = Color3.fromRGB(95, 52, 28)
local JACKAL_EYE = Color3.fromRGB(215, 35, 45)
local PSY_EYE = Color3.fromRGB(150, 70, 210)
local MEW_EYE = Color3.fromRGB(60, 135, 235)
local PSY_GLOW = Color3.fromRGB(170, 100, 255)
local SLEEP = Color3.fromRGB(170, 215, 255)

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

-- Groups faces by colour and draws one mesh per colour (all sharing the vertex list, so the plates keep the
-- same inside point); returns one handle covering every facet for the face helpers.
local function paintedMesh(b, name: string, vertices: { Vector3 }, faces: { { number } }, colorOf, center: Vector3, size: Vector3, opts: any?)
	local groups, order = {}, {}
	for _, face in faces do
		local color = colorOf(face)
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

-- Outward unit normal of a facet of a convex shape around `inside`.
local function facetNormal(a: Vector3, c: Vector3, d: Vector3, inside: Vector3): Vector3
	local normal = (c - a):Cross(d - a).Unit
	if normal:Dot((a + c + d) / 3 - inside) < 0 then
		normal = -normal
	end
	return normal
end

--[[
	Low-poly ball like b:Ball (same part cost) that can be sculpted and painted facet by facet.
	opts.Detail (default 2); opts.Deform(v) moves the unit vertices (|v| = 1, -Z = front) before scaling;
	opts.Paint(normal, offset) returns the colour of a facet (nil = `color`): outward normal and facet centre
	minus `position`, in design space. Returns a handle for the face helpers.
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
		local shaped = if options.Deform then options.Deform(v) else v
		vertices[index] = frame:PointToWorldSpace(shaped * size / 2)
	end
	return paintedMesh(b, name, vertices, faces, function(face)
		if not options.Paint then
			return color
		end
		local a, c, d = vertices[face[1]], vertices[face[2]], vertices[face[3]]
		return options.Paint(facetNormal(a, c, d, position), (a + c + d) / 3 - position) or color
	end, position, size, options.Mesh)
end

-- Deform: pushes the lower front vertices forwards (a muzzle), narrowed / lowered, the chin a little,
-- and with `bridge` the upper front vertex too (a longer snout).
local function snout(forward: number, narrow: number?, drop: number?, bridge: number?)
	return function(v: Vector3): Vector3
		if v.Z < -0.5 and v.Y < 0.1 then
			return V(v.X * (narrow or 1), v.Y - (drop or 0), v.Z - forward)
		elseif v.Y < -0.99 then
			return V(v.X, v.Y, v.Z - forward * 0.45)
		elseif bridge and v.Z < -0.85 and v.Y > 0 then
			return V(v.X, v.Y - bridge * 0.3, v.Z - bridge)
		end
		return v
	end
end

-- Deform: lowers the top vertex of a ball (a rounder dome than a pointed cap), then applies `after`.
local function domed(top: number, after: any?)
	return function(v: Vector3): Vector3
		local w = if v.Y > 0.99 then v * top else v
		return if after then after(w) else w
	end
end

--[[
	Closed faceted solid around the local Y axis of `frame` (bodies, heads): rings { y, rx, rz?, dz? } listed from
	the bottom up, `sides` vertices per ring, each ring turned half a step from the one below so every facet is a
	triangle (antiprism), pointed ends at the local points `bottom` / `top`. The first vertex of the first ring
	faces the front (-Z) of the frame. `color` is a colour or function(facetCentre, normal) -> colour.
	2 * sides triangles per ring gap plus `sides` per closed end, ~2 parts each.
]]
local function lathe(b, name: string, frame: CFrame, rings: { { number } }, sides: number, bottom: Vector3?, top: Vector3?, color: any, opts: any?, twist: number?)
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
	local sum = Vector3.zero
	for _, v in vertices do
		low = V(math.min(low.X, v.X), math.min(low.Y, v.Y), math.min(low.Z, v.Z))
		high = V(math.max(high.X, v.X), math.max(high.Y, v.Y), math.max(high.Z, v.Z))
		sum += v
	end
	local inside = sum / #vertices
	return paintedMesh(b, name, vertices, faces, function(face)
		if type(color) ~= "function" then
			return color
		end
		local a, c, d = vertices[face[1]], vertices[face[2]], vertices[face[3]]
		return color((a + c + d) / 3, facetNormal(a, c, d, inside))
	end, (low + high) / 2, high - low, opts)
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

--[[
	Pointed stripe lying on a body (tiger stripes): from the facet hit by a ray from `origin` along `direction`, a
	right-angled flat triangle (1 part) `width` wide at the hit point, reaching up to `length` along `toward`
	(projected on the facet), shortened until its point still touches the body, lifted off it. Not inside a mirrored
	bone (the points are already in actual space).
]]
local function stripe(b, name: string, shape, origin: Vector3, direction: Vector3, toward: Vector3, length: number, width: number, color: any)
	local point, normal = cast(shape, origin, direction.Unit)
	assert(point and normal, "stripe ray missed the shape")
	local d = (toward - normal * toward:Dot(normal)).Unit
	local across = normal:Cross(d)
	local base = point + normal * 0.035
	local reach = length
	for _ = 1, 8 do
		local tip = base + d * reach
		local hit = cast(shape, tip + normal * 0.6, -normal)
		if hit and (tip - hit):Dot(normal) < 0.07 then
			break
		end
		reach *= 0.85
	end
	return b:Tri(name, base, base + across * width, base + d * reach, color, THIN)
end

--[[
	Light pyramid from `base` to `tip` whose bulk lies on the `down` side of the base-tip edge: its two side faces are
	right-angled triangles (one part each), ~4 parts in all (tufts, locks, crests, small tails). Sink the base.
]]
local function prong(b, name: string, base: Vector3, tip: Vector3, width: number, depth: number, down: Vector3, color: any, opts: any?)
	local d = (tip - base).Unit
	local dn = down - d * down:Dot(d)
	if dn.Magnitude < 1e-3 then
		dn = SIDE - d * d.X
	end
	dn = dn.Unit
	local across = d:Cross(dn) * (width / 2)
	local low = base + dn * depth
	return b:Mesh(name, { base, low + across, low - across, tip }, { { 1, 2, 4 }, { 1, 3, 4 }, { 2, 3, 4 } }, color, opts or THIN)
end

-- Flat right-angled triangle (1 part) from `base` to `tip`, `width` wide at the base, facing `facing` (claws, fins).
local function feather(b, name: string, base: Vector3, tip: Vector3, width: number, facing: Vector3, color: any, opts: any?)
	local axis = tip - base
	local across = axis:Cross(facing)
	if across.Magnitude < 1e-4 then
		across = axis:Cross(UP)
	end
	return b:Tri(name, base, base + across.Unit * width, tip, color, opts or THIN)
end

-- `count` claws (1 part each) spread along `across` around `at`, pointing along `direction`.
local function claws(b, name: string, at: Vector3, direction: Vector3, across: Vector3, count: number, spread: number, size: number, color: any?)
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
	Leg column: a twisted triangular tube through `points` (top first, buried in the body), one radius per point and
	one colour per segment, the last ring on the ground with its front corner pushed out by `toe` (a paw). The sole
	is left open (it lies on the ground). 6 facets per segment (~12 parts).
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
		b:Mesh(name .. i, { r1[1], r1[2], r1[3], r2[1], r2[2], r2[3] }, faces, colors[math.min(i, #colors)], opts or THIN)
	end
end

-- Low foot: a triangle on the ground (toe in front) under an ankle point. 3 visible facets (~6 parts).
local function tetraFoot(b, name: string, center: Vector3, size: Vector3, color: any, opts: any?)
	local h = size / 2
	local y = center.Y - h.Y
	local vertices = {
		V(center.X, y, center.Z - h.Z),
		V(center.X + h.X, y, center.Z + h.Z * 0.6),
		V(center.X - h.X, y, center.Z + h.Z * 0.6),
		V(center.X, center.Y + h.Y, center.Z + h.Z * 0.3),
	}
	return b:Mesh(name, vertices, { { 1, 2, 4 }, { 2, 3, 4 }, { 3, 1, 4 } }, color, opts or THIN)
end

-- Small flat triangle on the front of a shape at (x, y) from its centre, point down (a negative height points
-- it up), lifted `lift` off it: noses, fangs, bangs.
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
local function innerFace(b, name: string, base: Vector3, tip: Vector3, width: number, depth: number, hint: Vector3?, scale: number, color: any)
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

--[[
	Band around a Spike pyramid (nose tips, rings): a slightly wider, steeper pyramid on the same axis that starts at
	fraction t0 of the spike and dives back into it at t1, so only that band shows (6 parts).
]]
local function collar(b, name: string, base: Vector3, tip: Vector3, width: number, depth: number, t0: number, t1: number, color: any, opts: any?, hint: Vector3?)
	local grow = 1.14
	local s0 = 1 - t0
	local t2 = (grow * s0 * t1 - (1 - t1) * t0) / (grow * s0 - (1 - t1))
	local axis = tip - base
	return b:Spike(name, base + axis * t0, base + axis * t2, width * s0 * grow, depth * s0 * grow, color, opts, hint)
end

--[[
	Fluffy tail / lock: a three-sided spindle from `root` through a ring of radius `radius` around `ring` to `tip`
	(the tip may bend away from the root-ring line: a curl). Root half in rootColor, tip half in tipColor, ~12 parts.
	`up` turns the ring (one ridge towards it).
]]
local function plume(b, name: string, root: Vector3, ring: Vector3, tip: Vector3, radius: number, rootColor: any, tipColor: any, up: Vector3?)
	local u, v = LowPoly.Perpendiculars(ring - root, up)
	local vertices = { root, tip }
	for k = 0, 2 do
		local a = k * TAU / 3
		table.insert(vertices, ring + (u * math.cos(a) + v * math.sin(a)) * radius)
	end
	b:Mesh(name, vertices, { { 1, 3, 4 }, { 1, 4, 5 }, { 1, 5, 3 } }, rootColor, THIN)
	return b:Mesh(name .. "Tip", vertices, { { 2, 4, 3 }, { 2, 5, 4 }, { 2, 3, 5 } }, tipColor, THIN)
end

--[[
	Fluffy collar (ruffs, manes): a star-shaped skirt from `apex` (hidden in the neck) down to a zig-zag rim of
	`count` tufts around `center`: tips reach `inner + reach` and fall `drop` (Vector2(front, back): longer and lower
	at the front), notches stay close in. 2 facets per tuft (~4 parts); open underneath (the body fills it).
]]
local function ruff(b, name: string, apex: Vector3, center: Vector3, inner: number, count: number, reach: Vector2, drop: Vector2, color: any, twist: number?)
	local vertices, faces = { apex }, {}
	local points = count * 2
	for k = 0, points - 1 do
		local a = (k + (twist or 0)) * TAU / points
		local front = (1 + math.cos(a)) / 2
		local length = reach.Y + (reach.X - reach.Y) * front
		local fall = drop.Y + (drop.X - drop.Y) * front
		if k % 2 == 1 then
			length, fall = length * 0.3, fall * 0.45
		end
		table.insert(vertices, center + V(math.sin(a), 0, -math.cos(a)) * (inner + length) - V(0, fall, 0))
		table.insert(faces, { 1, k + 2, (k + 1) % points + 2 })
	end
	return b:Mesh(name, vertices, faces, color, THIN)
end

--[[
	Rings of a faceted tube along a curve (rotation-minimising frames, every ring turned half a step so each facet is
	a real triangle). A radius of 0 makes that end a point.
]]
local function tubeRings(points: { Vector3 }, radii: { number }, sides: number, hint: Vector3?)
	local count = #points
	local tangents = {}
	for i = 1, count do
		tangents[i] = (points[math.min(count, i + 1)] - points[math.max(1, i - 1)]).Unit
	end
	local u = hint or UP
	u = u - tangents[1] * u:Dot(tangents[1])
	if u.Magnitude < 1e-3 then
		u = SIDE - tangents[1] * SIDE:Dot(tangents[1])
	end
	local rings = {}
	for i = 1, count do
		local t = tangents[i]
		u = (u - t * u:Dot(t)).Unit
		local v = t:Cross(u)
		local ring = {}
		for k = 0, sides - 1 do
			local a = (k + (i - 1) * 0.5) * TAU / sides
			ring[k + 1] = points[i] + (u * math.cos(a) + v * math.sin(a)) * radii[i]
		end
		rings[i] = { Center = points[i], Radius = radii[i], Ring = ring }
	end
	return rings
end

--[[
	Draws the tube segment between rings i and i + 1 (open at the start: hide it in the previous shape). With
	`overlap`, the segment starts that far back inside the previous one (slightly shrunk), so no gap opens when the
	bone it belongs to turns.
]]
local function tubeSegment(b, name: string, rings, i: number, color: any, opts: any?, overlap: number?)
	local r1, r2 = rings[i], rings[i + 1]
	local sides = #r1.Ring
	local vertices = table.clone(r1.Ring)
	if overlap and i > 1 then
		local back = (rings[i - 1].Center - r1.Center).Unit * overlap
		for k, point in vertices do
			vertices[k] = r1.Center + back + (point - r1.Center) * 0.92
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
	return b:Mesh(name, vertices, faces, color, opts or THIN)
end

-- Flat "Z" (sleep sign) facing the front: top bar, diagonal and bottom bar (6 flat triangles, ~8 parts).
local function zLetter(b, name: string, center: Vector3, size: number, color: any, opts: any?)
	local h, w, t = size / 2, size * 0.42, size * 0.17
	local function p(x: number, y: number): Vector3
		return center + V(x, y, 0)
	end
	b:Tri(name .. "A", p(-w, h), p(w, h), p(-w, h - t), color, opts)
	b:Tri(name .. "B", p(w, h), p(w, h - t), p(-w, h - t), color, opts)
	b:Tri(name .. "C", p(w - t * 1.5, h - t), p(w, h - t), p(-w, -h + t), color, opts)
	b:Tri(name .. "D", p(w, h - t), p(-w + t * 1.5, -h + t), p(-w, -h + t), color, opts)
	b:Tri(name .. "E", p(-w, -h + t), p(w, -h + t), p(-w, -h), color, opts)
	b:Tri(name .. "F", p(w, -h + t), p(w, -h), p(-w, -h), color, opts)
end

-- Dog line -----------------------------------------------------------------------------------------

-- Orange puppy: big head with a cream muzzle and a cream forelock, black tiger stripes along its back, a cream
-- ruff on the chest, short sturdy legs and a cream bushy tail.
Designs["Growlpup"] = function(b)
	-- Body lying along Z: 4-sided with a ridge along the spine, the chest a little higher, cream under the chest.
	local body = lathe(
		b,
		"Body",
		CFrame.new(0, 0.86, 0.4) * SIDEWAYS,
		{ { -0.46, 0.6, 0.52 }, { 0.3, 0.62, 0.55, 0.05 } },
		4,
		V(0, -0.8, 0.1),
		V(0, 0.8, 0.2),
		function(c: Vector3)
			return if c.Z < -0.15 and c.Y < 0.9 then "Belly" else "Body"
		end,
		THIN
	)
	b:SetCore(body)
	-- Black tiger stripes from the spine down the flanks.
	for _, side in { -1, 1 } do
		for index, z in { 0.2, 0.55, 0.88 } do
			stripe(b, "Stripe" .. index .. side, body, V(side * 2, 2.2, z), V(-side, -0.75, 0), V(0, -1, 0.3), 0.55, 0.14, "Extra")
		end
	end
	-- Short sturdy legs narrowing to paws.
	for index, z in { 0.02, 0.84 } do
		b:MirrorBone(if index == 1 then "LegFront" else "LegBack", V(0.3, 0.66, z), { Phase = if index == 1 then 0 else 0.5 }, function()
			column(b, "Leg", { V(0.3, 0.82, z), V(0.33, 0.05, z - 0.06) }, { 0.25, 0.16 }, { "Body" }, 1.75)
		end)
	end
	-- Cream ruff on the chest, longest under the chin.
	ruff(b, "Ruff", V(0, 1.5, -0.3), V(0, 1.12, -0.36), 0.32, 4, V2(0.3, 0.24), V2(0.42, 0.14), "Belly", 0)

	-- Cream bushy tail curling up behind.
	b:Bone("Tail", V(0, 1.05, 1.08), nil, function()
		plume(b, "Tail", V(0, 0.98, 1.02), V(0, 1.62, 1.42), V(0, 2.08, 1.2), 0.36, "Belly", "Belly", BACK)
	end)

	b:Bone("Head", V(0, 1.25, -0.3), nil, function()
		local head = sculpt(b, "Head", V(1.56, 1.38, 1.4), V(0, 1.75, -0.6), nil, "Body", { Deform = domed(0.9, snout(0.2, 0.8, 0.04)) })
		b:Eyes(head, 0.36, 0.14, V(0.36, 0.44, 0.3), DOG_EYE)
		-- Short cream muzzle with a black nose, the open mouth under it.
		local muzzle = b:Spike("Muzzle", V(0, 1.5, -1.0), V(0, 1.44, -1.5), 0.62, 0.46, "Belly", THIN, UP)
		faceTri(b, "Nose", muzzle, 0, 0.1, 0.2, 0.13, "Black", 0.04)
		b:Mouth(head, -0.42, 0.26, true)
		-- Spiky cream forelock on the crown: the middle tuft sweeps up and back, two smaller ones beside it.
		prong(b, "Tuft", V(0, 2.08, -0.6), V(0, 2.82, -0.3), 0.74, 0.5, FRONT, "Belly")
		for _, side in { -1, 1 } do
			prong(b, "TuftSide" .. side, V(side * 0.22, 2.05, -0.55), V(side * 0.5, 2.62, -0.2), 0.5, 0.36, FRONT, "Belly")
		end
		b:MirrorBone("Ear", V(0.48, 2.1, -0.45), nil, function()
			local base, tip = V(0.45, 2.02, -0.45), V(1.02, 2.62, -0.36)
			b:Spike("Ear", base, tip, 0.64, 0.3, "Body", THIN, BACK)
			innerFace(b, "EarInner", base, tip, 0.64, 0.3, BACK, 0.55, "Belly")
		end)
	end)
end

-- Majestic fire hound standing tall: a huge cream mane around the neck and chest, a cream forelock swept back over
-- the head, black tiger stripes, cream feathering on the legs and a big bushy cream tail.
Designs["Blazehound"] = function(b)
	local body = lathe(
		b,
		"Body",
		CFrame.new(0, 1.9, 0.3) * SIDEWAYS,
		{ { -0.62, 0.82, 0.76 }, { 0.38, 0.88, 0.82, 0.08 } },
		4,
		V(0, -1.12, 0.15),
		V(0, 1.02, 0.4),
		"Body",
		THIN
	)
	b:SetCore(body)
	for _, side in { -1, 1 } do
		for index, z in { -0.12, 0.3, 0.72, 1.1 } do
			stripe(b, "Stripe" .. index .. side, body, V(side * 3, 4.2, z), V(-side, -0.7, 0), V(0, -1, 0.25), 0.7, 0.16, "Black")
		end
	end
	-- Neck rising from the chest into the head (hidden by the mane).
	b:Spike("Neck", V(0, 2.1, -0.45), V(0, 3.4, -1.05), 1.0, 0.86, "Body", THIN, FRONT)
	-- Tall sturdy legs narrowing to paws, cream feathering at the back.
	for index, z in { -0.42, 0.98 } do
		b:MirrorBone(if index == 1 then "LegFront" else "LegBack", V(0.46, 1.75, z), { Phase = if index == 1 then 0 else 0.5 }, function()
			column(b, "Leg", { V(0.46, 2.05, z), V(0.49, 0.06, z - 0.08) }, { 0.38, 0.22 }, { "Body" }, 1.75)
			prong(b, "Feather", V(0.48, 1.25, z + 0.14), V(0.52, 0.5, z + 0.48), 0.4, 0.22, FRONT, "Belly")
		end)
	end
	-- Huge cream mane around the neck, longest on the chest, locks hanging down the chest and over the shoulders.
	ruff(b, "Mane", V(0, 3.15, -0.75), V(0, 2.62, -0.62), 0.58, 6, V2(0.66, 0.36), V2(0.8, 0.22), "Belly", 0.5)
	for index, x in { -0.32, 0, 0.32 } do
		local base = V(x * 0.8, 2.6, -1.0 + math.abs(x) * 0.25)
		prong(b, "Chest" .. index, base, base + V(x * 0.4, -1.0, -0.14), 0.6, 0.45, BACK, "Belly")
	end

	-- Big bushy cream tail held up behind: two plumes side by side.
	b:Bone("Tail", V(0, 2.3, 1.32), nil, function()
		plume(b, "Tail", V(0, 2.15, 1.2), V(0.05, 3.0, 1.85), V(0, 3.62, 1.5), 0.62, "Belly", "Belly", BACK)
		plume(b, "Tail2", V(0, 2.2, 1.3), V(-0.18, 2.7, 2.0), V(-0.25, 3.05, 2.05), 0.38, "Belly", "Belly", SIDE)
	end)

	b:Bone("Head", V(0, 3.0, -0.95), nil, function()
		local head = sculpt(b, "Head", V(1.6, 1.42, 1.55), V(0, 3.55, -1.22), nil, "Body", {
			Deform = domed(0.9, snout(0.55, 0.62, 0.08, 0.18)),
			Paint = function(normal: Vector3)
				return if normal.Y < -0.15 and normal.Z < -0.4 and math.abs(normal.X) < 0.6 then "Belly" else nil
			end,
		})
		b:Eyes(head, 0.36, 0.14, V(0.36, 0.4, 0.28), DOG_EYE, "Angry")
		faceTri(b, "Nose", head, 0, -0.2, 0.22, 0.14, "Black", 0.05)
		b:Mouth(head, -0.44, 0.28)
		-- Long cream forelock swept back over the head, and fluffy cream cheeks.
		prong(b, "Crest", V(0, 3.95, -1.6), V(0, 4.6, -0.35), 0.72, 0.5, DOWN, "Belly")
		for _, side in { -1, 1 } do
			prong(b, "Cheek" .. side, V(side * 0.55, 3.35, -1.15), V(side * 1.12, 3.1, -0.85), 0.46, 0.32, BACK, "Belly")
		end
		b:MirrorBone("Ear", V(0.45, 3.95, -1.05), nil, function()
			local base, tip = V(0.44, 3.88, -1.02), V(0.88, 4.7, -0.85)
			b:Spike("Ear", base, tip, 0.64, 0.32, "Body", THIN, BACK)
			innerFace(b, "EarInner", base, tip, 0.64, 0.32, BACK, 0.55, "Belly")
		end)
	end)
end

-- Jackal line --------------------------------------------------------------------------------------

-- Black mask across the eyes: a strip of flat triangles lying on the front of a head between a top and a bottom
-- outline, given from the centre outwards as { x, top, bottom } (mirrored to the left; equal top and bottom make
-- a point), lifted off the head. 2 flat triangles per section.
local function maskStrip(b, name: string, head, stations: { { number } }, lift: number, color: any)
	local list = {}
	for i = #stations, 1, -1 do
		local s = stations[i]
		table.insert(list, { -s[1], s[2], s[3] })
	end
	for i = if stations[1][1] == 0 then 2 else 1, #stations do
		table.insert(list, stations[i])
	end
	local function at(x: number, y: number): Vector3
		return (b:OnSurface(head, x, y) * CFrame.new(0, 0, -lift)).Position
	end
	local tops, bottoms = {}, {}
	for i, s in list do
		tops[i] = at(s[1], s[2])
		bottoms[i] = if math.abs(s[2] - s[3]) < 1e-3 then false else at(s[1], s[3])
	end
	local opts = { Thickness = 0.05 }
	for i = 1, #list - 1 do
		local t1, b1, t2, b2 = tops[i], bottoms[i], tops[i + 1], bottoms[i + 1]
		if b1 and b2 then
			b:Tri(name .. i .. "A", t1, b1, t2, color, opts)
			b:Tri(name .. i .. "B", b1, b2, t2, color, opts)
		elseif b2 then
			b:Tri(name .. i, t1, b2, t2, color, opts)
		elseif b1 then
			b:Tri(name .. i, t1, b1, t2, color, opts)
		end
	end
end

-- Head of the jackal line: a 20-facet lathe, a black mask strip across the eyes reaching back to points on the
-- sides, a pointed muzzle with a black nose, tall ears with black insides. Inside the head bone.
local function jackalHead(b, center: Vector3, s: number, earTip: Vector3, eyeStyle: string?)
	local head = lathe(
		b,
		"Head",
		CFrame.new(center),
		{ { -0.22 * s, 0.84 * s, 0.72 * s }, { 0.24 * s, 0.8 * s, 0.68 * s } },
		5,
		V(0, -0.64 * s, 0.05 * s),
		V(0, 0.7 * s, 0.05 * s),
		"Body",
		THIN
	)
	maskStrip(b, "Mask", head, {
		{ 0, 0.1 * s, -0.12 * s },
		{ 0.3 * s, 0.24 * s, -0.2 * s },
		{ 0.6 * s, 0.2 * s, -0.08 * s },
		{ 0.76 * s, 0.06 * s, 0.06 * s },
	}, 0.04, "Accent")
	b:Eyes(head, 0.32 * s, 0.02 * s, V(0.3, 0.36, 0.26) * s, JACKAL_EYE, eyeStyle)
	local base, tip = center + V(0, -0.22, -0.5) * s, center + V(0, -0.3, -1.0) * s
	b:Spike("Muzzle", base, tip, 0.56 * s, 0.44 * s, "Body", THIN, UP)
	collar(b, "Nose", base, tip, 0.56 * s, 0.44 * s, 0.8, 1.0, "Black", THIN, UP)
	b:MirrorBone("Ear", center + V(0.42, 0.5, 0.05) * s, nil, function()
		local earBase = center + V(0.4, 0.42, 0.05) * s
		b:Spike("Ear", earBase, earTip, 0.66 * s, 0.32 * s, "Body", THIN, BACK)
		innerFace(b, "EarInner", earBase, earTip, 0.66 * s, 0.32 * s, BACK, 0.48, "Accent")
	end)
	return head
end

-- Blue jackal pup standing on two black legs: big head with a black mask across red eyes, tall ears, round fists.
Designs["Pupjack"] = function(b)
	-- Pear-shaped body, black from the waist down (16 facets).
	local body = sculpt(b, "Body", V(1.08, 1.2, 0.9), V(0, 1.2, 0.05), nil, "Body", {
		Detail = 1,
		Deform = function(v: Vector3): Vector3
			return V(v.X * (1 - v.Y * 0.12), v.Y, v.Z)
		end,
		Paint = function(_normal: Vector3, offset: Vector3)
			return if offset.Y < -0.15 then "Accent" else nil
		end,
	})
	b:SetCore(body)
	b:MirrorBone("Leg", V(0.28, 0.85, 0.05), nil, function()
		b:Limb("Leg", V(0.26, 1.0, 0.05), V(0.32, 0.1, 0.0), 0.44, "Accent", { RingAt = 0.35, Thickness = 0.08 })
		tetraFoot(b, "Foot", V(0.32, 0.12, -0.12), V(0.42, 0.24, 0.64), "Accent")
	end)
	b:MirrorBone("Arm", V(0.44, 1.5, 0.02), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.36, 1.58, 0.02), V(0.74, 0.92, -0.2), 0.38, "Body", { RingAt = 0.66, Thickness = 0.06 })
	end)
	b:Bone("Tail", V(0, 0.95, 0.4), nil, function()
		prong(b, "Tail", V(0, 1.0, 0.3), V(0, 0.72, 1.0), 0.42, 0.3, UP, "Body")
	end)
	b:Bone("Head", V(0, 1.72, 0.0), nil, function()
		local head = jackalHead(b, V(0, 2.3, -0.05), 1, V(0.86, 3.65, 0.12))
		b:Mouth(head, -0.42, 0.2)
	end)
end

-- Tall aura warrior jackal: black mask and four black aura locks hanging from the back of the head, cream chest fur
-- with a white spike, black paws with white spikes, blue thighs over black shins, a blue tail and a blue aura.
Designs["Aurajack"] = function(b)
	-- Broad chest over a narrower waist (16 facets), cream fur on the upper front.
	local body = sculpt(b, "Body", V(1.3, 1.55, 0.95), V(0, 2.25, 0.05), nil, "Body", {
		Detail = 1,
		Deform = function(v: Vector3): Vector3
			return V(v.X * (0.86 + v.Y * 0.16), v.Y, v.Z)
		end,
		Paint = function(normal: Vector3, offset: Vector3)
			return if normal.Z < -0.3 and offset.Y > -0.2 then "Belly" else nil
		end,
	})
	b:SetCore(body)
	b:Particles(body, Color3.fromRGB(80, 160, 255), 5, 0.35)
	-- Shaggy cream chest fur sticking out at the sides, and the white chest spike.
	for _, side in { -1, 1 } do
		prong(b, "Fur" .. side, V(side * 0.32, 2.6, -0.28), V(side * 0.78, 2.12, -0.42), 0.5, 0.3, BACK, "Belly")
	end
	prong(b, "ChestSpike", V(0, 2.66, -0.32), V(0, 2.5, -0.92), 0.36, 0.3, DOWN, "White")

	b:MirrorBone("Leg", V(0.3, 1.65, 0.05), nil, function()
		column(b, "Leg", { V(0.28, 1.8, 0.05), V(0.36, 0.95, -0.02), V(0.38, 0.06, -0.06) }, { 0.3, 0.24, 0.16 }, { "Body", "Accent" }, 1.9)
	end)
	b:MirrorBone("Arm", V(0.56, 2.72, 0.02), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.48, 2.82, 0.02), V(0.9, 1.98, -0.2), 0.34, "Body", { RingAt = 0.4, Thickness = 0.06 })
		-- Black paw (a light pyramid) with a white spike on the back of the wrist.
		prong(b, "Paw", V(0.88, 2.08, -0.18), V(0.98, 1.58, -0.36), 0.36, 0.3, BACK, "Accent")
		b:Spike("PawSpike", V(0.9, 1.98, -0.12), V(1.0, 2.0, 0.3), 0.2, 0.05, "White", THIN, SIDE)
	end)
	b:Bone("Tail", V(0, 1.75, 0.35), nil, function()
		prong(b, "Tail", V(0, 1.85, 0.25), V(0, 1.1, 1.15), 0.5, 0.34, UP, "Body")
	end)

	b:Bone("Head", V(0, 2.95, 0.0), nil, function()
		jackalHead(b, V(0, 3.52, -0.05), 0.92, V(0.7, 4.8, 0.15), "Angry")
		-- Four black aura locks hanging from the back of the head.
		b:MirrorBone("EarLock", V(0.22, 3.55, 0.4), { Amp = 0.6 }, function()
			prong(b, "LockA", V(0.2, 3.62, 0.28), V(0.4, 2.7, 0.75), 0.26, 0.12, BACK, "Accent")
			feather(b, "LockB", V(0.3, 3.42, 0.22), V(0.56, 2.6, 0.5), 0.24, SIDE, "Accent")
		end)
	end)
end

-- Glutton line -------------------------------------------------------------------------------------

-- Painter for the faces of the glutton line: cream on the lower front facets.
local function facePaint(normal: Vector3, offset: Vector3): any
	return if normal.Z < -0.3 and offset.Y < 0.15 then "Belly" else nil
end

--[[
	Round foot pointing forwards (-Z): a 5-sided ring around `center` (a flat edge at the bottom) with a short blunt
	point in front (the sole) and a longer one at the back, hidden in the body. size = (width, height, length).
	10 facets (~20 parts). With `padColor`, a pad lies on the sole: a smaller copy of its 5 front facets, lifted off
	them (5 facets, ~10 parts).
]]
local function footPad(b, name: string, center: Vector3, size: Vector3, color: any, padColor: any?)
	local rx, ry = size.X / 2, size.Y / 2 / 0.81
	local front, back = center - V(0, 0, size.Z * 0.38), center + V(0, 0, size.Z * 0.62)
	local ring = {}
	for k = 0, 4 do
		local a = (k + 0.5) * TAU / 5
		ring[k + 1] = center + V(math.sin(a) * rx, -math.cos(a) * ry, 0)
	end
	local vertices = table.clone(ring)
	table.insert(vertices, front)
	table.insert(vertices, back)
	local faces = {}
	for k = 1, 5 do
		local k1 = k % 5 + 1
		table.insert(faces, { k, k1, 6 })
		table.insert(faces, { k1, k, 7 })
	end
	local handle = b:Mesh(name, vertices, faces, color, THIN)
	if padColor then
		local pad = {}
		for k = 1, 5 do
			pad[k] = front + (ring[k] - front) * 0.62 + V(0, 0, -0.035)
		end
		table.insert(pad, front + V(0, 0, -0.035))
		local padFaces = {}
		for k = 1, 5 do
			table.insert(padFaces, { k, k % 5 + 1, 6 })
		end
		b:Mesh(name .. "Pad", pad, padFaces, padColor, THIN)
	end
	return handle
end

-- Little dark glutton: round body with a cream belly, big head with a cream face under a fringe of dark fur,
-- a wide open mouth, small pointed ears, stubby arms and cream feet.
Designs["Munchling"] = function(b)
	local body = sculpt(b, "Body", V(1.95, 1.62, 1.65), V(0, 0.95, 0.05), nil, "Body", {
		Paint = function(normal: Vector3)
			return if normal.Z < -0.45 then "Belly" else nil
		end,
	})
	b:SetCore(body)
	b:MirrorBone("LegFoot", V(0.48, 0.35, -0.1), nil, function()
		footPad(b, "Foot", V(0.5, 0.2, -0.3), V(0.62, 0.4, 0.86), "Belly")
	end)
	b:MirrorBone("Arm", V(0.8, 1.28, -0.1), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.66, 1.36, -0.05), V(1.1, 0.88, -0.35), 0.42, "Body", { RingAt = 0.6, Thickness = 0.06 })
	end)
	b:Bone("Head", V(0, 1.72, -0.05), nil, function()
		local head = sculpt(b, "Head", V(1.8, 1.45, 1.5), V(0, 2.25, -0.1), nil, "Body", { Deform = domed(0.85), Paint = facePaint })
		for index, x in { -0.42, -0.14, 0.14, 0.42 } do
			faceTri(b, "Bang" .. index, head, x, 0.2, 0.34, 0.34, "Body", 0.04)
		end
		b:Eyes(head, 0.33, -0.02, V(0.22, 0.24, 0.22), "Black")
		b:Mouth(head, -0.32, 0.42, true)
		b:MirrorBone("Ear", V(0.5, 2.8, -0.05), nil, function()
			b:Spike("Ear", V(0.48, 2.72, -0.05), V(0.72, 3.25, 0.0), 0.42, 0.32, "Body", THIN, BACK)
		end)
	end)
end

-- Huge sleepy glutton: an enormous round body with a cream belly, a wide head with a cream face, closed eyes and two
-- little fangs, small pointed ears, thick arms with white claws, big cream feet with tan pads, and Zs floating up.
Designs["Snoozor"] = function(b)
	local body = sculpt(b, "Body", V(3.05, 2.7, 2.5), V(0, 1.45, 0.1), nil, "Body", {
		Paint = function(normal: Vector3, offset: Vector3)
			return if normal.Z < -0.35 and offset.Y < 0.75 then "Belly" else nil
		end,
	})
	b:SetCore(body)
	-- Big feet sticking out under the belly, the soles turned to the front: tan pads, three white claws on top.
	b:MirrorBone("LegFoot", V(0.85, 0.6, -0.55), nil, function()
		footPad(b, "Foot", V(0.88, 0.62, -0.95), V(1.0, 1.0, 1.0), "Belly", "Extra")
		claws(b, "Claw", V(0.88, 1.02, -1.15), V(0, 1, -0.45), SIDE, 3, 0.25, 0.3)
	end)
	b:MirrorBone("Arm", V(1.25, 2.1, -0.1), { Phase = 0.5 }, function()
		b:Limb("Arm", V(1.12, 2.22, -0.05), V(1.72, 1.32, -0.45), 0.75, "Body", { RingAt = 0.5, Thickness = 0.08 })
		claws(b, "Claw", V(1.74, 1.3, -0.52), V(0.3, -1, -0.4), BACK, 3, 0.16, 0.26)
	end)
	b:Bone("Head", V(0, 2.6, -0.1), nil, function()
		local head = sculpt(b, "Head", V(2.25, 1.4, 1.75), V(0, 3.08, -0.18), nil, "Body", { Deform = domed(0.75), Paint = facePaint })
		for index, x in { -0.5, -0.17, 0.17, 0.5 } do
			faceTri(b, "Bang" .. index, head, x, 0.2, 0.38, 0.3, "Body", 0.04)
		end
		b:Eyes(head, 0.38, 0.0, V(0.4, 0.3, 0.2), "Black", "Sleepy")
		b:Mouth(head, -0.32, 0.6)
		for _, side in { -1, 1 } do
			faceTri(b, "Fang" .. side, head, side * 0.17, -0.25, 0.12, -0.14, "White", 0.08)
		end
		b:MirrorBone("Ear", V(0.68, 3.6, -0.1), nil, function()
			b:Spike("Ear", V(0.66, 3.52, -0.1), V(0.98, 4.08, -0.05), 0.5, 0.34, "Body", THIN, BACK)
		end)
		-- Zs floating up from the sleeping head.
		b:Bone("FloatZ", V(1.0, 4.4, -0.3), { Role = "Float" }, function()
			zLetter(b, "ZBig", V(1.05, 4.45, -0.3), 0.5, SLEEP, { Neon = true, Thickness = 0.06 })
			zLetter(b, "ZSmall", V(1.55, 4.95, -0.3), 0.32, SLEEP, { Neon = true, Thickness = 0.05 })
		end)
	end)
end

-- Psychic line -------------------------------------------------------------------------------------

-- Tall psychic clone hovering above the ground: broad shoulders over a narrow purple waist, a small head with two
-- blunt horns and a tube to its back, long three-fingered arms around a floating psychic orb, strong thighs, and a long
-- thick purple tail that sways in three parts.
Designs["Psyclone"] = function(b)
	b.Hover = 1.0
	local body = lathe(
		b,
		"Body",
		CFrame.new(0, 2.45, 0.05),
		{ { -0.3, 0.4, 0.34 }, { 0.32, 0.84, 0.46 } },
		5,
		V(0, -0.95, 0.06),
		V(0, 0.68, 0.02),
		function(c: Vector3)
			return if c.Y < 2.25 then "Accent" else "Body"
		end,
		THIN
	)
	b:SetCore(body)

	-- Digitigrade legs: strong thigh forwards, slim shin back to a small pointed foot (they dangle while it hovers).
	b:MirrorBone("Leg", V(0.34, 1.8, 0.05), nil, function()
		b:Limb("Thigh", V(0.28, 2.0, 0.05), V(0.44, 1.02, -0.1), 0.7, "Body", { RingAt = 0.38, Thickness = 0.08 })
		b:Limb("Shin", V(0.44, 1.14, -0.12), V(0.46, 0.3, 0.16), 0.34, "Body", { RingAt = 0.3, Thickness = 0.06 })
		tetraFoot(b, "Foot", V(0.46, 0.16, 0.0), V(0.36, 0.32, 0.64), "Body")
	end)
	-- Long arms reaching forwards around the orb, three flat fingers on a small palm.
	b:MirrorBone("Arm", V(0.68, 2.88, 0.05), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.6, 2.98, 0.05), V(0.9, 1.86, -0.46), 0.36, "Body", { RingAt = 0.28, Thickness = 0.06 })
		local wrist = V(0.88, 1.9, -0.44)
		prong(b, "Hand", wrist, V(0.82, 1.66, -0.72), 0.32, 0.2, BACK, "Body")
		for index, tip in { V(0.66, 1.52, -0.84), V(0.8, 1.46, -0.92), V(0.96, 1.52, -0.86) } do
			feather(b, "Finger" .. index, V(0.82, 1.68, -0.68), tip, 0.1, FRONT, "Body")
		end
	end)

	-- Long thick purple tail: down from the hips, along behind and curling up at the tip.
	local rings = tubeRings({ V(0, 1.72, 0.3), V(0, 1.15, 0.95), V(0.05, 0.95, 1.6), V(0.15, 1.35, 2.1), V(0.2, 2.05, 2.2) }, { 0.36, 0.32, 0.25, 0.16, 0 }, 3, UP)
	b:Bone("Tail", V(0, 1.72, 0.38), { Amp = 0.6 }, function()
		tubeSegment(b, "Tail1", rings, 1, "Accent")
		b:Bone("Tail2", V(0, 1.15, 0.95), { Phase = 0.15 }, function()
			tubeSegment(b, "Tail2", rings, 2, "Accent", nil, 0.12)
			b:Bone("Tail3", V(0.05, 0.95, 1.6), { Phase = 0.3 }, function()
				tubeSegment(b, "Tail3", rings, 3, "Accent", nil, 0.1)
				tubeSegment(b, "Tail4", rings, 4, "Accent")
			end)
		end)
	end)

	-- Psychic orb floating between its hands.
	b:Bone("FloatOrb", V(0, 1.75, -1.05), { Role = "Float" }, function()
		local orb = b:Ball("Orb", V(0.52, 0.52, 0.52), V(0, 1.75, -1.05), nil, PSY_GLOW, { Detail = 0, Neon = true })
		b:Particles(orb, Color3.fromRGB(190, 120, 255), 6, 0.3)
	end)

	b:Bone("Head", V(0, 3.15, 0.0), nil, function()
		local head = sculpt(b, "Head", V(0.84, 0.76, 0.94), V(0, 3.44, -0.1), nil, "Body", { Detail = 1, Deform = snout(0.25, 0.8, 0.02) })
		b:Eyes(head, 0.2, 0.06, V(0.22, 0.2, 0.2), PSY_EYE, "Angry")
		b:MirrorSpike("Horn", V(0.2, 3.64, 0.0), V(0.36, 4.12, 0.2), 0.24, 0.22, "Body", THIN, BACK)
		-- Tube from the back of the skull down to the upper back.
		b:Limb("Tube", V(0, 3.56, 0.2), V(0, 2.92, 0.5), 0.26, "Body", { RingAt = 0.4, Thickness = 0.06 })
	end)
end

-- Tiny pink psychic cat floating in the air: big round head with huge blue eyes, small ears, a little body with tiny
-- arms, dangling hind legs with big feet, and a very long thin tail rising behind it in an S to an oval tip.
Designs["Pinkling"] = function(b)
	b.Hover = 1.6
	local body = sculpt(b, "Body", V(0.86, 1.05, 0.8), V(0, 1.25, 0.08), V(-12, 0, 0), "Body", { Detail = 1 })
	b:SetCore(body)
	b:Particles(body, Color3.fromRGB(255, 190, 230), 3, 0.2)
	b:MirrorBone("Leg", V(0.24, 1.0, 0.1), nil, function()
		b:Limb("Leg", V(0.22, 1.05, 0.1), V(0.34, 0.45, 0.0), 0.32, "Body", { RingAt = 0.3, Thickness = 0.06 })
		b:Limb("Foot", V(0.36, 0.48, 0.14), V(0.38, 0.3, -0.42), 0.34, "Body", { RingAt = 0.42, Thickness = 0.06 })
	end)
	b:MirrorBone("Arm", V(0.3, 1.55, -0.12), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.24, 1.6, -0.1), V(0.62, 1.32, -0.42), 0.22, "Body", { RingAt = 0.6, Thickness = 0.05 })
	end)

	-- Very long thin tail rising behind in an S, bending at three bones, an oval tip.
	local points = { V(0, 1.0, 0.35), V(0, 0.65, 1.0), V(0, 1.1, 1.65), V(0, 2.0, 1.85), V(0, 2.9, 1.55), V(0, 3.3, 1.2) }
	local rings = tubeRings(points, { 0.1, 0.09, 0.08, 0.07, 0.07, 0.06 }, 3, UP)
	b:Bone("Tail", points[1] + V(0, 0, 0.05), nil, function()
		tubeSegment(b, "Tail1", rings, 1, "Body")
		b:Bone("Tail2", points[2], { Phase = 0.15 }, function()
			tubeSegment(b, "Tail2", rings, 2, "Body", nil, 0.06)
			b:Bone("Tail3", points[3], { Phase = 0.3 }, function()
				tubeSegment(b, "Tail3", rings, 3, "Body", nil, 0.06)
				b:Bone("Tail4", points[4], { Phase = 0.45 }, function()
					tubeSegment(b, "Tail4", rings, 4, "Body", nil, 0.06)
					tubeSegment(b, "Tail5", rings, 5, "Body", nil, 0.06)
					sculpt(b, "TailTip", V(0.42, 0.62, 0.42), V(0, 3.45, 1.05), V(-40, 0, 0), "Body", { Detail = 1 })
				end)
			end)
		end)
	end)

	b:Bone("Head", V(0, 1.7, -0.02), nil, function()
		local head = sculpt(b, "Head", V(1.62, 1.4, 1.36), V(0, 2.3, -0.06), nil, "Body", { Deform = domed(0.9, snout(0.14, 0.8, 0.02)) })
		b:Eyes(head, 0.36, 0.06, V(0.42, 0.56, 0.3), MEW_EYE)
		b:Mouth(head, -0.38, 0.24)
		b:MirrorBone("Ear", V(0.48, 2.78, -0.05), nil, function()
			local base, tip = V(0.45, 2.7, -0.05), V(0.86, 3.35, 0.02)
			b:Spike("Ear", base, tip, 0.62, 0.3, "Body", THIN, BACK)
			innerFace(b, "EarInner", base, tip, 0.62, 0.3, BACK, 0.55, "Belly")
		end)
	end)
end

return Designs
