--[[
	CritterDesigns
	One sculpting function per critter, grouped by family in the child modules.
	Low-poly creatures inspired by classic monster-collecting archetypes, with original names.

	Conventions: ground at y = 0, the critter faces -Z, ~1 unit = 1 stud at scale 1.
	Palette keys: "Body", "Accent", "Belly", "Extra" (set in Shared/Config/Units).
]]

local V = Vector3.new
local V2 = Vector2.new

local Designs = {}

for _, batch in
	{
		require(script.Starters),
		require(script.WaterAndGhosts),
		require(script.DragonsAndRocks),
		require(script.Companions),
		require(script.Fighters),
		require(script.Legends),
	}
do
	for name, design in batch do
		assert(Designs[name] == nil, "Duplicate critter design: " .. name)
		Designs[name] = design
	end
end

-- Fallback for critters without a design (e.g. added in config but not sculpted yet).
Designs.Generic = function(b)
	local body = b:Ellipsoid("Body", V(2.2, 2.0, 2.0), V(0, 1.35, 0), nil, "Body")
	b:SetCore(body)
	b:Ellipsoid("BellyPatch", V(1.5, 1.4, 0.6), V(0, 1.2, -0.7), nil, "Belly")
	b:MirrorLimb("Ear", V(0.6, 2.2, 0), V(0.9, 2.9, 0.05), V2(0.5, 0.2), "Accent")
	b:MirrorGem("Foot", V(0.6, 0.35, 0.85), V(0.55, 0.175, -0.25), nil, "Accent")
	b:Eyes(body, 0.45, 0.3, V(0.4, 0.55, 0.2), "Black")
	b:Mouth(body, -0.1, 0.45, true)
end

return Designs
