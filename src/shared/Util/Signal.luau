--[[
	Signal
	Minimal event object. Handlers run in their own thread so one failing
	handler never breaks the others.
]]

local Signal = {}
Signal.__index = Signal

export type Connection = {
	Disconnect: () -> (),
}

function Signal.new()
	return setmetatable({ _handlers = {} :: { (...any) -> () } }, Signal)
end

function Signal:Connect(handler: (...any) -> ()): Connection
	local handlers = self._handlers
	table.insert(handlers, handler)
	return {
		Disconnect = function()
			local index = table.find(handlers, handler)
			if index then
				table.remove(handlers, index)
			end
		end,
	}
end

function Signal:Fire(...: any)
	for _, handler in table.clone(self._handlers) do
		task.spawn(handler, ...)
	end
end

return Signal
