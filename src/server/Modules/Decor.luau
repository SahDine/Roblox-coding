--[[
	Decor
	Shared building blocks for the scenery: anchored parts, lights, torches, lanterns, fireflies,
	plus the helpers used by the low-poly props (Flora, Landmarks, Horizon):
	  * Decor.Rng: deterministic random numbers (the same layout in every server and in tests),
	  * Decor.Facets: LowPoly part properties for a prop,
	  * Decor.AboveGround / Decor.DrawShaded: skip buried triangles, vary facet colours.

	Every prop is anchored and in the "Decor" collision group: players bump
	into trunks and rocks, critters walk through everything.
]]

local LowPoly = require(script.Parent.LowPoly)

local Decor = {}

export type Props = { [string]: any }

function Decor.Part(props: Props, parent: Instance): BasePart
	local part = Instance.new(props.ClassName or "Part") :: BasePart
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	part.CollisionGroup = "Decor"
	for key, value in props do
		if key ~= "ClassName" then
			(part :: any)[key] = value
		end
	end
	part.Parent = parent
	return part
end

function Decor.Light(part: BasePart, color: Color3, range: number, brightness: number?)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness or 1.5
	light.Shadows = false
	light.Parent = part
end

function Decor.Fireflies(parent: Instance, position: Vector3, area: Vector3, color: Color3?)
	local emitterPart = Decor.Part({
		Name = "Fireflies",
		Size = area,
		CFrame = CFrame.new(position),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	}, parent)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color or Color3.fromRGB(255, 240, 140))
	emitter.LightEmission = 1
	emitter.Rate = math.clamp(area.X * area.Z / 160, 2, 12) -- about the same density in every volume
	emitter.Lifetime = NumberRange.new(3, 6)
	emitter.Speed = NumberRange.new(0.3, 1)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.25),
		NumberSequenceKeypoint.new(0.8, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Parent = emitterPart
end

-- Square sections turned by 45 degrees read as facets in the low-poly style (no round parts).
local DIAMOND = CFrame.Angles(0, math.rad(45), 0)
local GEM = CFrame.Angles(0, math.rad(45), 0) * CFrame.Angles(math.rad(35.26), 0, 0) * CFrame.Angles(0, 0, math.rad(45))

-- Wooden torch with a faceted iron bowl, a fire and a warm light (2 parts). Non-collidable.
function Decor.Torch(parent: Instance, base: Vector3, height: number?)
	local h = height or 4
	Decor.Part({
		Name = "TorchStick",
		Size = Vector3.new(0.45, h, 0.45),
		CFrame = CFrame.new(base + Vector3.new(0, h / 2, 0)) * DIAMOND,
		Color = Color3.fromRGB(90, 60, 40),
		Material = Enum.Material.Wood,
		CanCollide = false,
	}, parent)
	local bowl = Decor.Part({
		Name = "TorchBowl",
		Size = Vector3.new(1.1, 0.6, 1.1),
		CFrame = CFrame.new(base + Vector3.new(0, h + 0.3, 0)) * DIAMOND,
		Color = Color3.fromRGB(60, 60, 70),
		Material = Enum.Material.Metal,
		CanCollide = false,
	}, parent)
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 6
	fire.Color = Color3.fromRGB(255, 140, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 90)
	fire.Parent = bowl
	Decor.Light(bowl, Color3.fromRGB(255, 170, 80), 16, 1.8)
end

-- Iron lantern post with a glowing gem (a cube standing on a corner) hanging from its arm (3 parts).
function Decor.Lantern(parent: Instance, base: Vector3, color: Color3)
	Decor.Part({
		Name = "LanternPost",
		Size = Vector3.new(0.45, 7, 0.45),
		CFrame = CFrame.new(base + Vector3.new(0, 3.5, 0)) * DIAMOND,
		Color = Color3.fromRGB(45, 40, 55),
		Material = Enum.Material.Metal,
	}, parent)
	Decor.Part({
		Name = "LanternArm",
		Size = Vector3.new(0.3, 0.3, 1.6),
		CFrame = CFrame.new(base + Vector3.new(0, 7, -0.6)),
		Color = Color3.fromRGB(45, 40, 55),
		Material = Enum.Material.Metal,
		CanCollide = false,
	}, parent)
	local glow = Decor.Part({
		Name = "LanternGlow",
		Size = Vector3.new(0.9, 0.9, 0.9),
		CFrame = CFrame.new(base + Vector3.new(0, 6.15, -1.2)) * GEM,
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
	}, parent)
	Decor.Light(glow, color, 18, 1.4)
end

-- Low-poly helpers ---------------------------------------------------------------------------

export type Rng = {
	NextNumber: (Rng, number, number) -> number,
	NextInteger: (Rng, number, number) -> number,
}

--[[
	Park-Miller generator. Used instead of Random so the map layout does not depend on the engine's
	generator: the offline map checks and every server see exactly the same scenery.
]]
function Decor.Rng(seed: number): Rng
	local state = math.floor(math.abs(seed) * 7919) % 2147483646 + 1
	local rng = {}
	function rng.NextNumber(_: Rng, low: number, high: number): number
		state = state * 16807 % 2147483647
		return low + (high - low) * (state - 1) / 2147483646
	end
	function rng.NextInteger(self: Rng, low: number, high: number): number
		return math.min(high, low + math.floor(self:NextNumber(0, 1) * (high - low + 1)))
	end
	return (rng :: any) :: Rng
end

-- LowPoly part properties. Only `solid` facets collide (with players: critters ignore Decor).
function Decor.Facets(name: string, color: Color3, material: Enum.Material?, solid: boolean?): LowPoly.PartProps
	return {
		Name = name,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		CanCollide = solid == true,
		CollisionGroup = "Decor",
	}
end

-- Drops the triangles lying entirely below `groundY` (buried faces of rocks, trunks...).
function Decor.AboveGround(triangles: { LowPoly.TriangleWithInside }, groundY: number): { LowPoly.TriangleWithInside }
	local kept = {}
	for _, triangle in triangles do
		if math.max(triangle.A.Y, triangle.B.Y, triangle.C.Y) > groundY then
			table.insert(kept, triangle)
		end
	end
	return kept
end

-- Outward unit normal of a triangle (or zero for a degenerate one).
function Decor.Normal(triangle: LowPoly.TriangleWithInside): Vector3
	local normal = (triangle.B - triangle.A):Cross(triangle.C - triangle.A)
	if normal.Magnitude < 1e-9 then
		return Vector3.zero
	end
	normal = normal.Unit
	local inside = triangle.Inside
	if inside and (triangle.A - inside):Dot(normal) < 0 then
		normal = -normal
	end
	return normal
end

--[[
	Draws triangles with a slightly different shade per facet (the hand-painted low-poly look).
	tint (optional) picks a colour per facet from its outward normal (moss on top of rocks, snow...).
]]
function Decor.DrawShaded(
	triangles: { LowPoly.TriangleWithInside },
	props: LowPoly.PartProps,
	parent: Instance,
	thickness: number,
	rng: Rng,
	amount: number,
	tint: ((normal: Vector3, triangle: LowPoly.TriangleWithInside) -> Color3?)?
): { BasePart }
	local parts = {}
	local base = props.Color
	for _, triangle in triangles do
		local color = base
		if tint then
			color = tint(Decor.Normal(triangle), triangle) or base
		end
		local shade = rng:NextNumber(-amount, amount)
		color = if shade >= 0 then color:Lerp(Color3.new(1, 1, 1), shade) else color:Lerp(Color3.new(0, 0, 0), -shade)
		local facetProps = table.clone(props)
		facetProps.Color = color
		for _, part in LowPoly.DrawTriangles({ triangle }, facetProps, parent, thickness) do
			table.insert(parts, part)
		end
	end
	return parts
end

-- Plate thickness for a low-poly shape whose smallest extent is `size` (same rule as LowPoly).
function Decor.Thickness(size: number): number
	return math.clamp(size * 0.08, 0.05, 1)
end

return Decor
