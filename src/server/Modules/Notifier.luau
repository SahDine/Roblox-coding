--[[
	Notifier
	Sends toast notifications to clients.
	Kinds: "info", "success", "error", "alert" (red, with sound), "announce" (big golden banner).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Notifier = {}

function Notifier.Send(player: Player, message: string, kind: string?)
	Remotes.Notify:FireClient(player, message, kind or "info")
end

function Notifier.All(message: string, kind: string?)
	Remotes.Notify:FireAllClients(message, kind or "info")
end

return Notifier
