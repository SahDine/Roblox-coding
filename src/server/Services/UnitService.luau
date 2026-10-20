--[[
	UnitService
	Critters owned by players: spawning them in the base, income, cash pads,
	selling, storage overflow, offline earnings and the hand-off with
	StealService (carry / return / transfer).

	Also handles evolution: placed critters gain 1 XP per second (2 with the Fast Evolution pass);
	once ready, the owner evolves them for cash (or makes them ready instantly with Robux).

	Saved data (DataService): data.Units[guid] = { Name, Mutation, Slot, Stored, Xp }
	Runtime only:             states[player].Units[guid] = { Model, State, Token, Prompts, ReadyNotified }
	State is "Walking" (going to its pedestal), "Placed" (earning) or "Carried" (being stolen).
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Economy)
local Rarities = require(Shared.Config.Rarities)
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
	ReadyNotified: boolean?,
}

type PlayerState = {
	Units: { [string]: Runtime },
	Multiplier: number,
	Friends: { [Player]: boolean },
}

local GRID_SIZE = 16

local DataService, PlotService, CurrencyService, MonetizationService, StealService

local states: { [Player]: PlayerState } = {}
local pendingEvolve: { [Player]: { Guid: string, Time: number } } = {}
local grantInstantEvolve: (Player) -> boolean

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
	-- Base upgrades boost every critter of the base (UpgradeService refreshes this on upgrade).
	local multiplier = Economy.GetRebirthMultiplier(data.Rebirths) * Economy.GetBaseIncomeMultiplier(data.BaseLevel)
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

local function getXpRate(player: Player): number
	if MonetizationService.OwnsPass(player, "FastEvolve") then
		return GameConfig.Evolution.FastEvolveMultiplier
	end
	return 1
end

-- Publishes when the critter will be able to evolve (server time) for the client timers and prompts.
local function refreshEvolveInfo(player: Player, guid: string)
	local state = states[player]
	local data = DataService.Get(player)
	local runtime = state and state.Units[guid]
	local unit = data and data.Units[guid]
	local model = runtime and runtime.Model
	if not (runtime and unit and model) then
		return
	end
	local need = Economy.GetEvolveTime(unit.Name)
	local evolveAt = nil
	if need then
		local remaining = math.max(0, need - (unit.Xp or 0))
		evolveAt = workspace:GetServerTimeNow() + remaining / getXpRate(player)
	end
	model:SetAttribute("EvolveAt", evolveAt)
	model:SetAttribute("EvolveTarget", Economy.GetEvolutionTarget(unit.Name))
	for _, prompt in runtime.Prompts do
		if prompt.Parent then
			prompt:SetAttribute("EvolveAt", evolveAt)
		end
	end
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
	sell.KeyboardKeyCode = Enum.KeyCode.X
	sell.GamepadKeyCode = Enum.KeyCode.ButtonB
	sell:SetAttribute("Kind", "Sell")
	sell:SetAttribute("OwnerUserId", player.UserId)
	sell.Triggered:Connect(function(who)
		if who == player then
			UnitService.Sell(player, guid)
		end
	end)
	sell.Parent = root
	table.insert(runtime.Prompts, sell)

	local target = Economy.GetEvolutionTarget(unit.Name)
	if target then
		local evolve = Instance.new("ProximityPrompt")
		evolve.Name = "EvolvePrompt"
		evolve.ActionText = "Evolve " .. Format.Money(Economy.GetEvolveCost(unit.Name, unit.Mutation) or 0)
		evolve.ObjectText = `🧬 {unit.Name} → {target}`
		evolve.HoldDuration = 0.5
		evolve.MaxActivationDistance = 10
		evolve.RequiresLineOfSight = false
		evolve.KeyboardKeyCode = Enum.KeyCode.E
		evolve.GamepadKeyCode = Enum.KeyCode.ButtonX
		evolve:SetAttribute("Kind", "Evolve")
		evolve:SetAttribute("OwnerUserId", player.UserId)
		evolve.Triggered:Connect(function(who)
			if who == player then
				UnitService.Evolve(player, guid, false)
			end
		end)
		evolve.Parent = root
		table.insert(runtime.Prompts, evolve)

		if MonetizationService.IsProductConfigured("InstantEvolve") then
			local instant = Instance.new("ProximityPrompt")
			instant.Name = "EvolveRobuxPrompt"
			instant.ActionText = `Ready now R$ {MonetizationService.GetRobuxPrice("InstantEvolve")}`
			instant.ObjectText = `🧬 {unit.Name}`
			instant.HoldDuration = 0
			instant.MaxActivationDistance = 10
			instant.RequiresLineOfSight = false
			instant.KeyboardKeyCode = Enum.KeyCode.F
			instant.GamepadKeyCode = Enum.KeyCode.ButtonY
			instant:SetAttribute("Kind", "EvolveRobux")
			instant:SetAttribute("OwnerUserId", player.UserId)
			instant.Triggered:Connect(function(who)
				if who == player then
					pendingEvolve[player] = { Guid = guid, Time = os.clock() }
					MonetizationService.PromptProduct(player, "InstantEvolve")
				end
			end)
			instant.Parent = root
			table.insert(runtime.Prompts, instant)
		end
	end

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
	UnitModelBuilder.CreateInfoBillboard(model, unit.Name, unit.Mutation, nil, nil, true)
	model.Parent = plot.Model

	runtime.State = "Placed"
	createPrompts(player, guid, runtime, unit)
	refreshEvolveInfo(player, guid)
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

	-- Up the ramp, through the gate, then along the aisles to the front of its collect pedestal.
	local path = PlotService.GetSlotPath(plot, unit.Slot)

	task.spawn(function()
		local result = Walker.Walk(humanoid, path, token, 120)
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

--[[
	True while one of the player's bought critters is walking from the conveyor to its pedestal
	(players bring their critters home one at a time). Also returns that critter's name.
	Critters being loaded or placed are "Walking" for an instant too, but only a real walk has a
	live walk token (placeModel clears it, and the walk always ends: Walker deadline). A walker
	whose model or humanoid vanished can never arrive, so it does not count either.
]]
function UnitService.HasCritterInTransit(player: Player): (boolean, string?)
	local state = states[player]
	local data = DataService.Get(player)
	if not state then
		return false, nil
	end
	for guid, runtime in state.Units do
		local token = runtime.Token
		local model = runtime.Model
		if
			runtime.State == "Walking"
			and token
			and not token.Cancelled
			and model
			and model.Parent
			and model:FindFirstChildOfClass("Humanoid")
		then
			local unit = data and data.Units[guid]
			return true, unit and unit.Name
		end
	end
	return false, nil
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
	options.Xp: evolution progress to keep (stolen critters keep their XP).
	Returns the new guid, or nil when the base was full (the critter goes to storage).
]]
function UnitService.GrantUnit(
	player: Player,
	unitName: string,
	mutation: string?,
	options: { Model: Model?, Walk: boolean?, Xp: number? }?
): string?
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
		table.insert(data.Storage, { Name = unitName, Mutation = resolvedMutation, Xp = opts.Xp })
		if opts.Model then
			opts.Model:Destroy()
		end
		Notifier.Send(player, `📦 Base full! {unitName} waits in storage until a slot is free.`, "alert")
		refreshAttributes(player)
		return nil
	end

	local guid = HttpService:GenerateGUID(false)
	data.Units[guid] = { Name = unitName, Mutation = resolvedMutation, Slot = slotIndex, Stored = 0, Xp = opts.Xp or 0 }
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
			UnitService.GrantUnit(player, entry.Name, entry.Mutation, { Xp = tonumber(entry.Xp) })
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

-- Evolution ---------------------------------------------------------------------

local function playEvolveEffect(position: Vector3, color: Color3)
	local burst = Instance.new("Part")
	burst.Name = "EvolveBurst"
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.CanTouch = false
	burst.Transparency = 1
	burst.Size = Vector3.new(1, 1, 1)
	burst.CFrame = CFrame.new(position)
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	sparkles.LightEmission = 1
	sparkles.Rate = 150
	sparkles.Lifetime = NumberRange.new(0.6, 1.2)
	sparkles.Speed = NumberRange.new(6, 12)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new(0.6, 0)
	sparkles.Parent = burst
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 20
	light.Brightness = 4
	light.Parent = burst
	burst.Parent = workspace
	task.delay(0.4, function()
		sparkles.Enabled = false
	end)
	task.delay(1.6, burst.Destroy, burst)
end

-- Evolves a placed critter. `free` skips the XP and cash requirements (admin tools / events).
function UnitService.Evolve(player: Player, guid: string, free: boolean?): boolean
	local data = DataService.Get(player)
	local state = states[player]
	local plot = PlotService.GetPlot(player)
	local unit = data and data.Units[guid]
	local runtime = state and state.Units[guid]
	if not (unit and runtime and plot and runtime.State == "Placed") then
		return false
	end
	local target = Economy.GetEvolutionTarget(unit.Name)
	local need = Economy.GetEvolveTime(unit.Name)
	if not target or not need then
		return false
	end
	if not free then
		if unit.Xp < need then
			local remaining = (need - unit.Xp) / getXpRate(player)
			Notifier.Send(player, `🧬 {unit.Name} needs {Format.Time(remaining)} more before evolving`, "error")
			return false
		end
		local cost = Economy.GetEvolveCost(unit.Name, unit.Mutation) or 0
		if not CurrencyService.TrySpend(player, cost) then
			Notifier.Send(player, `Not enough cash! Evolving costs {Format.Money(cost)}`, "error")
			return false
		end
	end

	local previous = unit.Name
	unit.Name = target
	unit.Xp = 0
	runtime.ReadyNotified = false
	clearPrompts(runtime)
	if runtime.Model then
		runtime.Model:Destroy()
		runtime.Model = nil
	end
	placeModel(player, guid)

	local targetDef = Units.ByName[target]
	local slot = plot.Slots[unit.Slot]
	if slot and targetDef then
		playEvolveEffect(slot.StandPosition + Vector3.new(0, 3, 0), Rarities.Info[targetDef.Rarity].Color)
	end
	Notifier.Send(player, `🧬 Your {previous} evolved into {target}!`, "success")
	if targetDef and Rarities.IsAtLeast(targetDef.Rarity, GameConfig.Evolution.AnnounceFromRarity) then
		Notifier.All(`🧬 {player.DisplayName}'s {previous} evolved into a {targetDef.Rarity} {target}!`, "announce")
	end
	refreshAttributes(player)
	task.spawn(DataService.SaveAsync, player)
	return true
end

-- Robux "Instant Evolution": the critter the player clicked becomes ready to evolve.
-- Must not yield (called from ProcessReceipt).
grantInstantEvolve = function(player: Player): boolean
	local data = DataService.Get(player)
	local state = states[player]
	if not (data and state) then
		return false
	end

	local pending = pendingEvolve[player]
	pendingEvolve[player] = nil
	local chosen: string? = nil
	if pending and os.clock() - pending.Time < 300 then
		local unit = data.Units[pending.Guid]
		local need = unit and Economy.GetEvolveTime(unit.Name)
		if need and unit.Xp < need then
			chosen = pending.Guid
		end
	end
	if not chosen then
		-- The clicked critter is gone (sold / stolen): help the critter that needs the most time.
		local best = 0
		for guid, unit in data.Units do
			local need = Economy.GetEvolveTime(unit.Name)
			if need and need - unit.Xp > best then
				best = need - unit.Xp
				chosen = guid
			end
		end
	end
	if not chosen then
		Notifier.Send(player, "No critter can evolve right now, your purchase will be retried later.", "error")
		return false
	end

	local unit = data.Units[chosen]
	unit.Xp = Economy.GetEvolveTime(unit.Name) or unit.Xp
	refreshEvolveInfo(player, chosen)
	Notifier.Send(player, `🧬 {unit.Name} is ready to evolve! Press E on it.`, "success")
	return true
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

	UnitService.GrantUnit(thief, unit.Name, unit.Mutation, { Model = model, Xp = unit.Xp })
	return true
end

-- Lifecycle -------------------------------------------------------------------

local function sanitize(player: Player, data)
	local maxSlots = UnitService.GetMaxSlots(player)
	local used = {}
	local needSlot = {}

	for _, entry in data.Storage do
		if type(entry) == "table" and type(entry.Name) == "string" then
			entry.Name = Units.Resolve(entry.Name)
		end
	end

	for guid, unit in data.Units do
		if type(unit) == "table" and type(unit.Name) == "string" then
			unit.Name = Units.Resolve(unit.Name)
		end
		if type(unit) ~= "table" or not Units.ByName[unit.Name] then
			data.Units[guid] = nil
		else
			unit.Mutation = if Mutations.Info[unit.Mutation] then unit.Mutation else "None"
			unit.Stored = if type(unit.Stored) == "number" and unit.Stored == unit.Stored then unit.Stored else 0
			unit.Xp = if type(unit.Xp) == "number" and unit.Xp == unit.Xp then math.max(0, unit.Xp) else 0
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
			table.insert(data.Storage, { Name = unit.Name, Mutation = unit.Mutation, Xp = unit.Xp })
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
			task.delay(
				3,
				Notifier.Send,
				player,
				`💤 Welcome back! Your critters earned {Format.Money(amount)} while you were away`,
				"success"
			)
		end
	end

	task.spawn(linkFriends, player)
end

function UnitService.OnPlayerRemoving(player: Player)
	pendingEvolve[player] = nil
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
		elseif passKey == "FastEvolve" then
			local state = states[player]
			if state then
				for guid in state.Units do
					refreshEvolveInfo(player, guid)
				end
			end
		end
	end)

	MonetizationService.RegisterKindHandler("EvolveReady", function(player)
		return grantInstantEvolve(player)
	end)

	-- Income tick.
	task.spawn(function()
		while true do
			local dt = task.wait(1)
			for player, state in states do
				local data = DataService.Get(player)
				local plot = PlotService.GetPlot(player)
				if data and plot then
					local autoCollect = MonetizationService.OwnsPass(player, "AutoCollect")
					local xpRate = getXpRate(player)
					local earned = 0
					for guid, unit in data.Units do
						local runtime = state.Units[guid]
						if runtime and runtime.State == "Placed" then
							local need = Economy.GetEvolveTime(unit.Name)
							unit.Xp = unit.Xp or 0
							if need and unit.Xp < need then
								unit.Xp = math.min(need, unit.Xp + xpRate * dt)
								if unit.Xp >= need and not runtime.ReadyNotified then
									runtime.ReadyNotified = true
									refreshEvolveInfo(player, guid) -- the client timer may have drifted
									Notifier.Send(player, `🧬 Your {unit.Name} is ready to evolve!`, "info")
								end
							end
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
