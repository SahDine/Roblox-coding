--[[
	CombatService
	Character setup (collision group, walk speed) and the Slap glove every
	player gets. A slap knocks the target back (applied by the target's
	client) and makes a thief drop the critter they carry (server-side).

	The glove is a big low-poly cartoon hand (golden and bigger with the
	MegaSlap pass). Every accepted swing, hit or miss, is sent to all clients
	(Remotes.SlapFx) and SlapController animates the arm going from the right
	to the left; the slapper's own client plays it as soon as they click.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)

local LowPoly = require(script.Parent.Parent.Modules.LowPoly)

local CombatService = {}

local SLAP = GameConfig.Slap

local MonetizationService, StealService

local lastSlap: { [Player]: number } = {}

local function setCollisionGroup(character: Model)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = "Players"
		end
	end
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = "Players"
		end
	end)
end

local function findTarget(player: Player, root: BasePart, range: number): (Player?, BasePart?)
	local best, bestRoot, bestDistance = nil, nil, math.huge
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local otherRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if other ~= player and otherRoot and humanoid and humanoid.Health > 0 then
			local offset = otherRoot.Position - root.Position
			local distance = offset.Magnitude
			if distance <= range and distance < bestDistance then
				local flat = Vector3.new(offset.X, 0, offset.Z)
				local facing = if flat.Magnitude > 0.1 then root.CFrame.LookVector:Dot(flat.Unit) else 1
				if facing > 0.2 or distance < 3.5 then
					best, bestRoot, bestDistance = other, otherRoot, distance
				end
			end
		end
	end
	return best, bestRoot
end

local function onSlap(player: Player, tool: Tool)
	local now = os.clock()
	if now - (lastSlap[player] or 0) < SLAP.Cooldown then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or tool.Parent ~= character then
		return
	end
	lastSlap[player] = now

	local mega = MonetizationService.OwnsPass(player, "MegaSlap")
	local target, targetRoot = findTarget(player, root, if mega then SLAP.MegaRange else SLAP.Range)

	-- Every client animates the right-to-left swing (SlapController), misses included, and on a hit
	-- plays the glove's HitSound when the hand reaches the front (played here, it would be heard by
	-- the others before the arm even swings). No "toolanim" value: the default Animate script's
	-- slash would fight the swing.
	Remotes.SlapFx:FireAllClients(player, target)
	if not target or not targetRoot then
		return
	end

	local power = if mega then SLAP.MegaKnockback else SLAP.Knockback
	local offset = targetRoot.Position - root.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local direction = if flat.Magnitude > 0.1 then flat.Unit else root.CFrame.LookVector
	local velocity = direction * power + Vector3.new(0, power * 0.45, 0)

	Remotes.Knockback:FireClient(target, velocity, SLAP.StunTime)
	StealService.OnSlapped(target, player)
end

-- Slap glove ------------------------------------------------------------------------------------
--[[
	A big cartoon hand (about 3x a normal hand) made of low-poly triangles. It is designed in the
	grip frame (the frame Roblox attaches tools to, at the end of the right arm, the same on R15 and
	R6): -Z runs from the wrist to the fingertips (along the arm), +Z goes up the arm (inside the
	cuff), +Y is the front of the arm and -X its inner side. The thumb is on +Y and the palm faces
	-X, the hand turned a little at the wrist (cocked back): in the default tool pose (arm held
	forward) the palm faces left with the thumb up, ready for a right-to-left slap.
]]

type GloveStyle = {
	HandScale: number, -- 1 = palm 1.6 studs wide, 2.7 long with the fingers
	CuffScale: number, -- 1 = just wide enough for a 1 x 1 arm
	Skin: Color3,
	SkinMaterial: Enum.Material,
	Cuff: Color3,
	CuffMaterial: Enum.Material,
	Trail: Color3,
	Gem: Color3?, -- crystal on the back of the hand
	Sparkles: boolean,
	WhooshSpeed: number,
	HitSpeed: number,
}

local GLOVES: { Normal: GloveStyle, Mega: GloveStyle } = {
	Normal = {
		HandScale = 1.12,
		CuffScale = 1,
		Skin = Color3.fromRGB(255, 205, 160),
		SkinMaterial = Enum.Material.SmoothPlastic,
		Cuff = Color3.fromRGB(225, 55, 55),
		CuffMaterial = Enum.Material.SmoothPlastic,
		Trail = Color3.fromRGB(255, 255, 255),
		Sparkles = false,
		WhooshSpeed = 1.05,
		HitSpeed = 1.5,
	},
	Mega = {
		HandScale = 1.45,
		CuffScale = 1.12,
		Skin = Color3.fromRGB(255, 198, 45),
		SkinMaterial = Enum.Material.Foil,
		Cuff = Color3.fromRGB(125, 50, 215),
		CuffMaterial = Enum.Material.SmoothPlastic,
		Trail = Color3.fromRGB(255, 220, 90),
		Gem = Color3.fromRGB(90, 235, 255),
		Sparkles = true,
		WhooshSpeed = 0.85,
		HitSpeed = 1.2,
	},
}

local WRIST_COCK = math.rad(-12) -- the fingers turn a little to the back of the hand

-- Hand space (wrist at the origin, before the cock): knuckle position, length, radius and how much
-- the finger spreads sideways (+Y = towards the thumb) over its length.
local FINGERS = {
	{ Y = 0.56, Z = -1.38, Length = 1.05, Radius = 0.23, Spread = 0.12 },
	{ Y = 0.19, Z = -1.52, Length = 1.15, Radius = 0.24, Spread = 0.02 },
	{ Y = -0.18, Z = -1.48, Length = 1.05, Radius = 0.23, Spread = -0.08 },
	{ Y = -0.52, Z = -1.32, Length = 0.85, Radius = 0.2, Spread = -0.2 },
}

-- Outline of the palm (Y, Z) from the wrist round the thumb side, the knuckles and back.
local PALM_OUTLINE = {
	Vector2.new(-0.52, 0),
	Vector2.new(0.52, 0),
	Vector2.new(0.84, -0.6),
	Vector2.new(0.8, -1.38),
	Vector2.new(0.2, -1.56),
	Vector2.new(-0.38, -1.52),
	Vector2.new(-0.74, -1.3),
	Vector2.new(-0.8, -0.6),
}

-- Hand space (unscaled, wrist at the origin) -> grip frame. The cuff is not cocked: it stays
-- around the arm.
local function wristFrame(style: GloveStyle): CFrame
	return CFrame.new(0, 0, -0.05 * style.CuffScale) * CFrame.Angles(0, WRIST_COCK, 0)
end

-- Builds the glove parts (welded to the returned Handle) and sets tool.Grip.
local function buildGlove(tool: Tool, style: GloveStyle): BasePart
	local scale = style.HandScale
	local cuffScale = style.CuffScale
	local wrist = wristFrame(style)
	local function hand(x: number, y: number, z: number): Vector3
		return wrist:PointToWorldSpace(Vector3.new(x, y, z) * scale)
	end

	-- Invisible handle over the palm (the sparkles are emitted from its volume).
	local handleCFrame = wrist * CFrame.new(0, 0.05 * scale, -0.85 * scale)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.7, 1.6, 1.7) * scale
	handle.CFrame = handleCFrame
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.CastShadow = false
	handle.Massless = true
	handle.CollisionGroup = "Players"
	handle.Parent = tool
	-- The grip point (end of the arm) is the origin of the design frame.
	tool.Grip = handleCFrame:Inverse()

	local skin: { LowPoly.TriangleWithInside } = {}
	-- Palm: a puffy lens, the outline fanned to a bulge on the palm side and one on the back.
	local palmCenter = hand(0, 0, -0.8)
	local palmBulge = hand(-0.4, 0.02, -0.8)
	local backBulge = hand(0.44, 0.02, -0.82)
	for index, point in PALM_OUTLINE do
		local nextPoint = PALM_OUTLINE[index % #PALM_OUTLINE + 1]
		local a, b = hand(0, point.X, point.Y), hand(0, nextPoint.X, nextPoint.Y)
		table.insert(skin, { A = a, B = b, C = palmBulge, Inside = palmCenter })
		table.insert(skin, { A = b, B = a, C = backBulge, Inside = palmCenter })
	end

	-- Fingers: a hidden root inside the palm, then a tapered tube curling a little towards the palm.
	local backOfHand = wrist:VectorToWorldSpace(Vector3.xAxis)
	local function digit(points: { Vector3 }, radii: { number })
		for _, triangle in LowPoly.TubeTriangles(points, radii, { Sides = 3, CapEnd = 0.6, Up = backOfHand }) do
			table.insert(skin, triangle)
		end
	end
	for _, finger in FINGERS do
		local tipY = finger.Y + finger.Spread * finger.Length
		local tipZ = finger.Z - finger.Length
		digit({
			hand(0, finger.Y * 0.8, finger.Z + 0.4),
			hand(0, finger.Y, finger.Z),
			hand(-0.06, (finger.Y + tipY) / 2, finger.Z - finger.Length * 0.55),
			hand(-0.16, tipY, tipZ),
		}, { 0, finger.Radius * scale, finger.Radius * 0.95 * scale, finger.Radius * 0.85 * scale })
	end
	-- Thumb: up and forward, along the side of the palm.
	digit({ hand(0, 0.42, -0.5), hand(-0.08, 0.86, -0.74), hand(-0.18, 1.18, -1.2) }, { 0, 0.26 * scale, 0.22 * scale })

	-- Cuff around the end of the arm, flared where the arm goes in.
	local cuff = LowPoly.TubeTriangles(
		{ Vector3.new(0, 0, 0.62) * cuffScale, Vector3.new(0, 0, -0.12) * cuffScale },
		{ 0.86 * cuffScale, 0.74 * cuffScale },
		{ Sides = 6, CapStart = 0.04, CapEnd = 0.04 }
	)

	local parts: { BasePart } = {}
	local function draw(triangles: { LowPoly.TriangleWithInside }, name: string, color: Color3, material: Enum.Material, thickness: number)
		local props: LowPoly.PartProps = {
			Name = name,
			Color = color,
			Material = material,
			CanCollide = false,
			CollisionGroup = "Players",
		}
		for _, part in LowPoly.DrawTriangles(triangles, props, tool, thickness) do
			table.insert(parts, part)
		end
	end
	draw(skin, "Glove", style.Skin, style.SkinMaterial, 0.08 * scale)
	draw(cuff, "Cuff", style.Cuff, style.CuffMaterial, 0.1 * cuffScale)
	if style.Gem then
		local gemCFrame = wrist * CFrame.new(Vector3.new(0.42, 0.04, -0.82) * scale)
		local gem = LowPoly.TransformMesh(LowPoly.Octahedron(), gemCFrame, Vector3.new(0.36, 0.62, 0.62) * scale)
		draw(LowPoly.MeshTriangles(gem), "Gem", style.Gem, Enum.Material.Neon, 0.06 * scale)
	end

	-- LowPoly makes anchored decor: turn the facets into weightless glove pieces.
	for _, part in parts do
		part.Anchored = false
		part.Massless = true
		part.CanTouch = false
		part.CanQuery = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
	end
	return handle
end

-- Swing trail (switched on by SlapController during the sweep) and the sounds.
local function addGloveEffects(handle: BasePart, style: GloveStyle)
	local scale = style.HandScale
	local wrist = wristFrame(style)
	local function attachment(name: string, point: Vector3): Attachment
		local attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.Position = handle.CFrame:PointToObjectSpace(wrist:PointToWorldSpace(point * scale))
		attachment.Parent = handle
		return attachment
	end

	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0 = attachment("TrailTip", Vector3.new(-0.1, 0.15, -2.45))
	trail.Attachment1 = attachment("TrailBase", Vector3.new(0, 0, -0.45))
	trail.Color = ColorSequence.new(style.Trail)
	trail.Transparency = NumberSequence.new(0.35, 1)
	trail.WidthScale = NumberSequence.new(1, 0.5)
	trail.LightEmission = 0.6
	trail.Lifetime = 0.16
	trail.MinLength = 0.05
	trail.FaceCamera = false
	trail.Enabled = false
	trail.Parent = handle

	if style.Sparkles then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "Sparkles"
		sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160))
		sparkles.LightEmission = 1
		sparkles.Rate = 9
		sparkles.Lifetime = NumberRange.new(0.5, 0.9)
		sparkles.Speed = NumberRange.new(0.5, 1.5)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.3, 0)
		sparkles.Parent = handle
	end

	-- Played by every client when the swing starts (SlapController).
	local whoosh = Instance.new("Sound")
	whoosh.Name = "Whoosh"
	whoosh.SoundId = GameConfig.Sounds.Slap
	whoosh.Volume = 0.55
	whoosh.PlaybackSpeed = style.WhooshSpeed
	whoosh.RollOffMaxDistance = 90
	whoosh.Parent = handle

	-- Played by every client when the slap lands (SlapController).
	local hit = Instance.new("Sound")
	hit.Name = "HitSound"
	hit.SoundId = GameConfig.Sounds.SlapHit
	hit.Volume = 0.9
	hit.PlaybackSpeed = style.HitSpeed
	hit.RollOffMaxDistance = 90
	hit.Parent = handle
end

local templates: { [boolean]: Tool } = {}

-- A ready-to-use Slap tool (not parented, no gameplay connection). Each glove is built once and
-- cloned for every character.
function CombatService.CreateSlapTool(mega: boolean): Tool
	local template = templates[mega]
	if not template then
		local style = if mega then GLOVES.Mega else GLOVES.Normal
		local tool = Instance.new("Tool")
		tool.Name = "Slap"
		tool.ToolTip = if mega then "Mega Slap!" else "Slap thieves to make them drop critters"
		tool.CanBeDropped = false
		tool.RequiresHandle = true
		tool:SetAttribute("Mega", mega)
		local handle = buildGlove(tool, style)
		addGloveEffects(handle, style)
		templates[mega] = tool
		template = tool
	end
	return template:Clone()
end

local function giveSlapTool(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack then
		return
	end
	local character = player.Character
	local wasEquipped = false
	for _, container in { backpack, character } do
		local old = container and container:FindFirstChild("Slap")
		if old then
			wasEquipped = wasEquipped or container == character
			old:Destroy()
		end
	end

	local tool = CombatService.CreateSlapTool(MonetizationService.OwnsPass(player, "MegaSlap"))
	tool.Activated:Connect(function()
		onSlap(player, tool)
	end)
	tool.Parent = backpack

	-- Upgraded to the Mega glove while holding the old one: keep it in hand.
	if wasEquipped and character and character.Parent then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid:EquipTool(tool)
		end
	end
end

-- Swaps the glove (held or in the backpack) when it no longer matches the MegaSlap pass: pass
-- bought, or the ownership check finished after the glove was given (slow web call). No glove yet:
-- the next CharacterAdded gives the right one.
local function refreshGlove(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	local glove = (backpack and backpack:FindFirstChild("Slap")) or (character and character:FindFirstChild("Slap"))
	if glove and glove:GetAttribute("Mega") ~= MonetizationService.OwnsPass(player, "MegaSlap") then
		giveSlapTool(player)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	setCollisionGroup(character)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.WalkSpeed = GameConfig.Player.WalkSpeed
	end
	giveSlapTool(player)
end

function CombatService.Init(services)
	MonetizationService = services.MonetizationService
	StealService = services.StealService
end

function CombatService.OnPlayerLoaded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	-- Set by MonetizationService when the pass check ends, which can be after the glove was given.
	player:GetAttributeChangedSignal("Pass_MegaSlap"):Connect(function()
		refreshGlove(player)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function CombatService.OnPlayerRemoving(player: Player)
	lastSlap[player] = nil
end

function CombatService.Start()
	MonetizationService.PassGranted:Connect(function(player, passKey)
		if passKey == "MegaSlap" then
			refreshGlove(player) -- no-op if the attribute change already swapped it
		end
	end)
end

return CombatService
