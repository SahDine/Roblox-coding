--[[
	ConveyorService
	Critters keep walking along the conveyor. Anyone can buy one with cash
	(first come, first served) or instantly with Robux for Epic+ rarities.
	Players bring their critters home one at a time: no new purchase while a critter they bought
	is still walking to their base (a paid Robux purchase is always granted: that critter then
	appears straight on its pedestal).

	Spawns: Common to Epic critters come from a random roll every few seconds. Legendary, Mythic
	and Secret critters spawn on public server-wide timers (GameConfig.RareSpawns, faster with
	Server Luck) shown on the "RARE CRITTERS" board next to the NEW CRITTERS portal.
	Rare spawns are announced to the whole server to create hype.

	The timers are replicated as attributes of ReplicatedStorage.RareSpawns (server time):
	  <Rarity> = next spawn, <Rarity>Last = last spawn, <Rarity>From = start of the current
	  countdown (server start or last spawn). BoardsController shows the countdowns.
]]

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Units = require(Shared.Config.Units)

local Modules = script.Parent.Parent.Modules
local Decor = require(Modules.Decor)
local LowPoly = require(Modules.LowPoly)
local Notifier = require(Modules.Notifier)
local UnitModelBuilder = require(Modules.UnitModelBuilder)
local Walker = require(Modules.Walker)

local ConveyorService = {}

type Entry = {
	Id: string,
	UnitName: string,
	Rarity: string,
	Mutation: string,
	Model: Model,
	Token: Walker.Token,
	Prompts: { ProximityPrompt },
	Sold: boolean,
	SpawnedAt: number, -- os.clock()
}

type PendingRobux = { EntryId: string, UnitName: string, Mutation: string, Rarity: string, Time: number }

type RareTimer = {
	Rarity: string,
	Remaining: number, -- timer seconds left (they pass faster with Server Luck)
	Warned: boolean,
	PublishedAt: number?, -- next spawn time (server time) last sent to the clients
}

local CONVEYOR = GameConfig.Conveyor
local RARE = GameConfig.RareSpawns
local TICK = 0.5

local MapService, UnitService, CurrencyService, MonetizationService, BoostService, PlotService

local entries: { [string]: Entry } = {}
local entryCount = 0
local pendingRobux: { [Player]: PendingRobux } = {}

local rareTimers: { RareTimer } = {}
local rareFolder: Folder
local lastTimerUpdate = 0 -- server time
local lastSpawnClock = -math.huge -- os.clock() of the last conveyor spawn
local nextRandomClock = 0

local function removeEntry(entry: Entry)
	if entries[entry.Id] then
		entries[entry.Id] = nil
		entryCount -= 1
	end
	entry.Token.Cancelled = true
	for _, prompt in entry.Prompts do
		prompt:Destroy()
	end
	table.clear(entry.Prompts)
end

-- Hands the conveyor critter to the buyer: it walks to their base (or appears on its pedestal).
-- Returns the new guid (nil when the base was full and the critter went to storage).
local function deliver(entry: Entry, player: Player, walk: boolean): string?
	entry.Sold = true
	removeEntry(entry)
	return UnitService.GrantUnit(player, entry.UnitName, entry.Mutation, { Model = entry.Model, Walk = walk })
end

-- Players bring their critters home one at a time. Returns true (and explains why) when busy.
local function isBringingCritterHome(player: Player): boolean
	local inTransit, name = UnitService.HasCritterInTransit(player)
	if inTransit then
		Notifier.Send(player, `Wait until your {name or "critter"} reaches your base!`, "error")
	end
	return inTransit
end

local function tryBuyWithCash(player: Player, entry: Entry)
	if entry.Sold or not player:GetAttribute("DataLoaded") or not PlotService.GetPlot(player) then
		return
	end
	if isBringingCritterHome(player) then
		return
	end
	if not UnitService.HasFreeSlot(player) then
		Notifier.Send(player, "Your base is full! Sell a critter or rebirth for more slots.", "error")
		return
	end
	local price = Economy.GetUnitPrice(entry.UnitName, entry.Mutation)
	if not CurrencyService.TrySpend(player, price) then
		Notifier.Send(player, `Not enough cash! You need {Format.Money(price)}`, "error")
		return
	end
	deliver(entry, player, true)
	Notifier.Send(player, `You bought {entry.UnitName}! It's walking to your base.`, "success")
end

local function tryBuyWithRobux(player: Player, entry: Entry)
	local productKey = Rarities.Info[entry.Rarity].RobuxProduct
	if entry.Sold or not productKey or not player:GetAttribute("DataLoaded") then
		return
	end
	-- Do not even open the purchase prompt (a receipt that arrives anyway is still granted).
	if isBringingCritterHome(player) then
		return
	end
	pendingRobux[player] = {
		EntryId = entry.Id,
		UnitName = entry.UnitName,
		Mutation = entry.Mutation,
		Rarity = entry.Rarity,
		Time = os.clock(),
	}
	MonetizationService.PromptProduct(player, productKey)
end

-- Puts a critter at the start of the conveyor. Returns true when it was spawned.
local function spawnCritter(unitName: string, mutation: string): boolean
	local def = Units.ByName[unitName]
	local model = if def then UnitModelBuilder.Build(unitName, mutation) else nil
	if not def or not model then
		return false
	end
	local root = model.PrimaryPart :: BasePart
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid

	local entry: Entry = {
		Id = HttpService:GenerateGUID(false),
		UnitName = unitName,
		Rarity = def.Rarity,
		Mutation = mutation,
		Model = model,
		Token = Walker.NewToken(),
		Prompts = {},
		Sold = false,
		SpawnedAt = os.clock(),
	}

	local price = Economy.GetUnitPrice(unitName, mutation)
	local productKey = Rarities.Info[def.Rarity].RobuxProduct
	local robuxEnabled = productKey ~= nil and MonetizationService.IsProductConfigured(productKey)
	local robuxText = if robuxEnabled and productKey then `or R$ {MonetizationService.GetRobuxPrice(productKey)}` else nil
	UnitModelBuilder.CreateInfoBillboard(model, unitName, mutation, Format.Money(price), robuxText)

	local start = MapService.ConveyorStart
	model:PivotTo(UnitModelBuilder.GetStandingCFrame(model, start, Vector3.new(1, 0, 0)))
	model.Parent = MapService.ConveyorFolder
	UnitModelBuilder.SetAnchored(model, false)
	humanoid.WalkSpeed = CONVEYOR.WalkSpeed

	local buyPrompt = Instance.new("ProximityPrompt")
	buyPrompt.Name = "BuyPrompt"
	buyPrompt.ActionText = "Buy " .. Format.Money(price)
	buyPrompt.ObjectText = (if mutation ~= "None" then mutation .. " " else "") .. unitName
	buyPrompt.HoldDuration = 0
	buyPrompt.MaxActivationDistance = 12
	buyPrompt.RequiresLineOfSight = false
	buyPrompt.KeyboardKeyCode = Enum.KeyCode.E
	buyPrompt:SetAttribute("Kind", "Buy")
	buyPrompt.Triggered:Connect(function(player)
		tryBuyWithCash(player, entry)
	end)
	buyPrompt.Parent = root
	table.insert(entry.Prompts, buyPrompt)

	if robuxEnabled and productKey then
		local robuxPrompt = Instance.new("ProximityPrompt")
		robuxPrompt.Name = "RobuxPrompt"
		robuxPrompt.ActionText = `Instant buy R$ {MonetizationService.GetRobuxPrice(productKey)}`
		robuxPrompt.ObjectText = def.Rarity
		robuxPrompt.HoldDuration = 0
		robuxPrompt.MaxActivationDistance = 12
		robuxPrompt.RequiresLineOfSight = false
		robuxPrompt.KeyboardKeyCode = Enum.KeyCode.F
		robuxPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
		robuxPrompt:SetAttribute("Kind", "Robux")
		robuxPrompt.Triggered:Connect(function(player)
			tryBuyWithRobux(player, entry)
		end)
		robuxPrompt.Parent = root
		table.insert(entry.Prompts, robuxPrompt)
	end

	entries[entry.Id] = entry
	entryCount += 1

	if Rarities.Info[def.Rarity].Announce or (mutation ~= "None" and Mutations.Get(mutation).Multiplier >= 5) then
		local label = (if mutation ~= "None" then mutation .. " " else "") .. unitName
		Notifier.All(`✨ A {string.upper(def.Rarity)} {label} appeared on the conveyor!`, "announce")
	end

	task.spawn(function()
		local travelTime = (MapService.ConveyorEnd - MapService.ConveyorStart).Magnitude / CONVEYOR.WalkSpeed
		local result = Walker.Walk(humanoid, { MapService.ConveyorEnd }, entry.Token, travelTime * 1.5 + 20)
		if result ~= "Cancelled" and not entry.Sold then
			removeEntry(entry)
			model:Destroy()
		end
	end)
	return true
end

-- Common to Epic: random roll (timed rarities are never rolled).
local function spawnRandom()
	local luck = BoostService.GetServerLuck()
	local rarity = Rarities.Roll(luck)
	local def = Units.PickFromRarity(rarity)
	if def then
		spawnCritter(def.Name, Mutations.Roll(luck))
	end
end

-- The conveyor is full and a timed critter must spawn: the oldest unbought critter of the lowest
-- rarity leaves the conveyor. Timed critters and critters in an open Robux prompt always stay.
local function makeRoom()
	if entryCount < CONVEYOR.MaxCritters then
		return
	end
	local prompted = {}
	for _, pending in pendingRobux do
		prompted[pending.EntryId] = true
	end
	local victim: Entry? = nil
	local victimIndex = math.huge
	for id, entry in entries do
		local index = Rarities.GetIndex(entry.Rarity)
		if
			not entry.Sold
			and not prompted[id]
			and not Rarities.IsTimed(entry.Rarity)
			and (index < victimIndex or (index == victimIndex and victim and entry.SpawnedAt < victim.SpawnedAt))
		then
			victim, victimIndex = entry, index
		end
	end
	if victim then
		removeEntry(victim)
		victim.Model:Destroy()
	end
end

local function spawnRarity(rarity: string): boolean
	local def = Units.PickFromRarity(rarity)
	return def ~= nil and spawnCritter(def.Name, Mutations.Roll(BoostService.GetServerLuck()))
end

-- Rare spawn timers --------------------------------------------------------------

-- Timer seconds that pass between two server times (Server Luck speeds the timers up).
local function timerProgress(from: number, to: number): number
	local boostEndsAt, multiplier = BoostService.GetServerLuckWindow()
	local elapsed = math.max(0, to - from)
	local boosted = math.clamp(boostEndsAt - from, 0, elapsed)
	return elapsed + boosted * (multiplier - 1)
end

-- Server time at which `remaining` timer seconds will have passed (accounts for the boost ending).
local function timeWhenDone(from: number, remaining: number): number
	local boostEndsAt, multiplier = BoostService.GetServerLuckWindow()
	local boostedWindow = math.max(0, boostEndsAt - from)
	if remaining <= boostedWindow * multiplier then
		return from + remaining / multiplier
	end
	return from + boostedWindow + (remaining - boostedWindow * multiplier)
end

-- Sends the predicted spawn time to the clients when it moved (luck bought or ended, spawn...).
local function publishTimer(timer: RareTimer, force: boolean?)
	local spawnAt = timeWhenDone(lastTimerUpdate, math.max(0, timer.Remaining))
	if force or not timer.PublishedAt or math.abs(spawnAt - (timer.PublishedAt :: number)) > 0.75 then
		timer.PublishedAt = spawnAt
		rareFolder:SetAttribute(timer.Rarity, spawnAt)
	end
end

local function updateRareTimers()
	local now = workspace:GetServerTimeNow()
	local progress = timerProgress(lastTimerUpdate, now)
	lastTimerUpdate = now
	for _, timer in rareTimers do
		timer.Remaining -= progress
		local warnBefore = RARE.Timers[timer.Rarity].WarnBefore
		if warnBefore and not timer.Warned and timer.Remaining > 0 then
			local left = timeWhenDone(now, timer.Remaining) - now
			if left <= warnBefore then
				timer.Warned = true
				local when = Format.Time(math.ceil(left))
				Notifier.All(`⏰ A {string.upper(timer.Rarity)} critter spawns in {when} at the NEW CRITTERS portal!`, "announce")
			end
		end
		publishTimer(timer)
	end
end

local function restartTimer(timer: RareTimer, seconds: number)
	timer.Remaining = seconds
	timer.Warned = false
	publishTimer(timer, true)
end

-- One scheduler step: a due rare critter first (rarest first), otherwise the regular random spawn.
local function spawnStep()
	updateRareTimers()
	local clock = os.clock()

	local due: RareTimer? = nil
	for _, timer in rareTimers do
		if timer.Remaining <= 0 and (not due or Rarities.GetIndex(timer.Rarity) > Rarities.GetIndex(due.Rarity)) then
			due = timer
		end
	end
	if due then
		-- Wait until the previous critter moved away from the portal (they would overlap).
		if clock - lastSpawnClock < RARE.MinGap then
			return
		end
		lastSpawnClock = clock
		nextRandomClock = math.max(nextRandomClock, clock + CONVEYOR.SpawnInterval)
		-- The board promised it: a timed critter spawns even when the conveyor is full.
		makeRoom()
		local ok, result = pcall(spawnRarity, due.Rarity)
		if not ok or not result then
			warn(`[ConveyorService] Timed {due.Rarity} spawn failed: {result}`)
		end
		-- Restarted even after a failure so a broken spawn cannot retry every tick.
		local spawnedAt = workspace:GetServerTimeNow()
		rareFolder:SetAttribute(due.Rarity .. "Last", spawnedAt)
		rareFolder:SetAttribute(due.Rarity .. "From", spawnedAt)
		restartTimer(due, RARE.Timers[due.Rarity].Interval)
		return
	end

	if clock >= nextRandomClock then
		nextRandomClock = clock + CONVEYOR.SpawnInterval
		if entryCount < CONVEYOR.MaxCritters then
			lastSpawnClock = clock
			local ok, err = pcall(spawnRandom)
			if not ok then
				warn("[ConveyorService] Spawn failed: " .. tostring(err))
			end
		end
	end
end

local function setupRareTimers()
	local folder = ReplicatedStorage:FindFirstChild("RareSpawns")
	if not (folder and folder:IsA("Folder")) then
		folder = Instance.new("Folder")
		folder.Name = "RareSpawns"
		folder.Parent = ReplicatedStorage
	end
	rareFolder = folder :: Folder

	lastTimerUpdate = workspace:GetServerTimeNow()
	local random = Random.new()
	for _, rarity in RARE.Order do
		local settings = RARE.Timers[rarity]
		if settings then
			local first = settings.First
			local timer: RareTimer = {
				Rarity = rarity,
				Remaining = random:NextNumber(first[1], first[2] or first[1]),
				Warned = false,
			}
			table.insert(rareTimers, timer)
			rareFolder:SetAttribute(rarity .. "From", lastTimerUpdate)
			publishTimer(timer, true)
		end
	end
end

-- Rare critters board --------------------------------------------------------------

-- Reserved map zone next to the NEW CRITTERS portal: x in [-232, -198], z in [-38, -16].
local BOARD_POSITION = Vector3.new(-215, 0, -27) -- ground point under the middle of the board
local BOARD_TURN = math.rad(10) -- faces the conveyor, slightly turned towards the spawn (both read it)
local BOARD_WIDTH = 24
local BOARD_HEIGHT = 15
local BOARD_BOTTOM = 3.5 -- the lower rows stay visible above the players' heads
local BOARD_PIXELS = 40 -- SurfaceGui canvas: 960 x 600 pixels
local BOARD_TAG = "RareSpawnBoard"

local GOLD = Color3.fromRGB(255, 205, 80)
local STONE = Color3.fromRGB(150, 145, 160)
local POST_STONE = Color3.fromRGB(105, 96, 128)
local MAGIC = Color3.fromRGB(170, 110, 255)
local SUBTEXT = Color3.fromRGB(205, 195, 235)

local function create(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function boardLabel(parent: Instance, props: { [string]: any }): TextLabel
	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = Color3.fromRGB(20, 12, 35),
		TextStrokeTransparency = 0.2,
	}, nil)
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

local function describeInterval(seconds: number): string
	local minutes = math.floor(seconds / 60 + 0.5)
	if minutes >= 60 and minutes % 60 == 0 then
		local hours = minutes // 60
		return if hours == 1 then "Every hour" else `Every {hours} hours`
	end
	return `Every {minutes} min`
end

-- One row: rarity gem, name, interval, countdown (updated by BoardsController) and progress bar.
local function buildBoardRow(parent: Instance, rarity: string, y: number, height: number)
	local color = Rarities.Info[rarity].Color
	local row = create("Frame", {
		Name = rarity,
		Position = UDim2.fromOffset(24, y),
		Size = UDim2.new(1, -48, 0, height),
		BackgroundColor3 = Color3.fromRGB(12, 8, 24),
		BackgroundTransparency = 0.25,
	}, parent)
	create("UICorner", { CornerRadius = UDim.new(0, 18) }, row)
	create("UIStroke", { Color = color, Thickness = 4 }, row)

	local gem = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(58, height / 2),
		Size = UDim2.fromOffset(50, 50),
		Rotation = 45,
		BackgroundColor3 = color,
	}, row)
	create("UICorner", { CornerRadius = UDim.new(0, 8) }, gem)
	create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3, Transparency = 0.25 }, gem)

	boardLabel(row, {
		Name = "RarityName",
		Text = string.upper(rarity),
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(108, 8),
		Size = UDim2.fromOffset(400, 58),
	})
	boardLabel(row, {
		Name = "Interval",
		Text = describeInterval(RARE.Timers[rarity].Interval),
		TextColor3 = SUBTEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(110, 66),
		Size = UDim2.fromOffset(300, 28),
	})
	local countdown = boardLabel(row, {
		Name = "Countdown",
		Text = "--:--",
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -22, 0, 8),
		Size = UDim2.fromOffset(380, 86),
	})
	countdown:SetAttribute("RareCountdown", rarity)

	local track = create("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 108, 1, -10),
		Size = UDim2.new(1, -130, 0, 10),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
	}, row)
	create("UICorner", { CornerRadius = UDim.new(0, 5) }, track)
	local fill = create("Frame", {
		Name = "Progress",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color,
	}, track)
	create("UICorner", { CornerRadius = UDim.new(0, 5) }, fill)
end

local function buildBoardGui(panel: BasePart)
	local gui = create("SurfaceGui", {
		Name = "RareBoardGui",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = BOARD_PIXELS,
		LightInfluence = 0,
		MaxDistance = 500,
	}, panel)
	local background = create("Frame", {
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, gui)
	create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(62, 42, 100), Color3.fromRGB(22, 16, 40)),
		Rotation = 90,
	}, background)

	boardLabel(background, {
		Name = "Title",
		Text = "✨ RARE CRITTERS ✨",
		TextColor3 = GOLD,
		Position = UDim2.fromOffset(30, 28),
		Size = UDim2.new(1, -60, 0, 78),
	})
	boardLabel(background, {
		Name = "Subtitle",
		Text = "Next spawns at the NEW CRITTERS portal",
		TextColor3 = SUBTEXT,
		Position = UDim2.fromOffset(60, 106),
		Size = UDim2.new(1, -120, 0, 30),
	})

	local rowHeight, gap, firstY = 114, 10, 144
	for index, rarity in RARE.Order do
		if RARE.Timers[rarity] then
			buildBoardRow(background, rarity, firstY + (index - 1) * (rowHeight + gap), rowHeight)
		end
	end

	local multiplier = GameConfig.ServerLuck.Multiplier
	boardLabel(background, {
		Name = "LuckLine",
		Text = `🍀 {multiplier}x Server Luck = rare timers {multiplier}x faster!`,
		TextColor3 = Color3.fromRGB(150, 235, 150),
		Position = UDim2.fromOffset(60, 516),
		Size = UDim2.new(1, -120, 0, 44),
	})

	-- The back only carries the title (seen from the bases).
	local back = create("SurfaceGui", {
		Name = "RareBoardBack",
		Face = Enum.NormalId.Back,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = BOARD_PIXELS,
		LightInfluence = 0,
		MaxDistance = 300,
	}, panel)
	boardLabel(back, {
		Text = "✨ RARE CRITTERS ✨",
		TextColor3 = GOLD,
		Position = UDim2.fromOffset(40, 200),
		Size = UDim2.new(1, -80, 0, 110),
	})
	boardLabel(back, {
		Text = "Spawn timers on the other side",
		TextColor3 = SUBTEXT,
		Position = UDim2.fromOffset(80, 320),
		Size = UDim2.new(1, -160, 0, 44),
	})
end

-- Big public board with the countdowns: slate panel, gold bars, stone posts, rarity crystals.
local function buildRareBoard()
	local model = Instance.new("Model")
	model.Name = "RareSpawnBoard"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- if StreamingEnabled is turned on

	local normal = Vector3.new(-math.sin(BOARD_TURN), 0, math.cos(BOARD_TURN)) -- towards the viewers
	local right = (-normal):Cross(Vector3.yAxis) -- the viewers' right
	local function at(x: number, y: number, z: number): Vector3
		return BOARD_POSITION + right * x + Vector3.yAxis * y + normal * z
	end
	local half = BOARD_WIDTH / 2
	local top = BOARD_BOTTOM + BOARD_HEIGHT

	local center = at(0, BOARD_BOTTOM + BOARD_HEIGHT / 2, 0)
	local panel = Decor.Part({
		Name = "Panel",
		Size = Vector3.new(BOARD_WIDTH, BOARD_HEIGHT, 0.8),
		CFrame = CFrame.lookAt(center, center + normal),
		Color = Color3.fromRGB(40, 32, 60),
		Material = Enum.Material.Slate,
	}, model)
	buildBoardGui(panel)

	local gold = { Color = GOLD, Material = Enum.Material.Metal, CollisionGroup = "Decor", Name = "Frame" }
	local stone = { Color = POST_STONE, Material = Enum.Material.Slate, CollisionGroup = "Decor", Name = "Post" }
	local rock = { Color = STONE, Material = Enum.Material.Slate, CollisionGroup = "Decor", Name = "Rock" }

	-- Gold bars along the top and bottom edges (their ends disappear in the posts).
	for _, y in { top + 0.3, BOARD_BOTTOM - 0.3 } do
		LowPoly.Tube({ at(-half - 0.5, y, 0), at(half + 0.5, y, 0) }, { 0.8 }, gold, model, { Sides = 3, Up = normal })
	end

	for side = -1, 1, 2 do
		local x = side * (half + 0.9)
		-- Faceted stone post with a pointed top, standing on a rock, crowned by a floating gem.
		LowPoly.Tube({ at(x, -0.5, 0), at(x, top + 1.6, 0) }, { 1.35, 1.0 }, stone, model, {
			Sides = 4,
			CapStart = 0,
			CapEnd = 1.3,
		})
		LowPoly.Rock(CFrame.new(at(x, 0.5, 0)), Vector3.new(4.4, 2.4, 4.4), 11 + side, rock, model, 0.3)
		local gem = LowPoly.Ball(
			CFrame.new(at(x, top + 4.4, 0)) * CFrame.Angles(0, math.rad(45), 0),
			Vector3.new(1.3, 1.9, 1.3),
			{ Color = MAGIC, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false, Name = "Gem" },
			model,
			0
		)
		if gem[1] then
			Decor.Light(gem[1], MAGIC, 14, 1.5)
		end

		-- Two crystal shards growing out of the ground at the foot of the post.
		for index, shard in { { 1.6, -1.4, 2.6 }, { 2.4, 0.9, 1.8 } } do
			local rarity = RARE.Order[(index + (side + 1) // 2) % #RARE.Order + 1]
			local base = at(x + side * shard[1], 0, shard[2])
			local tip = base + Vector3.new(0, shard[3], 0) + right * (side * 0.8)
			LowPoly.Cone(base, tip, 0.45, {
				Color = Rarities.Info[rarity].Color,
				Material = Enum.Material.Neon,
				CanCollide = false,
				CastShadow = false,
				Name = "Shard",
			}, model, 4)
		end
	end

	-- Crystal crest in the colours of the three rarities (the rarest in the middle).
	for _, crystal in
		{
			{ Rarity = "Legendary", X = -4.6, Height = 3.4, Radius = 0.9, Tilt = 16 },
			{ Rarity = "Secret", X = 0, Height = 5.2, Radius = 1.25, Tilt = 0 },
			{ Rarity = "Mythic", X = 4.6, Height = 3.4, Radius = 0.9, Tilt = -16 },
		}
	do
		local info = Rarities.Info[crystal.Rarity]
		if info then
			local base = CFrame.fromMatrix(at(crystal.X, top + 0.6, 0), right, Vector3.yAxis)
			local cframe = base * CFrame.Angles(0, 0, math.rad(crystal.Tilt)) * CFrame.new(0, crystal.Height / 2, 0)
			local size = Vector3.new(crystal.Radius * 2, crystal.Height, crystal.Radius * 2)
			local mesh = LowPoly.TransformMesh(LowPoly.Bipyramid(5, -0.55), cframe, size)
			local parts = LowPoly.DrawTriangles(LowPoly.MeshTriangles(mesh, cframe.Position), {
				Color = info.Color,
				Material = Enum.Material.Neon,
				Transparency = 0.1,
				CanCollide = false,
				CastShadow = false,
				Name = "Crystal",
			}, model, 0.12)
			if parts[1] and crystal.Rarity == "Secret" then
				Decor.Light(parts[1], info.Color, 18, 1.5)
			end
		end
	end

	CollectionService:AddTag(model, BOARD_TAG)
	model.Parent = workspace:FindFirstChild("Map") or workspace
	return model
end

-- Robux purchases ---------------------------------------------------------------------

-- Robux "Unit" products: the critter the player clicked on, or a random one of that rarity.
-- Must not yield (called from ProcessReceipt) and never refuses a paid purchase.
local function grantRobuxUnit(player: Player, _productKey: string, product): boolean
	local rarity = product.Rarity
	local pending = pendingRobux[player]
	pendingRobux[player] = nil

	-- Bought from the conveyor: you always get exactly the critter you clicked on.
	if pending and pending.Rarity == rarity and os.clock() - pending.Time < 300 then
		local entry = entries[pending.EntryId]
		if entry and not entry.Sold then
			-- One critter walks home at a time: if another one is still on its way, this one
			-- appears straight on its pedestal instead.
			local walk = not UnitService.HasCritterInTransit(player)
			local guid = deliver(entry, player, walk)
			if guid then
				local where = if walk then "It's walking to your base." else "It's waiting on its pedestal."
				Notifier.Send(player, `💎 {entry.UnitName} is yours! {where}`, "success")
			end
		else
			-- Someone bought it with cash while the prompt was open: give an identical one.
			UnitService.GrantUnit(player, pending.UnitName, pending.Mutation)
			Notifier.Send(player, `💎 {pending.UnitName} is yours!`, "success")
		end
		return true
	end

	-- Bought from the store: random critter of that rarity (odds are shown in the store).
	local def = Units.PickFromRarity(rarity)
	if not def then
		return false
	end
	UnitService.GrantUnit(player, def.Name, "None")
	Notifier.Send(player, `💎 You got a {rarity} {def.Name}!`, "success")
	return true
end

-- Lifecycle ---------------------------------------------------------------------------

function ConveyorService.Init(services)
	MapService = services.MapService
	UnitService = services.UnitService
	CurrencyService = services.CurrencyService
	MonetizationService = services.MonetizationService
	BoostService = services.BoostService
	PlotService = services.PlotService
end

function ConveyorService.OnPlayerRemoving(player: Player)
	pendingRobux[player] = nil
end

function ConveyorService.Start()
	MonetizationService.RegisterKindHandler("Unit", grantRobuxUnit)

	-- A cancelled conveyor prompt must not affect a later store purchase.
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _productId, isPurchased)
		local player = Players:GetPlayerByUserId(userId)
		if player and not isPurchased then
			pendingRobux[player] = nil
		end
	end)

	setupRareTimers()
	local ok, err = pcall(buildRareBoard)
	if not ok then
		warn("[ConveyorService] Rare critters board failed: " .. tostring(err))
	end

	-- Buying Server Luck moves the countdowns right away.
	BoostService.LuckChanged:Connect(updateRareTimers)

	nextRandomClock = os.clock() + CONVEYOR.SpawnInterval
	task.spawn(function()
		while true do
			task.wait(TICK)
			local stepOk, stepErr = pcall(spawnStep)
			if not stepOk then
				warn("[ConveyorService] Spawn step failed: " .. tostring(stepErr))
			end
		end
	end)
end

-- Exposed for admin tools / live events: spawns a given critter at the start of the conveyor.
ConveyorService.SpawnCritter = spawnCritter

-- Live events: the next critter of a timed rarity ("Legendary", "Mythic", "Secret") spawns now,
-- then its timer restarts as usual.
function ConveyorService.TriggerRareSpawn(rarity: string): boolean
	for _, timer in rareTimers do
		if timer.Rarity == rarity then
			restartTimer(timer, 0)
			return true
		end
	end
	return false
end

return ConveyorService
