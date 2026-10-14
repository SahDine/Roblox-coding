--[[
	UnitService
	Critters owned by players: spawning them in the base, income, cash pads,
	selling, storage overflow, offline earnings and the hand-off with
	StealService (carry / return / transfer).

	Saved data (DataService): data.Units[guid] = { Name, Mutation, Slot, Stored }
	Runtime only:             states[player].Units[guid] = { Model, State, Token, Prompts }
	State is "Walking" (going to its pedestal), "Placed" (earning) or "Carried" (being stolen).
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Mutations = require(Shared.Config.Mutations)
local Units = require(Shared.Config.Units)

local Modules = script.Parent.Parent.Modules
local Notifier = require(Modules.Notifier)
local UnitModelBuilder = require(Modules.UnitModelBuilder)
local Walker = require(Modules.Walker)

local UnitService = {}

type Runtime = {
	Guid: string,
	Model: Model?,
	State: string,
	Token: Walker.Token?,
	Prompts: { ProximityPrompt },
}

type PlayerState = {
	Units: { [string]: Runtime },
	Multiplier: number,
	Friends: { [Player]: boolean },
}

local GRID_SIZE = 16

local DataService, PlotService, CurrencyService, MonetizationService, StealService

local states: { [Player]: PlayerState } = {}

-- Helpers ---------------------------------------------------------------------

local function friendCount(state: PlayerState): number
	local count = 0
	for other in state.Friends do
		if other.Parent then
			count += 1
		end
	end
	return count
end

local function computeMultiplier(player: Player, data): number
	local economy = GameConfig.Economy
	local multiplier = Economy.GetRebirthMultiplier(data.Rebirths)
	if MonetizationService.OwnsPass(player, "VIP") then
		multiplier *= economy.VipMultiplier
	end

	local bonus = 0
	if player.MembershipType == Enum.MembershipType.Premium then
		bonus += economy.PremiumBonus
	end
	local state = states[player]
	if state then
		bonus += math.min(friendCount(state) * economy.FriendBonusPerFriend, economy.FriendBonusMax)
	end
	return multiplier * (1 + bonus)
end

local function clearPrompts(runtime: Runtime)
	for _, prompt in runtime.Prompts do
		prompt:Destroy()
	end
	table.clear(runtime.Prompts)
end

local function refreshAttributes(player: Player)
	local data = DataService.Get(player)
	local state = states[player]
	if not data or not state then
		return
	end
	local used = 0
	for _ in data.Units do
		used += 1
	end
	player:SetAttribute("Income", UnitService.GetIncomePerSecond(player))
	player:SetAttribute("Multiplier", state.Multiplier)
	player:SetAttribute("MaxSlots", UnitService.GetMaxSlots(player))
	player:SetAttribute("UsedSlots", used)
	player:SetAttribute("StorageCount", #data.Storage)
end

local function createPrompts(player: Player, guid: string, runtime: Runtime, unit)
	local model = runtime.Model
	local root = model and model.PrimaryPart
	if not root then
		return
	end

	local sell = Instance.new("ProximityPrompt")
	sell.Name = "SellPrompt"
	sell.ActionText = "Sell " .. Format.Money(Economy.GetSellValue(unit.Name, unit.Mutation))
	sell.ObjectText = unit.Name
	sell.HoldDuration = 1
	sell.MaxActivationDistance = 10
	sell.RequiresLineOfSight = false
	sell:SetAttribute("Kind", "Sell")
	sell:SetAttribute("OwnerUserId", player.UserId)
	sell.Triggered:Connect(function(who)
		if who == player then
			UnitService.Sell(player, guid)
		end
	end)
	sell.Parent = root
	table.insert(runtime.Prompts, sell)

	if GameConfig.Steal.Enabled then
		local steal = Instance.new("ProximityPrompt")
		steal.Name = "StealPrompt"
		steal.ActionText = "Steal"
		steal.ObjectText = unit.Name
		steal.HoldDuration = GameConfig.Steal.HoldDuration
		steal.MaxActivationDistance = 10
		steal.RequiresLineOfSight = false
		steal:SetAttribute("Kind", "Steal")
		steal:SetAttribute("OwnerUserId", player.UserId)
		StealService.BindPrompt(steal, player, guid)
		steal.Parent = root
		table.insert(runtime.Prompts, steal)
	end
end

-- Puts the critter on its pedestal (building the model if needed).
local function placeModel(player: Player, guid: string)
	local data = DataService.Get(player)
	local state = states[player]
	local plot = PlotService.GetPlot(player)
	local unit = data and data.Units[guid]
	local runtime = state and state.Units[guid]
	if not (unit and runtime and plot) then
		return
	end
	local slot = plot.Slots[unit.Slot]
	if not slot then
		return
	end

	local model = runtime.Model
	if not model then
		model = UnitModelBuilder.Build(unit.Name, unit.Mutation)
		if not model then
			return
		end
		runtime.Model = model
	end
	assert(model, "unreachable")

	if runtime.Token then
		runtime.Token.Cancelled = true
		runtime.Token = nil
	end
	clearPrompts(runtime)

	UnitModelBuilder.SetCarried(model, false)
	UnitModelBuilder.SetAnchored(model, true)
	model:PivotTo(UnitModelBuilder.GetStandingCFrame(model, slot.StandPosition, plot.CFrame.LookVector))
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Guid", guid)
	UnitModelBuilder.CreateInfoBillboard(model, unit.Name, unit.Mutation)
	model.Parent = plot.Model

	runtime.State = "Placed"
	createPrompts(player, guid, runtime, unit)
	PlotService.SetPadAmount(plot, unit.Slot, unit.Stored)
end

-- A bought critter walks from the conveyor to its pedestal.
local function walkToSlot(player: Player, guid: string, runtime: Runtime, model: Model)
	local data = DataService.Get(player)
	local plot = PlotService.GetPlot(player)
	local unit = data and data.Units[guid]
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not (unit and plot and humanoid) then
		placeModel(player, guid)
		return
	end

	runtime.State = "Walking"
	local token = Walker.NewToken()
	runtime.Token = token
	clearPrompts(runtime)

	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Guid", guid)
	UnitModelBuilder.CreateInfoBillboard(model, unit.Name, unit.Mutation)
	model.Parent = plot.Model
	UnitModelBuilder.SetCarried(model, false)
	UnitModelBuilder.SetAnchored(model, false)
	humanoid.WalkSpeed = GameConfig.Conveyor.DeliverySpeed

	local path = PlotService.GetEntrancePath(plot)
	table.insert(path, plot.Slots[unit.Slot].GroundPosition)

	task.spawn(function()
		local result = Walker.Walk(humanoid, path, token, 40)
		if result == "Cancelled" then
			return
		end
		local state = states[player]
		if state and state.Units[guid] == runtime and runtime.State == "Walking" then
			placeModel(player, guid)
		end
	end)
end

local function removeUnit(player: Player, guid: string)
	local data = DataService.Get(player)
	local state = states[player]
	local plot = PlotService.GetPlot(player)
	local unit = data and data.Units[guid]
	if data then
		data.Units[guid] = nil
	end
	local runtime = state and state.Units[guid]
	if runtime then
		if runtime.Token then
			runtime.Token.Cancelled = true
		end
		clearPrompts(runtime)
		if runtime.Model then
			runtime.Model:Destroy()
		end
		state.Units[guid] = nil
	end
	if plot and unit then
		PlotService.SetPadAmount(plot, unit.Slot, 0)
	end
end

-- Public API ------------------------------------------------------------------

function UnitService.GetMaxSlots(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	return math.min(Economy.GetMaxSlots(data.Rebirths, MonetizationService.OwnsPass(player, "ExtraSlots")), GRID_SIZE)
end

function UnitService.FindFreeSlot(player: Player): number?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local used = {}
	for _, unit in data.Units do
		used[unit.Slot] = true
	end
	for index = 1, UnitService.GetMaxSlots(player) do
		if not used[index] then
			return index
		end
	end
	return nil
end

function UnitService.HasFreeSlot(player: Player): boolean
	return UnitService.FindFreeSlot(player) ~= nil
end

-- Income per second of every owned critter, multipliers included.
function UnitService.GetIncomePerSecond(player: Player): number
	local data = DataService.Get(player)
	local state = states[player]
	if not data or not state then
		return 0
	end
	local total = 0
	for _, unit in data.Units do
		total += Economy.GetUnitIncome(unit.Name, unit.Mutation)
	end
	return total * state.Multiplier
end

function UnitService.GetUnit(player: Player, guid: string)
	local data = DataService.Get(player)
	return data and data.Units[guid]
end

function UnitService.GetState(player: Player, guid: string): string?
	local state = states[player]
	local runtime = state and state.Units[guid]
	return runtime and runtime.State
end

function UnitService.RefreshMultiplier(player: Player)
	local data = DataService.Get(player)
	local state = states[player]
	if data and state then
		state.Multiplier = computeMultiplier(player, data)
		refreshAttributes(player)
	end
end

--[[
	Gives a critter to a player.
	options.Model: reuse an existing model (conveyor critter, stolen critter).
	options.Walk: the model walks to its pedestal instead of appearing on it.
	Returns the new guid, or nil when the base was full (the critter goes to storage).
]]
function UnitService.GrantUnit(player: Player, unitName: string, mutation: string?, options: { Model: Model?, Walk: boolean?, Silent: boolean? }?): string?
	local opts = options or {}
	local data = DataService.Get(player)
	local state = states[player]
	local resolvedMutation = if mutation and Mutations.Info[mutation] then mutation else "None"

	if not data or not state or not Units.ByName[unitName] then
		if opts.Model then
			opts.Model:Destroy()
		end
		return nil
	end

	local slotIndex = UnitService.FindFreeSlot(player)
	if not slotIndex then
		table.insert(data.Storage, { Name = unitName, Mutation = resolvedMutation })
		if opts.Model then
			opts.Model:Destroy()
		end
		Notifier.Send(player, `📦 Base full! {unitName} waits in storage until a slot is free.`, "alert")
		refreshAttributes(player)
		return nil
	end

	local guid = HttpService:GenerateGUID(false)
	data.Units[guid] = { Name = unitName, Mutation = resolvedMutation, Slot = slotIndex, Stored = 0 }
	local runtime: Runtime = { Guid = guid, Model = opts.Model, State = "Walking", Prompts = {} }
	state.Units[guid] = runtime

	if opts.Model and opts.Walk then
		walkToSlot(player, guid, runtime, opts.Model)
	else
		placeModel(player, guid)
	end
	refreshAttributes(player)
	return guid
end

-- Moves critters waiting in storage onto free pedestals.
function UnitService.PlaceFromStorage(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	while #data.Storage > 0 and UnitService.HasFreeSlot(player) do
		local entry = table.remove(data.Storage, 1)
		if entry and Units.ByName[entry.Name] then
			UnitService.GrantUnit(player, entry.Name, entry.Mutation)
		end
	end
	refreshAttributes(player)
end

function UnitService.RefreshSlots(player: Player)
	local plot = PlotService.GetPlot(player)
	if plot then
		PlotService.SetUnlockedSlots(plot, UnitService.GetMaxSlots(player))
	end
	UnitService.PlaceFromStorage(player)
	refreshAttributes(player)
end

function UnitService.Sell(player: Player, guid: string)
	local unit = UnitService.GetUnit(player, guid)
	if not unit or UnitService.GetState(player, guid) ~= "Placed" then
		return
	end
	local value = Economy.GetSellValue(unit.Name, unit.Mutation) + math.floor(unit.Stored or 0)
	removeUnit(player, guid)
	CurrencyService.Add(player, value)
	Notifier.Send(player, `Sold {unit.Name} for {Format.Money(value)}`, "success")
	UnitService.PlaceFromStorage(player)
	refreshAttributes(player)
end

function UnitService.Collect(player: Player, slotIndex: number)
	local data = DataService.Get(player)
	local state = states[player]
	local plot = PlotService.GetPlot(player)
	if not (data and state and plot) then
		return
	end
	for guid, unit in data.Units do
		if unit.Slot == slotIndex then
			local runtime = state.Units[guid]
			if runtime and runtime.State == "Placed" and unit.Stored >= 1 then
				local amount = math.floor(unit.Stored)
				unit.Stored -= amount
				CurrencyService.Add(player, amount)
				PlotService.SetPadAmount(plot, slotIndex, unit.Stored)
			end
			return
		end
	end
end

function UnitService.CollectAll(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	for _, unit in data.Units do
		UnitService.Collect(player, unit.Slot)
	end
end

-- Stealing hand-off -------------------------------------------------------------

-- Detaches a placed critter so a thief can carry it. Returns its model.
function UnitService.BeginCarry(owner: Player, guid: string): Model?
	local data = DataService.Get(owner)
	local state = states[owner]
	local plot = PlotService.GetPlot(owner)
	local unit = data and data.Units[guid]
	local runtime = state and state.Units[guid]
	if not (unit and runtime and plot and runtime.State == "Placed" and runtime.Model) then
		return nil
	end

	-- The owner keeps the cash this critter already produced.
	if unit.Stored >= 1 then
		CurrencyService.Add(owner, math.floor(unit.Stored))
	end
	unit.Stored = 0
	PlotService.SetPadAmount(plot, unit.Slot, 0)

	runtime.State = "Carried"
	clearPrompts(runtime)
	UnitModelBuilder.SetCarried(runtime.Model, true)
	return runtime.Model
end

-- Steal failed: the critter goes back on its pedestal.
function UnitService.ReturnUnit(owner: Player, guid: string): boolean
	local state = states[owner]
	local runtime = state and state.Units[guid]
	if not runtime or runtime.State ~= "Carried" then
		return false
	end
	placeModel(owner, guid)
	return true
end

-- Steal succeeded: the critter changes owner.
function UnitService.TransferUnit(owner: Player, guid: string, thief: Player): boolean
	local ownerData = DataService.Get(owner)
	local ownerState = states[owner]
	local unit = ownerData and ownerData.Units[guid]
	local runtime = ownerState and ownerState.Units[guid]
	if not (unit and runtime and runtime.State == "Carried") then
		return false
	end

	local model = runtime.Model
	ownerData.Units[guid] = nil
	ownerState.Units[guid] = nil
	ownerData.Stats.TimesRobbed += 1
	local ownerPlot = PlotService.GetPlot(owner)
	if ownerPlot then
		PlotService.SetPadAmount(ownerPlot, unit.Slot, 0)
	end
	UnitService.PlaceFromStorage(owner)
	refreshAttributes(owner)

	UnitService.GrantUnit(thief, unit.Name, unit.Mutation, { Model = model })
	return true
end

-- Lifecycle -------------------------------------------------------------------

local function sanitize(player: Player, data)
	local maxSlots = UnitService.GetMaxSlots(player)
	local used = {}
	local needSlot = {}

	for guid, unit in data.Units do
		if type(unit) ~= "table" or not Units.ByName[unit.Name] then
			data.Units[guid] = nil
		else
			unit.Mutation = if Mutations.Info[unit.Mutation] then unit.Mutation else "None"
			unit.Stored = if type(unit.Stored) == "number" and unit.Stored == unit.Stored then unit.Stored else 0
			if type(unit.Slot) ~= "number" or unit.Slot < 1 or unit.Slot > maxSlots or used[unit.Slot] then
				table.insert(needSlot, guid)
			else
				used[unit.Slot] = true
			end
		end
	end

	for _, guid in needSlot do
		local unit = data.Units[guid]
		local freeSlot
		for index = 1, maxSlots do
			if not used[index] then
				freeSlot = index
				break
			end
		end
		if freeSlot then
			unit.Slot = freeSlot
			used[freeSlot] = true
		else
			data.Units[guid] = nil
			table.insert(data.Storage, { Name = unit.Name, Mutation = unit.Mutation })
		end
	end
end

local function linkFriends(player: Player)
	for _, other in Players:GetPlayers() do
		local otherState = states[other]
		if other ~= player and otherState then
			local ok, areFriends = pcall(player.IsFriendsWithAsync, player, other.UserId)
			local state = states[player]
			if ok and areFriends and state and states[other] then
				state.Friends[other] = true
				otherState.Friends[player] = true
				UnitService.RefreshMultiplier(other)
				Notifier.Send(other, `👋 Your friend {player.DisplayName} joined! Friend bonus increased`, "success")
			end
		end
	end
	UnitService.RefreshMultiplier(player)
end

function UnitService.OnPlayerLoaded(player: Player, data)
	local state: PlayerState = { Units = {}, Multiplier = 1, Friends = {} }
	states[player] = state
	state.Multiplier = computeMultiplier(player, data)

	sanitize(player, data)

	local plot = PlotService.GetPlot(player)
	if plot then
		PlotService.SetUnlockedSlots(plot, UnitService.GetMaxSlots(player))
	end

	for guid in data.Units do
		state.Units[guid] = { Guid = guid, Model = nil, State = "Walking", Prompts = {} }
		placeModel(player, guid)
	end
	UnitService.PlaceFromStorage(player)
	refreshAttributes(player)

	-- Offline earnings.
	local economy = GameConfig.Economy
	local offlineSeconds = math.clamp(os.time() - (data.LastOnline or 0), 0, economy.OfflineMaxSeconds)
	if data.LastOnline and data.LastOnline > 0 and offlineSeconds >= 60 then
		local amount = math.floor(UnitService.GetIncomePerSecond(player) * offlineSeconds * economy.OfflineRate)
		if amount >= 1 then
			CurrencyService.Add(player, amount)
			task.delay(3, Notifier.Send, player, `💤 Welcome back! Your critters earned {Format.Money(amount)} while you were away`, "success")
		end
	end

	task.spawn(linkFriends, player)
end

function UnitService.OnPlayerRemoving(player: Player)
	local state = states[player]
	if not state then
		return
	end
	for _, runtime in state.Units do
		if runtime.Token then
			runtime.Token.Cancelled = true
		end
		if runtime.Model then
			runtime.Model:Destroy()
		end
	end
	states[player] = nil

	for other in state.Friends do
		local otherState = states[other]
		if otherState then
			otherState.Friends[player] = nil
			UnitService.RefreshMultiplier(other)
		end
	end
end

function UnitService.Init(services)
	DataService = services.DataService
	PlotService = services.PlotService
	CurrencyService = services.CurrencyService
	MonetizationService = services.MonetizationService
	StealService = services.StealService
end

function UnitService.Start()
	PlotService.PadTouched:Connect(function(player, _plot, slotIndex)
		UnitService.Collect(player, slotIndex)
	end)

	MonetizationService.PassGranted:Connect(function(player, passKey)
		if passKey == "VIP" then
			UnitService.RefreshMultiplier(player)
		elseif passKey == "ExtraSlots" then
			UnitService.RefreshSlots(player)
		elseif passKey == "AutoCollect" then
			UnitService.CollectAll(player)
		end
	end)

	-- Income tick.
	task.spawn(function()
		while true do
			task.wait(1)
			for player, state in states do
				local data = DataService.Get(player)
				local plot = PlotService.GetPlot(player)
				if data and plot then
					local autoCollect = MonetizationService.OwnsPass(player, "AutoCollect")
					local earned = 0
					for guid, unit in data.Units do
						local runtime = state.Units[guid]
						if runtime and runtime.State == "Placed" then
							local income = Economy.GetUnitIncome(unit.Name, unit.Mutation) * state.Multiplier
							if autoCollect then
								earned += income
							else
								unit.Stored += income
								PlotService.SetPadAmount(plot, unit.Slot, unit.Stored)
							end
						end
					end
					if earned > 0 then
						CurrencyService.Add(player, earned)
					end
				end
			end
		end
	end)
end

return UnitService
