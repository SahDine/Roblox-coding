--[[
	Walker
	Makes a Humanoid walk through a list of waypoints.
	- Humanoid:MoveTo gives up after 8 seconds, so each waypoint is re-issued until reached.
	- A token lets the caller cancel a walk at any moment (critter bought, stolen, owner left...).
	- A global deadline guarantees the walk always ends.
]]

local Walker = {}

export type Token = { Cancelled: boolean }

function Walker.NewToken(): Token
	return { Cancelled = false }
end

local function waitForMoveFinished(humanoid: Humanoid, timeout: number): boolean
	local thread = coroutine.running()
	local finished = false
	local connection

	local function finish(reached: boolean)
		if finished then
			return
		end
		finished = true
		if connection then
			connection:Disconnect()
		end
		task.spawn(thread, reached)
	end

	connection = humanoid.MoveToFinished:Connect(finish)
	task.delay(timeout, finish, false)

	return coroutine.yield()
end

-- Returns "Arrived", "Cancelled" or "Timeout".
function Walker.Walk(humanoid: Humanoid, waypoints: { Vector3 }, token: Token, maxDuration: number?): string
	local deadline = os.clock() + (maxDuration or 60)

	for _, point in waypoints do
		while true do
			if token.Cancelled or not humanoid.Parent then
				return "Cancelled"
			end
			if os.clock() > deadline then
				return "Timeout"
			end

			humanoid:MoveTo(point)
			local reached = waitForMoveFinished(humanoid, 9)

			if token.Cancelled or not humanoid.Parent then
				return "Cancelled"
			end
			if reached then
				break
			end
		end
	end

	return "Arrived"
end

return Walker
