-- Server interface over profile-backed current-run forest progression.
-- Rebirth can reset RunProgress without deriving access from player position.
local Players = game:GetService("Players")
local ProfileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)

local WorldProgressService = {}

local DEFAULT_FOREST_ACCESS = {
	Base = true,
	Forest1 = true,
}

local KNOWN_FORESTS = {
	Base = true,
	Forest1 = true,
	Forest2 = true,
}

local function isCurrentPlayer(player)
	return typeof(player) == "Instance"
		and player:IsA("Player")
		and player:IsDescendantOf(Players)
end

local function getRunProgress(player)
	if not isCurrentPlayer(player) then return nil end
	local data = ProfileCache.GetData(player)
	if type(data) ~= "table" then return nil end
	if type(data.RunProgress) ~= "table" then
		data.RunProgress = {
			StandardAxeTier = 0,
			UnlockedForests = { Base = true, Forest1 = true, Forest2 = false },
		}
	end
	local runProgress = data.RunProgress
	if type(runProgress.UnlockedForests) ~= "table" then
		runProgress.UnlockedForests = { Base = true, Forest1 = true, Forest2 = false }
	end
	return runProgress
end

function WorldProgressService.CanAccessForest(player, forestId)
	if type(forestId) ~= "string" or not KNOWN_FORESTS[forestId] then
		return false
	end
	local runProgress = getRunProgress(player)
	if not runProgress then return false end
	if DEFAULT_FOREST_ACCESS[forestId] then return true end
	return runProgress.UnlockedForests[forestId] == true
end

function WorldProgressService.UnlockForest(player, forestId)
	if type(forestId) ~= "string" or not KNOWN_FORESTS[forestId] then
		return false
	end
	local runProgress = getRunProgress(player)
	if not runProgress then return false end
	runProgress.UnlockedForests[forestId] = true
	return true
end

function WorldProgressService.CanUseStandardAxeTier(player, requiredTier)
	if type(requiredTier) ~= "number"
		or requiredTier ~= requiredTier
		or requiredTier < 0
		or requiredTier % 1 ~= 0
		or requiredTier == math.huge then
		return false
	end
	local runProgress = getRunProgress(player)
	if not runProgress then return false end
	local currentTier = runProgress.StandardAxeTier
	return type(currentTier) == "number"
		and currentTier == currentTier
		and currentTier >= 0
		and currentTier % 1 == 0
		and currentTier >= requiredTier
		and currentTier < math.huge
end

function WorldProgressService.CanInteractWithTree(player, tree)
	if type(tree) ~= "table" then return false end
	if not WorldProgressService.CanAccessForest(player, tree.ForestId or "Base") then
		return false
	end
	local requiredTier = tree.RequiredStandardAxeTier
	if requiredTier ~= nil
		and not WorldProgressService.CanUseStandardAxeTier(player, requiredTier) then
		return false
	end
	return true
end

-- Progress is held by the profile, so there is no per-player cache to retain
-- across leave/rejoin. This method remains for callers that already use it.
function WorldProgressService.ClearPlayer(_player)
	return nil
end

return WorldProgressService
