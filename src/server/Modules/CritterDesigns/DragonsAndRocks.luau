--[[
	Critter designs: Drakelet, Serpendrake, Puffdrake, Pebbit, Bouldron, Emberfox, Novafox, Lagoonie.
	See CritterBuilder for the toolkit. Ground at y = 0, the critter faces -Z.
	Triangle style: every surface is faceted (Ball / Limb / Spike / Mesh...), only the eyes and the mouths
	are round, and every moving part lives in a bone (legs, arms, head, ears, tails, wings, flippers).
]]

local V = Vector3.new

local Designs = {}

local TAU = math.pi * 2
local UP = V(0, 1, 0)
local SIDE = V(1, 0, 0)
local FRONT = V(0, 0, -1)
-- Thin plates: the thickness of flat triangles (fins, membranes, stripes), and on small closed shapes
-- (limbs, spikes) they keep the low-poly edges crisp.
local THIN = { Thickness = 0.06 }

-- Shared pieces -----------------------------------------------------------------------------

-- Joins several handles into one (for the face helpers and SetCore).
local function merge(handles)
	local tris = {}
	local low, high = nil, nil
	for _, handle in handles do
		for _, triangle in handle.Tris do
			table.insert(tris, triangle)
		end
		local a, c = handle.Center - handle.Size / 2, handle.Center + handle.Size / 2
		low = if low then V(math.min(low.X, a.X), math.min(low.Y, a.Y), math.min(low.Z, a.Z)) else a
		high = if high then V(math.max(high.X, c.X), math.max(high.Y, c.Y), math.max(high.Z, c.Z)) else c
	end
	return { Part = handles[1].Part, Center = (low + high) / 2, Size = high - low, Tris = tris }
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
	Draws the rings first..last of a serpent (one closed faceted segment per pair of rings, so every plate
	is pushed towards its own segment). paint(normal, centroid, segment) -> colour of each facet.
	The first ring is left open: start the curve inside the shape it grows from (a head, a body).
	Returns one handle covering every facet.
]]
local function serpentPart(b, name: string, body, first: number, last: number, paint)
	local rings, sides = body.Rings, body.Sides
	local handles = {}
	local function emit(vertices, faces, segment: number)
		local center = Vector3.zero
		for _, vertex in vertices do
			center += vertex
		end
		center /= #vertices
		local groups, order = {}, {}
		for _, face in faces do
			local a, c, d = vertices[face[1]], vertices[face[2]], vertices[face[3]]
			local centroid = (a + c + d) / 3
			local normal = (c - a):Cross(d - a).Unit
			if normal:Dot(centroid - center) < 0 then
				normal = -normal
			end
			local color = paint(normal, centroid, segment)
			if not groups[color] then
				groups[color] = {}
				table.insert(order, color)
			end
			table.insert(groups[color], face)
		end
		for _, color in order do
			table.insert(handles, b:Mesh(name, vertices, groups[color], color))
		end
	end

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
		emit(vertices, faces, i)
	end
	return merge(handles)
end

--[[
	Patch lying on the front of a shape (bellies, chests): a fan of triangles from a raised centre to an
	outline given as (x, y) offsets from the shape's centre, every point cast onto the shape's facets.
	lift = how far the outline floats in front of the surface, bulge = how far the centre does.
]]
local function patch(b, name: string, shape, outline: { Vector2 }, centre: Vector2, lift: number, bulge: number, color: any)
	local vertices = {}
	for _, point in outline do
		table.insert(vertices, (b:OnSurface(shape, point.X, point.Y) * CFrame.new(0, 0, -lift)).Position)
	end
	table.insert(vertices, (b:OnSurface(shape, centre.X, centre.Y) * CFrame.new(0, 0, -bulge)).Position)
	local faces = {}
	for i = 1, #outline do
		table.insert(faces, { #vertices, i, i % #outline + 1 })
	end
	return b:Mesh(name, vertices, faces, color, THIN)
end

-- Unit icosahedron (same layout as LowPoly: a vertex on top, one upper vertex towards the front).
local ICO_VERTICES, ICO_FACES = {}, {}
do
	table.insert(ICO_VERTICES, V(0, 1, 0))
	local ringY, ringR = 1 / math.sqrt(5), 2 / math.sqrt(5)
	for i = 0, 4 do
		local a = i * TAU / 5
		table.insert(ICO_VERTICES, V(math.sin(a) * ringR, ringY, -math.cos(a) * ringR))
	end
	for i = 0, 4 do
		local a = (i + 0.5) * TAU / 5
		table.insert(ICO_VERTICES, V(math.sin(a) * ringR, -ringY, -math.cos(a) * ringR))
	end
	table.insert(ICO_VERTICES, V(0, -1, 0))
	for i = 0, 4 do
		local u1, u2 = 2 + i, 2 + (i + 1) % 5
		local l1, l2 = 7 + i, 7 + (i + 1) % 5
		table.insert(ICO_FACES, { 1, u1, u2 })
		table.insert(ICO_FACES, { u1, l1, u2 })
		table.insert(ICO_FACES, { u2, l1, l2 })
		table.insert(ICO_FACES, { 12, l2, l1 })
	end
end

--[[
	Lumpy rock: an icosahedron scaled to `size` whose 12 vertices are pushed in / out by `bumps` (12
	multipliers), painted two-tone: paint(faceIndex, normal) -> colour. Returns one handle.
]]
local function rock(b, name: string, size: Vector3, center: Vector3, rot: Vector3?, bumps: { number }, paint)
	local frame = CFrame.new(center)
	if rot then
		frame *= CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	end
	local vertices = {}
	for index, vertex in ICO_VERTICES do
		vertices[index] = frame:PointToWorldSpace(vertex * size / 2 * (bumps[index] or 1))
	end
	local groups, order = {}, {}
	for index, face in ICO_FACES do
		local a, c, d = vertices[face[1]], vertices[face[2]], vertices[face[3]]
		local normal = (c - a):Cross(d - a).Unit
		if normal:Dot((a + c + d) / 3 - center) < 0 then
			normal = -normal
		end
		local color = paint(index, normal)
		if not groups[color] then
			groups[color] = {}
			table.insert(order, color)
		end
		table.insert(groups[color], face)
	end
	local handles = {}
	for _, color in order do
		table.insert(handles, b:Mesh(name, vertices, groups[color], color))
	end
	return merge(handles)
end

-- Belly paint for serpents: facets facing `dir` (within ~55 degrees) are cream.
local function bellyFacing(dir: Vector3, threshold: number?)
	local unit = dir.Unit
	return function(normal: Vector3): string
		return if normal:Dot(unit) > (threshold or 0.55) then "Belly" else "Body"
	end
end

-- Point on the front of a shape at the design height y (x offset from its centre), lifted outwards.
local function onFront(b, shape, x: number, y: number, lift: number): Vector3
	return (b:OnSurface(shape, x, y - shape.Center.Y) * CFrame.new(0, 0, -lift)).Position
end

--[[
	Plume (fluffy fox tails, crests): a folded feather from `base` to `tip`, widest at ringAt with a ridge
	raised `depth` towards `facing`. The base half is painted baseColor, the tip half tipColor. 4 triangles.
]]
local function plume(
	b,
	name: string,
	base: Vector3,
	tip: Vector3,
	width: number,
	depth: number,
	facing: Vector3,
	baseColor: any,
	tipColor: any,
	ringAt: number?
)
	local axis = tip - base
	local up = facing - axis.Unit * facing:Dot(axis.Unit)
	up = if up.Magnitude > 1e-3 then up.Unit else UP
	local side = axis:Cross(up).Unit
	local ring = base + axis * (ringAt or 0.55)
	local vertices = { base, ring - side * width / 2, ring + side * width / 2, ring + up * depth, tip }
	b:Mesh(name, vertices, { { 1, 2, 4 }, { 1, 4, 3 } }, baseColor, THIN)
	b:Mesh(name .. "Tip", vertices, { { 2, 5, 4 }, { 4, 5, 3 } }, tipColor, THIN)
end

-- Dragon line ------------------------------------------------------------------------------------

-- Little blue serpent coiled on the ground: round head, white fin ears, white nose nub, cream belly.
Designs["Drakelet"] = function(b)
	local path = {
		V(0, 2.15, -0.3),
		V(0, 1.35, -0.42),
		V(0.05, 0.72, -0.18),
		V(0.55, 0.6, 0.55),
		V(0.0, 0.6, 1.2),
		V(-0.7, 0.6, 1.05),
		V(-1.0, 0.8, 0.45),
		V(-0.88, 1.2, 0.05),
	}
	local body = serpentRings(path, { 0.4, 0.46, 0.5, 0.48, 0.44, 0.36, 0.22, 0 }, 4, FRONT)
	local neckPaint = bellyFacing(V(0, -0.15, -1))
	local coilPaint = bellyFacing(V(0, -1, -0.4))

	local core = serpentPart(b, "Body", body, 2, 4, function(normal, _, segment)
		return if segment <= 2 then neckPaint(normal) else coilPaint(normal)
	end)
	b:SetCore(core)

	b:Bone("Tail", path[4], nil, function()
		serpentPart(b, "Tail", body, 4, 6, coilPaint)
		b:Bone("Tail2", path[6], { Phase = 0.25 }, function()
			serpentPart(b, "TailTip", body, 6, 8, coilPaint)
		end)
	end)

	b:Bone("Neck", path[2], { Role = "Tail", Amp = 0.35 }, function()
		serpentPart(b, "Neck", body, 1, 2, neckPaint)
		b:Bone("Head", V(0, 2.05, -0.36), nil, function()
			local head = b:Ball("Head", V(1.45, 1.3, 1.4), V(0, 2.6, -0.52), nil, "Body")
			b:Eyes(head, 0.36, 0.06, V(0.4, 0.48, 0.24), Color3.fromRGB(70, 40, 110))
			b:Mouth(head, -0.3, 0.3)
			b:FaceDot("Nose", head, 0, 0.42, V(0.3, 0.26, 0.2), "Accent")
			-- White fin ears: three feathery points fanning out backwards.
			b:MirrorBone("Ear", V(0.62, 2.62, -0.4), nil, function()
				local base = V(0.6, 2.62, -0.42)
				b:Spike("Fin1", base, V(1.28, 3.02, -0.3), 0.36, 0.08, "Accent", THIN, V(0, 0.3, -1))
				b:Spike("Fin2", base + V(0, -0.08, 0.05), V(1.42, 2.66, -0.15), 0.34, 0.08, "Accent", THIN, V(0, 0.3, -1))
				b:Spike("Fin3", base + V(0, -0.16, 0.1), V(1.25, 2.3, 0.0), 0.3, 0.08, "Accent", THIN, V(0, 0.3, -1))
			end)
		end)
	end)
end

-- Elegant flying serpent: horn, feathered head wings, crystal orbs on the throat and the tail.
Designs["Serpendrake"] = function(b)
	b.Hover = 1.4
	local path = {
		V(0, 4.15, -0.62),
		V(0, 2.75, -0.25),
		V(0.15, 1.7, 0.2),
		V(0.6, 1.0, 0.9),
		V(0.5, 0.85, 1.7),
		V(-0.2, 1.2, 2.2),
		V(-0.75, 1.95, 2.0),
		V(-0.9, 2.75, 1.55),
	}
	local body = serpentRings(path, { 0.36, 0.46, 0.55, 0.58, 0.54, 0.44, 0.3, 0 }, 4, FRONT)
	local neckPaint = bellyFacing(V(0, -0.1, -1))
	local bodyPaint = bellyFacing(V(0, -1, -0.5))
	local crystal = { Detail = 0, Material = Enum.Material.Glass }

	local core = serpentPart(b, "Body", body, 2, 4, function(normal, _, segment)
		return if segment <= 2 then neckPaint(normal) else bodyPaint(normal)
	end)
	b:SetCore(core)

	b:Bone("Tail", path[4], nil, function()
		serpentPart(b, "Tail", body, 4, 6, bodyPaint)
		b:Bone("Tail2", path[6], { Phase = 0.25 }, function()
			serpentPart(b, "TailTip", body, 6, 8, bodyPaint)
			-- Two crystal beads on the thin end of the tail.
			b:Ball("TailOrb1", V(0.72, 0.72, 0.72), path[7]:Lerp(path[8], 0.2), nil, "Accent", crystal)
			b:Ball("TailOrb2", V(0.52, 0.52, 0.52), path[7]:Lerp(path[8], 0.62), nil, "Accent", crystal)
		end)
	end)

	b:Bone("Neck", path[2], { Role = "Tail", Amp = 0.3 }, function()
		serpentPart(b, "Neck", body, 1, 2, neckPaint)
		-- Crystal orb on the throat.
		b:Ball("NeckOrb", V(0.6, 0.6, 0.5), V(0, 3.05, -0.72), nil, "Accent", crystal)
		b:Bone("Head", V(0, 3.95, -0.6), nil, function()
			local head = b:Ball("Head", V(1.3, 1.15, 1.65), V(0, 4.45, -0.85), nil, "Body")
			b:Eyes(head, 0.33, 0.12, V(0.28, 0.36, 0.22), Color3.fromRGB(40, 30, 90))
			b:Mouth(head, -0.3, 0.26)
			-- Short white horn on the forehead.
			b:Spike("Horn", V(0, 4.85, -1.1), V(0, 5.5, -1.3), 0.3, 0.26, "Belly", THIN, FRONT)
			-- Feathered head wings (they flap while it hovers).
			b:MirrorBone("Wing", V(0.55, 4.5, -0.7), nil, function()
				local base = V(0.52, 4.5, -0.72)
				b:Spike("Feather1", base, V(1.55, 5.25, -0.4), 0.46, 0.08, "Belly", THIN, V(0, 0.2, -1))
				b:Spike("Feather2", base + V(0, -0.06, 0.08), V(1.75, 4.65, -0.2), 0.42, 0.08, "Belly", THIN, V(0, 0.2, -1))
				b:Spike("Feather3", base + V(0, -0.12, 0.16), V(1.5, 4.15, 0.02), 0.36, 0.08, "Belly", THIN, V(0, 0.2, -1))
			end)
		end)
	end)
end

-- Big friendly flying dragon: round orange body, striped cream belly, small teal wings, antennae.
Designs["Puffdrake"] = function(b)
	b.Hover = 1.2
	-- Body turned so a vertex points forwards: the belly patch lies flat on the five facets around it.
	local body = b:Ball("Body", V(2.3, 2.05, 2.55), V(0, 1.6, 0.1), V(-90, 0, 0), "Body")
	b:SetCore(body)
	local outline = {}
	for k = 0, 7 do
		local a = k * TAU / 8
		table.insert(outline, Vector2.new(math.sin(a) * 0.8, -0.1 + math.cos(a) * 0.98))
	end
	local belly = patch(b, "Belly", body, outline, Vector2.new(0, 0), 0.03, 0.1, "Belly")
	for index, y in { 2.0, 1.62, 1.24 } do
		local half = 0.66 - math.abs(y - 1.62) * 0.35
		b:Tri(
			"Stripe" .. index,
			onFront(b, belly, -half, y, 0.05),
			onFront(b, belly, half, y, 0.05),
			onFront(b, belly, 0, y - 0.12, 0.07),
			"Extra",
			THIN
		)
	end
	b:Limb("Neck", V(0, 2.3, -0.02), V(0, 3.3, -0.25), 0.95, "Body")

	-- Dangling legs and short arms.
	b:MirrorBone("Leg", V(0.6, 0.85, 0.05), nil, function()
		b:Limb("Leg", V(0.6, 1.15, 0.1), V(0.74, 0.02, -0.38), 0.78, "Body", { RingAt = 0.35, Thickness = 0.06 })
	end)
	b:MirrorBone("Arm", V(0.98, 2.25, -0.2), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.85, 2.35, -0.15), V(1.45, 1.75, -0.7), 0.44, "Body", { Sides = 4, Thickness = 0.06 })
	end)

	-- Small teal wings on the back: an orange spar and a scalloped membrane.
	b:MirrorBone("Wing", V(0.5, 2.6, 0.75), nil, function()
		b:Spike("WingSpar", V(0.45, 2.6, 0.75), V(1.7, 3.95, 1.1), 0.22, 0.16, "Body", THIN, UP)
		b:Tri("Membrane1", V(0.5, 2.55, 0.8), V(1.66, 3.9, 1.12), V(1.55, 2.75, 1.35), "Accent", THIN)
		b:Tri("Membrane2", V(0.5, 2.55, 0.8), V(1.55, 2.75, 1.35), V(0.95, 2.15, 1.2), "Accent", THIN)
	end)

	b:Bone("Tail", V(0, 1.1, 0.85), nil, function()
		local tail = serpentRings({ V(0, 1.2, 0.65), V(0, 0.72, 1.6), V(0, 0.5, 2.35) }, { 0.62, 0.42, 0 }, 3, UP)
		serpentPart(b, "Tail", tail, 1, 3, bellyFacing(V(0, -1, 0)))
	end)

	b:Bone("Head", V(0, 3.1, -0.2), nil, function()
		local head = b:Ball("Head", V(1.45, 1.3, 1.8), V(0, 3.5, -0.42), nil, "Body")
		b:Eyes(head, 0.32, 0.22, V(0.28, 0.34, 0.22), "Black")
		b:Mouth(head, -0.28, 0.5)
		b:MirrorBone("Ear", V(0.22, 4.15, -0.35), nil, function()
			b:Spike("Antenna", V(0.2, 4.05, -0.35), V(0.5, 4.85, -0.05), 0.16, 0.12, "Body")
			b:Spike("AntennaTip", V(0.47, 4.76, -0.07), V(0.75, 5.1, -0.42), 0.16, 0.05, "Body", THIN, UP)
		end)
	end)
end

-- Rock ------------------------------------------------------------------------------------------

-- Living rock with two strong arms flexing big fists, heavy brows and a toothy grin.
Designs["Pebbit"] = function(b)
	local bumps = { 0.9, 1.04, 0.96, 1.07, 0.97, 1.03, 1.0, 1.05, 0.95, 1.04, 0.99, 0.95 }
	local body = rock(b, "Body", V(2.4, 2.4, 2.25), V(0, 1.14, 0), nil, bumps, function(index)
		return if index % 3 == 0 then "Accent" else "Body"
	end)
	b:SetCore(body)
	b:Eyes(body, 0.42, 0.3, V(0.44, 0.42, 0.24), "White", "Angry")
	b:Mouth(body, -0.28, 0.7, true)
	-- Gritted teeth along the top of the grin.
	b:Tri("Teeth", onFront(b, body, -0.3, 0.98, 0.07), onFront(b, body, 0.3, 0.98, 0.07), onFront(b, body, 0, 0.84, 0.09), "White", THIN)

	b:MirrorBone("Arm", V(1.0, 1.15, 0.0), { Phase = 0.5 }, function()
		b:Limb("UpperArm", V(0.85, 1.1, 0.0), V(1.95, 1.3, -0.1), 0.72, "Body", { RingAt = 0.5, Thickness = 0.06 })
		b:Limb("Forearm", V(1.85, 1.2, -0.1), V(2.0, 2.0, -0.6), 0.62, "Body", THIN)
		b:Ball("Fist", V(0.82, 0.82, 0.75), V(2.02, 2.15, -0.68), nil, "Body", { Detail = 1 })
	end)
end

-- Boulder shell with a craggy top, a stubby reptile head and thick clawed limbs.
Designs["Bouldron"] = function(b)
	local bumps = { 1.12, 0.94, 1.14, 0.96, 1.12, 0.95, 1.06, 0.97, 1.08, 0.98, 1.05, 0.8 }
	local shell = rock(b, "Shell", V(3.0, 2.6, 2.8), V(0, 1.65, 0.25), V(0, 36, 0), bumps, function(index)
		return if index % 3 == 1 then "Accent" else "Body"
	end)
	b:SetCore(shell)
	-- Rocky crags on the shell.
	for index, spec in { { V(0.6, 2.65, 0.5), V(0.85, 3.1, 0.7) }, { V(-0.6, 2.65, 0.5), V(-0.85, 3.1, 0.7) } } do
		b:Cone("Crag" .. index, spec[1], spec[2], 0.55, "Accent", { Sides = 3, Thickness = 0.06 })
	end

	b:MirrorBone("Leg", V(0.9, 0.8, 0.2), nil, function()
		b:Limb("Leg", V(0.9, 1.0, 0.2), V(0.98, 0.1, 0.05), 0.85, "Belly", THIN)
		-- Stumpy wedge foot with the ridge on top.
		b:Spike("Foot", V(0.98, 0.24, 0.3), V(0.98, 0.1, -0.62), 0.8, 0.5, "Belly", THIN, UP)
	end)
	b:MirrorBone("Arm", V(1.3, 1.95, -0.5), { Phase = 0.5 }, function()
		b:Limb("Arm", V(1.2, 2.0, -0.45), V(1.9, 1.0, -0.95), 0.72, "Belly", { RingAt = 0.55, Sides = 4, Thickness = 0.06 })
		for index, offset in { V(-0.2, 0, 0.06), V(0.0, 0, -0.08), V(0.2, 0, 0.06) } do
			b:Spike("Claw" .. index, V(1.88, 1.12, -0.95) + offset, V(1.92, 0.78, -1.22) + offset * 1.4, 0.2, 0.14, "White", THIN)
		end
	end)

	b:Bone("Head", V(0, 1.95, -0.95), nil, function()
		local head = b:Ball("Head", V(1.3, 1.05, 1.2), V(0, 1.95, -1.45), nil, "Belly", { Detail = 1 })
		b:Spike("Brow", V(0, 2.3, -1.25), V(0, 2.4, -2.1), 1.05, 0.32, "Belly", nil, UP)
		b:Eyes(head, 0.3, 0.02, V(0.26, 0.24, 0.2), Color3.fromRGB(200, 40, 40), "Angry")
		b:Mouth(head, -0.28, 0.42)
	end)
end

-- Fox line ----------------------------------------------------------------------------------------

-- Fox cub with a curly orange forelock and six curly tails.
Designs["Emberfox"] = function(b)
	local body = b:Ball("Body", V(1.3, 1.2, 1.95), V(0, 0.86, 0.15), nil, "Body", { Detail = 1 })
	b:SetCore(body)
	for index, z in { -0.32, 0.72 } do
		b:MirrorBone(if index == 1 then "LegFront" else "LegBack", V(0.36, 0.65, z), { Phase = if index == 1 then 0 else 0.5 }, function()
			b:Spike("Leg", V(0.36, 0.8, z), V(0.38, 0.0, z - 0.06), 0.42, 0.36, "Body", THIN)
		end)
	end

	-- Six curly tails fanning out behind (each its own bone so they sway one after the other).
	for index = 1, 6 do
		local a = math.rad(-70 + (index - 1) * 28)
		local base = V(0, 1.03, 0.9)
		local dir = V(math.sin(a), math.cos(a) * 0.95, 0.5).Unit
		local tip = base + dir * 1.6 + V(0, 0.1, -0.3)
		b:Bone("Tail" .. index, base, { Phase = index / 6, Amp = 0.6 }, function()
			plume(b, "Tail", base + dir * 0.1, tip, 0.46, 0.2, V(0, 0, -1), "Body", "Accent", 0.6)
		end)
	end

	b:Bone("Head", V(0, 1.18, -0.35), nil, function()
		local head = b:Ball("Head", V(1.55, 1.35, 1.35), V(0, 1.68, -0.62), nil, "Body")
		local muzzle = b:Ball("Muzzle", V(0.6, 0.42, 0.45), V(0, 1.46, -1.2), nil, "Belly", { Detail = 0 })
		b:Eyes(head, 0.38, 0.06, V(0.34, 0.42, 0.22), Color3.fromRGB(110, 50, 20))
		b:FaceDot("Nose", muzzle, 0, 0.06, V(0.16, 0.12, 0.12), "Black")
		-- Curly forelock: three orange locks falling over the forehead.
		b:Spike("Curl", V(0, 2.38, -0.7), V(0, 2.06, -1.32), 0.5, 0.34, "Accent", THIN, UP)
		b:MirrorSpike("CurlSide", V(0.25, 2.33, -0.7), V(0.48, 2.03, -1.24), 0.42, 0.28, "Accent", THIN, UP)
		b:MirrorBone("Ear", V(0.45, 2.18, -0.6), nil, function()
			b:Spike("Ear", V(0.42, 2.13, -0.6), V(0.98, 3.08, -0.45), 0.66, 0.3, "Body", THIN, V(0, 0, 1))
			b:Spike("EarInner", V(0.47, 2.25, -0.74), V(0.9, 2.93, -0.6), 0.38, 0.05, "Extra", THIN)
		end)
	end)
end

-- Elegant fox with a fluffy ruff, a swept-back crest and nine orange-tipped tails.
Designs["Novafox"] = function(b)
	local body = b:Ball("Body", V(1.3, 1.2, 2.1), V(0, 1.5, 0.35), nil, "Body", { Detail = 1 })
	b:SetCore(body)
	b:Limb("Neck", V(0, 1.55, -0.3), V(0, 2.75, -0.75), 0.62, "Body")
	-- Fluffy ruff on the chest.
	b:Spike("Ruff", V(0, 2.25, -0.62), V(0, 1.3, -1.02), 0.72, 0.42, "Body", THIN, FRONT)
	b:MirrorSpike("RuffSide", V(0.2, 2.15, -0.58), V(0.3, 1.45, -0.92), 0.55, 0.34, "Body", THIN, V(0.3, 0, -1))
	for index, z in { -0.3, 0.95 } do
		b:MirrorBone(if index == 1 then "LegFront" else "LegBack", V(0.38, 1.3, z), { Phase = if index == 1 then 0 else 0.5 }, function()
			b:Spike("Leg", V(0.38, 1.45, z), V(0.42, 0.0, z - 0.08), 0.42, 0.34, "Body", THIN)
		end)
	end

	for index = 1, 9 do
		local a = math.rad(-95 + (index - 1) * 23.75)
		local base = V(0, 1.7, 1.25)
		local dir = V(math.sin(a), math.cos(a) * 0.85 + 0.1, 0.7).Unit
		local tip = base + dir * 2.1
		b:Bone("Tail" .. index, base, { Phase = index / 9, Amp = 0.5 }, function()
			plume(b, "Tail", base + dir * 0.1, tip, 0.55, 0.22, V(0, 0, -1), "Body", "Accent", 0.72)
		end)
	end

	b:Bone("Head", V(0, 2.6, -0.7), nil, function()
		local head = b:Ball("Head", V(1.32, 1.15, 1.3), V(0, 2.95, -0.9), nil, "Body")
		b:Spike("Snout", V(0, 2.76, -1.32), V(0, 2.64, -1.8), 0.62, 0.42, "Body", THIN, UP)
		b:Eyes(head, 0.32, 0.1, V(0.3, 0.34, 0.22), Color3.fromRGB(210, 40, 50))
		b:FaceDot("Nose", head, 0, -0.3, V(0.12, 0.1, 0.1), "Black")
		-- Swept-back crest: a tuft rising from the forehead and a lock flowing back.
		b:Spike("Crest", V(0, 3.3, -1.0), V(0, 4.05, -0.6), 0.44, 0.3, "Body", THIN, FRONT)
		b:Spike("CrestBack", V(0, 3.35, -0.8), V(0, 3.75, 0.25), 0.4, 0.28, "Body", THIN, UP)
		b:MirrorBone("Ear", V(0.38, 3.25, -0.8), nil, function()
			b:Spike("Ear", V(0.36, 3.2, -0.8), V(0.78, 4.1, -0.62), 0.52, 0.26, "Body", THIN, V(0, 0, 1))
		end)
	end)
end

-- Sea ---------------------------------------------------------------------------------------------

-- Gentle sea creature: long neck with a cream front, curled horn, grey studded shell, four paddle flippers.
Designs["Lagoonie"] = function(b)
	local body = b:Ball("Body", V(2.5, 1.5, 2.8), V(0, 0.85, 0.35), nil, "Body", { Detail = 1 })
	b:SetCore(body)
	b:Ball("Shell", V(2.5, 1.3, 2.5), V(0, 1.45, 0.6), nil, "Accent", { Detail = 1 })
	for index, spec in
		{
			{ V(0.5, 1.95, 0.3), V(0.58, 2.3, 0.35) },
			{ V(-0.5, 1.95, 0.3), V(-0.58, 2.3, 0.35) },
			{ V(0.45, 1.85, 1.1), V(0.52, 2.15, 1.25) },
			{ V(-0.45, 1.85, 1.1), V(-0.52, 2.15, 1.25) },
		}
	do
		b:Spike("Knob" .. index, spec[1], spec[2], 0.48, 0.42, "Extra", nil, V(0, 0, 1))
	end

	-- Paddle flippers (they row while it walks).
	for index, spec in { { V(0.85, 0.65, -0.45), V(2.05, 0.06, -1.0), 0.85 }, { V(0.8, 0.6, 1.1), V(1.8, 0.06, 1.7), 0.7 } } do
		b:MirrorBone(if index == 1 then "FinFront" else "FinBack", spec[1], { Phase = if index == 1 then 0 else 0.5 }, function()
			plume(b, "Flipper", spec[1] - V(0.15, 0, 0), spec[2], spec[3], 0.2, UP, "Body", "Body", 0.5)
		end)
	end

	b:Bone("Neck", V(0, 1.1, -0.75), { Role = "Tail", Amp = 0.25 }, function()
		local neck = serpentRings({ V(0, 0.95, -0.65), V(0, 2.0, -1.1), V(0, 2.95, -1.05) }, { 0.58, 0.47, 0.42 }, 4, FRONT)
		serpentPart(b, "Neck", neck, 1, 3, bellyFacing(V(0, 0, -1)))
		b:Bone("Head", V(0, 2.9, -1.05), nil, function()
			local head = b:Ball("Head", V(1.45, 1.25, 1.6), V(0, 3.4, -1.3), nil, "Body")
			b:Eyes(head, 0.36, 0.08, V(0.34, 0.42, 0.24), "Black")
			b:Mouth(head, -0.34, 0.36)
			-- Horn curling backwards.
			b:Spike("Horn", V(0, 3.9, -1.38), V(0, 4.45, -1.3), 0.34, 0.28, "Body", THIN, FRONT)
			b:Spike("HornTip", V(0, 4.36, -1.3), V(0, 4.6, -0.95), 0.24, 0.2, "Body", THIN, UP)
			-- Ear flaps swept back.
			b:MirrorBone("Ear", V(0.55, 3.6, -1.1), nil, function()
				b:Spike("Ear", V(0.5, 3.6, -1.1), V(1.05, 3.85, -0.6), 0.46, 0.1, "Body", THIN, V(0, 1, -0.4))
			end)
		end)
	end)
end

return Designs
