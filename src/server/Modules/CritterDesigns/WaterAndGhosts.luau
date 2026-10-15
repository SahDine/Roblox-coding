--[[
	Critter designs: Puddlet, Shellwave, Cannontoise, Ghastling, Hauntling, Gloomer, Flopfish, Tidewyrm.
	See CritterBuilder for the toolkit. Ground at y = 0, the critter faces -Z.
	Triangle style: every surface is faceted (Ball / Limb / Tube / Spike / Mesh...), only the eyes and the
	mouths are round, and every moving part lives in a bone (legs, arms, head, ears, tails, fins, jaws, hands).
]]

local V = Vector3.new
local TAU = math.pi * 2

local Designs = {}

local TURTLE_EYE = Color3.fromRGB(150, 60, 50)
local SHELL_RIM = Color3.fromRGB(250, 246, 232)
local GHOST_EYE = Color3.fromRGB(245, 235, 250)
local GAS = Color3.fromRGB(170, 100, 230)
local GLOOM_EYE = Color3.fromRGB(225, 40, 55)
local WYRM_EYE = Color3.fromRGB(220, 60, 60)

local SIDE = V(1, 0, 0)
-- Up hint for limbs: puts a ridge (not a flat facet) on the outer side.
local OUT = V(1, 0.3, 0)
-- Plate thickness for small shapes: thin plates keep sharp low-poly edges crisp.
local THIN = 0.05
local UP = V(0, 1, 0)

-- Shared pieces -----------------------------------------------------------------------------

--[[
	Turtle torso: one closed faceted solid painted in three colours. From the front a cream plastron (a low
	pyramid on the widest ring), around it a white rim band whose back edge is a zig-zag, behind it the
	carapace (a low dome). center = centre of the widest ring, width / height = extents of that ring,
	front / back = how far the plastron / carapace apexes stick out. 4 * sides triangles.
	shellAlt: second colour for every other carapace facet (scutes). Returns the plastron handle.
]]
local function turtleTorso(b, center: Vector3, width: number, height: number, front: number, back: number, sides: number, shellAlt: any?)
	local vertices = {}
	local function ring(scale: number, z: number, twist: number): number
		local first = #vertices
		for k = 0, sides - 1 do
			local a = (k + twist) * TAU / sides
			local s, c = math.sin(a), math.cos(a)
			-- pear shaped: a little wider at the bottom
			table.insert(vertices, center + V(s * width / 2 * scale * (1 - 0.1 * c), c * height / 2 * scale, z))
		end
		return first
	end
	local rim = ring(1, 0, 0.5)
	local shell = ring(0.8, back * 0.45, 0)
	table.insert(vertices, center + V(0, -height * 0.05, -front))
	local frontApex = #vertices
	table.insert(vertices, center + V(0, height * 0.06, back))
	local backApex = #vertices

	local plastronFaces, rimFaces, shellFaces, altFaces = {}, {}, {}, {}
	for k = 1, sides do
		local k1 = k % sides + 1
		table.insert(plastronFaces, { frontApex, rim + k, rim + k1 })
		-- shell vertex k sits between rim vertices k - 1 and k: white teeth around the plastron, brown in between
		table.insert(shellFaces, { shell + k, rim + k, shell + k1 })
		table.insert(rimFaces, { rim + k, shell + k1, rim + k1 })
		table.insert(if shellAlt and k % 2 == 0 then altFaces else shellFaces, { backApex, shell + k, shell + k1 })
	end
	local plates = { Thickness = 0.08 }
	local plastron = b:Mesh("Plastron", vertices, plastronFaces, "Belly", plates)
	b:Mesh("ShellRim", vertices, rimFaces, SHELL_RIM, plates)
	b:Mesh("Shell", vertices, shellFaces, "Accent", plates)
	if shellAlt then
		b:Mesh("ShellScute", vertices, altFaces, shellAlt, plates)
	end
	return plastron
end

-- Cannon barrel: an antiprism (`sides` vertices per ring) from `back` (hidden in the shell, radius backRadius; 0 =
-- a point, cheaper) to `muzzle` (radius), whose mouth folds inwards into a dark funnel.
local function barrel(
	b,
	name: string,
	back: Vector3,
	muzzle: Vector3,
	backRadius: number,
	radius: number,
	sides: number,
	color: any,
	holeColor: any
)
	local dir = (muzzle - back).Unit
	local up = (UP - dir * UP:Dot(dir)).Unit
	local right = dir:Cross(up)
	local vertices = {}
	for ringIndex, point in { back, muzzle } do
		local r = if ringIndex == 1 then backRadius else radius
		for k = 0, sides - 1 do
			local a = (k + (ringIndex - 1) * 0.5 + 0.25) * TAU / sides
			table.insert(vertices, point + (right * math.cos(a) + up * math.sin(a)) * r)
		end
	end
	table.insert(vertices, muzzle - dir * radius * 0.9)
	local walls, hole = {}, {}
	for k = 1, sides do
		local k1 = k % sides + 1
		if backRadius > 0 then
			table.insert(walls, { k, sides + k, k1 })
		end
		table.insert(walls, { sides + k, sides + k1, k1 })
		table.insert(hole, { sides + k, sides + k1, 2 * sides + 1 })
	end
	b:Mesh(name, vertices, walls, color, { Thickness = THIN })
	b:Mesh(name .. "Hole", vertices, hole, holeColor, { Thickness = THIN })
end

-- Small flat triangle on a face (fangs, teeth): base centred at (x, y) on the shape, pointing down (or up).
local function fang(b, head, x: number, y: number, width: number, length: number, color: any?, down: boolean?)
	local frame = b:OnSurface(head, x, y) * CFrame.new(0, 0, -0.04)
	local tip = if down == false then length else -length
	b:Tri(
		"Fang",
		frame:PointToWorldSpace(V(-width / 2, 0, 0)),
		frame:PointToWorldSpace(V(width / 2, 0, 0)),
		frame:PointToWorldSpace(V(0, tip, -0.03)),
		color or "White",
		{ Thickness = 0.06 }
	)
end

-- Slanted eyelid over a round eye: a flat triangle in `color` covering the inner top of the eye.
local function eyelids(b, head, spacing: number, height: number, size: Vector3, color: any)
	for _, side in { -1, 1 } do
		local frame = b:OnSurface(head, side * spacing, height)
		local out = -math.max(size.Z, 0.25) * 0.55
		b:Tri(
			"Lid",
			frame:PointToWorldSpace(V(-side * size.X * 0.62, size.Y * 0.05, out)),
			frame:PointToWorldSpace(V(side * size.X * 0.62, size.Y * 0.62, out)),
			frame:PointToWorldSpace(V(-side * size.X * 0.45, size.Y * 0.68, out)),
			color,
			{ Thickness = 0.06 }
		)
	end
end

-- Ghost hand (built inside a Float bone): a mitten palm, three thick claws spread upwards (a spooky "boo!")
-- and a jagged cuff trailing towards the body. side = +1 for the right hand.
local function ghostHand(b, palm: Vector3, side: number, size: number, color: any)
	b:Ball("Palm", V(0.82, 0.78, 0.52) * size, palm, nil, color, { Detail = 0 })
	local fingers = { V(0.62, 0.78, -0.2), V(0.08, 1.05, -0.25), V(-0.42, 0.82, -0.2) }
	for index, offset in fingers do
		local dir = V(offset.X * side, offset.Y, offset.Z)
		b:Spike("Finger" .. index, palm + dir * 0.25 * size, palm + dir * 1.12 * size, 0.38 * size, 0.3 * size, color, nil, V(0, 0, -1))
	end
	for index, y in { 0.12, -0.18 } do
		b:Spike(
			"Cuff" .. index,
			palm + V(-0.2 * side, y, 0.05) * size,
			palm + V(-0.75 * side, y * 2.2 - 0.12, 0.12) * size,
			0.34 * size,
			0.05,
			color,
			{ Thickness = THIN },
			V(0, 0, -1)
		)
	end
end

--[[
	Crescent mouth lying on the front of `head` (grins, smiles). Options:
	  HalfWidth, Top, Bottom: the corners are at x = +-HalfWidth, the top / bottom edges at y = Top / Bottom in
	    the middle; Curl: how much both edges rise towards the pointed corners.
	  Gap: two strips of teeth with a dark line Gap wide between them; nil = one strip.
	  Color (default White), Columns (default 5: 6 triangles per strip; 3: 2 triangles), Lift (how far the strip
	  floats off the surface, default 0.04: raise it on coarse shapes so the flat triangles do not sink in).
]]
local function grin(b, head, options)
	local halfWidth, top, bottom, curl = options.HalfWidth, options.Top, options.Bottom, options.Curl
	local color = options.Color or "White"
	local count = options.Columns or 5
	local lift = options.Lift or 0.04
	local function point(x: number, y: number): Vector3
		return (b:OnSurface(head, x, y) * CFrame.new(0, 0, -lift)).Position
	end
	local function strip(name: string, upper: (number) -> number, lower: (number) -> number)
		local ups, downs = {}, {}
		for i = 1, count do
			local u = (i - 1) / (count - 1) * 2 - 1
			ups[i], downs[i] = point(u * halfWidth, upper(u)), point(u * halfWidth, lower(u))
		end
		-- the end columns are single points (ups = downs): one triangle there, two elsewhere
		for i = 1, count - 1 do
			if i > 1 then
				b:Tri(name, ups[i], ups[i + 1], downs[i], color, { Thickness = THIN })
			end
			if i < count - 1 then
				b:Tri(name, ups[i + 1], downs[i + 1], downs[i], color, { Thickness = THIN })
			end
		end
	end
	local corner = top + curl
	local function edge(y0: number): (number) -> number
		return function(u: number): number
			return y0 + (corner - y0) * u * u
		end
	end
	local gap = options.Gap
	if gap then
		local middle = (top + bottom) / 2
		local function mid(offset: number): (number) -> number
			return function(u: number): number
				return middle + offset * (1 - u * u) + (corner - middle) * u * u
			end
		end
		strip("GrinTop", edge(top), mid(gap / 2))
		strip("GrinBottom", mid(-gap / 2), edge(bottom))
	else
		strip("Grin", edge(top), edge(bottom))
	end
end

--[[
	Lofted body (fish, serpents): one closed faceted solid through elliptic sections. Each section is
	{ Center, Width, Height, Right?, Up? } (Right / Up: the section's axes, default +X / +Y); `front` / `back`:
	apex points closing both ends. Successive sections are turned by half a step (antiprism) so every facet is a
	real triangle. paint(facetCentroid, band, outwards, kind) -> colour of each facet (band 0 = front cone,
	kind 1 / 2 = facet pointing backwards / forwards, for two-tone patterns).
	Returns one handle covering every facet (for the face helpers).
]]
local function loft(
	b,
	name: string,
	sections,
	front: Vector3,
	back: Vector3,
	sides: number,
	paint: (Vector3, number, Vector3, number) -> any
)
	local vertices = {}
	for i, section in sections do
		local right = section.Right or SIDE
		local up = section.Up or UP
		for k = 0, sides - 1 do
			local a = (k + (i - 1) * 0.5) * TAU / sides
			table.insert(vertices, section.Center + right * (math.sin(a) * section.Width / 2) + up * (math.cos(a) * section.Height / 2))
		end
	end
	table.insert(vertices, front)
	local frontIndex = #vertices
	table.insert(vertices, back)
	local backIndex = #vertices

	local groups, order = {}, {}
	local function add(band: number, center: Vector3, face: { number }, kind: number)
		local centroid = (vertices[face[1]] + vertices[face[2]] + vertices[face[3]]) / 3
		local color = paint(centroid, band, centroid - center, kind)
		if not groups[color] then
			groups[color] = {}
			table.insert(order, color)
		end
		table.insert(groups[color], face)
	end
	local count = #sections
	for k = 0, sides - 1 do
		local k1 = (k + 1) % sides
		add(0, sections[1].Center, { frontIndex, 1 + k, 1 + k1 }, 0)
		add(count, sections[count].Center, { backIndex, (count - 1) * sides + 1 + k, (count - 1) * sides + 1 + k1 }, 0)
		for i = 1, count - 1 do
			local a, c = (i - 1) * sides, i * sides
			local center = (sections[i].Center + sections[i + 1].Center) / 2
			add(i, center, { a + 1 + k, c + 1 + k, a + 1 + k1 }, 1)
			add(i, center, { c + 1 + k, c + 1 + k1, a + 1 + k1 }, 2)
		end
	end
	local handle
	local tris = {}
	for _, color in order do
		local part = b:Mesh(name, vertices, groups[color], color)
		handle = handle or part
		for _, triangle in part.Tris do
			table.insert(tris, triangle)
		end
	end
	return { Part = handle.Part, Center = handle.Center, Size = handle.Size, Tris = tris }
end

--[[
	Serpent body: an antiprism tube (`Sides` vertices per ring, default 4, successive rings turned by half a step
	so every facet is a triangle) through `points`, one radius per point. The rings are oriented by `dorsal` (the
	direction of the back: one Vector3, or one per point): the facets facing away from it take `bellyColor`, the
	others `color`. Each segment is its own convex mesh so its facets lie exactly on the surface. options:
	  Sides (default 4), Twist (extra ring turn in steps: 0 = a zig-zag of single belly facets, 0.25 = a continuous
	  two-facet belly band), CapStart / CapEnd (pointed cap length as a fraction of the end radius; nil = open end
	  hidden in another shape), BellyCut (cosine threshold of the belly facets, default 0.6).
	Returns a handle covering the whole body (centre = middle point).
]]
local function serpent(b, name: string, points: { Vector3 }, radii: { number }, dorsal: any, color: any, bellyColor: any, options: any?)
	local opts = options or {}
	local sides = opts.Sides or 4
	local cut = opts.BellyCut or 0.6
	local count = #points
	-- one dorsal direction for the whole body, or a list with one per point
	local perPoint = type(dorsal) == "table" and rawget(dorsal, 1) ~= nil
	local rings, ups, tangents = {}, {}, {}
	for i = 1, count do
		local t = (points[math.min(count, i + 1)] - points[math.max(1, i - 1)]).Unit
		local d = if perPoint then dorsal[i] else dorsal
		local u = (d - t * d:Dot(t)).Unit
		local v = t:Cross(u)
		local ring = {}
		for k = 0, sides - 1 do
			local a = (k + (i - 1) * 0.5 + (opts.Twist or 0)) * TAU / sides
			ring[k + 1] = points[i] + u * (math.cos(a) * radii[i]) + v * (math.sin(a) * radii[i])
		end
		rings[i], ups[i], tangents[i] = ring, u, t
	end

	local tris = {}
	local function draw(vertices: { Vector3 }, faces: { { number } }, axisA: Vector3, axisB: Vector3, up: Vector3)
		local axis = (axisB - axisA).Unit
		local belly = -up
		local groups, order = {}, {}
		for _, face in faces do
			local centroid = (vertices[face[1]] + vertices[face[2]] + vertices[face[3]]) / 3
			local out = centroid - (axisA + axisB) / 2
			out -= axis * out:Dot(axis)
			local key = if out.Magnitude > 1e-6 and out.Unit:Dot(belly) > cut then bellyColor else color
			if not groups[key] then
				groups[key] = {}
				table.insert(order, key)
			end
			table.insert(groups[key], face)
		end
		for _, key in order do
			local handle = b:Mesh(name, vertices, groups[key], key)
			for _, triangle in handle.Tris do
				table.insert(tris, triangle)
			end
		end
	end

	for i = 1, count - 1 do
		local vertices, faces = {}, {}
		for k = 1, sides do
			vertices[k] = rings[i][k]
			vertices[sides + k] = rings[i + 1][k]
		end
		for k = 1, sides do
			local k1 = k % sides + 1
			table.insert(faces, { k, sides + k, k1 })
			table.insert(faces, { sides + k, sides + k1, k1 })
		end
		draw(vertices, faces, points[i], points[i + 1], (ups[i] + ups[i + 1]).Unit)
	end
	for _, cap in { { 1, -1, opts.CapStart }, { count, 1, opts.CapEnd } } do
		local index, direction, length = cap[1], cap[2], cap[3]
		if length and radii[index] > 1e-3 then
			local vertices = table.clone(rings[index])
			local apex = points[index] + tangents[index] * direction * radii[index] * length
			table.insert(vertices, apex)
			local faces = {}
			for k = 1, sides do
				table.insert(faces, { sides + 1, k, k % sides + 1 })
			end
			draw(vertices, faces, points[index], apex, ups[index])
		end
	end
	local middle = points[math.ceil(count / 2)]
	return { Part = nil, Center = middle, Size = V(radii[1], radii[1], radii[1]) * 2, Tris = tris }
end

-- Turtle family ------------------------------------------------------------------------------

-- Little blue turtle: big round head, cheerful smile, cream plastron, white rimmed brown shell, curly tail.
Designs["Puddlet"] = function(b)
	local torso = turtleTorso(b, V(0, 1.08, 0.05), 1.8, 1.7, 0.6, 0.85, 6, "Extra")
	b:SetCore(torso)

	-- Stubby feet tucked under the shell.
	b:MirrorBone("Leg", V(0.45, 0.5, 0.0), nil, function()
		b:Ball("Foot", V(0.72, 0.52, 0.98), V(0.47, 0.26, -0.15), nil, "Body", { Detail = 0, Thickness = THIN })
	end)
	b:MirrorBone("Arm", V(0.72, 1.45, -0.05), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.5, 1.58, 0.02), V(1.18, 1.0, -0.45), 0.46, "Body", { RingAt = 0.62, Thickness = THIN, Up = OUT })
	end)

	b:Bone("Head", V(0, 1.8, -0.05), nil, function()
		local head = b:Ball("Head", V(2.15, 1.85, 1.85), V(0, 2.66, -0.18), nil, "Body")
		b:Eyes(head, 0.46, 0.12, V(0.5, 0.62, 0.26), TURTLE_EYE)
		-- Cheerful open smile.
		grin(b, head, { HalfWidth = 0.46, Top = -0.32, Bottom = -0.58, Curl = 0.16, Color = "Mouth", Lift = 0.06 })
	end)

	-- Curly tail: comes out under the shell, sweeps back and curls up into a hook.
	b:Bone("Tail", V(0, 0.7, 0.6), nil, function()
		b:Tube("Tail", { V(0, 0.72, 0.45), V(0, 0.58, 1.3), V(0, 1.0, 1.75) }, { 0, 0.34, 0 }, "Body", { Thickness = THIN })
		b:Spike("TailCurl", V(0, 0.92, 1.62), V(0, 1.6, 1.3), 0.46, 0.4, "Body", { Thickness = THIN }, V(0, 0.3, 1))
	end)
end

-- Bigger turtle: feathery white ears curling back, two little fangs, a big fluffy white tail curling like a wave.
Designs["Shellwave"] = function(b)
	local torso = turtleTorso(b, V(0, 1.42, 0.05), 1.95, 2.05, 0.65, 0.95, 6)
	b:SetCore(torso)

	b:MirrorBone("Leg", V(0.5, 0.75, 0.0), nil, function()
		b:Ball("Foot", V(0.84, 0.68, 1.12), V(0.5, 0.34, -0.15), nil, "Body", { Detail = 0, Thickness = THIN })
	end)
	b:MirrorBone("Arm", V(0.78, 1.88, -0.05), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.55, 1.98, 0.02), V(1.32, 1.3, -0.5), 0.5, "Body", { RingAt = 0.62, Thickness = THIN, Up = OUT })
	end)

	b:Bone("Head", V(0, 2.28, -0.05), nil, function()
		local head = b:Ball("Head", V(1.95, 1.75, 1.8), V(0, 3.0, -0.2), nil, "Body")
		b:Eyes(head, 0.4, 0.1, V(0.44, 0.56, 0.25), TURTLE_EYE)
		b:Mouth(head, -0.36, 0.48)
		fang(b, head, -0.2, -0.38, 0.12, 0.15)
		fang(b, head, 0.2, -0.38, 0.12, 0.15)
		-- Feathery ears: a big white feather sweeping up, out and back, its tip curling backwards.
		b:MirrorBone("Ear", V(0.6, 3.45, 0.0), nil, function()
			b:Spike("Ear", V(0.5, 3.35, 0.0), V(1.45, 4.6, 0.55), 1.0, 0.6, "Extra", { Thickness = THIN }, V(0.4, 0.3, -1))
			b:Blade("EarCurl", V(1.25, 4.38, 0.45), V(1.8, 4.1, 1.0), 0.55, "Extra", { Thickness = 0.08 }, V(0.6, 0.3, -1))
		end)
	end)

	-- Fluffy tail: a thick white curl like a breaking wave, with a feathery tuft on its back.
	b:Bone("Tail", V(0, 1.0, 0.85), nil, function()
		b:Tube(
			"Tail",
			{ V(0, 0.95, 0.55), V(0, 1.05, 1.5), V(0, 2.05, 2.0), V(0, 2.75, 1.4) },
			{ 0, 0.55, 0.5, 0 },
			"Extra",
			{ Thickness = THIN }
		)
		b:Blade("TailTuft", V(0, 1.55, 1.95), V(0, 1.35, 2.65), 0.6, "Extra", { Thickness = 0.08 }, SIDE)
	end)
end

-- Huge armoured turtle with twin water cannons coming out of its shell over the shoulders, thick clawed limbs.
Designs["Cannontoise"] = function(b)
	local torso = turtleTorso(b, V(0, 1.85, 0.12), 2.7, 2.8, 0.85, 1.1, 6)
	b:SetCore(torso)

	-- Heavy feet with two white claws.
	b:MirrorBone("Leg", V(0.72, 1.0, 0.05), nil, function()
		b:Ball("Foot", V(1.05, 0.88, 1.35), V(0.74, 0.44, -0.15), nil, "Body", { Detail = 0, Thickness = THIN })
		for index, x in { -0.2, 0.2 } do
			b:Spike(
				"Claw" .. index,
				V(0.74 + x, 0.26, -0.62),
				V(0.74 + x * 1.25, 0.12, -1.0),
				0.26,
				0.05,
				"White",
				{ Thickness = THIN },
				UP
			)
		end
	end)
	-- Thick arms ending in clawed fists.
	b:MirrorBone("Arm", V(1.15, 2.55, -0.1), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.85, 2.72, 0.0), V(1.9, 1.62, -0.7), 0.88, "Body", { RingAt = 0.55, Thickness = THIN, Up = OUT })
		for index, offset in { V(-0.18, 0.05, 0), V(0.12, -0.1, 0) } do
			b:Spike(
				"Claw" .. index,
				V(1.72, 1.78, -0.62) + offset,
				V(1.8, 1.55, -1.02) + offset * 1.3,
				0.24,
				0.05,
				"White",
				{ Thickness = THIN },
				V(0, 0.4, -1)
			)
		end
	end)

	-- Water cannons: grey barrels from inside the shell, pointing forward over the shoulders.
	for _, side in { -1, 1 } do
		barrel(b, "Cannon", V(side * 0.32, 2.3, 0.3), V(side * 1.08, 3.05, -1.05), 0, 0.37, 5, "Extra", "Dark")
	end

	b:Bone("Head", V(0, 3.0, -0.25), nil, function()
		local head = b:Ball("Head", V(1.8, 1.5, 1.65), V(0, 3.6, -0.42), nil, "Body")
		b:Eyes(head, 0.37, 0.1, V(0.36, 0.38, 0.22), TURTLE_EYE, "Angry")
		b:Mouth(head, -0.38, 0.55)
		b:MirrorSpike("Ear", V(0.45, 4.0, -0.4), V(0.78, 4.55, -0.3), 0.42, 0.08, "Body", { Thickness = 0.08 }, V(0.3, 0, -1))
	end)

	b:Bone("Tail", V(0, 0.95, 1.0), nil, function()
		b:Spike("Tail", V(0, 0.95, 0.85), V(0, 0.42, 1.8), 0.7, 0.1, "Body", { Thickness = 0.1 }, UP)
	end)
end

-- Ghost family -------------------------------------------------------------------------------

-- Floating dark gas ball wrapped in a swirling purple haze.
Designs["Ghastling"] = function(b)
	b.Hover = 1.3
	local ball = b:Ball("Ball", V(2.0, 1.95, 1.9), V(0, 1.5, 0), nil, "Body")
	b:SetCore(ball)
	local eye = V(0.62, 0.52, 0.25)
	b:Eyes(ball, 0.44, 0.2, eye, "White", "Dazed")
	eyelids(b, ball, 0.44, 0.2, eye, "Body")
	b:Mouth(ball, -0.42, 0.85, true)
	fang(b, ball, -0.24, -0.3, 0.13, 0.2)
	fang(b, ball, 0.24, -0.3, 0.13, 0.2)

	-- Haze: a see-through purple cloud wrapping the back half of the ball (the face pokes out of it), then gas
	-- wisps all around it, swirling clockwise (three groups bobbing out of step).
	b:Ball("Haze", V(3.0, 2.9, 2.1), V(0, 1.5, 0.45), nil, "Accent", { Transparency = 0.4, Detail = 1 })
	local center = V(0, 1.5, 0.3)
	for group = 1, 3 do
		b:Bone("FloatGas" .. group, center, { Phase = group / 3 }, function()
			for index = group, 15, 3 do
				local angle = math.rad(index * 24 + 8)
				local swirl = angle - math.rad(32)
				local long = index % 2 == 0
				local reach = if long then 2.05 else 1.65
				-- alternate wisps lean backwards so the gas also has depth seen from the side
				local back = if index % 3 == 0 then 0.9 elseif long then 0.35 else -0.05
				b:Spike(
					"Gas",
					center + V(math.cos(angle), math.sin(angle), 0) * 0.75 + V(0, 0, back * 0.3),
					center + V(math.cos(swirl), math.sin(swirl), 0) * reach + V(0, 0, back),
					if long then 0.85 else 0.7,
					0.4,
					"Accent",
					{ Transparency = 0.25, Thickness = THIN }
				)
			end
		end)
	end
	b:Particles(ball, GAS, 5, 0.5)
end

-- Floating ghost head with a spiky crown, a wide dark grin with the tongue out, a wispy tail and two detached
-- clawed hands.
Designs["Hauntling"] = function(b)
	b.Hover = 1.5
	local body = b:Ball("Body", V(2.6, 2.2, 2.0), V(0, 2.45, 0), nil, "Body")
	b:SetCore(body)

	-- Spiky crown: two big horns sweeping up and out and two side points (ear bones that twitch), a tuft at the back.
	b:MirrorBone("Ear", V(0.7, 3.15, 0.1), nil, function()
		b:Spike("Horn", V(0.45, 3.0, 0.1), V(1.45, 4.55, 0.4), 0.95, 0.5, "Body", { Thickness = THIN })
		b:Spike("SideSpike", V(1.0, 2.6, 0.15), V(2.1, 3.05, 0.55), 0.7, 0.1, "Body", { Thickness = THIN }, V(0, 0.3, -1))
	end)
	b:Spike("Tuft", V(0, 3.2, 0.45), V(0, 3.9, 1.3), 0.95, 0.1, "Body", { Thickness = THIN }, UP)

	-- Wispy tail: the body thins into a curling point below.
	b:Bone("Tail", V(0, 1.7, 0.2), nil, function()
		b:Tube("Tail", { V(0, 2.2, 0.1), V(0, 1.45, 0.25), V(0.3, 0.75, 0.55), V(1.0, 0.35, 1.2) }, { 0, 0.75, 0.42, 0 }, "Body")
	end)

	b:Eyes(body, 0.52, 0.32, V(0.62, 0.46, 0.26), GHOST_EYE, "Angry")
	-- Wide dark grin with a big pink tongue hanging out.
	grin(b, body, { HalfWidth = 0.95, Top = -0.18, Bottom = -0.75, Curl = 0.4, Color = "Mouth", Columns = 7, Lift = 0.1 })
	local tongue = b:OnSurface(body, 0.18, -0.62)
	b:Spike(
		"Tongue",
		tongue.Position + V(0, 0.06, -0.12),
		tongue.Position + V(0.06, -0.5, -0.3),
		0.36,
		0.1,
		"Tongue",
		{ Thickness = 0.08 },
		V(0, 0.4, -1)
	)

	b:Bone("FloatHandR", V(1.95, 2.15, -0.7), { Phase = 0 }, function()
		ghostHand(b, V(1.95, 2.15, -0.7), 1, 1.2, "Body")
	end)
	b:Bone("FloatHandL", V(-1.95, 2.15, -0.7), { Phase = 0.5 }, function()
		ghostHand(b, V(-1.95, 2.15, -0.7), -1, 1.2, "Body")
	end)
	b:Particles(body, GAS, 4, 0.5)
end

-- Grinning spiky shadow ghost standing on stubby clawed legs.
Designs["Gloomer"] = function(b)
	local body = b:Ball("Body", V(3.0, 2.6, 2.4), V(0, 1.72, 0.05), nil, "Body")
	b:SetCore(body)

	b:MirrorBone("Leg", V(0.75, 0.75, 0.1), nil, function()
		b:Ball("Foot", V(0.95, 0.9, 1.2), V(0.78, 0.45, -0.08), nil, "Body", { Detail = 0, Thickness = THIN })
		for index, x in { -0.22, 0.0, 0.22 } do
			b:Spike("Toe" .. index, V(0.78 + x, 0.3, -0.5), V(0.78 + x * 1.3, 0.1, -0.88), 0.24, 0.05, "Body", { Thickness = THIN }, UP)
		end
	end)
	b:MirrorBone("Arm", V(1.2, 1.75, -0.25), { Phase = 0.5 }, function()
		b:Limb("Arm", V(1.0, 1.82, -0.15), V(1.88, 1.3, -0.82), 0.55, "Body", { RingAt = 0.55, Thickness = THIN, Up = OUT })
		b:Spike("Claw1", V(1.78, 1.4, -0.85), V(1.86, 1.68, -1.22), 0.24, 0.06, "Body", { Thickness = THIN })
		b:Spike("Claw2", V(1.86, 1.3, -0.88), V(2.12, 1.32, -1.22), 0.24, 0.06, "Body", { Thickness = THIN })
		b:Spike("Claw3", V(1.8, 1.2, -0.85), V(1.92, 0.98, -1.18), 0.24, 0.06, "Body", { Thickness = THIN })
	end)
	b:MirrorBone("Ear", V(0.85, 2.75, 0.05), nil, function()
		b:Spike("Ear", V(0.78, 2.68, 0.05), V(1.4, 4.0, 0.22), 0.9, 0.45, "Body", { Thickness = THIN })
	end)

	-- Spiky back: a crest along the spine and two rows on the sides.
	b:Spike("BackSpike", V(0, 2.75, 0.75), V(0, 3.5, 1.55), 0.75, 0.45, "Body", { Thickness = THIN }, UP)
	b:MirrorSpike("Spike1", V(0.6, 2.6, 0.8), V(1.1, 3.15, 1.7), 0.7, 0.45, "Body", { Thickness = THIN })
	b:MirrorSpike("Spike2", V(1.0, 2.05, 0.85), V(1.75, 2.35, 1.65), 0.7, 0.45, "Body", { Thickness = THIN })
	b:MirrorSpike("Spike3", V(1.05, 1.35, 0.85), V(1.75, 1.15, 1.6), 0.65, 0.1, "Body", { Thickness = 0.08 }, V(1, 0, -0.3))

	b:Bone("Tail", V(0, 0.8, 1.0), nil, function()
		b:Spike("Tail", V(0, 0.9, 0.9), V(0, 0.5, 1.85), 0.6, 0.45, "Body", { Thickness = THIN }, UP)
	end)

	b:Eyes(body, 0.6, 0.38, V(0.62, 0.4, 0.25), GLOOM_EYE, "Angry")
	-- Wide toothy grin curling up at both ends: a dark crescent with two white crescents of triangles on it (upper
	-- and lower teeth), the dark mouth showing between them.
	grin(b, body, { HalfWidth = 1.16, Top = -0.26, Bottom = -0.92, Curl = 0.44, Color = "Mouth", Lift = 0.05 })
	grin(b, body, { HalfWidth = 1.08, Top = -0.31, Bottom = -0.86, Curl = 0.42, Gap = 0.09, Lift = 0.1 })
	b:Particles(body, GAS, 4, 0.5)
end

-- Fish family --------------------------------------------------------------------------------

-- Clumsy red carp flopping on the ground: deep body, cream lips, big dazed eyes, yellow crown fin,
-- cream whiskers and fins, a big forked tail.
Designs["Flopfish"] = function(b)
	-- The body rests on its pelvic fins, a little above the ground.
	local sections = {
		{ Center = V(0, 1.08, -1.05), Width = 0.8, Height = 1.3 },
		{ Center = V(0, 1.11, -0.3), Width = 1.2, Height = 2.0 },
		{ Center = V(0, 1.13, 0.5), Width = 0.95, Height = 1.65 },
		{ Center = V(0, 1.16, 1.1), Width = 0.42, Height = 0.7 },
	}
	local body = loft(b, "Body", sections, V(0, 1.0, -1.55), V(0, 1.18, 1.42), 6, function(_, band, out, kind)
		if band == 0 then
			return "Accent" -- cream lips
		elseif out.Y < -0.45 then
			return "Belly"
		elseif band == 2 and kind == 1 and math.abs(out.X) > 0.3 then
			return "Belly" -- big pale scales on the flanks
		end
		return "Body"
	end)
	b:SetCore(body)
	b:Eyes(body, 0.45, 0.32, V(0.62, 0.62, 0.25), "White", "Dazed")
	b:Mouth(body, -0.12, 0.42, true)
	-- Long drooping whiskers from the corners of the mouth.
	b:MirrorSpike("Whisker", V(0.18, 1.06, -1.38), V(0.62, 0.98, -1.42), 0.11, 0.1, "Accent", { Thickness = THIN })
	b:MirrorSpike("WhiskerTip", V(0.58, 1.0, -1.41), V(0.9, 0.42, -1.1), 0.1, 0.09, "Accent", { Thickness = THIN })

	-- Crown fin: three yellow points along the back (sways a little).
	b:Bone("FinCrown", V(0, 1.88, 0.0), { Role = "Fin", Amp = 0.3 }, function()
		b:Spike("Crown1", V(0, 1.63, -0.7), V(0, 2.58, -0.5), 0.55, 0.2, "Extra", { Thickness = THIN }, SIDE)
		b:Spike("Crown2", V(0, 1.86, -0.15), V(0, 2.93, 0.15), 0.7, 0.22, "Extra", { Thickness = THIN }, SIDE)
		b:Spike("Crown3", V(0, 1.8, 0.45), V(0, 2.58, 0.85), 0.62, 0.2, "Extra", { Thickness = THIN }, SIDE)
		-- membrane joining the three points into one fin
		b:Tri("CrownWeb", V(0, 1.6, -0.75), V(0, 1.75, 0.8), V(0, 2.3, 0.05), "Extra", { Thickness = 0.08 })
	end)
	-- Pectoral fins behind the head, little pelvic fins propping the belly.
	b:MirrorBone("Fin", V(0.45, 0.78, -0.55), nil, function()
		b:Spike("Fin", V(0.4, 0.8, -0.6), V(1.15, 0.42, -0.05), 0.55, 0.08, "Accent", { Thickness = THIN }, UP)
	end)
	b:MirrorSpike("BellyFin", V(0.2, 0.42, 0.2), V(0.48, 0.03, 0.62), 0.5, 0.08, "Accent", { Thickness = THIN }, SIDE)

	-- Big forked tail fin (wags).
	b:Bone("Tail", V(0, 1.16, 1.05), nil, function()
		b:Spike("TailTop", V(0, 1.3, 1.2), V(0, 2.2, 1.95), 0.8, 0.1, "Accent", { Thickness = 0.08 }, SIDE)
		b:Spike("TailBottom", V(0, 1.06, 1.2), V(0, 0.32, 1.92), 0.8, 0.1, "Accent", { Thickness = 0.08 }, SIDE)
	end)
end

-- Furious sea serpent rearing over its own coil, jaws wide open, crest raised: blue back, cream belly band,
-- white fins and whiskers. Hovers; the coil and the tail are two nested tail bones, the neck sways the head.
Designs["Tidewyrm"] = function(b)
	b.Hover = 1.2
	local fin = { Thickness = 0.07 }
	local scutes = { Twist = 0.25 }
	-- Chest: rises from the coil, S-curved, belly to the front.
	local chest = serpent(
		b,
		"Body",
		{ V(0.5, 0.72, -0.3), V(0, 1.5, -0.62), V(0, 2.6, -0.42), V(0, 3.55, 0.12) },
		{ 0.7, 0.76, 0.76, 0.7 },
		{ V(0.4, 0.8, 0.5), V(0, 0.25, 1), V(0, 0, 1), V(0, -0.3, 1) },
		"Body",
		"Belly",
		scutes
	)
	b:SetCore(chest)
	b:Blade("Dorsal1", V(0, 2.4, 0.15), V(0, 2.8, 1.05), 0.85, "Accent", fin, SIDE)
	b:Blade("Dorsal2", V(0, 1.4, -0.05), V(0, 1.55, 0.95), 0.75, "Accent", fin, SIDE)

	-- Coil lying under the chest (right, back), then the tail rising on the left with its three-pronged fin.
	b:Bone("Tail", V(0.5, 0.72, -0.3), { Amp = 0.45 }, function()
		serpent(
			b,
			"Coil",
			{ V(0.5, 0.72, -0.3), V(1.2, 0.55, 0.7), V(-0.2, 0.55, 1.55) },
			{ 0.7, 0.6, 0.48 },
			UP,
			"Body",
			"Belly",
			{ Sides = 3 }
		)
		b:Blade("Dorsal3", V(1.1, 0.85, 0.55), V(1.8, 1.35, 1.1), 0.7, "Accent", fin, V(1, 0, -0.5))
		b:Bone("Tail2", V(-0.2, 0.55, 1.55), { Phase = 0.2 }, function()
			serpent(
				b,
				"TailEnd",
				{ V(-0.2, 0.55, 1.55), V(-1.2, 1.05, 1.15), V(-1.45, 2.2, 0.85) },
				{ 0.48, 0.34, 0 },
				V(-0.3, 0.5, 1),
				"Body",
				"Belly",
				{ Sides = 3 }
			)
			-- Three-pronged tail fin.
			local base = V(-1.42, 2, 0.88)
			local facing = V(1, 0, 0.5)
			b:Blade("TailFin1", base, V(-1.45, 3.3, 1.15), 0.6, "Accent", fin, facing)
			b:Blade("TailFin2", base, V(-2.3, 2.9, 1.25), 0.55, "Accent", fin, facing)
			b:Blade("TailFin3", base, V(-0.75, 2.95, 0.45), 0.5, "Accent", fin, facing)
		end)
	end)

	-- Neck (sways slowly) carrying the big head.
	b:Bone("Neck", V(0, 3.1, 0.1), { Role = "Tail", Amp = 0.3 }, function()
		serpent(
			b,
			"Neck",
			{ V(0, 2.85, 0.02), V(0, 3.95, 0.18), V(0, 4.6, -0.45) },
			{ 0.72, 0.64, 0.56 },
			{ V(0, -0.2, 1), V(0, 0.2, 1), V(0, 1, 0.6) },
			"Body",
			"Belly",
			scutes
		)
		b:Blade("DorsalNeck", V(0, 3.8, 0.6), V(0, 4.35, 1.45), 0.85, "Accent", fin, SIDE)

		b:Bone("Head", V(0, 4.5, -0.5), nil, function()
			local skull = b:Ball("Head", V(2.15, 1.7, 2.05), V(0, 5.05, -0.9), nil, "Body")
			-- Upper jaw: a wide snout with a ridge on top, dark palate underneath, two big fangs.
			b:Spike("UpperJaw", V(0, 4.83, -1.05), V(0, 4.77, -2.95), 1.95, 0.95, "Body", nil, UP)
			b:Tri("Palate", V(-0.66, 4.42, -1.3), V(0.66, 4.42, -1.3), V(0, 4.64, -2.6), "Mouth", { Thickness = 0.05 })
			for _, x in { -0.45, 0.45 } do
				b:Tri("Fang", V(x - 0.13, 4.53, -2.05), V(x + 0.13, 4.53, -2.05), V(x * 0.92, 3.9, -2.15), "White", { Thickness = 0.06 })
			end
			-- Dark throat between the jaws.
			local throat = b:OnSurface(skull, 0, -0.5)
			b:Tri(
				"Throat",
				throat:PointToWorldSpace(V(-0.42, 0.16, -0.03)),
				throat:PointToWorldSpace(V(0.42, 0.16, -0.03)),
				throat:PointToWorldSpace(V(0, -0.4, -0.03)),
				"Mouth",
				{ Thickness = 0.05 }
			)
			-- Lower jaw (snaps): cream, ridge underneath, red mouth on top, two small fangs.
			b:Bone("Jaw", V(0, 4.37, -1), nil, function()
				b:Spike("LowerJaw", V(0, 4.33, -1), V(0, 3.4, -2.3), 1.5, 0.62, "Belly", nil, V(0, -1, 0.3))
				b:Tri("Tongue", V(-0.52, 4.41, -1.12), V(0.52, 4.41, -1.12), V(0, 3.67, -2.05), "Mouth", { Thickness = 0.06 })
				for _, x in { -0.38, 0.38 } do
					b:Tri(
						"LowFang",
						V(x - 0.1, 3.85, -1.85),
						V(x + 0.1, 3.85, -1.85),
						V(x * 0.92, 4.27, -1.95),
						"White",
						{ Thickness = 0.06 }
					)
				end
			end)
			b:Eyes(skull, 0.58, 0.22, V(0.48, 0.36, 0.24), WYRM_EYE, "Angry")
			-- Crest: a tall central prong and two side prongs.
			b:Spike("Crest", V(0, 5.6, -0.85), V(0, 6.7, -0.15), 0.8, 0.32, "Accent", nil, SIDE)
			b:MirrorBlade("CrestSide", V(0.42, 5.53, -0.75), V(1.1, 6.4, -0.35), 0.5, "Accent", fin, V(1, 0, -0.4))
			-- Gill fins on the sides of the head.
			b:MirrorBone("Ear", V(0.85, 4.9, -0.75), nil, function()
				b:Blade("GillFin", V(0.78, 4.9, -0.8), V(1.95, 5.3, -0.2), 0.8, "Accent", fin, V(0, 0.5, -1))
			end)
			-- Long whiskers from the snout curling backwards.
			b:MirrorBlade("Whisker", V(0.6, 4.65, -2.1), V(1.45, 5, -2), 0.16, "Accent", fin, V(0, 0, -1))
			b:MirrorBlade("WhiskerTip", V(1.4, 5.03, -2), V(1.95, 4.2, -1.3), 0.15, "Accent", fin, V(0, 0, -1))
		end)
	end)
end

return Designs
