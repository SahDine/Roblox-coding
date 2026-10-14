--[[
	StealService
	The core "steal & defend" loop:
	  1. hold the Steal prompt on a critter in an unlocked base;
	  2. the critter is carried above your head, you walk slower;
	  3. reach your own base -> the critter is yours;
	     get slapped / die / time out -> it goes back to its owner.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Units = require(Shared.Config.Units)

local Notifier = require(script.Parent.Parent.Modules.Notifier)

local StealService = {}

type Carry = {
	Owner: Player,
	Guid: string,
	Model: Model,
	Weld: WeldConstraint,
	StartedAt: number,
	UnitName: string,
	Label: string,
}

local STEAL = GameConfig.Steal

local DataService, UnitService, PlotService, CurrencyService, MonetizationService

local carries: { [Player]: Carry } = {}
local holdStarts: { [Player]: number } = {}
local lastSteal: { [Player]: number } = {}

local function getCharacterParts(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return root, humanoid
end

local function getHoldDuration(player: Player): number
	if MonetizationService.OwnsPass(player, "FastSteal") then
		return STEAL.FastStealHoldDuration
	end
	return STEAL.HoldDuration
end

local function getCarrySpeed(player: Player): number
	if MonetizationService.OwnsPass(player, "FastSteal") then
		return STEAL.FastStealCarryWalkSpeed
	end
	return STEAL.CarryWalkSpeed
end

local function unitLabel(unitName: string, mutation: string?): string
	if mutation and mutation ~= "None" then
		return `{mutation} {unitName}`
	end
	return unitName
end

local function endCarry(thief: Player, carry: Carry)
	if carries[thief] == carry then
		carries[thief] = nil
	end
	carry.Weld:Destroy()
	thief:SetAttribute("Carrying", nil)
	local _, humanoid = getCharacterParts(thief)
	if humanoid then
		humanoid.WalkSpeed = GameConfig.Player.WalkSpeed
	end
end

local function failCarry(thief: Player, reason: string)
	local carry = carries[thief]
	if not carry then
		return
	end
	endCarry(thief, carry)

	local owner = carry.Owner
	if owner.Parent and UnitService.ReturnUnit(owner, carry.Guid) then
		Notifier.Send(owner, `✅ Your {carry.Label} is back home!`, "success")
	elseif carry.Model.Parent then
		carry.Model:Destroy()
	end

	if reason == "slapped" then
		Notifier.Send(thief, `💥 You got slapped and dropped {carry.Label}!`, "error")
	elseif reason == "timeout" then
		Notifier.Send(thief, `⏰ Too slow! {carry.Label} ran back home`, "error")
	elseif reason == "died" then
		Notifier.Send(thief, `You dropped {carry.Label}`, "error")
	end
end

local function succeedCarry(thief: Player)
	local carry = carries[thief]
	if not carry then
		return
	end
	endCarry(thief, carry)

	local owner = carry.Owner
	if not owner.Parent or not UnitService.TransferUnit(owner, carry.Guid, thief) then
		if not (owner.Parent and UnitService.ReturnUnit(owner, carry.Guid)) and carry.Model.Parent then
			carry.Model:Destroy()
		end
		return
	end

	local thiefData = DataService.Get(thief)
	if thiefData then
		thiefData.Stats.Steals += 1
		CurrencyService.Refresh(thief)
	end

	Notifier.Send(thief, `🎉 You stole {carry.Label}!`, "success")
	Notifier.Send(owner, `😱 {thief.DisplayName} stole your {carry.Label}!`, "alert")

	local def = Units.ByName[carry.UnitName]
	if def and Rarities.IsAtLeast(def.Rarity, STEAL.AnnounceFromRarity) then
		Notifier.All(`🦹 {thief.DisplayName} stole a {def.Rarity} {carry.Label} from {owner.DisplayName}!`, "announce")
	end

	-- Persist both sides right away to keep the trade consistent.
	task.spawn(DataService.SaveAsync, thief)
	task.spawn(DataService.SaveAsync, owner)
end

-- Public API ------------------------------------------------------------------

function StealService.IsCarrying(player: Player): boolean
	return carries[player] ~= nil
end

function StealService.BindPrompt(prompt: ProximityPrompt, owner: Player, guid: string)
	prompt.PromptButtonHoldBegan:Connect(function(player)
		holdStarts[player] = os.clock()
	end)
	prompt.Triggered:Connect(function(player)
		StealService.TryStartSteal(player, owner, guid, prompt)
	end)
end

function StealService.TryStartSteal(thief: Player, owner: Player, guid: string, prompt: ProximityPrompt)
	if not STEAL.Enabled or thief == owner or not thief:GetAttribute("DataLoaded") then
		return
	end

	-- Anti-exploit: the prompt must really have been held.
	local holdStart = holdStarts[thief]
	holdStarts[thief] = nil
	if not holdStart or os.clock() - holdStart < getHoldDuration(thief) * 0.7 then
		return
	end

	if carries[thief] then
		Notifier.Send(thief, "You are already carrying a critter!", "error")
		return
	end
	local cooldownLeft = (lastSteal[thief] or 0) + STEAL.Cooldown - os.clock()
	if cooldownLeft > 0 then
		Notifier.Send(thief, `Wait {math.ceil(cooldownLeft)}s before stealing again`, "error")
		return
	end

	local ownerPlot = PlotService.GetPlot(owner)
	if not ownerPlot or not PlotService.GetPlot(thief) then
		return
	end
	if PlotService.IsLocked(ownerPlot) then
		Notifier.Send(thief, "🔒 This base is locked!", "error")
		return
	end
	if not UnitService.HasFreeSlot(thief) then
		Notifier.Send(thief, "Your base is full! Sell a critter to make room.", "error")
		return
	end

	local root, humanoid = getCharacterParts(thief)
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local promptPart = prompt.Parent
	if promptPart and promptPart:IsA("BasePart") then
		if (promptPart.Position - root.Position).Magnitude > prompt.MaxActivationDistance + 6 then
			return
		end
	end

	local unit = UnitService.GetUnit(owner, guid)
	if not unit then
		return
	end
	local model = UnitService.BeginCarry(owner, guid)
	local modelRoot = model and model.PrimaryPart
	if not model or not modelRoot then
		return
	end

	-- Carry it above the thief's head.
	local standOffset = model:GetAttribute("StandOffset") or 2
	modelRoot.Anchored = false
	model:PivotTo(root.CFrame * CFrame.new(0, 2.8 + standOffset, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = modelRoot
	weld.Parent = modelRoot

	local label = unitLabel(unit.Name, unit.Mutation)
	local carry: Carry = {
		Owner = owner,
		Guid = guid,
		Model = model,
		Weld = weld,
		StartedAt = os.clock(),
		UnitName = unit.Name,
		Label = label,
	}
	carries[thief] = carry
	lastSteal[thief] = os.clock()

	humanoid.WalkSpeed = getCarrySpeed(thief)
	thief:SetAttribute("Carrying", label)
	humanoid.Died:Once(function()
		if carries[thief] == carry then
			failCarry(thief, "died")
		end
	end)

	local mutationInfo = Mutations.Get(unit.Mutation)
	local valueHint = if mutationInfo.Multiplier > 1 then ` (x{mutationInfo.Multiplier})` else ""
	Notifier.Send(owner, `🚨 {thief.DisplayName} is stealing your {label}{valueHint}! Slap them!`, "alert")
	Notifier.Send(thief, `🏃 Run back to your base with {label}!`, "info")
end

-- Called by CombatService when a player gets slapped.
function StealService.OnSlapped(target: Player, attacker: Player)
	local carry = carries[target]
	if not carry then
		return
	end
	failCarry(target, "slapped")
	if attacker ~= carry.Owner then
		Notifier.Send(attacker, `💥 You stopped {target.DisplayName}'s heist!`, "success")
	else
		Notifier.Send(attacker, `💥 You got your {carry.Label} back!`, "success")
	end
end

-- Lifecycle -------------------------------------------------------------------

function StealService.OnPlayerRemoving(player: Player)
	holdStarts[player] = nil
	lastSteal[player] = nil

	if carries[player] then
		failCarry(player, "left")
	end

	-- Critters of the leaving player that are being carried: cancel those steals.
	for thief, carry in carries do
		if carry.Owner == player then
			endCarry(thief, carry)
			Notifier.Send(thief, `{player.DisplayName} left, the steal was cancelled`, "info")
		end
	end
end

function StealService.Init(services)
	DataService = services.DataService
	UnitService = services.UnitService
	PlotService = services.PlotService
	CurrencyService = services.CurrencyService
	MonetizationService = services.MonetizationService
end

function StealService.Start()
	task.spawn(function()
		while true do
			task.wait(0.2)
			for thief, carry in carries do
				local root, humanoid = getCharacterParts(thief)
				if not root or not humanoid or humanoid.Health <= 0 or carry.Weld.Part0 ~= root then
					failCarry(thief, "died")
				elseif os.clock() - carry.StartedAt > STEAL.CarryTimeout then
					failCarry(thief, "timeout")
				else
					local plot = PlotService.GetPlot(thief)
					if plot and PlotService.IsInside(plot, root.Position) then
						succeedCarry(thief)
					end
				end
			end
		end
	end)
end

return StealService
