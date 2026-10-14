--[[
	CombatService
	Character setup (collision group, walk speed) and the Slap glove every
	player gets. A slap knocks the target back (applied by the target's
	client) and makes a thief drop the critter they carry (server-side).
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)

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

	-- The default Animate script plays its slash animation when it sees this value.
	local animation = Instance.new("StringValue")
	animation.Name = "toolanim"
	animation.Value = "Slash"
	animation.Parent = tool
	Debris:AddItem(animation, 0.5)

	local handle = tool:FindFirstChild("Handle")
	local sound = handle and handle:FindFirstChild("SlapSound") :: Sound?
	if sound then
		sound:Play()
	end

	local mega = MonetizationService.OwnsPass(player, "MegaSlap")
	local target, targetRoot = findTarget(player, root, if mega then SLAP.MegaRange else SLAP.Range)
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

local function giveSlapTool(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack then
		return
	end
	for _, container in { backpack, player.Character } do
		local old = container and container:FindFirstChild("Slap")
		if old then
			old:Destroy()
		end
	end

	local mega = MonetizationService.OwnsPass(player, "MegaSlap")

	local tool = Instance.new("Tool")
	tool.Name = "Slap"
	tool.ToolTip = if mega then "Mega Slap!" else "Slap thieves to make them drop critters"
	tool.CanBeDropped = false
	tool.RequiresHandle = true

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Ball
	handle.Size = Vector3.one * (if mega then 1.9 else 1.3)
	handle.Color = if mega then Color3.fromRGB(255, 200, 40) else Color3.fromRGB(230, 50, 50)
	handle.Material = if mega then Enum.Material.Foil else Enum.Material.SmoothPlastic
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local sound = Instance.new("Sound")
	sound.Name = "SlapSound"
	sound.SoundId = GameConfig.Sounds.Slap
	sound.Volume = 0.6
	sound.Parent = handle

	tool.Activated:Connect(function()
		onSlap(player, tool)
	end)
	tool.Parent = backpack
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
			giveSlapTool(player)
		end
	end)
end

return CombatService
