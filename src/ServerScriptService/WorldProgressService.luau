-- Server interface over profile-backed current-run forest progression.
-- Rebirth can reset RunProgress without deriving access from player position.
local Players = game:GetService("Players")
local ProfileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local ItemDataBase = require(game.ServerStorage.Items.ItemDataBase)
local AxeShopCatalog = require(game.ServerScriptService.Economy.AxeShopCatalog)

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

local function isNonnegativeInteger(value)
	return type(value) == "number"
		and value == value
		and value >= 0
		and value < math.huge
		and value % 1 == 0
end

-- Runtime equipment is the source of truth for combat and barrier access. The
-- server-created Tool reference prevents a matching name or client-side
-- attribute from establishing an equipped weapon on its own.
function WorldProgressService.GetEquippedRuntimeWeapon(player)
	if not isCurrentPlayer(player) then return nil end
	local data = ProfileCache.GetData(player)
	if type(data) ~= "table" or type(data.Runtime) ~= "table" then return nil end
	local runtime = data.Runtime
	local uid = runtime.EquippedWeaponUID
	if type(uid) ~= "string" or #uid < 1 then return nil end
	local weapon = type(runtime.Weapon) == "table" and runtime.Weapon[uid] or nil
	if type(weapon) ~= "table"
		or weapon.ItemType ~= "Weapon"
		or weapon.ItemUID ~= uid then
		return nil
	end

	local template = ItemDataBase.Instances[weapon.ItemID]
	if not template or not template:IsA("Tool") or weapon.InstanceName ~= template.Name then return nil end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local tool = runtime.EquippedWeaponTool
	if not character or not humanoid or humanoid.Health <= 0 then return nil end
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") or tool.Parent ~= character then return nil end
	if tool.Name ~= template.Name
		or tool:GetAttribute("EquippedAxe") ~= true
		or tool:GetAttribute("AxeItemUID") ~= uid then
		return nil
	end
	return weapon, uid, tool
end

function WorldProgressService.CanUseEquippedAxeTier(player, requiredTier)
	if not isNonnegativeInteger(requiredTier) then return false end
	local weapon = WorldProgressService.GetEquippedRuntimeWeapon(player)
	if not weapon then return false end
	local currentTier = AxeShopCatalog.ResolveAxeTier(weapon)
	return isNonnegativeInteger(currentTier) and currentTier >= requiredTier
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
		and not WorldProgressService.CanUseEquippedAxeTier(player, requiredTier) then
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
