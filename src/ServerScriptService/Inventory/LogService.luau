-- Server-authoritative unique log inventory, ground pickups, and selling.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ProfileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local EconomyManager = require(game.ServerScriptService.Economy.EconomyManager)
local AxeShopCatalog = require(game.ServerScriptService.Economy.AxeShopCatalog)
local MaterialDefinitions = require(game.ServerScriptService.Economy.MaterialDefinitions)
local SpeciesVisuals = require(game.ServerStorage:WaitForChild("SpeciesVisuals"))
local BaseStationAccess = require(game.ServerScriptService.WorldLayout.BaseStationAccess)
local LogCarryVisualService = require(game.ServerScriptService.Inventory.LogCarryVisualService)

local LogService = {}
local logsChangedEvent = Instance.new("BindableEvent")
LogService.LogsChanged = logsChangedEvent.Event

local DEFAULT_CAPACITY_KG = AxeShopCatalog.DEFAULT_CAPACITY_KG
local MAX_CAPACITY_KG = AxeShopCatalog.MAX_CAPACITY_KG
-- This physical-record ceiling is independent of weight. 40 kg supports up to
-- 80 Bamboo records at 0.5 kg each; spare room keeps the limit forward-safe.
local MAX_OWNED_LOGS = 96
local MAX_HARVEST_LOGS = 6
local MAX_STANDARD_TREE_LOGS = 3
-- Uncollected rewards are bounded by model count, not the player's kg bag.
local MAX_GROUND_LOG_DROPS_PER_PLAYER = 96
local OWNER_RESERVATION_SECONDS = 60
-- Overflow is deliberately short-lived. The owner has the full lifetime to
-- free a slot and recover the exact UID; it is not converted into a public
-- loot race after the reservation expires.
local GROUND_LOG_LIFETIME_SECONDS = 60
local PILE_LIFETIME_1_LOG_SECONDS = 15
local PILE_LIFETIME_2_LOGS_SECONDS = 25
local PILE_LIFETIME_3_TO_5_LOGS_SECONDS = 45
local PILE_LIFETIME_6_TO_12_LOGS_SECONDS = 75
local PILE_LIFETIME_13_PLUS_LOGS_SECONDS = 120
local MAX_PICKUP_DISTANCE = 15
-- Maximum physical records processed per request, independent of kg capacity.
local MAX_PICKUP_BATCH = 24
local CAPACITY_TOLERANCE_KG = 1e-5
local PICKUP_POP_DURATION = 0.10
local PICKUP_HOMING_SPEED = 24
local PICKUP_HOMING_UPDATE_RATE = 15
local PICKUP_HOMING_UPDATE_INTERVAL = 1 / PICKUP_HOMING_UPDATE_RATE
local PICKUP_HOMING_ARRIVAL_RADIUS = 2.5
local PICKUP_HOMING_TIMEOUT = 20
local OVERFLOW_PILE_COMMIT_DELAY = 0.35
local CARRY_FINAL_SETTLE_DURATION = 0.16
local OVERFLOW_FINAL_SETTLE_DURATION = 0.28
local GROUND_LOG_REVEAL_DURATION = 0.36
local GROUND_LOG_REVEAL_ARC_HEIGHT = 2.5
local GROUND_LOG_READABLE_PAUSE = 0.2
local OVERFLOW_MERGE_RADIUS = 24
local OVERFLOW_PLAYER_SIDE_OFFSET = 2.8
local OVERFLOW_PLAYER_BACK_OFFSET = 2.0
local PILE_LOGS_PER_LAYER = 12
local PILE_COLUMNS_PER_ROW = 3
local PILE_ROW_LENGTH_FACTOR = 0.48
local PILE_COLUMN_DIAMETER_FACTOR = 1.08
local PILE_LAYER_HEIGHT_FACTOR = 0.70
local PILE_SLOT_GAP = 0.08
local PILE_SLOT_YAW_VARIATION = 0.025
-- Keep pickup rejection diagnostics quiet in normal play. Enable temporarily
-- when investigating why a server rejected a ground-log pickup request.
local DEBUG_GROUND_PICKUP_DIAGNOSTICS = false
local DEBUG_PICKUP_HOMING = false
local DEBUG_PILE_LIFETIME = false
local DEBUG_PILE_TIMER = true
local DEBUG_PILE_RADIUS = true
local PILE_RADIUS_DEBUG_SEGMENT_COUNT = 32
local PILE_RADIUS_DEBUG_HEIGHT_OFFSET = 0.08
-- Ground geometry is an exact fourfold copy of the carry/back-stack geometry.
-- This is a visual-only scale; it never affects inventory or log value.
local GROUND_DROP_VISUAL_SCALE = 4
local REMOTE_INTERVALS = {
	Sell = 1,
	Lock = 0.15,
	Pickup = 0.08,
}

local economyRemotes = ReplicatedStorage:WaitForChild("Economy")
local GetLogsDataRF = economyRemotes:WaitForChild("GetLogsDataRF")
local GetSellSummaryRF = economyRemotes:WaitForChild("GetSellSummaryRF")
local SellUnlockedLogsRE = economyRemotes:WaitForChild("SellUnlockedLogsRE")
local SetLogLockedRE = economyRemotes:WaitForChild("SetLogLockedRE")
local PickupGroundLogRE = economyRemotes:WaitForChild("PickupGroundLogRE")
local PickupLogFXRE = economyRemotes:WaitForChild("PickupLogFXRE")
local EconomyStateUpdated = economyRemotes:WaitForChild("EconomyStateUpdated")

local profileLoaded = game.ServerScriptService.PlayerProfile.ProfileInit.ProfileLoadedEvent
local activeGroundDrops = {}
local pendingGroundDropByUserId = {}
-- Server-only ownership and layout index. Ground entries remain the source of
-- truth; these pile maps only group their UIDs into stable species-specific slots.
local pilesByPlayer = {}
local pileTimerUpdaterStarted = false
local remoteBudgetByPlayer = {}
local pendingCarryArrivalUids = {}
local deferredCarryRecords = {}
-- One bounded registry owns server-side logical motion and resolution state.
-- Client cosmetics follow the same speed but never choose an outcome or target.
local pickupHomingsByUid = {}
local homingUpdateAccumulator = 0
local MAX_HOMING_PICKUPS_PER_PLAYER = MAX_OWNED_LOGS + MAX_GROUND_LOG_DROPS_PER_PLAYER
local recoverOverflowHoming
local cancelPickupHoming
local scheduleGroundDropExpiry
local refreshPileExpiry
local schedulePileExpiry
local expireOverflowPile
local isRegisteredPile

local function isFinitePositive(number)
	return type(number) == "number"
		and number == number
		and number > 0
		and number < math.huge
end

local function isValidUid(uid)
	return type(uid) == "string" and #uid > 0 and #uid <= 80
end

local function debugPickupRejection(player, uid, reason)
	if not DEBUG_GROUND_PICKUP_DIAGNOSTICS then return end
	local playerLabel = if player then string.format("%s (%d)", player.Name, player.UserId) else "<unknown>"
	print(string.format(
		"[LogService] Ground pickup rejected: %s; player=%s; uid=%s",
		reason,
		playerLabel,
		tostring(uid)
	))
end

local function debugPickupHoming(action, uid, detail)
	if not DEBUG_PICKUP_HOMING then return end
	local suffix = if detail and detail ~= "" then " " .. detail else ""
	print(string.format("[PickupHoming] %s uid=%s%s", action, tostring(uid), suffix))
end

local function getPileLifetimeSeconds(itemCount)
	if itemCount <= 1 then
		return PILE_LIFETIME_1_LOG_SECONDS
	elseif itemCount == 2 then
		return PILE_LIFETIME_2_LOGS_SECONDS
	elseif itemCount <= 5 then
		return PILE_LIFETIME_3_TO_5_LOGS_SECONDS
	elseif itemCount <= 12 then
		return PILE_LIFETIME_6_TO_12_LOGS_SECONDS
	end
	return PILE_LIFETIME_13_PLUS_LOGS_SECONDS
end

local function debugPileLifetime(action, pile, detail)
	if not DEBUG_PILE_LIFETIME then return end
	local suffix = if detail and detail ~= "" then " " .. detail else ""
	print(string.format(
		"[PileLifetime] %s pile=%s count=%d%s",
		action,
		tostring(pile.PileId),
		pile.ItemCount,
		suffix
	))
end

local function isFiniteVector3(value)
	return typeof(value) == "Vector3"
		and value.X == value.X and value.Y == value.Y and value.Z == value.Z
		and math.abs(value.X) < math.huge
		and math.abs(value.Y) < math.huge
		and math.abs(value.Z) < math.huge
end

local function countPlayerHomingPickups(player)
	local count = 0
	for _, pickup in pairs(pickupHomingsByUid) do
		if pickup.Player == player then count += 1 end
	end
	return count
end

local function copyMutations(mutations)
	local result = {}
	if type(mutations) == "table" then
		for key, mutation in pairs(mutations) do
			if type(key) == "string"
				and (type(mutation) == "string" or type(mutation) == "number" or type(mutation) == "boolean") then
				result[key] = mutation
			end
		end
	end
	return result
end

local function normalizeLogRecord(logRecord, seenUids)
	if type(logRecord) ~= "table"
		or (logRecord.ItemType ~= nil and logRecord.ItemType ~= "Log")
		or type(logRecord.SpeciesId) ~= "string"
		or #logRecord.SpeciesId == 0
		or #logRecord.SpeciesId > 80 then
		return nil
	end

	local speciesId = logRecord.SpeciesId
	local uid = logRecord.UID
	if not isValidUid(uid) or seenUids[uid] then
		uid = HttpService:GenerateGUID(false)
	end
	seenUids[uid] = true

	local createdAt = logRecord.CreatedAt
	if type(createdAt) ~= "number" or createdAt ~= createdAt or math.abs(createdAt) == math.huge then
		createdAt = 0
	end
	local locked = logRecord.Locked == true

	-- Rewrite in place so legacy WeightKg/SizeScale and stale fields disappear
	-- from the profile without replacing the owned record itself.
	local mutations = copyMutations(logRecord.Mutations)
	table.clear(logRecord)
	logRecord.UID = uid
	logRecord.ItemType = "Log"
	logRecord.SpeciesId = speciesId
	logRecord.Mutations = mutations
	logRecord.Locked = locked
	logRecord.CreatedAt = createdAt
	return logRecord
end

local function normalizeLogs(data)
	local sourceLogs = type(data.Logs) == "table" and data.Logs or {}
	local normalizedLogs = {}
	local seenUids = {}
	for _, logRecord in ipairs(sourceLogs) do
		local normalizedRecord = normalizeLogRecord(logRecord, seenUids)
		if normalizedRecord then
			table.insert(normalizedLogs, normalizedRecord)
		end
	end
	data.Logs = normalizedLogs
end

local function getPlayerData(player)
	local profile = ProfileCache.GetProfile(player)
	if not profile or type(profile.Data) ~= "table" then return nil end
	normalizeLogs(profile.Data)
	ProfileCache.NormalizeCarryCapacity(profile.Data)
	if type(profile.Data.Coins) ~= "number"
		or profile.Data.Coins ~= profile.Data.Coins
		or profile.Data.Coins < 0
		or profile.Data.Coins == math.huge then
		profile.Data.Coins = 0
	end
	return profile.Data
end

local function getMaterialDefinition(speciesId)
	local definition = MaterialDefinitions.Get(speciesId)
	if not definition
		or not isFinitePositive(definition.CapacityKg)
		or not isFinitePositive(definition.SellValue)
		or not isFinitePositive(definition.CarryVisualScale) then
		return nil
	end
	return definition
end

local function getLogValue(logRecord)
	if type(logRecord) ~= "table" or logRecord.ItemType ~= "Log" then return nil end
	local definition = getMaterialDefinition(logRecord.SpeciesId)
	return definition and definition.SellValue or nil
end

local function getRecordCapacityKg(logRecord)
	if type(logRecord) ~= "table" or logRecord.ItemType ~= "Log" then return nil end
	local definition = getMaterialDefinition(logRecord.SpeciesId)
	local capacityKg = definition and definition.CapacityKg
	if not isFinitePositive(capacityKg) then return nil end
	return capacityKg
end

-- Unknown species make the bag full until the server knows their fixed cost.
-- This lets old/corrupt records remain visible without ever becoming free.
local function calculateCapacityMetrics(data)
	local capacityKg = ProfileCache.NormalizeCarryCapacity(data)
	local usedKg = 0
	local hasUnknownMaterial = false
	for _, logRecord in ipairs(data.Logs) do
		local logCapacityKg = getRecordCapacityKg(logRecord)
		if logCapacityKg then
			usedKg += logCapacityKg
		else
			hasUnknownMaterial = true
		end
	end
	if hasUnknownMaterial then
		usedKg = math.max(capacityKg, usedKg)
	end
	local remainingKg = if hasUnknownMaterial then 0 else math.max(0, capacityKg - usedKg)
	return {
		ItemCount = #data.Logs,
		UsedKg = usedKg,
		CarryCapacityKg = capacityKg,
		RemainingKg = remainingKg,
		HasUnknownMaterial = hasUnknownMaterial,
	}
end

-- Piled models are considered by AutoPickup only when one item can currently
-- fit. This replicated attribute is a request gate, never the server's final
-- capacity decision. Refreshes run only after inventory/capacity mutations.
local function refreshPiledLogPickupEligibility(player, data)
	local ownerPiles = pilesByPlayer[player.UserId]
	if not ownerPiles then return end
	data = data or getPlayerData(player)
	local metrics = data and calculateCapacityMetrics(data) or nil
	for _, pile in pairs(ownerPiles) do
		for uid, entry in pairs(pile.ItemsByUid) do
			if entry.State ~= "Piled" then
				continue
			end
			local capacityKg = getRecordCapacityKg(entry.LogRecord)
			local active = entry.OwnerUserId == player.UserId
				and entry.PileId == pile.PileId
				and entry.Drop ~= nil
				and activeGroundDrops[entry.Bundle] == entry.Drop
				and entry.Drop.LogRecordsByUid[uid] == entry
				and entry.Model ~= nil
				and entry.Model.Parent == entry.Bundle
			local enabled = active
				and metrics ~= nil
				and not metrics.HasUnknownMaterial
				and #data.Logs < MAX_OWNED_LOGS
				and capacityKg ~= nil
				and metrics.RemainingKg + CAPACITY_TOLERANCE_KG >= capacityKg
			if entry.PickupEnabled ~= enabled then
				entry.PickupEnabled = enabled
				if active then
					entry.Model:SetAttribute("PickupEnabled", enabled)
				end
			end
		end
	end
end

local function makeClientSnapshot(player)
	local data = getPlayerData(player)
	if not data then return nil end

	local logs = {}
	for _, logRecord in ipairs(data.Logs) do
		if isValidUid(logRecord.UID) then
			local value = getLogValue(logRecord) or 0
			local materialCapacityKg = getRecordCapacityKg(logRecord)
			table.insert(logs, {
				UID = logRecord.UID,
				ItemType = "Log",
				SpeciesId = logRecord.SpeciesId,
				Mutations = copyMutations(logRecord.Mutations),
				Locked = logRecord.Locked == true,
				CreatedAt = type(logRecord.CreatedAt) == "number" and logRecord.CreatedAt or 0,
				LogValue = value,
				EstimatedSellValue = value,
				-- Derived from server-owned species config for display only; never read
				-- back as an authoritative per-record weight.
				CapacityKg = materialCapacityKg,
			})
		end
	end

	local capacityMetrics = calculateCapacityMetrics(data)
	return {
		Logs = logs,
		ItemCount = capacityMetrics.ItemCount,
		UsedKg = capacityMetrics.UsedKg,
		CarryCapacityKg = capacityMetrics.CarryCapacityKg,
		RemainingKg = capacityMetrics.RemainingKg,
		HasUnknownMaterial = capacityMetrics.HasUnknownMaterial,
		Coins = data.Coins,
	}
end

function LogService.GetCapacitySnapshot(player)
	local data = getPlayerData(player)
	if not data then return nil end
	local metrics = calculateCapacityMetrics(data)
	return {
		ItemCount = metrics.ItemCount,
		UsedKg = metrics.UsedKg,
		CarryCapacityKg = metrics.CarryCapacityKg,
		RemainingKg = metrics.RemainingKg,
		HasUnknownMaterial = metrics.HasUnknownMaterial,
		Coins = data.Coins,
	}
end

-- Returns sanitized copies for server systems such as the back-cargo renderer.
-- Callers cannot mutate the authoritative profile records through this API.
function LogService.GetOwnedLogs(player)
	local snapshot = makeClientSnapshot(player)
	return snapshot and snapshot.Logs or nil
end

local function isStandardCraftLog(logRecord, speciesId)
	if type(logRecord) ~= "table"
		or logRecord.ItemType ~= "Log"
		or logRecord.SpeciesId ~= speciesId
		or (logRecord.Locked ~= nil and logRecord.Locked ~= false)
		or not isValidUid(logRecord.UID) then
		return false
	end
	local mutations = logRecord.Mutations
	return mutations == nil or (type(mutations) == "table" and next(mutations) == nil)
end

-- Server-only crafting seam. It returns only unlocked, normal wood and hides
-- logs whose pickup-to-carry cosmetic has not completed yet.
function LogService.GetCraftableLogUIDs(player, speciesId, count)
	if type(speciesId) ~= "string" or #speciesId == 0
		or type(count) ~= "number" or count % 1 ~= 0 or count < 1 then
		return nil
	end
	local data = getPlayerData(player)
	if not data then return nil end
	local pendingUids = pendingCarryArrivalUids[player]
	local selectedUids = {}
	local seenUids = {}
	for _, logRecord in ipairs(data.Logs) do
		local uid = logRecord.UID
		if isStandardCraftLog(logRecord, speciesId)
			and not (pendingUids and pendingUids[uid])
			and not seenUids[uid] then
			seenUids[uid] = true
			table.insert(selectedUids, uid)
			if #selectedUids == count then
				return selectedUids
			end
		end
	end
	return nil
end

function LogService.CountCraftableLogs(player, speciesId)
	if type(speciesId) ~= "string" or #speciesId == 0 then return 0 end
	local data = getPlayerData(player)
	if not data then return 0 end
	local pendingUids = pendingCarryArrivalUids[player]
	local count = 0
	local seenUids = {}
	for _, logRecord in ipairs(data.Logs) do
		local uid = logRecord.UID
		if isStandardCraftLog(logRecord, speciesId)
			and not (pendingUids and pendingUids[uid])
			and not seenUids[uid] then
			seenUids[uid] = true
			count += 1
		end
	end
	return count
end

-- Revalidates and removes the exact server-selected UIDs without publishing a
-- UI update. The caller must immediately commit the output or restore this list;
-- this small transaction intentionally contains no yielding calls.
function LogService.TakeCraftableLogUIDs(player, speciesId, logUids)
	if type(speciesId) ~= "string" or #speciesId == 0
		or type(logUids) ~= "table" or #logUids == 0 then
		return nil
	end
	local data = getPlayerData(player)
	if not data then return nil end
	local pendingUids = pendingCarryArrivalUids[player]
	local requested = {}
	for _, uid in ipairs(logUids) do
		if not isValidUid(uid) or requested[uid] then return nil end
		requested[uid] = true
	end
	local foundByUid = {}
	local requestedOccurrences = {}
	for _, logRecord in ipairs(data.Logs) do
		local uid = logRecord.UID
		if requested[uid] then
			requestedOccurrences[uid] = (requestedOccurrences[uid] or 0) + 1
			-- A malformed duplicate UID must never make one selected UID consume
			-- multiple records or make rollback lose track of the original records.
			if requestedOccurrences[uid] > 1 then return nil end
			if not isStandardCraftLog(logRecord, speciesId)
				or (pendingUids and pendingUids[uid]) then
				return nil
			end
			foundByUid[uid] = logRecord
		end
	end
	local removedRecords = {}
	for _, uid in ipairs(logUids) do
		local logRecord = foundByUid[uid]
		if not logRecord then return nil end
		table.insert(removedRecords, logRecord)
	end

	for index = #data.Logs, 1, -1 do
		if requested[data.Logs[index].UID] then
			table.remove(data.Logs, index)
		end
	end
	return removedRecords
end

-- Restores the original authoritative records after an output insertion fails.
-- It is intentionally silent; the caller publishes only the final transaction.
function LogService.RestoreCraftableLogRecords(player, records)
	if type(records) ~= "table" or #records == 0 then return false end
	local data = getPlayerData(player)
	if not data then return false end
	local existingUids = {}
	for _, logRecord in ipairs(data.Logs) do
		if type(logRecord) == "table" then
			existingUids[logRecord.UID] = true
		end
	end
	local restoredUids = {}
	for _, logRecord in ipairs(records) do
		if type(logRecord) ~= "table"
			or logRecord.ItemType ~= "Log"
			or not isValidUid(logRecord.UID)
			or existingUids[logRecord.UID]
			or restoredUids[logRecord.UID] then
			return false
		end
		restoredUids[logRecord.UID] = true
	end
	for _, logRecord in ipairs(records) do
		table.insert(data.Logs, logRecord)
	end
	return true
end

function LogService.ConsumeCraftableLogUIDs(player, speciesId, logUids)
	local removedRecords = LogService.TakeCraftableLogUIDs(player, speciesId, logUids)
	if not removedRecords then return false end
	LogService.NotifyState(player)
	return true
end

local function makeSellSummary(player)
	local data = getPlayerData(player)
	if not data then return nil end

	local eligibleCount = 0
	local totalValue = 0
	for _, logRecord in ipairs(data.Logs) do
		local value = getLogValue(logRecord)
		if value and logRecord.Locked ~= true then
			eligibleCount += 1
			totalValue += value
		end
	end

	local capacityMetrics = calculateCapacityMetrics(data)
	return {
		EligibleCount = eligibleCount,
		TotalValue = totalValue,
		Coins = data.Coins,
		ItemCount = capacityMetrics.ItemCount,
		UsedKg = capacityMetrics.UsedKg,
		CarryCapacityKg = capacityMetrics.CarryCapacityKg,
		RemainingKg = capacityMetrics.RemainingKg,
		HasUnknownMaterial = capacityMetrics.HasUnknownMaterial,
	}
end

function LogService.NotifyState(player)
	local data = getPlayerData(player)
	if data then
		refreshPiledLogPickupEligibility(player, data)
	end
	local snapshot = makeClientSnapshot(player)
	if snapshot and player:IsDescendantOf(Players) then
		logsChangedEvent:Fire(player, snapshot.Logs)
		EconomyStateUpdated:FireClient(player, snapshot)
	end
	return snapshot
end

local function rebuildCarryVisuals(player, records)
	if player:IsDescendantOf(Players) then
		LogCarryVisualService.RebuildCarryVisuals(player, records)
	end
end

local function getVisibleCarryRecords(player, includePendingUid)
	local records = LogService.GetOwnedLogs(player)
	if not records then return nil end

	local pendingUids = pendingCarryArrivalUids[player]
	if not pendingUids then return records end

	local visibleRecords = {}
	for _, logRecord in ipairs(records) do
		if not pendingUids[logRecord.UID] or logRecord.UID == includePendingUid then
			table.insert(visibleRecords, logRecord)
		end
	end
	return visibleRecords
end

LogService.LogsChanged:Connect(function(player, records)
	local pendingUids = pendingCarryArrivalUids[player]
	if pendingUids and next(pendingUids) ~= nil then
		deferredCarryRecords[player] = records
		return
	end
	rebuildCarryVisuals(player, records)
end)

local function findLog(data, uid)
	for index, logRecord in ipairs(data.Logs) do
		if type(logRecord) == "table" and logRecord.UID == uid and logRecord.ItemType == "Log" then
			return logRecord, index
		end
	end
	return nil
end

local function logCount(data)
	return #data.Logs
end

local function consumeRemoteBudget(player, action)
	local now = os.clock()
	local budget = remoteBudgetByPlayer[player]
	if not budget then
		budget = {}
		remoteBudgetByPlayer[player] = budget
	end
	if now < (budget[action] or 0) then return false end
	budget[action] = now + REMOTE_INTERVALS[action]
	return true
end

function LogService.CanSellAtBase(player)
	return BaseStationAccess.CanUseLumberDepot(player)
end

local function getGroundDropFolder()
	local folder = Workspace:FindFirstChild("WorldLogDrops")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "WorldLogDrops"
		folder.Parent = Workspace
	end
	return folder
end

local function cleanupDisabledPileTimerDebugAnchors()
	if DEBUG_PILE_TIMER then return end

	local folder = Workspace:FindFirstChild("WorldLogDrops")
	if not folder or not folder:IsA("Folder") then return end

	-- Timer anchors are direct children of WorldLogDrops. Match the explicit tag
	-- used by new anchors and the old distinctive name so a hot reload also cleans
	-- anchors created before the tag existed, without scanning normal drop models.
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart")
			and (child:GetAttribute("DebugPileTimerAnchor") == true or child.Name == "PileTimerDebugAnchor") then
			child:Destroy()
		end
	end
end

cleanupDisabledPileTimerDebugAnchors()

local function cleanupDisabledPileRadiusDebugModels()
	if DEBUG_PILE_RADIUS then return end

	local folder = Workspace:FindFirstChild("WorldLogDrops")
	if not folder or not folder:IsA("Folder") then return end

	-- Radius rings are direct child Models with an explicit marker.
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model")
			and child:GetAttribute("DebugPileRadiusModel") == true then
			child:Destroy()
		end
	end
end

cleanupDisabledPileRadiusDebugModels()

local function formatPileTimerCountdown(seconds)
	local wholeSeconds = math.floor(math.max(0, seconds))
	local minutes = math.floor(wholeSeconds / 60)
	local remainingSeconds = wholeSeconds % 60
	return string.format("%02d:%02d", minutes, remainingSeconds)
end

local function getPileTimerAnchorHeight(pile)
	local material = getMaterialDefinition(pile.SpeciesId)
	if not material then return nil end

	local visualScale = math.clamp(material.CarryVisualScale, 0.05, 4) * GROUND_DROP_VISUAL_SCALE
	local logDiameter = 0.48 * visualScale
	local highestLayerIndex = math.floor((pile.ItemCount - 1) / PILE_LOGS_PER_LAYER)
	local pileTop = logDiameter * 0.5 + 0.08
		+ highestLayerIndex * logDiameter * PILE_LAYER_HEIGHT_FACTOR
		+ logDiameter * 0.5
	-- Add clear space above the tallest geometry-based layer so the readout does
	-- not sit on the pile or follow an individual log model.
	return pileTop + 3
end

local function updatePileTimerDebug(pile)
	if not DEBUG_PILE_TIMER
		or not isRegisteredPile(pile)
		or pile.ItemCount <= 0
		or type(pile.ExpiresAt) ~= "number"
		or not pile.DebugPileTimerLabel
		or not pile.DebugPileTimerAnchor then
		return
	end
	local height = getPileTimerAnchorHeight(pile)
	if height then
		pile.DebugPileTimerAnchor.CFrame = pile.OriginCFrame * CFrame.new(0, height, 0)
	end

	local lifetimeTier = getPileLifetimeSeconds(pile.ItemCount)
	local logText = if pile.ItemCount == 1
		then "1 log"
		else string.format("%d logs", pile.ItemCount)
	pile.DebugPileTimerLabel.Text = string.format(
		"%s\n%s\nTier: %ds",
		logText,
		formatPileTimerCountdown(pile.ExpiresAt - os.clock()),
		lifetimeTier
	)
end

local function updateRegisteredPileTimerDebug()
	if not DEBUG_PILE_TIMER then return end

	-- Snapshot references first, then revalidate each one before touching it. Pile
	-- expiry/removal callbacks may invalidate registry entries between updates.
	local registeredPiles = {}
	for _, ownerPiles in pairs(pilesByPlayer) do
		for _, pile in pairs(ownerPiles) do
			table.insert(registeredPiles, pile)
		end
	end
	for _, pile in ipairs(registeredPiles) do
		if isRegisteredPile(pile) then
			updatePileTimerDebug(pile)
		end
	end
end

local function startPileTimerDebugUpdater()
	if not DEBUG_PILE_TIMER or pileTimerUpdaterStarted then return end
	pileTimerUpdaterStarted = true
	task.spawn(function()
		while DEBUG_PILE_TIMER do
			task.wait(1)
			updateRegisteredPileTimerDebug()
		end
		pileTimerUpdaterStarted = false
	end)
end

local function destroyPileTimerDebug(pile)
	local billboard = pile.DebugPileTimerBillboard
	local anchor = pile.DebugPileTimerAnchor
	pile.DebugPileTimerBillboard = nil
	pile.DebugPileTimerLabel = nil
	pile.DebugPileTimerAnchor = nil
	if billboard then billboard:Destroy() end
	if anchor then anchor:Destroy() end
end

local function ensurePileTimerDebug(pile)
	if not DEBUG_PILE_TIMER
		or not isRegisteredPile(pile)
		or pile.ItemCount <= 0
		or type(pile.ExpiresAt) ~= "number" then
		return
	end

	if pile.DebugPileTimerAnchor and pile.DebugPileTimerAnchor.Parent
		and pile.DebugPileTimerBillboard and pile.DebugPileTimerBillboard.Parent == pile.DebugPileTimerAnchor
		and pile.DebugPileTimerLabel and pile.DebugPileTimerLabel.Parent == pile.DebugPileTimerBillboard then
		updatePileTimerDebug(pile)
		startPileTimerDebugUpdater()
		return
	end
	destroyPileTimerDebug(pile)

	local anchor = Instance.new("Part")
	anchor.Name = "PileTimerDebugAnchor"
	anchor:SetAttribute("DebugPileTimerAnchor", true)
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	local height = getPileTimerAnchorHeight(pile)
	if not height then
		anchor:Destroy()
		return
	end
	anchor.CFrame = pile.OriginCFrame * CFrame.new(0, height, 0)
	anchor.Parent = getGroundDropFolder()

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PileTimerDebugBillboard"
	billboard.Adornee = anchor
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 160
	billboard.Size = UDim2.fromOffset(176, 72)
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Name = "TimerText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(28, 34, 30)
	label.BackgroundTransparency = 0.12
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(245, 255, 245)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.6
	label.TextSize = 15
	label.TextWrapped = true
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = billboard

	pile.DebugPileTimerAnchor = anchor
	pile.DebugPileTimerBillboard = billboard
	pile.DebugPileTimerLabel = label
	updatePileTimerDebug(pile)
	startPileTimerDebugUpdater()
end

local function destroyPileRadiusDebug(pile)
	local model = pile.DebugPileRadiusModel
	pile.DebugPileRadiusModel = nil
	if model then model:Destroy() end
end

local function ensurePileRadiusDebug(pile)
	if not DEBUG_PILE_RADIUS or not isRegisteredPile(pile) or pile.ItemCount <= 0 then
		return
	end

	local folder = getGroundDropFolder()
	local existingModel = pile.DebugPileRadiusModel
	if existingModel and existingModel.Parent == folder
		and existingModel:GetAttribute("DebugPileRadiusModel") == true then
		return
	end
	destroyPileRadiusDebug(pile)

	local model = Instance.new("Model")
	model.Name = "PileMergeRadiusDebug"
	model:SetAttribute("DebugPileRadiusModel", true)
	model:SetAttribute("DebugMergeRadius", OVERFLOW_MERGE_RADIUS)
	model:SetAttribute("DebugPileId", pile.PileId)

	local radius = OVERFLOW_MERGE_RADIUS
	local segmentLength = 2 * radius * math.sin(math.pi / PILE_RADIUS_DEBUG_SEGMENT_COUNT)
	local origin = pile.OriginCFrame.Position
	for index = 0, PILE_RADIUS_DEBUG_SEGMENT_COUNT - 1 do
		local angle = 2 * math.pi * index / PILE_RADIUS_DEBUG_SEGMENT_COUNT
		local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local center = origin
			+ radial * radius
			+ Vector3.new(0, PILE_RADIUS_DEBUG_HEIGHT_OFFSET, 0)

		local segment = Instance.new("Part")
		segment.Name = string.format("RadiusSegment%02d", index + 1)
		segment.Size = Vector3.new(segmentLength, 0.07, 0.10)
		segment.CFrame = CFrame.fromMatrix(center, tangent, Vector3.yAxis, tangent:Cross(Vector3.yAxis))
		segment.Anchored = true
		segment.CanCollide = false
		segment.CanTouch = false
		segment.CanQuery = false
		segment.CastShadow = false
		segment.Material = Enum.Material.Neon
		segment.Color = Color3.fromRGB(255, 92, 64)
		segment.Transparency = 0.18
		segment.Parent = model
	end

	model.Parent = folder
	pile.DebugPileRadiusModel = model
end

local function getGroundHeight(position)
	local ground = Workspace:FindFirstChild("BaseGround")
	if ground and ground:IsA("BasePart") then
		return ground.Position.Y + ground.Size.Y * 0.5
	end
	return position.Y
end

local function normalizeHorizontal(vector)
	if typeof(vector) ~= "Vector3" then return nil end
	if vector.X ~= vector.X or vector.Z ~= vector.Z
		or math.abs(vector.X) == math.huge or math.abs(vector.Z) == math.huge then
		return nil
	end
	local horizontal = Vector3.new(vector.X, 0, vector.Z)
	if horizontal.Magnitude <= 1e-4 then return nil end
	return horizontal.Unit
end

local function getPileSlotCFrame(pile, slotIndex, carryVisualScale)
	if type(slotIndex) ~= "number" or slotIndex % 1 ~= 0 or slotIndex < 1 then return nil end
	local scale = math.clamp(carryVisualScale, 0.05, 4) * GROUND_DROP_VISUAL_SCALE
	local logLength = 2.15 * scale
	local logDiameter = 0.48 * scale
	local zeroBased = slotIndex - 1
	local layerIndex = math.floor(zeroBased / PILE_LOGS_PER_LAYER)
	local inLayer = zeroBased % PILE_LOGS_PER_LAYER
	local rowIndex = math.floor(inLayer / PILE_COLUMNS_PER_ROW)
	local columnIndex = inLayer % PILE_COLUMNS_PER_ROW
	local localX = (rowIndex - 1.5) * logLength * PILE_ROW_LENGTH_FACTOR
	local localZ = (columnIndex - 1) * (logDiameter * PILE_COLUMN_DIAMETER_FACTOR + PILE_SLOT_GAP)
	-- A deterministic slight offset keeps the heap from reading as a perfect
	-- warehouse grid while preserving one stable overall pile orientation.
	local stagger = if (rowIndex + columnIndex) % 2 == 0 then 0.045 else -0.045
	local localY = logDiameter * 0.5 + 0.08 + layerIndex * logDiameter * PILE_LAYER_HEIGHT_FACTOR
	local yawStep = ((slotIndex * 37) % 7 - 3) * PILE_SLOT_YAW_VARIATION / 3
	return pile.OriginCFrame
		* CFrame.new(localX + stagger, localY, localZ)
		* CFrame.Angles(0, yawStep, 0)
end

local function getOwnerPiles(ownerUserId)
	local ownerPiles = pilesByPlayer[ownerUserId]
	if not ownerPiles then
		ownerPiles = {}
		pilesByPlayer[ownerUserId] = ownerPiles
	end
	return ownerPiles
end

isRegisteredPile = function(pile)
	local ownerPiles = pilesByPlayer[pile.OwnerUserId]
	return ownerPiles ~= nil and ownerPiles[pile.PileId] == pile
end

local function removePileFromRegistry(pile)
	pile.ExpiryGeneration = (pile.ExpiryGeneration or 0) + 1
	pile.ExpiresAt = nil
	destroyPileTimerDebug(pile)
	destroyPileRadiusDebug(pile)
	local ownerPiles = pilesByPlayer[pile.OwnerUserId]
	if ownerPiles and ownerPiles[pile.PileId] == pile then
		ownerPiles[pile.PileId] = nil
		if next(ownerPiles) == nil then
			pilesByPlayer[pile.OwnerUserId] = nil
		end
	end
end

schedulePileExpiry = function(pile, generation)
	if not isRegisteredPile(pile) or pile.ItemCount <= 0 or type(pile.ExpiresAt) ~= "number" then
		return
	end
	task.delay(math.max(0, pile.ExpiresAt - os.clock()), function()
		if pile.ExpiryGeneration ~= generation or not isRegisteredPile(pile) then return end
		if pile.ItemCount <= 0 or type(pile.ExpiresAt) ~= "number" then return end

		local now = os.clock()
		if now < pile.ExpiresAt then
			-- Delayed tasks can wake slightly early; retain this generation and
			-- schedule only the remaining portion of its authoritative deadline.
			schedulePileExpiry(pile, generation)
			return
		end
		expireOverflowPile(pile, generation)
	end)
end

refreshPileExpiry = function(pile, action, now)
	if not isRegisteredPile(pile)
		or pile.ItemCount <= 0
		or type(pile.LastAddedAt) ~= "number" then
		return false
	end

	now = now or os.clock()
	local previousExpiry = if type(pile.ExpiresAt) == "number" then pile.ExpiresAt else 0
	local proposedExpiry = now + getPileLifetimeSeconds(pile.ItemCount)
	pile.ExpiresAt = math.max(previousExpiry, proposedExpiry)
	local expiryExtended = pile.ExpiresAt > previousExpiry
	for _, entry in pairs(pile.ItemsByUid) do
		if entry and entry.PileId == pile.PileId and entry.OwnerUserId == pile.OwnerUserId then
			entry.ExpiresAt = pile.ExpiresAt
			entry.ReservedUntil = pile.ExpiresAt
			if entry.Model then
				entry.Model:SetAttribute("OwnerReservationSeconds", math.max(0, pile.ExpiresAt - now))
			end
		end
	end
	if expiryExtended then
		pile.ExpiryGeneration = (pile.ExpiryGeneration or 0) + 1
		schedulePileExpiry(pile, pile.ExpiryGeneration)
	end
	ensurePileTimerDebug(pile)
	ensurePileRadiusDebug(pile)
	debugPileLifetime(action, pile, string.format("expiresIn=%.1f", pile.ExpiresAt - now))
	return true
end

local function findCompatiblePile(ownerUserId, speciesId, position)
	local ownerPiles = pilesByPlayer[ownerUserId]
	if not ownerPiles then return nil end
	local bestPile = nil
	local bestDistance = math.huge
	for _, pile in pairs(ownerPiles) do
		if pile.SpeciesId == speciesId and pile.ItemCount > 0 then
			local distance = (pile.OriginCFrame.Position - position).Magnitude
			if distance <= OVERFLOW_MERGE_RADIUS
				and (distance < bestDistance
					or (math.abs(distance - bestDistance) <= 1e-4 and pile.PileId < bestPile.PileId)) then
				bestPile = pile
				bestDistance = distance
			end
		end
	end
	return bestPile
end

local function createPlayerPile(player, speciesId, root)
	local forward = normalizeHorizontal(root.CFrame.LookVector) or Vector3.zAxis
	local right = normalizeHorizontal(root.CFrame.RightVector) or Vector3.xAxis
	local position = root.Position + right * OVERFLOW_PLAYER_SIDE_OFFSET - forward * OVERFLOW_PLAYER_BACK_OFFSET
	position = Vector3.new(position.X, getGroundHeight(position), position.Z)
	local originCFrame = CFrame.fromMatrix(position, right, Vector3.yAxis, right:Cross(Vector3.yAxis))
	local pileId = HttpService:GenerateGUID(false)
	local createdAt = os.clock()
	local pile = {
		PileId = pileId,
		OwnerUserId = player.UserId,
		SpeciesId = speciesId,
		OriginCFrame = originCFrame,
		ItemsByUid = {},
		Slots = {},
		ItemCount = 0,
		CreatedAt = createdAt,
		LastAddedAt = createdAt,
		ExpiresAt = nil,
		ExpiryGeneration = 0,
	}
	getOwnerPiles(player.UserId)[pileId] = pile
	return pile
end

local function getOrCreateOverflowPile(player, speciesId, root)
	local nearest = findCompatiblePile(player.UserId, speciesId, root.Position)
	if nearest then return nearest end
	return createPlayerPile(player, speciesId, root)
end

local function getAvailablePileSlot(pile)
	for slotIndex = 1, MAX_GROUND_LOG_DROPS_PER_PLAYER do
		if not pile.Slots[slotIndex] then return slotIndex end
	end
	return nil
end

local function assignOverflowPileAtArrival(player, entry, root)
	local material = getMaterialDefinition(entry.LogRecord.SpeciesId)
	if not material then return nil end
	if not root or not root:IsA("BasePart") or not isFiniteVector3(root.Position) then return nil end
	local pile = getOrCreateOverflowPile(player, entry.LogRecord.SpeciesId, root)
	local slotIndex = getAvailablePileSlot(pile)
	local targetCFrame = slotIndex and getPileSlotCFrame(pile, slotIndex, material.CarryVisualScale)
	if not slotIndex or typeof(targetCFrame) ~= "CFrame" then return nil end
	local isFirstMembership = pile.ItemCount == 0

	-- Pile membership starts at the server-authoritative post-arrival commit
	-- time, after the fixed commit grace.
	entry.State = "OverflowSettling"
	entry.PileId = pile.PileId
	entry.PileSlot = slotIndex
	entry.PileTargetCFrame = targetCFrame
	entry.GroundCFrame = targetCFrame
	entry.PickupEnabled = false
	entry.Model:SetAttribute("GroundLogState", entry.State)
	entry.Model:SetAttribute("PileId", pile.PileId)
	entry.Model:SetAttribute("PileSlot", slotIndex)
	entry.Model:SetAttribute("PickupEnabled", false)
	pile.ItemsByUid[entry.LogRecord.UID] = entry
	pile.Slots[slotIndex] = entry
	pile.ItemCount += 1
	local now = os.clock()
	pile.LastAddedAt = now
	-- Invalidate the Fresh-entry timer before it can consume a member now owned
	-- by the pile lifecycle.
	entry.ExpiryGeneration = (entry.ExpiryGeneration or 0) + 1
	refreshPileExpiry(pile, if isFirstMembership then "CREATE" else "REFRESH", now)
	return pile
end

local function unregisterPileMembership(ownerUserId, uid, entry)
	local pileId = entry and entry.PileId
	if type(pileId) ~= "string" then return false end
	local ownerPiles = pilesByPlayer[ownerUserId]
	local pile = ownerPiles and ownerPiles[pileId]
	local removed = false
	if pile and pile.ItemsByUid[uid] == entry then
		pile.ItemsByUid[uid] = nil
		if pile.Slots[entry.PileSlot] == entry then
			pile.Slots[entry.PileSlot] = nil
		end
		pile.ItemCount = math.max(0, pile.ItemCount - 1)
		removed = true
		if pile.ItemCount == 0 then
			debugPileLifetime("REMOVE_EMPTY", pile)
			removePileFromRegistry(pile)
		else
			-- Shrinking is not activity. Preserve the earned deadline and let its
			-- existing generation-safe callback remain authoritative.
			debugPileLifetime("SHRINK", pile, string.format("remaining=%.1f", pile.ExpiresAt - os.clock()))
		end
	end
	if entry and entry.PileId == pileId then
		entry.PileId = nil
		entry.PileSlot = nil
		entry.PileTargetCFrame = nil
	end
	return removed
end

local function getFallPlacement(tree, fallRotation)
	local model = tree and tree.model
	local primary = model and model:IsA("Model") and model.PrimaryPart
	local pivot
	if model and model:IsA("Model") then
		pivot = model:GetPivot()
	elseif tree and typeof(tree.CFrame) == "CFrame" then
		pivot = tree.CFrame
	end

	local origin
	if pivot then
		origin = pivot.Position
	elseif tree and tree.InteractionPart and tree.InteractionPart:IsA("BasePart") then
		origin = tree.InteractionPart.Position
	else
		origin = Vector3.zero
	end

	-- The fall rotation is generated once by Tree:Die and is also used to rotate
	-- the tree. Rotating its up axis gives the direction the crown travels.
	local direction
	if typeof(fallRotation) == "CFrame" then
		direction = normalizeHorizontal(fallRotation:VectorToWorldSpace(Vector3.yAxis))
	end
	if not direction and pivot then
		direction = normalizeHorizontal(pivot.LookVector)
	end
	if not direction and primary then
		direction = normalizeHorizontal(primary.CFrame.LookVector)
	end
	if not direction then direction = Vector3.xAxis end

	-- PrimaryPart.Size.Y already includes the server-applied tree scale. The
	-- main trunk is assembled from roughly two vertical sections in current tree
	-- models, so use twice that height as the ground-projected fall path.
	local trunkLength = primary and primary:IsA("BasePart") and primary.Size.Y * 2 or 0
	if not isFinitePositive(trunkLength) or trunkLength < 6 then
		local modelHeight = model and model:IsA("Model") and model:GetExtentsSize().Y
		trunkLength = if isFinitePositive(modelHeight) and modelHeight >= 6 then modelHeight * 0.55 else 18
	end
	trunkLength = math.clamp(trunkLength, 8, 48)

	return {
		Origin = origin,
		Direction = direction,
		Perpendicular = Vector3.new(-direction.Z, 0, direction.X),
		TrunkLength = trunkLength,
	}
end

local function getFallPathPosition(fallPlacement, index, totalCount)
	local count = math.max(1, math.floor(tonumber(totalCount) or 1))
	local rank = math.clamp(math.floor(tonumber(index) or 1), 1, count)
	-- Keep the drops over the fallen trunk and distribute them along its length.
	-- A tiny alternating offset separates chunky logs without ejecting them sideways.
	local fraction = if count == 1 then 0.5 else 0.2 + 0.6 * ((rank - 1) / (count - 1))
	local lateralOffset = if count == 1 then 0 else (rank % 2 == 0 and 0.2 or -0.2)
	return fallPlacement.Origin
		+ fallPlacement.Direction * (fallPlacement.TrunkLength * fraction)
		+ fallPlacement.Perpendicular * lateralOffset
end

local function createLogVisualModel(name, logRecord, visualScale, hidden)
	local model = Instance.new("Model")
	model.Name = name
	local handle, caps = SpeciesVisuals.CreateLogParts(logRecord, "LogHandle", visualScale)
	local revealTransparencyByPart = {}
	handle.Parent = model
	for _, cap in ipairs(caps) do
		cap.Parent = model
	end
	model.PrimaryPart = handle
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			if hidden then
				revealTransparencyByPart[descendant] = descendant.Transparency
				descendant.Transparency = 1
			end
		end
	end
	return model, handle, revealTransparencyByPart
end

local function finishCarryArrival(player, uid)
	local pendingUids = pendingCarryArrivalUids[player]
	if pendingUids then
		pendingUids[uid] = nil
		if next(pendingUids) == nil then
			pendingCarryArrivalUids[player] = nil
		end
	end

	local visibleRecords = getVisibleCarryRecords(player)
	if visibleRecords then
		rebuildCarryVisuals(player, visibleRecords)
	end
end

local function cancelGroundDropReveal(entry)
	local reveal = entry and entry.ActiveGroundLogReveal
	if reveal then
		reveal.Cancelled = true
		entry.ActiveGroundLogReveal = nil
	end
end

local function makePickupHomingPayload(claim, outcome)
	local logRecord = claim.Entry.LogRecord
	local material = getMaterialDefinition(logRecord.SpeciesId)
	if not material then return nil end
	local palette = SpeciesVisuals.GetPalette(logRecord.SpeciesId)
	return {
		Mode = "Homing",
		Outcome = outcome,
		OwnerUserId = claim.OwnerUserId,
		UID = claim.UID,
		SpeciesId = logRecord.SpeciesId,
		Mutations = copyMutations(logRecord.Mutations),
		SourceCFrame = claim.StartCFrame,
		BarkColor = palette.Bark,
		CutEndColor = palette.CutEnd,
		CarryVisualScale = material.CarryVisualScale,
		PopDuration = PICKUP_POP_DURATION,
		LaunchDelay = 0,
		HomingSpeed = PICKUP_HOMING_SPEED,
		ArrivalRadius = PICKUP_HOMING_ARRIVAL_RADIUS,
		StartVisualScale = material.CarryVisualScale * GROUND_DROP_VISUAL_SCALE,
		GroundToCarryScale = GROUND_DROP_VISUAL_SCALE,
	}
end

local function makeCarryResolutionPayload(pickup, finalTargetOffset)
	if type(finalTargetOffset) ~= "table" then return nil end
	return {
		Mode = "CarryResolve",
		Outcome = "Carry",
		OwnerUserId = pickup.Player.UserId,
		UID = pickup.UID,
		FinalTargetOffset = finalTargetOffset,
		FinalSettleDuration = CARRY_FINAL_SETTLE_DURATION,
	}
end

local function makeOverflowResolutionPayload(pickup)
	if typeof(pickup.Entry.PileTargetCFrame) ~= "CFrame" then return nil end
	return {
		Mode = "OverflowResolve",
		Outcome = "Overflow",
		OwnerUserId = pickup.Player.UserId,
		UID = pickup.UID,
		PileTargetCFrame = pickup.Entry.PileTargetCFrame,
		FinalSettleDuration = OVERFLOW_FINAL_SETTLE_DURATION,
	}
end

local function broadcastPickupFx(payload)
	if not payload then return false end
	local fired, err = pcall(function()
		PickupLogFXRE:FireAllClients(payload)
	end)
	if not fired then
		warn("Could not broadcast picked-up log cosmetic", err)
	end
	return fired
end

local function clearPickupHoming(pickup)
	pickup.PileCommitAt = nil
	if pickupHomingsByUid[pickup.UID] == pickup then
		pickupHomingsByUid[pickup.UID] = nil
	end
end

local function sendPickupHomingCancel(pickup)
	broadcastPickupFx({
		Mode = "Cancel",
		Outcome = pickup.Outcome,
		OwnerUserId = pickup.Player.UserId,
		UID = pickup.UID,
	})
end

local function restoreOverflowPartTransparencies(entry)
	local intendedTransparencies = entry.RevealPartTransparencies
	local transitTransparencies = entry.TransitPartTransparencies or {}
	for part, transparency in pairs(transitTransparencies) do
		if intendedTransparencies then
			transparency = intendedTransparencies[part] or transparency
		end
		if part.Parent then part.Transparency = transparency end
	end
	for part, transparency in pairs(intendedTransparencies or {}) do
		if part.Parent then part.Transparency = transparency end
	end
	entry.TransitPartTransparencies = nil
	entry.RevealPartTransparencies = nil
end

local function getOwnerReservationSeconds(entry, state)
	if state == "OverflowSettling" or state == "Piled" then
		return math.max(0, (entry.ReservedUntil or os.clock()) - os.clock())
	end
	return OWNER_RESERVATION_SECONDS
end

local function ensureOverflowGroundRegistration(pickup)
	local entry = pickup.Entry
	local uid = pickup.UID
	local bundle = pickup.Bundle
	local drop = pickup.Drop
	local registeredBundle
	local registeredDrop
	local duplicates = {}
	for candidateBundle, candidateDrop in pairs(activeGroundDrops) do
		local records = type(candidateDrop) == "table" and candidateDrop.LogRecordsByUid
		local candidateEntry = type(records) == "table" and records[uid]
		if candidateEntry == entry then
			registeredBundle = candidateBundle
			registeredDrop = candidateDrop
		elseif candidateEntry then
			table.insert(duplicates, {
				Bundle = candidateBundle,
				Drop = candidateDrop,
				Entry = candidateEntry,
			})
		end
	end
	for _, duplicate in ipairs(duplicates) do
		local duplicateDrop = duplicate.Drop
		if duplicateDrop.LogRecordsByUid[uid] == duplicate.Entry then
			duplicateDrop.LogRecordsByUid[uid] = nil
			duplicateDrop.Count = math.max(0, duplicateDrop.Count - 1)
			unregisterPileMembership(duplicateDrop.OwnerUserId, uid, duplicate.Entry)
			if duplicate.Entry.Model and duplicate.Entry.Model.Parent then
				duplicate.Entry.Model:Destroy()
			end
			if duplicateDrop.Count == 0 and next(duplicateDrop.LogRecordsByUid) == nil then
				activeGroundDrops[duplicate.Bundle] = nil
				if pendingGroundDropByUserId[duplicateDrop.OwnerUserId] == duplicate.Bundle then
					pendingGroundDropByUserId[duplicateDrop.OwnerUserId] = nil
				end
				if duplicate.Bundle.Parent then duplicate.Bundle:Destroy() end
			end
		end
	end

	if registeredBundle and registeredDrop then
		bundle = registeredBundle
		drop = registeredDrop
	end
	if type(drop) ~= "table" or type(drop.LogRecordsByUid) ~= "table" then
		drop = {
			OwnerUserId = entry.OwnerUserId,
			LogRecordsByUid = {},
			Count = 0,
		}
	end
	local bundleDrop = bundle and activeGroundDrops[bundle]
	if bundleDrop and bundleDrop ~= drop then
		-- Do not overwrite another live bundle's registry entry if the original
		-- per-UID mapping was removed. Reconnect this retained drop table under
		-- a fresh bundle instead.
		bundle = nil
	end
	if not bundle or not bundle:IsDescendantOf(game) then
		local replacement = Instance.new("Folder")
		replacement.Name = "OwnerGroundLogDrops"
		replacement:SetAttribute("OwnerUserId", entry.OwnerUserId)
		replacement.Parent = getGroundDropFolder()
		if bundle and activeGroundDrops[bundle] == drop then
			activeGroundDrops[bundle] = nil
		end
		if pendingGroundDropByUserId[entry.OwnerUserId] == bundle then
			pendingGroundDropByUserId[entry.OwnerUserId] = replacement
		end
		bundle = replacement
	elseif bundle.Parent ~= getGroundDropFolder() then
		bundle.Parent = getGroundDropFolder()
	end

	drop.OwnerUserId = entry.OwnerUserId
	if drop.LogRecordsByUid[uid] ~= entry then
		drop.LogRecordsByUid[uid] = entry
	end
	local count = 0
	for _, registeredEntry in pairs(drop.LogRecordsByUid) do
		count += 1
		registeredEntry.Bundle = bundle
		registeredEntry.Drop = drop
		local model = registeredEntry.Model
		if model and model:IsDescendantOf(game) then
			registeredEntry.GroundCFrame = model:GetPivot()
		end
		if not model or not model:IsDescendantOf(game) then
			local hidden = registeredEntry.State == "HomingOverflow"
				or registeredEntry.State == "OverflowSettling"
			local newModel, _, transparencies = createLogVisualModel(
				"DroppedLog",
				registeredEntry.LogRecord,
				GROUND_DROP_VISUAL_SCALE,
				hidden
			)
			registeredEntry.Model = newModel
			registeredEntry.TransitPartTransparencies = if hidden then transparencies else nil
			model = newModel
		end
		if model.Parent ~= bundle then model.Parent = bundle end
		local targetCFrame = registeredEntry.PileTargetCFrame
			or registeredEntry.HomingStartCFrame
			or registeredEntry.GroundCFrame
			or (registeredEntry == entry and pickup.SourceCFrame)
		if typeof(targetCFrame) == "CFrame" then model:PivotTo(targetCFrame) end
		model:SetAttribute("UID", registeredEntry.LogRecord.UID)
		model:SetAttribute("ItemType", "Log")
		model:SetAttribute("SpeciesId", registeredEntry.LogRecord.SpeciesId)
		model:SetAttribute("OwnerUserId", registeredEntry.OwnerUserId)
		model:SetAttribute("OwnerReservationSeconds", getOwnerReservationSeconds(registeredEntry, registeredEntry.State))
		model:SetAttribute("HarvestBatchId", registeredEntry.HarvestBatchId)
		model:SetAttribute("GroundLogState", registeredEntry.State)
		model:SetAttribute("PileId", registeredEntry.PileId)
		model:SetAttribute("PileSlot", registeredEntry.PileSlot)
		model:SetAttribute("PickupEnabled", registeredEntry.PickupEnabled == true)
	end
	drop.Count = count
	activeGroundDrops[bundle] = drop
	pickup.Bundle = bundle
	pickup.Drop = drop
	entry.Bundle = bundle
	entry.Drop = drop
	local pendingBundle = pendingGroundDropByUserId[entry.OwnerUserId]
	if not pendingBundle or activeGroundDrops[pendingBundle] == nil then
		pendingGroundDropByUserId[entry.OwnerUserId] = bundle
	end
	return true
end

local function ensureOverflowGroundModel(pickup, state, targetCFrame, pickupEnabled)
	local entry = pickup.Entry
	local bundle = pickup.Bundle
	local drop = pickup.Drop
	local uid = pickup.UID
	if not entry or not ensureOverflowGroundRegistration(pickup) then return false end
	bundle = pickup.Bundle
	drop = pickup.Drop

	local worldDropFolder = getGroundDropFolder()
	if bundle.Parent ~= worldDropFolder then
		bundle.Parent = worldDropFolder
	end

	local model = entry.Model
	local modelAlive = model ~= nil and model:IsDescendantOf(game)
	if not modelAlive then
		local newModel, _, originalTransparencies = createLogVisualModel(
			"DroppedLog",
			entry.LogRecord,
			GROUND_DROP_VISUAL_SCALE,
			true
		)
		entry.Model = newModel
		entry.TransitPartTransparencies = originalTransparencies
		model = newModel
		model.Parent = bundle
	elseif model.Parent ~= bundle then
		model.Parent = bundle
	end
	if typeof(targetCFrame) == "CFrame" then
		model:PivotTo(targetCFrame)
	end
	model:SetAttribute("UID", uid)
	model:SetAttribute("ItemType", "Log")
	model:SetAttribute("SpeciesId", entry.LogRecord.SpeciesId)
	model:SetAttribute("OwnerUserId", entry.OwnerUserId)
	model:SetAttribute("OwnerReservationSeconds", getOwnerReservationSeconds(entry, state))
	model:SetAttribute("HarvestBatchId", entry.HarvestBatchId)
	model:SetAttribute("GroundLogState", state)
	model:SetAttribute("PileId", entry.PileId)
	model:SetAttribute("PileSlot", entry.PileSlot)
	model:SetAttribute("PickupEnabled", pickupEnabled == true)
	entry.PickupEnabled = pickupEnabled == true
	entry.State = state
	return true
end

local function finishCarryHoming(pickup)
	if pickupHomingsByUid[pickup.UID] ~= pickup or pickup.Status ~= "Homing" then return false end
	local player = pickup.Player
	local data = getPlayerData(player)
	local logRecord = data and findLog(data, pickup.UID)
	local finalTargetOffset = data and logRecord
		and LogCarryVisualService.GetTargetOffset(data.Logs, pickup.UID) or nil
	if not logRecord or type(finalTargetOffset) ~= "table" then
		debugPickupHoming("CLEANUP", pickup.UID, "reason=carry-record-missing")
		sendPickupHomingCancel(pickup)
		clearPickupHoming(pickup)
		finishCarryArrival(player, pickup.UID)
		return false
	end

	pickup.Status = "CarrySettling"
	pickup.SettleUntil = os.clock() + CARRY_FINAL_SETTLE_DURATION
	debugPickupHoming("ARRIVED", pickup.UID)
	debugPickupHoming("RESOLVE_CARRY", pickup.UID)
	broadcastPickupFx(makeCarryResolutionPayload(pickup, finalTargetOffset))
	return true
end

local function finishOverflowPileSettle(pickup)
	if pickupHomingsByUid[pickup.UID] ~= pickup or pickup.Status ~= "OverflowSettling" then return false end
	local entry = pickup.Entry
	local pile = pilesByPlayer[entry.OwnerUserId] and pilesByPlayer[entry.OwnerUserId][entry.PileId]
	if not pile or pile.ItemsByUid[pickup.UID] ~= entry or pile.Slots[entry.PileSlot] ~= entry
		or typeof(entry.PileTargetCFrame) ~= "CFrame"
		or not ensureOverflowGroundModel(pickup, "Piled", entry.PileTargetCFrame, false) then
		unregisterPileMembership(entry.OwnerUserId, pickup.UID, entry)
		pickup.Status = "Homing"
		recoverOverflowHoming(pickup, "pile-finalize-failed")
		return false
	end

	restoreOverflowPartTransparencies(entry)
	entry.Model:PivotTo(entry.PileTargetCFrame)
	entry.GroundCFrame = entry.PileTargetCFrame
	entry.Model:SetAttribute("GroundLogState", "Piled")
	entry.Model:SetAttribute("PickupEnabled", false)
	entry.PickupEnabled = false
	entry.HomingStartCFrame = nil
	entry.ExpiresAt = pile.ExpiresAt
	entry.ReservedUntil = pile.ExpiresAt
	clearPickupHoming(pickup)
	debugPickupHoming("SETTLE_COMPLETE", pickup.UID, "mode=Overflow")
	local owner = Players:GetPlayerByUserId(entry.OwnerUserId)
	if owner then refreshPiledLogPickupEligibility(owner) end
	return true
end

recoverOverflowHoming = function(pickup, reason)
	if pickupHomingsByUid[pickup.UID] ~= pickup then return false end
	if pickup.Status == "OverflowSettling" then
		-- Once pile membership has been assigned, finish that authoritative
		-- ground-owned state immediately if the player disappears or dies.
		sendPickupHomingCancel(pickup)
		return finishOverflowPileSettle(pickup)
	end

	pickup.Cancelled = true
	local entry = pickup.Entry
	if entry.PileId ~= nil or entry.PileSlot ~= nil then
		unregisterPileMembership(entry.OwnerUserId, pickup.UID, entry)
	end
	if not ensureOverflowGroundModel(
		pickup,
		"Fresh",
		pickup.SourceCFrame,
		os.clock() <= entry.ReservedUntil
	) then
		-- The registered entry is still the UID owner even if its model was
		-- externally removed. Leave it recoverable in the registry and make one
		-- best-effort attempt to restore the replicated visual on its source.
		entry.State = "Fresh"
		entry.PileId = nil
		entry.PileSlot = nil
		entry.PileTargetCFrame = nil
		entry.PickupEnabled = false
		entry.Model = nil
	end
	entry.PileId = nil
	entry.PileSlot = nil
	entry.PileTargetCFrame = nil
	entry.GroundCFrame = pickup.SourceCFrame
	entry.HomingStartCFrame = nil
	restoreOverflowPartTransparencies(entry)
	if entry.Model then
		entry.Model:SetAttribute("GroundLogState", "Fresh")
		entry.Model:SetAttribute("PileId", nil)
		entry.Model:SetAttribute("PileSlot", nil)
		entry.Model:SetAttribute("PickupEnabled", entry.PickupEnabled == true)
	end
	entry.State = "Fresh"
	local homingDuration = math.max(0, os.clock() - pickup.StartedAt)
	entry.ExpiresAt = (pickup.OriginalExpiresAt or pickup.StartedAt) + homingDuration
	entry.ReservedUntil = (pickup.OriginalReservedUntil or pickup.StartedAt) + homingDuration
	clearPickupHoming(pickup)
	sendPickupHomingCancel(pickup)
	if reason == "timeout" then
		debugPickupHoming("TIMEOUT", pickup.UID)
	else
		debugPickupHoming("CLEANUP", pickup.UID, "reason=" .. tostring(reason))
	end
	scheduleGroundDropExpiry(pickup.Bundle, pickup.UID, entry)
	local owner = Players:GetPlayerByUserId(entry.OwnerUserId)
	if owner then refreshPiledLogPickupEligibility(owner) end
	return true
end

local function cancelCarryHoming(pickup, reason, leaving)
	if pickupHomingsByUid[pickup.UID] ~= pickup then return false end
	clearPickupHoming(pickup)
	sendPickupHomingCancel(pickup)
	debugPickupHoming("CLEANUP", pickup.UID, "reason=" .. tostring(reason))
	if not leaving then
		-- The UID is already in the profile. Releasing its pending-visual marker
		-- makes the existing carried-stack renderer the safe recovery path.
		finishCarryArrival(pickup.Player, pickup.UID)
	end
	return true
end

cancelPickupHoming = function(pickup, reason, leaving)
	if pickup.Outcome == "Overflow" then
		if pickup.Status == "OverflowSettling" then
			sendPickupHomingCancel(pickup)
			return finishOverflowPileSettle(pickup)
		end
		return recoverOverflowHoming(pickup, reason)
	end
	return cancelCarryHoming(pickup, reason, leaving)
end

local function beginCarryHoming(player, claim, now)
	if pickupHomingsByUid[claim.UID] then return nil end
	cancelGroundDropReveal(claim.Entry)
	local pickup = {
		UID = claim.UID,
		Player = player,
		Outcome = "Carry",
		Status = "Homing",
		Entry = claim.Entry,
		SourceCFrame = claim.StartCFrame,
		LogicalPosition = claim.StartCFrame.Position,
		StartedAt = now,
		MotionStartsAt = now + PICKUP_POP_DURATION,
		LastUpdateAt = now,
		Deadline = now + PICKUP_HOMING_TIMEOUT,
	}
	claim.Entry.State = "HomingCarry"
	pickupHomingsByUid[claim.UID] = pickup
	debugPickupHoming("START", claim.UID, "mode=Carry")
	return pickup
end

local function beginOverflowHoming(player, claim, now)
	if pickupHomingsByUid[claim.UID] then return nil end
	local entry = claim.Entry
	if entry.State ~= "Fresh" or entry.PileId ~= nil or entry.PileSlot ~= nil
		or entry.PileTargetCFrame ~= nil then
		return nil
	end
	cancelGroundDropReveal(entry)
	local pickup = {
		UID = claim.UID,
		Player = player,
		Outcome = "Overflow",
		Status = "Homing",
		Entry = entry,
		Bundle = entry.Bundle,
		Drop = entry.Drop,
		SourceCFrame = claim.StartCFrame,
		LogicalPosition = claim.StartCFrame.Position,
		StartedAt = now,
		MotionStartsAt = now + PICKUP_POP_DURATION,
		LastUpdateAt = now,
		Deadline = now + PICKUP_HOMING_TIMEOUT,
		OriginalExpiresAt = entry.ExpiresAt or (now + GROUND_LOG_LIFETIME_SECONDS),
		OriginalReservedUntil = entry.ReservedUntil or (now + OWNER_RESERVATION_SECONDS),
	}
	entry.HomingStartCFrame = claim.StartCFrame
	entry.State = "HomingOverflow"
	entry.PickupEnabled = false
	entry.PileId = nil
	entry.PileSlot = nil
	entry.PileTargetCFrame = nil
	entry.TransitPartTransparencies = {}
	for _, descendant in ipairs(entry.Model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			entry.TransitPartTransparencies[descendant] = descendant.Transparency
			descendant.Transparency = 1
		end
	end
	entry.Model:SetAttribute("GroundLogState", entry.State)
	entry.Model:SetAttribute("PileId", nil)
	entry.Model:SetAttribute("PileSlot", nil)
	entry.Model:SetAttribute("PickupEnabled", false)
	-- A request accepted before the 60s ground expiry gets enough time to finish
	-- its bounded authoritative flight and final settle.
	entry.ReservedUntil = math.max(entry.ReservedUntil, pickup.Deadline + OVERFLOW_FINAL_SETTLE_DURATION)
	pickupHomingsByUid[claim.UID] = pickup
	debugPickupHoming("START", claim.UID, "mode=Overflow")
	return pickup
end

local function getPendingGroundDrop(ownerUserId)
	local bundle = pendingGroundDropByUserId[ownerUserId]
	if not bundle then return nil, nil end
	local drop = activeGroundDrops[bundle]
	if not drop then
		pendingGroundDropByUserId[ownerUserId] = nil
		return nil, nil
	end
	-- Reparent a server-owned registry bundle if an instance cleanup removed it
	-- from Workspace; do not discard its authoritative UID records.
	local worldDropFolder = getGroundDropFolder()
	if bundle.Parent ~= worldDropFolder then bundle.Parent = worldDropFolder end
	return bundle, drop
end

local function canSpawnGroundDrops(ownerUserId, incomingCount)
	if type(incomingCount) ~= "number" or incomingCount < 1 then return false end
	local _, drop = getPendingGroundDrop(ownerUserId)
	local existingCount = drop and drop.Count or 0
	return existingCount + incomingCount <= MAX_GROUND_LOG_DROPS_PER_PLAYER
end

local function clearGroundDropBundle(bundle, drop)
	activeGroundDrops[bundle] = nil
	if pendingGroundDropByUserId[drop.OwnerUserId] == bundle then
		pendingGroundDropByUserId[drop.OwnerUserId] = nil
	end
	for uid, entry in pairs(drop.LogRecordsByUid) do
		unregisterPileMembership(drop.OwnerUserId, uid, entry)
	end
	table.clear(drop.LogRecordsByUid)
	drop.Count = 0
	if bundle.Parent then bundle:Destroy() end
end

expireOverflowPile = function(pile, generation)
	if not isRegisteredPile(pile)
		or pile.ExpiryGeneration ~= generation
		or type(pile.ExpiresAt) ~= "number" then
		return false
	end
	local now = os.clock()
	if now < pile.ExpiresAt then
		schedulePileExpiry(pile, generation)
		return false
	end

	debugPileLifetime("EXPIRE", pile)
	local members = {}
	for uid, entry in pairs(pile.ItemsByUid) do
		table.insert(members, { UID = uid, Entry = entry })
	end

	-- Remove the registry identity up front. No delayed callback or re-entrant
	-- cleanup can treat this pile as current while its records are being removed.
	removePileFromRegistry(pile)
	local touchedDrops = {}
	for _, member in ipairs(members) do
		local uid = member.UID
		local entry = member.Entry
		if pile.ItemsByUid[uid] ~= entry then
			continue
		end

		pile.ItemsByUid[uid] = nil
		if pile.Slots[entry.PileSlot] == entry then
			pile.Slots[entry.PileSlot] = nil
		end
		pile.ItemCount = math.max(0, pile.ItemCount - 1)

		local pickup = pickupHomingsByUid[uid]
		if pickup and pickup.Entry == entry and pickup.Outcome == "Overflow" then
			pickup.Cancelled = true
			pickup.Resolved = true
			pickup.Status = "Expired"
			sendPickupHomingCancel(pickup)
			clearPickupHoming(pickup)
		end

		local bundle = entry.Bundle
		local drop = entry.Drop
		if type(drop) == "table" and type(drop.LogRecordsByUid) == "table"
			and drop.LogRecordsByUid[uid] == entry then
			drop.LogRecordsByUid[uid] = nil
			drop.Count = math.max(0, (drop.Count or 0) - 1)
			if bundle and activeGroundDrops[bundle] == drop then
				touchedDrops[bundle] = drop
			end
		else
			-- Repair only this exact UID if its bundle registration was rebuilt while
			-- the pile record retained older bundle references.
			for activeBundle, activeDrop in pairs(activeGroundDrops) do
				if activeDrop.LogRecordsByUid[uid] == entry then
					activeDrop.LogRecordsByUid[uid] = nil
					activeDrop.Count = math.max(0, (activeDrop.Count or 0) - 1)
					touchedDrops[activeBundle] = activeDrop
					break
				end
			end
		end

		entry.ExpiryGeneration = (entry.ExpiryGeneration or 0) + 1
		entry.ExpiresAt = nil
		entry.ReservedUntil = nil
		entry.PileId = nil
		entry.PileSlot = nil
		entry.PileTargetCFrame = nil
		entry.PickupEnabled = false
		entry.State = "Expired"
		if entry.Model then
			entry.Model:Destroy()
			entry.Model = nil
		end
	end

	table.clear(pile.ItemsByUid)
	table.clear(pile.Slots)
	pile.ItemCount = 0
	for bundle, drop in pairs(touchedDrops) do
		if drop.Count <= 0 and next(drop.LogRecordsByUid) == nil then
			clearGroundDropBundle(bundle, drop)
		end
	end
	return true
end

local function removeGroundDropLog(bundle, uid, expectedEntry)
	local drop = activeGroundDrops[bundle]
	local entry = drop and drop.LogRecordsByUid[uid]
	if not drop or not entry or (expectedEntry and entry ~= expectedEntry) then return false end
	-- Pile membership supersedes per-entry timers. This guard also makes any
	-- stale Fresh timer harmless after the UID has entered OverflowSettling.
	if entry.State == "OverflowSettling" or entry.State == "Piled" then return false end
	if entry.State ~= "Fresh" and entry.State ~= "HomingOverflow" then return false end
	local now = os.clock()
	local pickup = pickupHomingsByUid[uid]
	if pickup and pickup.Entry == entry
		and pickup.Status == "AwaitingPileCommit" then
		-- An overflow log held around a moving player remains registered. Refresh
		-- its finite ground lifetime and reservation, and keep one generation-safe
		-- expiry callback waiting beyond that window.
		local holdUntil = math.max(entry.ExpiresAt or 0, now + GROUND_LOG_LIFETIME_SECONDS)
		entry.ExpiresAt = holdUntil
		entry.ReservedUntil = math.max(entry.ReservedUntil or 0, holdUntil)
		scheduleGroundDropExpiry(bundle, uid, entry, holdUntil)
		return false
	elseif pickup and pickup.Entry == entry and pickup.Status == "Homing" then
		-- The ground lifetime callback must never consume a UID mid-flight. Extend
		-- by the remaining bounded homing time while preserving whatever ground
		-- lifetime remained when the request began.
		local safeAfter = pickup.SettleUntil or pickup.Deadline
		local lifetimeRemaining = math.max(0, (pickup.OriginalExpiresAt or pickup.StartedAt) - pickup.StartedAt)
		scheduleGroundDropExpiry(bundle, uid, entry, safeAfter + lifetimeRemaining)
		return false
	end
	if entry.ExpiresAt and now < entry.ExpiresAt then
		scheduleGroundDropExpiry(bundle, uid, entry, entry.ExpiresAt)
		return false
	end

	-- Clear the UID before destroying its prompt/visual so repeated trigger or
	-- expiry callbacks cannot award the same record twice.
	drop.LogRecordsByUid[uid] = nil
	drop.Count -= 1
	unregisterPileMembership(drop.OwnerUserId, uid, entry)
	if entry.Model and entry.Model.Parent then entry.Model:Destroy() end
	if drop.Count <= 0 then
		clearGroundDropBundle(bundle, drop)
	end
	return true
end

scheduleGroundDropExpiry = function(bundle, uid, entry, expiryAt)
	if not entry then return end
	if entry.State == "OverflowSettling" or entry.State == "Piled" then return end
	entry.ExpiryGeneration = (entry.ExpiryGeneration or 0) + 1
	local generation = entry.ExpiryGeneration
	local dueAt = expiryAt or entry.ExpiresAt or (os.clock() + GROUND_LOG_LIFETIME_SECONDS)
	task.delay(math.max(0, dueAt - os.clock()), function()
		if entry.ExpiryGeneration ~= generation then return end
		if entry.State == "OverflowSettling" or entry.State == "Piled" then return end
		removeGroundDropLog(bundle, uid, entry)
	end)
end

local function rejectPickup(player, uid, reason)
	debugPickupRejection(player, uid, reason)
	return false
end

local function isActiveGroundDropEntry(bundle, drop, uid, entry)
	local worldDropFolder = Workspace:FindFirstChild("WorldLogDrops")
	local model = entry and entry.Model
	return worldDropFolder ~= nil
		and worldDropFolder:IsA("Folder")
		and worldDropFolder:IsDescendantOf(Workspace)
		and activeGroundDrops[bundle] == drop
		and drop.LogRecordsByUid[uid] == entry
		and bundle.Parent == worldDropFolder
		and model ~= nil
		and model.Parent == bundle
		and os.clock() <= entry.ReservedUntil
end

local function getLivePlayerRoot(player)
	if not player or not player:IsDescendantOf(Players) then return nil end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not character:IsDescendantOf(game)
		or not humanoid or humanoid.Health <= 0
		or not root or not root:IsA("BasePart") or not isFiniteVector3(root.Position) then
		return nil
	end
	return root
end

local function isValidOverflowHomingEntry(pickup, player)
	if not pickup or not player or pickupHomingsByUid[pickup.UID] ~= pickup
		or pickup.Player ~= player
		or pickup.Outcome ~= "Overflow"
		or (pickup.Status ~= "Homing" and pickup.Status ~= "AwaitingPileCommit")
		or pickup.Resolved == true or pickup.Cancelled == true
		or not isValidUid(pickup.UID) then
		return false
	end

	local entry = pickup.Entry
	local bundle = pickup.Bundle
	local drop = pickup.Drop
	local record = entry and entry.LogRecord
	local model = entry and entry.Model
	return entry ~= nil
		and bundle ~= nil and drop ~= nil
		and entry.OwnerUserId == player.UserId
		and entry.Bundle == bundle and entry.Drop == drop
		and type(record) == "table" and record.ItemType == "Log" and record.UID == pickup.UID
		and entry.State == "HomingOverflow"
		and entry.PileId == nil and entry.PileSlot == nil and entry.PileTargetCFrame == nil
		and entry.PickupEnabled == false
		and model ~= nil
		and model:GetAttribute("UID") == pickup.UID
		and model:GetAttribute("OwnerUserId") == player.UserId
		and model:GetAttribute("SpeciesId") == record.SpeciesId
		and model:GetAttribute("GroundLogState") == "HomingOverflow"
		and model:GetAttribute("PileId") == nil and model:GetAttribute("PileSlot") == nil
		and model:GetAttribute("PickupEnabled") == false
		and isActiveGroundDropEntry(bundle, drop, pickup.UID, entry)
end

local function refreshAwaitingPileCommitLifetime(pickup, now)
	local entry = pickup.Entry
	local holdUntil = math.max(entry.ExpiresAt or 0, now + GROUND_LOG_LIFETIME_SECONDS)
	entry.ExpiresAt = holdUntil
	entry.ReservedUntil = math.max(entry.ReservedUntil or 0, holdUntil)
end

local function resolveOverflowHoming(pickup, now)
	if pickupHomingsByUid[pickup.UID] ~= pickup
		or pickup.Outcome ~= "Overflow"
		or pickup.Status ~= "AwaitingPileCommit"
		or pickup.Resolved == true or pickup.Cancelled == true
		or pickup.ServerArrived ~= true
		or type(pickup.PileCommitAt) ~= "number"
		or now < pickup.PileCommitAt then
		return false
	end

	local player = pickup.Player
	local entry = pickup.Entry
	if not isValidOverflowHomingEntry(pickup, player) then
		recoverOverflowHoming(pickup, "entry-invalid-at-pile-commit")
		return false
	end
	if not ensureOverflowGroundModel(pickup, "HomingOverflow", pickup.SourceCFrame, false) then
		recoverOverflowHoming(pickup, "model-missing-at-pile-commit")
		return false
	end
	-- Sample the current authoritative root after revalidating the owned ground
	-- entry. No client-supplied position participates in the pile decision.
	local root = getLivePlayerRoot(player)
	if not root or not isValidOverflowHomingEntry(pickup, player) then
		recoverOverflowHoming(pickup, "player-or-entry-invalid-at-pile-commit")
		return false
	end

	pickup.PileCommitAt = nil
	debugPickupHoming("PILE_COMMIT", pickup.UID)
	local pile = assignOverflowPileAtArrival(player, entry, root)
	if not pile then
		recoverOverflowHoming(pickup, "pile-assignment-failed")
		return false
	end

	pickup.Resolved = true
	pickup.Status = "OverflowSettling"
	pickup.SettleUntil = now + OVERFLOW_FINAL_SETTLE_DURATION
	debugPickupHoming("RESOLVE_PILE", pickup.UID, "pile=" .. tostring(pile.PileId))
	broadcastPickupFx(makeOverflowResolutionPayload(pickup))
	return true
end

local function markServerOverflowArrival(pickup, now, root)
	if pickupHomingsByUid[pickup.UID] ~= pickup
		or pickup.Outcome ~= "Overflow"
		or pickup.Status ~= "Homing"
		or pickup.ServerArrived == true
		or pickup.Cancelled == true
		or not root or not root:IsA("BasePart") or not isFiniteVector3(root.Position) then
		return false
	end

	pickup.ServerArrived = true
	pickup.ServerArrivedAt = now
	pickup.Status = "AwaitingPileCommit"
	pickup.PileCommitAt = now + OVERFLOW_PILE_COMMIT_DELAY
	local entry = pickup.Entry
	refreshAwaitingPileCommitLifetime(pickup, now)
	debugPickupHoming("SERVER_REACHED_PLAYER", pickup.UID)
	debugPickupHoming("AWAITING_PILE_COMMIT", pickup.UID)
	return true
end

local function updatePickupHomings(maxDeltaTime)
	local now = os.clock()
	for uid, pickup in pairs(pickupHomingsByUid) do
		if pickupHomingsByUid[uid] ~= pickup then
			continue
		end

		if pickup.Status == "CarrySettling" then
			if now >= pickup.SettleUntil then
				clearPickupHoming(pickup)
				finishCarryArrival(pickup.Player, pickup.UID)
				debugPickupHoming("SETTLE_COMPLETE", pickup.UID, "mode=Carry")
			end
			continue
		elseif pickup.Status == "OverflowSettling" then
			if now >= pickup.SettleUntil then
				finishOverflowPileSettle(pickup)
			end
			continue
		end

		if pickup.Status == "Homing" and now >= pickup.Deadline then
			cancelPickupHoming(pickup, "timeout", false)
			continue
		end
		local player = pickup.Player
		if not player:IsDescendantOf(Players) then
			cancelPickupHoming(pickup, "player-left", true)
			continue
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart")
			or not isFiniteVector3(root.Position) then
			cancelPickupHoming(pickup, "character-missing-or-dead", false)
			continue
		end

		if pickup.Outcome == "Overflow" then
			local entry = pickup.Entry
			local record = entry and entry.LogRecord
			local drop = pickup.Drop
			local active = entry ~= nil
				and type(record) == "table"
				and record.ItemType == "Log"
				and record.UID == pickup.UID
				and entry.OwnerUserId == player.UserId
				and pickup.Bundle ~= nil
				and type(drop) == "table"
				and type(drop.LogRecordsByUid) == "table"
				and activeGroundDrops[pickup.Bundle] == drop
				and drop.LogRecordsByUid[pickup.UID] == entry
				and entry.State == "HomingOverflow"
				and entry.PileId == nil and entry.PileSlot == nil and entry.PileTargetCFrame == nil
			if not active then
				recoverOverflowHoming(pickup, "entry-cleanup")
				continue
			end
			local model = entry.Model
			if not model or not model:IsDescendantOf(game) or model.Parent ~= pickup.Bundle
				or pickup.Bundle.Parent ~= Workspace:FindFirstChild("WorldLogDrops")
				or model:GetAttribute("UID") ~= pickup.UID
				or model:GetAttribute("OwnerUserId") ~= player.UserId
				or model:GetAttribute("SpeciesId") ~= record.SpeciesId
				or model:GetAttribute("GroundLogState") ~= "HomingOverflow"
				or model:GetAttribute("PileId") ~= nil or model:GetAttribute("PileSlot") ~= nil
				or model:GetAttribute("PickupEnabled") ~= false then
				if not ensureOverflowGroundModel(pickup, "HomingOverflow", pickup.SourceCFrame, false) then
					recoverOverflowHoming(pickup, "model-cleanup")
					continue
				end
			end
			if pickup.Status == "AwaitingPileCommit" then
				refreshAwaitingPileCommitLifetime(pickup, now)
			end
			if not isValidOverflowHomingEntry(pickup, player) then
				recoverOverflowHoming(pickup, "entry-invalid-during-homing")
				continue
			end

			if pickup.Status == "AwaitingPileCommit" then
				if type(pickup.PileCommitAt) ~= "number" then
					recoverOverflowHoming(pickup, "pile-commit-time-missing")
				elseif now >= pickup.PileCommitAt then
					resolveOverflowHoming(pickup, now)
				end
				continue
			end
		end

		if now < pickup.MotionStartsAt then continue end
		local movementStart = math.max(pickup.LastUpdateAt, pickup.MotionStartsAt)
		local deltaTime = math.min(math.max(0, now - movementStart), maxDeltaTime)
		pickup.LastUpdateAt = now
		if deltaTime <= 0 then continue end

		local target = root.Position
		local offset = target - pickup.LogicalPosition
		local distance = offset.Magnitude
		if distance ~= distance or math.abs(distance) == math.huge then
			cancelPickupHoming(pickup, "invalid-homing-distance", false)
			continue
		end
		if distance <= PICKUP_HOMING_ARRIVAL_RADIUS then
			if pickup.Outcome == "Carry" then
				finishCarryHoming(pickup)
			else
				markServerOverflowArrival(pickup, now, root)
			end
			continue
		end

		local stepDistance = math.min(PICKUP_HOMING_SPEED * deltaTime, distance)
		pickup.LogicalPosition += offset.Unit * stepDistance
		if (target - pickup.LogicalPosition).Magnitude <= PICKUP_HOMING_ARRIVAL_RADIUS then
			if pickup.Outcome == "Carry" then
				finishCarryHoming(pickup)
			else
				markServerOverflowArrival(pickup, now, root)
			end
		end
	end
end

RunService.Heartbeat:Connect(function(deltaTime)
	homingUpdateAccumulator += deltaTime
	if homingUpdateAccumulator < PICKUP_HOMING_UPDATE_INTERVAL then return end
	local elapsed = homingUpdateAccumulator
	homingUpdateAccumulator = 0
	-- A long server frame may advance the simulation, but must not produce an
	-- implausible single-step catch-up after a hitch.
	updatePickupHomings(math.min(elapsed, 0.5))
end)

local function isValidFreshGroundDropReveal(reveal)
	local entry = reveal.Entry
	local model = reveal.Model
	local record = entry and entry.LogRecord
	return entry ~= nil
		and model ~= nil
		and entry.State == "Fresh"
		and entry.ActiveGroundLogReveal == reveal
		and entry.Model == model
		and entry.Bundle == reveal.Bundle
		and entry.Drop == reveal.Drop
		and type(record) == "table"
		and record.ItemType == "Log"
		and record.UID == reveal.UID
		and model:GetAttribute("UID") == reveal.UID
		and model:GetAttribute("OwnerUserId") == entry.OwnerUserId
		and model:GetAttribute("GroundLogState") == "Fresh"
		and isActiveGroundDropEntry(reveal.Bundle, reveal.Drop, reveal.UID, entry)
end

local function animateGroundDropReveal(reveals)
	if #reveals == 0 then return end
	local startedAt = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - startedAt
		local alpha = math.clamp(elapsed / GROUND_LOG_REVEAL_DURATION, 0, 1)
		local eased = 1 - (1 - alpha) ^ 3
		local hasPendingReveal = false
		for _, reveal in ipairs(reveals) do
			if not reveal.Cancelled and not reveal.Completed then
				if not isValidFreshGroundDropReveal(reveal) then
					-- A claimed, replaced, or otherwise unregistered model must never
					-- resume this old reveal if its entry later returns to Fresh.
					reveal.Cancelled = true
					if reveal.Entry.ActiveGroundLogReveal == reveal then
						reveal.Entry.ActiveGroundLogReveal = nil
					end
				elseif alpha >= 1 then
					local entry = reveal.Entry
					local model = reveal.Model
					model:PivotTo(reveal.FinalCFrame)
					for part, finalTransparency in pairs(entry.RevealPartTransparencies or {}) do
						if part:IsDescendantOf(model) then
							part.Transparency = finalTransparency
						end
					end
					entry.RevealPartTransparencies = nil
					entry.ActiveGroundLogReveal = nil
					reveal.Completed = true
				else
					hasPendingReveal = true
					local entry = reveal.Entry
					local model = reveal.Model
					local position = reveal.StartPosition:Lerp(reveal.FinalCFrame.Position, eased)
					position += Vector3.yAxis * (math.sin(math.pi * alpha) * GROUND_LOG_REVEAL_ARC_HEIGHT)
					-- Keep the log aligned with its final ground orientation throughout
					-- the reveal. The arc supplies the motion; no spin or wobble is needed.
					model:PivotTo(CFrame.new(position) * reveal.FinalCFrame.Rotation)

					for part, finalTransparency in pairs(entry.RevealPartTransparencies or {}) do
						if part:IsDescendantOf(model) then
							part.Transparency = 1 - ((1 - finalTransparency) * eased)
						end
					end
				end
			end
		end

		if not hasPendingReveal then
			connection:Disconnect()
		end
	end)
end

-- Schedules one exact harvest batch for pickup after the fall fade and short
-- readable pause. Entries removed, reparented, or expired before then stay off.
function LogService.EnableGroundLogBatch(harvestBatchId)
	if not isValidUid(harvestBatchId) then return false end
	task.delay(GROUND_LOG_READABLE_PAUSE, function()
		local worldDropFolder = Workspace:FindFirstChild("WorldLogDrops")
		if not worldDropFolder or not worldDropFolder:IsA("Folder") then return end
		for bundle, drop in pairs(activeGroundDrops) do
			if drop and bundle.Parent == worldDropFolder then
				for uid, entry in pairs(drop.LogRecordsByUid) do
					if entry.HarvestBatchId == harvestBatchId
						and entry.State == "Fresh"
						and entry.PickupEnabled == false
						and isActiveGroundDropEntry(bundle, drop, uid, entry) then
						entry.PickupEnabled = true
						entry.Model:SetAttribute("PickupEnabled", true)
					end
				end
			end
		end
	end)
	return true
end

local function tryPickupGroundLog(player, bundle, uid, visualModel)
	local drop = activeGroundDrops[bundle]
	local entry = drop and drop.LogRecordsByUid[uid]
	local model = entry and entry.Model
	local handle = model and model.PrimaryPart
	local groundDropFolder = Workspace:FindFirstChild("WorldLogDrops")
	if not drop or not entry or model ~= visualModel or not groundDropFolder or bundle.Parent ~= groundDropFolder
		or model.Parent ~= bundle or not handle
		or type(entry.LogRecord) ~= "table" or entry.LogRecord.ItemType ~= "Log" or entry.LogRecord.UID ~= uid
		or model:GetAttribute("UID") ~= uid
		or model:GetAttribute("OwnerUserId") ~= player.UserId
		or model:GetAttribute("SpeciesId") ~= entry.LogRecord.SpeciesId
		or model:GetAttribute("GroundLogState") ~= entry.State
		or entry.Bundle ~= bundle or entry.Drop ~= drop
		then
		return rejectPickup(player, uid, "invalid registry/model mismatch")
	end
	if entry.State ~= "Fresh" and entry.State ~= "Piled" then
		return rejectPickup(player, uid, "not pickup eligible state")
	end
	if entry.PickupEnabled ~= true or model:GetAttribute("PickupEnabled") ~= true then
		return rejectPickup(player, uid, "pickup disabled")
	end
	if player.UserId ~= drop.OwnerUserId or entry.OwnerUserId ~= player.UserId then
		return rejectPickup(player, uid, "wrong owner")
	end
	if os.clock() > entry.ReservedUntil then
		return rejectPickup(player, uid, "expired reservation")
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return rejectPickup(player, uid, "dead/missing character")
	end
	if (root.Position - handle.Position).Magnitude > MAX_PICKUP_DISTANCE then
		return rejectPickup(player, uid, "too far")
	end

	local data = getPlayerData(player)
	if not data then return rejectPickup(player, uid, "profile unavailable") end
	local primaryCapacityKg = getRecordCapacityKg(entry.LogRecord)
	if not primaryCapacityKg then
		return rejectPickup(player, uid, "unknown material capacity")
	end
	if findLog(data, uid) then
		return rejectPickup(player, uid, "duplicate UID already owned")
	end
	if not consumeRemoteBudget(player, "Pickup") then
		return rejectPickup(player, uid, "rate limited")
	end
	if logCount(data) >= MAX_OWNED_LOGS and entry.State == "Piled" then
		refreshPiledLogPickupEligibility(player, data)
		return rejectPickup(player, uid, "physical item limit")
	end
	local capacityMetrics = calculateCapacityMetrics(data)
	if capacityMetrics.HasUnknownMaterial then
		return rejectPickup(player, uid, "unknown material blocks capacity calculation")
	end

	local primaryState = entry.State
	local pile
	if primaryState == "Piled" then
		local ownerPiles = pilesByPlayer[player.UserId]
		pile = ownerPiles and ownerPiles[entry.PileId]
		if not pile or pile.SpeciesId ~= entry.LogRecord.SpeciesId
			or pile.ItemsByUid[uid] ~= entry or pile.Slots[entry.PileSlot] ~= entry then
			return rejectPickup(player, uid, "invalid pile membership")
		end
	elseif entry.PileId ~= nil or entry.PileSlot ~= nil then
		return rejectPickup(player, uid, "fresh log has pile metadata")
	end
	local availableHomingSlots = MAX_HOMING_PICKUPS_PER_PLAYER - countPlayerHomingPickups(player)
	if availableHomingSlots <= 0 then
		return rejectPickup(player, uid, "homing registry limit")
	end

	-- The client nominates only the first registered model. Fresh batches are
	-- resolved from the same harvest; a piled request only batches members of
	-- that server-owned pile. No client can nominate additional UIDs or amounts.
	local nearby = {}
	for candidateUid, candidateEntry in pairs(drop.LogRecordsByUid) do
		local candidateModel = candidateEntry and candidateEntry.Model
		local candidateHandle = candidateModel and candidateModel.PrimaryPart
		local candidateLogRecord = candidateEntry and candidateEntry.LogRecord
		local candidateCapacityKg = getRecordCapacityKg(candidateLogRecord)
		local sameGroup = if primaryState == "Fresh"
			then candidateEntry.HarvestBatchId == entry.HarvestBatchId
			else candidateEntry.PileId == entry.PileId
		local candidatePileMember = primaryState ~= "Piled"
			or (pile.ItemsByUid[candidateUid] == candidateEntry
				and pile.Slots[candidateEntry.PileSlot] == candidateEntry)
		if candidateUid ~= uid
			and type(candidateLogRecord) == "table"
			and candidateLogRecord.ItemType == "Log"
			and candidateLogRecord.UID == candidateUid
			and candidateEntry.State == primaryState
			and candidateEntry.OwnerUserId == player.UserId
			and candidateEntry.Bundle == bundle
			and candidateEntry.Drop == drop
			and sameGroup
			and candidatePileMember
			and candidateEntry.PickupEnabled == true
			and candidateModel
			and candidateModel.Parent == bundle
			and candidateModel:GetAttribute("UID") == candidateUid
			and candidateModel:GetAttribute("OwnerUserId") == player.UserId
			and candidateModel:GetAttribute("SpeciesId") == candidateLogRecord.SpeciesId
			and candidateModel:GetAttribute("GroundLogState") == primaryState
			and candidateModel:GetAttribute("PickupEnabled") == true
			and candidateHandle
			and candidateCapacityKg
			and os.clock() <= candidateEntry.ReservedUntil
			and (root.Position - candidateHandle.Position).Magnitude <= MAX_PICKUP_DISTANCE
			and not findLog(data, candidateUid) then
			table.insert(nearby, {
				UID = candidateUid,
				Entry = candidateEntry,
				Model = candidateModel,
				CapacityKg = candidateCapacityKg,
				Distance = (root.Position - candidateHandle.Position).Magnitude,
			})
		end
	end
	table.sort(nearby, function(left, right)
		if math.abs(left.Distance - right.Distance) <= 0.001 then
			return left.UID < right.UID
		end
		return left.Distance < right.Distance
	end)

	local claims = {
		{
			UID = uid,
			Entry = entry,
			Model = model,
			State = primaryState,
			CapacityKg = primaryCapacityKg,
			StartCFrame = model:GetPivot(),
			OwnerUserId = player.UserId,
		},
	}
	local overflowCandidates = {}
	local remainingKg = capacityMetrics.RemainingKg
	local maximumInventoryAdds = math.max(0, MAX_OWNED_LOGS - logCount(data))
	local maximumSelectedLogs = math.min(MAX_PICKUP_BATCH, availableHomingSlots)
	local processedCount = 1
	if maximumInventoryAdds > 0
		and primaryCapacityKg <= remainingKg + CAPACITY_TOLERANCE_KG then
		remainingKg = math.max(0, remainingKg - primaryCapacityKg)
	elseif primaryState == "Fresh" then
		table.insert(overflowCandidates, claims[1])
		claims = {}
	else
		refreshPiledLogPickupEligibility(player, data)
		return rejectPickup(player, uid, "insufficient kg capacity for piled log")
	end

	for _, candidate in ipairs(nearby) do
		if processedCount >= maximumSelectedLogs then break end
		processedCount += 1
		local candidateClaim = {
			UID = candidate.UID,
			Entry = candidate.Entry,
			Model = candidate.Model,
			State = primaryState,
			CapacityKg = candidate.CapacityKg,
			StartCFrame = candidate.Model:GetPivot(),
			OwnerUserId = player.UserId,
		}
		if #claims < maximumInventoryAdds
			and candidate.CapacityKg <= remainingKg + CAPACITY_TOLERANCE_KG then
			table.insert(claims, {
				UID = candidateClaim.UID,
				Entry = candidateClaim.Entry,
				Model = candidateClaim.Model,
				State = candidateClaim.State,
				CapacityKg = candidateClaim.CapacityKg,
				StartCFrame = candidateClaim.StartCFrame,
				OwnerUserId = candidateClaim.OwnerUserId,
			})
			remainingKg = math.max(0, remainingKg - candidate.CapacityKg)
		elseif primaryState == "Fresh" then
			table.insert(overflowCandidates, candidateClaim)
		end
	end

	local now = os.clock()
	local overflowClaims = {}
	for _, overflow in ipairs(overflowCandidates) do
		if beginOverflowHoming(player, overflow, now) then
			table.insert(overflowClaims, overflow)
		end
	end
	if #claims == 0 and #overflowClaims == 0 then
		if primaryState == "Piled" then
			refreshPiledLogPickupEligibility(player, data)
		end
		return rejectPickup(player, uid, "no eligible log fits or can overflow")
	end

	-- Atomically claim every selected UID before any visual delay or profile
	-- mutation. Repeated remotes cannot award or animate the same record twice.
	local pendingUids = pendingCarryArrivalUids[player]
	if #claims > 0 and not pendingUids then
		pendingUids = {}
		pendingCarryArrivalUids[player] = pendingUids
	end
	for _, claim in ipairs(claims) do
		drop.LogRecordsByUid[claim.UID] = nil
		drop.Count -= 1
		if claim.State == "Piled" then
			unregisterPileMembership(player.UserId, claim.UID, claim.Entry)
		end
		pendingUids[claim.UID] = true
		table.insert(data.Logs, claim.Entry.LogRecord)
		claim.Homing = beginCarryHoming(player, claim, now)
	end

	if drop.Count <= 0 then
		clearGroundDropBundle(bundle, drop)
	end
	LogService.NotifyState(player)
	for _, claim in ipairs(claims) do
		broadcastPickupFx(makePickupHomingPayload(claim, "Carry"))
		claim.Model:Destroy()
	end
	for _, overflow in ipairs(overflowClaims) do
		broadcastPickupFx(makePickupHomingPayload(overflow, "Overflow"))
	end
	return true
end

local function spawnGroundDrops(logRecords, ownerUserId, fallPlacement, harvestBatchId, firstIndex, batchCount, revealMode)
	if #logRecords == 0 then return true end
	if not canSpawnGroundDrops(ownerUserId, #logRecords) then return false end

	local bundle, drop = getPendingGroundDrop(ownerUserId)
	if not bundle then
		bundle = Instance.new("Folder")
		bundle.Name = "OwnerGroundLogDrops"
		bundle:SetAttribute("OwnerUserId", ownerUserId)
		bundle.Parent = getGroundDropFolder()
		drop = {
			OwnerUserId = ownerUserId,
			LogRecordsByUid = {},
			Count = 0,
		}
		activeGroundDrops[bundle] = drop
		pendingGroundDropByUserId[ownerUserId] = bundle
	end

	local reveals = {}
	for index, logRecord in ipairs(logRecords) do
		local hiddenUntilReveal = revealMode == true
		local model, handle, revealTransparencyByPart = createLogVisualModel(
			"DroppedLog",
			logRecord,
			GROUND_DROP_VISUAL_SCALE,
			hiddenUntilReveal
		)
		local revealIndex = (firstIndex or 1) + index - 1
		local revealCount = batchCount or #logRecords
		local landingPosition = getFallPathPosition(fallPlacement, revealIndex, revealCount)
		local groundCFrame = CFrame.fromMatrix(
			Vector3.new(
				landingPosition.X,
				getGroundHeight(landingPosition) + handle.Size.Y * 0.5 + 0.08,
				landingPosition.Z
			),
			-- Log geometry's long local X axis follows the fallen trunk, not its
			-- crosswise perpendicular. Drops remain flat on the ground.
			fallPlacement.Direction,
			Vector3.yAxis,
			fallPlacement.Direction:Cross(Vector3.yAxis)
		)
		-- Start at the final footprint position. The reveal animation adds only a
		-- vertical pop, so logs settle in place along the trunk without flying sideways.
		local startPosition = groundCFrame.Position
		model:PivotTo(groundCFrame)
		model:SetAttribute("UID", logRecord.UID)
		model:SetAttribute("ItemType", "Log")
		model:SetAttribute("SpeciesId", logRecord.SpeciesId)
		model:SetAttribute("OwnerUserId", ownerUserId)
		model:SetAttribute("OwnerReservationSeconds", OWNER_RESERVATION_SECONDS)
		model:SetAttribute("HarvestBatchId", harvestBatchId)
		model:SetAttribute("GroundLogState", "Fresh")
		model:SetAttribute("PileId", nil)
		model:SetAttribute("PileSlot", nil)
		model:SetAttribute("PickupEnabled", not hiddenUntilReveal)
		model.Parent = bundle

		local createdAt = os.clock()
		local entry = {
			LogRecord = logRecord,
			Model = model,
			Bundle = bundle,
			Drop = drop,
			OwnerUserId = ownerUserId,
			HarvestBatchId = harvestBatchId,
			ReservedUntil = createdAt + OWNER_RESERVATION_SECONDS,
			ExpiresAt = createdAt + GROUND_LOG_LIFETIME_SECONDS,
			State = "Fresh",
			PileId = nil,
			PileSlot = nil,
			GroundCFrame = groundCFrame,
			PickupEnabled = not hiddenUntilReveal,
			RevealPartTransparencies = if hiddenUntilReveal then revealTransparencyByPart else nil,
		}
		drop.LogRecordsByUid[logRecord.UID] = entry
		drop.Count += 1
		if hiddenUntilReveal then
			local reveal = {
				Bundle = bundle,
				Drop = drop,
				UID = logRecord.UID,
				Entry = entry,
				Model = model,
				StartPosition = startPosition,
				FinalCFrame = groundCFrame,
			}
			entry.ActiveGroundLogReveal = reveal
			table.insert(reveals, reveal)
		end

		scheduleGroundDropExpiry(bundle, logRecord.UID, entry)
	end
	if revealMode == true then
		task.spawn(animateGroundDropReveal, reveals)
	end
	return true
end

local function createLogRecord(tree)
	return {
		UID = HttpService:GenerateGUID(false),
		ItemType = "Log",
		SpeciesId = tree.SpeciesId,
		Mutations = {},
		Locked = false,
		CreatedAt = os.time(),
	}
end

local function getTreeLogYieldCount(tree)
	local configuredYield = tree and tree.LogYield
	if configuredYield ~= nil then
		if not isFinitePositive(configuredYield) or configuredYield % 1 ~= 0
			or configuredYield > MAX_HARVEST_LOGS then
			return nil
		end
		return configuredYield
	end
	local sizeScale = tree and tree.SizeScale
	if not isFinitePositive(sizeScale) then return nil end

	-- These thresholds match the server-owned rollTreeScale bands: small trees
	-- yield one log, ordinary trees two, and the largest trees three.
	if sizeScale < 0.7 then
		return 1
	elseif sizeScale < 1.3 then
		return 2
	end
	return MAX_STANDARD_TREE_LOGS
end

function LogService.CaptureTreeLogAward(tree, contributions, fallRotation)
	if not tree or tree.YieldsLog ~= true or not getMaterialDefinition(tree.SpeciesId) then return nil end

	local contributionSnapshot = {}
	for userId, contribution in pairs(contributions or {}) do
		if type(contribution) == "table" then
			contributionSnapshot[userId] = {
				Player = contribution.Player,
				Damage = contribution.Damage,
			}
		end
	end

	return {
		YieldsLog = tree.YieldsLog,
		SpeciesId = tree.SpeciesId,
		LogYield = tree.LogYield,
		SizeScale = tree.SizeScale,
		Contributions = contributionSnapshot,
		FallPlacement = getFallPlacement(tree, fallRotation),
	}
end

function LogService.AwardTreeLog(awardSnapshot, options)
	local revealMode = type(options) == "table" and options.Reveal == true
	local harvestBatchId = HttpService:GenerateGUID(false)
	if type(harvestBatchId) ~= "string" or #harvestBatchId == 0 then return false end
	if type(awardSnapshot) ~= "table" or awardSnapshot.YieldsLog ~= true then return false end
	if type(awardSnapshot.SpeciesId) ~= "string" or not getMaterialDefinition(awardSnapshot.SpeciesId) then return false end
	local rewardCount = getTreeLogYieldCount(awardSnapshot)
	if not rewardCount or rewardCount > MAX_HARVEST_LOGS then return false end

	local winner
	local winnerUserId
	local winnerDamage = -1
	for userId, contribution in pairs(awardSnapshot.Contributions or {}) do
		local player = Players:GetPlayerByUserId(userId)
		if player and contribution.Player == player and isFinitePositive(contribution.Damage)
			and (contribution.Damage > winnerDamage
				or (contribution.Damage == winnerDamage and (not winnerUserId or userId < winnerUserId))) then
			winner = player
			winnerUserId = userId
			winnerDamage = contribution.Damage
		end
	end
	if not winner then return false end

	local data = getPlayerData(winner)
	if not data then return false end
	local logRecords = {}
	for index = 1, rewardCount do
		table.insert(logRecords, createLogRecord({ SpeciesId = awardSnapshot.SpeciesId }))
	end

	local fallPlacement = awardSnapshot.FallPlacement
	if type(fallPlacement) ~= "table" then return false end

	-- Every tree reward remains a physical, owner-reserved drop until the winner
	-- approaches it. Preflight the bounded registry so a harvest is never partial.
	if not canSpawnGroundDrops(winner.UserId, #logRecords) then
		return false
	end
	if not spawnGroundDrops(
		logRecords,
		winner.UserId,
		fallPlacement,
		harvestBatchId,
		1,
		rewardCount,
		revealMode
	) then
		return false
	end

	-- The unique batch id is also the narrow handle used by the delayed pickup
	-- release API. Returning it prevents a caller from releasing another tree's
	-- drops when several trees are falling in parallel.
	return harvestBatchId
end

LogService.DEFAULT_CAPACITY_KG = DEFAULT_CAPACITY_KG
LogService.MAX_CAPACITY_KG = MAX_CAPACITY_KG
LogService.MAX_OWNED_LOGS = MAX_OWNED_LOGS
LogService.MAX_PICKUP_BATCH = MAX_PICKUP_BATCH
LogService.MAX_GROUND_LOG_DROPS_PER_PLAYER = MAX_GROUND_LOG_DROPS_PER_PLAYER
LogService.CAPACITY_TIERS_KG = AxeShopCatalog.CAPACITY_TIERS_KG

GetLogsDataRF.OnServerInvoke = function(player, ...)
	if select("#", ...) ~= 0 then return nil end
	return makeClientSnapshot(player)
end

GetSellSummaryRF.OnServerInvoke = function(player, ...)
	if select("#", ...) ~= 0 then return nil end
	return makeSellSummary(player)
end

SellUnlockedLogsRE.OnServerEvent:Connect(function(player, ...)
	if select("#", ...) ~= 0 or not consumeRemoteBudget(player, "Sell") then return end
	if not LogService.CanSellAtBase(player) then return end
	local data = getPlayerData(player)
	if not data then return end

	local remaining = {}
	local saleTotal = 0
	local soldCount = 0
	for _, logRecord in ipairs(data.Logs) do
		local value = getLogValue(logRecord)
		if value and logRecord.Locked ~= true then
			saleTotal += value
			soldCount += 1
		else
			table.insert(remaining, logRecord)
		end
	end
	if soldCount == 0 or saleTotal <= 0 then return end

	data.Logs = remaining
	EconomyManager.Add(player, "Coins", saleTotal)
	LogService.NotifyState(player)
end)

SetLogLockedRE.OnServerEvent:Connect(function(player, uid, locked, ...)
	if select("#", ...) ~= 0 or not consumeRemoteBudget(player, "Lock") then return end
	if not isValidUid(uid) or type(locked) ~= "boolean" then return end
	local data = getPlayerData(player)
	if not data then return end
	local logRecord = findLog(data, uid)
	if not logRecord then return end
	logRecord.Locked = locked
	LogService.NotifyState(player)
end)

PickupGroundLogRE.OnServerEvent:Connect(function(player, visualModel, uid, ...)
	if select("#", ...) ~= 0 or typeof(visualModel) ~= "Instance"
		or not visualModel:IsA("Model") or not isValidUid(uid) then
		debugPickupRejection(player, uid, "invalid registry/model mismatch")
		return
	end

	local bundle = visualModel.Parent
	if not bundle or not bundle:IsA("Folder") then
		debugPickupRejection(player, uid, "invalid registry/model mismatch")
		return
	end
	tryPickupGroundLog(player, bundle, uid, visualModel)
end)

profileLoaded.Event:Connect(function(player)
	getPlayerData(player)
	LogService.NotifyState(player)
end)

Players.PlayerRemoving:Connect(function(player)
	local leavingHomings = {}
	for _, pickup in pairs(pickupHomingsByUid) do
		if pickup.Player == player then
			table.insert(leavingHomings, pickup)
		end
	end
	for _, pickup in ipairs(leavingHomings) do
		cancelPickupHoming(pickup, "player-left", true)
	end
	-- Keep owner-reserved ground UIDs in their registry. Fresh and recovered
	-- homing entries retain per-log expiry; established piles keep their own
	-- generation-safe pile deadline while a quick rejoin remains possible.
	remoteBudgetByPlayer[player] = nil
	pendingCarryArrivalUids[player] = nil
	deferredCarryRecords[player] = nil
end)

return LogService
