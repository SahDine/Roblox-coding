--[[
	Critter designs: Drakelet, Serpendrake, Puffdrake, Pebbit, Bouldron, Emberfox, Novafox, Lagoonie.
	See CritterBuilder for the toolkit. Ground at y = 0, the critter faces -Z.
]]

local Helpers = require(script.Parent.Helpers)

local V = Vector3.new
local V2 = Vector2.new
local stubbyFeet, bipedLegs, quadLegs, arms = Helpers.stubbyFeet, Helpers.bipedLegs, Helpers.quadLegs, Helpers.arms

local Designs = {}

-- TODO: Drakelet (not sculpted yet, uses the Generic design)

-- TODO: Serpendrake (not sculpted yet, uses the Generic design)

-- Friendly round dragon with tiny wings.
Designs["Puffdrake"] = function(b)
	local body = b:Ellipsoid("Body", V(2.3, 2.5, 2.0), V(0, 1.6, 0.1), nil, "Body")
	b:SetCore(body)
	b:Ellipsoid("BellyPatch", V(1.75, 2.0, 0.7), V(0, 1.5, -0.68), nil, "Belly")
	for index, y in { 1.1, 1.5, 1.9 } do
		b:Box("Stripe" .. index, V(1.2, 0.05, 0.1), V(0, y, -1.02), nil, "Extra")
	end
	b:Limb("Neck", V(0, 2.6, -0.1), V(0, 3.2, -0.2), 0.9, "Body")
	local head = b:Ellipsoid("Head", V(1.4, 1.3, 1.4), V(0, 3.6, -0.15), nil, "Body")
	local snout = b:Ellipsoid("Snout", V(1.0, 0.7, 0.85), V(0, 3.45, -0.75), nil, "Body")
	b:MirrorChain("Antenna", { V(0.25, 4.15, -0.05), V(0.45, 4.75, 0.05), V(0.75, 5.0, 0.2) }, 0.12, 0.1, "Body")
	b:MirrorLimb("Horn", V(0.4, 4.0, 0.05), V(0.5, 4.35, 0.15), 0.18, "Belly")
	b:MirrorEllipsoid("Wing", V(1.5, 1.05, 0.15), V(1.0, 2.95, 0.95), V(0, -30, -15), "Accent")
	b:MirrorLimb("WingBone", V(0.55, 2.85, 0.7), V(1.7, 3.35, 1.2), 0.15, "Body")
	arms(b, V(0.95, 2.3, -0.35), V(1.25, 1.85, -0.75), 0.36, "Body")
	stubbyFeet(b, 0.65, V(0.7, 0.4, 0.95), "Body")
	b:Chain("Tail", { V(0, 1.0, 0.9), V(0, 0.6, 1.6), V(0, 0.45, 2.2) }, 0.85, 0.45, "Body")
	b:Eyes(head, 0.32, 0.18, V(0.28, 0.36, 0.16), "Black")
	b:Mouth(snout, -0.08, 0.45, true)
end

-- TODO: Pebbit (not sculpted yet, uses the Generic design)

-- TODO: Bouldron (not sculpted yet, uses the Generic design)

-- Fox with six curly flame tails.
Designs["Emberfox"] = function(b)
	local body = b:Ellipsoid("Body", V(1.35, 1.35, 2.0), V(0, 1.1, 0.25), nil, "Body")
	b:SetCore(body)
	local head = b:Ellipsoid("Head", V(1.6, 1.4, 1.45), V(0, 2.15, -0.85), nil, "Body")
	b:Ellipsoid("Snout", V(0.7, 0.45, 0.6), V(0, 1.9, -1.55), nil, "Belly")
	b:MirrorLimb("Ear", V(0.4, 2.65, -0.8), V(0.85, 3.5, -0.7), V2(0.6, 0.18), "Body")
	b:MirrorLimb("EarTip", V(0.72, 3.25, -0.72), V(0.87, 3.55, -0.7), V2(0.38, 0.2), "Extra")
	for index, x in { -0.25, 0, 0.25 } do
		b:Ellipsoid("Curl" .. index, V(0.5, 0.45, 0.5), V(x, 2.85, -0.85 - math.abs(x) * 0.2), nil, "Accent")
	end
	quadLegs(b, -0.35, 0.85, 0.42, 0.85, 0.32, "Body", "Extra")
	for index = 1, 6 do
		local angle = math.rad(-75 + (index - 1) * 30)
		local mid = V(math.sin(angle) * 0.7, 1.55 + math.cos(angle) * 0.45, 1.75)
		local tip = V(math.sin(angle) * 1.35, 1.55 + math.cos(angle) * 0.95, 2.25)
		b:Chain("Tail" .. index, { V(0, 1.3, 1.1), mid, tip }, 0.5, 0.46, "Body")
		b:Ellipsoid("TailCurl" .. index, V(0.55, 0.55, 0.55), tip + V(0, 0.18, 0.12), nil, "Accent")
	end
	b:Eyes(head, 0.36, 0.12, V(0.34, 0.45, 0.18), Color3.fromRGB(110, 50, 20))
	b:FaceDot("Nose", head, 0, -0.25, V(0.14, 0.1, 0.1), "Black")
end

-- TODO: Novafox (not sculpted yet, uses the Generic design)

-- Gentle sea creature with a studded shell.
Designs["Lagoonie"] = function(b)
	local body = b:Ellipsoid("Body", V(2.5, 1.55, 2.8), V(0, 0.95, 0.35), nil, "Body")
	b:SetCore(body)
	b:Ellipsoid("Shell", V(2.6, 1.3, 2.5), V(0, 1.55, 0.6), nil, "Accent")
	for index, offset in { V(0.55, 2.05, 0.3), V(-0.55, 2.05, 0.3), V(0.5, 1.95, 1.1), V(-0.5, 1.95, 1.1) } do
		b:Limb("Knob" .. index, offset, offset + V(0, 0.4, 0.05), 0.35, "Extra")
	end
	b:Ellipsoid("Chest", V(1.4, 1.0, 0.6), V(0, 1.05, -0.95), nil, "Belly")
	b:Limb("Neck", V(0, 1.35, -0.75), V(0, 3.1, -1.3), 0.75, "Body")
	local head = b:Ellipsoid("Head", V(1.35, 1.15, 1.45), V(0, 3.5, -1.5), nil, "Body")
	b:Limb("Horn", V(0, 3.95, -1.6), V(0, 4.4, -1.45), 0.18, "Belly")
	b:MirrorLimb("Ear", V(0.5, 3.85, -1.4), V(0.75, 4.15, -1.3), V2(0.3, 0.15), "Body")
	for _, z in { -0.55, 1.2 } do
		b:MirrorEllipsoid("Flipper" .. z, V(1.3, 0.22, 0.7), V(1.4, 0.35, z), V(0, -20, -12), "Body")
	end
	b:Eyes(head, 0.32, 0.08, V(0.3, 0.38, 0.18), "Black")
	b:Mouth(head, -0.3, 0.35)
end

return Designs
