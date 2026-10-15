--[[
	LeaderboardService
	The two global leaderboards next to the spawn: "TOP REBIRTHS" and "TOP MONEY".

	- Scores live in two OrderedDataStores (GameConfig.Leaderboard.Stores), one key per UserId,
	  integer values. Every RefreshInterval seconds the scores of the players in this server are
	  written (only the ones that changed, within the DataStore request budget), then the top of
	  each store is read back and drawn on the boards. A player's scores are also written when
	  they leave (without yielding the leave sequence).
	- Rebirths = data.Rebirths. Money = data.TotalEarned, all the money ever earned: unlike the
	  current cash it is not reset by a rebirth and does not drop when a player buys critters, so
	  the board rewards progress instead of hoarding.
	- Names come from Players:GetNameFromUserIdAsync (cached). Players in this server are
	  highlighted, and their live scores are merged in (the stores are only eventually consistent).
	- Without DataStores (Studio without API access) the boards say "LEADERBOARD OFFLINE" and the
	  service keeps retrying. Studio sessions never submit scores (GameConfig.Leaderboard.WriteInStudio).
	- Server-rendered: physical boards with a SurfaceGui, nothing to do on the client.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local GameConfig = require(Shared.Config.GameConfig)

local Decor = require(script.Parent.Parent.Modules.Decor)
local LowPoly = require(script.Parent.Parent.Modules.LowPoly)

local LeaderboardService = {}

local LEADERBOARD = GameConfig.Leaderboard
local MAX_SCORE = 2 ^ 53 -- integers above this cannot be stored exactly in a Luau number
local WRITE_REQUEST = Enum.DataStoreRequestType.SetIncrementSortedAsync
local READ_REQUEST = Enum.DataStoreRequestType.GetSortedAsync
local LEAVE_WRITE_ATTEMPTS = 4 -- tries (2 s apart) to save the scores of a leaving player
local OFFLINE_RETRY = 30 -- seconds between two tries while a board has never been read

-- Board geometry. Reserved map zones: x in [-288, -238], z in [18, 44] and z in [-44, -18]
-- (each board's footprint, rotated towards the spawn, stays about 4 studs inside its zone).
local BOARD_WIDTH = 22
local BOARD_HEIGHT = 18
local BOARD_BOTTOM = 3 -- the lowest rows stay visible above the players' heads
local BOARD_PIXELS = 40 -- SurfaceGui canvas: 880 x 720 pixels
local ROW_TOP, ROW_HEIGHT, ROW_GAP = 134, 46, 6

local GOLD = Color3.fromRGB(255, 205, 80)
local STONE = Color3.fromRGB(150, 145, 160)
local POST_STONE = Color3.fromRGB(105, 96, 128)
local SUBTEXT = Color3.fromRGB(205, 195, 235)
local TEXT_STROKE = Color3.fromRGB(20, 12, 35)
local ROW_COLOR = Color3.fromRGB(12, 8, 24)
local ROW_OUTLINE = Color3.fromRGB(70, 60, 100)
local HERE_COLOR = Color3.fromRGB(120, 235, 120)
local HERE_ROW_COLOR = Color3.fromRGB(16, 52, 26)
local OFFLINE_COLOR = Color3.fromRGB(255, 110, 110)
local MEDALS = {
	Color3.fromRGB(255, 205, 70), -- gold
	Color3.fromRGB(205, 215, 230), -- silver
	Color3.fromRGB(215, 145, 85), -- bronze
}

type BoardDef = {
	Key: string, -- key in GameConfig.Leaderboard.Stores
	Title: string,
	Subtitle: string,
	Position: Vector3, -- ground point under the middle of the board
	Accent: Color3, -- scores, crest gem
	Top: Color3, -- background gradient
	Bottom: Color3,
	PanelColor: Color3,
	GetScore: (data: { [string]: any }) -> any,
	FormatScore: (score: number) -> string,
}

type Entry = { UserId: number, Score: number, Name: string }

type Row = {
	Frame: Frame,
	Name: TextLabel,
	Score: TextLabel,
	Here: Frame,
}

type Board = {
	Def: BoardDef,
	Store: OrderedDataStore?,
	Entries: { Entry }?, -- last top list (nil until the first successful read)
	Failed: boolean, -- the last read failed (problems are only logged when this turns true)
	Rows: { Row },
	Status: TextLabel,
	Detail: TextLabel,
	Footer: TextLabel,
	Legend: TextLabel,
}

local BOARD_DEFS: { BoardDef } = {
	{
		Key = "Money",
		Title = "💰 TOP MONEY 💰",
		Subtitle = "Most money earned of all time",
		Position = Vector3.new(-263, 0, -31),
		Accent = Color3.fromRGB(120, 240, 130),
		Top = Color3.fromRGB(30, 88, 70),
		Bottom = Color3.fromRGB(10, 32, 30),
		PanelColor = Color3.fromRGB(22, 52, 46),
		GetScore = function(data)
			return data.TotalEarned
		end,
		FormatScore = Format.Money,
	},
	{
		Key = "Rebirths",
		Title = "♻️ TOP REBIRTHS ♻️",
		Subtitle = "Most rebirths of all time",
		Position = Vector3.new(-263, 0, 31),
		Accent = Color3.fromRGB(255, 125, 220),
		Top = Color3.fromRGB(80, 40, 110),
		Bottom = Color3.fromRGB(24, 14, 42),
		PanelColor = Color3.fromRGB(44, 30, 64),
		GetScore = function(data)
			return data.Rebirths
		end,
		FormatScore = Format.Number,
	},
}

local DataService, MapService

local boards: { Board } = {}
-- Last value written per store and UserId (skips writes of unchanged scores).
local lastWritten: { [string]: { [number]: number } } = {}
local nameCache: { [number]: string } = {}
local pendingWrites = 0
local canWrite = not RunService:IsStudio() or LEADERBOARD.WriteInStudio

-- Data helpers ---------------------------------------------------------------------------

-- Ordered stores only take integers: floor, and clamp to [0, 2^53].
local function toScore(value: any): number
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, MAX_SCORE)
end

local function hasBudget(requestType: Enum.DataStoreRequestType): boolean
	local ok, budget = pcall(DataStoreService.GetRequestBudgetForRequestType, DataStoreService, requestType)
	-- If the budget cannot be read, let the (pcalled) request decide.
	return not ok or budget >= 1
end

local function describeInterval(seconds: number): string
	if seconds >= 60 and seconds % 60 == 0 then
		return `{seconds // 60} min`
	end
	return `{seconds} s`
end

-- Current scores of a player of this server, or nil (data not loaded, guest / Studio test account).
-- Works during OnPlayerRemoving too (the data is released after it).
local function getScores(player: Player): { [string]: number }?
	if player.UserId <= 0 then
		return nil
	end
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local scores = {}
	for _, board in boards do
		scores[board.Def.Key] = toScore(board.Def.GetScore(data))
	end
	return scores
end

local function openStores()
	for _, board in boards do
		if not board.Store then
			local ok, result = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, LEADERBOARD.Stores[board.Def.Key])
			if ok then
				board.Store = result
			elseif not board.Failed then
				warn(`[LeaderboardService] Cannot open the {board.Def.Key} store: {result}`)
			end
		end
	end
end

-- Yields. Returns true when the score is stored (or did not need to be written).
local function writeScore(board: Board, userId: number, score: number): boolean
	local written = lastWritten[board.Def.Key]
	if score <= 0 or written[userId] == score then
		return true
	end
	local store = board.Store
	if not store or not hasBudget(WRITE_REQUEST) then
		return false
	end
	local ok, err = pcall(store.SetAsync, store, tostring(userId), score)
	if not ok then
		warn(`[LeaderboardService] Could not save the {board.Def.Key} score of {userId}: {err}`)
		return false
	end
	written[userId] = score
	return true
end

-- Yields. Writes the scores of everybody in the server (players who left meanwhile are skipped:
-- OnPlayerRemoving takes care of them).
local function writeAll()
	for _, player in Players:GetPlayers() do
		local userId = player.UserId
		for _, board in boards do
			-- Read again before every write: the previous one yielded.
			local scores = if player.Parent then getScores(player) else nil
			if not scores then
				break
			end
			writeScore(board, userId, scores[board.Def.Key])
		end
	end
end

local function getName(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.Name
		return player.Name
	end
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	if ok and type(name) == "string" then
		nameCache[userId] = name
		return name
	end
	return `User {userId}` -- not cached: try again next refresh
end

-- Yields. Returns the top of a store, or nil + whether it is a real failure (vs. no budget left).
local function readTop(board: Board): ({ Entry }?, boolean)
	local store = board.Store
	if not store then
		return nil, true
	end
	if not hasBudget(READ_REQUEST) then
		return nil, false
	end
	local ok, result = pcall(function()
		return store:GetSortedAsync(false, LEADERBOARD.TopCount):GetCurrentPage()
	end)
	if not ok then
		if not board.Failed then
			warn(`[LeaderboardService] Could not read the {board.Def.Key} leaderboard: {result}`)
		end
		return nil, true
	end
	local entries: { Entry } = {}
	for _, item in result do
		local userId = tonumber(item.key)
		local score = toScore(item.value)
		if userId and userId > 0 and score > 0 then
			table.insert(entries, { UserId = userId, Score = score, Name = "" })
		end
	end
	return entries, false
end

-- Players of this server replace their (maybe outdated) stored score with their live one.
local function mergeLiveScores(board: Board, entries: { Entry })
	if not canWrite then
		return -- they are never submitted from Studio: keep the board truthful
	end
	local byUser: { [number]: Entry } = {}
	for _, entry in entries do
		byUser[entry.UserId] = entry
	end
	for _, player in Players:GetPlayers() do
		local scores = getScores(player)
		local score = if scores then scores[board.Def.Key] else 0
		if score > 0 then
			local entry = byUser[player.UserId]
			if entry then
				entry.Score = score
			else
				table.insert(entries, { UserId = player.UserId, Score = score, Name = "" })
			end
		end
	end
	table.sort(entries, function(a, b)
		if a.Score ~= b.Score then
			return a.Score > b.Score
		end
		return a.UserId < b.UserId
	end)
	for index = #entries, LEADERBOARD.TopCount + 1, -1 do
		entries[index] = nil
	end
end

-- Board GUI -------------------------------------------------------------------------------

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
		TextStrokeColor3 = TEXT_STROKE,
		TextStrokeTransparency = 0.2,
	}, nil)
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

-- One row: rank badge (gold / silver / bronze for the top 3), name, "HERE" tag, score.
local function buildRow(parent: Instance, rank: number, accent: Color3): Row
	local medal = MEDALS[rank]
	local frame = create("Frame", {
		Name = `Rank{rank}`,
		Position = UDim2.fromOffset(24, ROW_TOP + (rank - 1) * (ROW_HEIGHT + ROW_GAP)),
		Size = UDim2.new(1, -48, 0, ROW_HEIGHT),
		BackgroundColor3 = ROW_COLOR,
		BackgroundTransparency = 0.25,
		Visible = false,
	}, parent)
	create("UICorner", { CornerRadius = UDim.new(0, 12) }, frame)
	create("UIStroke", { Color = medal or ROW_OUTLINE, Thickness = if medal then 3 else 2 }, frame)

	local badge = create("Frame", {
		Name = "Badge",
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.fromOffset(ROW_HEIGHT - 8, ROW_HEIGHT - 8),
		BackgroundColor3 = medal or ROW_COLOR,
		BackgroundTransparency = if medal then 0 else 1,
	}, frame)
	create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, badge)
	if medal then
		create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.3 }, badge)
	end
	boardLabel(badge, {
		Name = "Rank",
		Text = tostring(rank),
		TextColor3 = if medal then TEXT_STROKE else SUBTEXT,
		TextStrokeTransparency = if medal then 1 else 0.2,
		Position = UDim2.fromScale(0.15, 0.12),
		Size = UDim2.fromScale(0.7, 0.76),
	})

	local name = boardLabel(frame, {
		Name = "PlayerName",
		Text = "",
		TextColor3 = medal or Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(ROW_HEIGHT + 8, 5),
		Size = UDim2.new(1, -(ROW_HEIGHT + 8 + 370), 0, ROW_HEIGHT - 10),
	})

	local here = create("Frame", {
		Name = "Here",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -262, 0.5, 0),
		Size = UDim2.fromOffset(92, 28),
		BackgroundColor3 = HERE_COLOR,
		Visible = false,
	}, frame)
	create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, here)
	boardLabel(here, {
		Text = "HERE",
		TextColor3 = TEXT_STROKE,
		TextStrokeTransparency = 1,
		Position = UDim2.fromScale(0.1, 0.12),
		Size = UDim2.fromScale(0.8, 0.76),
	})

	local score = boardLabel(frame, {
		Name = "Score",
		Text = "",
		TextColor3 = accent,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 5),
		Size = UDim2.fromOffset(236, ROW_HEIGHT - 10),
	})

	return { Frame = frame, Name = name, Score = score, Here = here }
end

local function buildGui(panel: BasePart, def: BoardDef): (Frame, { Row })
	local gui = create("SurfaceGui", {
		Name = "LeaderboardGui",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = BOARD_PIXELS,
		LightInfluence = 0,
		MaxDistance = 400,
	}, panel)
	local background = create("Frame", {
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, gui)
	create("UIGradient", { Color = ColorSequence.new(def.Top, def.Bottom), Rotation = 90 }, background)

	boardLabel(background, {
		Name = "Title",
		Text = def.Title,
		TextColor3 = GOLD,
		Position = UDim2.fromOffset(30, 16),
		Size = UDim2.new(1, -60, 0, 76),
	})
	boardLabel(background, {
		Name = "Subtitle",
		Text = def.Subtitle,
		TextColor3 = SUBTEXT,
		Position = UDim2.fromOffset(60, 92),
		Size = UDim2.new(1, -120, 0, 32),
	})

	local rows = {}
	for rank = 1, LEADERBOARD.TopCount do
		rows[rank] = buildRow(background, rank, def.Accent)
	end

	-- The back only carries the title (seen from the edge of the map).
	local back = create("SurfaceGui", {
		Name = "LeaderboardBack",
		Face = Enum.NormalId.Back,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = BOARD_PIXELS,
		LightInfluence = 0,
		MaxDistance = 250,
	}, panel)
	boardLabel(back, {
		Text = def.Title,
		TextColor3 = GOLD,
		Position = UDim2.fromOffset(40, 260),
		Size = UDim2.new(1, -80, 0, 100),
	})
	boardLabel(back, {
		Text = "Global leaderboard on the other side",
		TextColor3 = SUBTEXT,
		Position = UDim2.fromOffset(80, 370),
		Size = UDim2.new(1, -160, 0, 40),
	})

	return background, rows
end

-- Board model -----------------------------------------------------------------------------

local function buildBoard(def: BoardDef, parent: Instance, facing: Vector3): Board
	local model = Instance.new("Model")
	model.Name = `Leaderboard{def.Key}`
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- if StreamingEnabled is turned on

	-- Faces `facing` (the spawn), turned only around the vertical axis.
	local flat = Vector3.new(facing.X - def.Position.X, 0, facing.Z - def.Position.Z)
	local normal = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.xAxis -- towards the viewers
	local right = (-normal):Cross(Vector3.yAxis) -- the viewers' right
	local function at(x: number, y: number, z: number): Vector3
		return def.Position + right * x + Vector3.yAxis * y + normal * z
	end
	local half = BOARD_WIDTH / 2
	local top = BOARD_BOTTOM + BOARD_HEIGHT

	-- The panel carries the text: a plain slab (functional surface).
	local center = at(0, BOARD_BOTTOM + BOARD_HEIGHT / 2, 0)
	local panel = Decor.Part({
		Name = "Panel",
		Size = Vector3.new(BOARD_WIDTH, BOARD_HEIGHT, 0.8),
		CFrame = CFrame.lookAt(center, center + normal),
		Color = def.PanelColor,
		Material = Enum.Material.Slate,
	}, model)
	local background, rows = buildGui(panel, def)

	local gold = { Color = GOLD, Material = Enum.Material.Metal, CollisionGroup = "Decor", Name = "Frame" }
	local stone = { Color = POST_STONE, Material = Enum.Material.Slate, CollisionGroup = "Decor", Name = "Post" }
	local rock = { Color = STONE, Material = Enum.Material.Slate, CollisionGroup = "Decor", Name = "Rock" }

	-- Gold bars along the top and bottom edges (their ends disappear in the posts).
	for _, y in { top + 0.3, BOARD_BOTTOM - 0.3 } do
		LowPoly.Tube({ at(-half - 0.5, y, 0), at(half + 0.5, y, 0) }, { 0.8 }, gold, model, { Sides = 3, Up = normal })
	end

	-- Faceted stone posts with pointed tops, standing on rocks.
	for side = -1, 1, 2 do
		local x = side * (half + 0.9)
		LowPoly.Tube({ at(x, -0.5, 0), at(x, top + 1.8, 0) }, { 1.35, 1.0 }, stone, model, {
			Sides = 4,
			CapStart = 0,
			CapEnd = 1.3,
		})
		LowPoly.Rock(CFrame.new(at(x, 0.5, 0)), Vector3.new(4.4, 2.4, 4.4), 23 + side, rock, model, 0.3)
	end

	-- Gold crown on the top bar, a glowing gem in the board colour in its middle.
	for _, spike in
		{
			{ X = -5.2, Height = 2.2, Lean = -0.9 },
			{ X = -2.6, Height = 3, Lean = 0 },
			{ X = 2.6, Height = 3, Lean = 0 },
			{ X = 5.2, Height = 2.2, Lean = 0.9 },
		}
	do
		local base = at(spike.X, top + 0.5, 0)
		LowPoly.Cone(base, base + Vector3.yAxis * spike.Height + right * spike.Lean, 0.75, gold, model, 4)
	end
	local gemFrame = CFrame.fromMatrix(at(0, top + 3.1, 0), right, Vector3.yAxis)
	local gemSize = Vector3.new(2.6, 4.6, 2.6)
	local gemMesh = LowPoly.TransformMesh(LowPoly.Bipyramid(5, -0.3), gemFrame, gemSize)
	local gem = LowPoly.DrawTriangles(LowPoly.MeshTriangles(gemMesh, gemFrame.Position), {
		Color = def.Accent,
		Material = Enum.Material.Neon,
		Transparency = 0.1,
		CanCollide = false,
		CastShadow = false,
		Name = "Gem",
	}, model, 0.12)
	if gem[1] then
		Decor.Light(gem[1], def.Accent, 18, 1.5)
	end

	-- State labels over the rows area (loading / empty / offline) and the footer.
	local status = boardLabel(background, {
		Name = "Status",
		Text = "Loading...",
		TextColor3 = SUBTEXT,
		Position = UDim2.fromOffset(40, 270),
		Size = UDim2.new(1, -80, 0, 76),
	})
	local detail = boardLabel(background, {
		Name = "Detail",
		Text = "",
		TextColor3 = SUBTEXT,
		Position = UDim2.fromOffset(70, 356),
		Size = UDim2.new(1, -140, 0, 34),
	})
	local footer = boardLabel(background, {
		Name = "Footer",
		Text = `🔄 Updated every {describeInterval(LEADERBOARD.RefreshInterval)}`,
		TextColor3 = SUBTEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(30, 662),
		Size = UDim2.new(1, -330, 0, 34),
	})
	local legend = boardLabel(background, {
		Name = "Legend",
		Text = "HERE = in this server",
		TextColor3 = HERE_COLOR,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -30, 0, 662),
		Size = UDim2.fromOffset(280, 34),
		Visible = false,
	})

	model.Parent = parent
	return {
		Def = def,
		Store = nil,
		Entries = nil,
		Failed = false,
		Rows = rows,
		Status = status,
		Detail = detail,
		Footer = footer,
		Legend = legend,
	}
end

-- Draws the last known state of a board. Never yields.
-- leavingUserId: a player who is leaving right now (no "HERE" tag any more).
local function render(board: Board, leavingUserId: number?)
	local entries = board.Entries
	local anyHere = false
	for rank, row in board.Rows do
		local entry = if entries then entries[rank] else nil
		row.Frame.Visible = entry ~= nil
		if entry then
			local here = entry.UserId ~= leavingUserId and Players:GetPlayerByUserId(entry.UserId) ~= nil
			anyHere = anyHere or here
			row.Name.Text = entry.Name
			row.Score.Text = board.Def.FormatScore(entry.Score)
			row.Here.Visible = here
			row.Frame.BackgroundColor3 = if here then HERE_ROW_COLOR else ROW_COLOR
		end
	end
	board.Legend.Visible = anyHere

	local interval = describeInterval(LEADERBOARD.RefreshInterval)
	if not entries then
		if board.Failed then
			board.Status.Text = "LEADERBOARD OFFLINE"
			board.Status.TextColor3 = OFFLINE_COLOR
			board.Detail.Text = if RunService:IsStudio()
				then "Turn on Studio Access to API Services to see the global scores"
				else "Global scores are unavailable right now. Retrying soon..."
		else
			board.Status.Text = "Loading..."
			board.Status.TextColor3 = SUBTEXT
			board.Detail.Text = ""
		end
	elseif #entries == 0 then
		board.Status.Text = "No scores yet"
		board.Status.TextColor3 = SUBTEXT
		board.Detail.Text = "Play to be the first on this board!"
	else
		board.Status.Text = ""
		board.Detail.Text = ""
	end
	board.Status.Visible = board.Status.Text ~= ""
	board.Detail.Visible = board.Detail.Text ~= ""
	board.Footer.Text = if board.Failed and entries
		then `⚠️ Could not refresh, retrying every {interval}`
		else `🔄 Updated every {interval}`
end

local function renderAll(leavingUserId: number?)
	for _, board in boards do
		render(board, leavingUserId)
	end
end

-- Yields. One refresh cycle: submit the scores of this server, then read every board back.
local function refresh()
	openStores()
	if canWrite then
		writeAll()
	end
	for _, board in boards do
		local entries, failed = readTop(board)
		if entries then
			mergeLiveScores(board, entries)
			for _, entry in entries do
				entry.Name = getName(entry.UserId) -- yields the first time (web call), then cached
			end
			board.Entries = entries
			board.Failed = false
		elseif failed then
			board.Failed = true
		end
		render(board)
	end
end

function LeaderboardService.Init(services)
	DataService = services.DataService
	MapService = services.MapService
	for _, def in BOARD_DEFS do
		lastWritten[def.Key] = {}
	end
end

function LeaderboardService.OnPlayerRemoving(player: Player)
	-- Must not yield (the final data save comes right after): snapshot now, write in a thread.
	local userId = player.UserId
	local scores = if canWrite then getScores(player) else nil
	if scores then
		pendingWrites += 1
		task.spawn(function()
			openStores()
			for _, board in boards do
				for attempt = 1, LEAVE_WRITE_ATTEMPTS do
					if writeScore(board, userId, scores[board.Def.Key]) then
						break
					elseif attempt < LEAVE_WRITE_ATTEMPTS then
						task.wait(2)
					end
				end
				lastWritten[board.Def.Key][userId] = nil
			end
			pendingWrites -= 1
		end)
	end
	renderAll(userId)
end

function LeaderboardService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = workspace:FindFirstChild("Map") or workspace

	-- Both boards face the spawn.
	local spawnPoint = if MapService and MapService.SpawnPosition then MapService.SpawnPosition else Vector3.new(-245, 0, 0)
	for _, def in BOARD_DEFS do
		local board = buildBoard(def, folder, spawnPoint)
		table.insert(boards, board)
		render(board)
	end

	-- Green "HERE" tags follow the players joining this server.
	Players.PlayerAdded:Connect(function()
		renderAll()
	end)

	task.spawn(function()
		task.wait(LEADERBOARD.FirstRefreshDelay)
		while true do
			local ok, err = pcall(refresh)
			if not ok then
				warn(`[LeaderboardService] Refresh failed: {err}`)
			end
			-- Boards that never loaded (offline, or an error at start) retry sooner.
			local delay = LEADERBOARD.RefreshInterval
			for _, board in boards do
				if not board.Entries then
					delay = math.min(delay, OFFLINE_RETRY)
				end
			end
			task.wait(delay)
		end
	end)

	-- Let the scores of the last players reach the stores when the server shuts down.
	game:BindToClose(function()
		local deadline = os.clock() + 15
		while pendingWrites > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
end

return LeaderboardService
