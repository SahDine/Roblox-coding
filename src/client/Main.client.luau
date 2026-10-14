--[[
	Client entry point: starts every controller in order.
	NotificationController first so the others can show messages right away.
]]

local Controllers = script.Parent:WaitForChild("Controllers")

local ORDER = {
	"NotificationController",
	"HUDController",
	"StoreController",
	"RebirthController",
	"DailyController",
	"CodesController",
	"WorldController",
}

for _, name in ORDER do
	local module = Controllers:WaitForChild(name)
	local ok, err = pcall(function()
		require(module).Start()
	end)
	if not ok then
		warn(`[Client] {name} failed to start: {err}`)
	end
end
