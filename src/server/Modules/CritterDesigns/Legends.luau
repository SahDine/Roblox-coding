--[[
	Critter designs: Frostwing, Voltwing, Pyrowing, Wishstar, Skyserpent, Abysswing, Glitchno, Primordeus.
	See CritterBuilder for the toolkit. Ground at y = 0, the critter faces -Z.
]]

local Helpers = require(script.Parent.Helpers)

local V = Vector3.new
local V2 = Vector2.new
local stubbyFeet, bipedLegs, quadLegs, arms = Helpers.stubbyFeet, Helpers.bipedLegs, Helpers.quadLegs, Helpers.arms

local Designs = {}

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

-- TODO: Voltwing (not sculpted yet, uses the Generic design)

-- TODO: Pyrowing (not sculpted yet, uses the Generic design)

-- TODO: Wishstar (not sculpted yet, uses the Generic design)

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

return Designs
