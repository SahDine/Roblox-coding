--[[
	LowPoly
	Triangle geometry for the "everything is triangles" low-poly style.

	Roblox has no triangle part, so every triangle is drawn with one or two thin
	WedgeParts (a right triangle needs one wedge, any other triangle is split
	along its altitude into two right triangles). A closed shape is a list of
	triangles whose plates are pushed inwards so their outer faces are exactly
	the triangle planes: neighbouring facets meet edge to edge and are shaded
	flat, which gives the faceted low-poly look.

	Two layers:
	  * Geometry (pure maths, any space): TriangleWedges + shape generators that
	    return vertex / triangle lists (Icosahedron, Octahedron, Bipyramid, Tube,
	    Cone, BulgedBox, Rock...). CritterBuilder uses these in design space.
	  * World helpers that create anchored parts directly (map decor, props):
	    LowPoly.Mesh, LowPoly.Ball, LowPoly.Tube, LowPoly.Cone, LowPoly.Rock,
	    LowPoly.Triangle. Each returns the list of created parts.

	A triangle costs 2 parts (1 if it is a right triangle), e.g. a Ball
	(icosahedron, 20 faces) costs 40 parts, a 3-sided Tube segment 12.
]]

local LowPoly = {}

export type Wedge = { Size: Vector3, CFrame: CFrame }
export type Triangle = { Vector3 } -- { a, b, c }
export type TriangleWithInside = { A: Vector3, B: Vector3, C: Vector3, Inside: Vector3? }

-- Wedges thinner than this along an edge are skipped (degenerate slivers).
local MIN_EDGE = 0.01

--[[
	Returns the 1 or 2 wedges that draw triangle abc with plates `thickness` thick.
	inside (optional): a point on the inner side of the surface. When given, the plate is moved
	so that its outer face lies exactly on the triangle (closed meshes); otherwise the plate is
	centred on the triangle (free-standing flat triangles: wings, leaves, flames).
]]
function LowPoly.TriangleWedges(a: Vector3, b: Vector3, c: Vector3, thickness: number, inside: Vector3?): { Wedge }
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	-- `a` must be the vertex opposite to the longest edge (bc).
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b

	local normal = ac:Cross(ab)
	if normal.Magnitude < 1e-7 or bc.Magnitude < 1e-6 then
		return {}
	end

	-- A right triangle (right angle at `a`, opposite the longest edge) is exactly one wedge face.
	local abLength, acLength = ab.Magnitude, ac.Magnitude
	if math.abs(ab:Dot(ac)) < 0.002 * abLength * acLength then
		if abLength < MIN_EDGE or acLength < MIN_EDGE then
			return {}
		end
		local back = -ab / abLength
		local up = ac / acLength
		local right = up:Cross(back)
		local offset = Vector3.zero
		if inside then
			local side = (inside - a):Dot(right)
			offset = right * (if side >= 0 then thickness / 2 else -thickness / 2)
		end
		return {
			{ Size = Vector3.new(thickness, acLength, abLength), CFrame = CFrame.fromMatrix((b + c) / 2 + offset, right, up, back) },
		}
	end

	local right = normal.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	if height < MIN_EDGE then
		return {}
	end

	local offset = Vector3.zero
	if inside then
		local side = (inside - a):Dot(right)
		offset = right * (if side >= 0 then thickness / 2 else -thickness / 2)
	end

	local wedges = {}
	local d1 = math.abs(ab:Dot(back))
	local d2 = math.abs(ac:Dot(back))
	if d1 > MIN_EDGE then
		table.insert(wedges, {
			Size = Vector3.new(thickness, height, d1),
			CFrame = CFrame.fromMatrix((a + b) / 2 + offset, right, up, back),
		})
	end
	if d2 > MIN_EDGE then
		table.insert(wedges, {
			Size = Vector3.new(thickness, height, d2),
			CFrame = CFrame.fromMatrix((a + c) / 2 + offset, -right, up, -back),
		})
	end
	return wedges
end

-- Shape generators ------------------------------------------------------------------------
-- Unit shapes are centred on the origin with a radius of 1 (scale them per axis).

export type MeshData = { Vertices: { Vector3 }, Faces: { { number } } }

-- 20 faces, a vertex at the top and at the bottom, one upper vertex pointing to the front (-Z).
function LowPoly.Icosahedron(): MeshData
	local vertices = { Vector3.new(0, 1, 0) }
	local ringY = 1 / math.sqrt(5)
	local ringR = 2 / math.sqrt(5)
	for i = 0, 4 do
		local angle = i * math.pi * 2 / 5
		table.insert(vertices, Vector3.new(math.sin(angle) * ringR, ringY, -math.cos(angle) * ringR))
	end
	for i = 0, 4 do
		local angle = (i + 0.5) * math.pi * 2 / 5
		table.insert(vertices, Vector3.new(math.sin(angle) * ringR, -ringY, -math.cos(angle) * ringR))
	end
	table.insert(vertices, Vector3.new(0, -1, 0))

	local faces = {}
	for i = 0, 4 do
		local u1, u2 = 2 + i, 2 + (i + 1) % 5
		local l1, l2 = 7 + i, 7 + (i + 1) % 5
		table.insert(faces, { 1, u1, u2 })
		table.insert(faces, { u1, l1, u2 })
		table.insert(faces, { u2, l1, l2 })
		table.insert(faces, { 12, l2, l1 })
	end
	return { Vertices = vertices, Faces = faces }
end

-- 16 faces: two square pyramids on a twisted square band (cheaper than the icosahedron, still round-ish).
function LowPoly.Gyrobipyramid(): MeshData
	local ringY = 0.36
	local ringR = 0.93
	local vertices = { Vector3.new(0, 1, 0) }
	for i = 0, 3 do
		local angle = i * math.pi / 2
		table.insert(vertices, Vector3.new(math.sin(angle) * ringR, ringY, -math.cos(angle) * ringR))
	end
	for i = 0, 3 do
		local angle = (i + 0.5) * math.pi / 2
		table.insert(vertices, Vector3.new(math.sin(angle) * ringR, -ringY, -math.cos(angle) * ringR))
	end
	table.insert(vertices, Vector3.new(0, -1, 0))
	local faces = {}
	for i = 0, 3 do
		local u1, u2 = 2 + i, 2 + (i + 1) % 4
		local l1, l2 = 6 + i, 6 + (i + 1) % 4
		table.insert(faces, { 1, u1, u2 })
		table.insert(faces, { u1, l1, u2 })
		table.insert(faces, { u2, l1, l2 })
		table.insert(faces, { 10, l2, l1 })
	end
	return { Vertices = vertices, Faces = faces }
end

-- 8 faces (a diamond).
function LowPoly.Octahedron(): MeshData
	local vertices = {
		Vector3.new(0, 1, 0),
		Vector3.new(1, 0, 0),
		Vector3.new(0, 0, 1),
		Vector3.new(-1, 0, 0),
		Vector3.new(0, 0, -1),
		Vector3.new(0, -1, 0),
	}
	local faces = {}
	for i = 0, 3 do
		local r1, r2 = 2 + i, 2 + (i + 1) % 4
		table.insert(faces, { 1, r1, r2 })
		table.insert(faces, { 6, r2, r1 })
	end
	return { Vertices = vertices, Faces = faces }
end

-- Ring of `sides` vertices at height ringY plus a top and a bottom point (2 * sides faces).
function LowPoly.Bipyramid(sides: number, ringY: number?, twist: number?): MeshData
	local y = ringY or 0
	local vertices = { Vector3.new(0, 1, 0) }
	for i = 0, sides - 1 do
		local angle = (i + (twist or 0)) * math.pi * 2 / sides
		table.insert(vertices, Vector3.new(math.sin(angle), y, -math.cos(angle)))
	end
	table.insert(vertices, Vector3.new(0, -1, 0))
	local bottom = sides + 2
	local faces = {}
	for i = 0, sides - 1 do
		local r1, r2 = 2 + i, 2 + (i + 1) % sides
		table.insert(faces, { 1, r1, r2 })
		table.insert(faces, { bottom, r2, r1 })
	end
	return { Vertices = vertices, Faces = faces }
end

-- Irregular rock / crystal cluster: an icosahedron with every vertex pushed in or out.
function LowPoly.RockData(seed: number, roughness: number?): MeshData
	local data = LowPoly.Icosahedron()
	local random = Random.new(seed)
	local amount = roughness or 0.25
	for index, vertex in data.Vertices do
		data.Vertices[index] = vertex * (1 + (random:NextNumber() * 2 - 1) * amount)
	end
	return data
end

-- Transforms a unit mesh: scaled per axis (size = full extents), then placed with `cframe`.
function LowPoly.TransformMesh(data: MeshData, cframe: CFrame, size: Vector3): MeshData
	local half = size / 2
	local vertices = table.create(#data.Vertices)
	for index, vertex in data.Vertices do
		vertices[index] = cframe:PointToWorldSpace(vertex * half)
	end
	return { Vertices = vertices, Faces = data.Faces }
end

-- Triangles of a convex mesh, each with the mesh centre as its inside point.
function LowPoly.MeshTriangles(data: MeshData, inside: Vector3?): { TriangleWithInside }
	local center = inside
	if not center then
		local sum = Vector3.zero
		for _, vertex in data.Vertices do
			sum += vertex
		end
		center = sum / #data.Vertices
	end
	local triangles = {}
	for _, face in data.Faces do
		local v = data.Vertices
		table.insert(triangles, { A = v[face[1]], B = v[face[2]], C = v[face[3]], Inside = center })
	end
	return triangles
end

-- Two vectors perpendicular to `direction` (and to each other).
local function perpendiculars(direction: Vector3, hint: Vector3?): (Vector3, Vector3)
	local d = direction.Unit
	local reference = hint or Vector3.new(0, 1, 0)
	if math.abs(d:Dot(reference.Unit)) > 0.95 then
		reference = if math.abs(d.Z) < 0.9 then Vector3.new(0, 0, -1) else Vector3.new(1, 0, 0)
	end
	local u = (reference - d * reference:Dot(d)).Unit
	local v = d:Cross(u)
	return u, v
end
LowPoly.Perpendiculars = perpendiculars

export type TubeOptions = {
	Sides: number?, -- vertices per ring (3 = triangular section, the cheapest)
	Flatten: number?, -- ring squash along the second perpendicular (0.3 = flat fin-like tube)
	CapStart: number?, -- length of the pointed cap before the first point (fraction of its radius, 0 = flat)
	CapEnd: number?, -- same after the last point
	Up: Vector3?, -- preferred direction of the first ring vertex
	Twist: number?, -- extra rotation of the rings (in ring steps)
}

--[[
	Tube through `points` with one radius per point. Successive rings are turned by half a step
	(antiprism) so every facet is a real triangle, never a flat rectangle. Ends are pointed caps.
	A radius of 0 makes that end a sharp point (horns, tails).
]]
function LowPoly.TubeTriangles(points: { Vector3 }, radii: { number }, options: TubeOptions?): { TriangleWithInside }
	local opts = options or {}
	local sides = opts.Sides or 3
	local flatten = opts.Flatten or 1
	local count = #points
	assert(count >= 2, "a tube needs at least 2 points")

	-- Rotation-minimising frames along the curve.
	local tangents = {}
	for i = 1, count do
		local before = points[math.max(1, i - 1)]
		local after = points[math.min(count, i + 1)]
		local direction = after - before
		if direction.Magnitude < 1e-6 then
			direction = if i > 1 then tangents[i - 1] else Vector3.new(0, 1, 0)
		end
		tangents[i] = direction.Unit
	end
	local u0, _ = perpendiculars(tangents[1], opts.Up)
	local us, vs = {}, {}
	local u = u0
	for i = 1, count do
		local t = tangents[i]
		u = u - t * u:Dot(t)
		if u.Magnitude < 1e-4 then
			u = perpendiculars(t)
		end
		u = u.Unit
		us[i] = u
		vs[i] = t:Cross(u)
	end

	local rings = {}
	for i = 1, count do
		local ring = {}
		local radius = radii[math.min(i, #radii)]
		for k = 0, sides - 1 do
			local angle = (k + (i - 1) * 0.5 + (opts.Twist or 0)) * math.pi * 2 / sides
			ring[k] = points[i] + us[i] * (math.cos(angle) * radius) + vs[i] * (math.sin(angle) * radius * flatten)
		end
		rings[i] = { Points = ring, Radius = radius }
	end

	local triangles = {}
	local function add(a: Vector3, b: Vector3, c: Vector3, inside: Vector3)
		table.insert(triangles, { A = a, B = b, C = c, Inside = inside })
	end

	for i = 1, count - 1 do
		local r1, r2 = rings[i], rings[i + 1]
		local inside = (points[i] + points[i + 1]) / 2
		if r2.Radius <= 1e-4 then
			for k = 0, sides - 1 do
				add(r1.Points[k], r1.Points[(k + 1) % sides], points[i + 1], inside)
			end
		elseif r1.Radius <= 1e-4 then
			for k = 0, sides - 1 do
				add(points[i], r2.Points[k], r2.Points[(k + 1) % sides], inside)
			end
		else
			for k = 0, sides - 1 do
				local k1 = (k + 1) % sides
				add(r1.Points[k], r2.Points[k], r1.Points[k1], inside)
				add(r2.Points[k], r2.Points[k1], r1.Points[k1], inside)
			end
		end
	end

	local function cap(index: number, direction: Vector3, length: number)
		local ring = rings[index]
		if ring.Radius <= 1e-4 then
			return
		end
		local center = points[index]
		local tip = center + direction * (ring.Radius * length + 0.001)
		for k = 0, sides - 1 do
			add(ring.Points[k], ring.Points[(k + 1) % sides], tip, center - direction * ring.Radius * 0.1)
		end
	end
	cap(1, -tangents[1], opts.CapStart or 0.6)
	cap(count, tangents[count], opts.CapEnd or 0.6)
	return triangles
end

-- Double pyramid from a to b: a ring of `sides` vertices at `ringAt` (0..1) along the axis, pointed ends.
-- The cheapest limb (2 * sides triangles).
function LowPoly.SpindleTriangles(a: Vector3, b: Vector3, radius: number, sides: number?, ringAt: number?, flatten: number?, up: Vector3?): { TriangleWithInside }
	local n = sides or 3
	local axis = b - a
	local u, v = perpendiculars(axis, up)
	local center = a + axis * (ringAt or 0.45)
	local ring = {}
	for k = 0, n - 1 do
		local angle = k * math.pi * 2 / n
		ring[k] = center + u * (math.cos(angle) * radius) + v * (math.sin(angle) * radius * (flatten or 1))
	end
	local triangles = {}
	for k = 0, n - 1 do
		local k1 = (k + 1) % n
		table.insert(triangles, { A = ring[k], B = ring[k1], C = a, Inside = center })
		table.insert(triangles, { A = ring[k1], B = ring[k], C = b, Inside = center })
	end
	return triangles
end

-- Pyramid from a base centre to a tip (horns, beaks, pine trees, crystals).
function LowPoly.ConeTriangles(base: Vector3, tip: Vector3, radius: number, sides: number?, closed: boolean?, up: Vector3?): { TriangleWithInside }
	local n = sides or 4
	local axis = tip - base
	local u, v = perpendiculars(axis, up)
	local ring = {}
	for k = 0, n - 1 do
		local angle = k * math.pi * 2 / n
		ring[k] = base + u * (math.cos(angle) * radius) + v * (math.sin(angle) * radius)
	end
	local inside = base + axis * 0.25
	local triangles = {}
	for k = 0, n - 1 do
		table.insert(triangles, { A = ring[k], B = ring[(k + 1) % n], C = tip, Inside = inside })
	end
	if closed then
		local bottom = base - axis.Unit * radius * 0.15
		for k = 0, n - 1 do
			table.insert(triangles, { A = ring[(k + 1) % n], B = ring[k], C = bottom, Inside = inside })
		end
	end
	return triangles
end

--[[
	Convex polyhedron given by polygons (vertex index lists). Triangles stay as they are, larger
	polygons get a centre vertex pushed outwards by `bulge` so they become a fan of triangles
	instead of a flat face.
]]
function LowPoly.BulgedTriangles(vertices: { Vector3 }, polygons: { { number } }, bulge: number): { TriangleWithInside }
	local center = Vector3.zero
	for _, vertex in vertices do
		center += vertex
	end
	center /= #vertices
	local triangles = {}
	for _, polygon in polygons do
		if #polygon == 3 then
			table.insert(triangles, { A = vertices[polygon[1]], B = vertices[polygon[2]], C = vertices[polygon[3]], Inside = center })
		else
			local mid = Vector3.zero
			for _, index in polygon do
				mid += vertices[index]
			end
			mid /= #polygon
			local outwards = mid - center
			local apex = mid + (if outwards.Magnitude > 1e-6 then outwards.Unit * bulge else Vector3.zero)
			for i = 1, #polygon do
				local a = vertices[polygon[i]]
				local b = vertices[polygon[i % #polygon + 1]]
				table.insert(triangles, { A = a, B = b, C = apex, Inside = center })
			end
		end
	end
	return triangles
end

-- Box with every face turned into a shallow 4-triangle pyramid (24 triangles).
function LowPoly.BoxTriangles(cframe: CFrame, size: Vector3, bulge: number?): { TriangleWithInside }
	local h = size / 2
	local corners = {}
	for index, sign in
		{
			Vector3.new(-1, -1, -1),
			Vector3.new(1, -1, -1),
			Vector3.new(1, 1, -1),
			Vector3.new(-1, 1, -1),
			Vector3.new(-1, -1, 1),
			Vector3.new(1, -1, 1),
			Vector3.new(1, 1, 1),
			Vector3.new(-1, 1, 1),
		}
	do
		corners[index] = cframe:PointToWorldSpace(sign * h)
	end
	local polygons = { { 1, 2, 3, 4 }, { 6, 5, 8, 7 }, { 5, 1, 4, 8 }, { 2, 6, 7, 3 }, { 4, 3, 7, 8 }, { 5, 6, 2, 1 } }
	return LowPoly.BulgedTriangles(corners, polygons, bulge or math.min(size.X, size.Y, size.Z) * 0.12)
end

-- World helpers (anchored parts, for decor) ---------------------------------------------------

export type PartProps = {
	Color: Color3,
	Material: Enum.Material?,
	Transparency: number?,
	Thickness: number?,
	CanCollide: boolean?,
	CastShadow: boolean?,
	CollisionGroup: string?,
	Name: string?,
	Reflectance: number?,
}

local function makeWedge(wedge: Wedge, props: PartProps, parent: Instance): BasePart
	local part = Instance.new("WedgePart")
	part.Name = props.Name or "Facet"
	part.Size = wedge.Size
	part.CFrame = wedge.CFrame
	part.Color = props.Color
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Transparency = props.Transparency or 0
	part.Reflectance = props.Reflectance or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.CanTouch = false
	part.CanQuery = props.CanCollide ~= false
	part.CastShadow = props.CastShadow ~= false
	if props.CollisionGroup then
		part.CollisionGroup = props.CollisionGroup
	end
	part.Parent = parent
	return part
end

-- Default plate thickness for a world shape of this size.
local function defaultThickness(props: PartProps, size: number): number
	return props.Thickness or math.clamp(size * 0.08, 0.05, 1)
end

-- Draws a list of triangles; returns the created parts.
function LowPoly.DrawTriangles(triangles: { TriangleWithInside }, props: PartProps, parent: Instance, thickness: number?): { BasePart }
	local parts = {}
	local t = thickness or props.Thickness or 0.2
	for _, triangle in triangles do
		for _, wedge in LowPoly.TriangleWedges(triangle.A, triangle.B, triangle.C, t, triangle.Inside) do
			table.insert(parts, makeWedge(wedge, props, parent))
		end
	end
	return parts
end

-- One free-standing flat triangle (leaves, flags, wings...).
function LowPoly.Triangle(a: Vector3, b: Vector3, c: Vector3, props: PartProps, parent: Instance): { BasePart }
	return LowPoly.DrawTriangles({ { A = a, B = b, C = c } }, props, parent, props.Thickness or 0.1)
end

-- Low-poly ellipsoid (icosahedron, or octahedron with detail = 0). size = full extents.
function LowPoly.Ball(cframe: CFrame, size: Vector3, props: PartProps, parent: Instance, detail: number?): { BasePart }
	local data = if detail == 0 then LowPoly.Octahedron() else LowPoly.Icosahedron()
	local mesh = LowPoly.TransformMesh(data, cframe, size)
	local smallest = math.min(size.X, size.Y, size.Z)
	return LowPoly.DrawTriangles(LowPoly.MeshTriangles(mesh, cframe.Position), props, parent, defaultThickness(props, smallest))
end

-- Irregular rock. seed picks the shape.
function LowPoly.Rock(cframe: CFrame, size: Vector3, seed: number, props: PartProps, parent: Instance, roughness: number?): { BasePart }
	local mesh = LowPoly.TransformMesh(LowPoly.RockData(seed, roughness), cframe, size)
	local smallest = math.min(size.X, size.Y, size.Z)
	return LowPoly.DrawTriangles(LowPoly.MeshTriangles(mesh, cframe.Position), props, parent, defaultThickness(props, smallest))
end

function LowPoly.Tube(points: { Vector3 }, radii: { number }, props: PartProps, parent: Instance, options: TubeOptions?): { BasePart }
	local largest = 0
	for _, radius in radii do
		largest = math.max(largest, radius)
	end
	return LowPoly.DrawTriangles(LowPoly.TubeTriangles(points, radii, options), props, parent, defaultThickness(props, largest))
end

function LowPoly.Cone(base: Vector3, tip: Vector3, radius: number, props: PartProps, parent: Instance, sides: number?, closed: boolean?): { BasePart }
	return LowPoly.DrawTriangles(LowPoly.ConeTriangles(base, tip, radius, sides, closed), props, parent, defaultThickness(props, radius))
end

-- Faceted block (every face is a shallow pyramid, no flat face).
function LowPoly.Block(cframe: CFrame, size: Vector3, props: PartProps, parent: Instance, bulge: number?): { BasePart }
	local smallest = math.min(size.X, size.Y, size.Z)
	return LowPoly.DrawTriangles(LowPoly.BoxTriangles(cframe, size, bulge), props, parent, defaultThickness(props, smallest))
end

return LowPoly
