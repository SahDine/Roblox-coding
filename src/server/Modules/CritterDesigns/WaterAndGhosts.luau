--[[
	Critter designs: Puddlet, Shellwave, Cannontoise, Ghastling, Hauntling, Gloomer, Flopfish, Tidewyrm.
	See CritterBuilder for the toolkit. Ground at y = 0, the critter faces -Z.
]]

local V = Vector3.new

local Designs = {}

-- Shared pieces -----------------------------------------------------------------------------

-- Turtle torso: brown shell behind, cream plastron in front (the turtle family's signature).
local function turtleTorso(b, width: number, height: number, centerY: number, shellDepth: number, bellyDepth: number)
	local shell = b:Gem("Shell", V(width, height, shellDepth), V(0, centerY, shellDepth / 2 - 0.15), nil, "Accent")
	local belly = b:Gem("Plastron", V(width - 0.1, height - 0.1, bellyDepth), V(0, centerY - 0.02, -bellyDepth / 2 - 0.05), nil, "Belly")
	return shell, belly
end

-- Purple ghost gas: translucent triangles radiating from a centre in the XY plane.
local function gasRing(b, center: Vector3, count: number, inner: number, outer: number, width: number, startAngle: number)
	for index = 1, count do
		local angle = math.rad(startAngle + (index - 1) * 360 / count)
		local dir = V(math.cos(angle), math.sin(angle), 0)
		local z = if index % 2 == 0 then 0.12 else -0.12
		b:Spike("Gas" .. index, center + dir * inner + V(0, 0, z), center + dir * outer + V(0, 0, z * 2), width, 0.22, "Accent", { Transparency = 0.3 })
	end
end

-- Turtle family ------------------------------------------------------------------------------

-- Little turtle with a big round head, cream plastron and a curly tail.
Designs["Puddlet"] = function(b)
	local shell = turtleTorso(b, 1.75, 1.8, 1.3, 1.1, 0.7)
	b:SetCore(shell)
	b:Box("ShellPlate", V(0.75, 0.75, 0.1), V(0, 1.35, 0.98), V(0, 0, 45), "Extra")
	b:Box("PlastronLine1", V(0.95, 0.07, 0.08), V(0, 1.05, -0.78), nil, "Accent")
	b:Box("PlastronLine2", V(0.95, 0.07, 0.08), V(0, 1.5, -0.78), nil, "Accent")

	local head = b:Gem("Head", V(1.95, 1.75, 1.7), V(0, 3.0, -0.2), nil, "Body")
	b:Eyes(head, 0.45, 0.1, V(0.45, 0.62, 0.2), Color3.fromRGB(150, 70, 60))
	b:Mouth(head, -0.48, 0.5, true)

	b:MirrorLimb("Arm", V(0.75, 1.85, -0.2), V(1.15, 1.45, -0.5), 0.38, "Body")
	b:MirrorGem("Hand", V(0.42, 0.42, 0.42), V(1.17, 1.42, -0.52), nil, "Body")
	b:MirrorLimb("Leg", V(0.5, 0.8, 0.05), V(0.55, 0.3, -0.1), 0.55, "Body")
	b:MirrorGem("Foot", V(0.62, 0.36, 0.8), V(0.55, 0.18, -0.25), nil, "Body")

	b:Chain("Tail", { V(0, 0.75, 0.85), V(0, 0.7, 1.4), V(0, 1.2, 1.8) }, 0.45, 0.35, "Body")
	b:Gem("TailCurl", V(0.45, 0.45, 0.45), V(0, 1.45, 1.62), nil, "Body")
end

-- Bigger turtle with feathery white ears and a fluffy swirl tail.
Designs["Shellwave"] = function(b)
	local shell = turtleTorso(b, 1.85, 2.0, 1.55, 1.2, 0.8)
	b:SetCore(shell)
	b:Box("ShellPlate", V(0.8, 0.8, 0.1), V(0, 1.6, 1.08), V(0, 0, 45), "Extra")

	local head = b:Gem("Head", V(1.85, 1.6, 1.65), V(0, 3.3, -0.2), nil, "Body")
	b:Eyes(head, 0.42, 0.1, V(0.4, 0.52, 0.2), Color3.fromRGB(110, 50, 50))
	b:Mouth(head, -0.42, 0.45)
	b:FaceDot("FangL", head, -0.15, -0.5, V(0.1, 0.14, 0.18), "White")
	b:FaceDot("FangR", head, 0.15, -0.5, V(0.1, 0.14, 0.18), "White")

	b:MirrorSpike("Ear", V(0.65, 3.85, 0.0), V(1.35, 4.65, 0.55), 0.75, 0.14, "Extra")
	b:MirrorSpike("EarTuft", V(0.75, 3.7, 0.1), V(1.55, 4.0, 0.7), 0.5, 0.2, "Extra")

	b:MirrorLimb("Arm", V(0.8, 2.1, -0.25), V(1.2, 1.6, -0.6), 0.42, "Body")
	b:MirrorGem("Hand", V(0.45, 0.45, 0.45), V(1.22, 1.57, -0.62), nil, "Body")
	b:MirrorLimb("Leg", V(0.55, 0.9, 0.05), V(0.6, 0.3, -0.1), 0.6, "Body")
	b:MirrorGem("Foot", V(0.66, 0.4, 0.85), V(0.6, 0.2, -0.25), nil, "Body")

	b:Gem("Tail", V(0.5, 1.35, 1.35), V(0, 1.4, 1.65), nil, "Extra", { Axis = "X" })
	b:MirrorBox("TailSwirl", V(0.08, 0.55, 0.55), V(0.27, 1.4, 1.65), V(45, 0, 0), "Body")
end

-- Huge armoured turtle with twin water cannons sticking out of its shell.
Designs["Cannontoise"] = function(b)
	local shell = turtleTorso(b, 2.5, 2.7, 2.05, 1.6, 1.0)
	b:SetCore(shell)

	local head = b:Gem("Head", V(1.5, 1.3, 1.45), V(0, 3.85, -0.55), nil, "Body")
	b:Eyes(head, 0.36, 0.1, V(0.32, 0.36, 0.16), Color3.fromRGB(110, 50, 50), "Angry")
	b:Mouth(head, -0.35, 0.5)
	b:MirrorSpike("Ear", V(0.5, 4.35, -0.45), V(0.78, 4.9, -0.35), 0.42, 0.14, "Body")

	b:MirrorGem("Cannon", V(0.6, 0.6, 1.8), V(1.0, 3.35, -0.35), nil, "Extra")
	b:MirrorBox("Muzzle", V(0.34, 0.34, 0.08), V(1.0, 3.35, -1.27), nil, "Dark")

	b:MirrorLimb("Arm", V(1.15, 2.6, -0.4), V(1.45, 1.9, -0.8), 0.7, "Body")
	b:MirrorBox("Fist", V(0.48, 0.48, 0.48), V(1.47, 1.82, -0.85), V(0, 0, 0), "Body")
	b:MirrorLimb("Leg", V(0.75, 1.0, 0.1), V(0.8, 0.35, -0.05), 0.8, "Body")
	b:MirrorGem("Foot", V(0.85, 0.45, 1.05), V(0.8, 0.225, -0.2), nil, "Body")
	b:Limb("Tail", V(0, 0.9, 1.3), V(0, 0.55, 1.8), 0.5, "Body")
end

-- Ghost family -------------------------------------------------------------------------------

-- Floating dark gas ball wrapped in a purple haze.
Designs["Ghastling"] = function(b)
	b.Hover = 0.8
	local ball = b:Gem("Ball", V(2.0, 2.0, 1.8), V(0, 1.4, 0), nil, "Body")
	b:SetCore(ball)
	gasRing(b, V(0, 1.4, 0.25), 8, 0.7, 1.7, 0.9, 22.5)
	b:Eyes(ball, 0.45, 0.2, V(0.6, 0.5, 0.18), "White", "Dazed")
	b:FaceDot("Mouth", ball, 0, -0.42, V(1.0, 0.4, 0.14), "Mouth")
	b:FaceDot("Tongue", ball, 0, -0.52, V(0.45, 0.2, 0.18), "Tongue")
	b:FaceDot("FangL", ball, -0.3, -0.3, V(0.14, 0.16, 0.18), "White")
	b:FaceDot("FangR", ball, 0.3, -0.3, V(0.14, 0.16, 0.18), "White")
	b:Particles(ball.Part, Color3.fromRGB(170, 100, 230), 5, 0.5)
end

-- Floating ghost with spiky horns, a wispy tail and two detached clawed hands.
Designs["Hauntling"] = function(b)
	b.Hover = 0.7
	local body = b:Gem("Body", V(2.3, 2.0, 1.8), V(0, 2.0, 0), nil, "Body")
	b:SetCore(body)
	b:MirrorSpike("Horn", V(0.7, 2.75, 0.1), V(1.3, 3.75, 0.35), 0.85, 0.3, "Body")
	b:Spike("Tuft", V(0, 2.8, 0.5), V(0, 3.5, 1.2), 0.8, 0.3, "Body", nil, V(1, 0, 0))
	b:Spike("Tail", V(0, 1.15, 0.1), V(0.15, 0.05, 0.9), 1.7, 0.5, "Body")
	b:MirrorSpike("Wisp", V(0.6, 1.2, 0.0), V(0.9, 0.5, 0.4), 0.6, 0.3, "Body")

	for _, side in { 1 } do
		local palm = V(1.85 * side, 1.9, -0.6)
		b:MirrorGem("Palm", V(0.6, 0.45, 0.4), palm, nil, "Body")
		b:MirrorSpike("Finger1", palm + V(0.1, 0.15, -0.05), palm + V(0.3, 0.75, -0.15), 0.22, 0.15, "Body")
		b:MirrorSpike("Finger2", palm + V(0.25, 0.05, -0.05), palm + V(0.75, 0.45, -0.15), 0.22, 0.15, "Body")
		b:MirrorSpike("Finger3", palm + V(0.25, -0.1, -0.05), palm + V(0.8, -0.1, -0.15), 0.22, 0.15, "Body")
	end

	b:Eyes(body, 0.5, 0.3, V(0.6, 0.45, 0.18), "White", "Angry")
	b:FaceDot("Mouth", body, 0, -0.4, V(1.3, 0.45, 0.14), "Mouth")
	b:FaceDot("Tongue", body, 0, -0.52, V(0.6, 0.22, 0.18), "Tongue")
	b:Particles(body.Part, Color3.fromRGB(170, 100, 230), 4, 0.5)
end

-- Grinning spiky shadow ghost.
Designs["Gloomer"] = function(b)
	local body = b:Gem("Body", V(2.9, 2.5, 2.3), V(0, 1.6, 0.05), nil, "Body")
	b:SetCore(body)
	b:MirrorSpike("Ear", V(0.85, 2.55, 0.05), V(1.3, 3.65, 0.2), 0.8, 0.35, "Body")
	local spikeFacing = V(1, 0, -0.6)
	b:MirrorSpike("Spike1", V(1.1, 2.3, 0.6), V(1.6, 2.9, 1.2), 0.6, 0.25, "Body", nil, spikeFacing)
	b:MirrorSpike("Spike2", V(0.5, 2.6, 0.9), V(0.75, 3.3, 1.5), 0.6, 0.25, "Body", nil, spikeFacing)
	b:MirrorSpike("Spike3", V(1.35, 1.5, 0.8), V(2.0, 1.8, 1.4), 0.6, 0.25, "Body", nil, spikeFacing)

	b:MirrorLimb("Arm", V(1.35, 1.55, -0.3), V(1.8, 1.25, -0.75), 0.6, "Body")
	b:MirrorGem("Hand", V(0.45, 0.45, 0.45), V(1.82, 1.22, -0.78), nil, "Body")
	b:MirrorSpike("Claw1", V(1.85, 1.3, -0.9), V(2.0, 1.5, -1.3), 0.2, 0.15, "Body")
	b:MirrorSpike("Claw2", V(2.0, 1.2, -0.85), V(2.25, 1.25, -1.2), 0.2, 0.15, "Body")
	b:MirrorGem("Foot", V(0.85, 0.45, 1.05), V(0.85, 0.225, -0.25), nil, "Body")
	b:Limb("Tail", V(0, 0.9, 1.1), V(0, 0.65, 1.65), 0.45, "Body")

	b:Eyes(body, 0.6, 0.4, V(0.62, 0.42, 0.2), Color3.fromRGB(230, 40, 50), "Angry")
	local center = b:OnSurface(body, 0, -0.4, 0.05).Position
	b:Box("Grin", V(1.2, 0.42, 0.14), center, nil, "White")
	b:MirrorBox("GrinSide", V(0.5, 0.3, 0.14), center + V(0.75, 0.12, 0.02), V(0, 0, 25), "White")
	b:Box("GrinLine", V(1.5, 0.06, 0.16), center + V(0, 0.02, -0.03), nil, "Dark")
	b:Particles(body.Part, Color3.fromRGB(160, 90, 220), 4, 0.5)
end

-- Fish family --------------------------------------------------------------------------------

-- Clumsy red carp with a crown fin, cream fins and whiskers.
Designs["Flopfish"] = function(b)
	local body = b:Gem("Body", V(1.5, 1.85, 1.7), V(0, 1.0, -0.1), nil, "Body")
	b:SetCore(body)
	b:Gem("Tail", V(0.9, 1.15, 0.9), V(0, 1.15, 1.1), V(-20, 0, 0), "Body")
	local fin = V(1, 0, 0)
	b:Spike("TailFinTop", V(0, 1.45, 1.45), V(0, 2.35, 2.2), 0.9, 0.14, "Accent", nil, fin)
	b:Spike("TailFinBottom", V(0, 1.3, 1.5), V(0, 0.65, 2.35), 0.9, 0.14, "Accent", nil, fin)
	b:Spike("Crown1", V(0, 1.85, -0.5), V(0, 2.55, -0.45), 0.6, 0.12, "Extra", nil, fin)
	b:Spike("Crown2", V(0, 1.85, 0.0), V(0, 2.7, 0.15), 0.6, 0.24, "Extra", nil, fin)
	b:Spike("Crown3", V(0, 1.8, 0.5), V(0, 2.45, 0.75), 0.6, 0.12, "Extra", nil, fin)
	b:MirrorSpike("Fin", V(0.7, 0.7, -0.4), V(1.3, 0.4, 0.0), 0.55, 0.1, "Accent", nil, V(0, 1, 0))
	b:Eyes(body, 0.42, 0.25, V(0.55, 0.55, 0.18), "White", "Dazed")
	b:FaceDot("Lips", body, 0, -0.4, V(0.6, 0.5, 0.18), "Accent")
	b:FaceDot("Mouth", body, 0, -0.4, V(0.36, 0.26, 0.24), "Mouth")
	b:MirrorChain("Whisker", { V(0.35, 0.75, -0.97), V(0.75, 0.55, -1.15), V(0.95, 0.15, -1.0) }, 0.14, 0.1, "Extra")
end

-- Furious sea serpent rearing out of its own coils.
Designs["Tidewyrm"] = function(b)
	local coil = {
		V(-1.1, 0.3, 1.0),
		V(-1.4, 0.35, 0.1),
		V(-0.9, 0.4, -0.9),
		V(0.4, 0.45, -1.2),
		V(1.4, 0.5, -0.5),
		V(1.2, 0.55, 0.6),
		V(0, 0.6, 0.9),
	}
	b:Chain("Coil", coil, 0.45, 0.95, "Body")
	b:Chain("Neck", { V(0, 0.6, 0.9), V(0, 1.8, 1.2), V(0, 3.0, 0.8), V(0, 3.9, 0.0) }, 1.0, 0.9, "Body")
	b:Chain("Belly", { V(0, 1.8, 0.85), V(0, 2.9, 0.45), V(0, 3.7, -0.25) }, 0.7, 0.6, "Belly")

	local head = b:Gem("Head", V(1.4, 1.15, 1.6), V(0, 4.35, -0.55), nil, "Body")
	b:SetCore(head)
	b:Box("Jaw", V(1.1, 0.35, 1.2), V(0, 3.6, -0.75), V(15, 0, 0), "Body")
	b:Box("MouthInside", V(1.0, 0.45, 0.9), V(0, 3.85, -0.75), nil, "Mouth")
	b:MirrorSpike("Fang", V(0.35, 3.8, -1.25), V(0.35, 3.5, -1.25), 0.16, 0.1, "White")
	b:Eyes(head, 0.38, 0.15, V(0.36, 0.3, 0.16), "Extra", "Angry")

	local side = V(1, 0, 0)
	b:Spike("Crest", V(0, 4.85, -0.3), V(0, 5.6, 0.2), 0.6, 0.2, "Body", nil, side)
	b:MirrorSpike("CrestSide", V(0.4, 4.85, -0.2), V(0.6, 5.4, 0.3), 0.4, 0.15, "Body", nil, side)
	b:MirrorSpike("HeadFin", V(0.65, 4.3, -0.2), V(1.4, 4.6, 0.4), 0.6, 0.12, "Accent", nil, V(0, 1, 0))
	b:MirrorChain("Whisker", { V(0.5, 3.95, -1.3), V(1.0, 3.8, -1.2), V(1.4, 3.3, -0.8) }, 0.16, 0.1, "Belly")

	b:Spike("Dorsal1", V(0, 3.4, 0.9), V(0, 3.9, 1.5), 0.6, 0.12, "Accent", nil, side)
	b:Spike("Dorsal2", V(0, 2.4, 1.5), V(0, 2.6, 2.1), 0.6, 0.12, "Accent", nil, side)
	b:Spike("Dorsal3", V(0, 1.3, 1.5), V(0, 1.2, 2.1), 0.6, 0.12, "Accent", nil, side)
	b:Spike("TailFin1", V(-1.1, 0.35, 1.05), V(-1.3, 1.3, 1.6), 0.5, 0.12, "Accent", nil, side)
	b:Spike("TailFin2", V(-1.1, 0.35, 1.05), V(-0.8, 1.1, 1.8), 0.5, 0.12, "Accent", nil, side)
end

return Designs
