--[[
	Critter designs: Zappip, Voltmouse, Fennix, Moonfox, Quackle, Mystduck, Coinpurr, Regalynx.
	See CritterBuilder for the toolkit. Ground at y = 0, the critter faces -Z.
	Triangle style: every surface is faceted (Ball / Spike / Mesh / Tri...), only the eyes and the mouths
	are round, and every moving part lives in a bone (legs, arms, head, ears, tails).
]]

local V = Vector3.new

local Designs = {}

local TAU = math.pi * 2
local UP = V(0, 1, 0)
local FRONT = V(0, 0, -1)
local BACK = V(0, 0, 1)
local SIDE = V(1, 0, 0)
-- Lathe frame lying along the body (quadrupeds): local +Y = front (-Z), local +Z = up.
local SIDEWAYS = CFrame.Angles(math.rad(-90), 0, 0)
-- Thin plates for flat triangles and small closed shapes (keeps the low-poly edges crisp).
local THIN = { Thickness = 0.06 }

-- Geometry helpers --------------------------------------------------------------------------------

-- Ray / facet intersection (Möller-Trumbore) against a handle's triangles: point and outward normal.
local function cast(handle, origin: Vector3, direction: Vector3): (Vector3?, Vector3?)
	local best, bestTriangle = math.huge, nil
	for _, triangle in handle.Tris do
		local e1, e2 = triangle.B - triangle.A, triangle.C - triangle.A
		local p = direction:Cross(e2)
		local det = e1:Dot(p)
		if math.abs(det) > 1e-9 then
			local inv = 1 / det
			local tv = origin - triangle.A
			local u = tv:Dot(p) * inv
			if u >= 0 and u <= 1 then
				local q = tv:Cross(e1)
				local v = direction:Dot(q) * inv
				if v >= 0 and u + v <= 1 then
					local t = e2:Dot(q) * inv
					if t > 0 and t < best then
						best, bestTriangle = t, triangle
					end
				end
			end
		end
	end
	if not bestTriangle then
		return nil, nil
	end
	local point = origin + direction * best
	local normal = (bestTriangle.B - bestTriangle.A):Cross(bestTriangle.C - bestTriangle.A).Unit
	if (point - (bestTriangle.Inside or handle.Center)):Dot(normal) < 0 then
		normal = -normal
	end
	return point, normal
end

-- Point on the surface of a shape hit by a ray from `origin` along `direction`, lifted `lift` outwards.
local function on(handle, origin: Vector3, direction: Vector3, lift: number?): Vector3
	local point, normal = cast(handle, origin, direction.Unit)
	assert(point and normal, "surface ray missed the shape")
	return point + normal * (lift or 0)
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

--[[
	Flat triangle lying on the face of a Spike pyramid opposite its ridge (inner ears): the face
	(left, right, tip) shrunk by `scale` towards its centre and lifted `lift` off it.
]]
local function innerFace(
	b,
	name: string,
	base: Vector3,
	tip: Vector3,
	width: number,
	depth: number,
	hint: Vector3?,
	scale: number,
	color: any,
	lift: number?
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
	local offset = normal * (lift or 0.035)
	local function shrink(point: Vector3): Vector3
		return centre + (point - centre) * scale + offset
	end
	return b:Tri(name, shrink(left), shrink(right), shrink(tip), color, THIN)
end

--[[
	Band around a Spike pyramid (rings on ears, legs, tails): a slightly wider, steeper pyramid on the
	same axis that starts at fraction t0 of the spike and dives back into it at t1, so only that band
	shows. Costs one pyramid (6 parts).
]]
local function collar(
	b,
	name: string,
	base: Vector3,
	tip: Vector3,
	width: number,
	depth: number,
	t0: number,
	t1: number,
	color: any,
	opts: any?,
	hint: Vector3?
)
	local grow = 1.14
	local s0 = 1 - t0
	local t2 = (grow * s0 * t1 - (1 - t1) * t0) / (grow * s0 - (1 - t1))
	local axis = tip - base
	return b:Spike(name, base + axis * t0, base + axis * t2, width * s0 * grow, depth * s0 * grow, color, opts, hint)
end

--[[
	Closed paw / foot: a ring of 3 points (toe in front, two heel corners) at `ringAt` of its height,
	an ankle point on top (set back a little) and a sole point below. 6 facets (~12 parts).
]]
local function bean(b, name: string, center: Vector3, size: Vector3, color: any, opts: any?, ringAt: number?)
	local h = size / 2
	local y = center.Y - h.Y + size.Y * (ringAt or 0.35)
	local vertices = {
		V(center.X, y, center.Z - h.Z),
		V(center.X + h.X, y, center.Z + h.Z * 0.55),
		V(center.X - h.X, y, center.Z + h.Z * 0.55),
		V(center.X, center.Y + h.Y, center.Z + h.Z * 0.25),
		V(center.X, center.Y - h.Y, center.Z),
	}
	local faces = { { 1, 2, 4 }, { 2, 3, 4 }, { 3, 1, 4 }, { 2, 1, 5 }, { 3, 2, 5 }, { 1, 3, 5 } }
	return b:Mesh(name, vertices, faces, color, opts)
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
	return b:Mesh(name, vertices, { { 1, 2, 4 }, { 2, 3, 4 }, { 3, 1, 4 } }, color, opts)
end

--[[
	Rings of a faceted tube along a curve (rotation-minimising frames, every ring turned half a step so
	each facet is a real triangle). A radius of 0 makes that end a point.
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

-- Draws the tube segment between rings i and i + 1 (open at the start: hide it in the previous shape).
local function tubeSegment(b, name: string, rings, i: number, color: any, opts: any?)
	local r1, r2 = rings[i], rings[i + 1]
	local sides = #r1.Ring
	local vertices = table.clone(r1.Ring)
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
	return b:Mesh(name, vertices, faces, color, opts)
end

--[[
	Duck bill pointing forwards (-Z) from `back` (sink it in the head): a wide hexagonal rim with a
	raised ridge on top and a shallow keel below. `droop` lowers the front. 12 facets (~24 parts).
]]
local function bill(
	b,
	name: string,
	back: Vector3,
	width: number,
	length: number,
	height: number,
	color: any,
	droop: number?,
	frontWidth: number?
)
	local w, l, d = width / 2, length, droop or 0
	local fw = w * (frontWidth or 0.62)
	local vertices = {
		back + V(-w * 0.75, 0, 0),
		back + V(-w, -d * 0.45, -l * 0.5),
		back + V(-fw, -d, -l),
		back + V(fw, -d, -l),
		back + V(w, -d * 0.45, -l * 0.5),
		back + V(w * 0.75, 0, 0),
		back + V(0, height * 0.62, -l * 0.3),
		back + V(0, -height * 0.38 - d * 0.4, -l * 0.42),
	}
	local faces = {}
	for i = 1, 6 do
		table.insert(faces, { i, i % 6 + 1, 7 })
		table.insert(faces, { i % 6 + 1, i, 8 })
	end
	return b:Mesh(name, vertices, faces, color)
end

-- Faceted coin / gem on the front of a shape: a fan of `sides` triangles around a raised centre.
-- radius: a number, or Vector2(width, height) / 2 for an oval.
local function disc(
	b,
	name: string,
	shape,
	x: number,
	y: number,
	radius: number | Vector2,
	sides: number,
	raise: number,
	lift: number,
	color: any,
	opts: any?
)
	local frame = b:OnSurface(shape, x, y) * CFrame.new(0, 0, -lift)
	local rx = if type(radius) == "number" then radius else radius.X
	local ry = if type(radius) == "number" then radius else radius.Y
	local vertices = {}
	for k = 0, sides - 1 do
		local a = (k + 0.5) * TAU / sides
		table.insert(vertices, (frame * CFrame.new(math.sin(a) * rx, math.cos(a) * ry, 0)).Position)
	end
	table.insert(vertices, (frame * CFrame.new(0, 0, -raise)).Position)
	local faces = {}
	for k = 1, sides do
		table.insert(faces, { k, k % sides + 1, sides + 1 })
	end
	return b:Mesh(name, vertices, faces, color, opts)
end

--[[
	Mesh whose facets can have different colours: `color` is a colour, or function(faceCentre) -> colour key
	(e.g. a cream belly on the lower front facets). One Mesh per colour, all sharing the full vertex list (so the
	plates keep the same inside point), returned as ONE handle holding every facet for the face helpers.
]]
local function paintedMesh(b, name: string, vertices: { Vector3 }, faces: { { number } }, color: any, opts: any?)
	if type(color) ~= "function" then
		return b:Mesh(name, vertices, faces, color, opts)
	end
	local groups, order = {}, {}
	for _, face in faces do
		local paint = color((vertices[face[1]] + vertices[face[2]] + vertices[face[3]]) / 3)
		if not groups[paint] then
			groups[paint] = {}
			table.insert(order, paint)
		end
		table.insert(groups[paint], face)
	end
	local merged
	for index, paint in order do
		local handle = b:Mesh(if index == 1 then name else name .. paint, vertices, groups[paint], paint, opts)
		if merged then
			table.move(handle.Tris, 1, #handle.Tris, #merged.Tris + 1, merged.Tris)
		else
			merged = { Part = handle.Part, Center = handle.Center, Size = handle.Size, Tris = table.clone(handle.Tris) }
		end
	end
	return merged
end

-- Low-poly icosahedron ellipsoid (same as Ball Detail 2: a vertex on top, an upper vertex facing the front) whose
-- facets can be painted (see paintedMesh). ~40 parts.
local function ico(b, name: string, size: Vector3, position: Vector3, rot: Vector3?, color: any, opts: any?)
	local frame = CFrame.new(position) * (if rot then CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z)) else CFrame.identity)
	local half = size / 2
	local ringY, ringR = 1 / math.sqrt(5), 2 / math.sqrt(5)
	local unit = { V(0, 1, 0) }
	for i = 0, 4 do
		table.insert(unit, V(math.sin(i * TAU / 5) * ringR, ringY, -math.cos(i * TAU / 5) * ringR))
	end
	for i = 0, 4 do
		table.insert(unit, V(math.sin((i + 0.5) * TAU / 5) * ringR, -ringY, -math.cos((i + 0.5) * TAU / 5) * ringR))
	end
	table.insert(unit, V(0, -1, 0))
	local vertices = {}
	for index, v in unit do
		vertices[index] = frame:PointToWorldSpace(v * half)
	end
	local faces = {}
	for i = 0, 4 do
		local u1, u2 = 2 + i, 2 + (i + 1) % 5
		local l1, l2 = 7 + i, 7 + (i + 1) % 5
		table.insert(faces, { 1, u1, u2 })
		table.insert(faces, { u1, l1, u2 })
		table.insert(faces, { u2, l1, l2 })
		table.insert(faces, { 12, l2, l1 })
	end
	return paintedMesh(b, name, vertices, faces, color, opts)
end

--[[
	Closed faceted solid around the local Y axis of `frame` (bodies, heads): rings { y, rx, rz?, dz? } listed from
	the bottom up, `sides` vertices per ring, each ring turned half a step from the one below so every facet is a
	triangle (antiprism), pointed ends at the local points `bottom` / `top` (nil leaves that end open: only when it
	is buried in another shape). The first vertex of the first ring faces the front (-Z). `color` may be a paint
	function (see paintedMesh). Cost: 2 * sides * (#rings - 1) triangles + sides per closed end, ~2 parts each.
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
	return paintedMesh(b, name, vertices, faces, color, opts)
end

--[[
	Webbed foot lying on the ground: an ankle point over a fan of 6 facets reaching a heel and three toes with
	notches between them. The flat sole is left open (it sits on the ground). ~12 parts.
]]
local function webFoot(b, name: string, ankle: Vector3, center: Vector3, size: Vector3, color: any, opts: any?)
	local w, l, y = size.X / 2, size.Z / 2, center.Y
	local c = V(center.X, y, center.Z)
	local heel, outer, middle, inner = c + V(0, 0.03, l * 0.75), c + V(w, 0, -l * 0.55), c + V(0, 0, -l), c + V(-w, 0, -l * 0.55)
	local notchA, notchB = c + V(w * 0.42, 0.02, -l * 0.5), c + V(-w * 0.42, 0.02, -l * 0.5)
	local vertices = { ankle, heel, outer, notchA, middle, notchB, inner }
	local faces = { { 1, 2, 3 }, { 1, 3, 4 }, { 1, 4, 5 }, { 1, 5, 6 }, { 1, 6, 7 }, { 1, 7, 2 } }
	return b:Mesh(name, vertices, faces, color, opts)
end

--[[
	Fluffy collar (ruffs, manes): a star-shaped skirt from `apex` (hidden in the neck) down to a zig-zag rim of
	`count` tufts around `center`: tips reach `inner + reach` and fall `drop` (Vector2(front, back): longer and lower
	at the front), notches stay close in. 2 facets per tuft (~4 parts); open underneath (the body fills it).
]]
local function ruff(
	b,
	name: string,
	apex: Vector3,
	center: Vector3,
	inner: number,
	count: number,
	reach: Vector2,
	drop: Vector2,
	color: any,
	twist: number?
)
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
	Leg column: a twisted triangular tube through `points` (top first, buried in the body), one radius per point
	and one colour per segment (a colour or { colour, opts }), standing on a triangular sole whose front corner is
	pushed out by `toe` (the paw), or ending in a point when the last radius is 0. 6 facets per segment + the sole
	(~12 parts per segment).
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
		local pointed = radii[i + 1] <= 1e-4
		local faces = {}
		for k = 1, 3 do
			local k1 = k % 3 + 1
			table.insert(faces, { k, k1, k + 3 })
			if not pointed then
				table.insert(faces, { k + 3, k1, k1 + 3 })
			end
		end
		if i == n - 1 and not pointed then
			table.insert(faces, { 4, 5, 6 })
		end
		local paint = colors[math.min(i, #colors)]
		local color, options = paint, opts
		if type(paint) == "table" then
			color, options = paint[1], paint[2]
		end
		b:Mesh(name .. i, { r1[1], r1[2], r1[3], r2[1], r2[2], r2[3] }, faces, color, options)
	end
end

--[[
	Faceted ring lying on the front of a shape (forehead rings, coin rims): `sides` segments between two outlines
	of radius rOuter / rInner around (x, y), every point cast onto the shape and lifted `lift` off it.
	2 flat triangles per segment (not inside a MirrorBone: the points are already in actual space).
]]
local function ringPatch(
	b,
	name: string,
	shape,
	x: number,
	y: number,
	rOuter: number,
	rInner: number,
	sides: number,
	lift: number,
	color: any,
	opts: any?
)
	local outer, inner = {}, {}
	for k = 0, sides - 1 do
		local a = k * TAU / sides
		local function point(r: number): Vector3
			return (b:OnSurface(shape, x + math.sin(a) * r, y + math.cos(a) * r) * CFrame.new(0, 0, -lift)).Position
		end
		outer[k], inner[k] = point(rOuter), point(rInner)
	end
	local options = table.clone(opts or {})
	options.Thickness = options.Thickness or 0.05
	for k = 0, sides - 1 do
		local k1 = (k + 1) % sides
		b:Tri(name .. k .. "A", outer[k], outer[k1], inner[k], color, options)
		b:Tri(name .. k .. "B", inner[k], outer[k1], inner[k1], color, options)
	end
end

-- Small flat triangle on the front of a shape at (x, y), point down, lifted `lift` off it: noses, fangs.
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

-- Flat ribbon through stations { left, right } (lightning tails): two triangles per section.
local function ribbon(b, name: string, stations: { { Vector3 } }, colors: { any }, thickness: number)
	for i = 1, #stations - 1 do
		local l1, r1 = stations[i][1], stations[i][2]
		local l2, r2 = stations[i + 1][1], stations[i + 1][2]
		local color = colors[math.min(i, #colors)]
		b:Tri(name .. i .. "A", l1, r1, r2, color, { Thickness = thickness })
		b:Tri(name .. i .. "B", l1, r2, l2, color, { Thickness = thickness })
	end
end

-- Mouse line --------------------------------------------------------------------------------------

-- Electric mouse: long black-tipped ears, red cheeks, brown back stripes and a zig-zag lightning tail.
Designs["Zappip"] = function(b)
	local body = b:Ball("Body", V(1.8, 1.7, 1.55), V(0, 1.02, 0.05), nil, "Body")
	b:SetCore(body)
	-- Two brown stripes lying on the back (corners cast onto the facets from behind).
	for index, spec in { { 1.52, 0.36 }, { 1.12, 0.42 } } do
		local y, w = spec[1], spec[2]
		local left = on(body, V(-w, y, 4), FRONT, 0.04)
		local right = on(body, V(w, y, 4), FRONT, 0.04)
		local low = on(body, V(0, y - 0.28, 4), FRONT, 0.05)
		b:Tri("Stripe" .. index, left, right, low, "Extra", THIN)
	end

	b:MirrorBone("LegFoot", V(0.45, 0.5, -0.1), nil, function()
		bean(b, "Foot", V(0.45, 0.2, -0.35), V(0.62, 0.4, 0.95), "Body", THIN, 0.3)
	end)
	b:MirrorBone("Arm", V(0.48, 1.48, -0.5), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.42, 1.6, -0.35), V(0.82, 1.02, -0.8), 0.36, "Body", { RingAt = 0.6, Thickness = 0.06 })
	end)

	b:Bone("Head", V(0, 1.85, -0.05), nil, function()
		local head = b:Ball("Head", V(2.05, 1.75, 1.65), V(0, 2.6, -0.2), nil, "Body")
		b:Eyes(head, 0.45, 0.12, V(0.4, 0.46, 0.3), "Black")
		b:Cheeks(head, 0.6, -0.32, 0.5)
		b:Mouth(head, -0.36, 0.34, true)
		faceTri(b, "Nose", head, 0, -0.06, 0.12, 0.08, "Black")
		-- Long pointed ears with black tips (pyramids sunk into the head).
		b:MirrorBone("Ear", V(0.55, 3.25, -0.15), nil, function()
			b:Spike("Ear", V(0.5, 3.15, -0.15), V(1.12, 4.55, -0.05), 0.62, 0.36, "Body", THIN)
			b:Spike("EarTip", V(0.98, 4.2, -0.075), V(1.17, 4.68, -0.04), 0.33, 0.24, "Accent", THIN)
		end)
	end)

	-- Zig-zag lightning tail: a flat ribbon, brown at the base.
	b:Bone("Tail", V(0, 0.85, 0.6), nil, function()
		local function p(y: number, z: number): Vector3
			return V(0, y, z)
		end
		ribbon(b, "Tail", {
			{ p(0.85, 0.48), p(0.6, 0.62) },
			{ p(1.42, 0.98), p(1.17, 1.12) },
			{ p(1.34, 1.38), p(1.04, 1.44) },
			{ p(2.12, 1.96), p(1.74, 2.2) },
			{ p(2.02, 2.38), p(1.62, 2.44) },
		}, { "Extra", "Body", "Body", "Body" }, 0.16)
		b:Tri("TailTipA", p(2.02, 2.38), p(3.1, 2.25), p(1.62, 2.44), "Body", { Thickness = 0.16 })
		b:Tri("TailTipB", p(3.1, 2.25), p(2.72, 3.0), p(1.62, 2.44), "Body", { Thickness = 0.16 })
	end)
end

-- Bigger orange mouse: cream belly, yellow cheeks with fur tufts, huge brown ears with yellow insides curling out
-- at the tips, a long thin black tail ending in a yellow lightning bolt.
Designs["Voltmouse"] = function(b)
	local center = V(0, 1.2, 0.05)
	local body = ico(b, "Body", V(2.2, 2.1, 1.9), center, nil, function(c: Vector3)
		return if c.Z < center.Z - 0.3 and math.abs(c.Y - center.Y) < 0.45 then "Belly" else "Body"
	end)
	b:SetCore(body)
	b:MirrorBone("LegFoot", V(0.52, 0.55, -0.1), nil, function()
		bean(b, "Foot", V(0.55, 0.22, -0.45), V(0.75, 0.44, 1.15), "Body", THIN, 0.3)
	end)
	b:MirrorBone("Arm", V(0.62, 1.72, -0.45), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.47, 1.9, -0.38), V(0.95, 1.2, -0.92), 0.38, "Body", { RingAt = 0.6, Thickness = 0.06 })
	end)

	-- Long thin black tail (two bones so it whips) ending in a zig-zag yellow bolt.
	local rings = tubeRings({ V(0, 0.8, 0.55), V(0, 0.42, 1.45), V(0, 1.15, 2.3), V(0, 2.15, 2.5) }, { 0, 0.12, 0.1, 0.08 }, 3, UP)
	b:Bone("Tail", V(0, 0.8, 0.7), nil, function()
		tubeSegment(b, "Tail1", rings, 1, "Accent", THIN)
		b:Bone("Tail2", V(0, 0.42, 1.45), nil, function()
			tubeSegment(b, "Tail2", rings, 2, "Accent", THIN)
			tubeSegment(b, "Tail3", rings, 3, "Accent", THIN)
			local function p(y: number, z: number): Vector3
				return V(0, 2.1 + y * 1.4, 2.5 + z * 1.4)
			end
			ribbon(b, "Bolt", {
				{ p(0, -0.1), p(-0.05, 0.12) },
				{ p(0.42, 0.18), p(0.28, 0.34) },
				{ p(0.4, 0.38), p(0.24, 0.5) },
			}, { "Extra" }, 0.12)
			b:Tri("BoltTip", p(0.4, 0.38), p(1.0, 0.72), p(0.24, 0.5), "Extra", { Thickness = 0.12 })
		end)
	end)

	b:Bone("Head", V(0, 2.1, -0.1), nil, function()
		local head = b:Ball("Head", V(2.15, 1.9, 1.75), V(0, 3.0, -0.2), nil, "Body")
		b:Eyes(head, 0.44, 0.12, V(0.42, 0.48, 0.3), "Black")
		b:Cheeks(head, 0.6, -0.34, 0.5, "Extra")
		b:Mouth(head, -0.4, 0.38, true)
		faceTri(b, "Nose", head, 0, -0.1, 0.12, 0.08, "Black")
		-- Fur tufts sticking out under the cheeks.
		b:MirrorSpike("Tuft", V(0.86, 2.8, -0.42), V(1.3, 2.5, -0.48), 0.28, 0.06, "Body")
		b:MirrorBone("Ear", V(0.6, 3.6, -0.15), nil, function()
			local base, tip = V(0.55, 3.5, -0.15), V(1.55, 4.95, 0.0)
			b:Spike("Ear", base, tip, 1.0, 0.42, "Accent", THIN, BACK)
			innerFace(b, "EarInner", base, tip, 1.0, 0.42, BACK, 0.68, "Extra")
			b:Spike("EarCurl", V(1.4, 4.75, -0.02), V(1.9, 4.55, 0.02), 0.32, 0.05, "Accent", THIN)
		end)
	end)
end

-- Fox line ---------------------------------------------------------------------------------------

-- Fluffy brown fox: huge ears, big brown eyes, a cream ruff all around the neck and a bushy cream-tipped tail.
Designs["Fennix"] = function(b)
	local body = lathe(
		b,
		"Body",
		CFrame.new(0, 0.95, 0.4) * SIDEWAYS,
		{ { -0.5, 0.6, 0.52 }, { 0.35, 0.62, 0.56, 0.05 } },
		4,
		V(0, -0.95, 0.05),
		V(0, 0.85, 0.3),
		"Body",
		nil,
		0.5
	)
	b:SetCore(body)
	for index, z in { -0.12, 0.85 } do
		b:MirrorBone(if index == 1 then "LegFront" else "LegBack", V(0.3, 0.8, z), { Phase = if index == 1 then 0 else 0.5 }, function()
			column(b, "Leg", { V(0.3, 0.9, z), V(0.33, 0, z - 0.06) }, { 0.22, 0.13 }, { "Body" }, 1.7, THIN)
		end)
	end
	-- Cream ruff all around the neck: a star of tufts, longest under the chin.
	ruff(b, "Ruff", V(0, 1.85, -0.42), V(0, 1.5, -0.36), 0.42, 5, Vector2.new(0.62, 0.42), Vector2.new(0.6, 0.28), "Belly")

	-- Bushy tail curling up: a twisted triangular tube, cream tip.
	local rings = tubeRings({ V(0, 1.05, 0.95), V(0, 1.75, 1.5), V(0, 2.4, 1.62), V(0, 2.9, 1.42) }, { 0, 0.5, 0.42, 0 }, 3, UP)
	b:Bone("Tail", V(0, 1.15, 1.1), nil, function()
		tubeSegment(b, "Tail1", rings, 1, "Body", THIN)
		tubeSegment(b, "Tail2", rings, 2, "Body", THIN)
		tubeSegment(b, "TailTip", rings, 3, "Belly", THIN)
	end)

	b:Bone("Head", V(0, 1.45, -0.4), nil, function()
		local head = b:Ball("Head", V(1.75, 1.5, 1.5), V(0, 2.05, -0.5), nil, "Body")
		b:Eyes(head, 0.4, 0.05, V(0.42, 0.52, 0.3), Color3.fromRGB(95, 55, 30))
		faceTri(b, "Nose", head, 0, -0.2, 0.18, 0.11, "Black")
		b:Mouth(head, -0.38, 0.3)
		b:MirrorBone("Ear", V(0.45, 2.5, -0.5), nil, function()
			local base, tip = V(0.42, 2.4, -0.5), V(1.3, 3.65, -0.35)
			b:Spike("Ear", base, tip, 0.88, 0.34, "Body", THIN, BACK)
			innerFace(b, "EarInner", base, tip, 0.88, 0.34, BACK, 0.62, "Accent")
		end)
	end)
end

-- Sleek black night fox: long banded ears, red eyes, a glowing ring on the forehead, gold bands on legs and tail.
Designs["Moonfox"] = function(b)
	local glow = { Neon = true, Thickness = 0.06 }
	local body = lathe(
		b,
		"Body",
		CFrame.new(0, 1.75, 0.3) * SIDEWAYS,
		{ { -0.62, 0.55, 0.5, 0.04 }, { -0.05, 0.46, 0.42, 0.06 }, { 0.42, 0.58, 0.56, 0.1 } },
		5,
		V(0, -1.18, 0.08),
		V(0, 1.0, 0.9),
		"Body"
	)
	b:SetCore(body)
	for index, z in { -0.35, 0.95 } do
		b:MirrorBone(if index == 1 then "LegFront" else "LegBack", V(0.28, 1.6, z), { Phase = if index == 1 then 0 else 0.5 }, function()
			-- The gold top segment is buried in the body: only a band shows under it.
			column(
				b,
				"Leg",
				{ V(0.27, 1.8, z), V(0.29, 1.36, z - 0.02), V(0.32, 0, z - 0.08) },
				{ 0.12, 0.19, 0 },
				{ { "Accent", glow }, "Body" },
				nil,
				THIN
			)
		end)
	end
	b:Bone("Tail", V(0, 1.95, 1.3), nil, function()
		local base, tip = V(0, 1.85, 1.15), V(0, 3.35, 2.3)
		b:Spike("Tail", base, tip, 0.62, 0.5, "Body", THIN, BACK)
		collar(b, "TailRing", base, tip, 0.62, 0.5, 0.42, 0.56, "Accent", glow, BACK)
	end)

	b:Bone("Head", V(0, 2.35, -0.7), nil, function()
		local head = b:Ball("Head", V(1.5, 1.35, 1.45), V(0, 2.95, -0.95), nil, "Body")
		b:Spike("Muzzle", V(0, 2.75, -1.25), V(0, 2.62, -1.95), 0.6, 0.45, "Body", THIN, UP)
		b:Eyes(head, 0.36, 0.1, V(0.36, 0.4, 0.3), Color3.fromRGB(220, 30, 40))
		ringPatch(b, "ForeheadRing", head, 0, 0.42, 0.2, 0.12, 5, 0.03, "Accent", glow)
		b:MirrorBone("Ear", V(0.4, 3.25, -0.9), nil, function()
			local base, tip = V(0.36, 3.15, -0.9), V(0.98, 4.65, -0.72)
			b:Spike("Ear", base, tip, 0.66, 0.38, "Body", THIN, BACK)
			collar(b, "EarRing", base, tip, 0.66, 0.38, 0.42, 0.56, "Accent", glow, BACK)
		end)
	end)
end

-- Duck line --------------------------------------------------------------------------------------

-- Confused yellow duck clutching its aching head: pear body, wide flat bill, dazed eyes, three hairs.
Designs["Quackle"] = function(b)
	local body = lathe(
		b,
		"Body",
		CFrame.new(0, 1.0, 0.05),
		{ { -0.6, 0.92, 0.86 }, { -0.05, 1.04, 0.95 }, { 0.48, 0.8, 0.74 } },
		4,
		V(0, -0.88, 0),
		V(0, 0.95, 0),
		"Body"
	)
	b:SetCore(body)
	b:MirrorBone("LegFoot", V(0.48, 0.5, -0.05), nil, function()
		webFoot(b, "Foot", V(0.48, 0.2, -0.12), V(0.5, 0.04, -0.4), V(0.9, 0, 1.1), "Belly", THIN)
	end)
	b:Bone("Tail", V(0, 0.85, 0.8), nil, function()
		b:Spike("Tail", V(0, 0.8, 0.72), V(0, 1.15, 1.35), 0.5, 0.3, "Body", THIN, UP)
	end)
	-- Bent arms, hands pressed on the temples.
	b:MirrorBone("Arm", V(0.66, 1.62, -0.05), { Phase = 0.5, Amp = 0.3 }, function()
		local elbow = V(1.2, 1.92, -0.2)
		b:Limb("Arm", V(0.55, 1.55, -0.02), elbow + V(0.05, -0.02, 0), 0.42, "Body", { RingAt = 0.55, Thickness = 0.06 })
		b:Limb("Hand", elbow + V(0.04, -0.08, 0), V(0.98, 2.95, -0.34), 0.5, "Body", { RingAt = 0.72, Thickness = 0.06 })
	end)

	b:Bone("Head", V(0, 1.9, -0.05), { Amp = 0.5 }, function()
		local head = b:Ball("Head", V(2.2, 1.85, 1.9), V(0, 2.72, -0.1), nil, "Body")
		bill(b, "Bill", V(0, 2.42, -0.7), 1.25, 0.85, 0.38, "Belly", 0.04, 0.85)
		b:Eyes(head, 0.43, 0.28, V(0.6, 0.66, 0.3), "White", "Dazed")
		for index, tip in { V(-0.32, 4.25, 0.02), V(0, 4.38, -0.02), V(0.32, 4.25, 0.02) } do
			b:Blade("Hair" .. index, V(tip.X * 0.25, 3.45, -0.08), tip, 0.12, "Black", { Thickness = 0.08 }, SIDE)
		end
	end)
end

-- Tall blue swimmer duck: V-shaped torso, long cream bill, red forehead gem, swept-back crest, webbed hands.
Designs["Mystduck"] = function(b)
	local body = lathe(
		b,
		"Body",
		CFrame.new(0, 2.15, 0.08),
		{ { -0.55, 0.56, 0.46, 0.02 }, { 0.42, 0.72, 0.58, -0.06 } },
		5,
		V(0, -0.92, 0.04),
		V(0, 0.95, 0),
		"Body"
	)
	b:SetCore(body)
	b:MirrorBone("Leg", V(0.3, 1.6, 0.1), nil, function()
		b:Limb("Leg", V(0.24, 1.85, 0.1), V(0.46, 0.1, -0.02), 0.58, "Body", { RingAt = 0.28, Thickness = 0.08 })
		webFoot(b, "Foot", V(0.46, 0.2, -0.1), V(0.48, 0.04, -0.35), V(0.85, 0, 1.05), "Body", THIN)
	end)
	b:MirrorBone("Arm", V(0.6, 2.62, 0.02), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.48, 2.7, 0.04), V(0.98, 1.62, -0.24), 0.36, "Body", { RingAt = 0.35, Thickness = 0.06 })
		-- Webbed paddle: two facets fanning from the wrist to three finger tips.
		local wrist = V(0.98, 1.72, -0.24)
		b:Mesh(
			"Hand",
			{ wrist, V(0.98, 1.16, -0.58), V(1.14, 1.08, -0.3), V(1.02, 1.18, -0.02) },
			{ { 1, 2, 3 }, { 1, 3, 4 } },
			"Body",
			{ Thickness = 0.1 }
		)
	end)
	b:Bone("Tail", V(0, 1.45, 0.45), nil, function()
		b:Spike("Tail", V(0, 1.5, 0.4), V(0, 0.75, 1.35), 0.55, 0.25, "Body", THIN, UP)
	end)

	b:Bone("Head", V(0, 3.0, -0.02), nil, function()
		local head = b:Ball("Head", V(1.5, 1.32, 1.5), V(0, 3.58, -0.15), nil, "Body")
		bill(b, "Bill", V(0, 3.32, -0.72), 0.76, 1.15, 0.32, "Belly", 0.06, 0.6)
		b:Eyes(head, 0.34, 0.14, V(0.34, 0.38, 0.28), Color3.fromRGB(220, 40, 40))
		disc(b, "Gem", head, 0, 0.42, 0.16, 5, 0.1, 0.03, "Accent", { Neon = true, Thickness = 0.05 })
		-- Swept-back crest.
		b:Spike("Crest", V(0, 4.08, -0.1), V(0, 3.98, 1.1), 0.46, 0.32, "Body", THIN, UP)
		b:Spike("Crest2", V(0, 3.78, 0.1), V(0, 3.5, 0.95), 0.36, 0.24, "Body", THIN, UP)
	end)
end

-- Cat line ---------------------------------------------------------------------------------------

-- Cat standing on two legs: big head with an oval gold coin, black ears, three whiskers a side, fangs and a
-- curly brown-tipped tail.
Designs["Coinpurr"] = function(b)
	local body = lathe(
		b,
		"Body",
		CFrame.new(0, 1.2, 0.05),
		{ { -0.3, 0.6, 0.52 }, { 0.32, 0.5, 0.45 } },
		4,
		V(0, -0.62, 0),
		V(0, 0.72, 0),
		"Body",
		nil,
		0.5
	)
	b:SetCore(body)
	b:MirrorBone("Leg", V(0.28, 0.78, 0.05), nil, function()
		b:Spike("Leg", V(0.27, 0.92, 0.06), V(0.32, 0.1, -0.02), 0.38, 0.34, "Body", THIN)
		tetraFoot(b, "Foot", V(0.33, 0.13, -0.14), V(0.42, 0.26, 0.6), "Accent", THIN)
	end)
	b:MirrorBone("Arm", V(0.42, 1.55, -0.02), { Phase = 0.5 }, function()
		b:Spike("Arm", V(0.36, 1.66, 0.0), V(0.82, 1.05, -0.4), 0.3, 0.26, "Body", THIN, BACK)
	end)
	-- Tail: rises from the back and curls forwards at the top, brown tip.
	local rings = tubeRings({ V(0, 0.95, 0.3), V(0, 0.8, 1.1), V(0, 1.75, 1.42), V(0, 2.3, 1.05) }, { 0, 0.13, 0.11, 0 }, 3, UP)
	b:Bone("Tail", V(0, 0.95, 0.4), nil, function()
		tubeSegment(b, "Tail1", rings, 1, "Body", THIN)
		b:Bone("Tail2", V(0, 0.8, 1.1), nil, function()
			tubeSegment(b, "Tail2", rings, 2, "Body", THIN)
			tubeSegment(b, "TailTip", rings, 3, "Accent", THIN)
		end)
	end)

	b:Bone("Head", V(0, 1.8, -0.05), nil, function()
		local head = b:Ball("Head", V(2.3, 1.8, 1.7), V(0, 2.65, -0.1), nil, "Body")
		disc(b, "Coin", head, 0, 0.5, Vector2.new(0.36, 0.46), 8, 0.16, 0.05, "Gold", { Material = Enum.Material.Foil, Thickness = 0.06 })
		b:Eyes(head, 0.48, 0.02, V(0.4, 0.58, 0.3), "White")
		b:Mouth(head, -0.42, 0.4, true)
		faceTri(b, "Nose", head, 0, -0.2, 0.16, 0.1, "Blush")
		for _, side in { -1, 1 } do
			faceTri(b, "Fang" .. side, head, side * 0.1, -0.4, 0.1, 0.15, "White", 0.13)
		end
		for index, spec in { { 2.6, 2.78 }, { 2.48, 2.5 }, { 2.38, 2.2 } } do
			b:MirrorSpike("Whisker" .. index, V(0.8, spec[1], -0.7), V(1.78, spec[2], -0.74), 0.06, 0.02, "Dark")
		end
		b:MirrorBone("Ear", V(0.6, 3.3, -0.05), nil, function()
			local base, tip = V(0.58, 3.2, -0.02), V(1.08, 4.08, 0.05)
			b:Spike("Ear", base, tip, 0.74, 0.3, "Black", THIN, BACK)
			innerFace(b, "EarInner", base, tip, 0.74, 0.3, BACK, 0.6, "Accent")
		end)
	end)
end

-- Elegant cat on four slender legs: broad head, red forehead jewel, haughty eyes, long whiskers, curled tail.
Designs["Regalynx"] = function(b)
	local body = lathe(
		b,
		"Body",
		CFrame.new(0, 1.55, 0.35) * SIDEWAYS,
		{ { -0.65, 0.5, 0.5 }, { 0.4, 0.55, 0.52, 0.05 } },
		5,
		V(0, -1.2, 0.05),
		V(0, 1.0, 0.7),
		"Body"
	)
	b:SetCore(body)
	for index, z in { -0.35, 1.0 } do
		b:MirrorBone(if index == 1 then "LegFront" else "LegBack", V(0.32, 1.35, z), { Phase = if index == 1 then 0 else 0.5 }, function()
			column(b, "Leg", { V(0.32, 1.5, z), V(0.35, 0, z - 0.06) }, { 0.17, 0.1 }, { "Body" }, 2.0, THIN)
		end)
	end
	-- Long thin tail rising behind, curling forwards at the tip.
	local rings = tubeRings({ V(0, 1.7, 1.05), V(0, 2.1, 1.75), V(0, 2.95, 1.98), V(0, 3.35, 1.55) }, { 0, 0.12, 0.1, 0 }, 3, UP)
	b:Bone("Tail", V(0, 1.75, 1.2), nil, function()
		tubeSegment(b, "Tail1", rings, 1, "Body", THIN)
		b:Bone("Tail2", V(0, 2.1, 1.75), nil, function()
			tubeSegment(b, "Tail2", rings, 2, "Body", THIN)
			tubeSegment(b, "Tail3", rings, 3, "Body", THIN)
		end)
	end)

	b:Bone("Head", V(0, 2.3, -0.7), nil, function()
		local head = b:Ball("Head", V(2.15, 1.4, 1.5), V(0, 2.75, -1.0), nil, "Body")
		-- Puffed cheeks: flat tufts pointing out and down.
		b:MirrorTri("Cheek", V(0.75, 2.85, -1.05), V(0.8, 2.35, -1.25), V(1.3, 2.3, -1.05), "Body", { Thickness = 0.08 })
		disc(b, "Jewel", head, 0, 0.36, 0.22, 6, 0.12, 0.03, "Accent", { Neon = true, Thickness = 0.05 })
		b:Eyes(head, 0.4, 0.05, V(0.36, 0.32, 0.28), Color3.fromRGB(200, 30, 50), "Angry")
		faceTri(b, "Nose", head, 0, -0.28, 0.16, 0.1, "Blush")
		b:Mouth(head, -0.44, 0.3)
		b:MirrorSpike("WhiskerA", V(0.55, 2.55, -1.55), V(1.8, 2.85, -1.5), 0.06, 0.02, "Extra")
		b:MirrorSpike("WhiskerB", V(0.55, 2.45, -1.55), V(1.75, 2.18, -1.4), 0.06, 0.02, "Extra")
		b:MirrorBone("Ear", V(0.55, 3.2, -0.95), nil, function()
			local base, tip = V(0.52, 3.1, -0.93), V(1.08, 4.0, -0.85)
			b:Spike("Ear", base, tip, 0.72, 0.3, "Extra", THIN, BACK)
			innerFace(b, "EarInner", base, tip, 0.72, 0.3, BACK, 0.6, "Blush")
		end)
	end)
end

return Designs
