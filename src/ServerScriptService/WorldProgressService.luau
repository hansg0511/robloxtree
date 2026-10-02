-- Temporary server-only progression seam. Forest unlock persistence and barrier
-- behavior deliberately belong to the later vertical slice.
local Players = game:GetService("Players")

local WorldProgressService = {}

local DEFAULT_FOREST_ACCESS = {
	Base = true,
	Forest1 = true,
}

local unlockedForestsByPlayer = {}

local function isCurrentPlayer(player)
	return typeof(player) == "Instance"
		and player:IsA("Player")
		and player:IsDescendantOf(Players)
end

function WorldProgressService.CanAccessForest(player, forestId)
	if not isCurrentPlayer(player) or type(forestId) ~= "string" or forestId == "" then
		return false
	end
	if DEFAULT_FOREST_ACCESS[forestId] then return true end
	return unlockedForestsByPlayer[player] and unlockedForestsByPlayer[player][forestId] == true or false
end

function WorldProgressService.UnlockForest(player, forestId)
	if not isCurrentPlayer(player) or type(forestId) ~= "string" or forestId == "" then
		return false
	end
	local unlocked = unlockedForestsByPlayer[player]
	if not unlocked then
		unlocked = {}
		unlockedForestsByPlayer[player] = unlocked
	end
	unlocked[forestId] = true
	return true
end

function WorldProgressService.CanInteractWithTree(player, tree)
	if type(tree) ~= "table" then return false end
	return WorldProgressService.CanAccessForest(player, tree.ForestId or "Base")
end

function WorldProgressService.ClearPlayer(player)
	unlockedForestsByPlayer[player] = nil
end

Players.PlayerRemoving:Connect(WorldProgressService.ClearPlayer)

return WorldProgressService
