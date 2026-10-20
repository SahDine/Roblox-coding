--[[
	PlotService
	Builds the player bases (little fantasy castles), assigns one to each
	player, handles the base lock (magic shield), shows the base upgrade level
	(castle tiers) and teleports players home.

	Base layout (local space, -Z faces the conveyor):
	  the whole castle stands on a stone platform (FLOOR_TOP above the meadow) with a ramp at the gate,
	  gate + shield at the front, a lock button and an "Upgrade Base" station inside,
	  a 4x4 grid of pedestals, each with a collect pedestal (glowing button) in front of it,
	  stone walls with merlons, four square towers with pyramid roofs and flags.

	The terrain under every base is bare ground: the meadow's grass blades would poke through
	the floor and hide the collect pedestals.

	Upgrade tiers (GameConfig.BaseUpgrade.Tiers) recolour the walls, trims and roofs and add
	decorations built with LowPoly (banners, crystals, a crown...). Every player sees them, and
	the gems on the gate beam show the exact level.

	The shield's collision is handled on each client (owner walks through,
	others are blocked), the server only refuses steals while locked.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)

local Modules = script.Parent.Parent.Modules
local Decor = require(Modules.Decor)
local LowPoly = require(Modules.LowPoly)
local Notifier = require(Modules.Notifier)

local PlotService = {}

-- Fired with (player, plot, slotIndex) when an owner touches one of their collect pedestals.
PlotService.PadTouched = Signal.new()

export type Slot = {
	Index: number,
	Pedestal: BasePart,
	PedestalBase: BasePart,
	Glow: BasePart,
	Pad: BasePart, -- glowing button of the collect pedestal
	PadBase: BasePart, -- stone column of the collect pedestal
	PadCap: BasePart, -- trim cap of the collect pedestal (under the button)
	PadLabel: TextLabel,
	StandPosition: Vector3, -- top of the critter pedestal
	GroundPosition: Vector3, -- floor beside the collect pedestal (end of the walk home, see GetSlotPath)
	LastText: string?,
}

-- Parts repainted when the castle changes tier.
type Style = {
	Walls: { BasePart },
	Trims: { BasePart },
	Roofs: { BasePart },
	Tops: { BasePart },
	Gems: { BasePart },
	Decor: Instance?, -- decorations of the current tier (flags, banners, crystals...)
}

export type Plot = {
	Index: number,
	CFrame: CFrame,
	Model: Model,
	Color: Color3,
	Owner: Player?,
	LockedUntil: number,
	Level: number,
	TierIndex: number,
	Barrier: BasePart,
	OwnerLabel: TextLabel,
	StatusLabel: TextLabel,
	LevelLabel: TextLabel,
	LockLabel: TextLabel,
	LockPrompt: ProximityPrompt,
	UpgradeStation: BasePart,
	UpgradeTitle: TextLabel,
	UpgradeInfo: TextLabel,
	UpgradePrompt: ProximityPrompt,
	SpawnCFrame: CFrame,
	Slots: { Slot },
	Style: Style,
}

type Palette = {
	Wall: Color3,
	WallMaterial: Enum.Material,
	Trim: Color3,
	TrimMaterial: Enum.Material,
	Roof: Color3,
	RoofMaterial: Enum.Material,
	Top: Color3, -- top of the critter pedestals
	TopMaterial: Enum.Material,
	Accent: Color3, -- emblems and crystals
	FlagLength: number,
}

local MAP = GameConfig.Map
local WIDTH, DEPTH = MAP.PlotWidth, MAP.PlotDepth
local FLOOR_TOP = 1.8 -- height of the courtyard floor (top of the stone platform)
local COLUMNS = { -21, -7, 7, 21 }
local ROWS = { -14, 1, 16, 31 }
local ENTRANCE_WIDTH = 16
local WALL_HEIGHT = 10
local GATE_Z = -DEPTH / 2 + 0.75
local PEDESTAL_TOP = FLOOR_TOP + 1.3
local COLLECT_OFFSET = 5.7 -- distance from a critter pedestal to its collect pedestal (towards the gate)
local COLLECT_HEIGHT = 1 -- height of the collect pedestal's column (cap and button on top)
local ROW_AISLE = 3.2 -- walking critters follow the aisle this far in front of a row of collect pedestals
local WALK_SIDE = 2.9 -- ...and end their walk beside their collect pedestal (on the central aisle's side)
local RAMP_LENGTH = 7
local TERRAIN_MARGIN = 4 -- bare ground around the base
local STATION_Z = -DEPTH / 2 + 8 -- lock button and upgrade station, on each side of the gate plaza
local TOWER_SIZE = 8
local TOWER_TOP = FLOOR_TOP + WALL_HEIGHT + 5
local ROOF_HEIGHT = 7
local SIGN_Y = FLOOR_TOP + WALL_HEIGHT + 8.2
local SIGN_SIZE = Vector3.new(26, 6, 0.6)
local CORNERS = { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) }

local STONE = Color3.fromRGB(175, 170, 180)
local FOUNDATION = Color3.fromRGB(110, 104, 118)
local COURTYARD = Color3.fromRGB(198, 190, 176)
local PATH = Color3.fromRGB(165, 156, 146)
local WOOD = Color3.fromRGB(125, 88, 62)
local GOLD = Color3.fromRGB(255, 200, 70)
local CRYSTAL = Color3.fromRGB(140, 225, 255)
local BUSH = Color3.fromRGB(95, 170, 85)
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local PAD_IDLE = Color3.fromRGB(90, 90, 100)
local PAD_READY = Color3.fromRGB(60, 220, 90)
local GEM_OFF = Color3.fromRGB(60, 55, 75)

local PLOT_COLORS = {
	Color3.fromRGB(255, 95, 95),
	Color3.fromRGB(255, 165, 60),
	Color3.fromRGB(250, 215, 70),
	Color3.fromRGB(110, 210, 110),
	Color3.fromRGB(80, 190, 255),
	Color3.fromRGB(120, 120, 255),
	Color3.fromRGB(200, 110, 255),
	Color3.fromRGB(255, 120, 200),
}

local StealService, MonetizationService

local plots: { Plot } = {}
local plotByPlayer: { [Player]: Plot } = {}
local lastTeleport: { [Player]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function makeText(parent: Instance, text: string, color: Color3, size: UDim2, position: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Parent = parent
	return label
end

-- Props of a LowPoly decoration (never in the way: players and critters pass through).
local function facets(name: string, color: Color3, material: Enum.Material?, thickness: number?): LowPoly.PartProps
	return {
		Name = name,
		Color = color,
		Material = material,
		Thickness = thickness,
		CanCollide = false,
		CollisionGroup = "Decor",
	}
end

-- Tier looks ------------------------------------------------------------------------------------

local function getPalette(tierIndex: number, color: Color3): Palette
	if tierIndex >= 4 then -- Golden Palace
		return {
			Wall = Color3.fromRGB(244, 238, 226),
			WallMaterial = Enum.Material.Marble,
			Trim = GOLD,
			TrimMaterial = Enum.Material.Foil,
			Roof = GOLD,
			RoofMaterial = Enum.Material.Foil,
			Top = GOLD:Lerp(WHITE, 0.25),
			TopMaterial = Enum.Material.Foil,
			Accent = GOLD,
			FlagLength = 4.4,
		}
	elseif tierIndex == 3 then -- Crystal Citadel
		local crystal = CRYSTAL:Lerp(color, 0.3)
		return {
			Wall = Color3.fromRGB(82, 76, 118):Lerp(color, 0.15),
			WallMaterial = Enum.Material.Slate,
			Trim = crystal,
			TrimMaterial = Enum.Material.Neon,
			Roof = crystal:Lerp(Color3.fromRGB(70, 60, 140), 0.3),
			RoofMaterial = Enum.Material.Glass,
			Top = crystal:Lerp(WHITE, 0.45),
			TopMaterial = Enum.Material.Marble,
			Accent = crystal,
			FlagLength = 3.6,
		}
	elseif tierIndex == 2 then -- Royal Castle: polished stone
		return {
			Wall = Color3.fromRGB(230, 224, 212):Lerp(color, 0.1),
			WallMaterial = Enum.Material.Marble,
			Trim = color,
			TrimMaterial = Enum.Material.SmoothPlastic,
			Roof = color:Lerp(BLACK, 0.12),
			RoofMaterial = Enum.Material.SmoothPlastic,
			Top = color:Lerp(WHITE, 0.6),
			TopMaterial = Enum.Material.Marble,
			Accent = GOLD,
			FlagLength = 3.6,
		}
	end
	return { -- Stone Keep: wood and stone
		Wall = STONE:Lerp(color, 0.12),
		WallMaterial = Enum.Material.Cobblestone,
		Trim = WOOD,
		TrimMaterial = Enum.Material.Wood,
		Roof = color:Lerp(Color3.fromRGB(80, 55, 40), 0.3),
		RoofMaterial = Enum.Material.WoodPlanks,
		Top = color:Lerp(WHITE, 0.55),
		TopMaterial = Enum.Material.Marble,
		Accent = color:Lerp(WHITE, 0.4),
		FlagLength = 2.6,
	}
end

-- Decorations of a tier, rebuilt when the tier changes. Everything here is cosmetic.
local function buildTierDecor(plot: Plot, tierIndex: number, palette: Palette): Model
	local folder = Instance.new("Model")
	folder.Name = "TierDecor"
	local cframe = plot.CFrame
	local color = plot.Color

	local function point(x: number, y: number, z: number): Vector3
		return (cframe * CFrame.new(x, y, z)).Position
	end
	local function part(props, offset: CFrame): BasePart
		props.CFrame = cframe * offset
		props.CanCollide = false
		props.CanQuery = false
		props.CanTouch = false
		return Decor.Part(props, folder)
	end

	-- Flags on the four towers, flying outwards (bigger with every tier).
	local flagLength = palette.FlagLength
	local flagHeight = flagLength * 0.6
	local poleBottom = TOWER_TOP + 1 + ROOF_HEIGHT - 0.6
	for _, corner in CORNERS do
		local x, z = corner.X * (WIDTH / 2 - 1), corner.Z * (DEPTH / 2 - 1)
		local poleHeight = 2.5 + flagHeight
		part({
			Name = "FlagPole",
			Size = Vector3.new(0.3, poleHeight, 0.3),
			Color = if tierIndex >= 4 then GOLD else Color3.fromRGB(80, 70, 60),
			Material = if tierIndex >= 4 then Enum.Material.Foil else Enum.Material.Wood,
		}, CFrame.new(x, poleBottom + poleHeight / 2, z))
		local top = poleBottom + poleHeight - 0.15
		LowPoly.Triangle(
			point(x, top, z),
			point(x, top - flagHeight, z),
			point(x + corner.X * flagLength, top - flagHeight / 2, z),
			facets("Flag", color, Enum.Material.Fabric),
			folder
		)
		if tierIndex >= 3 then
			local crystal = LowPoly.Ball(
				cframe * CFrame.new(x, top + 1.3, z),
				Vector3.new(1.3, 2.4, 1.3),
				facets("TowerCrystal", palette.Accent, Enum.Material.Neon),
				folder,
				0
			)
			if corner.Z < 0 and crystal[1] then
				Decor.Light(crystal[1], palette.Accent, 18, 1.2)
			end
		end
	end

	-- Banners hanging outside the walls (Royal Castle and above).
	if tierIndex >= 2 then
		local top = FLOOR_TOP + WALL_HEIGHT - 0.5
		for _, anchor in
			{
				CFrame.new(-22, top, -DEPTH / 2),
				CFrame.new(22, top, -DEPTH / 2),
				CFrame.new(-WIDTH / 2, top, 0) * CFrame.Angles(0, math.rad(90), 0),
				CFrame.new(WIDTH / 2, top, 0) * CFrame.Angles(0, math.rad(-90), 0),
			}
		do
			-- Local space of a banner: -Z points away from the wall.
			local function at(x: number, y: number): Vector3
				return (cframe * anchor * CFrame.new(x, y, -0.15)).Position
			end
			part(
				{ Name = "BannerRod", Size = Vector3.new(4.2, 0.3, 0.3), Color = palette.Trim, Material = palette.TrimMaterial },
				anchor * CFrame.new(0, 0.1, -0.25)
			)
			part(
				{ Name = "BannerCloth", Size = Vector3.new(3.4, 5, 0.12), Color = color, Material = Enum.Material.Fabric },
				anchor * CFrame.new(0, -2.5, -0.15)
			)
			-- Swallowtail: two right triangles (one wedge each).
			LowPoly.Triangle(at(-1.7, -5), at(-1.7, -6.6), at(0, -5), facets("BannerTail", color, Enum.Material.Fabric, 0.12), folder)
			LowPoly.Triangle(at(1.7, -5), at(0, -5), at(1.7, -6.6), facets("BannerTail", color, Enum.Material.Fabric, 0.12), folder)
			part({
				Name = "BannerEmblem",
				Size = Vector3.new(1.4, 1.4, 0.15),
				Color = palette.Accent,
				Material = Enum.Material.Neon,
				CastShadow = false,
			}, anchor * CFrame.new(0, -2.4, -0.28) * CFrame.Angles(0, 0, math.rad(45)))
		end
	end

	-- At the foot of the ramp: low-poly bushes, then glowing crystal clusters (Crystal Citadel and above).
	for _, side in { -1, 1 } do
		local x, z = side * (ENTRANCE_WIDTH / 2 + 4.8), -DEPTH / 2 - 2.6
		if tierIndex >= 3 then
			local shards = { { 0, 0, 4.4, 0.95 }, { 1.2, 0.7, 3, 0.75 }, { -1, 0.9, 2.4, 0.6 } }
			for _, shard in shards do
				local base = point(x + shard[1] * side, -0.3, z + shard[2])
				local lean = cframe:VectorToWorldSpace(Vector3.new(shard[1] * side * 0.3, 1, shard[2] * 0.25).Unit)
				LowPoly.DrawTriangles(
					LowPoly.ConeTriangles(base, base + lean * shard[3], shard[4], 3),
					facets("GateCrystal", palette.Accent, Enum.Material.Glass),
					folder,
					0.2
				)
			end
			local glow = part({
				Name = "GateCrystalGlow",
				Size = Vector3.new(0.6, 2.4, 0.6),
				Color = palette.Accent,
				Material = Enum.Material.Neon,
				CastShadow = false,
			}, CFrame.new(x, 1.2, z))
			Decor.Light(glow, palette.Accent, 14, 1.2)
		else
			local mesh = LowPoly.TransformMesh(
				LowPoly.Bipyramid(5, 0.15),
				cframe * CFrame.new(x, 1, z) * CFrame.Angles(0, side * 0.4, 0),
				Vector3.new(3.8, 2.8, 3.8)
			)
			LowPoly.DrawTriangles(LowPoly.MeshTriangles(mesh), facets("Bush", BUSH), folder, 0.25)
		end
	end

	-- Golden Palace: a crown on the gate sign, a royal flag and golden sparkles.
	if tierIndex >= 4 then
		local signTop = SIGN_Y + SIGN_SIZE.Y / 2
		local z = GATE_Z - 1.2
		part(
			{ Name = "CrownBand", Size = Vector3.new(8.4, 1.3, 0.8), Color = GOLD, Material = Enum.Material.Foil },
			CFrame.new(0, signTop + 0.65, z)
		)
		for spike, height in { 1.8, 2.5, 3.2, 2.5, 1.8 } do
			local x = (spike - 3) * 1.65
			local baseY = signTop + 1.3
			LowPoly.Triangle(
				point(x - 0.82, baseY, z),
				point(x + 0.82, baseY, z),
				point(x, baseY + height, z),
				facets("CrownSpike", GOLD, Enum.Material.Foil, 0.6),
				folder
			)
			part({
				Name = "CrownGem",
				Size = Vector3.new(0.6, 0.6, 0.6),
				Color = if spike % 2 == 0 then Color3.fromRGB(80, 160, 255) else Color3.fromRGB(255, 70, 90),
				Material = Enum.Material.Neon,
				CastShadow = false,
			}, CFrame.new(x, baseY + height + 0.2, z) * CFrame.Angles(0, 0, math.rad(45)))
		end

		local poleBase = FLOOR_TOP + WALL_HEIGHT + 0.7
		part(
			{ Name = "RoyalPole", Size = Vector3.new(0.5, 15, 0.5), Color = GOLD, Material = Enum.Material.Foil },
			CFrame.new(0, poleBase + 7.5, DEPTH / 2 - 0.75)
		)
		part(
			{ Name = "RoyalPoleTip", Size = Vector3.new(1, 1, 1), Color = GOLD, Material = Enum.Material.Neon },
			CFrame.new(0, poleBase + 15.3, DEPTH / 2 - 0.75) * CFrame.Angles(math.rad(45), 0, math.rad(45))
		)
		LowPoly.Triangle(
			point(0, poleBase + 14.6, DEPTH / 2 - 0.75),
			point(0, poleBase + 9.4, DEPTH / 2 - 0.75),
			point(8.5, poleBase + 12, DEPTH / 2 - 0.75),
			facets("RoyalFlag", color, Enum.Material.Fabric, 0.15),
			folder
		)

		local sparkleArea = part({
			Name = "GoldSparkles",
			Size = Vector3.new(SIGN_SIZE.X, 3, 3),
			Transparency = 1,
			CastShadow = false,
		}, CFrame.new(0, signTop + 1.5, z))
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Color = ColorSequence.new(GOLD, WHITE)
		sparkles.LightEmission = 1
		sparkles.Rate = 8
		sparkles.Lifetime = NumberRange.new(1, 2)
		sparkles.Speed = NumberRange.new(0.5, 1.5)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.35, 0)
		sparkles.Parent = sparkleArea
	end

	return folder
end

-- Repaints the castle and rebuilds the tier decorations.
local function applyTier(plot: Plot, tierIndex: number)
	local palette = getPalette(tierIndex, plot.Color)
	local style = plot.Style
	local function paint(parts: { BasePart }, color: Color3, material: Enum.Material)
		for _, part in parts do
			part.Color = color
			part.Material = material
		end
	end
	paint(style.Walls, palette.Wall, palette.WallMaterial)
	paint(style.Trims, palette.Trim, palette.TrimMaterial)
	paint(style.Roofs, palette.Roof, palette.RoofMaterial)
	paint(style.Tops, palette.Top, palette.TopMaterial)

	if style.Decor then
		style.Decor:Destroy()
	end
	local decor = buildTierDecor(plot, tierIndex, palette)
	decor.Parent = plot.Model
	style.Decor = decor
end

-- Texts that depend on the owner and on the level (sign, upgrade station, prompts).
local function refreshLevelTexts(plot: Plot)
	local level = plot.Level
	local isMax = level >= GameConfig.BaseUpgrade.MaxLevel
	local owned = plot.Owner ~= nil
	local _, tier = Economy.GetBaseTier(level)

	plot.LevelLabel.Text = if owned then `⭐ Lv {level}` else ""
	plot.LevelLabel.TextColor3 = tier.Color
	plot.UpgradeTitle.Text = if not owned then "" elseif isMax then "👑 MAX LEVEL" else "🏰 UPGRADE BASE"
	plot.UpgradeInfo.Text = if owned then `Lv {level} • {tier.Name}` else ""
	plot.UpgradeInfo.TextColor3 = tier.Color
	plot.UpgradePrompt.ObjectText = if isMax then "Max level" else `Level {level} → {level + 1}`
	plot.LockPrompt.ObjectText = `{Economy.GetLockDuration(level)}s`
end

-- The meadow's grass blades would poke through the base: the terrain under the base (and a few
-- studs around it, ramp included) becomes bare ground with nothing above it.
local function clearTerrain(cframe: CFrame)
	local terrain = workspace.Terrain
	local size = Vector3.new(WIDTH + TERRAIN_MARGIN * 2, 4, DEPTH + RAMP_LENGTH + TERRAIN_MARGIN * 2)
	local center = cframe * CFrame.new(0, -2, -RAMP_LENGTH / 2)
	terrain:FillBlock(center, size, Enum.Material.Ground)
	terrain:FillBlock(center * CFrame.new(0, 32, 0), Vector3.new(size.X, 60, size.Z), Enum.Material.Air)
end

-- Base ----------------------------------------------------------------------------------------------

local function buildPlot(index: number, cframe: CFrame, folder: Folder): Plot
	local color = PLOT_COLORS[(index - 1) % #PLOT_COLORS + 1]
	local palette = getPalette(1, color)
	local style: Style = { Walls = {}, Trims = {}, Roofs = {}, Tops = {}, Gems = {}, Decor = nil }

	local model = Instance.new("Model")
	model.Name = "Plot_" .. index
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("BaseLevel", 1)

	local function add(props, offset: CFrame): BasePart
		props.CFrame = cframe * offset
		return Decor.Part(props, model)
	end
	local function world(x: number, y: number, z: number): Vector3
		return (cframe * CFrame.new(x, y, z)).Position
	end
	local function styled(list: { BasePart }, part: BasePart): BasePart
		table.insert(list, part)
		return part
	end

	-- Stone platform + ramp ---------------------------------------------------------------------
	-- The courtyard floor stands FLOOR_TOP above the meadow (its grass never hides the base).
	local floor = add({
		Name = "Floor",
		Size = Vector3.new(WIDTH, FLOOR_TOP + 1.2, DEPTH),
		Color = COURTYARD,
		Material = Enum.Material.Pavement,
	}, CFrame.new(0, (FLOOR_TOP - 1.2) / 2, 0))
	floor.CollisionGroup = "Default" -- critters walk on it
	add({
		Name = "Foundation",
		Size = Vector3.new(WIDTH + 1.6, 1.3, DEPTH + 1.6),
		Color = FOUNDATION,
		Material = Enum.Material.Slate,
	}, CFrame.new(0, -0.05, 0))

	-- WedgePart: high side at local +Z, i.e. at the gate.
	local rampZ = -DEPTH / 2 - RAMP_LENGTH / 2
	local ramp = add({
		ClassName = "WedgePart",
		Name = "Ramp",
		Size = Vector3.new(ENTRANCE_WIDTH, FLOOR_TOP, RAMP_LENGTH),
		Color = COURTYARD,
		Material = Enum.Material.Pavement,
	}, CFrame.new(0, FLOOR_TOP / 2, rampZ))
	ramp.CollisionGroup = "Default" -- critters walk up it too
	for _, side in { -1, 1 } do
		-- Overlaps the ramp by 0.1: its inner face must not lie in the gate pillar's face (z-fighting).
		add({
			ClassName = "WedgePart",
			Name = "RampSide",
			Size = Vector3.new(1.4, FLOOR_TOP + 0.6, RAMP_LENGTH),
			Color = FOUNDATION,
			Material = Enum.Material.Slate,
		}, CFrame.new(side * (ENTRANCE_WIDTH / 2 + 0.6), (FLOOR_TOP + 0.6) / 2, rampZ))
		Decor.Torch(model, world(side * (ENTRANCE_WIDTH / 2 + 2.4), 0, -DEPTH / 2 - RAMP_LENGTH + 0.8), 5)
	end

	-- Courtyard ----------------------------------------------------------------------------------
	add({
		Name = "Carpet",
		Size = Vector3.new(5, 0.08, DEPTH - 17),
		Color = color:Lerp(BLACK, 0.2),
		Material = Enum.Material.Fabric,
		CanCollide = false,
	}, CFrame.new(0, FLOOR_TOP + 0.04, 6.5))
	add({
		Name = "Plaza",
		Size = Vector3.new(ENTRANCE_WIDTH + 14, 0.06, 14),
		Color = PATH,
		Material = Enum.Material.Cobblestone,
		CanCollide = false,
	}, CFrame.new(0, FLOOR_TOP + 0.03, -DEPTH / 2 + 8))

	-- Walls with a trim and merlons ----------------------------------------------------------------
	local wallY = FLOOR_TOP + WALL_HEIGHT / 2
	-- The two front walls end 1 stud inside the gate pillars: their end faces (and the trims') must
	-- not lie in the pillars' inner faces, which would flicker in the gateway (z-fighting).
	local sideWidth = (WIDTH - ENTRANCE_WIDTH) / 2 - 1
	local walls = {
		{ Vector3.new(WIDTH, 0, 0), Vector3.new(0, 0, DEPTH / 2 - 0.75) },
		{ Vector3.new(0, 0, DEPTH), Vector3.new(-WIDTH / 2 + 0.75, 0, 0) },
		{ Vector3.new(0, 0, DEPTH), Vector3.new(WIDTH / 2 - 0.75, 0, 0) },
		{ Vector3.new(sideWidth, 0, 0), Vector3.new(-(WIDTH / 2 - sideWidth / 2), 0, -DEPTH / 2 + 0.75) },
		{ Vector3.new(sideWidth, 0, 0), Vector3.new(WIDTH / 2 - sideWidth / 2, 0, -DEPTH / 2 + 0.75) },
	}
	for wallIndex, wall in walls do
		local length = math.max(wall[1].X, wall[1].Z)
		local alongX = wall[1].X > 0
		local size = if alongX then Vector3.new(length, WALL_HEIGHT, 1.5) else Vector3.new(1.5, WALL_HEIGHT, length)
		styled(
			style.Walls,
			add(
				{ Name = "Wall" .. wallIndex, Size = size, Color = palette.Wall, Material = palette.WallMaterial },
				CFrame.new(wall[2] + Vector3.new(0, wallY, 0))
			)
		)
		styled(
			style.Trims,
			add({
				Name = "Trim",
				Size = if alongX then Vector3.new(length, 0.7, 1.8) else Vector3.new(1.8, 0.7, length),
				Color = palette.Trim,
				Material = palette.TrimMaterial,
			}, CFrame.new(wall[2] + Vector3.new(0, FLOOR_TOP + WALL_HEIGHT + 0.35, 0)))
		)
		local count = math.floor(length / 5)
		for merlon = 0, count - 1 do
			local offset = (merlon - (count - 1) / 2) * 5
			local position = wall[2] + (if alongX then Vector3.new(offset, 0, 0) else Vector3.new(0, 0, offset))
			styled(
				style.Walls,
				add({
					Name = "Merlon",
					Size = Vector3.new(2.2, 1.6, 1.6),
					Color = palette.Wall,
					Material = palette.WallMaterial,
				}, CFrame.new(position + Vector3.new(0, FLOOR_TOP + WALL_HEIGHT + 1.5, 0)))
			)
		end
	end

	-- Square corner towers with low-poly pyramid roofs -----------------------------------------------
	local diagonal = cframe:VectorToWorldSpace(Vector3.new(1, 0, 1).Unit)
	for _, corner in CORNERS do
		local x, z = corner.X * (WIDTH / 2 - 1), corner.Z * (DEPTH / 2 - 1)
		local height = TOWER_TOP + 0.5
		styled(
			style.Walls,
			add({
				Name = "Tower",
				Size = Vector3.new(TOWER_SIZE, height, TOWER_SIZE),
				Color = palette.Wall,
				Material = palette.WallMaterial,
			}, CFrame.new(x, height / 2 - 0.5, z))
		)
		styled(
			style.Trims,
			add({
				Name = "TowerRing",
				Size = Vector3.new(TOWER_SIZE + 1.2, 1, TOWER_SIZE + 1.2),
				Color = palette.Trim,
				Material = palette.TrimMaterial,
			}, CFrame.new(x, TOWER_TOP + 0.5, z))
		)
		-- 4 triangles whose corners line up with the tower's corners.
		local roofBase = world(x, TOWER_TOP + 1, z)
		local triangles = LowPoly.ConeTriangles(
			roofBase,
			roofBase + cframe.UpVector * ROOF_HEIGHT,
			(TOWER_SIZE + 1.8) / 2 * math.sqrt(2),
			4,
			false,
			diagonal
		)
		for _, part in
			LowPoly.DrawTriangles(
				triangles,
				{ Name = "Roof", Color = palette.Roof, Material = palette.RoofMaterial, CollisionGroup = "Decor" },
				model,
				0.35
			)
		do
			table.insert(style.Roofs, part)
		end
		if corner.Z < 0 then
			local window = add({
				Name = "Window",
				Size = Vector3.new(1.6, 2.4, 0.3),
				Color = Color3.fromRGB(255, 210, 120),
				Material = Enum.Material.Neon,
				CanCollide = false,
			}, CFrame.new(x, FLOOR_TOP + WALL_HEIGHT + 1, z - TOWER_SIZE / 2 - 0.1))
			Decor.Light(window, Color3.fromRGB(255, 200, 120), 10, 1)
		end
	end

	-- Gate -----------------------------------------------------------------------------------------
	for _, side in { -1, 1 } do
		local height = FLOOR_TOP + WALL_HEIGHT + 5
		styled(
			style.Walls,
			add({
				Name = "GatePillar",
				Size = Vector3.new(3.5, height, 3.5),
				Color = palette.Wall,
				Material = palette.WallMaterial,
			}, CFrame.new(side * (ENTRANCE_WIDTH / 2 + 1.75), height / 2, GATE_Z))
		)
	end
	-- The beam is a bit wider, deeper and taller than the pillars it rests on (bottom at the top of the
	-- shield): no face of it lies in a pillar face, which would flicker (z-fighting).
	local beamY = FLOOR_TOP + WALL_HEIGHT + 4
	styled(
		style.Trims,
		add({
			Name = "GateBeam",
			Size = Vector3.new(ENTRANCE_WIDTH + 7.4, 2.4, 3.9),
			Color = palette.Trim,
			Material = palette.TrimMaterial,
		}, CFrame.new(0, beamY, GATE_Z))
	)

	-- One gem per level on the gate beam: lit gems show the base level to everybody. Gem 1 is at
	-- local +X, i.e. on the left of someone facing the gate, so the row fills from left to right.
	local maxLevel = GameConfig.BaseUpgrade.MaxLevel
	local gemSpacing = math.min(1.9, (ENTRANCE_WIDTH + 5) / maxLevel)
	for gem = 1, maxLevel do
		styled(
			style.Gems,
			add({
				Name = "LevelGem",
				Size = Vector3.new(0.9, 0.9, 0.4),
				Color = GEM_OFF,
				Material = Enum.Material.Slate,
				CanCollide = false,
				CastShadow = false,
			}, CFrame.new(((maxLevel + 1) / 2 - gem) * gemSpacing, beamY, GATE_Z - 2.05) * CFrame.Angles(0, 0, math.rad(45)))
		)
	end

	-- Magic shield (collision is client-side, see WorldController).
	local barrier = add({
		Name = "Barrier",
		Size = Vector3.new(ENTRANCE_WIDTH, WALL_HEIGHT + 2.8, 0.5),
		Color = Color3.fromRGB(255, 70, 90),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	}, CFrame.new(0, FLOOR_TOP + (WALL_HEIGHT + 2.8) / 2, GATE_Z))
	barrier:SetAttribute("OwnerUserId", 0)
	barrier:SetAttribute("Locked", false)

	-- Sign above the gate (owner, level, lock status) in a trim frame.
	styled(
		style.Trims,
		add({
			Name = "SignFrame",
			Size = SIGN_SIZE + Vector3.new(1.2, 1.2, -0.2),
			Color = palette.Trim,
			Material = palette.TrimMaterial,
		}, CFrame.new(0, SIGN_Y, GATE_Z - 0.85))
	)
	local sign = add({
		Name = "Sign",
		Size = SIGN_SIZE,
		Color = Color3.fromRGB(45, 35, 55),
		Material = Enum.Material.Wood,
	}, CFrame.new(0, SIGN_Y, GATE_Z - 1.2))
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 20
	signGui.LightInfluence = 0
	signGui.Parent = sign
	local ownerLabel = makeText(signGui, "Empty Base", WHITE, UDim2.fromScale(0.94, 0.58), UDim2.fromScale(0.03, 0.04))
	local levelLabel = makeText(signGui, "", GOLD, UDim2.fromScale(0.3, 0.32), UDim2.fromScale(0.04, 0.64))
	local statusLabel = makeText(signGui, "", Color3.fromRGB(200, 200, 200), UDim2.fromScale(0.6, 0.32), UDim2.fromScale(0.36, 0.64))

	-- Lock button (an enchanted rune stone) on the left of the gate plaza.
	add({
		Name = "LockBase",
		Size = Vector3.new(4.4, 1, 4.4),
		Color = FOUNDATION,
		Material = Enum.Material.Slate,
	}, CFrame.new(-16, FLOOR_TOP + 0.5, STATION_Z))
	local lockButton = add({
		Name = "LockButton",
		Size = Vector3.new(3.2, 0.5, 3.2),
		Color = Color3.fromRGB(230, 60, 80),
		Material = Enum.Material.Neon,
	}, CFrame.new(-16, FLOOR_TOP + 1.25, STATION_Z))
	local lockGui = Instance.new("BillboardGui")
	lockGui.Size = UDim2.fromScale(6, 2)
	lockGui.StudsOffset = Vector3.new(0, 3, 0)
	lockGui.MaxDistance = 80
	lockGui.LightInfluence = 0
	lockGui.Parent = lockButton
	local lockLabel = makeText(lockGui, "🔓 LOCK BASE", WHITE, UDim2.fromScale(1, 1), UDim2.new())

	local lockPrompt = Instance.new("ProximityPrompt")
	lockPrompt.Name = "LockPrompt"
	lockPrompt.ActionText = "Lock Base"
	lockPrompt.ObjectText = `{GameConfig.Lock.Duration}s`
	lockPrompt.HoldDuration = 0
	lockPrompt.MaxActivationDistance = 10
	lockPrompt.RequiresLineOfSight = false
	lockPrompt:SetAttribute("Kind", "Lock")
	lockPrompt:SetAttribute("OwnerUserId", 0)
	lockPrompt.Parent = lockButton

	-- Upgrade station (a floating crystal on an altar) on the right of the gate plaza.
	-- Its prompt only opens the upgrade window (UpgradeController), the purchase goes through
	-- Remotes.UpgradeBase.
	local station = styled(
		style.Walls,
		add({
			Name = "UpgradeStation",
			Size = Vector3.new(4.4, 1.6, 4.4),
			Color = palette.Wall,
			Material = palette.WallMaterial,
		}, CFrame.new(16, FLOOR_TOP + 0.8, STATION_Z))
	)
	styled(
		style.Trims,
		add({
			Name = "UpgradeStationTop",
			Size = Vector3.new(4.9, 0.3, 4.9),
			Color = palette.Trim,
			Material = palette.TrimMaterial,
		}, CFrame.new(16, FLOOR_TOP + 1.75, STATION_Z))
	)
	local upgradeCrystal = LowPoly.Ball(
		cframe * CFrame.new(16, FLOOR_TOP + 4.4, STATION_Z),
		Vector3.new(1.8, 3.2, 1.8),
		facets("UpgradeCrystal", GOLD, Enum.Material.Neon),
		model,
		0
	)
	if upgradeCrystal[1] then
		Decor.Light(upgradeCrystal[1], GOLD, 14, 1.4)
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Color = ColorSequence.new(GOLD, WHITE)
		sparkles.LightEmission = 1
		sparkles.Rate = 4
		sparkles.Lifetime = NumberRange.new(1, 1.8)
		sparkles.Speed = NumberRange.new(0.6, 1.4)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.3, 0)
		sparkles.Parent = upgradeCrystal[1]
	end
	-- Three golden shards growing out of the altar around the floating crystal.
	for shard = 0, 2 do
		local angle = shard * math.pi * 2 / 3 + 0.5
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local base = world(16 + direction.X * 1.55, FLOOR_TOP + 1.7, STATION_Z + direction.Z * 1.55)
		local lean = cframe:VectorToWorldSpace((direction * 0.35 + Vector3.yAxis).Unit)
		LowPoly.DrawTriangles(
			LowPoly.ConeTriangles(base, base + lean * (1.6 + shard * 0.4), 0.6, 3),
			facets("UpgradeShard", GOLD, Enum.Material.Glass),
			model,
			0.15
		)
	end
	local upgradeGui = Instance.new("BillboardGui")
	upgradeGui.Size = UDim2.fromScale(8, 2.6)
	upgradeGui.StudsOffset = Vector3.new(0, 6.6, 0)
	upgradeGui.MaxDistance = 80
	upgradeGui.LightInfluence = 0
	upgradeGui.Parent = station
	local upgradeTitle = makeText(upgradeGui, "", GOLD, UDim2.fromScale(1, 0.58), UDim2.new())
	local upgradeInfo = makeText(upgradeGui, "", WHITE, UDim2.fromScale(1, 0.4), UDim2.fromScale(0, 0.6))

	local upgradePrompt = Instance.new("ProximityPrompt")
	upgradePrompt.Name = "UpgradePrompt"
	upgradePrompt.ActionText = "Upgrade Base"
	upgradePrompt.ObjectText = ""
	upgradePrompt.HoldDuration = 0
	upgradePrompt.MaxActivationDistance = 10
	upgradePrompt.RequiresLineOfSight = false
	upgradePrompt:SetAttribute("Kind", "UpgradeBase")
	upgradePrompt:SetAttribute("OwnerUserId", 0)
	CollectionService:AddTag(upgradePrompt, "UpgradeStation")
	upgradePrompt.Parent = station

	-- Lanterns and a big banner on the back wall.
	for _, position in
		{
			Vector3.new(-WIDTH / 2 + 7, 0, -DEPTH / 2 + 7),
			Vector3.new(WIDTH / 2 - 7, 0, -DEPTH / 2 + 7),
			Vector3.new(-WIDTH / 2 + 7, 0, DEPTH / 2 - 7),
			Vector3.new(WIDTH / 2 - 7, 0, DEPTH / 2 - 7),
		}
	do
		Decor.Lantern(model, world(position.X, FLOOR_TOP, position.Z), color:Lerp(WHITE, 0.4))
	end
	local bannerTop = FLOOR_TOP + WALL_HEIGHT - 0.6
	local bannerZ = DEPTH / 2 - 1.6
	add({
		Name = "Banner",
		Size = Vector3.new(10, 7, 0.25),
		Color = color,
		Material = Enum.Material.Fabric,
		CanCollide = false,
	}, CFrame.new(0, bannerTop - 3.5, bannerZ))
	LowPoly.Triangle(
		world(-5, bannerTop - 7, bannerZ),
		world(-5, bannerTop - 9.2, bannerZ),
		world(0, bannerTop - 7, bannerZ),
		facets("BannerTail", color, Enum.Material.Fabric, 0.25),
		model
	)
	LowPoly.Triangle(
		world(5, bannerTop - 7, bannerZ),
		world(0, bannerTop - 7, bannerZ),
		world(5, bannerTop - 9.2, bannerZ),
		facets("BannerTail", color, Enum.Material.Fabric, 0.25),
		model
	)
	add({
		Name = "BannerEmblem",
		Size = Vector3.new(3.5, 3.5, 0.3),
		Color = Color3.fromRGB(255, 225, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, CFrame.new(0, bannerTop - 3.4, bannerZ - 0.15) * CFrame.Angles(0, 0, math.rad(45)))

	-- Spawn marker (also the target of the "go home" beam on the client).
	local spawnCFrame = cframe * CFrame.new(0, FLOOR_TOP + 3, -DEPTH / 2 + 11)
	local marker = Decor.Part({
		Name = "SpawnMarker",
		Size = Vector3.new(1, 1, 1),
		CFrame = spawnCFrame,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, model)
	local target = Instance.new("Attachment")
	target.Name = "Target"
	target.Parent = marker

	-- Pedestals + collect pedestals -------------------------------------------------------------------
	local slots: { Slot } = {}
	for row = 1, #ROWS do
		for column = 1, #COLUMNS do
			local slotIndex = (row - 1) * #COLUMNS + column
			local x, z = COLUMNS[column], ROWS[row]

			local pedestalBase = styled(
				style.Walls,
				add({
					Name = "PedestalBase" .. slotIndex,
					Size = Vector3.new(7.6, 0.6, 7.6),
					Color = palette.Wall,
					Material = palette.WallMaterial,
				}, CFrame.new(x, FLOOR_TOP + 0.3, z))
			)
			local glow = add({
				Name = "PedestalGlow" .. slotIndex,
				Size = Vector3.new(7, 0.18, 7),
				Color = color,
				Material = Enum.Material.Neon,
				CastShadow = false,
			}, CFrame.new(x, FLOOR_TOP + 0.69, z))
			local pedestal = styled(
				style.Tops,
				add({
					Name = "Pedestal" .. slotIndex,
					Size = Vector3.new(6.6, 0.55, 6.6),
					Color = palette.Top,
					Material = palette.TopMaterial,
				}, CFrame.new(x, PEDESTAL_TOP - 0.275, z))
			)

			-- Collect pedestal: a short stone column with a trim cap and a glowing diamond button,
			-- touched (or stepped on) by the owner. The button turns green when cash is waiting.
			local collectZ = z - COLLECT_OFFSET
			local padBase = styled(
				style.Walls,
				add({
					Name = "CollectBase" .. slotIndex,
					Size = Vector3.new(2.4, COLLECT_HEIGHT, 2.4),
					Color = palette.Wall,
					Material = palette.WallMaterial,
				}, CFrame.new(x, FLOOR_TOP + COLLECT_HEIGHT / 2, collectZ))
			)
			local padCap = styled(
				style.Trims,
				add({
					Name = "CollectCap" .. slotIndex,
					Size = Vector3.new(3.2, 0.3, 3.2),
					Color = palette.Trim,
					Material = palette.TrimMaterial,
				}, CFrame.new(x, FLOOR_TOP + COLLECT_HEIGHT + 0.15, collectZ))
			)
			local pad = add({
				Name = "Pad" .. slotIndex,
				Size = Vector3.new(2, 0.4, 2),
				Color = PAD_IDLE,
				Material = Enum.Material.Neon,
				CastShadow = false,
			}, CFrame.new(x, FLOOR_TOP + COLLECT_HEIGHT + 0.4, collectZ) * CFrame.Angles(0, math.rad(45), 0))

			local padGui = Instance.new("BillboardGui")
			padGui.Size = UDim2.fromScale(6, 1.6)
			padGui.StudsOffset = Vector3.new(0, 1.5, 0)
			padGui.MaxDistance = 60
			padGui.LightInfluence = 0
			padGui.Parent = pad
			local padLabel = makeText(padGui, "", Color3.fromRGB(120, 255, 120), UDim2.fromScale(1, 1), UDim2.new())

			slots[slotIndex] = {
				Index = slotIndex,
				Pedestal = pedestal,
				PedestalBase = pedestalBase,
				Glow = glow,
				Pad = pad,
				PadBase = padBase,
				PadCap = padCap,
				PadLabel = padLabel,
				StandPosition = world(x, PEDESTAL_TOP, z),
				-- Between the collect pedestal's side and the front of the critter pedestal: the last
				-- hop onto the pedestal (UnitService.placeModel) stays short.
				GroundPosition = world(x - math.sign(x) * WALK_SIDE, FLOOR_TOP, z - 4.6),
			}
		end
	end

	model.Parent = folder

	local plot: Plot = {
		Index = index,
		CFrame = cframe,
		Model = model,
		Color = color,
		Owner = nil,
		LockedUntil = 0,
		Level = 1,
		TierIndex = 0, -- set by PlotService.SetLevel
		Barrier = barrier,
		OwnerLabel = ownerLabel,
		StatusLabel = statusLabel,
		LevelLabel = levelLabel,
		LockLabel = lockLabel,
		LockPrompt = lockPrompt,
		UpgradeStation = station,
		UpgradeTitle = upgradeTitle,
		UpgradeInfo = upgradeInfo,
		UpgradePrompt = upgradePrompt,
		SpawnCFrame = spawnCFrame,
		Slots = slots,
		Style = style,
	}

	-- Collect pedestals: only the owner collects (touching the button, its cap or its column).
	for _, slot in slots do
		local debounce = 0
		local function onTouched(hit: BasePart)
			local owner = plot.Owner
			if not owner or os.clock() - debounce < 0.3 then
				return
			end
			local character = owner.Character
			if character and hit:IsDescendantOf(character) then
				debounce = os.clock()
				PlotService.PadTouched:Fire(owner, plot, slot.Index)
			end
		end
		for _, part in { slot.Pad, slot.PadCap, slot.PadBase } do
			part.CanTouch = true
			part.Touched:Connect(onTouched)
		end
	end

	lockPrompt.Triggered:Connect(function(player)
		if player ~= plot.Owner then
			return
		end
		if PlotService.IsLocked(plot) then
			Notifier.Send(player, "Your base is already locked!", "info")
			return
		end
		local duration = PlotService.GetLockDuration(plot)
		PlotService.Lock(plot, duration)
		Notifier.Send(player, `🔒 Base locked for {duration}s`, "success")
	end)

	return plot
end

-- Public API ------------------------------------------------------------------

function PlotService.GetPlots(): { Plot }
	return plots
end

function PlotService.GetPlot(player: Player): Plot?
	return plotByPlayer[player]
end

function PlotService.IsLocked(plot: Plot): boolean
	return now() < plot.LockedUntil
end

function PlotService.Lock(plot: Plot, seconds: number)
	plot.LockedUntil = math.max(plot.LockedUntil, now()) + seconds
	PlotService.RefreshLockVisuals(plot)
end

-- Duration of the lock button at the base's upgrade level.
function PlotService.GetLockDuration(plot: Plot): number
	return Economy.GetLockDuration(plot.Level)
end

-- Shows a base upgrade level: castle tier (colours + decorations), gate gems and texts.
function PlotService.SetLevel(plot: Plot, level: number)
	local clamped = Economy.SanitizeBaseLevel(level)
	plot.Level = clamped
	plot.Model:SetAttribute("BaseLevel", clamped)

	local tierIndex = Economy.GetBaseTier(clamped)
	if tierIndex ~= plot.TierIndex then
		plot.TierIndex = tierIndex
		applyTier(plot, tierIndex)
	end
	for gemIndex, gem in plot.Style.Gems do
		local lit = gemIndex <= clamped
		gem.Color = if lit then GOLD else GEM_OFF
		gem.Material = if lit then Enum.Material.Neon else Enum.Material.Slate
	end
	refreshLevelTexts(plot)
end

local function burst(position: Vector3, color: Color3)
	local part = Instance.new("Part")
	part.Name = "UpgradeBurst"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = CFrame.new(position)
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(WHITE, color)
	sparkles.LightEmission = 1
	sparkles.Rate = 160
	sparkles.Lifetime = NumberRange.new(0.6, 1.3)
	sparkles.Speed = NumberRange.new(8, 16)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new(0.7, 0)
	sparkles.Parent = part
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 24
	light.Brightness = 4
	light.Parent = part
	part.Parent = workspace
	task.delay(0.5, function()
		sparkles.Enabled = false
	end)
	task.delay(2, part.Destroy, part)
end

-- Sparkles on the upgrade station and the gate after an upgrade (seen by everybody).
function PlotService.PlayUpgradeEffect(plot: Plot)
	local _, tier = Economy.GetBaseTier(plot.Level)
	burst(plot.UpgradeStation.Position + Vector3.new(0, 4, 0), tier.Color)
	burst((plot.CFrame * CFrame.new(0, FLOOR_TOP + WALL_HEIGHT + 4, GATE_Z - 2)).Position, tier.Color)
end

-- True if the position is inside the base walls.
function PlotService.IsInside(plot: Plot, position: Vector3): boolean
	local localPosition = plot.CFrame:PointToObjectSpace(position)
	return math.abs(localPosition.X) <= WIDTH / 2
		and math.abs(localPosition.Z) <= DEPTH / 2
		and localPosition.Y > -5
		and localPosition.Y < 40
end

-- Waypoints from the conveyor area to the inside of the base (foot of the ramp, then the gate).
function PlotService.GetEntrancePath(plot: Plot): { Vector3 }
	return {
		(plot.CFrame * CFrame.new(0, 0, -DEPTH / 2 - RAMP_LENGTH - 4)).Position,
		(plot.CFrame * CFrame.new(0, FLOOR_TOP, -DEPTH / 2 + 4)).Position,
	}
end

-- Waypoints of a critter walking home: up the ramp, through the gate, along the central aisle, then
-- along the aisle in front of its row and up beside its collect pedestal (it never walks through
-- other pedestals).
function PlotService.GetSlotPath(plot: Plot, slotIndex: number): { Vector3 }
	local path = PlotService.GetEntrancePath(plot)
	local slot = plot.Slots[slotIndex]
	if slot then
		local ground = plot.CFrame:PointToObjectSpace(slot.GroundPosition)
		local aisleZ = plot.CFrame:PointToObjectSpace(slot.StandPosition).Z - COLLECT_OFFSET - ROW_AISLE
		table.insert(path, (plot.CFrame * CFrame.new(0, FLOOR_TOP, aisleZ)).Position)
		table.insert(path, (plot.CFrame * CFrame.new(ground.X, FLOOR_TOP, aisleZ)).Position)
		table.insert(path, slot.GroundPosition)
	end
	return path
end

-- Pedestals beyond the player's slot count are shown greyed out.
function PlotService.SetUnlockedSlots(plot: Plot, count: number)
	for index, slot in plot.Slots do
		local unlocked = index <= count
		slot.Pedestal.Transparency = if unlocked then 0 else 0.6
		slot.PedestalBase.Transparency = if unlocked then 0 else 0.6
		slot.Glow.Transparency = if unlocked then 0 else 1
		slot.PadBase.Transparency = if unlocked then 0 else 0.6
		slot.PadCap.Transparency = if unlocked then 0 else 0.6
		slot.Pad.Transparency = if unlocked then 0 else 1
		slot.Pad.CanCollide = unlocked
		if not unlocked then
			slot.PadLabel.Text = ""
			slot.LastText = nil
		end
	end
end

function PlotService.SetPadAmount(plot: Plot, slotIndex: number, amount: number?)
	local slot = plot.Slots[slotIndex]
	if not slot then
		return
	end
	local text = if amount and amount >= 1 then Format.Money(math.floor(amount)) else ""
	if slot.LastText ~= text then
		slot.LastText = text
		slot.PadLabel.Text = text
		slot.Pad.Color = if text ~= "" then PAD_READY else PAD_IDLE
	end
end

function PlotService.RefreshLockVisuals(plot: Plot)
	local locked = PlotService.IsLocked(plot)
	local barrier = plot.Barrier
	if barrier:GetAttribute("Locked") ~= locked then
		barrier:SetAttribute("Locked", locked)
		barrier.Transparency = if locked then 0 else 1
	end
	if locked then
		local remaining = Format.Time(plot.LockedUntil - now())
		plot.StatusLabel.Text = "🔒 LOCKED " .. remaining
		plot.StatusLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
		plot.LockLabel.Text = "🔒 " .. remaining
	else
		plot.StatusLabel.Text = if plot.Owner then "🔓 Unlocked" else ""
		plot.StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		plot.LockLabel.Text = if plot.Owner then "🔓 LOCK BASE" else ""
	end
end

function PlotService.TeleportHome(player: Player)
	local plot = plotByPlayer[player]
	local character = player.Character
	if plot and character and character.Parent then
		character:PivotTo(plot.SpawnCFrame)
	end
end

-- Lifecycle -------------------------------------------------------------------

function PlotService.Init(services)
	StealService = services.StealService
	MonetizationService = services.MonetizationService

	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	folder.Parent = workspace

	-- MapService (initialised before) has already filled the meadow.
	local perSide = math.ceil(MAP.PlotCount / 2)
	for index = 1, MAP.PlotCount do
		local side = if index <= perSide then 1 else -1
		local column = (index - 1) % perSide
		local x = (column - (perSide - 1) / 2) * MAP.PlotSpacing
		local position = Vector3.new(x, 0, side * MAP.PlotDistanceFromCenter)
		local cframe = CFrame.lookAt(position, position + Vector3.new(0, 0, -side))
		clearTerrain(cframe)
		local plot = buildPlot(index, cframe, folder)
		PlotService.SetLevel(plot, 1)
		PlotService.SetUnlockedSlots(plot, 0)
		table.insert(plots, plot)
	end
end

function PlotService.OnPlayerLoaded(player: Player)
	local plot
	for _, candidate in plots do
		if not candidate.Owner then
			plot = candidate
			break
		end
	end
	if not plot then
		player:Kick("This server is full, please join another one!")
		return
	end

	plot.Owner = player
	plot.LockedUntil = 0
	plotByPlayer[player] = plot
	plot.Model:SetAttribute("OwnerUserId", player.UserId)
	plot.Barrier:SetAttribute("OwnerUserId", player.UserId)
	plot.LockPrompt:SetAttribute("OwnerUserId", player.UserId)
	plot.UpgradePrompt:SetAttribute("OwnerUserId", player.UserId)
	plot.OwnerLabel.Text = `{player.DisplayName}'s Base`
	plot.OwnerLabel.TextColor3 = plot.Color:Lerp(WHITE, 0.3)
	player:SetAttribute("PlotIndex", plot.Index)
	refreshLevelTexts(plot) -- UpgradeService sets the real level right after
	PlotService.RefreshLockVisuals(plot)

	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		task.wait()
		if plotByPlayer[player] == plot and character.Parent then
			character:PivotTo(plot.SpawnCFrame)
		end
	end)
	if player.Character then
		PlotService.TeleportHome(player)
	end
end

function PlotService.OnPlayerRemoving(player: Player)
	lastTeleport[player] = nil
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	plotByPlayer[player] = nil
	plot.Owner = nil
	plot.LockedUntil = 0
	plot.Model:SetAttribute("OwnerUserId", 0)
	plot.Barrier:SetAttribute("OwnerUserId", 0)
	plot.LockPrompt:SetAttribute("OwnerUserId", 0)
	plot.UpgradePrompt:SetAttribute("OwnerUserId", 0)
	plot.OwnerLabel.Text = "Empty Base"
	plot.OwnerLabel.TextColor3 = WHITE
	for index in plot.Slots do
		PlotService.SetPadAmount(plot, index, 0)
	end
	PlotService.SetUnlockedSlots(plot, 0)
	PlotService.SetLevel(plot, 1)
	PlotService.RefreshLockVisuals(plot)
end

function PlotService.Start()
	-- Lock timers.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, plot in plots do
				PlotService.RefreshLockVisuals(plot)
			end
		end
	end)

	MonetizationService.RegisterKindHandler("BaseLock", function(player, _key, product)
		local plot = plotByPlayer[player]
		if not plot then
			return false
		end
		PlotService.Lock(plot, product.Duration)
		Notifier.Send(player, `🔒 Super Lock! Your base is locked for {Format.Time(plot.LockedUntil - now())}`, "success")
		return true
	end)

	Remotes.TeleportHome.OnServerEvent:Connect(function(player)
		local last = lastTeleport[player] or 0
		if os.clock() - last < GameConfig.Home.TeleportCooldown then
			Notifier.Send(
				player,
				`Wait {math.ceil(GameConfig.Home.TeleportCooldown - (os.clock() - last))}s before teleporting again`,
				"error"
			)
			return
		end
		if StealService.IsCarrying(player) then
			Notifier.Send(player, "You can't teleport while carrying a critter!", "error")
			return
		end
		lastTeleport[player] = os.clock()
		PlotService.TeleportHome(player)
	end)
end

return PlotService
