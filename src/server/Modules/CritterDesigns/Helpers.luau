--[[
	Shared body plans used by several critter designs.
]]

local V = Vector3.new

local Helpers = {}

function Helpers.stubbyFeet(b, spacing: number, size: Vector3, color: any)
	b:MirrorEllipsoid("Foot", size, V(spacing, size.Y / 2, -0.25), nil, color)
end

function Helpers.bipedLegs(b, hipY: number, spacing: number, thickness: number, color: any, footColor: any?)
	b:MirrorLimb("Leg", V(spacing, hipY, 0.05), V(spacing + 0.05, 0.35, -0.05), thickness, color)
	b:MirrorEllipsoid("Foot", V(thickness * 1.1, thickness * 0.6, thickness * 1.5), V(spacing + 0.05, thickness * 0.3, -0.25), nil, footColor or color)
end

function Helpers.quadLegs(b, frontZ: number, backZ: number, spacing: number, topY: number, thickness: number, color: any, pawColor: any?)
	for _, z in { frontZ, backZ } do
		b:MirrorLimb("Leg" .. z, V(spacing, topY, z), V(spacing, 0.3, z - 0.05), thickness, color)
		b:MirrorEllipsoid("Paw" .. z, V(thickness * 1.15, thickness * 0.55, thickness * 1.35), V(spacing, thickness * 0.27, z - 0.12), nil, pawColor or color)
	end
end

function Helpers.arms(b, shoulder: Vector3, hand: Vector3, thickness: number, color: any, handColor: any?)
	b:MirrorLimb("Arm", shoulder, hand, thickness, color)
	b:MirrorEllipsoid("Hand", V(thickness * 1.2, thickness * 1.2, thickness * 1.2), hand, nil, handColor or color)
end

return Helpers
