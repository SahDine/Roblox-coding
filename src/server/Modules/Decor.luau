--[[
	Decor
	Fantasy props built from parts: giant mushrooms, glowing crystals, magic
	trees, floating islands, torches, lanterns and fireflies.

	Every prop is anchored and in the "Decor" collision group: players bump
	into trunks and stems, critters walk through everything.
]]

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

function Decor.Ellipsoid(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance, props: Props?): BasePart
	local options = props or {}
	options.Name = name
	options.Size = size
	options.CFrame = cframe
	options.Color = color
	local part = Decor.Part(options, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Upright cylinder whose base sits at `base`.
function Decor.Column(name: string, height: number, diameter: number, base: Vector3, color: Color3, parent: Instance, props: Props?): BasePart
	local options = props or {}
	options.Name = name
	options.Shape = Enum.PartType.Cylinder
	options.Size = Vector3.new(height, diameter, diameter)
	options.CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	options.Color = color
	return Decor.Part(options, parent)
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
	emitter.Rate = 6
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

function Decor.Torch(parent: Instance, base: Vector3, height: number?)
	local h = height or 4
	Decor.Column("TorchStick", h, 0.5, base, Color3.fromRGB(90, 60, 40), parent, { Material = Enum.Material.Wood, CanCollide = false })
	local bowl = Decor.Column("TorchBowl", 0.6, 1.2, base + Vector3.new(0, h, 0), Color3.fromRGB(60, 60, 70), parent, {
		Material = Enum.Material.Metal,
		CanCollide = false,
	})
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 6
	fire.Color = Color3.fromRGB(255, 140, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 90)
	fire.Parent = bowl
	Decor.Light(bowl, Color3.fromRGB(255, 170, 80), 16, 1.8)
end

function Decor.Lantern(parent: Instance, base: Vector3, color: Color3)
	Decor.Column("LanternPost", 7, 0.5, base, Color3.fromRGB(45, 40, 55), parent, { Material = Enum.Material.Metal })
	Decor.Part({
		Name = "LanternArm",
		Size = Vector3.new(0.3, 0.3, 1.6),
		CFrame = CFrame.new(base + Vector3.new(0, 7, -0.6)),
		Color = Color3.fromRGB(45, 40, 55),
		Material = Enum.Material.Metal,
		CanCollide = false,
	}, parent)
	local glow = Decor.Ellipsoid("LanternGlow", Vector3.new(1.2, 1.5, 1.2), CFrame.new(base + Vector3.new(0, 6.3, -1.2)), color, parent, {
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
	})
	Decor.Light(glow, color, 18, 1.4)
end

function Decor.Mushroom(parent: Instance, base: Vector3, scale: number, capColor: Color3)
	local s = scale
	local stemHeight = 7 * s
	Decor.Column("Stem", stemHeight, 2.2 * s, base, Color3.fromRGB(245, 235, 215), parent)
	local capCenter = base + Vector3.new(0, stemHeight + 0.6 * s, 0)
	Decor.Ellipsoid("Cap", Vector3.new(9, 4.5, 9) * s, CFrame.new(capCenter), capColor, parent, { CanCollide = false })
	local gills = Decor.Column("Gills", 0.4 * s, 7.5 * s, capCenter - Vector3.new(0, 0.6 * s, 0), capColor:Lerp(Color3.new(1, 1, 1), 0.5), parent, {
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
	})
	Decor.Light(gills, capColor:Lerp(Color3.new(1, 1, 1), 0.3), 14 * s, 1.2)
	for index = 1, 6 do
		local angle = index * 1.05 + s
		local radius = (if index % 2 == 0 then 2.6 else 1.4) * s
		local spot = capCenter + Vector3.new(math.cos(angle) * radius, 1.6 * s - radius * 0.25, math.sin(angle) * radius)
		Decor.Ellipsoid("Spot", Vector3.new(1.1, 0.5, 1.1) * s, CFrame.new(spot), Color3.fromRGB(255, 250, 240), parent, { CanCollide = false })
	end
end

function Decor.Crystal(parent: Instance, base: Vector3, scale: number, color: Color3)
	local seeds = { { 0, 0, 0, 1 }, { 1.4, 0.4, 20, 0.65 }, { -1.2, -0.6, -25, 0.7 }, { 0.3, -1.3, 10, 0.5 } }
	for index, seed in seeds do
		local height = 8 * scale * seed[4]
		local offset = Vector3.new(seed[1], 0, seed[2]) * scale
		local cframe = CFrame.new(base + offset)
			* CFrame.Angles(math.rad(seed[3]), math.rad(index * 37), math.rad(-seed[3] * 0.6))
			* CFrame.new(0, height / 2, 0)
		local shard = Decor.Part({
			Name = "Crystal",
			Size = Vector3.new(1.6, height, 1.6) * Vector3.new(scale * seed[4] + 0.4, 1, scale * seed[4] + 0.4),
			CFrame = cframe * CFrame.Angles(0, math.rad(45), 0),
			Color = color,
			Material = Enum.Material.Glass,
			Transparency = 0.15,
			Reflectance = 0.2,
		}, parent)
		local core = Decor.Part({
			Name = "CrystalCore",
			Size = shard.Size * Vector3.new(0.45, 0.8, 0.45),
			CFrame = shard.CFrame,
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
		}, parent)
		if index == 1 then
			Decor.Light(core, color, 16 * scale, 1.5)
		end
	end
end

local LEAF_COLORS = {
	Color3.fromRGB(255, 160, 205),
	Color3.fromRGB(170, 120, 255),
	Color3.fromRGB(90, 210, 190),
	Color3.fromRGB(255, 205, 90),
	Color3.fromRGB(110, 190, 90),
}

function Decor.Tree(parent: Instance, base: Vector3, scale: number, variant: number)
	local s = scale
	local leaf = LEAF_COLORS[(variant - 1) % #LEAF_COLORS + 1]
	local bark = Color3.fromRGB(105, 75, 60)
	-- Twisted trunk made of three tilted segments.
	local point = base
	for index = 1, 3 do
		local lean = Vector3.new(math.sin(variant + index) * 1.2, 4.5, math.cos(variant * 2 + index) * 1.2) * s
		local nextPoint = point + lean
		local mid = (point + nextPoint) / 2
		Decor.Part({
			Name = "Trunk",
			Size = Vector3.new((2.4 - index * 0.45) * s, lean.Magnitude + 0.6 * s, (2.4 - index * 0.45) * s),
			CFrame = CFrame.lookAt(mid, nextPoint) * CFrame.Angles(math.rad(90), 0, 0),
			Color = bark,
			Material = Enum.Material.Wood,
			CanCollide = index == 1,
		}, parent)
		point = nextPoint
	end
	for index, offset in { Vector3.new(0, 1.5, 0), Vector3.new(3, 0, 1), Vector3.new(-2.5, 0.3, -1.5), Vector3.new(0.5, -0.5, 3), Vector3.new(-1, 3.2, 0.5) } do
		local size = (if index == 1 then 8 else 5.5) * s
		Decor.Ellipsoid("Leaves", Vector3.new(size, size * 0.8, size), CFrame.new(point + offset * s), leaf, parent, {
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
	end
	-- Glowing fruits.
	for index = 1, 3 do
		local angle = variant + index * 2.1
		local fruit = Decor.Ellipsoid(
			"Fruit",
			Vector3.new(0.9, 0.9, 0.9) * s,
			CFrame.new(point + Vector3.new(math.cos(angle) * 3.6, -2.2, math.sin(angle) * 3.6) * s),
			leaf:Lerp(Color3.new(1, 1, 1), 0.5),
			parent,
			{ Material = Enum.Material.Neon, CanCollide = false, CastShadow = false }
		)
		if index == 1 then
			Decor.Light(fruit, leaf, 10 * s, 1)
		end
	end
end

function Decor.FloatingIsland(parent: Instance, center: Vector3, scale: number, variant: number)
	local s = scale
	local rock = Color3.fromRGB(120, 110, 125)
	Decor.Ellipsoid("IslandTop", Vector3.new(30, 6, 26) * s, CFrame.new(center), Color3.fromRGB(100, 185, 95), parent, {
		Material = Enum.Material.Grass,
	})
	Decor.Ellipsoid("IslandRock", Vector3.new(26, 18, 22) * s, CFrame.new(center - Vector3.new(0, 7, 0) * s), rock, parent, {
		Material = Enum.Material.Slate,
	})
	Decor.Ellipsoid("IslandTip", Vector3.new(12, 16, 10) * s, CFrame.new(center - Vector3.new(1, 17, 0) * s), rock, parent, {
		Material = Enum.Material.Slate,
	})
	Decor.Tree(parent, center + Vector3.new(-5, 2, 2) * s, 0.9 * s, variant)
	Decor.Crystal(parent, center + Vector3.new(7, 2, -4) * s, 0.8 * s, Color3.fromRGB(120, 220, 255))
	-- Waterfall pouring off the edge.
	Decor.Part({
		Name = "Waterfall",
		Size = Vector3.new(4, 40, 0.6) * s,
		CFrame = CFrame.new(center + Vector3.new(0, -18, 12) * s),
		Color = Color3.fromRGB(150, 210, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.35,
		CanCollide = false,
		CastShadow = false,
	}, parent)
end

function Decor.Flowers(parent: Instance, center: Vector3, radius: number, count: number, seed: number)
	local random = Random.new(seed)
	for _ = 1, count do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(0, radius)
		local position = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local color = LEAF_COLORS[random:NextInteger(1, #LEAF_COLORS)]
		Decor.Part({
			Name = "FlowerStem",
			Size = Vector3.new(0.2, 1.2, 0.2),
			CFrame = CFrame.new(position + Vector3.new(0, 0.6, 0)),
			Color = Color3.fromRGB(70, 150, 70),
			CanCollide = false,
			CastShadow = false,
		}, parent)
		Decor.Ellipsoid("Flower", Vector3.new(0.9, 0.4, 0.9), CFrame.new(position + Vector3.new(0, 1.3, 0)), color, parent, {
			CanCollide = false,
			CastShadow = false,
		})
	end
end

return Decor
