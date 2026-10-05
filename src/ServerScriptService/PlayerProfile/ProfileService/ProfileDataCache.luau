local profileType = require(script.Parent.DefaultPlayerData)
local playerProfileFolder = game.ServerScriptService.PlayerProfile
local profileBindableEvent = playerProfileFolder.ProfileInit.ProfileLoadedEvent
local profileRemoteEvent = game.ReplicatedStorage.Profile.ProfileLoadEvent
local ProfileService = playerProfileFolder.ProfileService
local AxeShopCatalog = require(game.ServerScriptService.Economy.AxeShopCatalog)

local PlayerProfileCache = {}

local Profiles: { [Player]: any } = {}

local function isNonnegativeInteger(value)
	return type(value) == "number"
		and value == value
		and value >= 0
		and value < math.huge
		and value % 1 == 0
end

local function normalizeProgressionData(data)
	if type(data.AxeHeads) ~= "table" then
		data.AxeHeads = {}
	end
	for headId, count in pairs(data.AxeHeads) do
		if type(headId) ~= "string" or not isNonnegativeInteger(count) then
			data.AxeHeads[headId] = nil
		end
	end
	for _, head in ipairs(AxeShopCatalog.AxeHeads) do
		if data.AxeHeads[head.Id] == nil then
			data.AxeHeads[head.Id] = 0
		end
	end

	if type(data.RunProgress) ~= "table" then
		data.RunProgress = {}
	end
	local runProgress = data.RunProgress
	if not isNonnegativeInteger(runProgress.StandardAxeTier) then
		runProgress.StandardAxeTier = 0
	end
	if type(runProgress.UnlockedForests) ~= "table" then
		runProgress.UnlockedForests = {}
	end
	local unlockedForests = runProgress.UnlockedForests
	-- The base and first forest are the entry point for every valid profile.
	unlockedForests.Base = true
	unlockedForests.Forest1 = true
	if unlockedForests.Forest2 == nil or type(unlockedForests.Forest2) ~= "boolean" then
		unlockedForests.Forest2 = false
	end
	for forestId, unlocked in pairs(unlockedForests) do
		if type(forestId) ~= "string" or type(unlocked) ~= "boolean" then
			unlockedForests[forestId] = nil
		end
	end
end

export type PlayerProfileCache = {
	Set: (player: Player, profile: profileType.PlayerData) -> (),
	Get: (player: Player) -> (profileType.PlayerData),
	Remove: (player: Player) -> (),
	FireLoaded: (profile: profileType.PlayerData) -> ()
}

local function BuildRuntime(profile)
	local runtime = {
		Weapon = {},
		Pet = {},
		Seed= {},
		FinalStats= {}
	}
	profile.Data.Runtime = runtime
end

function PlayerProfileCache.Set(player: Player, profile)
	if profile and type(profile.Data) == "table" then
		normalizeProgressionData(profile.Data)
	end
	BuildRuntime(profile)
	Profiles[player] = profile
end

-- Get full profile
function PlayerProfileCache.GetProfile(player: Player)
	return Profiles[player]
end

-- Get typed data only (autocomplete!)
function PlayerProfileCache.GetData(player: Player): profileType.PlayerData?
	local profile = Profiles[player]
	if not profile then return nil end
	return profile.Data :: profileType.PlayerData
end

-- Build RunTimeCache


-- Cleanup
function PlayerProfileCache.Remove(player: Player)
	Profiles[player] = nil
end


return PlayerProfileCache
