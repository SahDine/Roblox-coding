--[[
	Critter designs: Growlpup, Blazehound, Pupjack, Aurajack, Munchling, Snoozor, Psyclone, Pinkling.
	See CritterBuilder for the toolkit. Ground at y = 0, the critter faces -Z.
]]

local Helpers = require(script.Parent.Helpers)

local V = Vector3.new
local V2 = Vector2.new
local stubbyFeet, bipedLegs, quadLegs, arms = Helpers.stubbyFeet, Helpers.bipedLegs, Helpers.quadLegs, Helpers.arms

local Designs = {}

-- TODO: Growlpup (not sculpted yet, uses the Generic design)

-- Majestic fire hound.
Designs["Blazehound"] = function(b)
	local body = b:Ellipsoid("Body", V(1.8, 1.7, 3.0), V(0, 2.0, 0.35), nil, "Body")
	b:SetCore(body)
	b:Ellipsoid("ChestFluff", V(1.95, 1.65, 1.25), V(0, 2.3, -0.95), nil, "Belly")
	b:Ellipsoid("BackFluff", V(1.3, 0.6, 1.4), V(0, 2.85, 0.1), nil, "Belly")
	local head = b:Ellipsoid("Head", V(1.55, 1.4, 1.55), V(0, 3.45, -1.45), nil, "Body")
	b:Ellipsoid("Muzzle", V(0.85, 0.6, 0.8), V(0, 3.2, -2.15), nil, "Belly")
	b:Ellipsoid("Tuft", V(0.9, 0.55, 0.7), V(0, 4.15, -1.35), nil, "Belly")
	b:MirrorLimb("Ear", V(0.45, 3.95, -1.3), V(0.75, 4.55, -1.1), V2(0.5, 0.2), "Body")
	b:FaceDot("Nose", head, 0, -0.35, V(0.2, 0.14, 0.15), "Black")
	quadLegs(b, -0.65, 1.35, 0.6, 1.6, 0.55, "Body", "Belly")
	for index, z in { -0.2, 0.4, 1.0 } do
		b:MirrorEllipsoid("Stripe" .. index, V(0.12, 0.9, 0.18), V(0.88, 2.05, z), V(0, 0, 8), "Black", { Paint = false })
	end
	b:Chain("Tail", { V(0, 2.3, 1.75), V(0, 2.9, 2.25), V(0, 3.35, 2.2) }, 0.75, 0.7, "Belly")
	b:Eyes(head, 0.38, 0.12, V(0.3, 0.36, 0.16), Color3.fromRGB(60, 30, 20), "Angry")
end

-- TODO: Pupjack (not sculpted yet, uses the Generic design)

-- Aura warrior jackal.
Designs["Aurajack"] = function(b)
	local body = b:Ellipsoid("Body", V(1.3, 1.7, 1.1), V(0, 2.3, 0), nil, "Body")
	b:SetCore(body)
	b:Ellipsoid("ChestFur", V(1.0, 0.9, 0.5), V(0, 2.55, -0.42), nil, "Belly")
	b:Limb("ChestSpike", V(0, 2.5, -0.6), V(0, 2.45, -1.0), 0.2, "White")
	b:MirrorLimb("Thigh", V(0.38, 1.7, 0), V(0.45, 0.9, -0.05), 0.55, "Accent")
	b:MirrorLimb("Shin", V(0.45, 0.95, -0.05), V(0.45, 0.3, 0.05), 0.4, "Accent")
	b:MirrorEllipsoid("Foot", V(0.45, 0.3, 0.75), V(0.45, 0.15, -0.15), nil, "Accent")
	arms(b, V(0.72, 2.75, 0), V(1.05, 1.9, -0.25), 0.32, "Body", "Accent")
	b:MirrorLimb("HandSpike", V(1.05, 1.95, -0.3), V(1.1, 1.95, -0.7), 0.16, "White")
	local head = b:Ellipsoid("Head", V(1.35, 1.25, 1.35), V(0, 3.65, -0.1), nil, "Body")
	b:Ellipsoid("Mask", V(1.42, 0.42, 1.25), V(0, 3.7, -0.15), nil, "Accent")
	b:Ellipsoid("Snout", V(0.6, 0.45, 0.6), V(0, 3.45, -0.75), nil, "Body")
	b:FaceDot("Nose", head, 0, -0.25, V(0.15, 0.1, 0.1), "Black")
	b:MirrorLimb("Ear", V(0.32, 4.1, 0), V(0.55, 5.0, 0.1), V2(0.42, 0.18), "Body")
	b:MirrorChain("Lock", { V(0.3, 3.6, 0.55), V(0.38, 3.0, 0.85), V(0.4, 2.5, 0.9) }, 0.22, 0.16, "Accent")
	b:Chain("Tail", { V(0, 1.95, 0.5), V(0, 1.55, 1.1), V(0, 1.45, 1.55) }, 0.5, 0.42, "Body")
	b:Eyes(head, 0.3, 0.08, V(0.3, 0.32, 0.16), Color3.fromRGB(220, 40, 50), "Angry")
	b:Particles(body.Part, Color3.fromRGB(80, 160, 255), 5, 0.4)
end

-- TODO: Munchling (not sculpted yet, uses the Generic design)

-- Giant sleepy blob.
Designs["Snoozor"] = function(b)
	local body = b:Ellipsoid("Body", V(3.0, 2.75, 2.6), V(0, 1.5, 0.1), nil, "Body")
	b:SetCore(body)
	b:Ellipsoid("BellyPatch", V(2.3, 2.1, 1.0), V(0, 1.35, -0.8), nil, "Belly")
	b:Ellipsoid("Head", V(2.0, 1.35, 1.6), V(0, 3.2, -0.15), nil, "Body")
	local face = b:Ellipsoid("Face", V(1.55, 1.0, 0.7), V(0, 3.1, -0.7), nil, "Belly")
	b:MirrorLimb("Ear", V(0.55, 3.7, -0.1), V(0.85, 4.15, -0.05), V2(0.45, 0.2), "Body")
	b:MirrorLimb("Arm", V(1.3, 2.2, -0.2), V(1.65, 1.35, -0.45), 0.7, "Body")
	b:MirrorEllipsoid("Foot", V(0.95, 0.55, 1.05), V(0.85, 0.55, -0.75), V(-60, 0, 0), "Belly")
	b:MirrorEllipsoid("Pad", V(0.5, 0.35, 0.2), V(0.85, 0.62, -1.12), V(-60, 0, 0), "Extra")
	b:Eyes(face, 0.35, 0.12, V(0.4, 0.3, 0.15), "Black", "Sleepy")
	b:Mouth(face, -0.25, 0.4)
	b:FaceDot("Fang1", face, -0.18, -0.2, V(0.1, 0.14, 0.08), "White")
	b:FaceDot("Fang2", face, 0.18, -0.2, V(0.1, 0.14, 0.08), "White")
end

-- Psychic clone with a long tail.
Designs["Psyclone"] = function(b)
	local body = b:Ellipsoid("Body", V(1.35, 1.9, 1.2), V(0, 2.5, 0.05), nil, "Body")
	b:SetCore(body)
	b:Ellipsoid("BellyPatch", V(1.1, 0.75, 1.0), V(0, 2.2, -0.05), nil, "Accent")
	b:MirrorEllipsoid("Shoulder", V(0.7, 0.6, 0.7), V(0.65, 3.2, 0.05), nil, "Body")
	b:MirrorLimb("Thigh", V(0.45, 1.75, 0.05), V(0.55, 0.85, -0.05), 0.72, "Body")
	b:MirrorLimb("Shin", V(0.55, 0.9, -0.05), V(0.5, 0.3, -0.05), 0.42, "Body")
	b:MirrorEllipsoid("Foot", V(0.5, 0.3, 0.7), V(0.5, 0.15, -0.2), nil, "Body")
	arms(b, V(0.75, 3.05, 0.0), V(1.1, 2.15, -0.35), 0.3, "Body")
	b:Limb("Neck", V(0, 3.3, 0.05), V(0, 3.75, -0.05), 0.4, "Body")
	local head = b:Ellipsoid("Head", V(1.0, 0.95, 1.05), V(0, 4.15, -0.1), nil, "Body")
	b:MirrorLimb("Ear", V(0.32, 4.5, 0), V(0.42, 4.8, 0.05), V2(0.3, 0.15), "Body")
	b:Chain("Tube", { V(0, 4.0, 0.45), V(0, 3.75, 0.7), V(0, 3.35, 0.45) }, 0.22, 0.2, "Body")
	b:Chain("Tail", { V(0, 1.75, 0.55), V(0, 1.0, 1.4), V(0, 0.7, 2.2), V(0, 1.2, 2.9), V(0, 2.0, 3.0) }, 0.75, 0.4, "Accent")
	b:Eyes(head, 0.24, 0.05, V(0.24, 0.24, 0.12), Color3.fromRGB(140, 60, 200), "Angry")
	b:Particles(body.Part, Color3.fromRGB(190, 120, 255), 6, 0.45)
end

-- Tiny floating pink feline.
Designs["Pinkling"] = function(b)
	b.Hover = 1.1
	local body = b:Ellipsoid("Body", V(1.1, 1.3, 1.0), V(0, 1.55, 0.05), V(-10, 0, 0), "Body")
	b:SetCore(body)
	local head = b:Ellipsoid("Head", V(1.65, 1.45, 1.45), V(0, 2.75, -0.1), nil, "Body")
	b:MirrorLimb("Ear", V(0.55, 3.25, -0.05), V(0.82, 3.85, 0.0), V2(0.5, 0.16), "Body")
	b:MirrorLimb("Arm", V(0.45, 1.85, -0.25), V(0.7, 1.55, -0.6), 0.22, "Body")
	b:MirrorLimb("Leg", V(0.3, 1.05, 0.05), V(0.4, 0.5, -0.25), 0.3, "Body")
	b:MirrorEllipsoid("Foot", V(0.45, 0.3, 0.7), V(0.42, 0.4, -0.45), V(-30, 0, 0), "Body")
	b:Chain("Tail", { V(0, 1.2, 0.5), V(0, 0.75, 1.3), V(0, 1.4, 2.1), V(0, 2.6, 2.2), V(0, 3.4, 1.7) }, 0.17, 0.14, "Body")
	b:Ellipsoid("TailTip", V(0.42, 0.42, 0.42), V(0, 3.55, 1.6), nil, "Body")
	b:Eyes(head, 0.38, 0.08, V(0.42, 0.55, 0.2), Color3.fromRGB(70, 130, 230))
	b:Mouth(head, -0.38, 0.3)
end

return Designs
