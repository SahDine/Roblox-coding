--[[
	Shared body plans used by several critter designs. Each limb is its own bone so the
	client can animate it (walk cycle / idle): legs and feet swing from the hip, arms
	from the shoulder, left and right in opposite phase, quadrupeds trot (diagonal pairs).
]]

local V = Vector3.new

local Helpers = {}

-- Two round stubby feet under a blob-shaped critter (they shuffle when it walks).
function Helpers.stubbyFeet(b, spacing: number, size: Vector3, color: any)
	b:MirrorBone("LegFoot", V(spacing, size.Y, -0.15), nil, function()
		b:Ball("Foot", size, V(spacing, size.Y / 2, -0.25), nil, color, { Detail = 0 })
	end)
end

-- Two legs from the hips to the ground with a foot each.
function Helpers.bipedLegs(b, hipY: number, spacing: number, thickness: number, color: any, footColor: any?)
	b:MirrorBone("Leg", V(spacing, hipY, 0.05), nil, function()
		b:Limb("Leg", V(spacing, hipY, 0.05), V(spacing + 0.05, thickness * 0.5, -0.05), thickness, color)
		b:Ball(
			"Foot",
			V(thickness * 1.15, thickness * 0.6, thickness * 1.55),
			V(spacing + 0.05, thickness * 0.3, -0.25),
			nil,
			footColor or color,
			{ Detail = 0 }
		)
	end)
end

-- Four legs (front at frontZ, back at backZ) with paws. Diagonal pairs move together (trot).
function Helpers.quadLegs(b, frontZ: number, backZ: number, spacing: number, topY: number, thickness: number, color: any, pawColor: any?)
	for index, z in { frontZ, backZ } do
		b:MirrorBone(
			if index == 1 then "LegFront" else "LegBack",
			V(spacing, topY, z),
			{ Phase = if index == 1 then 0 else 0.5 },
			function()
				b:Limb("Leg", V(spacing, topY, z), V(spacing, thickness * 0.45, z - 0.05), thickness, color)
				b:Ball(
					"Paw",
					V(thickness * 1.2, thickness * 0.55, thickness * 1.4),
					V(spacing, thickness * 0.27, z - 0.12),
					nil,
					pawColor or color,
					{ Detail = 0 }
				)
			end
		)
	end
end

-- Two arms from the shoulders with a hand each (they swing opposite to the legs).
function Helpers.arms(b, shoulder: Vector3, hand: Vector3, thickness: number, color: any, handColor: any?)
	b:MirrorBone("Arm", shoulder, { Phase = 0.5 }, function()
		b:Limb("Arm", shoulder, hand, thickness, color)
		b:Ball("Hand", V(thickness * 1.25, thickness * 1.25, thickness * 1.25), hand, nil, handColor or color, { Detail = 0 })
	end)
end

return Helpers
