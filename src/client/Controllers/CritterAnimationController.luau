--[[
	CritterAnimationController
	Animates every critter on this client: walk cycle while moving (legs, arms, bouncing
	body), idle life when standing (breathing, looking around, tail wag, ear twitch, wing
	flaps), hovering for flying critters, rainbow colours for the Rainbow mutation.
	The curves live in Shared/CritterPose; the rig is built by CritterBuilder (one Motor6D
	per bone, attributes Role / Side / Phase / Amp).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CritterPose = require(ReplicatedStorage.Shared.CritterPose)

local CritterAnimationController = {}

local BODY_DISTANCE = 160 -- body bounce / hover
local BONE_DISTANCE = 110 -- limbs, head, tail...
local RAINBOW_INTERVAL = 1 / 15

type Joint = {
	Motor: Motor6D,
	Role: string,
	Side: number,
	Phase: number,
	Amp: number,
}

type Tracked = {
	Model: Model,
	Root: BasePart?,
	Body: Motor6D?,
	Joints: { Joint },
	State: CritterPose.State,
	Paint: { BasePart },
	Rainbow: boolean,
}

local tracked: { [Model]: Tracked } = {}

local function scan(info: Tracked)
	local model = info.Model
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	info.Root = root
	info.Body = root and root:FindFirstChild("Bounce") :: Motor6D?
	table.clear(info.Joints)
	table.clear(info.Paint)
	local hasLegs = false
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			local role = descendant:GetAttribute("Role")
			if type(role) == "string" and role ~= "Static" then
				table.insert(info.Joints, {
					Motor = descendant,
					Role = role,
					Side = descendant:GetAttribute("Side") or 0,
					Phase = descendant:GetAttribute("Phase") or 0,
					Amp = descendant:GetAttribute("Amp") or 1,
				})
				hasLegs = hasLegs or role == "Leg"
			end
		elseif descendant:IsA("BasePart") and descendant:GetAttribute("Paint") then
			table.insert(info.Paint, descendant)
		end
	end
	info.State.HasLegs = hasLegs
	info.State.Scale = model:GetAttribute("Scale") or 1
	info.State.Floats = model:GetAttribute("Floats") == true
	info.Rainbow = model:GetAttribute("Mutation") == "Rainbow"
end

local function track(instance: Instance)
	if not instance:IsA("Model") or tracked[instance] then
		return
	end
	local info: Tracked = {
		Model = instance,
		Root = nil,
		Body = nil,
		Joints = {},
		Paint = {},
		Rainbow = false,
		State = {
			Time = 0,
			Seed = math.random() * 100,
			Cycle = math.random(),
			Walk = 0,
			Floats = false,
			Scale = 1,
			HasLegs = false,
		},
	}
	tracked[instance] = info
	scan(info)
	-- Big models can finish replicating a moment after the tag shows up.
	task.delay(1, function()
		if tracked[instance] == info then
			scan(info)
		end
	end)
end

local rainbowClock = 0

local function step(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPosition = camera.CFrame.Position
	local now = os.clock()
	rainbowClock += dt
	local paintRainbow = rainbowClock >= RAINBOW_INTERVAL
	if paintRainbow then
		rainbowClock = 0
	end

	for model, info in tracked do
		local root = info.Root
		if not root or not root.Parent then
			continue
		end
		local distance = (root.Position - cameraPosition).Magnitude
		if distance > BODY_DISTANCE then
			continue
		end

		local state = info.State
		local velocity = root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local target = if speed > 0.8 then 1 else 0
		state.Walk += (target - state.Walk) * math.min(1, dt * 6)
		state.Cycle = (state.Cycle + dt * CritterPose.CycleRate(speed, state.Scale)) % 1
		state.Time = now

		if info.Body then
			info.Body.Transform = CritterPose.Body(state)
		end
		if distance <= BONE_DISTANCE then
			for _, joint in info.Joints do
				joint.Motor.Transform = CritterPose.Bone(joint.Role, joint.Side, joint.Phase, joint.Amp, state)
			end
		end

		if info.Rainbow and paintRainbow then
			for index, part in info.Paint do
				part.Color = Color3.fromHSV((now * 0.25 + index * 0.02) % 1, 0.75, 1)
			end
		end
	end
end

function CritterAnimationController.Start()
	for _, model in CollectionService:GetTagged("Critter") do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal("Critter"):Connect(track)
	CollectionService:GetInstanceRemovedSignal("Critter"):Connect(function(model)
		tracked[model :: Model] = nil
	end)
	RunService.RenderStepped:Connect(step)
end

return CritterAnimationController
