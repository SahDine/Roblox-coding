--[[
	DataService
	Loads and saves player data with DataStoreService.

	- Session locking: a profile can only be open on one server at a time,
	  which prevents item duplication when a player hops between servers.
	- Every write uses UpdateAsync; failed saves are retried.
	- Autosave every GameConfig.Data.AutoSaveInterval seconds + save on leave + BindToClose.
	- In Studio, if API access is disabled (or Debug.UseMockDataInStudio), an
	  in-memory store is used so the game stays testable.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local DataService = {}

local DATA = GameConfig.Data

type Profile = {
	Data: { [string]: any },
	Key: string,
	Released: boolean, -- no more writes allowed (final save started or lock lost)
	Releasing: boolean?,
	ReleaseFinished: boolean?,
}

local profiles: { [Player]: Profile } = {}
local useMock = false
local mockStore: { [string]: any } = {}
local store: DataStore? = nil

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value :: any do
		copy[deepCopy(key)] = deepCopy(item)
	end
	return copy :: any
end

local function getDefaultData()
	return {
		Version = 1,
		Cash = GameConfig.Player.StartingCash,
		TotalEarned = 0,
		Rebirths = 0,
		BaseLevel = 1, -- base upgrade level (UpgradeService), kept through rebirths
		-- [guid] = { Name, Mutation, Slot, Stored }
		Units = {},
		-- Critters waiting for a free slot: { { Name, Mutation } }
		Storage = {},
		Daily = { LastClaim = 0, Streak = 0 },
		RedeemedCodes = {},
		Receipts = {},
		Stats = { Steals = 0, TimesRobbed = 0, RobuxSpent = 0 },
		LastOnline = 0,
	}
end

-- Adds missing fields (new features) without touching existing values.
local function reconcile(data, template)
	for key, value in template do
		if data[key] == nil then
			data[key] = deepCopy(value)
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil then
			reconcile(data[key], value)
		end
	end
end

local function updateAsync(key: string, transform: (any) -> any)
	if useMock then
		local result = transform(deepCopy(mockStore[key]))
		if result ~= nil then
			mockStore[key] = deepCopy(result)
		end
		return result
	end
	assert(store, "DataStore not initialised")
	return store:UpdateAsync(key, transform)
end

function DataService.Get(player: Player): { [string]: any }?
	local profile = profiles[player]
	if profile and not profile.Released then
		return profile.Data
	end
	return nil
end

function DataService.IsLoaded(player: Player): boolean
	return DataService.Get(player) ~= nil
end

function DataService.IsMock(): boolean
	return useMock
end

-- Yields. Returns the data, or nil if it could not be loaded (the player is kicked).
function DataService.LoadAsync(player: Player): { [string]: any }?
	local key = "Player_" .. player.UserId
	local loaded: any = nil
	local success = false

	for attempt = 1, DATA.LoadAttempts do
		if not player.Parent then
			return nil
		end

		local forceSteal = attempt == DATA.LoadAttempts
		local lockedElsewhere = false

		local ok, err = pcall(updateAsync, key, function(old)
			old = if type(old) == "table" then old else {}
			local now = os.time()
			local session = old.Session
			if
				not forceSteal
				and session
				and session.JobId ~= game.JobId
				and now - (session.Time or 0) < DATA.SessionLockExpiry
			then
				lockedElsewhere = true
				return nil -- cancel the write, try again later
			end
			lockedElsewhere = false
			loaded = old.Data
			old.Session = { JobId = game.JobId, Time = now }
			return old
		end)

		if ok and not lockedElsewhere then
			success = true
			break
		end

		if not ok then
			warn(`[DataService] Load attempt {attempt} failed for {player.Name}: {err}`)
		end
		task.wait(DATA.LoadRetryDelay)
	end

	if not success then
		player:Kick("Could not load your data. Please rejoin in a minute!")
		return nil
	end

	local data = if type(loaded) == "table" then loaded else getDefaultData()
	reconcile(data, getDefaultData())

	if RunService:IsStudio() and GameConfig.Debug.StudioStartingCash then
		data.Cash = GameConfig.Debug.StudioStartingCash
	end

	local profile: Profile = { Data = data, Key = key, Released = false }

	-- The player left while we were loading: release the lock right away.
	if not player.Parent then
		profiles[player] = profile
		DataService.ReleaseAsync(player)
		return nil
	end

	profiles[player] = profile
	return data
end

-- Yields. Returns true when the data reached the DataStore.
function DataService.SaveAsync(player: Player, release: boolean?): boolean
	local profile = profiles[player]
	if not profile or profile.Released then
		return false
	end

	if release then
		-- No other code may touch this data anymore.
		profile.Released = true
	end

	profile.Data.LastOnline = os.time()
	local snapshot = deepCopy(profile.Data)

	for attempt = 1, 3 do
		local lockLost = false
		local ok, err = pcall(updateAsync, profile.Key, function(old)
			old = if type(old) == "table" then old else {}
			local session = old.Session
			if not session or session.JobId ~= game.JobId then
				lockLost = true
				return nil
			end
			lockLost = false
			return {
				Data = snapshot,
				Session = if release then nil else { JobId = game.JobId, Time = os.time() },
			}
		end)

		if ok then
			if lockLost then
				-- Another server took over this profile: never overwrite its data.
				warn(`[DataService] Session lock lost for {player.Name}`)
				profile.Released = true
				if player.Parent then
					player:Kick("Your data was opened on another server. Please rejoin!")
				end
				return false
			end
			return true
		end

		warn(`[DataService] Save attempt {attempt} failed for {player.Name}: {err}`)
		task.wait(attempt * 2)
	end

	return false
end

-- Final save + unlock. Called when the player leaves and on shutdown.
-- Safe to call several times: later callers wait for the first one to finish.
function DataService.ReleaseAsync(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	if profile.Releasing then
		while not profile.ReleaseFinished do
			task.wait(0.1)
		end
		return
	end
	profile.Releasing = true
	DataService.SaveAsync(player, true)
	profile.ReleaseFinished = true
	if profiles[player] == profile then
		profiles[player] = nil
	end
end

function DataService.Init()
	if RunService:IsStudio() and GameConfig.Debug.UseMockDataInStudio then
		useMock = true
	else
		local ok, err = pcall(function()
			store = DataStoreService:GetDataStore(DATA.StoreName)
			if RunService:IsStudio() then
				-- Probe: fails when "Enable Studio Access to API Services" is off.
				(store :: DataStore):GetAsync("__studio_probe")
			end
		end)
		if not ok then
			if RunService:IsStudio() then
				useMock = true
				warn(
					"[DataService] DataStores unavailable in Studio, using a temporary in-memory store. "
						.. "Publish the place and enable 'Studio Access to API Services' to test saving. ("
						.. tostring(err)
						.. ")"
				)
			else
				error(err)
			end
		end
	end
end

function DataService.Start()
	-- Autosave loop.
	task.spawn(function()
		while true do
			task.wait(DATA.AutoSaveInterval)
			for player, profile in profiles do
				if not profile.Released then
					task.spawn(DataService.SaveAsync, player)
					task.wait(0.5)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService.ReleaseAsync(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
