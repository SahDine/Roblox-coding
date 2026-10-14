--[[
	Critter designs: Sproutle, Bloomtoad, Floradon, Embit, Emberclaw, Blazewing, Puffloon, Puffluxe.
	See CritterBuilder for the toolkit. Ground at y = 0, the critter faces -Z.
]]

local Helpers = require(script.Parent.Helpers)

local V = Vector3.new
local V2 = Vector2.new
local stubbyFeet, bipedLegs, quadLegs, arms = Helpers.stubbyFeet, Helpers.bipedLegs, Helpers.quadLegs, Helpers.arms

local Designs = {}

local SEED_EYE = Color3.fromRGB(215, 50, 60)
local FIRE_EYE = Color3.fromRGB(40, 110, 140)
local PUFF_EYE = Color3.fromRGB(40, 150, 175)
local BARK = Color3.fromRGB(150, 100, 65)

-- Pyramid of `count` triangles leaning in from a ring to a tip (closed buds, leafy roofs).
local function roof(b, name: string, center: Vector3, radius: number, tipHeight: number, width: number, color: any, count: number?, turn: number?)
	local n = count or 4
	local tip = center + V(0, tipHeight, 0)
	for index = 1, n do
		local angle = math.rad((turn or 0) + (index - 1) * 360 / n)
		local out = V(math.sin(angle), 0, math.cos(angle))
		b:Spike(name .. index, center + out * radius, tip, width, 0.16, color, nil, out)
	end
end

-- Flat horizontal triangles fanned around a point (leaves, petals). `drop` tilts the tips down (negative = up).
local function fan(b, name: string, center: Vector3, length: number, width: number, drop: number, color: any, count: number, turn: number)
	for index = 1, count do
		local angle = math.rad(turn + (index - 1) * 360 / count)
		local out = V(math.sin(angle), 0, math.cos(angle))
		b:Spike(name .. index, center, center + out * length - V(0, drop, 0), width, 0.14, color, nil, V(0, 1, 0))
	end
end

-- Wing membrane hanging from a bone: triangles whose base sits on the bone, tips pointing away from it.
local function wing(b, name: string, shoulder: Vector3, peak: Vector3, normal: Vector3, drops: { number }, color: any)
	local along = peak - shoulder
	local away = normal:Cross(along).Unit
	if away.Y > 0 then
		away = -away
	end
	local count = #drops
	for index, drop in drops do
		local base = shoulder + along * ((index - 0.5) / count)
		b:MirrorSpike(name .. index, base, base + away * drop, along.Magnitude / count * 1.2, 0.12, color, nil, normal)
	end
end

-- Seed toad with a leafy bulb on its back.
Designs["Sproutle"] = function(b)
	local body = b:Gem("Body", V(2.0, 1.3, 2.1), V(0, 1.05, 0.45), nil, "Body")
	b:SetCore(body)
	local head = b:Gem("Head", V(2.4, 1.75, 1.5), V(0, 1.6, -0.85), nil, "Body")
	for _, z in { -0.2, 1.05 } do
		b:MirrorBox("Leg" .. z, V(0.62, 0.7, 0.62), V(0.72, 0.35, z), nil, "Body")
	end
	b:MirrorSpike("Ear", V(0.75, 2.3, -0.95), V(1.1, 2.9, -0.95), 0.5, 0.18, "Body")
	b:Gem("Bulb", V(1.8, 1.1, 1.8), V(0, 2.2, 0.55), nil, "Accent", { Axis = "Y" })
	roof(b, "Leaf", V(0, 2.65, 0.55), 0.85, 0.95, 1.25, "Extra", 4, 45)
	b:Eyes(head, 0.58, 0.1, V(0.5, 0.6, 0.2), SEED_EYE)
	b:Mouth(head, -0.5, 0.85, false)
	b:FaceDot("Spot", head, -0.72, 0.62, V(0.36, 0.26, 0.12), "Extra")
end

-- Bigger toad whose bulb has opened into a pink bud with four leaves.
Designs["Bloomtoad"] = function(b)
	local body = b:Gem("Body", V(2.2, 1.4, 2.3), V(0, 1.15, 0.5), nil, "Body")
	b:SetCore(body)
	local head = b:Gem("Head", V(2.5, 1.8, 1.55), V(0, 1.75, -0.95), nil, "Body")
	for _, z in { -0.25, 1.2 } do
		b:MirrorBox("Leg" .. z, V(0.7, 0.8, 0.7), V(0.8, 0.4, z), nil, "Body")
	end
	b:MirrorSpike("Ear", V(0.8, 2.45, -1.05), V(1.3, 3.2, -1.0), 0.55, 0.18, "Body")
	fan(b, "Leaf", V(0, 2.0, 0.6), 2.0, 1.0, 0.35, "Extra", 4, 45)
	b:Gem("Bud", V(1.2, 0.9, 1.2), V(0, 2.4, 0.6), nil, "Accent", { Axis = "Y" })
	roof(b, "Petal", V(0, 2.75, 0.6), 0.55, 1.1, 0.95, "Accent", 4, 0)
	b:Eyes(head, 0.6, 0.12, V(0.48, 0.55, 0.2), SEED_EYE, "Angry")
	b:Mouth(head, -0.5, 0.8, false)
	b:FaceDot("Spot", head, -0.75, 0.6, V(0.36, 0.26, 0.12), "Extra")
end

-- Huge flower toad: open five-petal flower over a palm of leaves.
Designs["Floradon"] = function(b)
	local body = b:Gem("Body", V(2.6, 1.7, 2.6), V(0, 1.4, 0.5), nil, "Body")
	b:SetCore(body)
	local head = b:Gem("Head", V(2.6, 1.7, 1.5), V(0, 1.75, -1.1), nil, "Body")
	for _, z in { -0.4, 1.35 } do
		b:MirrorBox("Leg" .. z, V(0.85, 1.0, 0.85), V(0.95, 0.5, z), nil, "Body")
		b:MirrorBox("Claw" .. z, V(0.6, 0.18, 0.2), V(0.95, 0.09, z - 0.5), nil, "White")
	end
	b:MirrorSpike("Ear", V(0.85, 2.45, -1.2), V(1.15, 2.95, -1.2), 0.5, 0.18, "Body")
	b:Box("Trunk", V(0.7, 0.9, 0.7), V(0, 2.55, 0.5), V(0, 45, 0), BARK)
	fan(b, "Leaf", V(0, 2.65, 0.5), 2.2, 1.1, 0.6, "Extra", 4, 45)
	fan(b, "Petal", V(0, 3.0, 0.5), 1.8, 1.3, -0.15, "Accent", 5, 0)
	b:Box("Center", V(0.8, 0.3, 0.8), V(0, 3.05, 0.5), V(0, 45, 0), "Belly")
	b:Eyes(head, 0.62, 0.15, V(0.46, 0.5, 0.2), SEED_EYE, "Angry")
	b:Mouth(head, -0.48, 0.9, true)
	b:FaceDot("Spot", head, -0.8, 0.55, V(0.38, 0.28, 0.12), "Extra")
end

-- Little fire lizard with a flame on its tail.
Designs["Embit"] = function(b)
	local body = b:Gem("Body", V(1.5, 1.7, 1.35), V(0, 1.35, 0.05), nil, "Body")
	b:SetCore(body)
	b:Gem("Belly", V(1.0, 1.25, 0.3), V(0, 1.3, -0.62), nil, "Belly")
	local head = b:Gem("Head", V(1.85, 1.65, 1.6), V(0, 2.85, -0.25), nil, "Body")
	bipedLegs(b, 0.8, 0.45, 0.55, "Body")
	arms(b, V(0.7, 1.85, -0.2), V(1.0, 1.4, -0.55), 0.32, "Body")
	b:Chain("Tail", { V(0, 0.9, 0.6), V(0, 0.65, 1.4), V(0, 1.1, 2.0) }, 0.55, 0.38, "Body")
	b:Flame("TailFlame", V(0, 1.25, 2.1), 0.55)
	b:Eyes(head, 0.42, 0.15, V(0.42, 0.62, 0.2), FIRE_EYE)
	b:Mouth(head, -0.42, 0.6, true)
end

-- Taller, sharper fire lizard with a horn and claws.
Designs["Emberclaw"] = function(b)
	local body = b:Gem("Body", V(1.5, 2.0, 1.35), V(0, 1.65, 0.1), nil, "Body")
	b:SetCore(body)
	b:Gem("Belly", V(0.95, 1.55, 0.3), V(0, 1.55, -0.62), nil, "Belly")
	local head = b:Gem("Head", V(1.5, 1.35, 1.5), V(0, 3.3, -0.35), nil, "Body")
	b:Box("Snout", V(1.0, 0.55, 0.6), V(0, 3.0, -1.3), nil, "Body")
	b:Spike("Horn", V(0, 3.85, 0.1), V(0, 4.15, 1.05), 0.55, 0.2, "Body", nil, V(1, 0, 0))
	bipedLegs(b, 1.0, 0.5, 0.55, "Body")
	arms(b, V(0.7, 2.25, -0.2), V(1.05, 1.7, -0.6), 0.3, "Body")
	b:MirrorSpike("Claw", V(1.05, 1.55, -0.65), V(1.1, 1.35, -0.95), 0.2, 0.1, "White")
	b:Chain("Tail", { V(0, 1.1, 0.65), V(0, 0.6, 1.5), V(0, 0.9, 2.3), V(0, 1.5, 2.7) }, 0.55, 0.32, "Body")
	b:Flame("TailFlame", V(0, 1.65, 2.75), 0.7)
	b:Eyes(head, 0.36, 0.15, V(0.34, 0.42, 0.18), FIRE_EYE, "Angry")
	b:Mouth(head, -0.45, 0.6, false)
end

-- Fire dragon with big wings.
Designs["Blazewing"] = function(b)
	local body = b:Gem("Body", V(1.9, 2.4, 1.7), V(0, 2.0, 0.1), nil, "Body")
	b:SetCore(body)
	b:Gem("Belly", V(1.3, 2.0, 0.3), V(0, 1.9, -0.82), nil, "Belly")
	b:Limb("Neck", V(0, 3.0, -0.1), V(0, 3.75, -0.45), 0.75, "Body")
	local head = b:Gem("Head", V(1.2, 1.05, 1.3), V(0, 4.15, -0.5), nil, "Body")
	b:Box("Snout", V(0.85, 0.5, 0.7), V(0, 3.95, -1.3), nil, "Body")
	b:MirrorSpike("Horn", V(0.35, 4.5, -0.3), V(0.55, 4.8, 0.6), 0.3, 0.15, "Body", nil, V(1, 0, 0))
	b:MirrorLimb("Thigh", V(0.6, 1.4, 0.1), V(0.65, 0.5, -0.05), 0.75, "Body")
	b:MirrorBox("Foot", V(0.6, 0.35, 0.95), V(0.65, 0.175, -0.25), nil, "Body")
	arms(b, V(0.85, 2.6, -0.3), V(1.15, 2.0, -0.7), 0.3, "Body")
	local normal = V(0.3, 0, -1).Unit
	b:MirrorLimb("WingBone", V(0.6, 2.9, 0.6), V(2.3, 4.7, 1.1), 0.25, "Body")
	b:MirrorLimb("WingFinger", V(2.3, 4.7, 1.1), V(2.9, 3.4, 1.3), 0.18, "Body")
	wing(b, "Wing", V(0.6, 2.9, 0.6), V(2.3, 4.7, 1.1), normal, { 0.9, 1.3, 1.6 }, "Accent")
	b:Chain("Tail", { V(0, 1.2, 0.75), V(0, 0.75, 1.6), V(0, 1.05, 2.4) }, 0.7, 0.4, "Body")
	b:Flame("TailFlame", V(0, 1.3, 2.55), 0.85)
	b:Eyes(head, 0.28, 0.12, V(0.26, 0.3, 0.14), FIRE_EYE, "Angry")
end

-- Round singing balloon with a hair curl.
Designs["Puffloon"] = function(b)
	local body = b:Gem("Body", V(2.7, 2.55, 1.5), V(0, 1.45, 0), nil, "Body")
	b:SetCore(body)
	local face = b:Gem("Face", V(2.0, 1.9, 2.35), V(0, 1.45, 0), nil, "Body")
	b:MirrorSpike("Ear", V(0.75, 2.45, 0), V(1.2, 3.25, 0.05), 0.75, 0.2, "Body")
	b:MirrorSpike("EarInner", V(0.8, 2.6, -0.17), V(1.13, 3.1, -0.14), 0.38, 0.1, "Black")
	b:Chain("Curl", { V(0, 2.55, -0.6), V(0, 2.75, -1.05), V(0.15, 2.4, -1.35) }, 0.5, 0.36, "Body")
	b:Box("CurlEnd", V(0.34, 0.34, 0.34), V(0.12, 2.2, -1.32), V(0, 45, 0), "Body")
	b:MirrorBox("Arm", V(0.4, 0.6, 0.4), V(1.38, 1.4, -0.25), V(0, 0, -20), "Body")
	stubbyFeet(b, 0.6, V(0.72, 0.36, 0.95), "Body")
	b:Eyes(face, 0.5, 0.15, V(0.62, 0.72, 0.2), PUFF_EYE)
	b:Mouth(face, -0.45, 0.4, true)
	b:Cheeks(face, 0.85, -0.25, 0.3, "Blush")
end

-- Tall fluffy bunny-balloon with long ears and a white tuft.
Designs["Puffluxe"] = function(b)
	local body = b:Gem("Body", V(2.6, 3.0, 1.6), V(0, 1.75, 0.05), nil, "Body")
	b:SetCore(body)
	local face = b:Gem("Face", V(1.9, 2.35, 2.3), V(0, 1.75, 0.05), nil, "Body")
	b:Gem("Belly", V(1.4, 1.1, 0.25), V(0, 1.05, -1.2), nil, "Belly")
	b:MirrorSpike("Ear", V(0.65, 3.0, 0.1), V(1.2, 4.35, 0.2), 0.8, 0.2, "Body")
	b:MirrorSpike("EarInner", V(0.7, 3.2, -0.07), V(1.13, 4.1, 0.03), 0.4, 0.1, "Black")
	b:Spike("Tuft", V(0, 3.1, -0.5), V(0, 3.75, -1.05), 0.8, 0.3, "Belly", nil, V(1, 0, 0))
	b:MirrorSpike("TuftSide", V(0.3, 3.1, -0.4), V(0.7, 3.6, -0.85), 0.6, 0.25, "Belly", nil, V(1, 0, 0))
	arms(b, V(1.0, 1.8, -0.3), V(1.4, 1.4, -0.6), 0.32, "Body")
	stubbyFeet(b, 0.65, V(0.8, 0.4, 1.05), "Body")
	b:Eyes(face, 0.48, 0.5, V(0.55, 0.62, 0.2), PUFF_EYE)
	b:Mouth(face, -0.05, 0.45, true)
	b:Cheeks(face, 0.78, 0.05, 0.28, "Blush")
end

return Designs
