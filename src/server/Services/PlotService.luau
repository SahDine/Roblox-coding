--[[
	PlotService
	Builds the player bases (little fantasy castles), assigns one to each
	player, handles the base lock (magic shield) and teleports players home.

	Base layout (local space, -Z faces the conveyor):
	  gate + shield at the front, a lock button inside,
	  a 4x4 grid of pedestals, each with a cash pad in front of it,
	  stone walls with merlons, four domed towers and banners.

	The shield's collision is handled on each client (owner walks through,
	others are blocked), the server only refuses steals while locked.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)

local Modules = script.Parent.Parent.Modules
local Decor = require(Modules.Decor)
local Notifier = require(Modules.Notifier)

local PlotService = {}

-- Fired with (player, plot, slotIndex) when an owner steps on one of their cash pads.
PlotService.PadTouched = Signal.new()

export type Slot = {
	Index: number,
	Pedestal: BasePart,
	PedestalBase: BasePart,
	Glow: BasePart,
	Pad: BasePart,
	PadLabel: TextLabel,
	StandPosition: Vector3,
	GroundPosition: Vector3,
	LastText: string?,
}

export type Plot = {
	Index: number,
	CFrame: CFrame,
	Model: Model,
	Color: Color3,
	Owner: Player?,
	LockedUntil: number,
	Barrier: BasePart,
	OwnerLabel: TextLabel,
	StatusLabel: TextLabel,
	LockLabel: TextLabel,
	SpawnCFrame: CFrame,
	Slots: { Slot },
}

local MAP = GameConfig.Map
local WIDTH, DEPTH = MAP.PlotWidth, MAP.PlotDepth
local FLOOR_TOP = 0.2
local COLUMNS = { -21, -7, 7, 21 }
local ROWS = { -14, 1, 16, 31 }
local ENTRANCE_WIDTH = 16
local WALL_HEIGHT = 10
local PEDESTAL_TOP = FLOOR_TOP + 1.3

local STONE = Color3.fromRGB(175, 170, 180)
local GRASS = Color3.fromRGB(120, 185, 95)
local PATH = Color3.fromRGB(170, 160, 150)

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

local function buildPlot(index: number, cframe: CFrame, folder: Folder): Plot
	local color = PLOT_COLORS[(index - 1) % #PLOT_COLORS + 1]
	local stone = STONE:Lerp(color, 0.12)
	local trimColor = color:Lerp(Color3.new(1, 1, 1), 0.15)

	local model = Instance.new("Model")
	model.Name = "Plot_" .. index
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)

	local function add(props, offset: CFrame): BasePart
		props.CFrame = cframe * offset
		return Decor.Part(props, model)
	end
	local function world(x: number, y: number, z: number): Vector3
		return (cframe * CFrame.new(x, y, z)).Position
	end

	-- Courtyard ---------------------------------------------------------------------------
	local floor = add({
		Name = "Floor",
		Size = Vector3.new(WIDTH, FLOOR_TOP, DEPTH),
		Color = GRASS,
		Material = Enum.Material.Grass,
	}, CFrame.new(0, FLOOR_TOP / 2, 0))
	floor.CollisionGroup = "Default" -- critters walk on it
	add({
		Name = "Path",
		Size = Vector3.new(6, 0.06, DEPTH - 2),
		Color = PATH,
		Material = Enum.Material.Cobblestone,
		CanCollide = false,
	}, CFrame.new(0, FLOOR_TOP + 0.03, 0))
	add({
		Name = "Plaza",
		Size = Vector3.new(ENTRANCE_WIDTH + 14, 0.06, 14),
		Color = PATH,
		Material = Enum.Material.Cobblestone,
		CanCollide = false,
	}, CFrame.new(0, FLOOR_TOP + 0.03, -DEPTH / 2 + 8))

	-- Walls with a coloured trim and merlons ------------------------------------------------
	local wallY = FLOOR_TOP + WALL_HEIGHT / 2
	local sideWidth = (WIDTH - ENTRANCE_WIDTH) / 2
	local walls = {
		{ Vector3.new(WIDTH, 0, 0), Vector3.new(0, 0, DEPTH / 2 - 0.75) },
		{ Vector3.new(0, 0, DEPTH), Vector3.new(-WIDTH / 2 + 0.75, 0, 0) },
		{ Vector3.new(0, 0, DEPTH), Vector3.new(WIDTH / 2 - 0.75, 0, 0) },
		{ Vector3.new(sideWidth, 0, 0), Vector3.new(-(ENTRANCE_WIDTH / 2 + sideWidth / 2), 0, -DEPTH / 2 + 0.75) },
		{ Vector3.new(sideWidth, 0, 0), Vector3.new(ENTRANCE_WIDTH / 2 + sideWidth / 2, 0, -DEPTH / 2 + 0.75) },
	}
	for wallIndex, wall in walls do
		local length = math.max(wall[1].X, wall[1].Z)
		local alongX = wall[1].X > 0
		local size = if alongX then Vector3.new(length, WALL_HEIGHT, 1.5) else Vector3.new(1.5, WALL_HEIGHT, length)
		add({ Name = "Wall" .. wallIndex, Size = size, Color = stone, Material = Enum.Material.Cobblestone }, CFrame.new(wall[2] + Vector3.new(0, wallY, 0)))
		add({
			Name = "Trim",
			Size = if alongX then Vector3.new(length, 0.7, 1.8) else Vector3.new(1.8, 0.7, length),
			Color = trimColor,
			Material = Enum.Material.SmoothPlastic,
		}, CFrame.new(wall[2] + Vector3.new(0, FLOOR_TOP + WALL_HEIGHT + 0.35, 0)))
		local count = math.floor(length / 5)
		for merlon = 0, count - 1 do
			local offset = (merlon - (count - 1) / 2) * 5
			local position = wall[2] + (if alongX then Vector3.new(offset, 0, 0) else Vector3.new(0, 0, offset))
			add({
				Name = "Merlon",
				Size = Vector3.new(2.2, 1.6, 1.6),
				Color = stone,
				Material = Enum.Material.Cobblestone,
			}, CFrame.new(position + Vector3.new(0, FLOOR_TOP + WALL_HEIGHT + 1.5, 0)))
		end
	end

	-- Corner towers with domes and banners ---------------------------------------------------
	for _, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
		local base = world(corner.X * (WIDTH / 2 - 1), 0, corner.Z * (DEPTH / 2 - 1))
		Decor.Column("Tower", WALL_HEIGHT + 6, 8, base, stone, model, { Material = Enum.Material.Cobblestone })
		Decor.Column("TowerRing", 1, 9, base + Vector3.new(0, WALL_HEIGHT + 6, 0), trimColor, model)
		Decor.Ellipsoid("Dome", Vector3.new(8.6, 8, 8.6), CFrame.new(base + Vector3.new(0, WALL_HEIGHT + 7, 0)), color, model, {
			Material = Enum.Material.SmoothPlastic,
		})
		local spireTop = base + Vector3.new(0, WALL_HEIGHT + 15, 0)
		Decor.Column("FlagPole", 5, 0.35, spireTop - Vector3.new(0, 4, 0), Color3.fromRGB(80, 70, 60), model, { CanCollide = false })
		Decor.Part({
			Name = "Flag",
			Size = Vector3.new(0.15, 1.8, 3),
			CFrame = CFrame.new(spireTop + Vector3.new(0, -0.3, 0)) * cframe.Rotation * CFrame.new(0, 0, 1.6),
			Color = color,
			CanCollide = false,
		}, model)
		if corner.Z < 0 then
			local window = Decor.Part({
				Name = "Window",
				Size = Vector3.new(1.6, 2.4, 0.3),
				CFrame = CFrame.new(base + Vector3.new(0, WALL_HEIGHT + 1, 0)) * cframe.Rotation * CFrame.new(0, 0, -4),
				Color = Color3.fromRGB(255, 210, 120),
				Material = Enum.Material.Neon,
				CanCollide = false,
			}, model)
			Decor.Light(window, Color3.fromRGB(255, 200, 120), 10, 1)
		end
	end

	-- Gate -------------------------------------------------------------------------------------
	local gateZ = -DEPTH / 2 + 0.75
	for _, side in { -1, 1 } do
		add({
			Name = "GatePillar",
			Size = Vector3.new(3.5, WALL_HEIGHT + 5, 3.5),
			Color = stone,
			Material = Enum.Material.Cobblestone,
		}, CFrame.new(side * (ENTRANCE_WIDTH / 2 + 1.75), FLOOR_TOP + (WALL_HEIGHT + 5) / 2, gateZ))
		Decor.Torch(model, world(side * (ENTRANCE_WIDTH / 2 + 2), 0, gateZ - 3.5), 5)
	end
	add({
		Name = "GateBeam",
		Size = Vector3.new(ENTRANCE_WIDTH + 7, 2.2, 3.5),
		Color = trimColor,
	}, CFrame.new(0, FLOOR_TOP + WALL_HEIGHT + 3.9, gateZ))

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
	}, CFrame.new(0, FLOOR_TOP + (WALL_HEIGHT + 2.8) / 2, gateZ))
	barrier:SetAttribute("OwnerUserId", 0)
	barrier:SetAttribute("Locked", false)

	-- Sign above the gate.
	local sign = add({
		Name = "Sign",
		Size = Vector3.new(26, 6, 0.6),
		Color = Color3.fromRGB(45, 35, 55),
		Material = Enum.Material.Wood,
	}, CFrame.new(0, FLOOR_TOP + WALL_HEIGHT + 8.2, gateZ - 1.2))
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 20
	signGui.LightInfluence = 0
	signGui.Parent = sign
	local ownerLabel = makeText(signGui, "Empty Base", Color3.new(1, 1, 1), UDim2.fromScale(0.94, 0.58), UDim2.fromScale(0.03, 0.04))
	local statusLabel = makeText(signGui, "", Color3.fromRGB(200, 200, 200), UDim2.fromScale(0.9, 0.32), UDim2.fromScale(0.05, 0.64))

	-- Lock button (an enchanted rune stone).
	add({
		Name = "LockBase",
		Size = Vector3.new(4.5, 0.6, 4.5),
		Color = stone,
		Material = Enum.Material.Cobblestone,
	}, CFrame.new(-16, FLOOR_TOP + 0.3, -DEPTH / 2 + 8))
	local lockButton = add({
		Name = "LockButton",
		Size = Vector3.new(3.4, 0.7, 3.4),
		Color = Color3.fromRGB(230, 60, 80),
		Material = Enum.Material.Neon,
	}, CFrame.new(-16, FLOOR_TOP + 0.95, -DEPTH / 2 + 8))
	local lockGui = Instance.new("BillboardGui")
	lockGui.Size = UDim2.fromScale(6, 2)
	lockGui.StudsOffset = Vector3.new(0, 3, 0)
	lockGui.MaxDistance = 80
	lockGui.LightInfluence = 0
	lockGui.Parent = lockButton
	local lockLabel = makeText(lockGui, "🔓 LOCK BASE", Color3.new(1, 1, 1), UDim2.fromScale(1, 1), UDim2.new())

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

	-- Lanterns and a big banner on the back wall.
	for _, position in { Vector3.new(-WIDTH / 2 + 5, 0, -DEPTH / 2 + 5), Vector3.new(WIDTH / 2 - 5, 0, -DEPTH / 2 + 5), Vector3.new(-WIDTH / 2 + 5, 0, DEPTH / 2 - 5), Vector3.new(WIDTH / 2 - 5, 0, DEPTH / 2 - 5) } do
		Decor.Lantern(model, world(position.X, FLOOR_TOP, position.Z), color:Lerp(Color3.new(1, 1, 1), 0.4))
	end
	add({
		Name = "Banner",
		Size = Vector3.new(10, 8, 0.25),
		Color = color,
		CanCollide = false,
	}, CFrame.new(0, FLOOR_TOP + WALL_HEIGHT - 4, DEPTH / 2 - 1.6))
	add({
		Name = "BannerEmblem",
		Size = Vector3.new(3.5, 3.5, 0.3),
		Color = Color3.fromRGB(255, 225, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, CFrame.new(0, FLOOR_TOP + WALL_HEIGHT - 3.6, DEPTH / 2 - 1.75) * CFrame.Angles(0, 0, math.rad(45)))

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

	-- Pedestals + cash pads ---------------------------------------------------------------------
	local slots: { Slot } = {}
	for row = 1, #ROWS do
		for column = 1, #COLUMNS do
			local slotIndex = (row - 1) * #COLUMNS + column
			local x, z = COLUMNS[column], ROWS[row]

			local pedestalBase = add({
				Name = "PedestalBase" .. slotIndex,
				Size = Vector3.new(7.6, 0.6, 7.6),
				Color = stone,
				Material = Enum.Material.Cobblestone,
			}, CFrame.new(x, FLOOR_TOP + 0.3, z))
			local glow = add({
				Name = "PedestalGlow" .. slotIndex,
				Size = Vector3.new(7, 0.18, 7),
				Color = color,
				Material = Enum.Material.Neon,
				CastShadow = false,
			}, CFrame.new(x, FLOOR_TOP + 0.69, z))
			local pedestal = add({
				Name = "Pedestal" .. slotIndex,
				Size = Vector3.new(6.6, 0.55, 6.6),
				Color = color:Lerp(Color3.new(1, 1, 1), 0.55),
				Material = Enum.Material.Marble,
			}, CFrame.new(x, PEDESTAL_TOP - 0.275, z))

			local pad = add({
				Name = "Pad" .. slotIndex,
				Size = Vector3.new(4.5, 0.3, 2.5),
				Color = Color3.fromRGB(90, 90, 100),
				Material = Enum.Material.Neon,
			}, CFrame.new(x, FLOOR_TOP + 0.15, z - 5.6))
			pad.CanTouch = true

			local padGui = Instance.new("BillboardGui")
			padGui.Size = UDim2.fromScale(5, 1.2)
			padGui.StudsOffset = Vector3.new(0, 1.2, 0)
			padGui.MaxDistance = 50
			padGui.LightInfluence = 0
			padGui.Parent = pad
			local padLabel = makeText(padGui, "", Color3.fromRGB(120, 255, 120), UDim2.fromScale(1, 1), UDim2.new())

			slots[slotIndex] = {
				Index = slotIndex,
				Pedestal = pedestal,
				PedestalBase = pedestalBase,
				Glow = glow,
				Pad = pad,
				PadLabel = padLabel,
				StandPosition = world(x, PEDESTAL_TOP, z),
				GroundPosition = world(x, FLOOR_TOP, z - 5.6),
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
		Barrier = barrier,
		OwnerLabel = ownerLabel,
		StatusLabel = statusLabel,
		LockLabel = lockLabel,
		SpawnCFrame = spawnCFrame,
		Slots = slots,
	}

	-- Cash pads: only the owner collects.
	for _, slot in slots do
		local debounce = 0
		slot.Pad.Touched:Connect(function(hit)
			local owner = plot.Owner
			if not owner or os.clock() - debounce < 0.3 then
				return
			end
			local character = owner.Character
			if character and hit:IsDescendantOf(character) then
				debounce = os.clock()
				PlotService.PadTouched:Fire(owner, plot, slot.Index)
			end
		end)
	end

	lockPrompt.Triggered:Connect(function(player)
		if player ~= plot.Owner then
			return
		end
		if PlotService.IsLocked(plot) then
			Notifier.Send(player, "Your base is already locked!", "info")
			return
		end
		PlotService.Lock(plot, GameConfig.Lock.Duration)
		Notifier.Send(player, `🔒 Base locked for {GameConfig.Lock.Duration}s`, "success")
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

-- True if the position is inside the base walls.
function PlotService.IsInside(plot: Plot, position: Vector3): boolean
	local localPosition = plot.CFrame:PointToObjectSpace(position)
	return math.abs(localPosition.X) <= WIDTH / 2
		and math.abs(localPosition.Z) <= DEPTH / 2
		and localPosition.Y > -5
		and localPosition.Y < 40
end

-- Waypoints from the conveyor area to the inside of the base.
function PlotService.GetEntrancePath(plot: Plot): { Vector3 }
	return {
		(plot.CFrame * CFrame.new(0, 0, -DEPTH / 2 - 6)).Position,
		(plot.CFrame * CFrame.new(0, FLOOR_TOP, -DEPTH / 2 + 4)).Position,
	}
end

-- Pedestals beyond the player's slot count are shown greyed out.
function PlotService.SetUnlockedSlots(plot: Plot, count: number)
	for index, slot in plot.Slots do
		local unlocked = index <= count
		slot.Pedestal.Transparency = if unlocked then 0 else 0.6
		slot.PedestalBase.Transparency = if unlocked then 0 else 0.6
		slot.Glow.Transparency = if unlocked then 0 else 1
		slot.Pad.Transparency = if unlocked then 0 else 1
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
		slot.Pad.Color = if text ~= "" then Color3.fromRGB(60, 220, 90) else Color3.fromRGB(90, 90, 100)
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

	local perSide = math.ceil(MAP.PlotCount / 2)
	for index = 1, MAP.PlotCount do
		local side = if index <= perSide then 1 else -1
		local column = (index - 1) % perSide
		local x = (column - (perSide - 1) / 2) * MAP.PlotSpacing
		local position = Vector3.new(x, 0, side * MAP.PlotDistanceFromCenter)
		local cframe = CFrame.lookAt(position, position + Vector3.new(0, 0, -side))
		local plot = buildPlot(index, cframe, folder)
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
	local lockPrompt = plot.Model:FindFirstChild("LockPrompt", true)
	if lockPrompt then
		lockPrompt:SetAttribute("OwnerUserId", player.UserId)
	end
	plot.OwnerLabel.Text = `{player.DisplayName}'s Base`
	plot.OwnerLabel.TextColor3 = plot.Color:Lerp(Color3.new(1, 1, 1), 0.3)
	player:SetAttribute("PlotIndex", plot.Index)
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
	local lockPrompt = plot.Model:FindFirstChild("LockPrompt", true)
	if lockPrompt then
		lockPrompt:SetAttribute("OwnerUserId", 0)
	end
	plot.OwnerLabel.Text = "Empty Base"
	plot.OwnerLabel.TextColor3 = Color3.new(1, 1, 1)
	for index in plot.Slots do
		PlotService.SetPadAmount(plot, index, 0)
	end
	PlotService.SetUnlockedSlots(plot, 0)
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
			Notifier.Send(player, `Wait {math.ceil(GameConfig.Home.TeleportCooldown - (os.clock() - last))}s before teleporting again`, "error")
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
