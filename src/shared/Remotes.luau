--[[
	Remotes
	Typed access to the RemoteEvents / RemoteFunctions declared in default.project.json.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:WaitForChild("Remotes")

return {
	-- Server -> client
	Notify = folder:WaitForChild("Notify") :: RemoteEvent,
	Knockback = folder:WaitForChild("Knockback") :: RemoteEvent,
	SlapFx = folder:WaitForChild("SlapFx") :: RemoteEvent, -- (slapper: Player, target: Player?) every client animates the swing

	-- Client -> server
	TeleportHome = folder:WaitForChild("TeleportHome") :: RemoteEvent,
	RequestRebirth = folder:WaitForChild("RequestRebirth") :: RemoteFunction,
	ClaimDaily = folder:WaitForChild("ClaimDaily") :: RemoteFunction,
	RedeemCode = folder:WaitForChild("RedeemCode") :: RemoteFunction,
	UpgradeBase = folder:WaitForChild("UpgradeBase") :: RemoteFunction,
}
