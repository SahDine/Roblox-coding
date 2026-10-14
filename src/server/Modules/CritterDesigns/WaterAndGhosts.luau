--[[
	Critter designs: Puddlet, Shellwave, Cannontoise, Ghastling, Hauntling, Gloomer, Flopfish, Tidewyrm.
	See CritterBuilder for the toolkit. Ground at y = 0, the critter faces -Z.
]]

local V = Vector3.new
local V2 = Vector2.new

local Designs = {}

local TURTLE_EYE = Color3.fromRGB(150, 60, 50)
local SHELL_RIM = Color3.fromRGB(250, 246, 232)
local GHOST_EYE = Color3.fromRGB(245, 235, 250)
local GAS = Color3.fromRGB(170, 100, 230)
local GLOOM_EYE = Color3.fromRGB(225, 40, 55)

local SIDE = V(1, 0, 0)
local UP = V(0, 1, 0)

-- Shared pieces -----------------------------------------------------------------------------

-- Turtle torso: brown shell behind, white rim, cream plastron in front (the turtle family's signature).
local function turtleTorso(b, width: number, height: number, centerY: number, shellDepth: number)
	local shell = b:Gem("Shell", V(width, height, shellDepth), V(0, centerY, shellDepth / 2 + 0.05), nil, "Accent")
	b:Gem("Rim", V(width + 0.2, height + 0.14, 0.3), V(0, centerY, 0), nil, SHELL_RIM)
	local belly = b:Gem("Plastron", V(width - 0.4, height - 0.25, 0.6), V(0, centerY - 0.05, -0.2), nil, "Belly")
	return shell, belly
end

-- Ghost gas: translucent triangles radiating (and swirling) from a centre in the XY plane.
local function gasRing(b, center: Vector3, count: number, inner: number, outer: number, width: number, startAngle: number, color: any)
	for index = 1, count do
		local angle = math.rad(startAngle + (index - 1) * 360 / count)
		local swirl = angle + math.rad(24)
		local dir = V(math.cos(angle), math.sin(angle), 0)
		local tipDir = V(math.cos(swirl), math.sin(swirl), 0)
		local z = if index % 2 == 0 then 0.1 else -0.1
		b:Spike("Gas" .. index, center + dir * inner + V(0, 0, z), center + tipDir * outer + V(0, 0, z), width, 0.2, color, { Transparency = 0.35 })
	end
end

-- Three-fingered ghost hand: a palm block and three pointed fingers fanned towards `out`.
local function ghostHand(b, name: string, palm: Vector3, out: Vector3, size: number, color: any)
	b:Box(name .. "Palm", V(0.62, 0.55, 0.4) * size, palm, nil, color)
	local side = math.sign(out.X)
	local fingers = { V(side * 0.15, 0.75, -0.05), V(side * 0.6, 0.55, -0.1), V(side * 0.75, 0.05, -0.1) }
	for index, tipOffset in fingers do
		local base = palm + V(side * 0.15, 0.1, 0) * size + tipOffset.Unit * 0.2 * size
		b:Spike(name .. "Finger" .. index, base, palm + tipOffset * size * 1.3, 0.24 * size, 0.18 * size, color)
	end
end

-- Turtle family ------------------------------------------------------------------------------

-- Little blue turtle: big round head, brown shell with a white rim, curly tail.
Designs["Puddlet"] = function(b)
	local shell = turtleTorso(b, 1.7, 1.8, 1.3, 1.0)
	b:SetCore(shell)
	b:Box("ShellPlate", V(0.7, 0.7, 0.1), V(0, 1.35, 1.1), V(0, 0, 45), "Extra")
	b:Box("PlastronLine1", V(0.9, 0.07, 0.06), V(0, 1.05, -0.52), nil, "Extra")
	b:Box("PlastronLine2", V(1.0, 0.07, 0.06), V(0, 1.45, -0.52), nil, "Extra")

	local head = b:Gem("Head", V(2.0, 1.8, 1.75), V(0, 3.0, -0.3), nil, "Body")
	b:Eyes(head, 0.48, 0.1, V(0.48, 0.66, 0.2), TURTLE_EYE)
	b:Mouth(head, -0.5, 0.5, true)

	b:MirrorLimb("Arm", V(0.75, 1.75, -0.15), V(1.2, 1.3, -0.45), 0.42, "Body")
	b:MirrorBox("Foot", V(0.62, 0.45, 0.85), V(0.5, 0.225, -0.2), nil, "Body")

	b:Chain("Tail", { V(0, 0.55, 0.8), V(0, 0.45, 1.45), V(0, 0.9, 1.95), V(0, 1.4, 1.75) }, 0.48, 0.36, "Body")
	b:Box("TailCurl", V(0.36, 0.36, 0.36), V(0, 1.3, 1.5), V(45, 0, 0), "Body")
end

-- Bigger turtle with feathery white ears and a fluffy white tail.
Designs["Shellwave"] = function(b)
	local shell = turtleTorso(b, 1.85, 2.05, 1.5, 1.15)
	b:SetCore(shell)

	local head = b:Gem("Head", V(1.85, 1.65, 1.65), V(0, 3.35, -0.3), nil, "Body")
	b:Eyes(head, 0.42, 0.12, V(0.42, 0.52, 0.2), TURTLE_EYE)
	b:FaceDot("FangL", head, -0.18, -0.48, V(0.12, 0.16, 0.14), "White")
	b:FaceDot("FangR", head, 0.18, -0.48, V(0.12, 0.16, 0.14), "White")

	b:MirrorSpike("Ear", V(0.7, 3.8, -0.1), V(1.45, 4.85, 0.5), 0.8, 0.18, "Extra")
	b:MirrorSpike("EarTuft", V(0.8, 3.6, 0.0), V(1.75, 4.1, 0.6), 0.55, 0.22, "Extra")

	b:MirrorLimb("Arm", V(0.8, 2.05, -0.2), V(1.25, 1.55, -0.55), 0.44, "Body")
	b:MirrorLimb("Leg", V(0.55, 0.9, 0.05), V(0.6, 0.35, -0.1), 0.55, "Body")
	b:MirrorBox("Foot", V(0.64, 0.4, 0.9), V(0.6, 0.2, -0.25), nil, "Body")

	b:Gem("Tail", V(0.45, 1.5, 1.5), V(0, 1.55, 1.85), nil, "Extra", { Axis = "X" })
end

-- Huge armoured turtle with twin water cannons sticking out of its shell.
Designs["Cannontoise"] = function(b)
	local shell = turtleTorso(b, 2.6, 2.7, 2.0, 1.6)
	b:SetCore(shell)

	local head = b:Gem("Head", V(1.5, 1.3, 1.45), V(0, 3.95, -0.5), nil, "Body")
	b:Eyes(head, 0.36, 0.1, V(0.32, 0.36, 0.16), TURTLE_EYE, "Angry")
	b:Mouth(head, -0.35, 0.5)
	b:MirrorSpike("Ear", V(0.5, 4.45, -0.4), V(0.78, 5.0, -0.3), 0.42, 0.14, "Body")

	b:MirrorGem("Cannon", V(0.66, 0.66, 2.1), V(1.15, 3.45, -0.15), nil, "Extra")
	b:MirrorBox("Muzzle", V(0.36, 0.36, 0.1), V(1.15, 3.45, -1.22), nil, "Dark")

	b:MirrorLimb("Arm", V(1.2, 2.6, -0.4), V(1.55, 1.85, -0.85), 0.75, "Body")
	b:MirrorLimb("Leg", V(0.8, 1.0, 0.1), V(0.85, 0.35, -0.05), 0.85, "Body")
	b:MirrorBox("Foot", V(0.9, 0.45, 1.1), V(0.85, 0.225, -0.25), nil, "Body")
	b:Limb("Tail", V(0, 0.9, 1.5), V(0, 0.55, 2.0), 0.5, "Body")
end

-- Ghost family -------------------------------------------------------------------------------

-- Floating dark gas ball wrapped in a purple haze.
Designs["Ghastling"] = function(b)
	b.Hover = 0.9
	local ball = b:Gem("Ball", V(2.0, 2.0, 1.8), V(0, 1.5, 0), nil, "Body")
	b:SetCore(ball)
	b:Gem("Haze", V(2.9, 2.9, 0.9), V(0, 1.5, 0.6), nil, "Accent", { Transparency = 0.45 })
	gasRing(b, V(0, 1.5, 0.3), 6, 1.0, 2.0, 0.9, 30, "Accent")
	b:Eyes(ball, 0.45, 0.22, V(0.62, 0.55, 0.18), "White", "Dazed")
	b:FaceDot("Mouth", ball, 0, -0.42, V(1.0, 0.42, 0.14), "Mouth")
	b:FaceDot("Tongue", ball, 0, -0.52, V(0.45, 0.2, 0.18), "Tongue")
	b:FaceDot("FangL", ball, -0.3, -0.28, V(0.14, 0.16, 0.18), "White")
	b:FaceDot("FangR", ball, 0.3, -0.28, V(0.14, 0.16, 0.18), "White")
	b:Particles(ball.Part, GAS, 5, 0.5)
end

-- Floating ghost with a spiky head, a wispy tail and two detached clawed hands.
Designs["Hauntling"] = function(b)
	b.Hover = 0.7
	local body = b:Gem("Body", V(2.5, 2.1, 1.8), V(0, 2.3, 0), nil, "Body")
	b:SetCore(body)
	b:MirrorSpike("Horn", V(0.75, 3.1, 0.1), V(1.45, 4.2, 0.35), 0.9, 0.3, "Body")
	b:MirrorSpike("SideSpike", V(1.1, 2.6, 0.2), V(1.9, 2.9, 0.5), 0.6, 0.25, "Body")
	b:Spike("Tuft", V(0, 3.2, 0.4), V(0, 3.9, 1.2), 0.9, 0.3, "Body", nil, SIDE)
	b:Spike("Tail", V(0, 1.4, 0.2), V(0.45, 0.1, 0.8), 1.8, 0.55, "Body")
	b:Spike("TailCurl", V(0.3, 0.6, 0.6), V(-0.3, 0.0, 1.1), 0.6, 0.4, "Body")

	ghostHand(b, "HandR", V(2.0, 2.2, -0.7), V(1, 0, 0), 1, "Body")
	ghostHand(b, "HandL", V(-2.0, 2.2, -0.7), V(-1, 0, 0), 1, "Body")

	b:Eyes(body, 0.52, 0.3, V(0.6, 0.45, 0.18), GHOST_EYE, "Angry")
	b:FaceDot("Mouth", body, 0, -0.42, V(1.3, 0.45, 0.14), "Mouth")
	b:FaceDot("Tongue", body, 0, -0.54, V(0.6, 0.22, 0.18), "Tongue")
	b:Particles(body.Part, GAS, 4, 0.5)
end

-- Grinning spiky shadow ghost.
Designs["Gloomer"] = function(b)
	local body = b:Gem("Body", V(3.0, 2.6, 2.4), V(0, 1.75, 0.05), nil, "Body")
	b:SetCore(body)
	b:MirrorSpike("Ear", V(0.9, 2.75, 0.05), V(1.4, 3.95, 0.2), 0.9, 0.35, "Body")
	local spikeFacing = V(1, 0, -0.5)
	b:Spike("BackSpike", V(0, 2.9, 0.8), V(0, 3.6, 1.6), 0.7, 0.28, "Body", nil, SIDE)
	b:MirrorSpike("Spike1", V(0.8, 2.6, 0.9), V(1.2, 3.2, 1.7), 0.65, 0.25, "Body", nil, spikeFacing)
	b:MirrorSpike("Spike2", V(1.3, 1.9, 0.9), V(2.0, 2.3, 1.6), 0.65, 0.25, "Body", nil, spikeFacing)
	b:MirrorSpike("Spike3", V(1.25, 1.1, 0.9), V(1.9, 1.0, 1.6), 0.6, 0.25, "Body", nil, spikeFacing)

	b:MirrorLimb("Arm", V(1.35, 1.6, -0.4), V(1.85, 1.3, -0.85), 0.6, "Body")
	b:MirrorBox("Hand", V(0.48, 0.48, 0.48), V(1.88, 1.28, -0.9), nil, "Body")
	b:MirrorSpike("Claw1", V(1.85, 1.35, -1.05), V(1.95, 1.6, -1.4), 0.22, 0.16, "Body")
	b:MirrorSpike("Claw2", V(2.02, 1.22, -1.0), V(2.3, 1.3, -1.35), 0.22, 0.16, "Body")
	b:MirrorBox("Foot", V(0.9, 0.48, 1.1), V(0.85, 0.24, -0.3), nil, "Body")
	b:Limb("Tail", V(0, 0.9, 1.2), V(0, 0.6, 1.8), 0.5, "Body")

	b:Eyes(body, 0.62, 0.42, V(0.64, 0.44, 0.2), GLOOM_EYE, "Angry")
	local center = b:OnSurface(body, 0, -0.42, 0.05).Position
	b:Box("Grin", V(1.3, 0.45, 0.14), center, nil, "White")
	b:MirrorBox("GrinSide", V(0.55, 0.3, 0.14), center + V(0.8, 0.13, 0.02), V(0, 0, 25), "White")
	b:Box("GrinLine", V(1.6, 0.06, 0.16), center + V(0, 0.02, -0.03), nil, "Dark")
	b:Particles(body.Part, GAS, 4, 0.5)
end

-- Fish family --------------------------------------------------------------------------------

-- Clumsy red carp flopping its tail, with a yellow crown fin, cream fins and whiskers.
Designs["Flopfish"] = function(b)
	local body = b:Gem("Body", V(1.4, 2.0, 2.3), V(0, 1.3, 0.1), nil, "Body")
	b:SetCore(body)
	b:Limb("TailStalk", V(0, 1.3, 1.0), V(0.45, 1.55, 1.85), 0.8, "Body")
	b:Spike("TailFinTop", V(0.45, 1.65, 1.85), V(0.9, 2.55, 2.45), 0.9, 0.14, "Accent", nil, V(1, 0, -0.5))
	b:Spike("TailFinBottom", V(0.45, 1.5, 1.85), V(0.95, 0.75, 2.55), 0.9, 0.14, "Accent", nil, V(1, 0, -0.5))

	b:Spike("Crown1", V(0, 2.2, -0.6), V(0, 2.95, -0.55), 0.65, 0.14, "Extra", nil, SIDE)
	b:Spike("Crown2", V(0, 2.25, 0.05), V(0, 3.15, 0.2), 0.7, 0.18, "Extra", nil, SIDE)
	b:Spike("Crown3", V(0, 2.2, 0.65), V(0, 2.85, 0.95), 0.65, 0.14, "Extra", nil, SIDE)
	b:MirrorSpike("Fin", V(0.68, 0.95, -0.4), V(1.35, 0.6, 0.1), 0.6, 0.12, "Accent", nil, UP)
	b:MirrorSpike("BellyFin", V(0.35, 0.4, 0.4), V(0.55, 0.02, 0.85), 0.55, 0.12, "Accent", nil, SIDE)
	b:MirrorBox("Scale1", V(0.1, 0.42, 0.42), V(0.67, 1.45, 0.15), V(45, 0, 0), "Belly")
	b:MirrorBox("Scale2", V(0.1, 0.42, 0.42), V(0.67, 1.0, 0.6), V(45, 0, 0), "Belly")

	b:Eyes(body, 0.42, 0.35, V(0.56, 0.56, 0.18), "White", "Dazed")
	b:FaceDot("Lips", body, 0, -0.4, V(0.62, 0.52, 0.16), "Accent")
	b:FaceDot("Mouth", body, 0, -0.4, V(0.36, 0.28, 0.22), "Mouth")
	b:MirrorChain("Whisker", { V(0.32, 0.95, -1.12), V(0.75, 0.75, -1.3), V(0.95, 0.3, -1.15) }, 0.14, 0.1, "Extra")
end

-- Furious sea serpent rearing out of its own coils, jaws wide open.
Designs["Tidewyrm"] = function(b)
	local spine = {
		V(1.5, 0.35, 2.0),
		V(1.9, 0.45, 0.7),
		V(1.4, 0.55, -0.6),
		V(0.2, 0.6, -1.2),
		V(-1.1, 0.6, -0.8),
		V(-1.6, 0.6, 0.4),
		V(-0.8, 0.7, 1.3),
		V(0, 1.6, 1.45),
		V(0, 2.9, 1.15),
		V(0, 3.9, 0.45),
		V(0, 4.45, -0.2),
	}
	b:Chain("Body", spine, 0.45, 1.15, "Body")
	b:Limb("BellyPlate1", V(0, 1.7, 0.85), V(0, 2.8, 0.6), V2(0.75, 0.3), "Belly")
	b:Limb("BellyPlate2", V(0, 3.05, 0.5), V(0, 3.75, -0.05), V2(0.75, 0.3), "Belly")

	local head = b:Gem("Head", V(1.7, 1.3, 1.5), V(0, 4.85, -0.45), nil, "Body")
	b:SetCore(head)
	b:Box("UpperJaw", V(1.4, 0.42, 1.0), V(0, 4.35, -1.45), V(8, 0, 0), "Body")
	b:Box("LowerJaw", V(1.25, 0.32, 1.1), V(0, 3.75, -1.3), V(-18, 0, 0), "Belly")
	b:Box("MouthInside", V(1.15, 0.6, 0.9), V(0, 4.05, -1.3), nil, "Mouth")
	b:MirrorSpike("Fang", V(0.45, 4.15, -1.8), V(0.45, 3.82, -1.8), 0.18, 0.1, "White")
	b:MirrorSpike("LowFang", V(0.4, 3.85, -1.75), V(0.4, 4.1, -1.75), 0.15, 0.1, "White")
	b:Eyes(head, 0.42, 0.3, V(0.38, 0.32, 0.16), "Extra", "Angry")

	b:Spike("Crest", V(0, 5.4, -0.4), V(0, 6.5, 0.25), 0.85, 0.22, "Body", nil, SIDE)
	b:MirrorSpike("CrestSide", V(0.4, 5.35, -0.3), V(0.7, 6.05, 0.35), 0.5, 0.18, "Body", nil, SIDE)
	b:MirrorSpike("EarFin", V(0.8, 4.85, -0.2), V(1.6, 5.25, 0.45), 0.7, 0.14, "Accent", nil, V(0, 0.3, -1))
	b:MirrorChain("Whisker", { V(0.65, 4.4, -1.85), V(1.3, 4.65, -1.6), V(1.8, 4.2, -1.0) }, 0.16, 0.1, "Accent")

	for index, spot in { V(0, 3.6, 0.95), V(0, 2.5, 1.65), V(0, 1.3, 1.85), V(-1.3, 0.95, 1.1) } do
		b:Spike("Dorsal" .. index, spot, spot + V(0, 0.45, 0.6), 0.6, 0.14, "Accent", nil, SIDE)
	end
	b:Spike("TailFin1", V(1.5, 0.4, 2.0), V(1.3, 1.4, 2.6), 0.55, 0.14, "Accent", nil, SIDE)
	b:Spike("TailFin2", V(1.5, 0.4, 2.0), V(1.9, 1.2, 2.75), 0.55, 0.14, "Accent", nil, SIDE)
end

return Designs
