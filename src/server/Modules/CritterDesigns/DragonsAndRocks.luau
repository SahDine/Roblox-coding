--[[
	Critter designs: Drakelet, Serpendrake, Puffdrake, Pebbit, Bouldron, Emberfox, Novafox, Lagoonie.
	See CritterBuilder for the toolkit. Ground at y = 0, the critter faces -Z.
	Triangle style: every surface is faceted, only the eyes and the mouths are round, and every moving part
	lives in a bone (legs, arms, head, ears, tails, wings, flippers). Local helpers sculpt low-poly balls
	(snouts, lumpy rocks, pear bodies) and paint some of their facets (bellies, rock patches) without extra
	parts, draw serpent bodies that bend at several bones, and build pointed shapes out of right-angled
	triangles (one part each instead of two) so the budget goes into the silhouette.
]]

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

local DRATINI_EYE = Color3.fromRGB(95, 45, 140)
local DRAGONAIR_EYE = Color3.fromRGB(70, 40, 120)
local FOX_EYE = Color3.fromRGB(120, 60, 25)
local NINE_EYE = Color3.fromRGB(215, 40, 50)
local GOLEM_EYE = Color3.fromRGB(225, 55, 40)
local CRYSTAL = { Detail = 0, Material = Enum.Material.Glass }

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
	opts.Detail (default 2); opts.Deform(v, index) moves the unit vertices (|v| = 1, -Z = front) before
	scaling; opts.Paint(normal, offset, index) returns the colour of a facet (nil = `color`): normal and
	offset (facet centre - position) in design space. Returns a handle for the face helpers.
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

-- Point on a shape seen from `origin` looking along `direction`, moved `lift` along the facet normal
-- (negative = sunk into the shape). When the ray misses the facets it aims at the shape's centre instead.
local function onShape(handle, origin: Vector3, direction: Vector3, lift: number): Vector3
	local point, normal = cast(handle, origin, direction.Unit)
	if not point then
		point, normal = cast(handle, origin, (handle.Center - origin).Unit)
	end
	if point and normal then
		return point + normal * lift
	end
	return handle.Center
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
	Slim leg from `top` to `bottom`: a spindle with one straight edge (the axis) and its bulk towards
	`back`, widest at ringAt. Its two flat sides are right-angled triangles: 8 parts (a Limb costs 12).
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
	local vertices = { top, low + across, low - across, bottom, ring }
	local faces = { { 5, 2, 1 }, { 5, 3, 1 }, { 2, 3, 1 }, { 5, 2, 4 }, { 5, 3, 4 }, { 2, 3, 4 } }
	return b:Mesh(name, vertices, faces, color, THIN)
end

--[[
	Fluffy tail: a spindle from `root` through its widest point `ring` to `tip`; the tip may bend away from
	the root-ring line (a curl). The root-ring edge is straight and the bulk lies on the `down` side, so the
	root half is two right-angled faces + one (4 parts, rootColor) and the tip half 6 parts (tipColor).
]]
local function spindle(
	b,
	name: string,
	root: Vector3,
	ring: Vector3,
	tip: Vector3,
	width: number,
	depth: number,
	down: Vector3,
	rootColor: any,
	tipColor: any
)
	local left, right = prongPoints(ring, root, width, depth, down)
	local vertices = { root, ring, left, right, tip }
	b:Mesh(name, vertices, { { 1, 2, 3 }, { 1, 2, 4 }, { 1, 3, 4 } }, rootColor, THIN)
	b:Mesh(name .. "Tip", vertices, { { 5, 2, 3 }, { 5, 2, 4 }, { 5, 3, 4 } }, tipColor, THIN)
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
	continuous at rest and bends at the bone pivots.
]]
local function serpentRings(points: { Vector3 }, radii: { number }, sides: number, hint: Vector3?)
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
			ring[k + 1] = points[i] + (u * math.cos(a) + v * math.sin(a)) * radii[i]
		end
		data[i] = { Center = points[i], Radius = radii[i], Ring = ring }
	end
	return { Rings = data, Sides = sides }
end

--[[
	Draws the segments between rings first..last of a serpent (one closed faceted mesh per segment and
	colour, so every plate is pushed towards its own segment). paint(normal, segment) -> colour of a facet.
	The first ring is left open: start the curve inside the shape it grows from (a head, a body).
]]
local function serpentPart(b, name: string, body, first: number, last: number, paint)
	local rings, sides = body.Rings, body.Sides
	local tris = {}
	for i = first, last - 1 do
		local r1, r2 = rings[i], rings[i + 1]
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
		local mid = (r1.Center + r2.Center) / 2
		local handle = paintedMesh(b, name, vertices, faces, function(_, face)
			local a, c, d = vertices[face[1]], vertices[face[2]], vertices[face[3]]
			local normal = (c - a):Cross(d - a).Unit
			if normal:Dot((a + c + d) / 3 - mid) < 0 then
				normal = -normal
			end
			return paint(normal, i)
		end, mid, V(1, 1, 1))
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

-- Little blue serpent coiled on the ground: big round head, white fin ears, white nub, cream belly.
Designs["Drakelet"] = function(b)
	local path = {
		V(0, 2.72, -0.52),
		V(0, 1.62, -0.42),
		V(0.12, 0.8, -0.16),
		V(0.68, 0.64, 0.72),
		V(0.05, 0.58, 1.45),
		V(-0.88, 0.5, 1.12),
		V(-1.08, 0.72, 0.25),
	}
	local body = serpentRings(path, { 0.38, 0.43, 0.47, 0.46, 0.41, 0.32, 0 }, 5, FRONT)
	local neckPaint = bellyFacing(V(0, -0.1, -1), 0.5)
	local coilPaint = bellyFacing(V(0, -1, -0.2), 0.45)

	local core = serpentPart(b, "Body", body, 3, 4, coilPaint)
	b:SetCore(core)

	b:Bone("Tail", path[4], { Amp = 0.7 }, function()
		serpentPart(b, "Tail", body, 4, 5, coilPaint)
		b:Bone("Tail2", path[5], { Phase = 0.25 }, function()
			serpentPart(b, "TailTip", body, 5, 7, coilPaint)
		end)
	end)

	b:Bone("Neck", path[3], { Role = "Tail", Amp = 0.35 }, function()
		serpentPart(b, "Neck", body, 1, 3, neckPaint)
		b:Bone("Head", V(0, 2.4, -0.45), nil, function()
			local head = sculpt(b, "Head", V(1.65, 1.48, 1.52), V(0, 3.05, -0.55), nil, "Body", { Deform = snout(0.14, 1.05) })
			b:Eyes(head, 0.37, 0.08, V(0.43, 0.53, 0.26), DRATINI_EYE)
			b:Mouth(head, -0.37, 0.3)
			b:FaceDot("Nub", head, 0, 0.48, V(0.3, 0.26, 0.22), "Accent")
			b:MirrorBone("Ear", V(0.7, 3.08, -0.5), nil, function()
				finEar(
					b,
					V(0.66, 3.08, -0.5),
					{ V(1.3, 3.62, -0.25), V(1.56, 3.12, -0.1), V(1.32, 2.62, 0.05) },
					0.3,
					V(0.35, 0.1, -1),
					"Accent"
				)
			end)
		end)
	end)
end

-- Elegant flying serpent spiralling down: horn, feathered head wings, crystal orbs on the throat and tail.
Designs["Serpendrake"] = function(b)
	b.Hover = 1.1
	local path = {
		V(0, 4.3, -0.8),
		V(0.12, 3.3, -0.5),
		V(0.72, 2.25, -0.12),
		V(0.25, 1.1, 0.3),
		V(-0.8, 0.75, 0.7),
		V(-1.38, 1.5, 1.0),
		V(-1.22, 2.45, 0.8),
	}
	local body = serpentRings(path, { 0.36, 0.45, 0.54, 0.57, 0.5, 0.36, 0 }, 5, FRONT)
	local neckPaint = bellyFacing(V(0, -0.1, -1), 0.5)
	local bodyPaint = bellyFacing(V(0, -1, -0.4), 0.5)

	local core = serpentPart(b, "Body", body, 3, 4, bodyPaint)
	b:SetCore(core)

	b:Bone("Tail", path[4], { Amp = 0.6 }, function()
		serpentPart(b, "Tail", body, 4, 5, bodyPaint)
		b:Bone("Tail2", path[5], { Phase = 0.25 }, function()
			serpentPart(b, "TailTip", body, 5, 7, bodyPaint)
			-- Two crystal beads on the thin end of the tail.
			b:Ball("TailOrb1", V(0.74, 0.74, 0.74), path[6]:Lerp(path[7], 0.2), nil, "Accent", CRYSTAL)
			b:Ball("TailOrb2", V(0.54, 0.54, 0.54), path[6]:Lerp(path[7], 0.6), nil, "Accent", CRYSTAL)
		end)
	end)

	b:Bone("Neck", path[3], { Role = "Tail", Amp = 0.3 }, function()
		serpentPart(b, "Neck", body, 1, 3, neckPaint)
		-- Crystal orb on the throat.
		b:Ball("NeckOrb", V(0.62, 0.62, 0.5), V(0, 3.45, -1.02), nil, "Accent", CRYSTAL)
		b:Bone("Head", V(0, 4.0, -0.78), nil, function()
			local head = sculpt(b, "Head", V(1.38, 1.2, 1.7), V(0, 4.55, -0.98), nil, "Body", { Deform = snout(0.25, 0.9, 0.04) })
			b:Eyes(head, 0.34, 0.12, V(0.32, 0.4, 0.24), DRAGONAIR_EYE)
			b:Mouth(head, -0.33, 0.24)
			-- Short white horn on the forehead.
			prong(b, "Horn", V(0, 5.0, -1.28), V(0, 5.62, -1.42), 0.3, 0.26, BACK, "Belly")
			-- Feathered head wings (they flap while it hovers).
			b:MirrorBone("Wing", V(0.58, 4.6, -0.85), nil, function()
				finEar(
					b,
					V(0.58, 4.6, -0.85),
					{ V(1.5, 5.3, -0.55), V(1.82, 4.75, -0.35), V(1.55, 4.2, -0.15) },
					0.36,
					V(0.25, 0.15, -1),
					"Belly"
				)
			end)
		end)
	end)
end

-- Big friendly flying dragon: chubby orange body, ribbed cream belly, small teal wings, antennae.
Designs["Puffdrake"] = function(b)
	b.Hover = 1.1
	local body = sculpt(b, "Body", V(2.5, 2.5, 2.25), V(0, 1.75, 0.15), nil, "Body", {
		-- Pear shaped: wide hips, narrower shoulders.
		Deform = function(v: Vector3): Vector3
			return V(v.X * (1 - v.Y * 0.16), v.Y, v.Z * (1 - v.Y * 0.1))
		end,
		Paint = function(normal: Vector3): any
			return if normal.Z < -0.45 and math.abs(normal.X) < 0.62 then "Belly" else nil
		end,
	})
	b:SetCore(body)
	local neck = serpentRings({ V(0, 2.45, -0.02), V(0, 3.55, -0.36) }, { 0.74, 0.56 }, 4, FRONT)
	serpentPart(b, "Neck", neck, 1, 2, bellyFacing(FRONT, 0.6))

	-- Short arms with three claws and dangling legs with big feet.
	b:MirrorBone("Arm", V(0.95, 2.4, -0.3), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.74, 2.42, -0.2), V(1.42, 1.85, -0.78), 0.48, "Body", { RingAt = 0.4 })
		claws(b, "Claw", V(1.42, 1.85, -0.78), V(0.3, -0.6, -0.8), V(1, 0, -0.3), 3, 0.11, 0.24, "Belly")
	end)
	b:MirrorBone("Leg", V(0.62, 0.95, 0.2), nil, function()
		b:Limb("Leg", V(0.6, 1.3, 0.2), V(0.72, 0.25, 0.0), 0.8, "Body", { RingAt = 0.3 })
		prong(b, "Foot", V(0.72, 0.38, 0.05), V(0.76, 0.04, -0.6), 0.66, 0.34, V(0, -0.88, 0.46), "Body")
	end)

	-- Small teal wings on the back: an orange spar and a scalloped membrane.
	b:MirrorBone("Wing", V(0.45, 2.5, 0.72), nil, function()
		prong(b, "WingSpar", V(0.38, 2.48, 0.7), V(1.85, 4.0, 1.25), 0.22, 0.18, DOWN, "Body")
		b:Tri("Membrane1", V(0.45, 2.5, 0.78), V(1.8, 3.95, 1.27), V(1.6, 2.85, 1.45), "Accent", THIN)
		b:Tri("Membrane2", V(0.45, 2.5, 0.78), V(1.6, 2.85, 1.45), V(0.95, 2.15, 1.22), "Accent", THIN)
	end)

	b:Bone("Tail", V(0, 1.2, 1.0), nil, function()
		local tail = serpentRings({ V(0, 1.25, 0.85), V(0, 0.82, 1.75), V(0, 0.6, 2.5) }, { 0.62, 0.4, 0 }, 4, UP)
		serpentPart(b, "Tail", tail, 1, 3, bellyFacing(DOWN, 0.6))
	end)

	b:Bone("Head", V(0, 3.45, -0.35), nil, function()
		local head = sculpt(b, "Head", V(1.6, 1.42, 1.55), V(0, 4.0, -0.5), nil, "Body", { Deform = snout(0.45, 0.8, 0.02, 0.32) })
		b:Eyes(head, 0.33, 0.24, V(0.29, 0.35, 0.22), "Black")
		b:Mouth(head, -0.33, 0.56)
		b:FaceDot("NostrilL", head, -0.14, -0.06, V(0.08, 0.06, 0.06), "Dark")
		b:FaceDot("NostrilR", head, 0.14, -0.06, V(0.08, 0.06, 0.06), "Dark")
		-- Thin antennae curling forwards from the forehead (they twitch like ears).
		b:MirrorBone("Ear", V(0.2, 4.6, -0.82), nil, function()
			prong(b, "Antenna", V(0.18, 4.55, -0.8), V(0.36, 5.42, -0.95), 0.15, 0.11, BACK, "Body")
			prong(b, "AntennaTip", V(0.35, 5.37, -0.93), V(0.55, 5.7, -0.66), 0.13, 0.09, BACK, "Body")
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

-- Weathered stone: about a third of the facets (picked from their vertex indices) in the darker colour,
-- except those facing `clear` (the face).
local function stonePaint(dark: any, clear: Vector3?)
	return function(normal: Vector3, _offset: Vector3, face: { number }): any
		if clear and normal:Dot(clear) > 0.6 then
			return nil
		end
		return if (face[1] * 7 + face[2] * 3 + face[3]) % 3 == 0 then dark else nil
	end
end

-- Living rock with two strong arms flexing big fists, heavy brows and a toothy grin.
Designs["Pebbit"] = function(b)
	local bumps = { 0.9, 1.05, 0.97, 1.08, 1.02, 0.96, 1.04, 0.98, 1.07, 0.95, 1.03, 0.94 }
	local body =
		sculpt(b, "Body", V(2.35, 2.15, 2.15), V(0, 1.06, 0), nil, "Body", { Deform = lumps(bumps), Paint = stonePaint("Accent", FRONT) })
	b:SetCore(body)
	b:Eyes(body, 0.42, 0.24, V(0.42, 0.42, 0.26), "White")
	-- Heavy rock brows slanting down towards the nose (angry).
	for _, side in { -1, 1 } do
		local outer = onFront(b, body, side * 0.74, 1.66, 0.02)
		local inner = onFront(b, body, side * 0.06, 1.47, 0.1)
		prong(b, "Brow" .. (if side < 0 then "L" else "R"), outer, inner, 0.26, 0.26, V(0, -0.3, 1), "Accent")
	end
	-- Wide clenched grin: a dark slit with a row of teeth in front of it.
	b:Mouth(body, -0.36, 0.86)
	b:Tri("Teeth", onFront(b, body, -0.3, 0.73, 0.1), onFront(b, body, 0.3, 0.73, 0.1), onFront(b, body, 0, 0.66, 0.1), "White", THIN)

	b:MirrorBone("Arm", V(1.0, 1.1, 0.0), { Phase = 0.5 }, function()
		b:Limb("UpperArm", V(0.8, 1.02, 0.05), V(1.92, 1.18, -0.12), 0.8, "Body", { RingAt = 0.55 })
		b:Limb("Forearm", V(1.82, 0.98, -0.1), V(1.98, 2.1, -0.45), 0.72, "Body", { RingAt = 0.45 })
		b:Ball("Fist", V(0.95, 0.88, 0.88), V(1.98, 2.25, -0.52), nil, "Body", { Detail = 1 })
	end)
end

-- Big round boulder standing on short legs: the reptile head pokes out of its upper front, thick
-- clawed arms stick out of its sides, rocky lumps on top.
Designs["Bouldron"] = function(b)
	local bumps = { 1.06, 0.96, 1.1, 0.97, 1.08, 0.97, 1.05, 0.97, 1.07, 0.98, 1.04, 0.9 }
	local shell =
		sculpt(b, "Shell", V(3.2, 2.9, 3.0), V(0, 2.0, 0.2), nil, "Body", { Deform = lumps(bumps), Paint = stonePaint("Accent", FRONT) })
	b:SetCore(shell)
	-- Rocky lumps on the shell: low three-sided pyramids leaning back.
	for index, spot in { V(0.75, 0, -0.05), V(-0.45, 0, 0.25), V(0.25, 0, 1.0), V(-1.0, 0, 0.95), V(1.1, 0, 0.9) } do
		local at = onShape(shell, spot + V(0, 5, 0), DOWN, -0.15)
		b:Cone("Lump" .. index, at, at + V(spot.X * 0.2, 0.42, 0.25), 0.55, "Accent", { Sides = 3, Thickness = 0.08 })
	end

	b:MirrorBone("Leg", V(0.85, 0.85, 0.3), nil, function()
		b:Limb("Leg", V(0.85, 1.3, 0.3), V(0.92, 0.3, 0.2), 1.0, "Belly", { RingAt = 0.45 })
		prong(b, "Foot", V(0.92, 0.04, 0.55), V(0.95, 0.04, -0.45), 0.95, 0.52, UP, "Belly")
		claws(b, "Toe", V(0.95, 0.1, -0.38), V(0, -0.2, -1), SIDE, 3, 0.25, 0.26)
	end)
	b:MirrorBone("Arm", V(1.4, 2.0, -0.2), { Phase = 0.5 }, function()
		b:Limb("Arm", V(1.2, 2.08, -0.15), V(2.1, 1.12, -0.65), 0.92, "Belly", { RingAt = 0.4 })
		claws(b, "Claw", V(2.1, 1.12, -0.68), V(0.2, -0.6, -0.75), V(1, 0, 0.4), 3, 0.22, 0.42)
	end)

	b:Bone("Head", V(0, 2.25, -0.8), nil, function()
		local head = sculpt(b, "Head", V(1.6, 1.3, 1.4), V(0, 2.25, -1.4), nil, "Belly", { Detail = 1, Deform = snout(0.12, 1.12) })
		b:Eyes(head, 0.33, 0.06, V(0.28, 0.26, 0.2), GOLEM_EYE, "Angry")
		b:Mouth(head, -0.33, 0.55)
		-- Rocky brow ridge over the eyes.
		for _, side in { -1, 1 } do
			prong(
				b,
				"Brow" .. (if side < 0 then "L" else "R"),
				V(side * 0.74, 2.73, -1.5),
				V(0, 2.63, -2.15),
				0.36,
				0.32,
				V(0, -0.4, 1),
				"Accent"
			)
		end
	end)
end

-- Fox line ----------------------------------------------------------------------------------------

-- Pointed ear with a flat front face and a darker inner triangle on it. Give the right side.
local function foxEar(b, base: Vector3, tip: Vector3, width: number, depth: number, color: any, inner: any)
	prong(b, "Ear", base, tip, width, depth, FRONT, color)
	-- The front face of the prong is (left, right, tip): lay the inner ear on it.
	local left, right = prongPoints(base, tip, width, depth, FRONT)
	local centre = (left + right + tip) / 3
	local normal = (right - left):Cross(tip - left).Unit
	if normal:Dot(centre - base) < 0 then
		normal = -normal
	end
	local lift = normal * 0.035
	b:Tri(
		"EarInner",
		left:Lerp(centre, 0.35) + lift,
		right:Lerp(centre, 0.35) + lift,
		tip:Lerp(centre, 0.25) + lift,
		inner,
		{ Thickness = 0.04 }
	)
end

-- Four slim legs (struts with the calf at the back), paws in `pawColor`; diagonal pairs trot together.
local function foxLegs(b, frontZ: number, backZ: number, spacing: number, hipY: number, width: number, pawColor: any?)
	for index, z in { frontZ, backZ } do
		b:MirrorBone(
			if index == 1 then "LegFront" else "LegBack",
			V(spacing, hipY, z),
			{ Phase = if index == 1 then 0 else 0.5 },
			function()
				strut(b, "Leg", V(spacing - 0.02, hipY + 0.2, z), V(spacing + 0.02, 0.1, z - 0.04), width, width * 0.85, BACK, "Body", 0.3)
				if pawColor then
					prong(b, "Paw", V(spacing + 0.02, 0.03, z + 0.1), V(spacing + 0.02, 0.03, z - 0.3), width * 0.85, 0.24, UP, pawColor)
				end
			end
		)
	end
end

-- Fox cub with a curly orange forelock and six curly tails.
Designs["Emberfox"] = function(b)
	local body = sculpt(b, "Body", V(1.3, 1.2, 1.9), V(0, 1.02, 0.3), nil, "Body", {
		Detail = 1,
		Paint = function(normal: Vector3): any
			return if normal.Y < -0.45 then "Belly" else nil
		end,
	})
	b:SetCore(body)
	foxLegs(b, -0.25, 0.85, 0.37, 0.85, 0.36, "Extra")

	-- Six curly tails fanning out behind (each its own bone so they sway one after the other).
	for index, spec in { { -45, 55 }, { 0, 72 }, { 45, 55 }, { -70, 18 }, { 0, 32 }, { 70, 18 } } do
		local az, el = math.rad(spec[1]), math.rad(spec[2])
		local dir = V(math.sin(az) * math.cos(el), math.sin(el), math.cos(az) * math.cos(el))
		local root = V(math.sin(az) * 0.12, 1.15, 0.95)
		local ring = root + dir * 0.75
		local tip = ring + (dir + V(0, 0.55, -0.9)).Unit * 0.62
		b:Bone("Tail" .. index, root, { Phase = index / 6, Amp = 0.6 }, function()
			-- Bulk towards the middle of the bush: every tail shows its ridge to the outside.
			spindle(b, "Tail", root, ring, tip, 0.62, 0.42, V(0, 0.7, 0.7) - dir, "Body", "Accent")
		end)
	end

	b:Bone("Head", V(0, 1.35, -0.4), nil, function()
		local head = sculpt(b, "Head", V(1.6, 1.4, 1.4), V(0, 1.9, -0.5), nil, "Body", { Deform = snout(0.2, 0.85, 0.02) })
		b:Eyes(head, 0.38, 0.08, V(0.36, 0.44, 0.26), FOX_EYE)
		b:FaceDot("Nose", head, 0, -0.22, V(0.16, 0.12, 0.12), "Black")
		b:Mouth(head, -0.38, 0.2)
		-- Curly forelock: three orange locks falling over the forehead.
		prong(b, "Curl", V(0, 2.54, -0.42), V(0, 2.26, -1.22), 0.5, 0.34, UP, "Accent")
		for _, side in { -1, 1 } do
			prong(b, "CurlSide" .. side, V(side * 0.3, 2.48, -0.37), V(side * 0.56, 2.18, -1.08), 0.42, 0.28, UP, "Accent")
		end
		b:MirrorBone("Ear", V(0.45, 2.45, -0.55), nil, function()
			foxEar(b, V(0.4, 2.38, -0.55), V(0.98, 3.3, -0.42), 0.68, 0.3, "Body", "Extra")
		end)
	end)
end

-- Elegant fox with a fluffy ruff, a swept-back crest and nine orange-tipped tails.
Designs["Novafox"] = function(b)
	local body = sculpt(b, "Body", V(1.35, 1.25, 2.2), V(0, 1.62, 0.3), nil, "Body", { Detail = 1 })
	b:SetCore(body)
	-- Fluffy ruff on the chest, hanging down to a point.
	sculpt(b, "Ruff", V(1.25, 1.35, 1.05), V(0, 2.0, -0.55), nil, "Body", {
		Detail = 0,
		Deform = function(v: Vector3): Vector3
			return if v.Y < -0.9 then V(0, -1.4, -0.45) elseif v.Z < -0.9 then V(0, 0.1, -1.15) else v
		end,
	})
	for index, z in { -0.25, 0.9 } do
		b:MirrorBone(if index == 1 then "LegFront" else "LegBack", V(0.36, 1.45, z), { Phase = if index == 1 then 0 else 0.5 }, function()
			b:Limb("Leg", V(0.34, 1.75, z + 0.04), V(0.4, 0.0, z - 0.06), 0.42, "Body", { RingAt = 0.3 })
		end)
	end

	-- Nine long tails spread over a dome behind it (azimuth from straight back, elevation).
	local tails = { { -72, 30 }, { -42, 52 }, { 0, 68 }, { 42, 52 }, { 72, 30 }, { -50, 8 }, { -18, 26 }, { 18, 26 }, { 50, 8 } }
	for index, spec in tails do
		local az, el = math.rad(spec[1]), math.rad(spec[2])
		local dir = V(math.sin(az) * math.cos(el), math.sin(el), math.cos(az) * math.cos(el))
		local root = V(math.sin(az) * 0.12, 1.85, 1.1)
		b:Bone("Tail" .. index, root, { Phase = index / 9, Amp = 0.5 }, function()
			spindle(b, "Tail", root, root + dir * 1.15, root + dir * 1.95, 0.66, 0.46, V(0, 0.65, 0.75) - dir, "Body", "Accent")
		end)
	end

	b:Bone("Head", V(0, 2.5, -0.75), nil, function()
		local head = sculpt(b, "Head", V(1.28, 1.12, 1.38), V(0, 2.98, -0.95), nil, "Body", { Deform = snout(0.4, 0.7, 0.05) })
		b:Eyes(head, 0.32, 0.12, V(0.3, 0.34, 0.22), NINE_EYE)
		b:FaceDot("Nose", head, 0, -0.28, V(0.12, 0.1, 0.1), "Black")
		-- Swept-back crest rising from the forehead.
		prong(b, "Crest", V(0, 3.4, -1.05), V(0, 4.05, -0.45), 0.44, 0.32, BACK + DOWN, "Body")
		b:MirrorBone("Ear", V(0.36, 3.3, -0.85), nil, function()
			foxEar(b, V(0.32, 3.22, -0.85), V(0.76, 4.1, -0.7), 0.52, 0.26, "Body", "Accent")
		end)
	end)
end

-- Sea ---------------------------------------------------------------------------------------------

-- Gentle sea creature: long neck with a cream front, curled horn, grey studded shell, four paddle flippers.
Designs["Lagoonie"] = function(b)
	local body = sculpt(b, "Body", V(2.6, 1.45, 2.9), V(0, 0.78, 0.35), nil, "Body", {
		Detail = 1,
		Paint = function(normal: Vector3): any
			return if normal.Y < -0.4 or normal.Z < -0.7 then "Belly" else nil
		end,
	})
	b:SetCore(body)
	local shell = sculpt(b, "Shell", V(2.8, 1.75, 2.75), V(0, 1.32, 0.7), nil, "Accent", {
		Deform = function(v: Vector3): Vector3
			return if v.Y < 0 then V(v.X, v.Y * 0.45, v.Z) elseif v.Y > 0.99 then V(0, 1.12, 0.05) else v
		end,
	})
	-- Blunt knobs on the shell.
	for index, spot in { V(0.55, 0, 0.3), V(-0.55, 0, 0.3), V(0.62, 0, 1.15), V(-0.62, 0, 1.15), V(0, 0, 1.6) } do
		local at = onShape(shell, spot + V(0, 4, 0), DOWN, -0.12)
		b:Spike("Knob" .. index, at, at + V(spot.X * 0.15, 0.42, 0.05), 0.46, 0.42, "Extra", THIN, BACK)
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
		local neck = serpentRings({ V(0, 0.9, -0.6), V(0, 2.0, -1.05), V(0, 2.95, -1.12) }, { 0.6, 0.48, 0.42 }, 5, FRONT)
		serpentPart(b, "Neck", neck, 1, 3, bellyFacing(V(0, -0.1, -1), 0.5))
		b:Bone("Head", V(0, 2.9, -1.1), nil, function()
			local head = sculpt(b, "Head", V(1.55, 1.3, 1.65), V(0, 3.42, -1.3), nil, "Body", { Deform = snout(0.2, 0.95) })
			b:Eyes(head, 0.38, 0.1, V(0.34, 0.42, 0.24), "Black")
			b:Mouth(head, -0.38, 0.4)
			-- Horn curling backwards.
			prong(b, "Horn", V(0, 3.95, -1.5), V(0, 4.5, -1.42), 0.32, 0.26, BACK, "Body")
			prong(b, "HornTip", V(0, 4.4, -1.42), V(0, 4.62, -1.05), 0.24, 0.2, DOWN, "Body")
			-- Ear flaps swept back.
			b:MirrorBone("Ear", V(0.58, 3.65, -1.15), nil, function()
				prong(b, "Ear", V(0.55, 3.62, -1.15), V(1.12, 3.9, -0.62), 0.44, 0.2, DOWN, "Body")
			end)
		end)
	end)
end

return Designs
