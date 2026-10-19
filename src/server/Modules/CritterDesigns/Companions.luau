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

-- Ray / facet intersection (Möller-Trumbore) against a handle's triangles: point, outward normal and the facet.
local function cast(handle, origin: Vector3, direction: Vector3): (Vector3?, Vector3?, any)
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
		return nil, nil, nil
	end
	local point = origin + direction * best
	local normal = (bestTriangle.B - bestTriangle.A):Cross(bestTriangle.C - bestTriangle.A).Unit
	if (point - (bestTriangle.Inside or handle.Center)):Dot(normal) < 0 then
		normal = -normal
	end
	return point, normal, bestTriangle
end

--[[
	Stripe lying flat on one facet of a shape (back stripes, markings): the facet hit by a ray from `origin` along
	`direction` is cut by two lines parallel to the edge opposite its vertex furthest along `apexDir`, at fractions
	t0 .. t1 of the way from that edge to the vertex, and lifted off the facet. 2 flat triangles (~4 parts).
]]
local function facetBand(b, name: string, handle, origin: Vector3, direction: Vector3, apexDir: Vector3, t0: number, t1: number, color: any)
	local _, normal, facet = cast(handle, origin, direction.Unit)
	assert(normal and facet, "stripe ray missed the shape")
	local corners = { facet.A, facet.B, facet.C }
	table.sort(corners, function(p: Vector3, q: Vector3): boolean
		return p:Dot(apexDir) > q:Dot(apexDir)
	end)
	local apex, e1, e2 = corners[1], corners[2], corners[3]
	local lift = normal * 0.035
	local function at(edge: Vector3, t: number): Vector3
		return edge + (apex - edge) * t + lift
	end
	b:Tri(name .. "A", at(e1, t0), at(e2, t0), at(e2, t1), color, THIN)
	b:Tri(name .. "B", at(e1, t0), at(e2, t1), at(e1, t1), color, THIN)
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
	Light pyramid from `base` to `tip` whose bulk lies on the `down` side of the base-tip edge: its two side faces are
	right-angled triangles (one part each), ~4 parts in all (crests, tufts, small tails). Sink the base.
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

--[[
	Slim leg from `top` to `bottom`: a spindle whose front edge is straight (on the axis) and whose bulk lies towards
	`back`, widest at `ringAt`. Four of its six faces are right-angled (one part each): ~8 parts (a Limb costs 12).
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

-- Blunt paw: a wide front face (two toe corners on the ground and a knuckle point) over a heel. 3 visible facets
-- (~6 parts), open underneath (it stands on the ground). Hide the leg's lower end in it.
local function paw(b, name: string, center: Vector3, size: Vector3, color: any, opts: any?)
	local h = size / 2
	local y = center.Y - h.Y
	local vertices = {
		V(center.X - h.X, y, center.Z - h.Z),
		V(center.X + h.X, y, center.Z - h.Z),
		V(center.X, y, center.Z + h.Z),
		V(center.X, center.Y + h.Y, center.Z - h.Z * 0.05),
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

-- Faceted coin / gem on the front of a shape: a fan of `sides` triangles around a raised centre (on the centre line it
-- faces straight out of the shape, so it stays symmetric).
-- radius: a number, or Vector2(width, height) / 2 for an oval. tilt (degrees): face this far above straight ahead
-- instead of along the surface (a coin standing up on a sloping forehead).
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
	opts: any?,
	tilt: number?
)
	local frame = b:OnSurface(shape, x, y)
	if tilt then
		local point = frame.Position
		frame = CFrame.lookAt(point, point + FRONT * math.cos(math.rad(tilt)) + UP * math.sin(math.rad(tilt)), UP)
	elseif x == 0 then
		-- On the centre line the ray can land on a facet seam (tilted to one side): face straight out instead.
		local point, half = frame.Position, shape.Size / 2
		local out = V(0, (point.Y - shape.Center.Y) / (half.Y * half.Y), (point.Z - shape.Center.Z) / (half.Z * half.Z))
		frame = CFrame.lookAt(point, point + (out.Unit + FRONT).Unit, UP)
	end
	frame *= CFrame.new(0, 0, -lift)
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
		-- opts may also be function(colour) -> opts (e.g. a glowing band on a dark tail).
		local options = if type(opts) == "function" then opts(paint) else opts
		local handle = b:Mesh(if index == 1 then name else name .. paint, vertices, groups[paint], paint, options)
		if merged then
			table.move(handle.Tris, 1, #handle.Tris, #merged.Tris + 1, merged.Tris)
		else
			merged = { Part = handle.Part, Center = handle.Center, Size = handle.Size, Tris = table.clone(handle.Tris) }
		end
	end
	return merged
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

-- Frame at `base` whose +Y points at `tip` and whose +Z leans towards `back`: a lathe along any axis (tails, plumes).
local function axisFrame(base: Vector3, tip: Vector3, back: Vector3): CFrame
	local y = (tip - base).Unit
	local z = (back - y * back:Dot(y)).Unit
	return CFrame.fromMatrix(base, y:Cross(z), y, z)
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
	(~12 parts per segment). `open` leaves the sole out (it lies on the ground, nobody sees it).
]]
local function column(b, name: string, points: { Vector3 }, radii: { number }, colors: { any }, toe: number?, opts: any?, open: boolean?)
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
		if i == n - 1 and not pointed and not open then
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

-- Whisker: a long thin right-angled triangle (1 part) from `base` to `tip`, `width` wide at the base, seen from the front.
local function whisker(b, name: string, base: Vector3, tip: Vector3, width: number, color: any)
	local across = (tip - base):Cross(FRONT).Unit
	return b:Tri(name, base, base + across * width, tip, color, { Thickness = 0.04 })
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
	-- Pear-shaped body: an icosahedron whose rings sit low and wide (20 facets, like a Ball).
	local body = lathe(
		b,
		"Body",
		CFrame.new(0, 1.0, 0.05),
		{ { -0.3, 0.96, 0.8 }, { 0.38, 0.76, 0.66 } },
		5,
		V(0, -0.86, 0),
		V(0, 1.35, -0.05),
		"Body",
		nil,
		0.5
	)
	b:SetCore(body)
	-- Two brown stripes across the back, lying flat on its facets.
	facetBand(b, "Stripe1", body, V(0, 1.55, 4), FRONT, UP, 0.12, 0.42, "Extra")
	facetBand(b, "Stripe2", body, V(0, 1.2, 4), FRONT, V(0, -1, 0), 0.14, 0.42, "Extra")

	b:MirrorBone("LegFoot", V(0.45, 0.5, -0.1), nil, function()
		prong(b, "Leg", V(0.42, 0.78, -0.15), V(0.46, 0.12, -0.36), 0.34, 0.26, BACK, "Body")
		paw(b, "Foot", V(0.46, 0.14, -0.4), V(0.64, 0.28, 0.9), "Body", THIN)
	end)
	-- Short stubby arms reaching down and forwards from the shoulders, the bulge near the paw.
	b:MirrorBone("Arm", V(0.55, 1.52, -0.3), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.42, 1.62, -0.18), V(0.84, 0.98, -0.66), 0.36, "Body", { RingAt = 0.62, Thickness = 0.06 })
	end)

	b:Bone("Head", V(0, 1.85, -0.05), nil, function()
		-- Wide head, fullest at the cheeks, with a short chin (20 facets).
		local head = lathe(
			b,
			"Head",
			CFrame.new(0, 2.58, -0.2),
			{ { -0.3, 1.06, 0.84 }, { 0.32, 0.94, 0.78 } },
			5,
			V(0, -0.78, 0.05),
			V(0, 0.88, 0.05),
			"Body"
		)
		b:Eyes(head, 0.45, 0.12, V(0.4, 0.46, 0.3), "Black")
		b:Cheeks(head, 0.66, -0.3, 0.5)
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
	-- Chubby pear body with a cream belly diamond (the front facets below the chest).
	local center = V(0, 1.16, 0.05)
	local body = lathe(
		b,
		"Body",
		CFrame.new(center),
		{ { -0.34, 1.16, 0.98 }, { 0.44, 0.9, 0.78 } },
		5,
		V(0, -1.02, 0),
		V(0, 1.55, -0.05),
		function(c: Vector3)
			local angle = math.deg(math.atan2(c.X - center.X, center.Z - c.Z))
			return if math.abs(angle) <= 45 and c.Y < center.Y + 0.4 then "Belly" else "Body"
		end,
		nil,
		0.5
	)
	b:SetCore(body)
	b:MirrorBone("LegFoot", V(0.54, 0.55, -0.1), nil, function()
		prong(b, "Leg", V(0.52, 0.82, -0.15), V(0.58, 0.12, -0.45), 0.4, 0.32, BACK, "Body")
		paw(b, "Foot", V(0.58, 0.15, -0.52), V(0.8, 0.3, 1.15), "Body", THIN)
	end)
	b:MirrorBone("Arm", V(0.64, 1.74, -0.34), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.5, 1.86, -0.2), V(1.0, 1.1, -0.74), 0.42, "Body", { RingAt = 0.62, Thickness = 0.06 })
	end)

	-- Long thin black tail (two bones so it whips) ending in a big yellow lightning bolt.
	local rings = tubeRings({ V(0, 0.8, 0.55), V(0, 0.36, 1.3), V(0, 1.0, 1.95), V(0, 1.9, 2.05) }, { 0, 0.12, 0.1, 0.07 }, 3, UP)
	b:Bone("Tail", V(0, 0.8, 0.7), nil, function()
		tubeSegment(b, "Tail1", rings, 1, "Accent", THIN)
		b:Bone("Tail2", V(0, 0.36, 1.3), nil, function()
			tubeSegment(b, "Tail2", rings, 2, "Accent", THIN)
			tubeSegment(b, "Tail3", rings, 3, "Accent", THIN)
			-- Bolt in the tail's plane, narrow end on the tail tip: two slanted parallelograms (a classic zig-zag).
			local function p(u: number, v: number): Vector3
				return V(0, 1.84 + v * 1.45, 2.05 + (u - 0.3) * 1.45)
			end
			local bolt = { Thickness = 0.12 }
			b:Tri("BoltA", p(0.6, 1.0), p(0.12, 0.42), p(0.45, 0.45), "Extra", bolt)
			b:Tri("BoltB", p(0.6, 1.0), p(0.45, 0.45), p(0.58, 0.6), "Extra", bolt)
			local spark = b:Tri("BoltC", p(0.42, 0.47), p(0.3, 0.0), p(0.88, 0.6), "Extra", bolt)
			b:Particles(spark, Color3.fromRGB(255, 240, 120), 3, 0.12)
			b:Tri("BoltD", p(0.42, 0.47), p(0.88, 0.6), p(0.58, 0.6), "Extra", bolt)
		end)
	end)

	b:Bone("Head", V(0, 2.1, -0.1), nil, function()
		-- Wide head, fullest at the cheeks (like Zappip's, bigger).
		local head = lathe(
			b,
			"Head",
			CFrame.new(0, 2.98, -0.2),
			{ { -0.32, 1.12, 0.9 }, { 0.34, 1.0, 0.82 } },
			5,
			V(0, -0.84, 0.05),
			V(0, 0.95, 0.05),
			"Body"
		)
		b:Eyes(head, 0.46, 0.14, V(0.42, 0.5, 0.3), "Black")
		b:Cheeks(head, 0.6, -0.27, 0.58, "Extra")
		b:Mouth(head, -0.4, 0.38, true)
		faceTri(b, "Nose", head, 0, -0.1, 0.12, 0.08, "Black")
		-- Fur tufts sticking out beside the cheeks.
		b:MirrorSpike("Tuft", V(0.92, 2.7, -0.12), V(1.42, 2.36, -0.2), 0.32, 0.06, "Body")
		b:MirrorBone("Ear", V(0.6, 3.6, -0.15), nil, function()
			local base, tip = V(0.55, 3.5, -0.15), V(1.38, 5.05, 0.0)
			b:Spike("Ear", base, tip, 1.0, 0.42, "Accent", THIN, BACK)
			innerFace(b, "EarInner", base, tip, 1.0, 0.42, BACK, 0.68, "Extra")
			-- The tip curls outwards.
			b:Spike("EarCurl", V(1.24, 4.82, -0.0), V(1.78, 4.7, 0.04), 0.36, 0.05, "Accent", THIN)
		end)
	end)
end

-- Fox line ---------------------------------------------------------------------------------------

-- Fluffy brown fox: huge ears, big brown eyes, a cream ruff all around the neck and a bushy cream-tipped tail.
Designs["Fennix"] = function(b)
	-- Body lying along Z: a 4-sided lathe with a ridge along the spine and the belly.
	local body = lathe(
		b,
		"Body",
		CFrame.new(0, 0.92, 0.4) * SIDEWAYS,
		{ { -0.45, 0.62, 0.58 }, { 0.36, 0.64, 0.6, 0.05 } },
		4,
		V(0, -1.0, 0.05),
		V(0, 0.88, 0.3),
		"Body"
	)
	b:SetCore(body)
	-- Short legs narrowing to a paw (the sole's front corner pushed out as a toe).
	for index, z in { -0.1, 0.85 } do
		b:MirrorBone(if index == 1 then "LegFront" else "LegBack", V(0.3, 0.72, z), { Phase = if index == 1 then 0 else 0.5 }, function()
			column(b, "Leg", { V(0.29, 0.82, z), V(0.33, 0, z - 0.06) }, { 0.23, 0.15 }, { "Body" }, 1.75, THIN, true)
		end)
	end
	-- Cream ruff all around the neck: a star of tufts, longest under the chin.
	ruff(b, "Ruff", V(0, 1.75, -0.42), V(0, 1.4, -0.36), 0.42, 5, Vector2.new(0.66, 0.42), Vector2.new(0.62, 0.28), "Belly", 0)

	-- Big bushy plume of a tail rising behind, curling forwards at the cream tip (16 facets).
	b:Bone("Tail", V(0, 1.15, 1.05), nil, function()
		local base, tip = V(0, 1.0, 0.95), V(0, 3.05, 1.6)
		local axis = (tip - base).Unit
		lathe(
			b,
			"Tail",
			axisFrame(base, tip, BACK),
			{ { 0.62, 0.5, 0.42 }, { 1.42, 0.5, 0.44, -0.08 } },
			4,
			V(0, 0, 0),
			V(0, 2.12, -0.3),
			function(c: Vector3)
				return if (c - base):Dot(axis) > 1.5 then "Belly" else "Body"
			end,
			THIN,
			0.5
		)
	end)

	b:Bone("Head", V(0, 1.35, -0.4), nil, function()
		local head = b:Ball("Head", V(1.8, 1.55, 1.5), V(0, 1.97, -0.5), nil, "Body")
		b:Eyes(head, 0.4, 0.05, V(0.42, 0.52, 0.3), Color3.fromRGB(95, 55, 30))
		faceTri(b, "Nose", head, 0, -0.2, 0.18, 0.11, "Black")
		b:Mouth(head, -0.38, 0.3)
		b:MirrorBone("Ear", V(0.45, 2.42, -0.5), nil, function()
			local base, tip = V(0.42, 2.32, -0.5), V(1.32, 3.6, -0.35)
			b:Spike("Ear", base, tip, 0.88, 0.34, "Body", THIN, BACK)
			innerFace(b, "EarInner", base, tip, 0.88, 0.34, BACK, 0.62, "Accent")
		end)
	end)
end

-- Sleek black night fox: long ears, slender legs and a long tail, each with a glowing gold ring, a gold ring on the
-- forehead, red eyes and a short pointed muzzle.
Designs["Moonfox"] = function(b)
	local glow = { Neon = true, Thickness = 0.06 }
	local function glowing(paint: string)
		return if paint == "Accent" then glow else THIN
	end
	-- Lean black body (16 facets: the facets barely show on black), chest raised.
	local body = b:Ball("Body", V(1.38, 1.34, 2.55), V(0, 1.5, 0.32), V(10, 0, 0), "Body", { Detail = 1 })
	b:SetCore(body)
	-- Faint gold sparkles (moonlight).
	b:Particles(body, Color3.fromRGB(255, 220, 110), 2, 0.14)
	for index, spec in { { -0.46, 0.3 }, { 1.05, 0.32 } } do
		local z, x = spec[1], spec[2]
		b:MirrorBone(if index == 1 then "LegFront" else "LegBack", V(x, 1.3, z), { Phase = if index == 1 then 0 else 0.5 }, function()
			-- Gold pyramid from deep in the body: only the band under the body shows.
			column(
				b,
				"Leg",
				{ V(x, 1.8, z), V(x + 0.01, 0.88, z - 0.02), V(x + 0.03, 0, z - 0.08) },
				{ 0, 0.18, 0.11 },
				{ { "Accent", glow }, "Body" },
				1.9,
				THIN,
				true
			)
		end)
	end

	-- Long tail held up behind: a 16-facet plume (like Fennix's, slimmer) with a glowing gold band around the middle.
	b:Bone("Tail", V(0, 1.75, 1.4), nil, function()
		local base, tip = V(0, 1.62, 1.3), V(0, 3.4, 2.6)
		local axis = (tip - base).Unit
		lathe(
			b,
			"Tail",
			axisFrame(base, tip, BACK),
			{ { 0.8, 0.4, 0.32 }, { 1.3, 0.36, 0.3, -0.04 } },
			4,
			V(0, 0, 0),
			V(0, 2.25, -0.12),
			function(c: Vector3)
				local along = (c - base):Dot(axis)
				return if along > 0.8 and along < 1.3 then "Accent" else "Body"
			end,
			glowing,
			0.5
		)
	end)

	-- Head on a short neck (the lathe's lower point dives into the chest), short pointed muzzle with a black nose.
	b:Bone("Head", V(0, 2.05, -0.75), nil, function()
		local head = lathe(
			b,
			"Head",
			CFrame.new(0, 2.62, -1.0),
			{ { -0.28, 0.86, 0.74 }, { 0.3, 0.8, 0.7 } },
			5,
			V(0, -1.2, 0.6),
			V(0, 0.78, 0.05),
			"Body"
		)
		local snout, tip = V(0, 2.28, -1.22), V(0, 2.2, -1.86)
		b:Spike("Muzzle", snout, tip, 0.86, 0.62, "Body", THIN, UP)
		collar(b, "Nose", snout, tip, 0.86, 0.62, 0.8, 1.0, "Black", THIN, UP)
		b:Eyes(head, 0.36, 0.12, V(0.38, 0.44, 0.3), Color3.fromRGB(220, 30, 40))
		ringPatch(b, "ForeheadRing", head, 0, 0.44, 0.21, 0.12, 5, 0.03, "Accent", glow)
		b:MirrorBone("Ear", V(0.38, 3.02, -0.9), nil, function()
			local base, ear = V(0.36, 2.92, -0.9), V(0.95, 4.55, -0.72)
			b:Spike("Ear", base, ear, 0.72, 0.4, "Body", THIN, BACK)
			collar(b, "EarRing", base, ear, 0.72, 0.4, 0.45, 0.58, "Accent", glow, BACK)
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
		V(0, 1.45, -0.05),
		"Body"
	)
	b:SetCore(body)
	b:MirrorBone("LegFoot", V(0.48, 0.5, -0.05), nil, function()
		prong(b, "Leg", V(0.46, 0.72, -0.06), V(0.48, 0.16, -0.14), 0.3, 0.22, BACK, "Belly")
		webFoot(b, "Foot", V(0.48, 0.2, -0.12), V(0.5, 0.04, -0.4), V(0.9, 0, 1.1), "Belly", THIN)
	end)
	b:Bone("Tail", V(0, 0.85, 0.8), nil, function()
		b:Spike("Tail", V(0, 0.8, 0.72), V(0, 1.15, 1.35), 0.5, 0.3, "Body", THIN, UP)
	end)
	-- Bent arms, hands pressed on the temples.
	b:MirrorBone("Arm", V(0.66, 1.62, -0.05), { Phase = 0.5, Amp = 0.3 }, function()
		local elbow = V(1.2, 1.92, -0.2)
		b:Limb("Arm", V(0.55, 1.55, -0.02), elbow + V(0.05, -0.02, 0), 0.42, "Body", { RingAt = 0.55, Thickness = 0.06 })
		strut(b, "Hand", elbow + V(0.04, -0.08, 0), V(0.98, 2.95, -0.34), 0.5, 0.4, V(0.6, 0, 1), "Body", 0.72)
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

-- Tall blue swimmer duck: V-shaped torso, long cream bill, red forehead gem, swept-back crest, stern red eyes,
-- webbed hands and feet.
Designs["Mystduck"] = function(b)
	local body = lathe(
		b,
		"Body",
		CFrame.new(0, 2.25, 0.05),
		{ { -0.55, 0.5, 0.44, 0.02 }, { 0.4, 0.76, 0.58, -0.05 } },
		5,
		V(0, -1.02, 0.03),
		V(0, 1.12, -0.05),
		"Body"
	)
	b:SetCore(body)
	b:MirrorBone("Leg", V(0.32, 1.55, 0.05), nil, function()
		b:Limb("Leg", V(0.26, 1.85, 0.06), V(0.46, 0.16, 0.0), 0.62, "Body", { RingAt = 0.3, Thickness = 0.08 })
		webFoot(b, "Foot", V(0.46, 0.22, -0.08), V(0.48, 0.03, -0.38), V(0.9, 0, 1.15), "Body", THIN)
	end)
	b:MirrorBone("Arm", V(0.66, 2.78, 0.02), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.52, 2.9, 0.04), V(1.04, 1.74, -0.3), 0.5, "Body", { RingAt = 0.3, Thickness = 0.06 })
		-- Webbed hand: three fingers fanning from the wrist, joined by the web.
		local wrist = V(1.02, 1.84, -0.28)
		b:Mesh(
			"Hand",
			{ wrist, V(0.94, 1.16, -0.66), V(1.18, 1.04, -0.34), V(1.1, 1.18, 0.02) },
			{ { 1, 2, 3 }, { 1, 3, 4 } },
			"Body",
			{ Thickness = 0.12 }
		)
	end)
	b:Bone("Tail", V(0, 1.45, 0.45), nil, function()
		prong(b, "Tail", V(0, 1.6, 0.3), V(0, 0.85, 1.32), 0.62, 0.32, V(0, 1, 0), "Body")
	end)

	b:Bone("Head", V(0, 3.2, -0.02), nil, function()
		-- Round head whose top is swept back into a pointed crest (20 facets, the crest is the top cap).
		local head = lathe(
			b,
			"Head",
			CFrame.new(0, 3.9, -0.12),
			{ { -0.32, 0.88, 0.82 }, { 0.3, 0.8, 0.74, 0.12 } },
			5,
			V(0, -0.78, 0.05),
			V(0, 0.56, 1.35),
			"Body"
		)
		bill(b, "Bill", V(0, 3.56, -0.78), 0.9, 1.3, 0.36, "Belly", 0.08, 0.6)
		b:Eyes(head, 0.38, 0.1, V(0.36, 0.4, 0.28), Color3.fromRGB(220, 40, 40), "Angry")
		local gem = disc(b, "Gem", head, 0, 0.42, 0.19, 6, 0.1, 0.03, "Accent", { Neon = true, Thickness = 0.05 })
		-- The gem glows with psychic power.
		b:Particles(gem, Color3.fromRGB(255, 120, 140), 1.5, 0.1)
	end)
end

-- Cat line ---------------------------------------------------------------------------------------

-- Cat standing on two legs: big head with an oval gold coin, black ears, three whiskers a side, fangs and a
-- curly brown-tipped tail.
Designs["Coinpurr"] = function(b)
	-- Small pear-shaped body standing upright (20 facets).
	local body = lathe(
		b,
		"Body",
		CFrame.new(0, 1.2, 0.05),
		{ { -0.28, 0.64, 0.56 }, { 0.32, 0.5, 0.46 } },
		5,
		V(0, -0.62, 0),
		V(0, 1.05, -0.05),
		"Body"
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
	local rings = tubeRings({ V(0, 0.95, 0.3), V(0, 0.72, 1.12), V(0, 1.95, 1.48), V(0, 2.5, 0.95) }, { 0, 0.13, 0.11, 0 }, 3, UP)
	b:Bone("Tail", V(0, 0.95, 0.4), nil, function()
		tubeSegment(b, "Tail1", rings, 1, "Body", THIN)
		b:Bone("Tail2", V(0, 0.72, 1.12), nil, function()
			tubeSegment(b, "Tail2", rings, 2, "Body", THIN)
			tubeSegment(b, "TailTip", rings, 3, "Accent", THIN)
		end)
	end)

	b:Bone("Head", V(0, 1.8, -0.05), nil, function()
		-- Big round head, widest at the cheeks (20 facets).
		local head = lathe(
			b,
			"Head",
			CFrame.new(0, 2.62, -0.1),
			{ { -0.26, 1.16, 0.84 }, { 0.3, 1.06, 0.8 } },
			5,
			V(0, -0.8, 0.05),
			V(0, 0.86, -0.12),
			"Body"
		)
		-- Oval gold coin: a bright rim around a darker raised centre.
		local foil = { Material = Enum.Material.Foil, Thickness = 0.06 }
		-- It stands up on the sloping forehead (its lower edge sinks in a little), so it reads as a coin from the front.
		disc(b, "Coin", head, 0, 0.44, Vector2.new(0.34, 0.42), 8, 0.04, 0.02, "Gold", foil, 30)
		disc(b, "CoinFace", head, 0, 0.44, Vector2.new(0.19, 0.27), 4, 0.025, 0.05, Color3.fromRGB(225, 160, 30), foil, 30)
		b:Eyes(head, 0.48, 0.02, V(0.4, 0.58, 0.3), "White")
		b:Mouth(head, -0.42, 0.4, true)
		faceTri(b, "Nose", head, 0, -0.2, 0.16, 0.1, "Blush")
		for _, side in { -1, 1 } do
			faceTri(b, "Fang" .. side, head, side * 0.1, -0.4, 0.1, 0.15, "White", 0.13)
		end
		for index, spec in { { 2.6, 2.8 }, { 2.48, 2.5 }, { 2.36, 2.18 } } do
			for _, side in { -1, 1 } do
				whisker(b, "Whisker" .. index .. side, V(side * 0.8, spec[1], -0.7), V(side * 1.8, spec[2], -0.74), 0.07, "Dark")
			end
		end
		b:MirrorBone("Ear", V(0.6, 3.3, -0.05), nil, function()
			local base, tip = V(0.58, 3.2, -0.02), V(1.08, 4.08, 0.05)
			b:Spike("Ear", base, tip, 0.74, 0.3, "Black", THIN, BACK)
			innerFace(b, "EarInner", base, tip, 0.74, 0.3, BACK, 0.6, "Accent")
		end)
	end)
end

-- Elegant cream cat on four slender legs: broad flat head with puffed cheek fur, a red jewel on the forehead,
-- haughty red eyes, long whiskers, dark ears and a long tail held high, curling at the tip.
Designs["Regalynx"] = function(b)
	-- Long slender body lying along Z: 5-sided, a ridge along the spine, the chest a little higher.
	local body = lathe(
		b,
		"Body",
		CFrame.new(0, 1.55, 0.35) * SIDEWAYS,
		{ { -0.55, 0.6, 0.52, 0.04 }, { 0.36, 0.68, 0.66, 0.06 } },
		5,
		V(0, -1.2, 0.08),
		V(0, 1.05, 0.2),
		"Body"
	)
	b:SetCore(body)
	-- Proud neck rising from the chest into the head.
	b:Spike("Neck", V(0, 1.45, -0.15), V(0, 2.6, -0.8), 0.9, 0.74, "Body", THIN, FRONT)
	-- Four slender legs narrowing to neat paws (the sole's front corner pushed out).
	for index, spec in { { -0.22, 0.32 }, { 0.98, 0.34 } } do
		local z, x = spec[1], spec[2]
		b:MirrorBone(if index == 1 then "LegFront" else "LegBack", V(x, 1.25, z), { Phase = if index == 1 then 0 else 0.5 }, function()
			column(b, "Leg", { V(x - 0.02, 1.45, z), V(x + 0.02, 0, z - 0.06) }, { 0.21, 0.11 }, { "Body" }, 2.0, THIN, true)
		end)
	end
	-- Long tail held high, curling forwards at the tip.
	local rings = tubeRings({ V(0, 1.75, 1.3), V(0, 2.25, 2.0), V(0, 3.15, 2.25), V(0, 3.65, 1.8) }, { 0, 0.16, 0.12, 0 }, 3, UP)
	b:Bone("Tail", V(0, 1.8, 1.4), nil, function()
		tubeSegment(b, "Tail1", rings, 1, "Body", THIN)
		b:Bone("Tail2", V(0, 2.25, 2.0), nil, function()
			tubeSegment(b, "Tail2", rings, 2, "Body", THIN)
			tubeSegment(b, "Tail3", rings, 3, "Body", THIN)
		end)
	end)

	b:Bone("Head", V(0, 2.15, -0.6), nil, function()
		-- Broad, flat head, widest at the cheeks (20 facets).
		local head = lathe(
			b,
			"Head",
			CFrame.new(0, 2.7, -0.9),
			{ { -0.2, 1.12, 0.78 }, { 0.24, 0.98, 0.72 } },
			5,
			V(0, -0.62, 0.05),
			V(0, 0.66, 0.08),
			"Body"
		)
		-- Puffed cheek fur sticking out on each side.
		for _, side in { -1, 1 } do
			prong(b, "Tuft" .. side, V(side * 0.85, 2.55, -0.85), V(side * 1.55, 2.3, -0.92), 0.6, 0.34, BACK, "Body")
			prong(b, "TuftLow" .. side, V(side * 0.72, 2.32, -0.95), V(side * 1.25, 1.98, -1.0), 0.44, 0.28, BACK, "Body")
		end
		disc(b, "Jewel", head, 0, 0.32, 0.21, 5, 0.12, 0.03, "Accent", { Neon = true, Thickness = 0.05 })
		b:Eyes(head, 0.44, 0.02, V(0.4, 0.32, 0.28), Color3.fromRGB(200, 30, 50), "Angry")
		faceTri(b, "Nose", head, 0, -0.26, 0.17, 0.11, "Blush")
		b:Mouth(head, -0.42, 0.28)
		for _, side in { -1, 1 } do
			whisker(b, "WhiskerA" .. side, V(side * 0.7, 2.56, -1.42), V(side * 2.0, 2.88, -1.45), 0.06, "Extra")
			whisker(b, "WhiskerB" .. side, V(side * 0.7, 2.44, -1.42), V(side * 1.95, 2.18, -1.35), 0.06, "Extra")
		end
		b:MirrorBone("Ear", V(0.6, 3.2, -0.88), nil, function()
			local base, tip = V(0.58, 3.1, -0.86), V(1.04, 4.02, -0.78)
			b:Spike("Ear", base, tip, 0.76, 0.3, "Extra", THIN, BACK)
			innerFace(b, "EarInner", base, tip, 0.76, 0.3, BACK, 0.6, "Blush")
		end)
	end)
end

return Designs
