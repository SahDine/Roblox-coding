--[[
	CritterDesigns
	One sculpting function per critter (see CritterBuilder for the toolkit).
	Original creatures inspired by classic monster-collecting archetypes.

	Conventions: ground at y = 0, the critter faces -Z, ~1 unit = 1 stud at scale 1.
	Palette keys: "Body", "Accent", "Belly", "Extra" (set in Shared/Config/Units).
]]

local V = Vector3.new
local V2 = Vector2.new

local Designs = {}

-- Shared body plans -----------------------------------------------------------------------

local function stubbyFeet(b, spacing: number, size: Vector3, color: any)
	b:MirrorEllipsoid("Foot", size, V(spacing, size.Y / 2, -0.25), nil, color)
end

local function bipedLegs(b, hipY: number, spacing: number, thickness: number, color: any, footColor: any?)
	b:MirrorLimb("Leg", V(spacing, hipY, 0.05), V(spacing + 0.05, 0.35, -0.05), thickness, color)
	b:MirrorEllipsoid("Foot", V(thickness * 1.1, thickness * 0.6, thickness * 1.5), V(spacing + 0.05, thickness * 0.3, -0.25), nil, footColor or color)
end

local function quadLegs(b, frontZ: number, backZ: number, spacing: number, topY: number, thickness: number, color: any, pawColor: any?)
	for _, z in { frontZ, backZ } do
		b:MirrorLimb("Leg" .. z, V(spacing, topY, z), V(spacing, 0.3, z - 0.05), thickness, color)
		b:MirrorEllipsoid("Paw" .. z, V(thickness * 1.15, thickness * 0.55, thickness * 1.35), V(spacing, thickness * 0.27, z - 0.12), nil, pawColor or color)
	end
end

local function arms(b, shoulder: Vector3, hand: Vector3, thickness: number, color: any, handColor: any?)
	b:MirrorLimb("Arm", shoulder, hand, thickness, color)
	b:MirrorEllipsoid("Hand", V(thickness * 1.2, thickness * 1.2, thickness * 1.2), hand, nil, handColor or color)
end

-- Common ------------------------------------------------------------------------------------

-- Seed toad with a bulb on its back.
Designs["Sproutle"] = function(b)
	local body = b:Ellipsoid("Body", V(2.3, 1.5, 2.6), V(0, 1.05, 0.35), nil, "Body")
	b:SetCore(body)
	local head = b:Ellipsoid("Head", V(2.2, 1.75, 1.9), V(0, 1.75, -1.05), nil, "Body")
	b:MirrorLimb("Ear", V(0.65, 2.45, -1.1), V(0.95, 2.95, -1.05), V2(0.4, 0.16), "Body")
	quadLegs(b, -0.4, 1.15, 0.8, 0.75, 0.62, "Body")
	-- Bulb
	b:Ellipsoid("Bulb", V(1.75, 1.6, 1.75), V(0, 2.05, 0.75), nil, "Accent")
	b:Ellipsoid("BulbTip", V(0.7, 0.6, 0.7), V(0, 2.85, 0.8), nil, "Accent")
	for index, angle in { 0, 90, 180, 270 } do
		local rad = math.rad(angle + 45)
		local dir = V(math.sin(rad), 0, math.cos(rad))
		b:Limb("Leaf" .. index, V(0, 1.55, 0.75) + dir * 0.5, V(0, 1.5, 0.75) + dir * 1.35, V2(0.75, 0.12), "Extra")
	end
	-- Spots
	b:FaceDot("Spot1", head, -0.65, 0.55, V(0.4, 0.3, 0.12), "Extra")
	b:FaceDot("Spot2", head, 0.5, 0.65, V(0.3, 0.25, 0.12), "Extra")
	b:Ellipsoid("Spot3", V(0.5, 0.18, 0.4), V(0.75, 1.6, 0.15), V(0, 0, 25), "Extra")
	b:Ellipsoid("Spot4", V(0.4, 0.15, 0.35), V(-0.8, 1.55, 0.45), V(0, 0, -25), "Extra")
	b:Eyes(head, 0.52, 0.12, V(0.42, 0.55, 0.2), Color3.fromRGB(200, 40, 50))
	b:Mouth(head, -0.42, 0.55, true)
end

-- Little fire lizard with a flame on its tail.
Designs["Embit"] = function(b)
	local body = b:Ellipsoid("Body", V(1.6, 1.9, 1.45), V(0, 1.45, 0), nil, "Body")
	b:SetCore(body)
	b:Ellipsoid("BellyPatch", V(1.15, 1.45, 0.6), V(0, 1.35, -0.5), nil, "Belly")
	local head = b:Ellipsoid("Head", V(1.9, 1.7, 1.8), V(0, 3.0, -0.2), nil, "Body")
	bipedLegs(b, 0.9, 0.5, 0.58, "Body")
	arms(b, V(0.7, 1.95, -0.15), V(1.05, 1.45, -0.55), 0.34, "Body")
	b:Chain("Tail", { V(0, 1.0, 0.55), V(0, 0.85, 1.45), V(0, 1.35, 2.1) }, 0.6, 0.38, "Body")
	b:Flame("TailFlame", V(0, 1.5, 2.2), 0.55)
	b:Eyes(head, 0.42, 0.12, V(0.42, 0.62, 0.2), "Black")
	b:Mouth(head, -0.4, 0.6, true)
end

-- Turtle tadpole with a round shell and a curly tail.
Designs["Puddlet"] = function(b)
	local body = b:Ellipsoid("Body", V(1.7, 1.85, 1.6), V(0, 1.4, 0), nil, "Body")
	b:SetCore(body)
	b:Ellipsoid("Shell", V(2.0, 2.1, 1.3), V(0, 1.45, 0.45), nil, "Accent")
	b:Ellipsoid("ShellRim", V(2.05, 0.28, 1.7), V(0, 0.98, 0.3), nil, "Belly")
	b:Ellipsoid("Plastron", V(1.3, 1.5, 0.5), V(0, 1.4, -0.65), nil, "Belly")
	local head = b:Ellipsoid("Head", V(1.8, 1.7, 1.7), V(0, 2.95, -0.15), nil, "Body")
	bipedLegs(b, 0.85, 0.5, 0.55, "Body")
	arms(b, V(0.75, 1.95, -0.15), V(1.1, 1.5, -0.5), 0.34, "Body")
	b:Chain("Tail", { V(0, 0.9, 1.0), V(0, 1.05, 1.6), V(0, 1.55, 1.75) }, 0.42, 0.3, "Body")
	b:Ellipsoid("TailCurl", V(0.5, 0.5, 0.5), V(0, 1.75, 1.55), nil, "Body")
	b:Eyes(head, 0.42, 0.12, V(0.42, 0.6, 0.2), Color3.fromRGB(150, 70, 60))
	b:Mouth(head, -0.42, 0.55, true)
end

-- Round singing balloon with a hair curl.
Designs["Puffloon"] = function(b)
	local body = b:Ellipsoid("Body", V(2.6, 2.5, 2.4), V(0, 1.45, 0), nil, "Body")
	b:SetCore(body)
	b:MirrorLimb("Ear", V(0.75, 2.45, 0), V(1.1, 3.05, 0.05), V2(0.65, 0.22), "Body")
	b:MirrorLimb("EarInner", V(0.78, 2.5, -0.06), V(1.05, 2.95, -0.04), V2(0.38, 0.12), "Black")
	b:Chain("Curl", { V(0, 2.65, -0.3), V(0, 2.75, -0.85), V(0.2, 2.35, -1.15) }, 0.5, 0.32, "Body")
	b:Ellipsoid("CurlEnd", V(0.32, 0.32, 0.32), V(0.12, 2.15, -1.12), nil, "Body")
	b:MirrorEllipsoid("Arm", V(0.4, 0.62, 0.4), V(1.28, 1.45, -0.25), V(0, 0, -20), "Body")
	stubbyFeet(b, 0.6, V(0.72, 0.36, 0.95), "Body")
	b:Eyes(body, 0.55, 0.15, V(0.68, 0.78, 0.22), Color3.fromRGB(40, 150, 170))
	b:Mouth(body, -0.35, 0.45, true)
	b:Cheeks(body, 0.95, -0.12, 0.35, "Blush")
end

-- Uncommon ----------------------------------------------------------------------------------

-- Electric mouse with lightning tail and red cheeks.
Designs["Zappip"] = function(b)
	local body = b:Ellipsoid("Body", V(1.75, 1.85, 1.6), V(0, 1.2, 0.05), nil, "Body")
	b:SetCore(body)
	local head = b:Ellipsoid("Head", V(2.0, 1.8, 1.7), V(0, 2.6, -0.15), nil, "Body")
	b:MirrorLimb("Ear", V(0.5, 3.25, -0.1), V(1.2, 4.55, 0.0), V2(0.55, 0.22), "Body")
	b:MirrorLimb("EarTip", V(1.0, 4.15, -0.02), V(1.27, 4.68, 0.0), V2(0.44, 0.24), "Accent")
	stubbyFeet(b, 0.45, V(0.55, 0.3, 0.85), "Body")
	arms(b, V(0.7, 1.6, -0.25), V(0.85, 1.25, -0.7), 0.3, "Body")
	-- Lightning tail
	b:Beam("Tail1", V(0, 0.85, 0.75), V(0, 1.5, 1.4), V2(0.18, 0.35), "Extra")
	b:Beam("Tail2", V(0, 1.45, 1.4), V(0, 1.3, 1.85), V2(0.18, 0.5), "Body")
	b:Beam("Tail3", V(0, 1.25, 1.85), V(0, 2.55, 2.55), V2(0.18, 0.75), "Body")
	b:Box("TailTop", V(0.2, 0.9, 1.15), V(0, 2.8, 2.55), V(-35, 0, 0), "Body")
	b:Ellipsoid("Stripe1", V(1.05, 0.2, 0.55), V(0, 1.55, 0.72), V(25, 0, 0), "Extra")
	b:Ellipsoid("Stripe2", V(0.9, 0.18, 0.5), V(0, 1.15, 0.82), V(10, 0, 0), "Extra")
	b:Eyes(head, 0.45, 0.15, V(0.38, 0.45, 0.2), "Black")
	b:Cheeks(head, 0.68, -0.25, 0.48)
	b:Mouth(head, -0.3, 0.4, true)
	b:FaceDot("Nose", head, 0, -0.05, V(0.12, 0.08, 0.08), "Black")
end

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

-- Rare --------------------------------------------------------------------------------------

-- Mischievous spiky ghost with a huge grin.
Designs["Gloomer"] = function(b)
	local body = b:Ellipsoid("Body", V(2.8, 2.55, 2.4), V(0, 1.5, 0), nil, "Body")
	b:SetCore(body)
	b:MirrorLimb("Ear", V(0.75, 2.5, -0.15), V(1.05, 3.15, -0.05), V2(0.62, 0.3), "Body")
	for index, offset in { V(0.85, 2.35, 0.55), V(0.4, 2.55, 0.9), V(1.15, 1.85, 0.85) } do
		b:MirrorLimb("Spike" .. index, offset, offset + V(offset.X * 0.35, 0.65, 0.45), V2(0.5, 0.3), "Body")
	end
	b:MirrorLimb("Arm", V(1.2, 1.4, -0.35), V(1.65, 1.15, -0.7), 0.5, "Body")
	stubbyFeet(b, 0.75, V(0.75, 0.4, 0.95), "Body")
	b:Limb("Tail", V(0, 0.9, 1.0), V(0, 0.7, 1.55), 0.45, "Body")
	b:Eyes(body, 0.55, 0.35, V(0.6, 0.45, 0.2), Color3.fromRGB(230, 40, 50), "Angry")
	b:FaceDot("Grin", body, 0, -0.35, V(1.6, 0.45, 0.2), "White")
	b:FaceDot("GrinLine", body, 0, -0.33, V(1.4, 0.06, 0.25), "Dark")
	b:Particles(body.Part, Color3.fromRGB(160, 90, 220), 4, 0.5)
end

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

-- Epic --------------------------------------------------------------------------------------

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

-- Fire dragon with big wings.
Designs["Blazewing"] = function(b)
	local body = b:Ellipsoid("Body", V(1.7, 2.2, 1.5), V(0, 1.95, 0.05), nil, "Body")
	b:SetCore(body)
	b:Ellipsoid("BellyPatch", V(1.2, 1.8, 0.6), V(0, 1.9, -0.5), nil, "Belly")
	b:Limb("Neck", V(0, 2.8, -0.15), V(0, 3.55, -0.4), 0.65, "Body")
	local head = b:Ellipsoid("Head", V(1.1, 1.0, 1.25), V(0, 3.95, -0.5), nil, "Body")
	b:Ellipsoid("Snout", V(0.75, 0.55, 0.8), V(0, 3.8, -1.05), nil, "Body")
	b:MirrorLimb("Horn", V(0.3, 4.3, -0.25), V(0.42, 4.55, 0.45), 0.16, "Belly")
	b:MirrorLimb("Thigh", V(0.5, 1.5, 0.05), V(0.55, 0.7, -0.05), 0.65, "Body")
	b:MirrorEllipsoid("Foot", V(0.55, 0.32, 0.9), V(0.55, 0.16, -0.25), nil, "Body")
	arms(b, V(0.75, 2.6, -0.2), V(1.05, 2.0, -0.6), 0.3, "Body")
	-- Wings: bone + membrane
	local vertical = { Up = V(0, 0, 1) }
	b:MirrorLimb("WingBone", V(0.5, 2.95, 0.55), V(2.2, 4.55, 1.0), 0.22, "Body")
	b:MirrorLimb("WingBone2", V(2.2, 4.55, 1.0), V(3.15, 3.6, 1.2), 0.16, "Body")
	b:MirrorLimb("WingMembrane1", V(0.6, 3.0, 0.65), V(2.15, 4.25, 1.05), V2(1.25, 0.1), "Accent", vertical)
	b:MirrorLimb("WingMembrane2", V(0.7, 2.75, 0.7), V(2.9, 3.45, 1.15), V2(1.15, 0.1), "Accent", vertical)
	b:MirrorLimb("WingMembrane3", V(0.75, 2.6, 0.7), V(2.3, 2.75, 1.05), V2(0.8, 0.1), "Accent", vertical)
	b:Chain("Tail", { V(0, 1.2, 0.65), V(0, 0.75, 1.5), V(0, 1.05, 2.3) }, 0.65, 0.38, "Body")
	b:Flame("TailFlame", V(0, 1.3, 2.45), 0.8)
	b:Eyes(head, 0.28, 0.1, V(0.24, 0.3, 0.14), Color3.fromRGB(40, 140, 120), "Angry")
end

-- Legendary --------------------------------------------------------------------------------

-- Frost bird with a long flowing tail.
Designs["Frostwing"] = function(b)
	b.Hover = 0.6
	local body = b:Ellipsoid("Body", V(1.4, 1.6, 2.0), V(0, 2.1, 0.2), V(-15, 0, 0), "Body")
	b:SetCore(body)
	b:Ellipsoid("Chest", V(1.1, 1.2, 0.8), V(0, 2.2, -0.45), nil, "Belly")
	b:Limb("Neck", V(0, 2.6, -0.35), V(0, 3.15, -0.6), 0.6, "Body")
	local head = b:Ellipsoid("Head", V(1.05, 1.0, 1.1), V(0, 3.45, -0.65), nil, "Body")
	b:Limb("Beak", V(0, 3.35, -1.1), V(0, 3.2, -1.6), V2(0.28, 0.22), "Grey")
	for index, x in { -0.15, 0, 0.15 } do
		b:Chain("Crest" .. index, { V(x, 3.85, -0.75), V(x * 1.5, 4.3, -0.55), V(x * 2, 4.5, -0.15) }, 0.16, 0.12, "Accent")
	end
	b:MirrorEllipsoid("Wing", V(3.3, 0.16, 1.8), V(1.95, 2.85, 0.4), V(0, 8, 18), "Body")
	b:MirrorEllipsoid("WingTip", V(1.6, 0.18, 1.3), V(3.25, 3.25, 0.6), V(0, 12, 22), "Accent")
	b:MirrorChain("TailFeather", { V(0.15, 1.85, 1.0), V(0.3, 1.25, 2.1), V(0.4, 0.95, 3.2) }, 0.55, 0.45, "Accent")
	b:MirrorLimb("Leg", V(0.3, 1.5, 0.2), V(0.3, -0.45, 0.0), 0.14, "Grey")
	b:Eyes(head, 0.3, 0.1, V(0.24, 0.24, 0.12), Color3.fromRGB(220, 50, 60), "Angry")
	b:Particles(body.Part, Color3.fromRGB(220, 240, 255), 8, 0.35)
end

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

-- Mythic ---------------------------------------------------------------------------------------

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

-- Sky serpent coiled around itself.
Designs["Skyserpent"] = function(b)
	b.Hover = 0.6
	local points = {}
	for index = 0, 11 do
		local angle = index * 0.75
		local radius = 1.35 - index * 0.05
		table.insert(points, V(math.sin(angle) * radius, 0.55 + index * 0.27, math.cos(angle) * radius + 0.3))
	end
	b:Chain("Coil", points, 0.95, 0.6, "Body")
	local body = b:Ellipsoid("Body", V(1.2, 1.2, 1.2), V(0, 1.4, 0.3), nil, "Body")
	b:SetCore(body)
	for index = 2, 11, 3 do
		b:Ellipsoid("Ring" .. index, V(0.55, 0.12, 0.55), points[index] + V(0, 0.4, 0), nil, "Accent", { Neon = true })
	end
	b:Limb("Neck", points[#points], V(0, 3.85, -0.6), 0.6, "Body")
	local head = b:Ellipsoid("Head", V(1.1, 0.9, 1.65), V(0, 4.05, -0.95), nil, "Body")
	b:Ellipsoid("Jaw", V(0.85, 0.35, 1.2), V(0, 3.7, -1.15), nil, "Body")
	b:FaceDot("Mark", head, 0, -0.2, V(0.7, 0.12, 0.2), "Red")
	b:MirrorChain("Horn", { V(0.35, 4.35, -0.65), V(0.55, 4.6, 0.0), V(0.6, 4.45, 0.6) }, 0.22, 0.12, "Body")
	b:MirrorLimb("Fin", V(0.5, 3.95, -0.4), V(1.1, 4.1, 0.2), V2(0.5, 0.1), "Accent")
	b:Eyes(head, 0.3, 0.12, V(0.24, 0.2, 0.12), "Yellow", "Glow")
	b:Particles(body.Part, Color3.fromRGB(120, 255, 160), 6, 0.4)
end

-- Silver guardian of the deep sea.
Designs["Abysswing"] = function(b)
	b.Hover = 0.8
	local body = b:Ellipsoid("Body", V(1.55, 2.0, 1.75), V(0, 2.1, 0.25), nil, "Body")
	b:SetCore(body)
	b:Ellipsoid("Belly", V(1.2, 1.5, 0.7), V(0, 2.0, -0.4), nil, "Belly")
	b:Limb("Neck", V(0, 2.9, -0.2), V(0, 3.7, -0.45), 0.6, "Body")
	local head = b:Ellipsoid("Head", V(0.95, 0.85, 1.35), V(0, 4.0, -0.6), nil, "Body")
	b:MirrorEllipsoid("EyePatch", V(0.42, 0.32, 0.5), V(0.3, 4.05, -0.95), nil, "Accent")
	for index, y in { 3.0, 2.4, 1.8 } do
		b:Ellipsoid("BackPlate" .. index, V(0.45, 0.6, 0.35), V(0, y, 1.1 - index * 0.05), V(20, 0, 0), "Accent")
	end
	b:MirrorLimb("WingArm", V(0.6, 2.9, 0.3), V(2.4, 3.6, 0.5), 0.3, "Body")
	for index = 1, 4 do
		local base = V(1.5 + index * 0.25, 3.5 - index * 0.05, 0.5)
		b:MirrorLimb("Feather" .. index, base, base + V(0.35, -1.0 - index * 0.15, 0.1), V2(0.38, 0.12), "Body")
	end
	b:MirrorEllipsoid("FeatherTip", V(0.4, 0.4, 0.14), V(2.6, 2.0, 0.6), nil, "Accent")
	b:Chain("Tail", { V(0, 1.4, 1.0), V(0, 0.7, 1.9), V(0, 0.65, 2.8) }, 0.5, 0.3, "Body")
	b:MirrorEllipsoid("TailFin", V(0.6, 0.12, 0.8), V(0.3, 0.65, 2.95), V(0, 30, 0), "Accent")
	b:Eyes(head, 0.28, 0.08, V(0.2, 0.2, 0.12), "Black")
	b:Particles(body.Part, Color3.fromRGB(140, 200, 255), 6, 0.4)
end

-- Secret ---------------------------------------------------------------------------------------

-- The creator: celestial horse with a golden ring.
Designs["Primordeus"] = function(b)
	b.Hover = 0.4
	local body = b:Ellipsoid("Body", V(1.55, 1.5, 2.6), V(0, 2.1, 0.25), nil, "Body")
	b:SetCore(body)
	b:Ellipsoid("BellyPatch", V(1.25, 0.8, 2.1), V(0, 1.7, 0.25), nil, "Extra")
	b:Limb("Neck", V(0, 2.5, -0.75), V(0, 3.45, -1.15), 0.75, "Body")
	local head = b:Ellipsoid("Head", V(0.95, 0.9, 1.3), V(0, 3.75, -1.35), nil, "Body")
	b:Ellipsoid("Face", V(0.75, 0.65, 0.7), V(0, 3.65, -1.85), nil, "Extra")
	b:Chain("Crest", { V(0, 4.15, -1.35), V(0, 4.75, -0.9), V(0, 4.85, -0.15), V(0, 4.5, 0.35) }, 0.5, 0.25, "Body")
	b:MirrorChain("Mane", { V(0.3, 3.45, -0.9), V(0.6, 3.0, -0.3), V(0.55, 2.6, 0.2) }, 0.5, 0.3, "Body")
	quadLegs(b, -0.6, 1.1, 0.5, 1.8, 0.38, "Body", "Accent")
	-- Golden ring around the waist
	local center = V(0, 2.2, 0.3)
	local ring = {}
	for index = 0, 16 do
		local angle = index / 16 * math.pi * 2
		table.insert(ring, center + V(math.cos(angle) * 1.75, math.sin(angle) * 0.35, math.sin(angle) * 1.75))
	end
	b:Chain("Ring", ring, 0.32, 0.32, "Accent", { Material = Enum.Material.Foil })
	for index = 1, 4 do
		local angle = (index - 0.5) / 4 * math.pi * 2
		b:Ellipsoid("Gem" .. index, V(0.3, 0.3, 0.3), center + V(math.cos(angle) * 1.75, math.sin(angle) * 0.35 + 0.2, math.sin(angle) * 1.75), nil, "Green", { Neon = true })
	end
	b:Chain("Tail", { V(0, 2.2, 1.55), V(0, 1.6, 2.1), V(0, 1.1, 2.3) }, 0.45, 0.3, "Extra")
	b:Eyes(head, 0.25, 0.0, V(0.22, 0.22, 0.12), Color3.fromRGB(60, 200, 110), "Angry")
	b:Particles(body.Part, Color3.fromRGB(255, 230, 140), 10, 0.45)
end

-- A glitch in the critter database.
Designs["Glitchno"] = function(b)
	b.Hover = 0.3
	local layout = {
		"..##",
		".###",
		"##.#",
		"####",
		"#.##",
		"###.",
		"##..",
		"#...",
	}
	local colors = { "Body", "Accent", "Extra", "Belly" }
	local core
	for row, line in layout do
		for column = 1, #line do
			if string.sub(line, column, column) == "#" then
				local color = colors[(row * 3 + column) % #colors + 1]
				local neon = (row + column) % 3 == 0
				local part = b:Box(
					`Pixel{row}_{column}`,
					V(0.7, 0.7, 0.7),
					V((column - 2.5) * 0.7, 0.4 + (#layout - row) * 0.7, (row % 2) * 0.12),
					nil,
					color,
					{ Neon = neon }
				)
				if row == 4 and column == 2 then
					core = part
				end
			end
		end
	end
	b.Core = core
	b:Particles(core, Color3.fromRGB(0, 255, 160), 12, 0.35)
end

-- Fallback for critters without a design (e.g. added in config but not sculpted yet).
Designs.Generic = function(b)
	local body = b:Ellipsoid("Body", V(2.2, 2.0, 2.0), V(0, 1.35, 0), nil, "Body")
	b:SetCore(body)
	b:Ellipsoid("BellyPatch", V(1.5, 1.4, 0.6), V(0, 1.2, -0.7), nil, "Belly")
	b:MirrorLimb("Ear", V(0.6, 2.2, 0), V(0.9, 2.9, 0.05), V2(0.5, 0.2), "Accent")
	stubbyFeet(b, 0.55, V(0.6, 0.35, 0.85), "Accent")
	b:Eyes(body, 0.45, 0.3, V(0.4, 0.55, 0.2), "Black")
	b:Mouth(body, -0.1, 0.45, true)
end

return Designs
