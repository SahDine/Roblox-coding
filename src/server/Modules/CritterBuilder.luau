--[[
	CritterBuilder
	Small modelling toolkit used by CritterDesigns to sculpt creatures out of
	primitives (no mesh assets needed).

	Design space: 1 unit = 1 stud at scale 1, the ground is y = 0 and the
	critter looks towards -Z. Every position / size is multiplied by the
	rarity scale when the part is created.

	Colours can be a Color3 or a palette key:
	  "Body", "Accent", "Belly", "Extra"   -> colours of the critter (repainted by mutations)
	  anything in DEFAULT_COLORS           -> fixed colours (eyes, cheeks, flames...)
]]

local CritterBuilder = {}
CritterBuilder.__index = CritterBuilder

local DEFAULT_COLORS = {
	White = Color3.fromRGB(250, 250, 252),
	Black = Color3.fromRGB(28, 26, 34),
	Dark = Color3.fromRGB(55, 50, 62),
	Grey = Color3.fromRGB(150, 150, 160),
	Cream = Color3.fromRGB(250, 235, 200),
	Cheek = Color3.fromRGB(240, 70, 70),
	Blush = Color3.fromRGB(255, 140, 170),
	Mouth = Color3.fromRGB(120, 35, 50),
	Tongue = Color3.fromRGB(255, 120, 140),
	Gold = Color3.fromRGB(255, 200, 50),
	Flame = Color3.fromRGB(255, 120, 30),
	FlameCore = Color3.fromRGB(255, 235, 100),
	Red = Color3.fromRGB(215, 45, 55),
	Yellow = Color3.fromRGB(255, 215, 60),
	Blue = Color3.fromRGB(70, 140, 230),
	Green = Color3.fromRGB(80, 200, 120),
	Purple = Color3.fromRGB(150, 80, 220),
}

local PAINTABLE = { Body = true, Accent = true, Belly = true, Extra = true }

export type Handle = {
	Part: BasePart,
	Center: Vector3,
	Size: Vector3,
}

export type Options = {
	Material: Enum.Material?,
	Transparency: number?,
	Neon: boolean?,
	Paint: boolean?,
	Shadow: boolean?,
	Up: Vector3?,
}

local function rotation(degrees: Vector3?): CFrame
	if not degrees then
		return CFrame.new()
	end
	return CFrame.Angles(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
end

-- CFrame at `position` whose -Z axis points along `direction`.
local function facing(position: Vector3, direction: Vector3, up: Vector3?): CFrame
	local unit = direction.Unit
	local hint = up or Vector3.new(0, 1, 0)
	if math.abs(unit:Dot(hint.Unit)) > 0.98 then
		hint = if math.abs(unit.Z) < 0.9 then Vector3.new(0, 0, -1) else Vector3.new(1, 0, 0)
	end
	return CFrame.lookAt(position, position + unit, hint)
end

function CritterBuilder.new(name: string, scale: number, palette: { [string]: Color3 })
	local self = setmetatable({}, CritterBuilder)
	self.Name = name
	self.Scale = scale
	self.Palette = palette
	self.Model = Instance.new("Model")
	self.Model.Name = name
	self.Parts = {} :: { BasePart }
	self.Core = nil :: BasePart?
	self.Hover = 0 -- design units the whole critter floats above the ground
	return self
end

function CritterBuilder:ResolveColor(color: any): (Color3, boolean)
	if type(color) == "string" then
		local fromPalette = self.Palette[color]
		if fromPalette then
			return fromPalette, PAINTABLE[color] == true
		end
		local fixed = DEFAULT_COLORS[color]
		assert(fixed, "Unknown critter colour: " .. color)
		return fixed, false
	end
	return color, false
end

-- Creates a part from a design-space CFrame.
function CritterBuilder:_part(className: string, name: string, size: Vector3, cframe: CFrame, color: any, opts: Options?): BasePart
	local options = opts or {}
	local s = self.Scale
	local resolved, paintable = self:ResolveColor(color)

	local part = Instance.new(className) :: BasePart
	part.Name = name
	part.Size = size * s
	part.CFrame = CFrame.new((cframe.Position + Vector3.new(0, self.Hover, 0)) * s) * cframe.Rotation
	part.Color = resolved
	part.Material = if options.Neon then Enum.Material.Neon else options.Material or Enum.Material.SmoothPlastic
	part.Transparency = options.Transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = options.Shadow ~= false and not options.Neon
	if paintable and options.Paint ~= false then
		part:SetAttribute("Paint", true)
	end
	part.Parent = self.Model
	table.insert(self.Parts, part)
	return part
end

-- Primitives ------------------------------------------------------------------------

-- Ellipsoid (the main sculpting brick). Returns a handle usable by Face helpers.
function CritterBuilder:Ellipsoid(name: string, size: Vector3, position: Vector3, rot: Vector3?, color: any, opts: Options?): Handle
	local part = self:_part("Part", name, size, CFrame.new(position) * rotation(rot), color, opts)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return { Part = part, Center = position, Size = size }
end

function CritterBuilder:Box(name: string, size: Vector3, position: Vector3, rot: Vector3?, color: any, opts: Options?): BasePart
	return self:_part("Part", name, size, CFrame.new(position) * rotation(rot), color, opts)
end

function CritterBuilder:Wedge(name: string, size: Vector3, position: Vector3, rot: Vector3?, color: any, opts: Options?): BasePart
	return self:_part("WedgePart", name, size, CFrame.new(position) * rotation(rot), color, opts)
end

-- Upright cylinder (axis = Y before `rot`).
function CritterBuilder:Cylinder(name: string, height: number, diameter: number, position: Vector3, rot: Vector3?, color: any, opts: Options?): BasePart
	local part = self:_part(
		"Part",
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(position) * rotation(rot) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		opts
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- Rounded segment from `a` to `b` (arms, legs, tails, ears, necks...).
-- thickness: number (round) or Vector2 (width, depth) for flat shapes like ears or fins.
function CritterBuilder:Limb(name: string, a: Vector3, b: Vector3, thickness: number | Vector2, color: any, opts: Options?): Handle
	local width, depth
	if type(thickness) == "number" then
		width, depth = thickness, thickness
	else
		width, depth = thickness.X, thickness.Y
	end
	local offset = b - a
	local length = offset.Magnitude + math.min(width, depth) * 0.6
	local center = (a + b) / 2
	local part = self:_part("Part", name, Vector3.new(width, depth, length), facing(center, offset, opts and opts.Up), color, opts)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return { Part = part, Center = center, Size = Vector3.new(width, depth, length) }
end

-- Chain of limbs through several points, thickness interpolated from first to last.
function CritterBuilder:Chain(name: string, points: { Vector3 }, fromThickness: number, toThickness: number, color: any, opts: Options?)
	local count = #points - 1
	for index = 1, count do
		local alpha = if count > 1 then (index - 1) / (count - 1) else 0
		local thickness = fromThickness + (toThickness - fromThickness) * alpha
		self:Limb(name .. index, points[index], points[index + 1], thickness, color, opts)
	end
end

-- Straight box from `a` to `b` (angular shapes: lightning tails, blades).
function CritterBuilder:Beam(name: string, a: Vector3, b: Vector3, thickness: Vector2, color: any, opts: Options?): BasePart
	local offset = b - a
	return self:_part("Part", name, Vector3.new(thickness.X, thickness.Y, offset.Magnitude), facing((a + b) / 2, offset, opts and opts.Up), color, opts)
end

-- Same shape on both sides (x is mirrored, as well as the Y and Z rotations).
function CritterBuilder:MirrorEllipsoid(name: string, size: Vector3, position: Vector3, rot: Vector3?, color: any, opts: Options?)
	local r = rot or Vector3.zero
	self:Ellipsoid(name .. "L", size, Vector3.new(-position.X, position.Y, position.Z), Vector3.new(r.X, -r.Y, -r.Z), color, opts)
	self:Ellipsoid(name .. "R", size, position, r, color, opts)
end

function CritterBuilder:MirrorLimb(name: string, a: Vector3, b: Vector3, thickness: number | Vector2, color: any, opts: Options?)
	local function flip(v: Vector3)
		return Vector3.new(-v.X, v.Y, v.Z)
	end
	self:Limb(name .. "L", flip(a), flip(b), thickness, color, opts)
	self:Limb(name .. "R", a, b, thickness, color, opts)
end

function CritterBuilder:MirrorChain(name: string, points: { Vector3 }, fromThickness: number, toThickness: number, color: any, opts: Options?)
	local flipped = {}
	for index, point in points do
		flipped[index] = Vector3.new(-point.X, point.Y, point.Z)
	end
	self:Chain(name .. "L", flipped, fromThickness, toThickness, color, opts)
	self:Chain(name .. "R", points, fromThickness, toThickness, color, opts)
end

-- Face helpers --------------------------------------------------------------------------

-- CFrame on the front surface of an (unrotated) ellipsoid, -Z pointing outwards.
-- x, y are offsets from the ellipsoid centre; `inset` pushes the result inside the surface.
function CritterBuilder:OnSurface(handle: Handle, x: number, y: number, inset: number?): CFrame
	local a, b, c = handle.Size.X / 2, handle.Size.Y / 2, handle.Size.Z / 2
	local nx, ny = math.clamp(x / a, -0.95, 0.95), math.clamp(y / b, -0.95, 0.95)
	local z = -c * math.sqrt(math.max(0.02, 1 - nx * nx - ny * ny))
	local localPoint = Vector3.new(x, y, z)
	local normal = Vector3.new(x / (a * a), y / (b * b), z / (c * c)).Unit
	local position = handle.Center + localPoint - normal * (inset or 0)
	return facing(position, normal)
end

local function at(cframe: CFrame, x: number, y: number, z: number): (Vector3, Vector3)
	-- Returns a position relative to `cframe` and its outward direction.
	return (cframe * CFrame.new(x, y, z)).Position, -cframe.ZVector
end

-- Eyes.
-- style: "Cute" (iris + pupil + shines), "Dazed" (white + dot), "Angry" (with brows),
--        "Sleepy" (closed lines), "Glow" (neon, no pupil)
function CritterBuilder:Eyes(head: Handle, spacing: number, height: number, size: Vector3, irisColor: any, style: string?)
	local eyeStyle = style or "Cute"
	for _, side in { -1, 1 } do
		local suffix = if side < 0 then "L" else "R"
		local base = self:OnSurface(head, side * spacing, height, size.Z * 0.25)
		local function place(name: string, partSize: Vector3, x: number, y: number, z: number, color: any, opts: Options?)
			local position, direction = at(base, x, y, z)
			self:_part("Part", name .. suffix, partSize, facing(position, direction), color, opts)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = self.Parts[#self.Parts]
		end

		if eyeStyle == "Sleepy" then
			place("Eye", Vector3.new(size.X * 1.1, size.Y * 0.16, size.Z), 0, -size.Y * 0.1, 0, "Black")
		elseif eyeStyle == "Dazed" then
			place("Eye", size, 0, 0, 0, "White")
			place("Pupil", Vector3.new(size.X * 0.22, size.X * 0.22, size.Z * 0.5), side * -size.X * 0.05, 0, -size.Z * 0.35, "Black")
		elseif eyeStyle == "Glow" then
			place("Eye", size, 0, 0, 0, irisColor, { Neon = true })
		else
			place("Eye", size, 0, 0, 0, irisColor)
			if irisColor ~= "Black" then
				place("Pupil", Vector3.new(size.X * 0.5, size.Y * 0.55, size.Z * 0.6), 0, -size.Y * 0.04, -size.Z * 0.25, "Black")
			end
			place("Shine", Vector3.new(size.X * 0.36, size.X * 0.36, size.Z * 0.4), side * -size.X * 0.12, size.Y * 0.2, -size.Z * 0.42, "White")
			place("Shine2", Vector3.new(size.X * 0.16, size.X * 0.16, size.Z * 0.3), side * size.X * 0.14, -size.Y * 0.2, -size.Z * 0.42, "White")
			if eyeStyle == "Angry" then
				local browPosition, _ = at(base, side * size.X * 0.05, size.Y * 0.62, -size.Z * 0.2)
				self:_part(
					"Part",
					"Brow" .. suffix,
					Vector3.new(size.X * 1.25, size.Y * 0.16, size.Z * 0.5),
					CFrame.new(browPosition) * base.Rotation * CFrame.Angles(0, 0, math.rad(side * -22)),
					"Black"
				)
			end
		end
	end
end

-- Small ellipsoid pinned on the face (cheeks, nose, mouth, gems...).
function CritterBuilder:FaceDot(name: string, head: Handle, x: number, y: number, size: Vector3, color: any, opts: Options?): BasePart
	local cframe = self:OnSurface(head, x, y, size.Z * 0.3)
	local part = self:_part("Part", name, size, cframe, color, opts)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

function CritterBuilder:Cheeks(head: Handle, spacing: number, height: number, size: number, color: any?)
	for _, side in { -1, 1 } do
		self:FaceDot("Cheek" .. side, head, side * spacing, height, Vector3.new(size, size * 0.85, size * 0.35), color or "Cheek")
	end
end

-- Cute open smile.
function CritterBuilder:Mouth(head: Handle, height: number, width: number, open: boolean?)
	if open then
		self:FaceDot("Mouth", head, 0, height, Vector3.new(width, width * 0.6, width * 0.3), "Mouth")
		self:FaceDot("Tongue", head, 0, height - width * 0.12, Vector3.new(width * 0.6, width * 0.3, width * 0.3), "Tongue")
	else
		self:FaceDot("Mouth", head, 0, height, Vector3.new(width, width * 0.22, width * 0.25), "Mouth")
	end
end

-- Effects ---------------------------------------------------------------------------------

function CritterBuilder:Flame(name: string, position: Vector3, size: number)
	self:Ellipsoid(name .. "Outer", Vector3.new(size, size * 1.3, size), position + Vector3.new(0, size * 0.3, 0), nil, "Flame", { Neon = true, Transparency = 0.15 })
	self:Limb(name .. "Tip", position + Vector3.new(0, size * 0.6, 0), position + Vector3.new(0, size * 1.45, size * 0.1), size * 0.5, "Flame", { Neon = true, Transparency = 0.2 })
	local core = self:Ellipsoid(name .. "Core", Vector3.new(size * 0.55, size * 0.9, size * 0.55), position + Vector3.new(0, size * 0.2, 0), nil, "FlameCore", { Neon = true })
	local fire = Instance.new("Fire")
	fire.Size = math.max(2, size * self.Scale * 2)
	fire.Heat = 4
	fire.Color = DEFAULT_COLORS.Flame
	fire.SecondaryColor = DEFAULT_COLORS.FlameCore
	fire.Parent = core.Part
	local light = Instance.new("PointLight")
	light.Color = DEFAULT_COLORS.Flame
	light.Range = 8
	light.Brightness = 1.5
	light.Parent = core.Part
end

function CritterBuilder:Particles(part: BasePart, color: Color3, rate: number, size: number?)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(size or 0.3, 0)
	emitter.Parent = part
end

function CritterBuilder:SetCore(handle: Handle)
	self.Core = handle.Part
end

-- Finalise ------------------------------------------------------------------------------

-- Adds the invisible root + Humanoid, welds every part to the core and returns the model.
-- Model attributes: StandOffset (root height above ground), Scale, Height (top of the critter).
function CritterBuilder:Finish(): Model
	local s = self.Scale
	local model = self.Model
	local core = self.Core or self.Parts[1]
	assert(core, "A critter needs at least one part")

	local standOffset = 1.5 * s
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 2) * s
	root.CFrame = CFrame.new(0, standOffset, 0)
	root.Transparency = 1
	root.CanCollide = true
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.Parent = model
	model.PrimaryPart = root

	local bounce = Instance.new("Motor6D")
	bounce.Name = "Bounce"
	bounce.Part0 = root
	bounce.Part1 = core
	bounce.C0 = root.CFrame:ToObjectSpace(core.CFrame)
	bounce.Parent = root

	local top = 0
	for _, part in self.Parts do
		if part ~= core then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = core
			weld.Part1 = part
			weld.Parent = part
		end
		local size = part.Size
		top = math.max(top, part.Position.Y + math.max(size.X, size.Y, size.Z) * 0.45)
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = standOffset - root.Size.Y / 2
	humanoid.Parent = model

	model:SetAttribute("StandOffset", standOffset)
	model:SetAttribute("Scale", s)
	model:SetAttribute("Height", top)
	model:SetAttribute("Floats", self.Hover > 0)
	return model
end

return CritterBuilder
