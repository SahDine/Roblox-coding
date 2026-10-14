--[[
	PlotService
	Builds the player bases, assigns one to each player, handles the base
	lock (laser barrier) and teleports players home.

	Base layout (local space, -Z faces the conveyor):
	  entrance + barrier at the front, a lock button inside,
	  a 4x4 grid of pedestals, each with a cash pad in front of it.

	The barrier's collision is handled on each client (owner walks through,
	others are blocked), the server only refuses steals while locked.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)

local Notifier = require(script.Parent.Parent.Modules.Notifier)

local PlotService = {}

-- Fired with (player, plot, slotIndex) when an owner steps on one of their cash pads.
PlotService.PadTouched = Signal.new()

export type Slot = {
	Index: number,
	Pedestal: BasePart,
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
local COLUMNS = { -18, -6, 6, 18 }
local ROWS = { -10, 2, 14, 26 }
local ENTRANCE_WIDTH = 14
local WALL_HEIGHT = 8

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

local MapService, StealService, MonetizationService

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
	local newPart = MapService.NewPart
	local color = PLOT_COLORS[(index - 1) % #PLOT_COLORS + 1]

	local model = Instance.new("Model")
	model.Name = "Plot_" .. index
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)

	local function add(props, offset: CFrame): BasePart
		props.CFrame = cframe * offset
		local part = newPart(props, model)
		part.CollisionGroup = "Decor"
		return part
	end

	local floor = add({
		Name = "Floor",
		Size = Vector3.new(WIDTH, FLOOR_TOP, DEPTH),
		Color = color:Lerp(Color3.new(1, 1, 1), 0.7),
	}, CFrame.new(0, FLOOR_TOP / 2, 0))
	floor.CollisionGroup = "Default" -- critters walk on it

	local wallColor = color:Lerp(Color3.new(0, 0, 0), 0.1)
	local wallY = FLOOR_TOP + WALL_HEIGHT / 2
	local sideWidth = (WIDTH - ENTRANCE_WIDTH) / 2
	add({ Name = "WallBack", Size = Vector3.new(WIDTH, WALL_HEIGHT, 1), Color = wallColor }, CFrame.new(0, wallY, DEPTH / 2 - 0.5))
	add({ Name = "WallLeft", Size = Vector3.new(1, WALL_HEIGHT, DEPTH), Color = wallColor }, CFrame.new(-WIDTH / 2 + 0.5, wallY, 0))
	add({ Name = "WallRight", Size = Vector3.new(1, WALL_HEIGHT, DEPTH), Color = wallColor }, CFrame.new(WIDTH / 2 - 0.5, wallY, 0))
	for _, side in { -1, 1 } do
		add({
			Name = "WallFront",
			Size = Vector3.new(sideWidth, WALL_HEIGHT, 1),
			Color = wallColor,
		}, CFrame.new(side * (ENTRANCE_WIDTH / 2 + sideWidth / 2), wallY, -DEPTH / 2 + 0.5))
	end
	add({
		Name = "GateBeam",
		Size = Vector3.new(ENTRANCE_WIDTH, 1.5, 1),
		Color = wallColor,
	}, CFrame.new(0, FLOOR_TOP + WALL_HEIGHT + 0.75, -DEPTH / 2 + 0.5))

	-- Laser barrier (collision is client-side, see WorldController).
	local barrier = add({
		Name = "Barrier",
		Size = Vector3.new(ENTRANCE_WIDTH, WALL_HEIGHT, 0.4),
		Color = Color3.fromRGB(255, 50, 50),
		Material = Enum.Material.Neon,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	}, CFrame.new(0, wallY, -DEPTH / 2 + 0.5))
	barrier:SetAttribute("OwnerUserId", 0)
	barrier:SetAttribute("Locked", false)

	-- Sign above the entrance.
	local sign = add({
		Name = "Sign",
		Size = Vector3.new(26, 6, 0.6),
		Color = Color3.fromRGB(35, 35, 45),
	}, CFrame.new(0, FLOOR_TOP + WALL_HEIGHT + 4.5, -DEPTH / 2 + 0.5))
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 20
	signGui.LightInfluence = 0
	signGui.Parent = sign
	local ownerLabel = makeText(signGui, "Empty Base", Color3.new(1, 1, 1), UDim2.fromScale(0.94, 0.58), UDim2.fromScale(0.03, 0.04))
	local statusLabel = makeText(signGui, "", Color3.fromRGB(200, 200, 200), UDim2.fromScale(0.9, 0.32), UDim2.fromScale(0.05, 0.64))

	-- Lock button.
	local lockButton = add({
		Name = "LockButton",
		Size = Vector3.new(3.5, 0.8, 3.5),
		Color = Color3.fromRGB(230, 60, 60),
		Material = Enum.Material.Neon,
	}, CFrame.new(-14, FLOOR_TOP + 0.4, -DEPTH / 2 + 7))
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
	lockPrompt.MaxActivationDistance = 9
	lockPrompt.RequiresLineOfSight = false
	lockPrompt:SetAttribute("Kind", "Lock")
	lockPrompt:SetAttribute("OwnerUserId", 0)
	lockPrompt.Parent = lockButton

	-- Spawn marker (also the target of the "go home" beam on the client).
	local spawnCFrame = cframe * CFrame.new(0, FLOOR_TOP + 3, -DEPTH / 2 + 10)
	local marker = newPart({
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

	-- Pedestals + cash pads.
	local slots: { Slot } = {}
	for row = 1, #ROWS do
		for column = 1, #COLUMNS do
			local slotIndex = (row - 1) * #COLUMNS + column
			local x, z = COLUMNS[column], ROWS[row]

			local pedestal = add({
				Name = "Pedestal" .. slotIndex,
				Size = Vector3.new(6, 1, 6),
				Color = Color3.fromRGB(70, 70, 80),
			}, CFrame.new(x, FLOOR_TOP + 0.5, z))

			local pad = add({
				Name = "Pad" .. slotIndex,
				Size = Vector3.new(4, 0.3, 2.5),
				Color = Color3.fromRGB(90, 90, 100),
				Material = Enum.Material.Neon,
			}, CFrame.new(x, FLOOR_TOP + 0.15, z - 4.5))
			pad.CanTouch = true

			local padGui = Instance.new("BillboardGui")
			padGui.Size = UDim2.fromScale(5, 1.2)
			padGui.StudsOffset = Vector3.new(0, 1.2, 0)
			padGui.MaxDistance = 45
			padGui.LightInfluence = 0
			padGui.Parent = pad
			local padLabel = makeText(padGui, "", Color3.fromRGB(120, 255, 120), UDim2.fromScale(1, 1), UDim2.new())

			local slot: Slot = {
				Index = slotIndex,
				Pedestal = pedestal,
				Pad = pad,
				PadLabel = padLabel,
				StandPosition = (cframe * CFrame.new(x, FLOOR_TOP + 1, z)).Position,
				GroundPosition = (cframe * CFrame.new(x, FLOOR_TOP, z - 4.5)).Position,
			}
			slots[slotIndex] = slot
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
		slot.Pedestal.Transparency = if unlocked then 0 else 0.75
		slot.Pedestal.Color = if unlocked then Color3.fromRGB(70, 70, 80) else Color3.fromRGB(40, 40, 45)
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
		barrier.Transparency = if locked then 0.45 else 1
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
	MapService = services.MapService
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
