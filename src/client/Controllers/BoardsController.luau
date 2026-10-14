--[[
	BoardsController
	Live text of the public boards of the world, updated client-side (no network traffic):
	- "RARE CRITTERS" board (built by ConveyorService, tag "RareSpawnBoard"): countdown to the next
	  Legendary / Mythic / Secret spawn, progress bars and the Server Luck line.
	  Spawn times are the attributes of ReplicatedStorage.RareSpawns (server time):
	  <Rarity> = next spawn, <Rarity>Last = last spawn.
	Updated twice per second, which also makes "SPAWNING!" blink.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)

local BoardsController = {}

local RARE = GameConfig.RareSpawns
local BOARD_TAG = "RareSpawnBoard"
local UPDATE_INTERVAL = 0.5
local SPAWNING_HOLD = 5 -- seconds "SPAWNING!" stays on after a spawn
local URGENT = 60 -- the last minute is shown in the rarity colour

local WHITE = Color3.new(1, 1, 1)
local LUCK_ON = Color3.fromRGB(120, 255, 120)

type Row = { Rarity: string, Countdown: TextLabel, Progress: GuiObject? }
type Board = { Rows: { Row }, Luck: TextLabel?, LuckText: string, LuckColor: Color3 }

local boards: { [Instance]: Board } = {}

local expectedRows = 0
for _, rarity in RARE.Order do
	if RARE.Timers[rarity] then
		expectedRows += 1
	end
end

-- Finds the labels the server marked (rows can replicate a moment after the board itself).
local function scan(board: Instance): Board
	local result: Board = { Rows = {}, Luck = nil, LuckText = "", LuckColor = WHITE }
	for _, descendant in board:GetDescendants() do
		if descendant:IsA("TextLabel") then
			local rarity = descendant:GetAttribute("RareCountdown")
			if type(rarity) == "string" and RARE.Timers[rarity] then
				local row = descendant.Parent
				local progress = row and row:FindFirstChild("Progress", true)
				table.insert(result.Rows, {
					Rarity = rarity,
					Countdown = descendant,
					Progress = if progress and progress:IsA("GuiObject") then progress else nil,
				})
			elseif descendant.Name == "LuckLine" then
				result.Luck = descendant
				result.LuckText = descendant.Text
				result.LuckColor = descendant.TextColor3
			end
		end
	end
	return result
end

local function setText(label: TextLabel, text: string, color: Color3)
	if label.Text ~= text then
		label.Text = text
	end
	if label.TextColor3 ~= color then
		label.TextColor3 = color
	end
end

local function updateRow(row: Row, folder: Instance?, now: number, blink: boolean)
	local info = Rarities.Info[row.Rarity]
	local color = if info then info.Color else WHITE
	local spawnAt = folder and folder:GetAttribute(row.Rarity)
	local lastAt = folder and folder:GetAttribute(row.Rarity .. "Last")
	local fraction = 0

	if type(spawnAt) ~= "number" then
		setText(row.Countdown, "--:--", WHITE)
	else
		local remaining = spawnAt - now
		local justSpawned = type(lastAt) == "number" and now - lastAt < SPAWNING_HOLD
		if remaining <= 0 or justSpawned then
			setText(row.Countdown, "SPAWNING!", if blink then color else WHITE)
			fraction = 1
		else
			setText(row.Countdown, Format.Time(math.ceil(remaining)), if remaining <= URGENT then color else WHITE)
			fraction = 1 - remaining / RARE.Timers[row.Rarity].Interval
		end
	end

	local progress = row.Progress
	if progress then
		local size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		if progress.Size ~= size then
			progress.Size = size
		end
	end
end

local function updateLuck(board: Board, now: number)
	local label = board.Luck
	if not label then
		return
	end
	local endsAt = ReplicatedStorage:GetAttribute("ServerLuckEndsAt")
	local multiplier = ReplicatedStorage:GetAttribute("ServerLuckMultiplier")
	local left = if type(endsAt) == "number" then endsAt - now else 0
	if left > 0 and type(multiplier) == "number" and multiplier > 1 then
		setText(label, `🍀 {multiplier}x SERVER LUCK: timers {multiplier}x faster! {Format.Time(left)}`, LUCK_ON)
	else
		setText(label, board.LuckText, board.LuckColor)
	end
end

local function update(blink: boolean)
	local folder = ReplicatedStorage:FindFirstChild("RareSpawns")
	local now = workspace:GetServerTimeNow()
	for instance, board in boards do
		if not instance.Parent then
			boards[instance] = nil
			continue
		end
		if #board.Rows < expectedRows then
			board = scan(instance)
			boards[instance] = board
		end
		for _, row in board.Rows do
			updateRow(row, folder, now, blink)
		end
		updateLuck(board, now)
	end
end

function BoardsController.Start()
	for _, instance in CollectionService:GetTagged(BOARD_TAG) do
		boards[instance] = scan(instance)
	end
	CollectionService:GetInstanceAddedSignal(BOARD_TAG):Connect(function(instance)
		boards[instance] = scan(instance)
	end)
	CollectionService:GetInstanceRemovedSignal(BOARD_TAG):Connect(function(instance)
		boards[instance] = nil
	end)

	task.spawn(function()
		local blink = false
		while true do
			blink = not blink
			local ok, err = pcall(update, blink)
			if not ok then
				warn("[BoardsController] " .. tostring(err))
			end
			task.wait(UPDATE_INTERVAL)
		end
	end)
end

return BoardsController
