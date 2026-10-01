local profileType = require(script.Parent.DefaultPlayerData)
local playerProfileFolder = game.ServerScriptService.PlayerProfile
local profileBindableEvent = playerProfileFolder.ProfileInit.ProfileLoadedEvent
local profileRemoteEvent = game.ReplicatedStorage.Profile.ProfileLoadEvent
local ProfileService = playerProfileFolder.ProfileService

local PlayerProfileCache = {}

local Profiles: { [Player]: any } = {}

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
