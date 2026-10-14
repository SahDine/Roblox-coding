--[[
	CritterBuilder
	Low-poly modelling toolkit used by CritterDesigns to build creatures out of
	blocks and wedges (no mesh assets needed). Every rounded shape becomes a
	faceted octagonal prism, ears / horns / flames / wings are triangles.

	Design space: 1 unit = 1 stud at scale 1, the ground is y = 0 and the
	critter looks towards -Z. Every position / size is multiplied by the
	rarity scale when the part is created.

	Colours can be a Color3 or a palette key:
	  "Body", "Accent", "Belly", "Extra"   -> colours of the critter (repainted by mutations)
	  anything in DEFAULT_COLORS           -> fixed colours (eyes, cheeks, flames...)

	Main primitives:
	  Gem / Ellipsoid   faceted octagonal prism (axis Z by default, opts.Axis = "X" | "Y" | "Z")
	  Box, Beam         cuboid, cuboid from point a to point b
	  Limb, Chain       diamond-section struts (legs, arms, tails, necks)
	  Spike             flat triangle from a base to a tip (ears, horns, spikes, wings, flames)
	  Wedge             raw WedgePart
	  Eyes, Cheeks, Mouth, FaceDot, Flame, Particles
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
	Orange = Color3.fromRGB(255, 150, 40),
	Ice = Color3.fromRGB(190, 235, 255),
}

local PAINTABLE = { Body = true, Accent = true, Belly = true, Extra = true }

-- Below this cross-section a gem is a single block (keeps the part count low).
local GEM_MIN_FACETED = 0.5

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
	Axis: string?,
	Roll: number?,
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

-- CFrame at `position` whose +Y axis points along `direction` and whose Z axis is as close as possible to `hint`.
local function pointing(position: Vector3, direction: Vector3, hint: Vector3?): CFrame
	local y = direction.Unit
	local z = hint or Vector3.new(0, 0, -1)
	z = z - y * z:Dot(y)
	if z.Magnitude < 1e-3 then
		z = Vector3.new(1, 0, 0) - y * y.X
		if z.Magnitude < 1e-3 then
			z = Vector3.new(0, 1, 0) - y * y.Y
		end
	end
	z = z.Unit
	local x = y:Cross(z)
	return CFrame.fromMatrix(position, x, y, z)
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
	part.Size = Vector3.new(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05)) * s
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

-- Octagonal prism along the local Z axis of `frame` (size X = width, Y = height, Z = length).
-- 7 parts: a core block, two narrower caps and four 45° wedges on the edges.
function CritterBuilder:_octagon(name: string, size: Vector3, frame: CFrame, color: any, opts: Options?): BasePart
	local w, h, d = size.X, size.Y, size.Z
	local small = math.min(w, h)
	if small < GEM_MIN_FACETED then
		return self:_part("Part", name, size, frame, color, opts)
	end
	local c = small * 0.29
	local core = self:_part("Part", name, Vector3.new(w, h - 2 * c, d), frame, color, opts)
	self:_part("Part", name .. "Top", Vector3.new(w - 2 * c, c, d), frame * CFrame.new(0, h / 2 - c / 2, 0), color, opts)
	self:_part("Part", name .. "Bottom", Vector3.new(w - 2 * c, c, d), frame * CFrame.new(0, -h / 2 + c / 2, 0), color, opts)
	-- Corner wedges: the top-right one is rotated -90° around Y so its slope faces up-right,
	-- the other corners are the same wedge turned around the prism axis.
	local corners = {
		{ 1, 1, 0 },
		{ -1, 1, 1 },
		{ -1, -1, 2 },
		{ 1, -1, 3 },
	}
	for _, corner in corners do
		self:_part(
			"WedgePart",
			name .. "Facet",
			Vector3.new(d, c, c),
			frame
				* CFrame.new(corner[1] * (w / 2 - c / 2), corner[2] * (h / 2 - c / 2), 0)
				* CFrame.Angles(0, 0, corner[3] * math.pi / 2)
				* CFrame.Angles(0, -math.pi / 2, 0),
			color,
			opts
		)
	end
	return core
end

-- Primitives ------------------------------------------------------------------------

-- Faceted rounded shape. Returns a handle usable by the face helpers (front face is flat at -Z).
function CritterBuilder:Gem(name: string, size: Vector3, position: Vector3, rot: Vector3?, color: any, opts: Options?): Handle
	local axis = opts and opts.Axis or "Z"
	local frame = CFrame.new(position) * rotation(rot)
	local part
	if axis == "Y" then
		part = self:_octagon(name, Vector3.new(size.X, size.Z, size.Y), frame * CFrame.Angles(math.rad(90), 0, 0), color, opts)
	elseif axis == "X" then
		part = self:_octagon(name, Vector3.new(size.Z, size.Y, size.X), frame * CFrame.Angles(0, math.rad(90), 0), color, opts)
	else
		part = self:_octagon(name, size, frame, color, opts)
	end
	return { Part = part, Center = position, Size = size }
end

-- Kept for older designs: same as Gem.
CritterBuilder.Ellipsoid = CritterBuilder.Gem

function CritterBuilder:Box(name: string, size: Vector3, position: Vector3, rot: Vector3?, color: any, opts: Options?): BasePart
	return self:_part("Part", name, size, CFrame.new(position) * rotation(rot), color, opts)
end

function CritterBuilder:Wedge(name: string, size: Vector3, position: Vector3, rot: Vector3?, color: any, opts: Options?): BasePart
	return self:_part("WedgePart", name, size, CFrame.new(position) * rotation(rot), color, opts)
end

-- Upright faceted cylinder (octagonal prism along Y before `rot`).
function CritterBuilder:Cylinder(name: string, height: number, diameter: number, position: Vector3, rot: Vector3?, color: any, opts: Options?): BasePart
	local frame = CFrame.new(position) * rotation(rot) * CFrame.Angles(math.rad(90), 0, 0)
	return self:_octagon(name, Vector3.new(diameter, diameter, height), frame, color, opts)
end

-- Strut from `a` to `b` (arms, legs, tails, necks). Round limbs get a diamond cross-section,
-- flat limbs (Vector2 thickness: width, depth) stay square so they read as fins / feathers.
function CritterBuilder:Limb(name: string, a: Vector3, b: Vector3, thickness: number | Vector2, color: any, opts: Options?): Handle
	local width, depth, roll
	if type(thickness) == "number" then
		width, depth, roll = thickness * 0.85, thickness * 0.85, 45
	else
		width, depth, roll = thickness.X, thickness.Y, 0
	end
	if opts and opts.Roll then
		roll = opts.Roll
	end
	local offset = b - a
	local length = offset.Magnitude + math.min(width, depth) * 0.5
	local center = (a + b) / 2
	local frame = facing(center, offset, opts and opts.Up) * CFrame.Angles(0, 0, math.rad(roll))
	local part = self:_part("Part", name, Vector3.new(width, depth, length), frame, color, opts)
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

-- Straight box from `a` to `b` (angular shapes: lightning tails, blades, planks).
function CritterBuilder:Beam(name: string, a: Vector3, b: Vector3, thickness: Vector2, color: any, opts: Options?): BasePart
	local offset = b - a
	return self:_part("Part", name, Vector3.new(thickness.X, thickness.Y, offset.Magnitude), facing((a + b) / 2, offset, opts and opts.Up), color, opts)
end

--[[
	Flat triangle (a "tent" of two wedges) whose base is centred on `base` and whose point is at `tip`.
	width: size of the base edge, depth: thickness of the triangle.
	facingHint: direction the flat side faces (default: towards the front, -Z).
	  Use Vector3.new(1, 0, 0) for spikes seen from the side (dorsal fins),
	  Vector3.new(0, 1, 0) for horizontal triangles (wings).
]]
function CritterBuilder:Spike(name: string, base: Vector3, tip: Vector3, width: number, depth: number, color: any, opts: Options?, facingHint: Vector3?)
	local offset = tip - base
	local height = offset.Magnitude
	local frame = pointing(base, offset, facingHint)
	local half = width / 2
	local wedgeTurn = CFrame.Angles(0, -math.pi / 2, 0)
	self:_part("WedgePart", name .. "R", Vector3.new(depth, height, half), frame * CFrame.new(half / 2, height / 2, 0) * wedgeTurn, color, opts)
	self:_part(
		"WedgePart",
		name .. "L",
		Vector3.new(depth, height, half),
		frame * CFrame.new(-half / 2, height / 2, 0) * CFrame.Angles(0, math.pi, 0) * wedgeTurn,
		color,
		opts
	)
end

-- Same shape on both sides (x is mirrored, as well as the Y and Z rotations).
local function flip(v: Vector3): Vector3
	return Vector3.new(-v.X, v.Y, v.Z)
end

function CritterBuilder:MirrorGem(name: string, size: Vector3, position: Vector3, rot: Vector3?, color: any, opts: Options?)
	local r = rot or Vector3.zero
	self:Gem(name .. "L", size, flip(position), Vector3.new(r.X, -r.Y, -r.Z), color, opts)
	self:Gem(name .. "R", size, position, r, color, opts)
end

CritterBuilder.MirrorEllipsoid = CritterBuilder.MirrorGem

function CritterBuilder:MirrorBox(name: string, size: Vector3, position: Vector3, rot: Vector3?, color: any, opts: Options?)
	local r = rot or Vector3.zero
	self:Box(name .. "L", size, flip(position), Vector3.new(r.X, -r.Y, -r.Z), color, opts)
	self:Box(name .. "R", size, position, r, color, opts)
end

function CritterBuilder:MirrorLimb(name: string, a: Vector3, b: Vector3, thickness: number | Vector2, color: any, opts: Options?)
	self:Limb(name .. "L", flip(a), flip(b), thickness, color, opts)
	self:Limb(name .. "R", a, b, thickness, color, opts)
end

function CritterBuilder:MirrorChain(name: string, points: { Vector3 }, fromThickness: number, toThickness: number, color: any, opts: Options?)
	local flipped = {}
	for index, point in points do
		flipped[index] = flip(point)
	end
	self:Chain(name .. "L", flipped, fromThickness, toThickness, color, opts)
	self:Chain(name .. "R", points, fromThickness, toThickness, color, opts)
end

function CritterBuilder:MirrorSpike(name: string, base: Vector3, tip: Vector3, width: number, depth: number, color: any, opts: Options?, facingHint: Vector3?)
	local hint = facingHint and flip(facingHint)
	self:Spike(name .. "L", flip(base), flip(tip), width, depth, color, opts, hint)
	self:Spike(name .. "R", base, tip, width, depth, color, opts, facingHint)
end

-- Face helpers --------------------------------------------------------------------------

-- CFrame on the flat front face of a gem, -Z pointing outwards.
-- x, y are offsets from the gem centre; `inset` pushes the result inside the surface.
function CritterBuilder:OnSurface(handle: Handle, x: number, y: number, inset: number?): CFrame
	local halfX, halfY = handle.Size.X / 2, handle.Size.Y / 2
	local px = math.clamp(x, -halfX * 0.92, halfX * 0.92)
	local py = math.clamp(y, -halfY * 0.92, halfY * 0.92)
	-- Points in the chamfered corners sit on the 45° facet, slightly further back.
	local c = math.min(handle.Size.X, handle.Size.Y) * 0.29
	local cornerX = math.max(0, math.abs(px) - (halfX - c))
	local cornerY = math.max(0, math.abs(py) - (halfY - c))
	local back = (cornerX + cornerY) * 0.5
	local position = handle.Center + Vector3.new(px, py, -handle.Size.Z / 2 + back + (inset or 0))
	return CFrame.new(position)
end

-- Eyes (flat low-poly blocks).
-- style: "Cute" (iris + pupil + shine), "Dazed" (white + dot), "Angry" (with brows),
--        "Sleepy" (closed lines), "Glow" (neon)
function CritterBuilder:Eyes(head: Handle, spacing: number, height: number, size: Vector3, irisColor: any, style: string?)
	local eyeStyle = style or "Cute"
	local depth = math.max(size.Z, 0.12)
	for _, side in { -1, 1 } do
		local suffix = if side < 0 then "L" else "R"
		local base = self:OnSurface(head, side * spacing, height, depth * 0.35)
		local function place(name: string, partSize: Vector3, x: number, y: number, z: number, color: any, opts: Options?)
			self:_part("Part", name .. suffix, partSize, base * CFrame.new(x, y, z), color, opts)
		end

		if eyeStyle == "Sleepy" then
			place("Eye", Vector3.new(size.X * 1.1, size.Y * 0.18, depth), 0, -size.Y * 0.1, 0, "Black")
		elseif eyeStyle == "Dazed" then
			place("Eye", Vector3.new(size.X, size.Y, depth), 0, 0, 0, "White")
			place("Pupil", Vector3.new(size.X * 0.24, size.X * 0.24, depth), side * -size.X * 0.05, 0, -depth * 0.3, "Black")
		elseif eyeStyle == "Glow" then
			place("Eye", Vector3.new(size.X, size.Y, depth), 0, 0, 0, irisColor, { Neon = true })
		else
			place("Eye", Vector3.new(size.X, size.Y, depth), 0, 0, 0, irisColor)
			if irisColor ~= "Black" then
				place("Pupil", Vector3.new(size.X * 0.5, size.Y * 0.55, depth), 0, -size.Y * 0.05, -depth * 0.25, "Black")
			end
			place("Shine", Vector3.new(size.X * 0.34, size.X * 0.34, depth), side * -size.X * 0.15, size.Y * 0.2, -depth * 0.4, "White")
			if eyeStyle == "Angry" then
				self:_part(
					"Part",
					"Brow" .. suffix,
					Vector3.new(size.X * 1.3, size.Y * 0.18, depth),
					base * CFrame.new(side * size.X * 0.05, size.Y * 0.65, -depth * 0.2) * CFrame.Angles(0, 0, math.rad(side * -22)),
					"Black"
				)
			end
		end
	end
end

-- Small flat block pinned on the face (cheeks, nose, mouth, gems...).
function CritterBuilder:FaceDot(name: string, head: Handle, x: number, y: number, size: Vector3, color: any, opts: Options?): BasePart
	local cframe = self:OnSurface(head, x, y, size.Z * 0.3)
	return self:_part("Part", name, size, cframe, color, opts)
end

function CritterBuilder:Cheeks(head: Handle, spacing: number, height: number, size: number, color: any?)
	for _, side in { -1, 1 } do
		self:FaceDot("Cheek" .. side, head, side * spacing, height, Vector3.new(size, size * 0.8, 0.12), color or "Cheek")
	end
end

-- Open or closed mouth.
function CritterBuilder:Mouth(head: Handle, height: number, width: number, open: boolean?)
	if open then
		self:FaceDot("Mouth", head, 0, height, Vector3.new(width, width * 0.5, 0.14), "Mouth")
		self:FaceDot("Tongue", head, 0, height - width * 0.12, Vector3.new(width * 0.55, width * 0.22, 0.16), "Tongue")
	else
		self:FaceDot("Mouth", head, 0, height, Vector3.new(width, width * 0.16, 0.14), "Mouth")
	end
end

-- Effects ---------------------------------------------------------------------------------

-- Low-poly flame: two crossed neon triangles + a Roblox Fire for animation.
function CritterBuilder:Flame(name: string, position: Vector3, size: number)
	local tip = position + Vector3.new(0, size * 1.6, 0)
	self:Spike(name .. "A", position, tip, size, size * 0.15, "Flame", { Neon = true })
	self:Spike(name .. "B", position, tip, size, size * 0.15, "Flame", { Neon = true }, Vector3.new(1, 0, 0))
	local core = self:_part("Part", name .. "Core", Vector3.new(size * 0.45, size * 0.45, size * 0.45), CFrame.new(position + Vector3.new(0, size * 0.35, 0)) * CFrame.Angles(0, math.rad(45), math.rad(45)), "FlameCore", { Neon = true })
	local fire = Instance.new("Fire")
	fire.Size = math.max(2, size * self.Scale * 2)
	fire.Heat = 4
	fire.Color = DEFAULT_COLORS.Flame
	fire.SecondaryColor = DEFAULT_COLORS.FlameCore
	fire.Parent = core
	local light = Instance.new("PointLight")
	light.Color = DEFAULT_COLORS.Flame
	light.Range = 8
	light.Brightness = 1.5
	light.Parent = core
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
	model:SetAttribute("PartCount", #self.Parts)
	return model
end

return CritterBuilder
