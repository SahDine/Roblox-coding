--[[
	CritterPose
	Animation curves of the critters (pure functions, no state): the client animator
	(CritterAnimationController) writes them into the Motor6D.Transform of every bone.

	Bones are created by CritterBuilder; each bone motor has a Role (Leg, Arm, Head, Tail,
	Wing, Ear, Fin, Jaw, Float, Spin, Static), a Side (+1 right, -1 left, 0 centre), a Phase
	(0..1, offset in the walk cycle) and an Amp (amplitude multiplier). Rotations are in the
	critter's own axes (X = right, Y = up, -Z = forward) around the bone pivot.
]]

local CritterPose = {}

export type State = {
	Time: number, -- seconds
	Seed: number, -- per-critter offset so critters do not move in sync
	Cycle: number, -- walk cycle position (1 = one full stride)
	Walk: number, -- 0 = idle .. 1 = walking
	Floats: boolean, -- flying / hovering critter
	Scale: number, -- rarity scale of the critter (studs)
	HasLegs: boolean,
}

local TAU = math.pi * 2

function CritterPose.Bone(role: string, side: number, phase: number, amp: number, state: State): CFrame
	local walk = state.Walk
	local idle = 1 - walk
	local t = state.Time + state.Seed
	local cycle = (state.Cycle + phase) * TAU

	if role == "Leg" then
		if state.Floats then
			-- Dangling legs paddle gently while hovering.
			return CFrame.Angles((math.sin(t * 2.2 + phase * TAU) * 0.12 + 0.1 * walk) * amp, 0, 0)
		end
		return CFrame.Angles(math.sin(cycle) * 0.55 * walk * amp, 0, 0)
	elseif role == "Arm" then
		local swing = -math.sin(cycle) * 0.6 * walk
		local sway = math.sin(t * 1.7 + phase * TAU) * 0.12 * idle
		local open = side * (0.06 + math.sin(t * 1.3) * 0.05) * idle
		return CFrame.Angles((swing + sway) * amp, 0, open * amp)
	elseif role == "Head" then
		local nod = math.sin(t * 1.15) * 0.06 * idle + math.sin(cycle * 2) * 0.06 * walk
		local look = math.sin(t * 0.55) * 0.22 * idle
		local tilt = math.sin(t * 0.8 + 1) * 0.06 * idle
		return CFrame.Angles(nod * amp, look * amp, tilt * amp)
	elseif role == "Tail" then
		local speed = 2.6 + 3.4 * walk
		local wag = math.sin(t * speed + phase * TAU) * (0.28 + 0.14 * walk)
		return CFrame.Angles(math.sin(t * 1.3) * 0.08 * amp, wag * amp, 0)
	elseif role == "Wing" then
		local flap
		if state.Floats then
			flap = math.sin(t * 6.5 + phase * TAU) * 0.45 + 0.1
		else
			flap = math.sin(t * 1.6 + phase * TAU) * 0.1 + math.abs(math.sin(cycle)) * 0.2 * walk
		end
		return CFrame.Angles(0, 0, side * flap * amp)
	elseif role == "Ear" then
		local twitch = math.max(0, math.sin(t * 0.9 + phase * TAU)) ^ 12 * 0.45
		return CFrame.Angles(0, 0, side * (twitch + math.sin(t * 2.1) * 0.05) * amp)
	elseif role == "Fin" then
		return CFrame.Angles(0, math.sin(t * 4 + phase * TAU) * 0.3 * amp, 0)
	elseif role == "Jaw" then
		return CFrame.Angles(math.max(0, math.sin(t * 1.4 + phase * TAU)) * 0.25 * amp, 0, 0)
	elseif role == "Float" then
		return CFrame.new(0, math.sin(t * 1.8 + phase * TAU) * 0.35 * state.Scale * amp, 0)
	elseif role == "Spin" then
		return CFrame.Angles(0, (t * 1.2 * amp) % TAU, 0)
	end
	return CFrame.identity
end

-- Transform of the whole body (the "Bounce" motor between the root and the core).
function CritterPose.Body(state: State): CFrame
	local t = state.Time + state.Seed
	local walk = state.Walk
	local idle = 1 - walk
	local scale = state.Scale

	if state.Floats then
		local y = (math.sin(t * 1.6) + 1) * 0.35 * scale
		return CFrame.new(0, y, 0) * CFrame.Angles(math.sin(t * 1.6) * 0.05 - 0.12 * walk, math.sin(t * 0.8) * 0.12 * idle, 0)
	end

	local stride = state.Cycle * TAU
	local bounce = math.abs(math.sin(stride)) * (if state.HasLegs then 0.14 else 0.4) * scale * walk
	local breathe = (math.sin(t * 2.2) + 1) * 0.05 * scale * idle
	local waddle = math.sin(stride) * (if state.HasLegs then 0.04 else 0.15) * walk
	local sway = math.sin(t * 0.9) * 0.08 * idle
	return CFrame.new(0, bounce + breathe, 0) * CFrame.Angles(0, sway, waddle)
end

-- How fast the walk cycle advances for a critter moving at `speed` studs per second.
function CritterPose.CycleRate(speed: number, scale: number): number
	return math.clamp(speed / (2.4 * scale), 0, 3.5)
end

return CritterPose
