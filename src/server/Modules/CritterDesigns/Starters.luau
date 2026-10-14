--[[
	Critter designs: Sproutle, Bloomtoad, Floradon, Embit, Emberclaw, Blazewing, Puffloon, Puffluxe.
	See CritterBuilder for the toolkit. Ground at y = 0, the critter faces -Z.
	Every surface is made of triangles (only the eyes and the mouth are round) and every moving part is a bone.
]]

local V = Vector3.new

local Designs = {}

local SEED_EYE = Color3.fromRGB(215, 50, 60)
local FIRE_EYE = Color3.fromRGB(40, 110, 140)
local PUFF_EYE = Color3.fromRGB(40, 150, 175)
local BARK = Color3.fromRGB(150, 100, 65)
local EAR_DARK = Color3.fromRGB(75, 45, 60)

local UP = V(0, 1, 0)
local SIDE = V(1, 0, 0)

-- Geometry helpers ----------------------------------------------------------------------------

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

-- Flat triangle lying on the facet that `handle` shows towards `direction` (spots, patches).
-- Call it outside mirrored bones: the handle is already in design space.
local function patch(b, name: string, handle, direction: Vector3, radius: number, spin: number, color: any, stretch: number?)
	local point, normal = cast(handle, handle.Center, direction.Unit)
	if not point or not normal then
		return
	end
	local up = if math.abs(normal.Y) > 0.9 then V(0, 0, -1) else UP
	local frame = CFrame.lookAt(point + normal * 0.03, point + normal * 1.03, up)
	local corners = {}
	for index = 0, 2 do
		local angle = math.rad(spin + index * 120)
		corners[index + 1] = frame:PointToWorldSpace(V(math.cos(angle) * radius * (stretch or 1), math.sin(angle) * radius, 0))
	end
	b:Tri(name, corners[1], corners[2], corners[3], color, { Thickness = 0.05 })
end

--[[
	Closed shape turned around a vertical axis (bulbs, buds, balloon bodies): rings of `n` vertices, each
	turned half a step from the previous one (antiprism: every facet is a triangle), between a bottom and a
	top point. rings = { { height, radiusX, radiusZ? }, ... } from the bottom up, relative to `base`.
	colors = one entry per band (bottom fan, each gap between rings, top fan): a colour, nil (band not built,
	hidden inside the body) or { Alt = { a, b } } to alternate the up / down triangles (stripes).
	lean shifts every point by lean * height (a bent tip). Returns the handle of the first mesh.
]]
local function lathe(b, name: string, base: Vector3, bottom: number, rings: { { number } }, top: number, n: number, colors: { any }, lean: Vector3?, twist: number?)
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
	local function add(spec: any, alternate: number, face: { number })
		if spec == nil then
			return
		end
		local color = spec
		if type(spec) == "table" and spec.Alt then
			color = spec.Alt[alternate]
		end
		for _, group in groups do
			if group.Color == color then
				table.insert(group.Faces, face)
				return
			end
		end
		table.insert(groups, { Color = color, Faces = { face } })
	end
	local last = #rings
	for k = 0, n - 1 do
		local k1 = (k + 1) % n
		add(colors[1], 1 + k % 2, { 1, starts[1] + k1, starts[1] + k })
		add(colors[last + 1], 1 + k % 2, { starts[last] + k, starts[last] + k1, tip })
		for r = 1, last - 1 do
			local a, c = starts[r], starts[r + 1]
			add(colors[r + 1], 1, { a + k, a + k1, c + k })
			add(colors[r + 1], 2, { c + k, c + k1, a + k1 })
		end
	end
	local first = nil
	for index, group in groups do
		local handle = b:Mesh(name .. (if index > 1 then tostring(index) else ""), vertices, group.Faces, group.Color)
		first = first or handle
	end
	return first
end

-- Faceted plate on the front of a body (bellies): a ring of `n` points around an apex pushed forwards.
-- Only the front facets are built (the back is inside the body). tilt leans it back (degrees).
local function shield(b, name: string, center: Vector3, width: number, height: number, bulge: number, n: number, color: any, tilt: number?)
	local frame = CFrame.new(center) * CFrame.Angles(math.rad(tilt or 0), 0, 0)
	local vertices = { frame:PointToWorldSpace(V(0, 0, -bulge)) }
	for k = 0, n - 1 do
		local angle = (k + 0.5) * math.pi * 2 / n
		table.insert(vertices, frame:PointToWorldSpace(V(math.sin(angle) * width / 2, math.cos(angle) * height / 2, 0)))
	end
	table.insert(vertices, frame:PointToWorldSpace(V(0, 0, bulge)))
	local faces = {}
	for k = 0, n - 1 do
		table.insert(faces, { 1, 2 + k, 2 + (k + 1) % n })
	end
	return b:Mesh(name, vertices, faces, color)
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

-- Seed toads (Sproutle family) -----------------------------------------------------------------

-- Four short thick legs, one bone each: diagonal pairs trot together. claws = white claws on the front feet.
local function toadLegs(b, frontZ: number, backZ: number, spacing: number, hipY: number, thickness: number, claws: boolean?)
	for index, z in { frontZ, backZ } do
		local name = if index == 1 then "LegFront" else "LegBack"
		b:MirrorBone(name, V(spacing, hipY, z), { Phase = if index == 1 then 0 else 0.5 }, function()
			b:Limb("Leg", V(spacing - 0.08, hipY + 0.3, z + 0.05), V(spacing + 0.04, 0, z - 0.1), thickness, "Body", { RingAt = 0.72 })
			if claws and index == 1 then
				for c, dx in { -0.16, 0.16 } do
					local base = V(spacing + 0.04 + dx, 0.12, z - 0.1 - thickness * 0.3)
					b:Spike("Claw" .. c, base, base + V(dx * 0.3, -0.1, -0.28), 0.16, 0.04, "White", nil, UP)
				end
			end
		end)
	end
end

-- Big wide toad head with red eyes, pointed ears and a wide mouth (inside the head bone).
local function toadFace(b, head, eyeSpacing: number, eyeSize: Vector3, style: string, mouthWidth: number, open: boolean)
	b:Eyes(head, eyeSpacing, 0.1, eyeSize, SEED_EYE, style)
	b:Mouth(head, -0.42, mouthWidth, open)
end

-- Seed toad with a leafy garlic bulb on its back (Bulbasaur-like).
Designs["Sproutle"] = function(b)
	local body = b:Ball("Body", V(2.1, 1.4, 2.3), V(0, 1.0, 0.4), nil, "Body", { Detail = 1 })
	b:SetCore(body)
	patch(b, "SpotA", body, V(0.8, 0.35, 0.3), 0.24, 20, "Extra")
	patch(b, "SpotB", body, V(-0.8, 0.45, 0.6), 0.22, 70, "Extra")

	-- The bulb: Accent leaves wrapped around it with darker seams, a point on top.
	lathe(b, "Bulb", V(0, 1.2, 0.55), 0, { { 0.55, 0.9 }, { 1.15, 0.6 } }, 1.7, 5, {
		"Accent",
		{ Alt = { "Accent", "Extra" } },
		{ Alt = { "Extra", "Accent" } },
	}, V(0, 0, 0.1))

	toadLegs(b, -0.2, 0.95, 0.72, 0.75, 0.62)

	b:Bone("Head", V(0, 1.35, -0.3), nil, function()
		local head = b:Ball("Head", V(2.4, 1.7, 1.75), V(0, 1.65, -0.9), nil, "Body")
		toadFace(b, head, 0.6, V(0.5, 0.58, 0.22), "Cute", 0.75, true)
		patch(b, "SpotHead", head, V(-0.35, 0.8, -0.4), 0.2, 0, "Extra")
		b:MirrorBone("Ear", V(0.75, 2.25, -0.85), nil, function()
			b:Spike("Ear", V(0.7, 2.15, -0.85), V(1.05, 2.8, -0.85), 0.5, 0.12, "Body")
		end)
	end)
end

-- Bigger toad whose bulb has opened into a pink bud over four big leaves (Ivysaur-like).
Designs["Bloomtoad"] = function(b)
	local body = b:Ball("Body", V(2.3, 1.5, 2.45), V(0, 1.1, 0.45), nil, "Body", { Detail = 1 })
	b:SetCore(body)
	patch(b, "SpotA", body, V(0.8, 0.35, 0.3), 0.26, 20, "Extra")
	patch(b, "SpotB", body, V(-0.8, 0.45, 0.6), 0.24, 70, "Extra")

	-- Pink bud with green sepals at its base.
	lathe(b, "Bud", V(0, 1.55, 0.55), 0, { { 0.5, 0.62 }, { 1.0, 0.45 } }, 1.55, 4, {
		"Extra",
		"Accent",
		"Accent",
	})
	-- Four leaves fanned out under the bud (they sway).
	for index, z in { -0.15, 1.15 } do
		local dz = if index == 1 then -1 else 1
		b:MirrorBone(if index == 1 then "WingLeafFront" else "WingLeafBack", V(0.35, 1.95, z), { Phase = index * 0.25 }, function()
			leaf(b, "Leaf", V(0.15, 1.95, z + 0.4 * -dz), V(1.95, 1.55, z + 1.05 * dz), 1.05, UP, 0.18, "Extra")
		end)
	end

	toadLegs(b, -0.25, 1.1, 0.8, 0.8, 0.7)

	b:Bone("Head", V(0, 1.45, -0.35), nil, function()
		local head = b:Ball("Head", V(2.55, 1.8, 1.85), V(0, 1.75, -1.0), nil, "Body")
		toadFace(b, head, 0.62, V(0.48, 0.52, 0.22), "Angry", 0.8, false)
		patch(b, "SpotHead", head, V(-0.35, 0.8, -0.4), 0.22, 0, "Extra")
		b:MirrorBone("Ear", V(0.8, 2.4, -0.95), nil, function()
			b:Spike("Ear", V(0.75, 2.3, -0.95), V(1.25, 3.1, -0.9), 0.55, 0.3, "Body")
		end)
	end)
end

-- Huge flower toad: a palm of leaves and an open five-petal flower on a stubby trunk (Venusaur-like).
Designs["Floradon"] = function(b)
	local body = b:Ball("Body", V(2.9, 1.85, 2.95), V(0, 1.25, 0.5), nil, "Body", { Detail = 1 })
	b:SetCore(body)
	patch(b, "SpotA", body, V(0.8, 0.35, 0.3), 0.3, 20, "Extra")
	patch(b, "SpotB", body, V(-0.8, 0.45, 0.6), 0.28, 70, "Extra")

	b:Cone("Trunk", V(0, 1.8, 0.55), V(0, 3.0, 0.6), 0.5, BARK, { Sides = 4 })
	-- Palm leaves (they sway) and the flower on top.
	for index, z in { 0.0, 1.1 } do
		local dz = if index == 1 then -1 else 1
		b:MirrorBone(if index == 1 then "WingLeafFront" else "WingLeafBack", V(0.3, 2.3, z), { Phase = index * 0.25 }, function()
			leaf(b, "Leaf", V(0.1, 2.35, 0.55), V(2.25, 1.65, 0.55 + 1.15 * dz), 1.2, UP, 0.22, "Extra")
		end)
	end
	for index = 1, 5 do
		local angle = math.rad((index - 1) * 72)
		local out = V(math.sin(angle), 0, -math.cos(angle))
		local base = V(0, 2.75, 0.6)
		local tip = base + out * 1.75 + V(0, 0.45, 0)
		leaf(b, "Petal" .. index, base, tip, 1.25, UP - out * 0.3, 0.12, "Accent", 0.55)
		patch(b, "PetalSpot" .. index, { Center = base + out * 0.9 + V(0, 0.6, 0), Tris = {} }, -UP, 0.2, 0, "White")
	end
	b:Cone("Pistil", V(0, 2.75, 0.6), V(0, 3.25, 0.6), 0.45, "Belly", { Sides = 5 })

	toadLegs(b, -0.4, 1.35, 0.95, 0.95, 0.85, true)

	b:Bone("Head", V(0, 1.45, -0.55), nil, function()
		local head = b:Ball("Head", V(2.6, 1.7, 1.8), V(0, 1.55, -1.25), nil, "Body")
		toadFace(b, head, 0.64, V(0.44, 0.46, 0.22), "Angry", 0.9, true)
		patch(b, "SpotHead", head, V(-0.35, 0.8, -0.4), 0.24, 0, "Extra")
		b:MirrorBone("Ear", V(0.85, 2.2, -1.2), nil, function()
			b:Spike("Ear", V(0.8, 2.1, -1.2), V(1.15, 2.65, -1.2), 0.5, 0.12, "Body")
		end)
	end)
end

-- Fire lizards (Embit family) ------------------------------------------------------------------

-- Two short legs, each with a pointed foot.
local function lizardLegs(b, hipY: number, spacing: number, thickness: number, footLength: number)
	b:MirrorBone("Leg", V(spacing, hipY, 0.12), nil, function()
		b:Limb("Leg", V(spacing - 0.03, hipY + 0.25, 0.15), V(spacing + 0.05, 0.06, -0.02), thickness, "Body", { RingAt = 0.55 })
		b:Spike("Foot", V(spacing + 0.05, 0.12, 0.08), V(spacing + 0.08, 0.06, -footLength), thickness * 0.9, thickness * 0.42, "Body", nil, UP)
	end)
end

-- Tail curving up behind, a flame burning at its tip.
local function flameTail(b, points: { Vector3 }, thickness: number, flame: number)
	b:Bone("Tail", points[1], nil, function()
		b:Chain("Tail", points, thickness, 0, "Body")
		b:Flame("TailFlame", points[#points] + V(0, -0.05, 0), flame)
	end)
end

-- Little fire lizard with a flame on its tail (Charmander-like).
Designs["Embit"] = function(b)
	local body = b:Ball("Body", V(1.45, 1.65, 1.35), V(0, 1.2, 0.1), nil, "Body", { Detail = 1 })
	b:SetCore(body)
	shield(b, "Belly", V(0, 1.1, -0.38), 0.95, 1.15, 0.2, 4, "Belly")

	lizardLegs(b, 0.75, 0.42, 0.6, 0.5)
	b:MirrorBone("Arm", V(0.55, 1.6, -0.12), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.48, 1.68, -0.1), V(0.95, 1.2, -0.55), 0.34, "Body")
	end)
	b:Bone("Head", V(0, 1.95, -0.05), nil, function()
		local head = b:Ball("Head", V(1.8, 1.6, 1.65), V(0, 2.6, -0.2), V(0, 180, 0), "Body")
		b:Eyes(head, 0.42, 0.18, V(0.42, 0.6, 0.22), FIRE_EYE)
		b:Mouth(head, -0.35, 0.55, true)
	end)
	flameTail(b, { V(0, 0.85, 0.5), V(0, 0.55, 1.3), V(0, 1.15, 1.95) }, 0.6, 0.5)
end

-- Taller, sharper red lizard with a horn and claws (Charmeleon-like).
Designs["Emberclaw"] = function(b)
	local body = b:Ball("Body", V(1.5, 2.1, 1.35), V(0, 1.5, 0.1), nil, "Body", { Detail = 1 })
	b:SetCore(body)
	shield(b, "Belly", V(0, 1.35, -0.38), 0.95, 1.5, 0.2, 4, "Belly")

	lizardLegs(b, 0.85, 0.45, 0.62, 0.55)
	b:MirrorBone("Arm", V(0.6, 2.0, -0.1), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.52, 2.05, -0.1), V(0.98, 1.4, -0.6), 0.32, "Body")
		for c, dx in { -0.07, 0.07 } do
			b:Spike("Claw" .. c, V(0.98 + dx, 1.42, -0.6), V(1.0 + dx * 2, 1.25, -0.82), 0.12, 0.04, "White", nil, UP)
		end
	end)
	b:Bone("Head", V(0, 2.4, -0.05), nil, function()
		local head = b:Ball("Head", V(1.45, 1.3, 1.9), V(0, 3.05, -0.35), V(-12, 0, 0), "Body")
		b:Spike("Horn", V(0, 3.45, 0.2), V(0, 3.7, 1.15), 0.45, 0.32, "Body", nil, UP)
		b:Eyes(head, 0.34, 0.15, V(0.34, 0.42, 0.2), FIRE_EYE, "Angry")
		b:Mouth(head, -0.3, 0.5, false)
	end)
	flameTail(b, { V(0, 1.0, 0.5), V(0, 0.55, 1.45), V(0, 1.05, 2.3) }, 0.62, 0.7)
end

-- Fire dragon hovering on big teal wings (Charizard-like).
Designs["Blazewing"] = function(b)
	b.Hover = 1.3
	local body = b:Ball("Body", V(1.85, 2.35, 1.65), V(0, 1.85, 0.1), nil, "Body", { Detail = 1 })
	b:SetCore(body)
	shield(b, "Belly", V(0, 1.7, -0.45), 1.2, 1.8, 0.22, 6, "Belly")

	b:MirrorBone("Leg", V(0.6, 1.25, 0.15), nil, function()
		b:Limb("Leg", V(0.55, 1.5, 0.15), V(0.72, 0.15, -0.2), 0.85, "Body", { RingAt = 0.35 })
		b:Spike("Foot", V(0.72, 0.22, -0.05), V(0.75, 0.12, -0.6), 0.5, 0.26, "Body", nil, UP)
	end)
	b:MirrorBone("Arm", V(0.78, 2.5, -0.25), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.7, 2.55, -0.2), V(1.2, 1.95, -0.75), 0.3, "Body")
	end)
	b:MirrorBone("Wing", V(0.55, 2.7, 0.55), nil, function()
		local shoulder, wrist = V(0.55, 2.65, 0.6), V(2.05, 4.25, 1.05)
		b:Limb("WingArm", V(0.45, 2.65, 0.5), wrist, 0.24, "Body")
		b:Spike("WingClaw", wrist, wrist + V(0.1, 0.4, -0.05), 0.2, 0.05, "Body")
		local trailing = { V(0.9, 1.9, 0.9), V(1.9, 2.35, 1.15), V(2.75, 3.05, 1.2) }
		b:Tri("Membrane1", wrist, shoulder, trailing[1], "Accent")
		b:Tri("Membrane2", wrist, trailing[1], trailing[2], "Accent")
		b:Tri("Membrane3", wrist, trailing[2], trailing[3], "Accent")
	end)
	b:Bone("Head", V(0, 2.85, -0.05), nil, function()
		b:Limb("Neck", V(0, 2.5, 0.05), V(0, 3.95, -0.45), 0.8, "Body")
		local head = b:Ball("Head", V(1.15, 1.0, 1.65), V(0, 4.0, -0.65), V(-12, 0, 0), "Body", { Detail = 1 })
		b:MirrorSpike("Horn", V(0.28, 4.3, -0.4), V(0.42, 4.55, 0.45), 0.24, 0.2, "Body")
		b:Eyes(head, 0.27, 0.12, V(0.25, 0.3, 0.16), FIRE_EYE, "Angry")
		b:Mouth(head, -0.25, 0.4, false)
	end)
	flameTail(b, { V(0, 1.1, 0.65), V(0, 0.55, 1.5), V(0, 0.85, 2.4) }, 0.75, 0.85)
end

-- Singing balloons (Puffloon family) ------------------------------------------------------------

-- Pointed ears with a dark inside (Ear bones).
local function puffEars(b, root: Vector3, tip: Vector3, width: number)
	b:MirrorBone("Ear", root, nil, function()
		b:Spike("Ear", root - V(0.05, 0.1, 0), tip, width, width * 0.5, "Body")
		local inner = root + V(0.05, 0.1, -width * 0.32)
		b:Spike("EarInner", inner, inner + (tip - root) * 0.72, width * 0.5, 0.05, EAR_DARK)
	end)
end

-- Round pink balloon that floats while it sings, with a curl of hair (Jigglypuff-like).
Designs["Puffloon"] = function(b)
	b.Hover = 1.2
	local body = lathe(b, "Body", V(0, 0.15, 0), 0, { { 0.55, 1.05, 0.92 }, { 1.25, 1.32, 1.15 }, { 1.95, 1.05, 0.92 } }, 2.5, 5, {
		"Body",
		"Body",
		"Body",
		"Body",
	})
	b:SetCore(body)
	puffEars(b, V(0.62, 2.3, 0.0), V(1.15, 3.1, 0.05), 0.75)
	b:Chain("Curl", { V(0, 2.5, -0.45), V(0.05, 2.95, -0.85), V(0.15, 2.7, -1.3), V(0.1, 2.35, -1.2) }, 0.45, 0, "Body")

	b:MirrorBone("Arm", V(1.05, 1.3, -0.2), { Phase = 0.5 }, function()
		b:Limb("Arm", V(1.0, 1.35, -0.2), V(1.5, 1.05, -0.4), 0.38, "Body")
	end)
	b:MirrorBone("LegFoot", V(0.55, 0.45, -0.1), nil, function()
		b:Ball("Foot", V(0.6, 0.35, 0.8), V(0.55, 0.3, -0.2), nil, "Body", { Detail = 0, Thickness = 0.05 })
	end)
	b:Eyes(body, 0.5, 0.2, V(0.62, 0.7, 0.22), PUFF_EYE)
	b:Mouth(body, -0.35, 0.38, true)
end

-- Tall fluffy bunny balloon with long ears and a white tuft (Wigglytuff-like).
Designs["Puffluxe"] = function(b)
	local body = b:Ball("Body", V(2.5, 3.0, 2.2), V(0, 1.6, 0.0), nil, "Body")
	b:SetCore(body)
	shield(b, "Belly", V(0, 1.05, -0.72), 1.5, 1.2, 0.2, 5, "Belly", 10)
	puffEars(b, V(0.6, 2.85, 0.1), V(1.2, 4.4, 0.25), 0.8)
	for index, tuft in { { V(0, 2.9, -0.55), V(0, 3.6, -1.15) }, { V(0.3, 2.85, -0.6), V(0.75, 3.3, -1.0) }, { V(-0.3, 2.85, -0.6), V(-0.75, 3.3, -1.0) } } do
		b:Spike("Tuft" .. index, tuft[1], tuft[2], 0.7, 0.45, "Belly", nil, UP)
	end

	b:MirrorBone("Arm", V(1.0, 1.7, -0.25), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.95, 1.75, -0.25), V(1.45, 1.35, -0.55), 0.38, "Body")
	end)
	b:MirrorBone("LegFoot", V(0.6, 0.45, -0.1), nil, function()
		b:Ball("Foot", V(0.7, 0.4, 0.95), V(0.6, 0.2, -0.25), nil, "Body", { Detail = 0, Thickness = 0.05 })
	end)
	b:Eyes(body, 0.48, 0.45, V(0.55, 0.62, 0.22), PUFF_EYE)
	b:Mouth(body, 0.0, 0.42, true)
end

return Designs
