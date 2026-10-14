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

local SIDE = V(1, 0, 0)
local UP = V(0, 1, 0)

-- Shared pieces -----------------------------------------------------------------------------

--[[
	Turtle torso: one closed faceted solid painted in three colours. From the front a cream plastron (a low
	pyramid on the widest ring), around it a white rim band, behind it the brown carapace (a low dome).
	center = centre of the widest ring, width / height = extents of that ring, front / back = how far the
	plastron / carapace apexes stick out. 4 * sides triangles. Returns the plastron handle.
]]
local function turtleTorso(b, center: Vector3, width: number, height: number, front: number, back: number, sides: number)
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

	local plastronFaces, rimFaces, shellFaces = {}, {}, {}
	for k = 1, sides do
		local k1 = k % sides + 1
		table.insert(plastronFaces, { frontApex, rim + k, rim + k1 })
		-- shell vertex k sits between rim vertices k - 1 and k
		table.insert(rimFaces, { shell + k, rim + k, shell + k1 })
		table.insert(rimFaces, { rim + k, shell + k1, rim + k1 })
		table.insert(shellFaces, { backApex, shell + k, shell + k1 })
	end
	local plastron = b:Mesh("Plastron", vertices, plastronFaces, "Belly")
	b:Mesh("ShellRim", vertices, rimFaces, SHELL_RIM)
	b:Mesh("Shell", vertices, shellFaces, "Accent")
	return plastron
end

-- Low faceted foot standing on the ground: a pyramid on a diamond (toe, sides, heel), 6 triangles.
local function pawFoot(b, name: string, base: Vector3, size: Vector3, color: any)
	local w, h, l = size.X / 2, size.Y, size.Z
	local vertices = {
		base + V(0, h * 0.12, -l * 0.58), -- toe
		base + V(w, 0, -l * 0.08),
		base + V(0, 0, l * 0.42), -- heel
		base + V(-w, 0, -l * 0.08),
		base + V(0, h, 0), -- top, hidden in the leg / body
	}
	return b:Mesh(name, vertices, { { 1, 2, 5 }, { 2, 3, 5 }, { 3, 4, 5 }, { 4, 1, 5 }, { 1, 2, 3 }, { 1, 3, 4 } }, color)
end

-- Small flat triangle on a face (fangs, teeth): base centred at (x, y) on the shape, pointing `dir` (2D).
local function fang(b, head, x: number, y: number, width: number, length: number, color: any, down: boolean?)
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

-- Ghost hand (built inside a Float bone): faceted palm, three clawed fingers and a jagged cuff.
local function ghostHand(b, palm: Vector3, side: number, size: number, color: any)
	b:Ball("Palm", V(0.62, 0.56, 0.5) * size, palm, nil, color, { Detail = 0 })
	local fingers = { V(0.12, 0.85, -0.2), V(0.62, 0.62, -0.28), V(0.85, 0.12, -0.22) }
	for index, offset in fingers do
		local dir = V(offset.X * side, offset.Y, offset.Z)
		b:Spike("Finger" .. index, palm + dir.Unit * 0.1 * size, palm + dir * size, 0.24 * size, 0.2 * size, color)
	end
	b:Spike("Cuff", palm + V(-side * 0.12, -0.05, 0.05) * size, palm + V(-side * 0.62, -0.3, 0.2) * size, 0.5 * size, 0.3 * size, color)
end

-- Turtle family ------------------------------------------------------------------------------

-- Little blue turtle: big round head, cream plastron, white rimmed brown shell, curly tail.
Designs["Puddlet"] = function(b)
	local torso = turtleTorso(b, V(0, 1.12, 0.02), 1.72, 1.7, 0.62, 0.78, 6)
	b:SetCore(torso)

	b:MirrorBone("Leg", V(0.48, 0.55, -0.05), nil, function()
		pawFoot(b, "Foot", V(0.5, 0, -0.2), V(0.66, 0.78, 0.92), "Body")
	end)
	b:MirrorBone("Arm", V(0.64, 1.6, -0.12), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.56, 1.66, -0.1), V(1.14, 1.18, -0.52), 0.44, "Body", { RingAt = 0.6 })
	end)

	b:Bone("Head", V(0, 1.95, -0.05), nil, function()
		local head = b:Ball("Head", V(2.1, 1.85, 1.8), V(0, 2.78, -0.15), nil, "Body")
		b:Eyes(head, 0.46, 0.08, V(0.5, 0.64, 0.26), TURTLE_EYE)
		b:Mouth(head, -0.45, 0.5, true)
	end)

	b:Bone("Tail", V(0, 0.62, 0.5), nil, function()
		b:Tube("Tail", { V(0, 0.62, 0.4), V(0, 0.48, 1.1), V(0, 0.85, 1.55), V(0, 1.3, 1.35) }, { 0.28, 0.26, 0.2, 0 }, "Body")
	end)
end

-- Bigger turtle: feathery white ears, two little fangs and a big fluffy white tail.
Designs["Shellwave"] = function(b)
	local torso = turtleTorso(b, V(0, 1.5, 0.05), 1.85, 2.15, 0.65, 0.85, 6)
	b:SetCore(torso)

	b:MirrorBone("Leg", V(0.52, 0.75, 0.0), nil, function()
		b:Spike("Thigh", V(0.5, 1.0, 0.05), V(0.55, 0.15, -0.15), 0.55, 0.5, "Body")
		pawFoot(b, "Foot", V(0.56, 0, -0.22), V(0.62, 0.5, 0.95), "Body")
	end)
	b:MirrorBone("Arm", V(0.7, 2.0, -0.1), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.6, 2.05, -0.08), V(1.2, 1.5, -0.55), 0.42, "Body", { RingAt = 0.6 })
	end)

	b:Bone("Head", V(0, 2.5, -0.05), nil, function()
		local head = b:Ball("Head", V(1.8, 1.6, 1.65), V(0, 3.2, -0.2), nil, "Body")
		b:Eyes(head, 0.4, 0.1, V(0.42, 0.52, 0.25), TURTLE_EYE)
		b:Mouth(head, -0.4, 0.42)
		fang(b, head, -0.14, -0.43, 0.1, 0.16)
		fang(b, head, 0.14, -0.43, 0.1, 0.16)
		b:MirrorBone("Ear", V(0.65, 3.5, 0.0), nil, function()
			b:Spike("Ear", V(0.6, 3.55, 0.0), V(1.35, 4.6, 0.55), 0.7, 0.12, "Extra", nil, V(1, 0, -0.4))
			b:Spike("EarCurl", V(0.75, 3.4, 0.1), V(1.7, 3.95, 0.75), 0.55, 0.12, "Extra", nil, V(1, 0, -0.4))
		end)
	end)

	b:Bone("Tail", V(0, 0.95, 0.8), nil, function()
		b:Spike("Tail1", V(0, 1.0, 0.75), V(0, 2.6, 1.7), 0.9, 0.75, "Extra")
		b:Spike("Tail2", V(0.2, 0.9, 0.8), V(0.55, 1.9, 2.1), 0.75, 0.6, "Extra")
		b:Spike("Tail3", V(-0.2, 0.9, 0.8), V(-0.55, 1.7, 2.0), 0.75, 0.6, "Extra")
		b:Spike("TailCurl", V(0, 2.3, 1.6), V(0, 2.3, 1.05), 0.55, 0.4, "Extra")
	end)
end

-- Huge armoured turtle with twin water cannons sticking out of its shell.
Designs["Cannontoise"] = function(b)
	local torso = turtleTorso(b, V(0, 1.8, 0.1), 2.6, 2.75, 0.8, 1.05, 6)
	b:SetCore(torso)

	b:MirrorBone("Leg", V(0.75, 0.85, 0.05), nil, function()
		pawFoot(b, "Foot", V(0.85, 0, -0.3), V(0.95, 1.1, 1.25), "Body")
	end)
	b:MirrorBone("Arm", V(1.1, 2.55, -0.2), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.95, 2.65, -0.15), V(1.65, 1.75, -0.8), 0.72, "Body", { RingAt = 0.55 })
	end)

	-- Cannons: square barrels whose muzzle folds inwards (a dark funnel).
	for _, side in { -1, 1 } do
		local back, muzzle = V(side * 0.95, 3.0, 0.35), V(side * 1.0, 3.2, -1.05)
		local dir = (muzzle - back).Unit
		b:Tube("Cannon", { back, muzzle, muzzle - dir * 0.35 }, { 0.36, 0.36, 0 }, "Extra", { Sides = 4, Up = UP })
	end

	b:Bone("Head", V(0, 3.2, -0.2), nil, function()
		local head = b:Ball("Head", V(1.5, 1.3, 1.5), V(0, 3.8, -0.5), nil, "Body", { Detail = 1 })
		b:Eyes(head, 0.34, 0.08, V(0.32, 0.34, 0.22), TURTLE_EYE, "Angry")
		b:Mouth(head, -0.36, 0.5)
		b:MirrorBone("Ear", V(0.45, 4.25, -0.4), nil, function()
			b:Spike("Ear", V(0.42, 4.2, -0.38), V(0.72, 4.85, -0.25), 0.4, 0.1, "Body", nil, V(0, 0, -1))
		end)
	end)

	b:Bone("Tail", V(0, 0.9, 1.0), nil, function()
		b:Cone("Tail", V(0, 0.95, 0.9), V(0, 0.45, 1.75), 0.3, "Body")
	end)
end

-- Ghost family -------------------------------------------------------------------------------

-- Floating dark gas ball wrapped in a swirling purple haze.
Designs["Ghastling"] = function(b)
	b.Hover = 1.3
	local ball = b:Ball("Ball", V(2.0, 1.95, 1.85), V(0, 1.5, 0), nil, "Body")
	b:SetCore(ball)
	b:Eyes(ball, 0.42, 0.18, V(0.6, 0.5, 0.25), "White", "Dazed")
	eyelids(b, ball, 0.42, 0.18, V(0.6, 0.5, 0.25), "Body")
	b:Mouth(ball, -0.42, 0.8, true)
	fang(b, ball, -0.22, -0.32, 0.12, 0.18)
	fang(b, ball, 0.22, -0.32, 0.12, 0.18)

	b:Ball("Haze", V(2.9, 2.8, 1.1), V(0, 1.5, 0.5), nil, "Accent", { Transparency = 0.55, Detail = 1 })
	local center = V(0, 1.5, 0.3)
	for group = 1, 3 do
		b:Bone("FloatGas" .. group, center, { Phase = group / 3 }, function()
			for index = group, 9, 3 do
				local angle = math.rad(index * 40 + 10)
				local swirl = angle + math.rad(28)
				local reach = if index % 2 == 0 then 1.95 else 1.7
				local z = if index % 2 == 0 then 0.15 else -0.05
				b:Spike(
					"Gas",
					center + V(math.cos(angle), math.sin(angle), 0) * 0.75 + V(0, 0, z),
					center + V(math.cos(swirl), math.sin(swirl), 0) * reach + V(0, 0, z + 0.2),
					0.8,
					0.36,
					"Accent",
					{ Transparency = 0.35 }
				)
			end
		end)
	end
	b:Particles(ball, GAS, 5, 0.5)
end

-- Floating ghost head with a spiky crown, a wispy tail and two detached clawed hands.
Designs["Hauntling"] = function(b)
	b.Hover = 1.2
	local body = b:Ball("Body", V(2.4, 2.1, 1.85), V(0, 2.3, 0), nil, "Body")
	b:SetCore(body)

	b:MirrorBone("Ear", V(0.7, 3.05, 0.1), nil, function()
		b:Spike("Horn", V(0.6, 3.0, 0.1), V(1.35, 4.25, 0.35), 0.85, 0.5, "Body")
		b:Spike("SideSpike", V(1.0, 2.6, 0.15), V(1.85, 2.95, 0.5), 0.6, 0.4, "Body")
	end)
	b:Spike("Tuft", V(0, 3.15, 0.35), V(0, 3.75, 1.15), 0.8, 0.45, "Body", nil, UP)

	b:Bone("Tail", V(0, 1.6, 0.2), nil, function()
		b:Tube("Tail", { V(0, 1.75, 0.15), V(0.25, 1.0, 0.45), V(0.6, 0.45, 1.0) }, { 0.75, 0.38, 0 }, "Body")
	end)

	b:Eyes(body, 0.5, 0.3, V(0.58, 0.42, 0.25), GHOST_EYE, "Angry")
	b:Mouth(body, -0.4, 1.0, true)

	b:Bone("FloatHandR", V(1.95, 2.0, -0.6), { Phase = 0 }, function()
		ghostHand(b, V(1.95, 2.0, -0.6), 1, 1, "Body")
	end)
	b:Bone("FloatHandL", V(-1.95, 2.0, -0.6), { Phase = 0.5 }, function()
		ghostHand(b, V(-1.95, 2.0, -0.6), -1, 1, "Body")
	end)
	b:Particles(body, GAS, 4, 0.5)
end

-- Grinning spiky shadow ghost.
Designs["Gloomer"] = function(b)
	local body = b:Ball("Body", V(3.0, 2.6, 2.4), V(0, 1.75, 0.05), nil, "Body")
	b:SetCore(body)

	b:MirrorBone("Leg", V(0.75, 0.75, 0.1), nil, function()
		pawFoot(b, "Foot", V(0.8, 0, -0.15), V(0.85, 0.85, 1.15), "Body")
	end)
	b:MirrorBone("Arm", V(1.25, 1.7, -0.3), { Phase = 0.5 }, function()
		b:Limb("Arm", V(1.15, 1.75, -0.25), V(1.85, 1.3, -0.8), 0.55, "Body", { RingAt = 0.55 })
		b:Spike("Claw1", V(1.8, 1.4, -0.9), V(1.9, 1.62, -1.25), 0.2, 0.06, "Body")
		b:Spike("Claw2", V(1.92, 1.3, -0.9), V(2.15, 1.32, -1.22), 0.2, 0.06, "Body")
		b:Spike("Claw3", V(1.85, 1.2, -0.88), V(1.95, 1.0, -1.18), 0.2, 0.06, "Body")
	end)
	b:MirrorBone("Ear", V(0.85, 2.75, 0.05), nil, function()
		b:Spike("Ear", V(0.8, 2.7, 0.05), V(1.35, 3.95, 0.2), 0.85, 0.45, "Body")
	end)

	b:Spike("BackSpike", V(0, 2.75, 0.75), V(0, 3.45, 1.55), 0.75, 0.45, "Body", nil, UP)
	b:MirrorSpike("Spike1", V(0.65, 2.55, 0.85), V(1.15, 3.05, 1.7), 0.7, 0.45, "Body")
	b:MirrorSpike("Spike2", V(1.05, 2.0, 0.85), V(1.75, 2.3, 1.6), 0.7, 0.45, "Body")
	b:MirrorSpike("Spike3", V(1.1, 1.3, 0.85), V(1.7, 1.15, 1.55), 0.6, 0.4, "Body")

	b:Bone("Tail", V(0, 0.8, 1.0), nil, function()
		b:Spike("Tail", V(0, 0.85, 0.95), V(0, 0.55, 1.85), 0.55, 0.45, "Body", nil, UP)
	end)

	b:Eyes(body, 0.6, 0.38, V(0.62, 0.4, 0.25), GLOOM_EYE, "Angry")
	-- Wide toothy grin: a white crescent of triangles lying on the face, split by a dark line.
	local top, bottom = {}, {}
	for i = 0, 4 do
		local x = -0.95 + 0.475 * i
		local t = (x / 0.95) ^ 2
		top[i] = (b:OnSurface(body, x, -0.25 + 0.3 * t) * CFrame.new(0, 0, -0.05)).Position
		bottom[i] = (b:OnSurface(body, x, -0.75 + 0.8 * t) * CFrame.new(0, 0, -0.05)).Position
	end
	for i = 0, 3 do
		b:Tri("Grin", top[i], top[i + 1], bottom[i + 1], "White")
		b:Tri("Grin", top[i], bottom[i + 1], bottom[i], "White")
	end
	b:Mouth(body, -0.45, 1.5)
	b:Particles(body, GAS, 4, 0.5)
end

-- Fish family --------------------------------------------------------------------------------

-- Clumsy red carp flopping its tail, with a yellow crown fin, cream fins and whiskers.
Designs["Flopfish"] = function(b)
	local body = b:Ball("Body", V(1.35, 2.3, 2.15), V(0, 1.12, 0.05), V(-90, 0, 0), "Body")
	b:SetCore(body)
	b:Eyes(body, 0.4, 0.3, V(0.55, 0.55, 0.25), "White", "Dazed")
	b:FaceDot("Lips", body, 0, -0.35, V(0.7, 0.6, 0.16), "Accent")
	b:Mouth(body, -0.35, 0.45, true)
	b:MirrorSpike("Whisker", V(0.3, 0.85, -0.95), V(0.75, 0.55, -1.15), 0.12, 0.1, "Accent")
	b:MirrorSpike("WhiskerTip", V(0.72, 0.58, -1.13), V(0.95, 0.1, -1.0), 0.1, 0.08, "Accent")

	b:Bone("FinCrown", V(0, 2.1, 0.0), { Role = "Fin", Amp = 0.3 }, function()
		b:Spike("Crown1", V(0, 1.95, -0.55), V(0, 2.75, -0.45), 0.6, 0.12, "Extra", nil, SIDE)
		b:Spike("Crown2", V(0, 2.05, 0.0), V(0, 3.0, 0.15), 0.7, 0.14, "Extra", nil, SIDE)
		b:Spike("Crown3", V(0, 1.95, 0.55), V(0, 2.7, 0.85), 0.6, 0.12, "Extra", nil, SIDE)
	end)
	b:MirrorBone("Fin", V(0.6, 0.85, -0.3), nil, function()
		b:Spike("Fin", V(0.55, 0.85, -0.3), V(1.35, 0.4, 0.25), 0.6, 0.1, "Accent", nil, UP)
	end)
	b:MirrorSpike("BellyFin", V(0.3, 0.3, 0.3), V(0.5, 0.0, 0.75), 0.5, 0.1, "Accent", nil, SIDE)

	b:Bone("Tail", V(0, 1.15, 0.9), nil, function()
		b:Spike("TailStalk", V(0, 1.15, 0.7), V(0, 1.35, 1.65), 0.7, 0.45, "Body", nil, UP)
		b:Spike("TailFinTop", V(0, 1.4, 1.5), V(0, 2.3, 2.15), 0.75, 0.1, "Accent", nil, SIDE)
		b:Spike("TailFinBottom", V(0, 1.3, 1.5), V(0, 0.55, 2.3), 0.75, 0.1, "Accent", nil, SIDE)
	end)
end

-- Furious sea serpent rearing out of its own coils, jaws wide open.
Designs["Tidewyrm"] = function(b)
	b.Hover = 1.0
	-- Neck and belly (body), then the coil and the tail in two nested tail bones.
	local core = b:Tube(
		"Body",
		{ V(0, 4.75, -0.45), V(0, 3.8, 0.1), V(0, 2.8, 0.25), V(0, 1.85, -0.05), V(0.25, 1.05, -0.65) },
		{ 0.48, 0.55, 0.62, 0.66, 0.66 },
		"Body"
	)
	b:SetCore(core)
	b:Blade("BellyPlate1", V(0, 3.0, -0.4), V(0, 3.9, -0.55), 0.7, "Belly", { Thickness = 0.1 })
	b:Blade("BellyPlate2", V(0, 2.0, -0.6), V(0, 2.9, -0.4), 0.8, "Belly", { Thickness = 0.1 })
	b:Bone("Tail", V(0.25, 1.05, -0.65), nil, function()
		b:Tube("Coil", { V(0.25, 1.05, -0.65), V(1.15, 0.7, -0.75), V(1.75, 0.75, 0.15), V(1.3, 0.95, 1.15) }, { 0.64, 0.6, 0.55, 0.5 }, "Body")
		b:Spike("Dorsal1", V(1.75, 1.2, 0.15), V(2.1, 1.75, 0.6), 0.6, 0.1, "Accent", nil, V(1, 0, -0.3))
		b:Bone("Tail2", V(1.3, 0.95, 1.15), { Phase = 0.25 }, function()
			b:Tube("TailEnd", { V(1.3, 0.95, 1.15), V(0.2, 1.35, 1.65), V(-0.85, 2.0, 1.75), V(-1.45, 2.85, 1.45) }, { 0.5, 0.42, 0.3, 0 }, "Body")
			b:Spike("Dorsal2", V(0.2, 1.75, 1.75), V(0.0, 2.2, 2.25), 0.55, 0.1, "Accent", nil, V(0, 0, 1))
			b:Spike("TailFin1", V(-1.4, 2.75, 1.45), V(-1.25, 3.7, 1.9), 0.6, 0.1, "Accent", nil, V(1, 0, 0.4))
			b:Spike("TailFin2", V(-1.4, 2.75, 1.45), V(-2.05, 3.5, 1.7), 0.6, 0.1, "Accent", nil, V(1, 0, 0.4))
		end)
	end)
	b:Spike("Dorsal3", V(0, 3.3, 0.55), V(0, 3.75, 1.15), 0.6, 0.1, "Accent", nil, SIDE)
	b:Spike("Dorsal4", V(0, 2.2, 0.55), V(0, 2.55, 1.15), 0.6, 0.1, "Accent", nil, SIDE)

	b:Bone("Head", V(0, 4.75, -0.45), nil, function()
		local head = b:Ball("Head", V(1.6, 1.25, 1.55), V(0, 5.3, -0.75), nil, "Body", { Detail = 1 })
		-- Upper jaw: wide triangular snout (ridge on top), red palate underneath.
		b:Spike("UpperJaw", V(0, 5.15, -0.55), V(0, 4.95, -2.05), 1.3, 0.6, "Body", nil, UP)
		b:Bone("Jaw", V(0, 4.75, -0.6), nil, function()
			b:Spike("LowerJaw", V(0, 4.65, -0.6), V(0, 4.05, -1.75), 1.1, 0.45, "Belly", nil, V(0, -1, 0))
			fang(b, { Center = V(0, 4.3, -1.4), Size = V(1, 1, 1), Tris = {} }, -0.35, 0, 0.1, 0.2, "White", false)
		end)
		b:Eyes(head, 0.42, 0.22, V(0.36, 0.3, 0.22), "Extra", "Angry")
		b:Spike("Crest", V(0, 5.75, -0.55), V(0, 6.75, 0.0), 0.8, 0.4, "Accent", nil, V(0, 0, -1))
		b:MirrorSpike("CrestSide", V(0.35, 5.7, -0.45), V(0.75, 6.3, 0.1), 0.45, 0.1, "Accent", nil, SIDE)
		b:MirrorSpike("EarFin", V(0.7, 5.3, -0.5), V(1.55, 5.65, 0.05), 0.6, 0.1, "Accent", nil, V(0, 0.4, -1))
		b:MirrorSpike("Whisker", V(0.5, 5.0, -1.55), V(1.2, 5.2, -1.4), 0.12, 0.1, "Accent")
		b:MirrorSpike("WhiskerTip", V(1.18, 5.2, -1.4), V(1.6, 4.65, -0.95), 0.1, 0.08, "Accent")
	end)
end

return Designs
