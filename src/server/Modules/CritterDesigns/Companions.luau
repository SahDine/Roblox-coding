--[[
	Critter designs: Zappip, Voltmouse, Fennix, Moonfox, Quackle, Mystduck, Coinpurr, Regalynx.
	See CritterBuilder for the toolkit. Ground at y = 0, the critter faces -Z.
]]

local Helpers = require(script.Parent.Helpers)

local V = Vector3.new
local V2 = Vector2.new
local stubbyFeet, bipedLegs, quadLegs, arms = Helpers.stubbyFeet, Helpers.bipedLegs, Helpers.quadLegs, Helpers.arms

local Designs = {}

-- Electric mouse with lightning tail and red cheeks.
-- REFERENCE DESIGN for the triangle toolkit: bones for every moving part, nested ear bones in the head,
-- attachments sunk into the shapes they hang from, round eyes / mouth, everything else faceted.
Designs["Zappip"] = function(b)
	local body = b:Ball("Body", V(1.8, 1.75, 1.55), V(0, 1.05, 0.05), nil, "Body")
	b:SetCore(body)
	-- Brown stripes on the back: flat triangles lying on the body.
	b:Tri("Stripe1", V(-0.5, 1.75, 0.62), V(0.5, 1.75, 0.62), V(0, 1.45, 0.78), "Extra")
	b:Tri("Stripe2", V(-0.45, 1.3, 0.8), V(0.45, 1.3, 0.8), V(0, 1.02, 0.86), "Extra")

	b:MirrorBone("LegFoot", V(0.45, 0.5, -0.1), nil, function()
		b:Ball("Foot", V(0.7, 0.42, 0.95), V(0.45, 0.21, -0.3), nil, "Body", { Detail = 0 })
	end)
	b:MirrorBone("Arm", V(0.62, 1.5, -0.45), { Phase = 0.5 }, function()
		b:Limb("Arm", V(0.55, 1.6, -0.4), V(0.88, 1.12, -0.82), 0.34, "Body")
		b:Ball("Paw", V(0.3, 0.3, 0.3), V(0.88, 1.12, -0.84), nil, "Body", { Detail = 0 })
	end)

	b:Bone("Head", V(0, 1.85, -0.05), nil, function()
		local head = b:Ball("Head", V(2.05, 1.75, 1.65), V(0, 2.6, -0.2), nil, "Body")
		b:Eyes(head, 0.45, 0.12, V(0.4, 0.46, 0.3), "Black")
		b:Cheeks(head, 0.72, -0.3, 0.46)
		b:Mouth(head, -0.36, 0.34, true)
		b:FaceDot("Nose", head, 0, -0.06, V(0.12, 0.08, 0.1), "Black")
		-- Long pointed ears with black tips (pyramids, sunk 0.15 into the head).
		b:MirrorBone("Ear", V(0.55, 3.25, -0.15), nil, function()
			b:Spike("Ear", V(0.5, 3.15, -0.15), V(1.12, 4.55, -0.05), 0.62, 0.36, "Body")
			b:Spike("EarTip", V(0.98, 4.2, -0.075), V(1.17, 4.68, -0.04), 0.33, 0.24, "Accent")
		end)
	end)

	-- Zig-zag lightning tail: flat beams, brown at the base.
	b:Bone("Tail", V(0, 1.0, 0.7), nil, function()
		b:Beam("Tail1", V(0, 0.8, 0.62), V(0, 1.45, 1.25), V2(0.4, 0.16), "Extra")
		b:Beam("Tail2", V(0, 1.4, 1.22), V(0, 1.25, 1.75), V2(0.5, 0.16), "Body")
		b:Beam("Tail3", V(0, 1.2, 1.7), V(0, 2.35, 2.45), V2(0.75, 0.16), "Body")
		b:Tri("TailTip", V(0, 2.05, 2.15), V(0, 2.95, 2.25), V(0, 2.55, 2.95), "Body", { Thickness = 0.16 })
	end)
end

-- TODO: Voltmouse (not sculpted yet, uses the Generic design)

-- Fluffy fox with a cream mane.
Designs["Fennix"] = function(b)
	local body = b:Ellipsoid("Body", V(1.55, 1.5, 2.1), V(0, 1.15, 0.25), nil, "Body")
	b:SetCore(body)
	b:Ellipsoid("Mane", V(2.1, 1.25, 1.35), V(0, 1.85, -0.4), nil, "Belly")
	for index, x in { -0.75, 0, 0.75 } do
		b:Ellipsoid("ManeTuft" .. index, V(0.7, 0.6, 0.7), V(x, 1.55, -0.95), nil, "Belly")
	end
	local head = b:Ellipsoid("Head", V(1.8, 1.6, 1.6), V(0, 2.75, -0.5), nil, "Body")
	b:MirrorLimb("Ear", V(0.5, 3.3, -0.45), V(1.35, 4.55, -0.35), V2(0.95, 0.22), "Body")
	b:MirrorLimb("EarInner", V(0.55, 3.35, -0.58), V(1.25, 4.35, -0.48), V2(0.55, 0.1), "Accent")
	quadLegs(b, -0.4, 0.95, 0.5, 0.9, 0.42, "Body")
	b:Chain("Tail", { V(0, 1.3, 1.15), V(0, 2.0, 1.7), V(0, 2.55, 1.6) }, 1.0, 0.95, "Body")
	b:Ellipsoid("TailTip", V(0.85, 0.85, 0.85), V(0, 2.8, 1.5), nil, "Belly")
	b:Eyes(head, 0.42, 0.1, V(0.4, 0.55, 0.2), Color3.fromRGB(110, 60, 30))
	b:Mouth(head, -0.38, 0.4)
	b:FaceDot("Nose", head, 0, -0.18, V(0.18, 0.12, 0.1), "Black")
end

-- Night fox with glowing rings.
Designs["Moonfox"] = function(b)
	local body = b:Ellipsoid("Body", V(1.4, 1.4, 2.2), V(0, 1.3, 0.25), nil, "Body")
	b:SetCore(body)
	local head = b:Ellipsoid("Head", V(1.55, 1.4, 1.5), V(0, 2.6, -0.85), nil, "Body")
	b:Ellipsoid("Snout", V(0.65, 0.45, 0.6), V(0, 2.35, -1.55), nil, "Body")
	b:MirrorLimb("Ear", V(0.4, 3.1, -0.8), V(0.9, 4.45, -0.7), V2(0.62, 0.2), "Body")
	b:MirrorLimb("EarRing", V(0.68, 3.7, -0.78), V(0.75, 3.9, -0.76), V2(0.6, 0.24), "Accent", { Neon = true })
	b:FaceDot("ForeheadRing", head, 0, 0.42, V(0.45, 0.45, 0.12), "Accent", { Neon = true })
	quadLegs(b, -0.3, 1.0, 0.45, 1.0, 0.36, "Body")
	b:MirrorEllipsoid("LegRing", V(0.42, 0.14, 0.42), V(0.45, 0.65, -0.32), nil, "Accent", { Neon = true })
	b:Chain("Tail", { V(0, 1.55, 1.25), V(0, 2.2, 1.75), V(0, 2.75, 1.7) }, 0.6, 0.5, "Body")
	b:Ellipsoid("TailRing", V(0.62, 0.62, 0.2), V(0, 2.25, 1.75), V(-45, 0, 0), "Accent", { Neon = true })
	b:Eyes(head, 0.36, 0.1, V(0.34, 0.42, 0.18), Color3.fromRGB(220, 30, 40))
	b:FaceDot("Nose", head, 0, -0.3, V(0.12, 0.09, 0.1), "Dark")
end

-- Confused yellow duck holding its head.
Designs["Quackle"] = function(b)
	local body = b:Ellipsoid("Body", V(2.0, 2.0, 1.8), V(0, 1.2, 0), nil, "Body")
	b:SetCore(body)
	local head = b:Ellipsoid("Head", V(2.0, 1.9, 1.8), V(0, 2.9, -0.1), nil, "Body")
	b:Ellipsoid("BeakTop", V(1.05, 0.42, 0.95), V(0, 2.62, -1.0), nil, "Belly")
	b:Ellipsoid("BeakBottom", V(0.85, 0.25, 0.8), V(0, 2.4, -0.92), nil, "Belly")
	for index, x in { -0.18, 0, 0.18 } do
		b:Limb("Hair" .. index, V(x, 3.75, -0.05), V(x * 2.4, 4.4, 0.05), 0.08, "Black")
	end
	b:MirrorLimb("Arm", V(0.85, 1.85, -0.15), V(1.12, 2.75, -0.3), 0.38, "Body")
	b:MirrorEllipsoid("Hand", V(0.45, 0.45, 0.45), V(1.0, 3.0, -0.3), nil, "Body")
	stubbyFeet(b, 0.55, V(0.65, 0.25, 1.0), "Belly")
	b:Eyes(head, 0.45, 0.3, V(0.5, 0.5, 0.2), "White", "Dazed")
end

-- TODO: Mystduck (not sculpted yet, uses the Generic design)

-- Cat with a lucky coin on its forehead.
Designs["Coinpurr"] = function(b)
	local body = b:Ellipsoid("Body", V(1.4, 1.65, 1.3), V(0, 1.2, 0), nil, "Body")
	b:SetCore(body)
	local head = b:Ellipsoid("Head", V(2.2, 1.85, 1.75), V(0, 2.75, -0.1), nil, "Body")
	b:MirrorLimb("Ear", V(0.6, 3.4, -0.05), V(0.95, 4.15, 0.0), V2(0.65, 0.22), "Body")
	b:MirrorLimb("EarInner", V(0.62, 3.45, -0.15), V(0.9, 4.0, -0.1), V2(0.38, 0.1), "Accent")
	b:Cylinder("Coin", 0.12, 0.7, V(0, 3.35, -0.85), V(90, 0, 0), "Gold", { Material = Enum.Material.Foil })
	for _, side in { -1, 1 } do
		for index, angle in { -8, 8 } do
			b:Box("Whisker" .. side .. index, V(0.75, 0.05, 0.05), V(side * 1.15, 2.55, -0.65), V(0, 0, angle * side), "Dark")
		end
	end
	bipedLegs(b, 0.75, 0.38, 0.38, "Body", "Accent")
	arms(b, V(0.55, 1.65, -0.15), V(0.8, 1.15, -0.5), 0.26, "Body")
	b:Chain("Tail", { V(0, 0.9, 0.55), V(0, 1.5, 1.25), V(0, 2.3, 1.1) }, 0.24, 0.22, "Body")
	b:Ellipsoid("TailTip", V(0.35, 0.35, 0.35), V(0, 2.45, 1.0), nil, "Accent")
	b:Eyes(head, 0.5, 0.05, V(0.36, 0.6, 0.2), "Black")
	b:Mouth(head, -0.45, 0.45, true)
end

-- TODO: Regalynx (not sculpted yet, uses the Generic design)

return Designs
