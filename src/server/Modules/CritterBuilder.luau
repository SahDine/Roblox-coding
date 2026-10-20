--[[
	CritterBuilder
	Modelling toolkit used by CritterDesigns. Critters are LOW POLY MADE OF TRIANGLES:
	every surface is a set of flat-shaded triangles (drawn with thin WedgeParts by
	LowPoly), never a flat box face. Only the eyes and the mouth are round.
	Critters are rigged with bones so the client can animate them (walk / idle).

	Design space: 1 unit = 1 stud at scale 1, the ground is y = 0, the critter
	looks towards -Z, +X is its right side. Positions / sizes are multiplied by
	the rarity scale when parts are created.

	Colours: a Color3, a palette key ("Body", "Accent", "Belly", "Extra": recoloured
	by mutations) or a fixed colour name from DEFAULT_COLORS.

	Shapes (all return a handle { Part, Center, Size, Tris } usable by the face helpers):
	  Ball(name, size, pos, rot?, color, opts?)       low-poly ellipsoid. opts.Detail: 2 = icosahedron (20 facets,
	                                                  40 parts), 1 = 16 facets (32 parts), 0 = octahedron (8 facets,
	                                                  16 parts). Default from the smallest size: >= 1 -> 2, >= 0.45 -> 1
	  Gem / Ellipsoid                                 same as Ball (older designs)
	  Limb(name, a, b, thickness, color, opts?)       faceted spindle from a to b, widest at 45 % (legs, arms):
	                                                  6 facets / 12 parts; hide its pointed ends in the body / foot.
	                                                  opts.Sides (3), opts.RingAt (0.45); Vector2 thickness (width,
	                                                  depth) gives a flat strut (fins)
	  Chain(name, points, fromThickness, toThickness, color, opts?)
	                                                  one continuous faceted tube through the points (tails,
	                                                  necks, serpents); toThickness = 0 ends in a point
	  Tube(name, points, radii, color, opts?)         same with one radius per point (LowPoly.TubeOptions)
	  Cone(name, base, tip, radius, color, opts?)     pyramid (horns, beaks, claws), opts.Sides (default 4)
	  Spike(name, base, tip, width, depth, color, opts?, facingHint?)
	                                                  triangle from a base to a tip: a 3-sided pyramid, or a
	                                                  flat triangle when depth < 0.3 * width (ears, fins, flames)
	  Blade(name, base, tip, width, color, opts?, facingHint?)   flat isosceles triangle (wings, feathers, leaves)
	  Tri(name, a, b, c, color, opts?)                flat triangle through 3 points (custom membranes)
	  Mesh(name, vertices, faces, color, opts?)       custom convex mesh (faces = vertex index triples)
	  Cylinder(name, height, diameter, pos, rot?, color, opts?)  faceted 6-sided column with low pointed caps
	  Beam(name, a, b, Vector2(width, depth), color, opts?)  flat angular spindle (lightning tails, blades): 16 parts
	  Box / Wedge                                     kept for older designs: faceted (every face is a shallow
	                                                  pyramid), costly (48 / 28 parts), prefer the shapes above
	  Mirror<Shape>(...)                              same shape on both sides: give the +X (right) side

	Face (on any shape, placed by casting a ray from the front onto its facets):
	  Eyes(head, spacing, height, Vector3(w, h, depth), irisColor, style?)   ROUND eyes
	       styles "Cute", "Angry", "Sleepy", "Dazed", "Glow"
	  Mouth(head, height, width, open?)               ROUND mouth
	  FaceDot(name, head, x, y, size, color, opts?)   small faceted stud (nose, spots, gems)
	  Cheeks(head, spacing, height, size, color?)
	  OnSurface(head, x, y) -> CFrame on the surface, -Z = outwards

	Rig (animation):
	  Bone(name, pivot, opts?, build)                 parts created inside build() move with this bone,
	                                                  rotating around `pivot`. opts: { Role, Phase, Amp }
	                                                  Role: "Leg" "Arm" "Head" "Tail" "Wing" "Ear" "Fin" "Jaw"
	                                                  "Float" "Spin" "Static" (default: from the name prefix)
	  MirrorBone(name, pivot, opts?, build(side))     the same bone on both sides: build() is called twice and
	                                                  everything inside is mirrored automatically for the left
	                                                  side (do not use Mirror<Shape> inside it). Legs / arms
	                                                  get opposite walk phases.
	  Bones can be nested (ears inside the head bone). Parts outside any bone belong to the body.

	Misc: Flame(name, pos, size), Particles(handleOrPart, color, rate, size?), SetCore(handle),
	b.Hover = n (flying critters float n units above the ground).
]]

local LowPoly = require(script.Parent.LowPoly)

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

local ROLES = { "Leg", "Arm", "Head", "Tail", "Wing", "Ear", "Fin", "Jaw", "Float", "Spin", "Static" }
-- Walk phase offset of the left copy made by MirrorBone.
local MIRROR_PHASE = { Leg = 0.5, Arm = 0.5 }

export type Handle = {
	Part: BasePart?,
	Center: Vector3,
	Size: Vector3,
	Tris: { LowPoly.TriangleWithInside },
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
	Detail: number?,
	Sides: number?,
	Thickness: number?,
	Closed: boolean?,
	CapStart: number?,
	CapEnd: number?,
	Flatten: number?,
	Twist: number?,
	RingAt: number?,
}

export type BoneOptions = {
	Role: string?,
	Phase: number?,
	Amp: number?,
}

type Bone = {
	Name: string,
	Role: string,
	Phase: number,
	Amp: number,
	Pivot: Vector3, -- world space
	Parent: Bone?,
	Parts: { BasePart },
	Root: BasePart?,
}

local function rotation(degrees: Vector3?): CFrame
	if not degrees then
		return CFrame.new()
	end
	return CFrame.Angles(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
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

local function mirrorVector(v: Vector3): Vector3
	return Vector3.new(-v.X, v.Y, v.Z)
end

-- Mirror image of a CFrame through the YZ plane (S * cf * S with S = diag(-1, 1, 1)), still a rotation.
local function mirrorCFrame(cf: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

-- Ray / triangle intersection (Möller–Trumbore). Returns the distance along `direction` or nil.
local function rayTriangle(origin: Vector3, direction: Vector3, a: Vector3, b: Vector3, c: Vector3): number?
	local e1, e2 = b - a, c - a
	local p = direction:Cross(e2)
	local det = e1:Dot(p)
	if math.abs(det) < 1e-9 then
		return nil
	end
	local inv = 1 / det
	local tv = origin - a
	local u = tv:Dot(p) * inv
	if u < 0 or u > 1 then
		return nil
	end
	local q = tv:Cross(e1)
	local v = direction:Dot(q) * inv
	if v < 0 or u + v > 1 then
		return nil
	end
	local t = e2:Dot(q) * inv
	if t <= 0 then
		return nil
	end
	return t
end

function CritterBuilder.new(name: string, scale: number, palette: { [string]: Color3 })
	local self = setmetatable({}, CritterBuilder)
	self.Name = name
	self.Scale = scale
	self.Palette = palette
	self.Model = Instance.new("Model")
	self.Model.Name = name
	self.Parts = {} :: { BasePart } -- visible parts
	self.CoreParts = {} :: { BasePart } -- parts that belong to the body (no bone)
	self.Bones = {} :: { Bone }
	self.BoneNames = {} :: { [string]: boolean }
	self.CurrentBone = nil :: Bone?
	self.Flip = false -- true while building the mirrored (left) copy of something
	self.CoreCenter = nil :: Vector3?
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

-- Design space -> world space (mirror, hover, scale).
function CritterBuilder:_world(p: Vector3): Vector3
	local q = if self.Flip then mirrorVector(p) else p
	return (q + Vector3.new(0, self.Hover, 0)) * self.Scale
end

-- Design point -> actual design point (mirror only), used for handles and face placement.
function CritterBuilder:_actual(p: Vector3): Vector3
	return if self.Flip then mirrorVector(p) else p
end

-- Creates a part from a WORLD size and CFrame and files it under the current bone (or the body).
function CritterBuilder:_rawPart(className: string, name: string, size: Vector3, cframe: CFrame, color: any, opts: Options?): BasePart
	local options = opts or {}
	local resolved, paintable = self:ResolveColor(color)

	local part = Instance.new(className) :: BasePart
	part.Name = name
	part.Size = Vector3.new(math.max(size.X, 0.01), math.max(size.Y, 0.01), math.max(size.Z, 0.01))
	part.CFrame = cframe
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
	local bone = self.CurrentBone
	if bone then
		table.insert(bone.Parts, part)
	else
		table.insert(self.CoreParts, part)
	end
	return part
end

-- Design-space CFrame -> world CFrame (mirror, hover, scale).
function CritterBuilder:_worldCFrame(cframe: CFrame): CFrame
	local cf = if self.Flip then mirrorCFrame(cframe) else cframe
	return CFrame.new((cf.Position + Vector3.new(0, self.Hover, 0)) * self.Scale) * cf.Rotation
end

-- Draws design-space triangles. Returns a handle whose Tris are in actual design space.
function CritterBuilder:_triangles(
	name: string,
	triangles: { LowPoly.TriangleWithInside },
	color: any,
	opts: Options?,
	thickness: number,
	center: Vector3,
	size: Vector3
): Handle
	local first: BasePart? = nil
	local actualTris = table.create(#triangles)
	local t = ((opts and opts.Thickness) or thickness) * self.Scale
	for _, triangle in triangles do
		local a, b, c = self:_world(triangle.A), self:_world(triangle.B), self:_world(triangle.C)
		local inside = if triangle.Inside then self:_world(triangle.Inside) else nil
		for _, wedge in LowPoly.TriangleWedges(a, b, c, t, inside) do
			local part = self:_rawPart("WedgePart", name, wedge.Size, wedge.CFrame, color, opts)
			first = first or part
		end
		table.insert(actualTris, {
			A = self:_actual(triangle.A),
			B = self:_actual(triangle.B),
			C = self:_actual(triangle.C),
			Inside = if triangle.Inside then self:_actual(triangle.Inside) else nil,
		})
	end
	return { Part = first, Center = self:_actual(center), Size = size, Tris = actualTris }
end

-- Plate thickness of a closed shape whose smallest extent is `smallest`.
local function shellThickness(smallest: number): number
	return math.clamp(smallest * 0.3, 0.04, 0.18)
end

-- Shapes --------------------------------------------------------------------------------

function CritterBuilder:Ball(name: string, size: Vector3, position: Vector3, rot: Vector3?, color: any, opts: Options?): Handle
	local smallest = math.min(size.X, size.Y, size.Z)
	local detail = (opts and opts.Detail) or (if smallest >= 1 then 2 elseif smallest >= 0.45 then 1 else 0)
	local data = if detail >= 2 then LowPoly.Icosahedron() elseif detail == 1 then LowPoly.Gyrobipyramid() else LowPoly.Octahedron()
	local frame = CFrame.new(position) * rotation(rot)
	local mesh = LowPoly.TransformMesh(data, frame, size)
	return self:_triangles(name, LowPoly.MeshTriangles(mesh, position), color, opts, shellThickness(smallest), position, size)
end

CritterBuilder.Gem = CritterBuilder.Ball
CritterBuilder.Ellipsoid = CritterBuilder.Ball

function CritterBuilder:Mesh(name: string, vertices: { Vector3 }, faces: { { number } }, color: any, opts: Options?): Handle
	local low, high = vertices[1], vertices[1]
	for _, v in vertices do
		low = Vector3.new(math.min(low.X, v.X), math.min(low.Y, v.Y), math.min(low.Z, v.Z))
		high = Vector3.new(math.max(high.X, v.X), math.max(high.Y, v.Y), math.max(high.Z, v.Z))
	end
	local size = high - low
	local mesh = { Vertices = vertices, Faces = faces }
	local center = (low + high) / 2
	return self:_triangles(name, LowPoly.MeshTriangles(mesh), color, opts, shellThickness(math.min(size.X, size.Y, size.Z)), center, size)
end

function CritterBuilder:Tube(name: string, points: { Vector3 }, radii: { number }, color: any, opts: Options?): Handle
	local options = opts or {}
	local largest, low, high = 0, points[1], points[1]
	for index, point in points do
		local r = radii[math.min(index, #radii)]
		largest = math.max(largest, r)
		low = Vector3.new(math.min(low.X, point.X - r), math.min(low.Y, point.Y - r), math.min(low.Z, point.Z - r))
		high = Vector3.new(math.max(high.X, point.X + r), math.max(high.Y, point.Y + r), math.max(high.Z, point.Z + r))
	end
	local triangles = LowPoly.TubeTriangles(points, radii, {
		Sides = options.Sides,
		Flatten = options.Flatten,
		CapStart = options.CapStart,
		CapEnd = options.CapEnd,
		Up = options.Up,
		Twist = options.Twist,
	})
	return self:_triangles(name, triangles, color, opts, shellThickness(largest * 2), (low + high) / 2, high - low)
end

-- Faceted spindle (double pyramid). number thickness = width at its widest; Vector2 = flat (width, depth).
-- The ends are pointed: extend a / b a little into the body, the foot or the hand.
function CritterBuilder:Limb(name: string, a: Vector3, b: Vector3, thickness: number | Vector2, color: any, opts: Options?): Handle
	local options = opts or {}
	local radius, flatten, sides
	if type(thickness) == "number" then
		radius, flatten, sides = thickness * 0.62, 1, options.Sides or 3
	else
		radius = thickness.X / 2
		flatten = options.Flatten or math.clamp(thickness.Y / math.max(thickness.X, 0.01), 0.1, 1)
		sides = options.Sides or 4
	end
	local triangles = LowPoly.SpindleTriangles(a, b, radius, sides, options.RingAt, flatten, options.Up)
	local size = Vector3.new(radius * 2, (b - a).Magnitude, radius * 2)
	return self:_triangles(name, triangles, color, opts, shellThickness(radius * 2 * flatten), (a + b) / 2, size)
end

function CritterBuilder:Chain(
	name: string,
	points: { Vector3 },
	fromThickness: number,
	toThickness: number,
	color: any,
	opts: Options?
): Handle
	local radii = {}
	local count = #points
	for index = 1, count do
		local alpha = if count > 1 then (index - 1) / (count - 1) else 0
		radii[index] = (fromThickness + (toThickness - fromThickness) * alpha) * 0.58
	end
	return self:Tube(name, points, radii, color, opts)
end

-- Angular flat strut (lightning tails, blades, planks): a flattened 4-sided spindle (16 parts).
-- thickness = (width, depth); opts.RingAt moves the widest point (default 0.5).
function CritterBuilder:Beam(name: string, a: Vector3, b: Vector3, thickness: Vector2, color: any, opts: Options?): Handle
	local options = opts or {}
	local radius = thickness.X / 2
	local flatten = options.Flatten or math.clamp(thickness.Y / math.max(thickness.X, 0.01), 0.1, 1)
	local triangles = LowPoly.SpindleTriangles(a, b, radius, options.Sides or 4, options.RingAt or 0.5, flatten, options.Up)
	local size = Vector3.new(thickness.X, (b - a).Magnitude, thickness.Y)
	return self:_triangles(name, triangles, color, opts, shellThickness(thickness.Y), (a + b) / 2, size)
end

function CritterBuilder:Cone(name: string, base: Vector3, tip: Vector3, radius: number, color: any, opts: Options?): Handle
	local options = opts or {}
	local triangles = LowPoly.ConeTriangles(base, tip, radius, options.Sides or 4, options.Closed, options.Up)
	local size = Vector3.new(radius * 2, (tip - base).Magnitude, radius * 2)
	return self:_triangles(name, triangles, color, opts, shellThickness(radius * 2), (base + tip) / 2, size)
end

function CritterBuilder:Cylinder(
	name: string,
	height: number,
	diameter: number,
	position: Vector3,
	rot: Vector3?,
	color: any,
	opts: Options?
): Handle
	local frame = CFrame.new(position) * rotation(rot)
	local options = table.clone(opts or {}) :: Options
	options.Sides = options.Sides or 6
	options.CapStart = options.CapStart or 0.2
	options.CapEnd = options.CapEnd or 0.2
	local bottom = frame:PointToWorldSpace(Vector3.new(0, -height / 2, 0))
	local top = frame:PointToWorldSpace(Vector3.new(0, height / 2, 0))
	return self:Tube(name, { bottom, top }, { diameter / 2, diameter / 2 }, color, options)
end

function CritterBuilder:Box(name: string, size: Vector3, position: Vector3, rot: Vector3?, color: any, opts: Options?): Handle
	local frame = CFrame.new(position) * rotation(rot)
	local smallest = math.min(size.X, size.Y, size.Z)
	return self:_triangles(name, LowPoly.BoxTriangles(frame, size, smallest * 0.12), color, opts, shellThickness(smallest), position, size)
end

-- Wedge-shaped solid (high at the back, +Z), every face faceted.
function CritterBuilder:Wedge(name: string, size: Vector3, position: Vector3, rot: Vector3?, color: any, opts: Options?): Handle
	local frame = CFrame.new(position) * rotation(rot)
	local h = size / 2
	local vertices = {
		frame:PointToWorldSpace(Vector3.new(-h.X, -h.Y, -h.Z)),
		frame:PointToWorldSpace(Vector3.new(h.X, -h.Y, -h.Z)),
		frame:PointToWorldSpace(Vector3.new(h.X, -h.Y, h.Z)),
		frame:PointToWorldSpace(Vector3.new(-h.X, -h.Y, h.Z)),
		frame:PointToWorldSpace(Vector3.new(-h.X, h.Y, h.Z)),
		frame:PointToWorldSpace(Vector3.new(h.X, h.Y, h.Z)),
	}
	local polygons = { { 1, 2, 3, 4 }, { 4, 3, 6, 5 }, { 1, 5, 6, 2 }, { 1, 4, 5 }, { 2, 6, 3 } }
	local smallest = math.min(size.X, size.Y, size.Z)
	return self:_triangles(
		name,
		LowPoly.BulgedTriangles(vertices, polygons, smallest * 0.1),
		color,
		opts,
		shellThickness(smallest),
		position,
		size
	)
end

-- Flat triangle through three points.
function CritterBuilder:Tri(name: string, a: Vector3, b: Vector3, c: Vector3, color: any, opts: Options?): Handle
	local low = Vector3.new(math.min(a.X, b.X, c.X), math.min(a.Y, b.Y, c.Y), math.min(a.Z, b.Z, c.Z))
	local high = Vector3.new(math.max(a.X, b.X, c.X), math.max(a.Y, b.Y, c.Y), math.max(a.Z, b.Z, c.Z))
	return self:_triangles(name, { { A = a, B = b, C = c } }, color, opts, (opts and opts.Thickness) or 0.1, (low + high) / 2, high - low)
end

-- Flat isosceles triangle whose base is centred on `base` and whose point is `tip`.
-- facingHint: direction the flat side faces (default: front, -Z). Vector3.new(1, 0, 0) for dorsal fins seen
-- from the side, Vector3.new(0, 1, 0) for horizontal triangles (wings).
function CritterBuilder:Blade(
	name: string,
	base: Vector3,
	tip: Vector3,
	width: number,
	color: any,
	opts: Options?,
	facingHint: Vector3?
): Handle
	local frame = pointing(base, tip - base, facingHint)
	local half = width / 2
	local a = base + frame.XVector * half
	local b = base - frame.XVector * half
	return self:Tri(name, a, b, tip, color, opts)
end

--[[
	Triangle from a base to a tip. depth = thickness of the shape along facingHint.
	Thin (depth < 0.3 * width): a flat triangle `depth` thick (fins, leaves, wings, flames).
	Otherwise: a 3-sided pyramid with a ridge towards facingHint (ears, horns, spikes, crests).
]]
function CritterBuilder:Spike(
	name: string,
	base: Vector3,
	tip: Vector3,
	width: number,
	depth: number,
	color: any,
	opts: Options?,
	facingHint: Vector3?
): Handle
	if depth < width * 0.3 then
		local options = table.clone(opts or {}) :: Options
		options.Thickness = options.Thickness or math.max(depth, 0.06)
		return self:Blade(name, base, tip, width, color, options, facingHint)
	end
	local frame = pointing(base, tip - base, facingHint)
	local x, z = frame.XVector, frame.ZVector
	local front = base + z * (depth * 0.6)
	local left = base - x * (width / 2) - z * (depth * 0.4)
	local right = base + x * (width / 2) - z * (depth * 0.4)
	local inside = (front + left + right) / 3 + (tip - base) * 0.2
	local triangles = {
		{ A = front, B = right, C = tip, Inside = inside },
		{ A = right, B = left, C = tip, Inside = inside },
		{ A = left, B = front, C = tip, Inside = inside },
	}
	local size = Vector3.new(width, (tip - base).Magnitude, depth)
	return self:_triangles(name, triangles, color, opts, shellThickness(math.min(width, depth)), (base + tip) / 2, size)
end

-- Mirrored shapes: build the given (right, +X) shape and its mirror image on the left.
function CritterBuilder:_mirrored(build: (string) -> ())
	local saved = self.Flip
	self.Flip = not saved
	build("L")
	self.Flip = saved
	build("R")
end

function CritterBuilder:MirrorBall(name: string, size: Vector3, position: Vector3, rot: Vector3?, color: any, opts: Options?)
	self:_mirrored(function(suffix)
		self:Ball(name .. suffix, size, position, rot, color, opts)
	end)
end
CritterBuilder.MirrorGem = CritterBuilder.MirrorBall
CritterBuilder.MirrorEllipsoid = CritterBuilder.MirrorBall

function CritterBuilder:MirrorBox(name: string, size: Vector3, position: Vector3, rot: Vector3?, color: any, opts: Options?)
	self:_mirrored(function(suffix)
		self:Box(name .. suffix, size, position, rot, color, opts)
	end)
end

function CritterBuilder:MirrorLimb(name: string, a: Vector3, b: Vector3, thickness: number | Vector2, color: any, opts: Options?)
	self:_mirrored(function(suffix)
		self:Limb(name .. suffix, a, b, thickness, color, opts)
	end)
end

function CritterBuilder:MirrorChain(
	name: string,
	points: { Vector3 },
	fromThickness: number,
	toThickness: number,
	color: any,
	opts: Options?
)
	self:_mirrored(function(suffix)
		self:Chain(name .. suffix, points, fromThickness, toThickness, color, opts)
	end)
end

function CritterBuilder:MirrorTube(name: string, points: { Vector3 }, radii: { number }, color: any, opts: Options?)
	self:_mirrored(function(suffix)
		self:Tube(name .. suffix, points, radii, color, opts)
	end)
end

function CritterBuilder:MirrorBeam(name: string, a: Vector3, b: Vector3, thickness: Vector2, color: any, opts: Options?)
	self:_mirrored(function(suffix)
		self:Beam(name .. suffix, a, b, thickness, color, opts)
	end)
end

function CritterBuilder:MirrorCone(name: string, base: Vector3, tip: Vector3, radius: number, color: any, opts: Options?)
	self:_mirrored(function(suffix)
		self:Cone(name .. suffix, base, tip, radius, color, opts)
	end)
end

function CritterBuilder:MirrorCylinder(
	name: string,
	height: number,
	diameter: number,
	position: Vector3,
	rot: Vector3?,
	color: any,
	opts: Options?
)
	self:_mirrored(function(suffix)
		self:Cylinder(name .. suffix, height, diameter, position, rot, color, opts)
	end)
end

function CritterBuilder:MirrorSpike(
	name: string,
	base: Vector3,
	tip: Vector3,
	width: number,
	depth: number,
	color: any,
	opts: Options?,
	facingHint: Vector3?
)
	self:_mirrored(function(suffix)
		self:Spike(name .. suffix, base, tip, width, depth, color, opts, facingHint)
	end)
end

function CritterBuilder:MirrorBlade(
	name: string,
	base: Vector3,
	tip: Vector3,
	width: number,
	color: any,
	opts: Options?,
	facingHint: Vector3?
)
	self:_mirrored(function(suffix)
		self:Blade(name .. suffix, base, tip, width, color, opts, facingHint)
	end)
end

function CritterBuilder:MirrorTri(name: string, a: Vector3, b: Vector3, c: Vector3, color: any, opts: Options?)
	self:_mirrored(function(suffix)
		self:Tri(name .. suffix, a, b, c, color, opts)
	end)
end

function CritterBuilder:MirrorMesh(name: string, vertices: { Vector3 }, faces: { { number } }, color: any, opts: Options?)
	self:_mirrored(function(suffix)
		self:Mesh(name .. suffix, vertices, faces, color, opts)
	end)
end

-- Rig ------------------------------------------------------------------------------------

local function roleFromName(name: string): string
	for _, role in ROLES do
		if string.sub(name, 1, #role) == role then
			return role
		end
	end
	return "Static"
end

function CritterBuilder:Bone(name: string, pivot: Vector3, opts: BoneOptions?, build: () -> ())
	local options = opts or {}
	local unique = name
	local index = 1
	while self.BoneNames[unique] do
		index += 1
		unique = name .. index
	end
	self.BoneNames[unique] = true

	local bone: Bone = {
		Name = unique,
		Role = options.Role or roleFromName(name),
		Phase = options.Phase or 0,
		Amp = options.Amp or 1,
		Pivot = self:_world(pivot),
		Parent = self.CurrentBone,
		Parts = {},
		Root = nil,
	}
	table.insert(self.Bones, bone)
	local saved = self.CurrentBone
	self.CurrentBone = bone
	build()
	self.CurrentBone = saved
end

-- The same bone on both sides. build(side) receives 1 (right) then -1 (left, built mirrored).
function CritterBuilder:MirrorBone(name: string, pivot: Vector3, opts: BoneOptions?, build: (number) -> ())
	local options = opts or {}
	local role = options.Role or roleFromName(name)
	local saved = self.Flip
	for _, side in { 1, -1 } do
		self.Flip = if side < 0 then not saved else saved
		local phase = (options.Phase or 0) + (if side < 0 then MIRROR_PHASE[role] or 0 else 0)
		self:Bone(name .. (if side < 0 then "L" else "R"), pivot, { Role = role, Phase = phase % 1, Amp = options.Amp }, function()
			build(side)
		end)
	end
	self.Flip = saved
end

-- Face helpers ---------------------------------------------------------------------------------

-- Point and outward normal on the front of a shape at offset (x, y) from its centre (actual design space).
function CritterBuilder:_surface(handle: Handle, x: number, y: number): (Vector3, Vector3)
	local dx = if self.Flip then -x else x
	local origin = handle.Center + Vector3.new(dx, y, -(handle.Size.Magnitude + 5))
	local direction = Vector3.new(0, 0, 1)
	local best, bestTriangle = math.huge, nil
	for _, triangle in handle.Tris do
		local t = rayTriangle(origin, direction, triangle.A, triangle.B, triangle.C)
		if t and t < best then
			best, bestTriangle = t, triangle
		end
	end
	if bestTriangle then
		local point = origin + direction * best
		local normal = (bestTriangle.B - bestTriangle.A):Cross(bestTriangle.C - bestTriangle.A).Unit
		local inside = bestTriangle.Inside or handle.Center
		if (point - inside):Dot(normal) < 0 then
			normal = -normal
		end
		return point, normal
	end
	-- Missed (offset outside the silhouette): use the bounding ellipsoid.
	local half = handle.Size / 2
	local px = math.clamp(dx, -half.X * 0.95, half.X * 0.95)
	local py = math.clamp(y, -half.Y * 0.95, half.Y * 0.95)
	local inner = math.max(0, 1 - (px / half.X) ^ 2 - (py / half.Y) ^ 2)
	local pz = -half.Z * math.sqrt(inner)
	local normal = Vector3.new(px / (half.X * half.X), py / (half.Y * half.Y), pz / (half.Z * half.Z))
	return handle.Center + Vector3.new(px, py, pz), (if normal.Magnitude > 1e-6 then normal.Unit else Vector3.new(0, 0, -1))
end

-- CFrame on the surface of a shape, -Z (LookVector) pointing outwards (mostly forwards).
function CritterBuilder:OnSurface(handle: Handle, x: number, y: number, inset: number?): CFrame
	local point, normal = self:_surface(handle, x, y)
	local look = (normal + Vector3.new(0, 0, -1)).Unit
	local up = Vector3.new(0, 1, 0)
	if math.abs(look:Dot(up)) > 0.95 then
		up = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(point - look * (inset or 0), point - look * (inset or 0) + look, up)
end

-- Round part (SpecialMesh sphere scaled to `size`) at an ACTUAL design-space CFrame (no mirroring).
function CritterBuilder:_round(name: string, size: Vector3, cframe: CFrame, color: any, opts: Options?): BasePart
	local s = self.Scale
	local world = CFrame.new((cframe.Position + Vector3.new(0, self.Hover, 0)) * s) * cframe.Rotation
	local part = self:_rawPart("Part", name, size * s, world, color, opts)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Faceted stud lying on the surface (nose, spots, cheeks, gems): triangles around a raised point
-- (4 = a diamond, 3 for tiny studs).
function CritterBuilder:_stud(name: string, frame: CFrame, size: Vector3, color: any, opts: Options?)
	local look, right, up = frame.LookVector, frame.RightVector, frame.UpVector
	local base = frame.Position - look * (size.Z * 0.35)
	local apex = frame.Position + look * (size.Z * 0.65)
	local corners
	if math.max(size.X, size.Y) >= 0.25 then
		corners = { base + right * (size.X / 2), base + up * (size.Y / 2), base - right * (size.X / 2), base - up * (size.Y / 2) }
	else
		corners =
			{ base + up * (size.Y / 2), base - right * (size.X / 2) - up * (size.Y / 4), base + right * (size.X / 2) - up * (size.Y / 4) }
	end
	local inside = base - look * size.Z
	local triangles = {}
	for index = 1, #corners do
		table.insert(triangles, { A = corners[index], B = corners[index % #corners + 1], C = apex, Inside = inside })
	end
	local saved = self.Flip
	self.Flip = false
	self:_triangles(name, triangles, color, opts, math.max(size.Z * 0.4, 0.04), frame.Position, size)
	self.Flip = saved
end

--[[
	Round eyes on the front of `head`. size = (width, height, depth).
	style: "Cute" (iris + pupil + shine), "Dazed" (white + small pupil), "Angry" (with triangle brows),
	       "Sleepy" (closed), "Glow" (neon).
]]
function CritterBuilder:Eyes(head: Handle, spacing: number, height: number, size: Vector3, irisColor: any, style: string?)
	local eyeStyle = style or "Cute"
	local depth = math.max(size.Z, 0.25)
	for _, side in { -1, 1 } do
		local suffix = if side < 0 then "L" else "R"
		local surface = self:OnSurface(head, side * spacing, height)
		-- Sink the eye half into the head, then work in its local frame (-Z = outwards).
		local frame = surface * CFrame.new(0, 0, depth * 0.1)
		local function place(name: string, partSize: Vector3, x: number, y: number, out: number, color: any, opts: Options?)
			self:_round(name .. suffix, partSize, frame * CFrame.new(x, y, -out), color, opts)
		end

		if eyeStyle == "Sleepy" then
			place("Eye", Vector3.new(size.X * 1.05, size.Y * 0.2, depth * 0.6), 0, -size.Y * 0.1, depth * 0.2, "Black")
		elseif eyeStyle == "Dazed" then
			place("Eye", Vector3.new(size.X, size.Y, depth), 0, 0, 0, "White")
			place("Pupil", Vector3.new(size.X * 0.3, size.X * 0.3, depth * 0.5), 0, 0, depth * 0.3, "Black")
		elseif eyeStyle == "Glow" then
			place("Eye", Vector3.new(size.X, size.Y, depth), 0, 0, 0, irisColor, { Neon = true })
		else
			place("Eye", Vector3.new(size.X, size.Y, depth), 0, 0, 0, irisColor)
			local iris = self:ResolveColor(irisColor)
			if iris ~= DEFAULT_COLORS.Black then
				place("Pupil", Vector3.new(size.X * 0.55, size.Y * 0.6, depth * 0.6), 0, -size.Y * 0.04, depth * 0.24, "Black")
			end
			local shine = math.min(size.X, size.Y) * 0.36
			place("Shine", Vector3.new(shine, shine, depth * 0.35), side * -size.X * 0.16, size.Y * 0.2, depth * 0.38, "White")
			if eyeStyle == "Angry" then
				-- Triangle brow slanting down towards the nose.
				local inner = frame:PointToWorldSpace(Vector3.new(-side * size.X * 0.55, size.Y * 0.42, -depth * 0.3))
				local outer = frame:PointToWorldSpace(Vector3.new(side * size.X * 0.65, size.Y * 0.72, -depth * 0.3))
				local low = frame:PointToWorldSpace(Vector3.new(side * size.X * 0.45, size.Y * 0.5, -depth * 0.3))
				local saved = self.Flip
				self.Flip = false
				self:Tri("Brow" .. suffix, inner, outer, low, "Black", { Thickness = 0.08 })
				self.Flip = saved
			end
		end
	end
end

-- Small faceted stud pinned on the face (nose, spots, gems...). size = (width, height, depth).
function CritterBuilder:FaceDot(name: string, head: Handle, x: number, y: number, size: Vector3, color: any, opts: Options?)
	local frame = self:OnSurface(head, x, y)
	self:_stud(name, frame, size, color, opts)
end

function CritterBuilder:Cheeks(head: Handle, spacing: number, height: number, size: number, color: any?)
	for _, side in { -1, 1 } do
		local frame = self:OnSurface(head, side * spacing, height)
		self:_stud("Cheek" .. (if side < 0 then "L" else "R"), frame, Vector3.new(size, size * 0.75, 0.14), color or "Cheek")
	end
end

-- Round mouth, closed (a thin smile) or open (with a tongue).
function CritterBuilder:Mouth(head: Handle, height: number, width: number, open: boolean?)
	local frame = self:OnSurface(head, 0, height) * CFrame.new(0, 0, 0.04)
	if open then
		self:_round("Mouth", Vector3.new(width, width * 0.55, 0.3), frame, "Mouth")
		self:_round("Tongue", Vector3.new(width * 0.55, width * 0.25, 0.3), frame * CFrame.new(0, -width * 0.12, -0.04), "Tongue")
	else
		self:_round("Mouth", Vector3.new(width, width * 0.2, 0.22), frame, "Mouth")
	end
end

-- Effects ---------------------------------------------------------------------------------------

-- Invisible helper part (fire, lights, particles) at a design position.
function CritterBuilder:_anchor(name: string, position: Vector3, size: number): BasePart
	local part = self:_rawPart("Part", name, Vector3.one * size * self.Scale, CFrame.new(self:_world(position)), "White")
	part.Transparency = 1
	part.CastShadow = false
	part:SetAttribute("Helper", true)
	return part
end

-- Low-poly flame: crossed neon triangles (outer flame + inner core) and a real Fire for motion.
function CritterBuilder:Flame(name: string, position: Vector3, size: number)
	local tip = position + Vector3.new(0, size * 1.6, 0)
	local coreTip = position + Vector3.new(0, size * 1.0, 0)
	local base = position - Vector3.new(0, size * 0.15, 0)
	local thickness = { Neon = true, Thickness = math.max(size * 0.08, 0.05) }
	self:Blade(name .. "A", base, tip, size, "Flame", thickness)
	self:Blade(name .. "B", base, tip, size, "Flame", thickness, Vector3.new(1, 0, 0))
	self:Blade(name .. "CoreA", base, coreTip, size * 0.55, "FlameCore", thickness, Vector3.new(0.7, 0, -0.7))
	self:Blade(name .. "CoreB", base, coreTip, size * 0.55, "FlameCore", thickness, Vector3.new(0.7, 0, 0.7))
	local anchor = self:_anchor(name .. "Fire", position + Vector3.new(0, size * 0.4, 0), size * 0.4)
	local fire = Instance.new("Fire")
	fire.Size = math.max(2, size * self.Scale * 2)
	fire.Heat = 4
	fire.Color = DEFAULT_COLORS.Flame
	fire.SecondaryColor = DEFAULT_COLORS.FlameCore
	fire.Parent = anchor
	local light = Instance.new("PointLight")
	light.Color = DEFAULT_COLORS.Flame
	light.Range = 8
	light.Brightness = 1.5
	light.Parent = anchor
end

function CritterBuilder:Particles(target: any, color: Color3, rate: number, size: number?)
	local part: BasePart? = if typeof(target) == "Instance" then target else (target and target.Part)
	if not part then
		return
	end
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

-- Marks the main body shape: the invisible animated core sits at its centre.
function CritterBuilder:SetCore(handle: Handle)
	self.CoreCenter = handle.Center
end

-- Finalise --------------------------------------------------------------------------------------

local function invisiblePart(name: string, size: Vector3, cframe: CFrame, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Transparency = 1
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function weld(part0: BasePart, part1: BasePart)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = part0
	constraint.Part1 = part1
	constraint.Parent = part1
end

--[[
	Builds the rig and returns the model:
		HumanoidRootPart (invisible, collides with the ground)
		  └─ Motor6D "Bounce" -> Core (invisible, body centre): every body part is welded to it
		       └─ Motor6D <bone name> -> <bone name>Root (invisible, at the pivot): the bone's parts are welded to it
	Bone motors carry the attributes Role, Phase, Amp and Side (+1 right, -1 left, 0 centre) read by the client animator.
	Model attributes: StandOffset, Scale, Height (top), Bottom (lowest point), Floats, PartCount, BoneCount.
]]
function CritterBuilder:Finish(): Model
	local s = self.Scale
	local model = self.Model
	assert(#self.Parts > 0, "A critter needs at least one part")

	local standOffset = 1.5 * s
	local root = invisiblePart("HumanoidRootPart", Vector3.new(2, 2, 2) * s, CFrame.new(0, standOffset, 0), model)
	root.Massless = false
	root.CanCollide = true
	model.PrimaryPart = root

	local coreCenter = if self.CoreCenter
		then self:_world(self.CoreCenter)
		else self.CoreParts[1] and self.CoreParts[1].Position or root.Position
	local core = invisiblePart("Core", Vector3.new(1.2, 1.2, 1.2) * s, CFrame.new(coreCenter), model)
	local bounce = Instance.new("Motor6D")
	bounce.Name = "Bounce"
	bounce.Part0 = root
	bounce.Part1 = core
	bounce.C0 = root.CFrame:ToObjectSpace(core.CFrame)
	bounce.Parent = root

	for _, part in self.CoreParts do
		weld(core, part)
	end

	for _, bone in self.Bones do
		local parentPart = if bone.Parent and bone.Parent.Root then bone.Parent.Root else core
		local boneRoot = invisiblePart(bone.Name .. "Root", Vector3.new(0.4, 0.4, 0.4) * s, CFrame.new(bone.Pivot), model)
		bone.Root = boneRoot
		local motor = Instance.new("Motor6D")
		motor.Name = bone.Name
		motor.Part0 = parentPart
		motor.Part1 = boneRoot
		motor.C0 = parentPart.CFrame:ToObjectSpace(boneRoot.CFrame)
		motor:SetAttribute("Role", bone.Role)
		motor:SetAttribute("Phase", bone.Phase)
		motor:SetAttribute("Amp", bone.Amp)
		motor:SetAttribute("Side", if bone.Pivot.X > 0.05 * s then 1 elseif bone.Pivot.X < -0.05 * s then -1 else 0)
		motor.Parent = parentPart
		for _, part in bone.Parts do
			weld(boneRoot, part)
		end
	end

	-- Exact vertical extent of every visible part.
	local top, bottom = -math.huge, math.huge
	local visible = 0
	for _, part in self.Parts do
		if part.Transparency < 1 then
			visible += 1
			local cf, size = part.CFrame, part.Size
			local halfY = math.abs(cf.XVector.Y) * size.X / 2 + math.abs(cf.YVector.Y) * size.Y / 2 + math.abs(cf.ZVector.Y) * size.Z / 2
			top = math.max(top, cf.Position.Y + halfY)
			bottom = math.min(bottom, cf.Position.Y - halfY)
		end
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = standOffset - root.Size.Y / 2
	humanoid.Parent = model

	model:SetAttribute("StandOffset", standOffset)
	model:SetAttribute("Scale", s)
	model:SetAttribute("Height", top)
	model:SetAttribute("Bottom", bottom)
	model:SetAttribute("Floats", self.Hover > 0)
	model:SetAttribute("PartCount", visible)
	model:SetAttribute("BoneCount", #self.Bones)
	return model
end

return CritterBuilder
