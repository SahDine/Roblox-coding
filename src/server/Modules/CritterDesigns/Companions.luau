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
local function innerFace(b, name: string, base: Vector3, tip: Vector3, width: number, depth: number, hint: Vector3?, scale: number, color: any, lift: number?)
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
	-- Pull the base edge up a little so the triangle stays on the visible part of the face.
	return b:Tri(name, shrink(left), shrink(right), shrink(tip), color, THIN)
end

--[[
	Band around a Spike pyramid (rings on ears, legs, tails): a slightly wider, steeper pyramid on the
	same axis that starts at fraction t0 of the spike and dives back into it at t1, so only that band
	shows. Costs one pyramid (6 parts).
]]
local function collar(b, name: string, base: Vector3, tip: Vector3, width: number, depth: number, t0: number, t1: number, color: any, opts: any?, hint: Vector3?)
	local grow = 1.14
	local s0 = 1 - t0
	local t2 = (grow * s0 * t1 - (1 - t1) * t0) / (grow * s0 - (1 - t1))
	local axis = tip - base
	return b:Spike(name, base + axis * t0, base + axis * t2, width * s0 * grow, depth * s0 * grow, color, opts, hint)
end

--[[
	Leg column: a twisted triangular prism (3-sided antiprism) from `top` (hide it in the body) down to
	a triangular sole at `bottom` whose point faces forwards (the toe). 7 facets (~14 parts).
]]
local function post(b, name: string, top: Vector3, bottom: Vector3, rTop: number, rBottom: number, color: any, opts: any?, toe: number?, sole: boolean?)
	local vertices = {}
	for k = 0, 2 do
		local a = (k + 0.5) * TAU / 3
		table.insert(vertices, top + V(math.sin(a) * rTop, 0, -math.cos(a) * rTop))
	end
	for k = 0, 2 do
		local a = k * TAU / 3
		local r = if k == 0 then rBottom * (toe or 1.35) else rBottom
		table.insert(vertices, bottom + V(math.sin(a) * r, 0, -math.cos(a) * r))
	end
	local faces = { { 4, 1, 5 }, { 1, 5, 2 }, { 5, 2, 6 }, { 2, 6, 3 }, { 6, 3, 4 }, { 3, 4, 1 } }
	if sole ~= false then
		table.insert(faces, { 4, 6, 5 })
	end
	return b:Mesh(name, vertices, faces, color, opts)
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
local function bill(b, name: string, back: Vector3, width: number, length: number, height: number, color: any, droop: number?, frontWidth: number?)
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
local function disc(b, name: string, shape, x: number, y: number, radius: number, sides: number, raise: number, lift: number, color: any, opts: any?)
	local frame = b:OnSurface(shape, x, y) * CFrame.new(0, 0, -lift)
	local vertices = {}
	for k = 0, sides - 1 do
		local a = (k + 0.5) * TAU / sides
		table.insert(vertices, (frame * CFrame.new(math.sin(a) * radius, math.cos(a) * radius, 0)).Position)
	end
	table.insert(vertices, (frame * CFrame.new(0, 0, -raise)).Position)
	local faces = {}
	for k = 1, sides do
		table.insert(faces, { k, k % sides + 1, sides + 1 })
	end
	return b:Mesh(name, vertices, faces, color, opts)
end

--[[
	Patch lying on the front of a shape (bellies): a fan of triangles from a raised centre to an outline
	of (x, y) offsets from the shape's centre, every point cast onto the shape's facets.
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
		b:Limb("Arm", V(0.4, 1.55, -0.35), V(0.66, 1.12, -1.0), 0.36, "Body", { RingAt = 0.62, Thickness = 0.06 })
	end)

	b:Bone("Head", V(0, 1.85, -0.05), nil, function()
		local head = b:Ball("Head", V(2.05, 1.75, 1.65), V(0, 2.6, -0.2), nil, "Body")
		b:Eyes(head, 0.45, 0.12, V(0.4, 0.46, 0.3), "Black")
		b:Cheeks(head, 0.72, -0.3, 0.46)
		b:Mouth(head, -0.36, 0.34, true)
		b:FaceDot("Nose", head, 0, -0.06, V(0.12, 0.08, 0.1), "Black")
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
			{ p(0.92, 0.45), p(0.6, 0.6) },
			{ p(1.52, 1.05), p(1.22, 1.2) },
			{ p(1.5, 1.38), p(1.15, 1.52) },
			{ p(2.5, 2.12), p(2.08, 2.48) },
		}, { "Extra", "Body", "Body" }, 0.16)
		b:Tri("TailTipA", p(2.5, 2.12), p(3.15, 2.22), p(2.08, 2.48), "Body", { Thickness = 0.16 })
		b:Tri("TailTipB", p(3.15, 2.22), p(2.7, 3.05), p(2.08, 2.48), "Body", { Thickness = 0.16 })
	end)
end

-- Bigger orange mouse: cream belly, yellow cheeks, curled brown ears and a long thin tail ending in a bolt.
Designs["Voltmouse"] = function(b)
	local body = b:Ball("Body", V(2.1, 2.0, 1.8), V(0, 1.15, 0.05), nil, "Body")
	b:SetCore(body)
	patch(b, "Belly", body, {
		Vector2.new(0, 0.62),
		Vector2.new(0.66, 0.15),
		Vector2.new(0.42, -0.66),
		Vector2.new(-0.42, -0.66),
		Vector2.new(-0.66, 0.15),
	}, Vector2.new(0, -0.05), 0.06, 0.14, "Belly")

	b:MirrorBone("LegFoot", V(0.5, 0.55, -0.1), nil, function()
		bean(b, "Foot", V(0.52, 0.22, -0.4), V(0.7, 0.44, 1.05), "Body", THIN, 0.3)
	end)
	b:MirrorBone("Arm", V(0.55, 1.68, -0.55), { Phase = 0.5 }, function()
		b:Spike("Arm", V(0.48, 1.75, -0.38), V(0.8, 1.22, -1.12), 0.36, 0.36, "Body", THIN, SIDE)
		b:Spike("Hand", V(0.74, 1.32, -0.98), V(0.82, 1.18, -1.16), 0.26, 0.24, "Accent", THIN, SIDE)
	end)

	b:Bone("Head", V(0, 2.05, -0.1), nil, function()
		local head = b:Ball("Head", V(2.05, 1.8, 1.7), V(0, 2.95, -0.2), nil, "Body")
		b:Eyes(head, 0.44, 0.12, V(0.42, 0.48, 0.3), "Black")
		b:Cheeks(head, 0.74, -0.32, 0.46, "Extra")
		b:Mouth(head, -0.4, 0.38, true)
		-- Big ears: dark brown backs, yellow insides, tips curling outwards.
		b:MirrorBone("Ear", V(0.6, 3.6, -0.15), nil, function()
			local base, tip = V(0.55, 3.5, -0.15), V(1.5, 4.85, 0.0)
			b:Spike("Ear", base, tip, 0.98, 0.4, "Accent", THIN, BACK)
			innerFace(b, "EarInner", base, tip, 0.98, 0.4, BACK, 0.68, "Extra")
			b:Spike("EarCurl", V(1.36, 4.66, -0.02), V(1.85, 4.45, 0.02), 0.32, 0.05, "Accent", THIN)
		end)
	end)

	-- Long thin black tail curving up, ending in a yellow lightning bolt (two bones so it whips).
	local rings = tubeRings({ V(0, 0.75, 0.6), V(0, 0.55, 1.45), V(0, 1.35, 2.2), V(0, 2.3, 2.35) }, { 0.13, 0.12, 0.1, 0.08 }, 3, UP)
	b:Bone("Tail", V(0, 0.75, 0.65), nil, function()
		tubeSegment(b, "Tail1", rings, 1, "Accent", THIN)
		b:Bone("Tail2", V(0, 0.55, 1.45), nil, function()
			tubeSegment(b, "Tail2", rings, 2, "Accent", THIN)
			tubeSegment(b, "Tail3", rings, 3, "Accent", THIN)
			local function p(y: number, z: number): Vector3
				return V(0, y, z)
			end
			b:Tri("BoltA", p(2.15, 2.28), p(2.95, 2.0), p(2.6, 2.75), "Extra", { Thickness = 0.12 })
			b:Tri("BoltB", p(2.7, 2.45), p(3.35, 2.55), p(2.9, 3.1), "Extra", { Thickness = 0.12 })
		end)
	end)
end

-- Fox line ---------------------------------------------------------------------------------------

-- Fluffy brown fox: huge ears, cream ruff and a bushy cream-tipped tail.
Designs["Fennix"] = function(b)
	local body = b:Ball("Body", V(1.35, 1.15, 1.85), V(0, 0.9, 0.35), nil, "Body", { Detail = 1 })
	b:SetCore(body)
	for index, z in { -0.18, 0.9 } do
		b:MirrorBone(if index == 1 then "LegFront" else "LegBack", V(0.36, 0.7, z), { Phase = if index == 1 then 0 else 0.5 }, function()
			post(b, "Leg", V(0.34, 0.85, z), V(0.37, 0, z - 0.06), 0.2, 0.11, "Body", THIN, 2.1, false)
		end)
	end
	-- Cream ruff around the neck.
	b:Spike("Ruff", V(0, 1.5, -0.5), V(0, 0.82, -1.02), 0.8, 0.48, "Belly", THIN, FRONT)
	b:MirrorSpike("RuffSide", V(0.3, 1.5, -0.45), V(0.78, 0.95, -0.8), 0.62, 0.42, "Belly", THIN, V(0.5, 0, -1))

	-- Bushy tail curving up, cream tip.
	b:Bone("Tail", V(0, 1.15, 1.1), nil, function()
		b:Ball("Tail", V(0.95, 1.45, 0.85), V(0, 1.62, 1.45), V(30, 0, 0), "Body", { Detail = 0, Thickness = 0.08 })
		b:Ball("TailTip", V(0.85, 0.95, 0.8), V(0, 2.36, 1.84), V(30, 0, 0), "Belly", { Detail = 0, Thickness = 0.08 })
	end)

	b:Bone("Head", V(0, 1.42, -0.4), nil, function()
		local head = b:Ball("Head", V(1.7, 1.5, 1.45), V(0, 2.0, -0.55), nil, "Body")
		b:Eyes(head, 0.4, 0.05, V(0.4, 0.5, 0.3), Color3.fromRGB(95, 55, 30))
		b:FaceDot("Nose", head, 0, -0.2, V(0.16, 0.11, 0.1), "Black")
		b:Mouth(head, -0.38, 0.3)
		b:MirrorBone("Ear", V(0.45, 2.47, -0.5), nil, function()
			local base, tip = V(0.42, 2.37, -0.5), V(1.3, 3.62, -0.35)
			b:Spike("Ear", base, tip, 0.85, 0.34, "Body", THIN, BACK)
			innerFace(b, "EarInner", base, tip, 0.85, 0.34, BACK, 0.62, "Accent")
		end)
	end)
end

-- Sleek black fox with glowing yellow rings on its ears, forehead, legs and tail.
Designs["Moonfox"] = function(b)
	local body = b:Ball("Body", V(1.35, 1.3, 2.25), V(0, 1.55, 0.3), nil, "Body", { Detail = 1 })
	b:Limb("Neck", V(0, 1.45, -0.2), V(0, 2.6, -0.85), 0.75, "Body", { RingAt = 0.4, Thickness = 0.08 })
	b:SetCore(body)
	local glow = { Neon = true, Thickness = 0.06 }
	for index, z in { -0.42, 1.0 } do
		b:MirrorBone(if index == 1 then "LegFront" else "LegBack", V(0.38, 1.4, z), { Phase = if index == 1 then 0 else 0.5 }, function()
			local base, tip = V(0.38, 1.5, z), V(0.4, 0.0, z - 0.1)
			b:Spike("Leg", base, tip, 0.48, 0.42, "Body", THIN)
			collar(b, "LegRing", base, tip, 0.48, 0.42, 0.38, 0.5, "Accent", glow)
		end)
	end

	-- Long tail with a glowing ring: two pyramids base to base.
	b:Bone("Tail", V(0, 1.75, 1.25), nil, function()
		local mid, tip = V(0, 2.25, 1.85), V(0, 3.2, 2.25)
		b:Spike("TailBase", mid, V(0, 1.7, 1.15), 0.5, 0.42, "Body", THIN, BACK)
		b:Spike("Tail", mid, tip, 0.5, 0.42, "Body", THIN, BACK)
		collar(b, "TailRing", mid, tip, 0.5, 0.42, 0.05, 0.22, "Accent", glow, BACK)
	end)

	b:Bone("Head", V(0, 2.1, -0.6), nil, function()
		local head = b:Ball("Head", V(1.55, 1.4, 1.45), V(0, 2.8, -0.95), nil, "Body")
		b:Ball("Muzzle", V(0.72, 0.5, 0.7), V(0, 2.5, -1.5), nil, "Body", { Detail = 0, Thickness = 0.06 })
		b:Eyes(head, 0.36, 0.08, V(0.34, 0.38, 0.28), Color3.fromRGB(220, 30, 40))
		b:FaceDot("Nose", head, 0, -0.38, V(0.12, 0.09, 0.1), "Dark")
		b:FaceDot("ForeheadRing", head, 0, 0.4, V(0.44, 0.44, 0.12), "Accent", { Neon = true })
		b:FaceDot("ForeheadDot", head, 0, 0.4, V(0.24, 0.24, 0.2), "Body")
		b:MirrorBone("Ear", V(0.4, 3.2, -0.85), nil, function()
			local base, tip = V(0.36, 3.1, -0.85), V(0.95, 4.6, -0.7)
			b:Spike("Ear", base, tip, 0.62, 0.36, "Body", THIN, BACK)
			collar(b, "EarRing", base, tip, 0.62, 0.36, 0.42, 0.56, "Accent", glow, BACK)
		end)
	end)
end

-- Duck line --------------------------------------------------------------------------------------

-- Confused yellow duck holding its aching head: wide cream bill, three hairs, dazed eyes.
Designs["Quackle"] = function(b)
	local body = b:Ball("Body", V(1.95, 1.8, 1.75), V(0, 1.0, 0.05), nil, "Body")
	b:SetCore(body)
	b:MirrorBone("LegFoot", V(0.5, 0.45, -0.1), nil, function()
		local vertices = { V(0.5, 0.34, -0.05), V(0.5, 0.06, 0.22), V(0.84, 0.05, -0.55), V(0.5, 0.05, -0.72), V(0.16, 0.05, -0.55) }
		b:Mesh("Foot", vertices, { { 1, 3, 4 }, { 1, 4, 5 }, { 1, 2, 3 }, { 1, 5, 2 }, { 2, 5, 4 }, { 2, 4, 3 } }, "Belly", THIN)
	end)
	b:Bone("Tail", V(0, 1.0, 0.75), nil, function()
		b:Spike("Tail", V(0, 0.95, 0.65), V(0, 1.2, 1.25), 0.55, 0.3, "Body", THIN, UP)
	end)
	-- Arms raised to hold the head.
	b:MirrorBone("Arm", V(0.75, 1.5, -0.1), { Phase = 0.5, Amp = 0.3 }, function()
		b:Limb("Arm", V(0.62, 1.42, -0.1), V(1.0, 2.5, -0.2), 0.4, "Body", { RingAt = 0.6, Thickness = 0.06 })
		b:Cone("Hand", V(0.92, 2.6, -0.2), V(1.2, 2.64, -0.22), 0.27, "Body", { Sides = 4, Thickness = 0.06 })
	end)

	b:Bone("Head", V(0, 1.75, 0), { Amp = 0.5 }, function()
		local head = b:Ball("Head", V(2.0, 1.85, 1.8), V(0, 2.6, -0.1), nil, "Body")
		bill(b, "Bill", V(0, 2.32, -0.72), 1.05, 0.78, 0.36, "Belly", 0.05)
		b:Eyes(head, 0.42, 0.25, V(0.52, 0.52, 0.3), "White", "Dazed")
		for index, x in { -0.16, 0, 0.16 } do
			b:Spike("Hair" .. index, V(x, 3.35, -0.05), V(x * 2.6, 4.1, 0.05), 0.1, 0.08, "Black")
		end
	end)
end

-- Tall blue duck: long cream bill, red forehead gem, swept-back crest, webbed hands and feet.
Designs["Mystduck"] = function(b)
	local body = b:Ball("Body", V(1.5, 2.05, 1.3), V(0, 2.05, 0.1), nil, "Body")
	b:SetCore(body)
	b:MirrorBone("Leg", V(0.42, 1.35, 0.15), nil, function()
		b:Limb("Leg", V(0.4, 1.45, 0.15), V(0.48, 0.18, 0.02), 0.44, "Body", { RingAt = 0.35, Thickness = 0.08 })
		local vertices = { V(0.48, 0.32, 0.02), V(0.48, 0.06, 0.25), V(0.82, 0.05, -0.5), V(0.48, 0.05, -0.68), V(0.14, 0.05, -0.5) }
		b:Mesh("Foot", vertices, { { 1, 3, 4 }, { 1, 4, 5 }, { 1, 2, 3 }, { 1, 5, 2 }, { 2, 5, 4 }, { 2, 4, 3 } }, "Body", THIN)
	end)
	b:MirrorBone("Arm", V(0.62, 2.6, -0.05), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.52, 2.65, -0.02), V(1.0, 1.62, -0.36), 0.36, "Body", { RingAt = 0.4, Thickness = 0.06 })
		b:Spike("Hand", V(0.98, 1.68, -0.36), V(1.08, 1.2, -0.48), 0.4, 0.22, "Body", THIN, V(1, 0, 0))
	end)
	b:Bone("Tail", V(0, 1.4, 0.6), nil, function()
		b:Spike("Tail", V(0, 1.45, 0.55), V(0, 0.75, 1.6), 0.55, 0.22, "Body", THIN, UP)
	end)

	b:Bone("Head", V(0, 2.95, -0.05), nil, function()
		local head = b:Ball("Head", V(1.35, 1.2, 1.45), V(0, 3.48, -0.2), nil, "Body")
		bill(b, "Bill", V(0, 3.28, -0.72), 0.72, 1.0, 0.3, "Belly", 0.08, 0.5)
		b:Eyes(head, 0.32, 0.12, V(0.32, 0.36, 0.28), Color3.fromRGB(220, 40, 40), "Angry")
		b:FaceDot("Gem", head, 0, 0.36, V(0.3, 0.32, 0.16), "Accent", { Neon = true })
		b:Spike("Crest", V(0, 3.75, 0.2), V(0, 3.5, 1.1), 0.55, 0.32, "Body", THIN, UP)
	end)
end

-- Cat line ---------------------------------------------------------------------------------------

-- Cat standing on two legs with a gold coin on its forehead, long whiskers and a curly brown-tipped tail.
Designs["Coinpurr"] = function(b)
	local body = b:Ball("Body", V(1.4, 1.5, 1.2), V(0, 1.2, 0.05), nil, "Body", { Detail = 1 })
	b:SetCore(body)
	b:MirrorBone("Leg", V(0.3, 0.8, 0.05), nil, function()
		b:Spike("Leg", V(0.3, 0.98, 0.05), V(0.34, 0.12, -0.03), 0.38, 0.32, "Body", THIN)
		tetraFoot(b, "Foot", V(0.34, 0.14, -0.14), V(0.4, 0.28, 0.56), "Accent", THIN)
	end)
	b:MirrorBone("Arm", V(0.45, 1.6, -0.25), { Phase = 0.5 }, function()
		b:Cone("Arm", V(0.4, 1.68, -0.18), V(0.66, 1.08, -0.72), 0.17, "Body", { Sides = 4, Thickness = 0.05 })
	end)
	local rings = tubeRings({ V(0, 0.85, 0.4), V(0, 1.05, 1.2), V(0, 2.0, 1.35) }, { 0.13, 0.12, 0.1 }, 3, UP)
	b:Bone("Tail", V(0, 0.85, 0.45), nil, function()
		tubeSegment(b, "Tail1", rings, 1, "Body", THIN)
		b:Bone("Tail2", V(0, 1.05, 1.2), nil, function()
			tubeSegment(b, "Tail2", rings, 2, "Body", THIN)
			b:Spike("TailCurl", V(0, 1.95, 1.37), V(0, 2.4, 1.0), 0.3, 0.26, "Accent", THIN, BACK)
		end)
	end)

	b:Bone("Head", V(0, 1.8, -0.05), nil, function()
		local head = b:Ball("Head", V(2.3, 1.85, 1.7), V(0, 2.65, -0.1), nil, "Body")
		disc(b, "Coin", head, 0, 0.52, 0.4, 6, 0.12, 0.04, "Gold", { Material = Enum.Material.Foil, Thickness = 0.06 })
		b:Eyes(head, 0.48, 0.05, V(0.38, 0.58, 0.3), "White")
		b:Mouth(head, -0.42, 0.42, true)
		b:FaceDot("Nose", head, 0, -0.2, V(0.14, 0.1, 0.1), "Blush")
		b:MirrorSpike("WhiskerA", V(0.8, 2.48, -0.72), V(1.75, 2.62, -0.78), 0.07, 0.03, "Dark")
		b:MirrorSpike("WhiskerB", V(0.8, 2.38, -0.72), V(1.72, 2.2, -0.74), 0.07, 0.03, "Dark")
		b:MirrorBone("Ear", V(0.6, 3.3, -0.05), nil, function()
			local base, tip = V(0.58, 3.2, -0.02), V(1.08, 4.05, 0.05)
			b:Spike("Ear", base, tip, 0.72, 0.3, "Black", THIN, BACK)
			innerFace(b, "EarInner", base, tip, 0.72, 0.3, BACK, 0.6, "Accent")
		end)
	end)
end

-- Elegant cat on four slender legs: red forehead gem, haughty eyes, long whiskers, S-curved tail.
Designs["Regalynx"] = function(b)
	local body = b:Ball("Body", V(1.3, 1.2, 2.3), V(0, 1.5, 0.35), nil, "Body", { Detail = 1 })
	b:SetCore(body)
	for index, z in { -0.45, 1.05 } do
		b:MirrorBone(if index == 1 then "LegFront" else "LegBack", V(0.36, 1.35, z), { Phase = if index == 1 then 0 else 0.5 }, function()
			post(b, "Leg", V(0.36, 1.45, z), V(0.38, 0, z - 0.06), 0.18, 0.1, "Body", THIN, 2.3, false)
		end)
	end
	local rings = tubeRings({ V(0, 1.6, 1.25), V(0, 2.15, 1.85), V(0, 2.95, 1.95), V(0, 3.3, 1.55) }, { 0.14, 0.12, 0.1, 0 }, 3, UP)
	b:Bone("Tail", V(0, 1.65, 1.3), nil, function()
		tubeSegment(b, "Tail1", rings, 1, "Body", THIN)
		b:Bone("Tail2", V(0, 2.15, 1.85), nil, function()
			tubeSegment(b, "Tail2", rings, 2, "Body", THIN)
			tubeSegment(b, "Tail3", rings, 3, "Body", THIN)
		end)
	end)

	b:Bone("Head", V(0, 2.1, -0.6), nil, function()
		local head = b:Ball("Head", V(1.95, 1.5, 1.5), V(0, 2.6, -0.95), nil, "Body")
		b:FaceDot("Gem", head, 0, 0.36, V(0.36, 0.42, 0.18), "Accent", { Neon = true })
		b:Eyes(head, 0.4, 0.06, V(0.36, 0.34, 0.28), Color3.fromRGB(200, 30, 50), "Angry")
		b:FaceDot("Nose", head, 0, -0.3, V(0.14, 0.1, 0.1), "Blush")
		b:Mouth(head, -0.44, 0.3)
		b:MirrorSpike("WhiskerA", V(0.55, 2.4, -1.5), V(1.7, 2.7, -1.45), 0.07, 0.03, "Extra")
		b:MirrorSpike("WhiskerB", V(0.55, 2.3, -1.5), V(1.65, 2.05, -1.35), 0.07, 0.03, "Extra")
		b:MirrorBone("Ear", V(0.55, 3.15, -0.9), nil, function()
			local base, tip = V(0.52, 3.05, -0.88), V(1.1, 3.95, -0.8)
			b:Spike("Ear", base, tip, 0.72, 0.3, "Extra", THIN, BACK)
			innerFace(b, "EarInner", base, tip, 0.72, 0.3, BACK, 0.6, "Blush")
		end)
	end)
end

return Designs
