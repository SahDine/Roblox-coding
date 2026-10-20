--[[
	SlapController
	The slap swing, seen by everyone: the right arm goes out to the right, sweeps across the front
	of the body to the left and comes back, with a short twist of the upper body, the glove's trail
	and a whoosh.

	There is no animation asset: the joints are driven in code by changing Motor6D.C0 every frame
	(the final pose is C0 * Transform, Transform being written by the default Animator, so the
	normal animations keep running underneath) and the original C0 is restored afterwards.
	  * Right shoulder (R15 RightUpperArm.RightShoulder, R6 Torso["Right Shoulder"]): blended from
	    the animated pose to the scripted swing and back, so the swing looks the same whatever the
	    character is doing. R15 also straightens the elbow.
	  * Upper body (R15 UpperTorso.Waist, R6 HumanoidRootPart.RootJoint): a twist added on top.

	The server fires SlapFx(slapper, target?) to every client for each accepted swing (hits and
	misses). The local player's swing starts right on click (Tool.Activated) and its echo is only
	used for the hit sound. On a hit, the glove's HitSound plays when the hand crosses the front
	(the target hears it at once: their knockback starts right away).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local SlapController = {}

local player = Players.LocalPlayer
local SLAP = GameConfig.Slap

-- Timeline (seconds).
local WIND_UP = 0.1 -- the arm goes out to the right
local SWEEP = 0.24 -- right to left across the front of the body
local HOLD = 0.05 -- follow-through on the left
local RECOVER = 0.22 -- back to the animated pose
local SWEEP_END = WIND_UP + SWEEP
local RECOVER_START = SWEEP_END + HOLD
local DURATION = RECOVER_START + RECOVER
local IMPACT = WIND_UP + SWEEP * 0.5 -- the hand crosses the front of the body: hit sound

-- Arm direction relative to the torso: yaw around its vertical axis (0 = straight ahead,
-- + = to the left) and pitch from hanging down (90 degrees = horizontal).
local YAW_RIGHT = math.rad(-85)
local YAW_LEFT = math.rad(55)
local PITCH = math.rad(84)
local PITCH_LIFT = math.rad(10) -- the arm rises a little in the middle of the sweep
local ELBOW_BEND = math.rad(10) -- R15: nearly straight arm during the swing
-- Upper body twist (+ = turned to the left).
local TWIST_RIGHT = math.rad(-16)
local TWIST_LEFT = math.rad(20)

-- The echo of the local player's own swing arrives about one ping after the click; inside this
-- window it is ignored, later it means the server accepted a click the client did not animate.
local ECHO_WINDOW = SLAP.Cooldown * 0.75
-- Swings farther than this from the camera are not animated.
local MAX_DISTANCE = 300

type JointTrack = {
	Joint: Motor6D,
	Original: CFrame, -- C0 before the swing
	Written: CFrame?, -- last C0 written here (if it changed since, someone else owns the joint)
	From: CFrame?, -- pose shown when a swing restarted mid-way (nil = start from the animated pose)
}

type Swing = {
	Start: number,
	Shoulder: JointTrack?,
	Elbow: JointTrack?,
	Waist: JointTrack?,
	TwistFrom: number,
	Twist: number,
	Trail: Trail?,
	TrailOn: boolean,
	HitPending: boolean, -- play the hit sound at IMPACT
}

local swings: { [Model]: Swing } = {}
local stepConnection: RBXScriptConnection? = nil
local lastLocalSwing = -math.huge

-- Maths ---------------------------------------------------------------------------------------

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function easeOut(x: number): number
	return 1 - (1 - x) * (1 - x)
end

local function smooth(x: number): number
	local t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

local function armRotation(yaw: number, pitch: number): CFrame
	return CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
end

-- Arm orientation relative to the torso at time t, and how much it replaces the animated pose.
local function armPose(t: number): (CFrame, number)
	if t < WIND_UP then
		return armRotation(YAW_RIGHT, PITCH), easeOut(t / WIND_UP)
	elseif t < SWEEP_END then
		local s = smooth((t - WIND_UP) / SWEEP)
		return armRotation(lerp(YAW_RIGHT, YAW_LEFT, s), PITCH + math.sin(s * math.pi) * PITCH_LIFT), 1
	end
	return armRotation(YAW_LEFT, PITCH), 1 - smooth((t - RECOVER_START) / RECOVER)
end

local function twistAt(swing: Swing, t: number): number
	if t < WIND_UP then
		return lerp(swing.TwistFrom, TWIST_RIGHT, easeOut(t / WIND_UP))
	elseif t < SWEEP_END then
		return lerp(TWIST_RIGHT, TWIST_LEFT, smooth((t - WIND_UP) / SWEEP))
	end
	return lerp(TWIST_LEFT, 0, smooth((t - RECOVER_START) / RECOVER))
end

-- Joints --------------------------------------------------------------------------------------

local function findMotor(parent: Instance?, name: string): Motor6D?
	local joint = parent and parent:FindFirstChild(name)
	if joint and joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
		return joint
	end
	return nil
end

local function newTrack(joint: Motor6D?): JointTrack?
	if not joint then
		return nil
	end
	return { Joint = joint, Original = joint.C0 }
end

-- Keeps the original C0 up to date if something else rewrote the joint (e.g. a rig rebuild).
local function original(track: JointTrack): CFrame
	local current = track.Joint.C0
	if track.Written and current ~= track.Written then
		track.Original = current
	end
	return track.Original
end

--[[
	Poses the joint so that Part1 is turned by `rotation` (relative to Part0, around the joint's
	pivot) from its rest pose, blended with the animated pose by `weight`. Part1 ends up at
	Part0 * C0 * Transform * C1:Inverse(), so C0 = pose * Transform:Inverse().
]]
local function drive(track: JointTrack, rotation: CFrame, weight: number, fromCaptured: boolean)
	local joint = track.Joint
	local rest = original(track)
	local transform = joint.Transform
	local base = if fromCaptured and track.From then track.From else rest * transform
	local target = CFrame.new(rest.Position) * rotation * rest.Rotation
	joint.C0 = base:Lerp(target, weight) * transform:Inverse()
	track.Written = joint.C0
end

-- Adds a turn around Part0's vertical axis on top of the animated pose.
local function twist(track: JointTrack, angle: number)
	local rest = original(track)
	track.Joint.C0 = CFrame.new(rest.Position) * CFrame.Angles(0, angle, 0) * rest.Rotation
	track.Written = track.Joint.C0
end

local function restore(track: JointTrack?)
	if track and track.Written and track.Joint.C0 == track.Written then
		track.Joint.C0 = track.Original
	end
end

-- Remembers the pose shown right now as the start of a restarted swing.
local function capture(track: JointTrack?)
	if track then
		track.From = track.Joint.C0 * track.Joint.Transform
	end
end

local function alive(track: JointTrack?): boolean
	return track == nil or track.Joint:IsDescendantOf(workspace)
end

-- Swings --------------------------------------------------------------------------------------

-- A sound of the glove the character holds (the tool is in the character while it is equipped).
local function gloveSound(character: Model, name: string): Sound?
	local tool = character:FindFirstChild("Slap")
	local handle = tool and tool:FindFirstChild("Handle")
	local sound = handle and handle:FindFirstChild(name)
	return if sound and sound:IsA("Sound") then sound else nil
end

local function finish(character: Model, swing: Swing)
	restore(swing.Shoulder)
	restore(swing.Elbow)
	restore(swing.Waist)
	if swing.Trail then
		swing.Trail.Enabled = false
	end
	swings[character] = nil
end

local function step()
	local now = os.clock()
	for character, swing in swings do
		local t = now - swing.Start
		if
			t >= DURATION
			or not character:IsDescendantOf(workspace)
			or not (alive(swing.Shoulder) and alive(swing.Elbow) and alive(swing.Waist))
		then
			finish(character, swing)
			continue
		end

		local windingUp = t < WIND_UP
		local rotation, weight = armPose(t)
		if swing.Shoulder then
			drive(swing.Shoulder, rotation, weight, windingUp)
		end
		if swing.Elbow then
			drive(swing.Elbow, CFrame.Angles(ELBOW_BEND, 0, 0), weight, windingUp)
		end
		swing.Twist = twistAt(swing, t)
		if swing.Waist then
			twist(swing.Waist, swing.Twist)
		end

		local trailOn = t >= WIND_UP * 0.5 and t < RECOVER_START
		if swing.Trail and trailOn ~= swing.TrailOn then
			swing.Trail.Enabled = trailOn
		end
		swing.TrailOn = trailOn

		if swing.HitPending and t >= IMPACT then
			swing.HitPending = false
			local hit = gloveSound(character, "HitSound")
			if hit then
				hit:Play()
			end
		end
	end

	if next(swings) == nil and stepConnection then
		stepConnection:Disconnect()
		stepConnection = nil
	end
end

local function playSwing(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not root or not root:IsA("BasePart") then
		return
	end
	if camera and (camera.CFrame.Position - root.Position).Magnitude > MAX_DISTANCE then
		return
	end

	local now = os.clock()
	local swing = swings[character]
	if swing then
		-- Restart from the pose shown right now (no jump).
		capture(swing.Shoulder)
		capture(swing.Elbow)
		swing.TwistFrom = swing.Twist
		swing.Start = now
	else
		local shoulder = findMotor(character:FindFirstChild("RightUpperArm"), "RightShoulder")
		local elbow: Motor6D?, waist: Motor6D? = nil, nil
		if shoulder then -- R15
			elbow = findMotor(character:FindFirstChild("RightLowerArm"), "RightElbow")
			waist = findMotor(character:FindFirstChild("UpperTorso"), "Waist")
		else -- R6
			shoulder = findMotor(character:FindFirstChild("Torso"), "Right Shoulder")
			waist = findMotor(root, "RootJoint")
		end
		swing = {
			Start = now,
			Shoulder = newTrack(shoulder),
			Elbow = newTrack(elbow),
			Waist = newTrack(waist),
			TwistFrom = 0,
			Twist = 0,
			TrailOn = false,
			HitPending = false,
		}
		swings[character] = swing
	end

	-- Glove effects (the tool is in the character while it is equipped).
	local tool = character:FindFirstChild("Slap")
	local handle = tool and tool:FindFirstChild("Handle")
	if handle then
		local trail = handle:FindFirstChild("SwingTrail")
		if trail and trail:IsA("Trail") and trail ~= swing.Trail then
			if swing.Trail then
				swing.Trail.Enabled = false
			end
			swing.Trail = trail
			swing.TrailOn = false -- the new trail is switched on by the next step
		end
		local whoosh = gloveSound(character, "Whoosh")
		if whoosh then
			whoosh:Play()
		end
	end

	if not stepConnection then
		stepConnection = RunService.PreSimulation:Connect(step)
	end
end

-- The slap landed: the hit sound plays when the hand crosses the front, or right away if it already
-- has (and for the target, who is knocked back at once).
local function landHit(character: Model, isTarget: boolean)
	local swing = swings[character]
	if swing and not isTarget and os.clock() - swing.Start < IMPACT then
		swing.HitPending = true -- played by step
		return
	end
	local hit = gloveSound(character, "HitSound")
	if hit then
		hit:Play()
	end
end

-- Local player --------------------------------------------------------------------------------

local function onLocalActivated(tool: Tool)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 or tool.Parent ~= character then
		return
	end
	local now = os.clock()
	if now - lastLocalSwing < SLAP.Cooldown then
		return -- the server refuses it too
	end
	lastLocalSwing = now
	playSwing(character)
end

local hookedTools: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function hookTool(child: Instance)
	if child:IsA("Tool") and child.Name == "Slap" and not hookedTools[child] then
		hookedTools[child] = true
		child.Activated:Connect(function()
			onLocalActivated(child)
		end)
	end
end

local function watchCharacter(character: Model)
	for _, child in character:GetChildren() do
		hookTool(child)
	end
	character.ChildAdded:Connect(hookTool)
end

function SlapController.Start()
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end

	Remotes.SlapFx.OnClientEvent:Connect(function(slapper: unknown, target: unknown)
		if typeof(slapper) ~= "Instance" or not slapper:IsA("Player") then
			return
		end
		local hit = typeof(target) == "Instance" and target:IsA("Player")
		local character = slapper.Character
		if slapper == player then
			local now = os.clock()
			if now - lastLocalSwing < ECHO_WINDOW then
				-- Already played on click: only the hit sound is new.
				if hit and character then
					landHit(character, false)
				end
				return
			end
			lastLocalSwing = now
		end
		if character then
			playSwing(character)
			-- Swings too far away to be animated stay silent (the sound would not carry anyway).
			if hit and (swings[character] or target == player) then
				landHit(character, target == player)
			end
		end
	end)
end

return SlapController
