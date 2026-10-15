--[[
	Critter designs: Sproutle, Bloomtoad, Floradon, Embit, Emberclaw, Blazewing, Puffloon, Puffluxe.
	See CritterBuilder for the toolkit. Ground at y = 0, the critter faces -Z.
	Every surface is made of triangles (only the eyes and the mouth are round) and every moving part is a bone.
	Local helpers sculpt low-poly balls (snouts, pear bodies) and paint some of their facets (bellies) without
	extra parts; small or pointed shapes use thin plates (THIN) so that no plate pokes through a tip.
]]

local V = Vector3.new

local Designs = {}

local SEED_EYE = Color3.fromRGB(215, 50, 60)
local FIRE_EYE = Color3.fromRGB(40, 110, 140)
local PUFF_EYE = Color3.fromRGB(40, 150, 175)
local BARK = Color3.fromRGB(150, 100, 65)
local EAR_DARK = Color3.fromRGB(70, 40, 55)

local UP = V(0, 1, 0)
-- Thin plates for small or pointed shapes (thick plates poke through the facets near the tips).
local THIN = { Thickness = 0.06 }

-- Geometry helpers ----------------------------------------------------------------------------

-- Unit low-poly ball, same vertices and facets as the toolkit's Ball: detail 2 = icosahedron (20 facets),
-- 1 = 16 facets, 0 = octahedron (8 facets). A vertex on top, the first ring vertex at the front (-Z).
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
			local angle = (i + ring * 0.5) * math.pi * 2 / n
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

--[[
	Low-poly ball like b:Ball (same part cost) that can be sculpted and painted facet by facet.
	opts.Detail (default 2); opts.Deform(v) moves the unit vertices (|v| = 1, -Z = front) before scaling;
	opts.Paint(normal, centre) returns the colour of a facet (nil = `color`), both in the unit space.
	Returns a handle that covers every facet (for the face helpers). Not for use inside mirrored bones.
]]
local function sculpt(b, name: string, size: Vector3, position: Vector3, rot: Vector3?, color: any, opts: any?)
	local options = opts or {}
	local unit, faces = ballData(options.Detail or 2)
	local frame = CFrame.new(position)
	if rot then
		frame *= CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	end
	local shaped, vertices = {}, {}
	for index, v in unit do
		shaped[index] = if options.Deform then options.Deform(v) else v
		vertices[index] = frame:PointToWorldSpace(shaped[index] * size / 2)
	end
	local groups, order = {}, {}
	for _, face in faces do
		local a, c, d = shaped[face[1]], shaped[face[2]], shaped[face[3]]
		local centre = (a + c + d) / 3
		local normal = (c - a):Cross(d - a).Unit
		if normal:Dot(centre) < 0 then
			normal = -normal
		end
		local paint = (options.Paint and options.Paint(normal, centre)) or color
		if not groups[paint] then
			groups[paint] = {}
			table.insert(order, paint)
		end
		table.insert(groups[paint], face)
	end
	local tris, first = {}, nil
	for index, paint in order do
		local handle = b:Mesh(name .. (if index > 1 then tostring(index) else ""), vertices, groups[paint], paint)
		first = first or handle.Part
		for _, triangle in handle.Tris do
			table.insert(tris, triangle)
		end
	end
	return { Part = first, Center = position, Size = size, Tris = tris }
end

-- Facet painter for sculpt: the belly (front-lower facets).
local function bellyPaint(color: any)
	return function(normal: Vector3, _centre: Vector3)
		if normal.Z < -0.55 and math.abs(normal.X) < 0.5 and normal.Y < 0.3 then
			return color
		end
		return nil
	end
end

-- Snout: pushes the lower front vertices of a ball forwards (jaw), the chin a little, and with `bridge`
-- the upper front vertex too (a long dragon snout).
local function snout(forward: number, narrow: number?, lift: number?, bridge: number?)
	return function(v: Vector3): Vector3
		if v.Z < -0.5 and v.Y < 0 then
			return V(v.X * (narrow or 1), v.Y + (lift or 0), v.Z - forward)
		elseif v.Y < -0.99 then
			return V(v.X, v.Y, v.Z - forward * 0.45)
		elseif bridge and v.Z < -0.85 and v.Y > 0 then
			return V(v.X, v.Y - bridge * 0.4, v.Z - bridge)
		end
		return v
	end
end

-- Pear-shaped upright body (wider at the hips) whose chest vertex is raised, so that the painted belly
-- reaches from the neck down to the legs.
local function lizardBody(taper: number, chest: number)
	return function(v: Vector3): Vector3
		local shaped = V(v.X * (1 - v.Y * taper), v.Y, v.Z * (1 - v.Y * taper * 0.7))
		if v.Y > 0.2 and v.Y < 0.9 then
			-- Broad shoulders: the head and the arms sit on them.
			shaped = V(shaped.X * 1.1, v.Y + 0.1, shaped.Z * 1.05)
		end
		if v.Z < -0.85 and v.Y > 0 then
			shaped = V(shaped.X, v.Y + chest, shaped.Z - 0.05)
		end
		return shaped
	end
end

--[[
	Pointed ear from `base` (sunk in the head) to `tip`: a flat front face and a ridge at the back (6 parts),
	or with folded = true only the two back faces (a cupped ear, 4 parts). inner = colour of the inside,
	a smaller triangle lying on the front face. Works inside mirrored bones (give the right side).
]]
local function ear(b, name: string, base: Vector3, tip: Vector3, width: number, depth: number, color: any, inner: any?, folded: boolean?)
	local axis = (tip - base).Unit
	local front = V(0, 0, -1)
	front = (front - axis * front:Dot(axis)).Unit
	local across = axis:Cross(front).Unit * (width / 2)
	local left = base - across + front * (depth * 0.4)
	local right = base + across + front * (depth * 0.4)
	local ridge = base - front * (depth * 0.6)
	local faces = if folded then { { 2, 4, 3 }, { 4, 1, 3 } } else { { 1, 2, 3 }, { 2, 4, 3 }, { 4, 1, 3 } }
	b:Mesh(name, { left, right, tip, ridge }, faces, color, THIN)
	if inner then
		local centre = (left + right + tip) / 3
		local normal = (right - left):Cross(tip - left).Unit
		if normal:Dot(front) < 0 then
			normal = -normal
		end
		local lift = normal * 0.035
		b:Tri(
			name .. "Inner",
			left:Lerp(centre, 0.4) + lift,
			right:Lerp(centre, 0.4) + lift,
			tip:Lerp(centre, 0.3) + lift,
			inner,
			{ Thickness = 0.04 }
		)
	end
end

-- Nearest facet of a shape hit by a ray: point and outward normal (handle.Tris are in design space).
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

-- Flat right-angled triangle (1 part) lying on a surface at `point` facing `normal` (spots, patches).
local function flatSpot(b, name: string, point: Vector3, normal: Vector3, radius: number, spin: number, color: any, stretch: number?)
	local up = if math.abs(normal.Y) > 0.9 then V(0, 0, -1) else UP
	local frame = CFrame.lookAt(point + normal * 0.03, point + normal * 1.03, up) * CFrame.Angles(0, 0, math.rad(spin))
	local corner = frame:PointToWorldSpace(V(-radius * 0.6 * (stretch or 1), -radius * 0.6, 0))
	local a = corner + frame.RightVector * (radius * 1.8 * (stretch or 1))
	local c = corner + frame.UpVector * (radius * 1.8)
	b:Tri(name, corner, a, c, color, { Thickness = 0.05 })
end

-- Flat triangle on the facet that `handle` shows towards `direction`. Not for use inside mirrored bones.
local function patch(b, name: string, handle, direction: Vector3, radius: number, spin: number, color: any, stretch: number?)
	local point, normal = cast(handle, handle.Center, direction.Unit)
	if point and normal then
		flatSpot(b, name, point, normal, radius, spin, color, stretch)
	end
end

--[[
	Closed shape turned around a vertical axis (bulbs, buds, balloon bodies): rings of `n` vertices, each
	turned half a step from the previous one (antiprism: every facet is a triangle), between a bottom and a
	top point. rings = { { height, radiusX, radiusZ? }, ... } from the bottom up, relative to `base`.
	colors = one entry per band (bottom fan, each gap between rings, top fan): a colour, nil (band not built,
	hidden inside the body) or { Alt = { a, b } } to alternate the up / down triangles (stripes); or a
	function(band, centre) -> colour? (centre of the facet relative to `base`).
	lean shifts every point by lean * height (a bent tip). Returns a handle covering every facet.
]]
local function lathe(
	b,
	name: string,
	base: Vector3,
	bottom: number,
	rings: { { number } },
	top: number,
	n: number,
	colors: any,
	lean: Vector3?,
	twist: number?
)
	local shear = lean or Vector3.zero
	local vertices = { base + V(0, bottom, 0) + shear * bottom }
	local starts = {}
	for r, ring in rings do
		starts[r] = #vertices + 1
		local h, rx = ring[1], ring[2]
		local rz = ring[3] or rx
		for k = 0, n - 1 do
			local angle = (k + (r - 1) * 0.5 + (twist or 0)) * math.pi * 2 / n
			table.insert(vertices, base + V(math.sin(angle) * rx, h, -math.cos(angle) * rz) + shear * h)
		end
	end
	local tip = #vertices + 1
	table.insert(vertices, base + V(0, top, 0) + shear * top)

	local groups = {}
	local function add(band: number, alternate: number, face: { number })
		local spec
		if type(colors) == "function" then
			spec = colors(band, (vertices[face[1]] + vertices[face[2]] + vertices[face[3]]) / 3 - base)
		else
			spec = colors[band]
			if type(spec) == "table" and spec.Alt then
				spec = spec.Alt[alternate]
			end
		end
		if spec == nil then
			return
		end
		for _, group in groups do
			if group.Color == spec then
				table.insert(group.Faces, face)
				return
			end
		end
		table.insert(groups, { Color = spec, Faces = { face } })
	end
	local last = #rings
	for k = 0, n - 1 do
		local k1 = (k + 1) % n
		add(1, 1 + k % 2, { 1, starts[1] + k1, starts[1] + k })
		add(last + 1, 1 + k % 2, { starts[last] + k, starts[last] + k1, tip })
		for r = 1, last - 1 do
			local a, c = starts[r], starts[r + 1]
			add(r + 1, 1, { a + k, a + k1, c + k })
			add(r + 1, 2, { c + k, c + k1, a + k1 })
		end
	end
	local tris, first = {}, nil
	local low, high = vertices[1], vertices[1]
	for _, v in vertices do
		low = V(math.min(low.X, v.X), math.min(low.Y, v.Y), math.min(low.Z, v.Z))
		high = V(math.max(high.X, v.X), math.max(high.Y, v.Y), math.max(high.Z, v.Z))
	end
	for index, group in groups do
		local handle = b:Mesh(name .. (if index > 1 then tostring(index) else ""), vertices, group.Faces, group.Color)
		first = first or handle.Part
		for _, triangle in handle.Tris do
			table.insert(tris, triangle)
		end
	end
	return { Part = first, Center = (low + high) / 2, Size = high - low, Tris = tris }
end

-- Leaf / petal: two flat triangles folded along the midrib from `base` to `tip`. `up` is the side the
-- leaf faces, `fold` lifts its edges (cupped leaf), `widest` is where it is widest (0..1).
local function leaf(b, name: string, base: Vector3, tip: Vector3, width: number, up: Vector3, fold: number, color: any, widest: number?)
	local axis = tip - base
	local across = axis:Cross(up).Unit * (width / 2)
	local mid = base + axis * (widest or 0.45) + up.Unit * fold
	b:Tri(name .. "A", base, mid + across, tip, color, { Thickness = 0.08 })
	b:Tri(name .. "B", base, tip, mid - across, color, { Thickness = 0.08 })
end

-- Small white claws fanned around `at`, pointing along `direction`: right-angled flat triangles (1 part each).
local function claws(b, at: Vector3, direction: Vector3, count: number, spread: number, size: number)
	local across = direction:Cross(UP).Unit
	for index = 1, count do
		local offset = (index - (count + 1) / 2) * spread
		local base = at + V(offset, 0, 0) - across * (size * 0.25)
		local along = (direction + V(offset * 0.5, 0, 0)).Unit
		local side = along:Cross(UP).Unit
		b:Tri("Claw" .. index, base, base + along * size, base + side * (size * 0.5), "White", { Thickness = 0.05 })
	end
end

-- Seed toads (Sproutle family) -----------------------------------------------------------------

-- Four short thick legs, one bone each: diagonal pairs trot together. Each leg is a spindle widest low
-- down (a vertex of its ring points forwards: the toe). clawSize > 0 adds white claws on the front toes.
local function toadLegs(b, frontZ: number, backZ: number, spacing: number, hipY: number, thickness: number, clawSize: number?)
	for index, z in { frontZ, backZ } do
		local name = if index == 1 then "LegFront" else "LegBack"
		b:MirrorBone(name, V(spacing, hipY, z), { Phase = if index == 1 then 0 else 0.5 }, function()
			local top, bottom = V(spacing - 0.24, hipY + 0.25, z + 0.05), V(spacing + 0.05, 0.05, z - 0.1)
			b:Limb("Leg", top, bottom, thickness, "Body", { RingAt = 0.72, Thickness = 0.07 })
			if index == 1 and clawSize and clawSize > 0 then
				local toe = top:Lerp(bottom, 0.72) + V(0, 0, -thickness * 0.62 * 0.75)
				claws(b, toe, V(0, -0.7, -1).Unit, 3, thickness * 0.24, clawSize)
			end
		end)
	end
end

-- Pointed ears on the head (Ear bones), folded = cupped ear (cheaper).
local function toadEars(b, root: Vector3, tip: Vector3, width: number, depth: number, folded: boolean?)
	b:MirrorBone("Ear", root, nil, function()
		ear(b, "Ear", root - V(0.05, 0.12, 0), tip, width, depth, "Body", nil, folded)
	end)
end

-- Seed toad with a leafy garlic bulb on its back (Bulbasaur-like).
Designs["Sproutle"] = function(b)
	local body = sculpt(b, "Body", V(2.05, 1.4, 2.3), V(0, 0.95, 0.4), nil, "Body", { Detail = 1 })
	b:SetCore(body)
	patch(b, "SpotA", body, V(0.8, 0.35, 0.3), 0.24, 20, "Extra")
	patch(b, "SpotB", body, V(-0.8, 0.45, 0.6), 0.22, 70, "Extra")

	-- The bulb: green leaves wrapped around it (alternating shades), a point on top bent backwards.
	lathe(b, "Bulb", V(0, 1.15, 0.6), 0, { { 0.5, 0.9 }, { 1.05, 0.66 } }, 1.65, 5, {
		"Accent",
		{ Alt = { "Accent", "Extra" } },
		{ Alt = { "Extra", "Accent" } },
	}, V(0, 0, 0.14))

	toadLegs(b, -0.25, 1.0, 0.75, 0.75, 0.62)

	b:Bone("Head", V(0, 1.3, -0.4), nil, function()
		local head = sculpt(b, "Head", V(2.4, 1.65, 1.8), V(0, 1.5, -0.85), nil, "Body", { Deform = snout(0.12, 1.05) })
		b:Eyes(head, 0.6, 0.1, V(0.5, 0.56, 0.22), SEED_EYE)
		b:Mouth(head, -0.3, 0.7, true)
		patch(b, "SpotHead", head, V(-0.35, 0.8, -0.4), 0.2, 0, "Extra")
		toadEars(b, V(0.72, 2.15, -0.85), V(1.08, 2.78, -0.82), 0.55, 0.3, true)
	end)
end

-- Bigger toad whose bulb has opened into a pink bud over four big leaves (Ivysaur-like).
Designs["Bloomtoad"] = function(b)
	local body = sculpt(b, "Body", V(2.3, 1.5, 2.5), V(0, 1.05, 0.45), nil, "Body", { Detail = 1 })
	b:SetCore(body)
	patch(b, "SpotA", body, V(0.8, 0.35, 0.3), 0.26, 20, "Extra")
	patch(b, "SpotB", body, V(-0.8, 0.45, 0.6), 0.24, 70, "Extra")

	-- Pink bud wrapped in green sepals.
	lathe(b, "Bud", V(0, 1.55, 0.55), 0, { { 0.45, 0.62 }, { 0.95, 0.5 } }, 1.5, 5, {
		"Extra",
		{ Alt = { "Extra", "Accent" } },
		"Accent",
	})
	-- Four big leaves fanned out under the bud (they sway).
	for index, dz in { -1, 1 } do
		local z = 0.55 + dz * 0.3
		b:MirrorBone(if index == 1 then "WingLeafFront" else "WingLeafBack", V(0.3, 2.0, z), { Phase = index * 0.25, Amp = 0.8 }, function()
			leaf(b, "Leaf", V(0.15, 2.05, z - dz * 0.15), V(2.1, 1.6, z + dz * 1.0), 1.1, UP, 0.2, "Extra")
		end)
	end

	toadLegs(b, -0.3, 1.1, 0.82, 0.8, 0.7)

	b:Bone("Head", V(0, 1.4, -0.45), nil, function()
		local head = sculpt(b, "Head", V(2.55, 1.75, 1.9), V(0, 1.65, -1.0), nil, "Body", { Deform = snout(0.15, 1.05) })
		b:Eyes(head, 0.62, 0.1, V(0.48, 0.5, 0.22), SEED_EYE, "Angry")
		b:Mouth(head, -0.3, 0.74, true)
		patch(b, "SpotHead", head, V(-0.35, 0.8, -0.4), 0.22, 0, "Extra")
		toadEars(b, V(0.8, 2.3, -0.95), V(1.25, 3.05, -0.9), 0.6, 0.32, true)
	end)
end

-- Huge flower toad: a palm of leaves and an open five-petal flower on a stubby trunk (Venusaur-like).
Designs["Floradon"] = function(b)
	local body = sculpt(b, "Body", V(3.0, 1.9, 3.0), V(0, 1.25, 0.5), nil, "Body", { Detail = 1 })
	b:SetCore(body)
	patch(b, "SpotA", body, V(0.8, 0.35, 0.3), 0.3, 20, "Extra")
	patch(b, "SpotB", body, V(-0.8, 0.45, 0.6), 0.28, 70, "Extra")

	b:Cone("Trunk", V(0, 1.9, 0.55), V(0, 3.05, 0.6), 0.5, BARK, { Sides = 4 })
	-- Palm leaves drooping over the body (they sway).
	for index, dz in { -1, 1 } do
		local z = 0.55 + dz * 0.3
		b:MirrorBone(
			if index == 1 then "WingLeafFront" else "WingLeafBack",
			V(0.3, 2.45, z),
			{ Phase = index * 0.25, Amp = 0.7 },
			function()
				leaf(b, "Leaf", V(0.1, 2.5, z - dz * 0.1), V(2.35, 1.7, z + dz * 1.2), 1.3, UP, 0.25, "Extra")
			end
		)
	end
	-- The flower: five big cupped petals with white spots around a yellow heart.
	local heart = V(0, 2.85, 0.6)
	for index = 1, 5 do
		local angle = math.rad((index - 1) * 72 + 36)
		local out = V(math.sin(angle), 0, -math.cos(angle))
		local tip = heart + out * 1.95 - V(0, 0.05, 0)
		local up = (UP - out * 0.25).Unit
		leaf(b, "Petal" .. index, heart - out * 0.1, tip, 1.4, up, 0.18, "Accent", 0.55)
		flatSpot(b, "PetalSpot" .. index, heart + out * 1.1 + up * 0.08, up, 0.2, math.deg(angle), "White", 1.4)
	end
	b:Cone("Heart", heart - V(0, 0.1, 0), heart + V(0, 0.5, 0), 0.45, "Belly", { Sides = 5 })

	toadLegs(b, -0.45, 1.35, 0.98, 0.95, 0.85, 0.3)

	b:Bone("Head", V(0, 1.45, -0.6), nil, function()
		local head = sculpt(b, "Head", V(2.7, 1.75, 1.95), V(0, 1.55, -1.3), nil, "Body", { Deform = snout(0.18, 1.05) })
		b:Eyes(head, 0.66, 0.12, V(0.44, 0.46, 0.22), SEED_EYE, "Angry")
		b:Mouth(head, -0.3, 0.86, true)
		patch(b, "SpotHead", head, V(-0.35, 0.8, -0.4), 0.24, 0, "Extra")
		toadEars(b, V(0.85, 2.2, -1.25), V(1.2, 2.75, -1.25), 0.5, 0.3)
	end)
end

-- Fire lizards (Embit family) ------------------------------------------------------------------

-- Two short legs, each with a pointed foot.
local function lizardLegs(b, hipY: number, spacing: number, thickness: number, footLength: number)
	b:MirrorBone("Leg", V(spacing, hipY, 0.12), nil, function()
		b:Limb(
			"Leg",
			V(spacing - 0.03, hipY + 0.25, 0.15),
			V(spacing + 0.05, 0.08, 0.0),
			thickness,
			"Body",
			{ RingAt = 0.55, Thickness = 0.06 }
		)
		b:Spike(
			"Foot",
			V(spacing + 0.05, 0.13, 0.12),
			V(spacing + 0.08, 0.06, -footLength),
			thickness * 0.9,
			thickness * 0.5,
			"Body",
			THIN,
			UP
		)
	end)
end

-- Two arms from the shoulders; clawSize > 0 adds white claws at the hands (3 unless clawCount).
local function lizardArms(b, shoulder: Vector3, hand: Vector3, thickness: number, clawSize: number?, clawCount: number?)
	b:MirrorBone("Arm", shoulder, { Phase = 0.5 }, function()
		b:Limb("Arm", shoulder - V(0.08, -0.05, -0.05), hand, thickness, "Body", THIN)
		if clawSize and clawSize > 0 then
			claws(b, hand + V(0, 0.02, 0.05), V(0.1, -0.45, -1).Unit, clawCount or 3, 0.1, clawSize)
		end
	end)
end

-- Tail from inside the body curving up behind, a flame burning at its tip (one Tail bone).
local function flameTail(b, pivot: Vector3, points: { Vector3 }, radii: { number }, flame: number)
	b:Bone("Tail", pivot, nil, function()
		b:Tube("Tail", points, radii, "Body", { Thickness = 0.08 })
		b:Flame("TailFlame", points[#points] - V(0, 0.08, 0), flame)
	end)
end

-- Little fire lizard with a flame on its tail (Charmander-like).
Designs["Embit"] = function(b)
	local body = sculpt(b, "Body", V(1.5, 1.7, 1.35), V(0, 1.15, 0.12), nil, "Body", {
		Detail = 1,
		Deform = lizardBody(0.1, 0.22),
		Paint = bellyPaint("Belly"),
	})
	b:SetCore(body)

	lizardLegs(b, 0.8, 0.42, 0.6, 0.45)
	lizardArms(b, V(0.55, 1.55, -0.1), V(0.95, 1.12, -0.52), 0.4, 0.16, 2)
	b:Bone("Head", V(0, 1.8, -0.05), nil, function()
		local head = sculpt(b, "Head", V(1.75, 1.55, 1.6), V(0, 2.47, -0.22), nil, "Body", { Deform = snout(0.32, 0.9, 0.06, 0.06) })
		b:Eyes(head, 0.42, 0.2, V(0.4, 0.58, 0.22), FIRE_EYE)
		b:Mouth(head, -0.28, 0.42, true)
	end)
	flameTail(b, V(0, 0.85, 0.6), { V(0, 0.95, 0.3), V(0, 0.62, 0.95), V(0, 0.78, 1.6), V(0, 1.3, 1.95) }, { 0, 0.34, 0.25, 0 }, 0.5)
end

-- Taller, sharper red lizard with a horn and claws (Charmeleon-like).
Designs["Emberclaw"] = function(b)
	local body = sculpt(b, "Body", V(1.5, 2.1, 1.35), V(0, 1.5, 0.1), nil, "Body", {
		Detail = 1,
		Deform = lizardBody(0.12, 0.25),
		Paint = bellyPaint("Belly"),
	})
	b:SetCore(body)

	lizardLegs(b, 0.9, 0.45, 0.64, 0.55)
	lizardArms(b, V(0.6, 2.0, -0.1), V(1.02, 1.42, -0.58), 0.38, 0.24)
	b:Bone("Head", V(0, 2.4, -0.05), nil, function()
		local head = sculpt(b, "Head", V(1.45, 1.3, 1.75), V(0, 3.05, -0.3), nil, "Body", { Deform = snout(0.45, 0.85, 0.08, 0.15) })
		b:Spike("Horn", V(0, 3.45, 0.15), V(0, 3.75, 1.2), 0.45, 0.32, "Body", THIN, UP)
		b:Eyes(head, 0.34, 0.15, V(0.34, 0.42, 0.2), FIRE_EYE, "Angry")
		b:Mouth(head, -0.3, 0.5, true)
	end)
	flameTail(b, V(0, 1.0, 0.6), { V(0, 1.1, 0.3), V(0, 0.6, 1.1), V(0, 0.7, 1.9), V(0, 1.35, 2.4) }, { 0, 0.36, 0.27, 0 }, 0.7)
end

-- Fire dragon hovering on big bat wings (Charizard-like).
Designs["Blazewing"] = function(b)
	b.Hover = 1.4
	local body = sculpt(b, "Body", V(1.95, 2.45, 1.7), V(0, 1.95, 0.15), nil, "Body", {
		Detail = 1,
		Deform = lizardBody(0.12, 0.25),
		Paint = bellyPaint("Belly"),
	})
	b:SetCore(body)

	-- Dangling legs with thick thighs.
	b:MirrorBone("Leg", V(0.6, 1.3, 0.15), nil, function()
		b:Limb("Leg", V(0.55, 1.6, 0.15), V(0.72, 0.15, -0.15), 0.85, "Body", { RingAt = 0.35, Thickness = 0.08 })
		b:Spike("Foot", V(0.72, 0.22, 0.0), V(0.75, 0.1, -0.6), 0.5, 0.3, "Body", THIN, UP)
	end)
	lizardArms(b, V(0.72, 2.5, -0.2), V(1.2, 1.95, -0.78), 0.36, 0.24, 2)
	-- Wings: a bony leading edge from the shoulder to the wrist, three fingers fanned out and a teal
	-- membrane between them whose trailing edge is scalloped.
	b:MirrorBone("Wing", V(0.5, 2.75, 0.55), nil, function()
		local shoulder, wrist, root = V(0.45, 2.75, 0.6), V(2.0, 4.35, 1.05), V(0.55, 1.95, 0.8)
		local tips = { V(3.2, 3.3, 1.3), V(2.6, 2.15, 1.3), V(1.45, 1.6, 1.05) }
		b:Spike("WingBone", shoulder - V(0.1, 0, 0), wrist + V(0.05, 0.05, 0), 0.34, 0.28, "Body", THIN, V(0, 0, -1))
		local claw = wrist + V(0.02, 0.05, 0)
		b:Tri(
			"WingClaw",
			claw,
			claw + V(0.18, 0.42, 0),
			claw + V(0.18, 0.42, 0):Cross(V(0, 0, 1)).Unit * 0.16,
			"Body",
			{ Thickness = 0.08 }
		)
		local function scallop(a: Vector3, c: Vector3): Vector3
			return wrist + ((a + c) / 2 - wrist) * 0.72
		end
		local edge = { root, scallop(root, tips[3]), tips[3], scallop(tips[3], tips[2]), tips[2], scallop(tips[2], tips[1]), tips[1] }
		for index = 1, #edge - 1 do
			b:Tri("Membrane" .. index, wrist, edge[index], edge[index + 1], "Accent")
		end
		-- Finger bones on the front of the membrane: thin right-angled triangles (1 part each).
		for index, tip in tips do
			local along = tip - wrist
			local normal = along:Cross(edge[2 * (4 - index)] - wrist).Unit
			if normal.Z > 0 then
				normal = -normal
			end
			local side = along:Cross(normal).Unit * 0.13
			b:Tri("Finger" .. index, wrist + normal * 0.07, tip + normal * 0.07, wrist + side + normal * 0.07, "Body", { Thickness = 0.06 })
		end
	end)
	b:Bone("Head", V(0, 2.85, -0.05), nil, function()
		b:Limb("Neck", V(0, 2.5, 0.05), V(0, 3.95, -0.45), 0.8, "Body", { Thickness = 0.08 })
		local head =
			sculpt(b, "Head", V(1.15, 1.0, 1.35), V(0, 4.05, -0.55), nil, "Body", { Detail = 1, Deform = snout(0.55, 0.75, 0.12, 0.35) })
		b:MirrorSpike("Horn", V(0.25, 4.3, -0.4), V(0.42, 4.62, 0.45), 0.24, 0.2, "Body", THIN)
		b:Eyes(head, 0.27, 0.14, V(0.25, 0.3, 0.16), FIRE_EYE, "Angry")
		b:Mouth(head, -0.25, 0.4, false)
	end)
	flameTail(b, V(0, 1.2, 0.75), { V(0, 1.35, 0.45), V(0, 0.8, 1.25), V(0, 0.85, 2.05), V(0, 1.4, 2.6) }, { 0, 0.44, 0.3, 0 }, 0.85)
end

-- Singing balloons (Puffloon family) ------------------------------------------------------------

-- Pointed ears with a dark inside (Ear bones).
local function puffEars(b, root: Vector3, tip: Vector3, width: number)
	b:MirrorBone("Ear", root, nil, function()
		ear(b, "Ear", root - V(0.05, 0.12, 0), tip, width, width * 0.45, "Body", EAR_DARK)
	end)
end

-- Stubby arms and oval feet of the balloons (the feet are sunk into the bottom of the body).
local function puffLimbs(b, shoulder: Vector3, hand: Vector3, armThickness: number, foot: Vector3, footSize: Vector3)
	b:MirrorBone("Arm", shoulder, { Phase = 0.5 }, function()
		b:Limb("Arm", shoulder - V(0.15, -0.05, -0.05), hand, armThickness, "Body", { RingAt = 0.6, Thickness = 0.06 })
	end)
	b:MirrorBone("LegFoot", foot + V(0, footSize.Y * 0.4, 0.2), nil, function()
		b:Ball("Foot", footSize, foot, nil, "Body", { Detail = 0, Thickness = 0.06 })
	end)
end

-- Round pink balloon that floats while it sings, with a curl of hair (Jigglypuff-like).
Designs["Puffloon"] = function(b)
	b.Hover = 1.2
	local r = 1.3
	local body = lathe(b, "Body", V(0, 0.15, 0), 0, { { r * 0.36, r * 0.77 }, { r, r }, { r * 1.64, r * 0.77 } }, r * 2, 6, function()
		return "Body"
	end)
	b:SetCore(body)
	b:Bone("Head", V(0, 2.2, 0), { Amp = 0.5 }, function()
		puffEars(b, V(0.5, 2.45, 0.0), V(1.18, 3.3, 0.1), 0.85)
		-- The curl: a lock of hair rising from the crown, rolling forwards over the forehead and tucking back into it.
		b:Tube("Curl", { V(0, 2.5, -0.12), V(0, 2.84, -0.52), V(0.04, 2.6, -1.02), V(0.06, 2.2, -0.86) }, { 0, 0.3, 0.24, 0 }, "Body", THIN)
	end)
	puffLimbs(b, V(1.05, 1.35, -0.2), V(1.5, 1.12, -0.45), 0.48, V(0.45, 0.36, -0.32), V(0.62, 0.38, 0.85))
	b:Eyes(body, 0.5, 0.15, V(0.64, 0.72, 0.22), PUFF_EYE)
	b:Mouth(body, -0.35, 0.32, true)
end

-- Tall fluffy bunny balloon with long ears and a white tuft (Wigglytuff-like).
Designs["Puffluxe"] = function(b)
	local body = lathe(
		b,
		"Body",
		V(0, 0.06, 0),
		0,
		{ { 0.6, 1.2, 1.05 }, { 1.5, 1.38, 1.2 }, { 2.5, 1.05, 0.95 } },
		3.05,
		6,
		function(_band, centre)
			if centre.Z < -0.55 and centre.Y < 1.5 then
				return "Belly"
			end
			return "Body"
		end
	)
	b:SetCore(body)
	b:Bone("Head", V(0, 2.6, 0), { Amp = 0.5 }, function()
		puffEars(b, V(0.5, 2.85, 0.1), V(1.3, 4.55, 0.25), 0.95)
		-- White tuft: a big hook of fur over the forehead with two smaller locks.
		b:Tube(
			"Tuft",
			{ V(0, 2.95, -0.25), V(0, 3.14, -0.72), V(0.04, 2.8, -1.12), V(0.06, 2.38, -0.86) },
			{ 0, 0.4, 0.3, 0 },
			"Belly",
			THIN
		)
		b:Spike("TuftL", V(-0.2, 2.86, -0.52), V(-0.72, 3.22, -0.86), 0.45, 0.32, "Belly", THIN, UP)
		b:Spike("TuftR", V(0.2, 2.86, -0.52), V(0.7, 3.18, -0.92), 0.45, 0.32, "Belly", THIN, UP)
	end)
	puffLimbs(b, V(1.1, 1.7, -0.25), V(1.6, 1.38, -0.55), 0.5, V(0.52, 0.25, -0.38), V(0.72, 0.5, 0.98))
	b:Eyes(body, 0.52, 0.5, V(0.66, 0.74, 0.22), PUFF_EYE)
	b:Mouth(body, 0.02, 0.42, true)
end

return Designs
