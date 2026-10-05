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
local MAX_PICKUP_DISTANCE = 15
-- Maximum physical records processed per request, independent of kg capacity.
local MAX_PICKUP_BATCH = 24
local CAPACITY_TOLERANCE_KG = 1e-5
local PICKUP_POP_DURATION = 0.10
local PICKUP_FLIGHT_DURATION = 0.36
local PICKUP_LAUNCH_OFFSET_PER_LOG = 0.015
local MAX_PICKUP_LAUNCH_OFFSET = 0.08
local GROUND_LOG_REVEAL_DURATION = 0.36
local GROUND_LOG_REVEAL_ARC_HEIGHT = 2.5
local GROUND_LOG_READABLE_PAUSE = 0.2
local OVERFLOW_MERGE_RADIUS = 12
local OVERFLOW_PLAYER_SIDE_OFFSET = 2.8
local OVERFLOW_PLAYER_BACK_OFFSET = 2.0
local OVERFLOW_FLIGHT_DURATION = 0.52
local OVERFLOW_TRANSIT_DURATION = PICKUP_POP_DURATION + OVERFLOW_FLIGHT_DURATION
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
local remoteBudgetByPlayer = {}
local pendingCarryArrivalUids = {}
local deferredCarryRecords = {}

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
	local pile = {
		PileId = pileId,
		OwnerUserId = player.UserId,
		SpeciesId = speciesId,
		OriginCFrame = originCFrame,
		ItemsByUid = {},
		Slots = {},
		ItemCount = 0,
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

local function registerOverflowTransit(player, entry, root)
	local material = getMaterialDefinition(entry.LogRecord.SpeciesId)
	if not material then return nil end
	local pile = getOrCreateOverflowPile(player, entry.LogRecord.SpeciesId, root)
	local slotIndex = getAvailablePileSlot(pile)
	local targetCFrame = slotIndex and getPileSlotCFrame(pile, slotIndex, material.CarryVisualScale)
	if not slotIndex or typeof(targetCFrame) ~= "CFrame" then return nil end

	entry.State = "OverflowTransit"
	entry.PileId = pile.PileId
	entry.PileSlot = slotIndex
	entry.PileTargetCFrame = targetCFrame
	entry.PickupEnabled = false
	entry.TransitPartTransparencies = {}
	for _, descendant in ipairs(entry.Model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			entry.TransitPartTransparencies[descendant] = descendant.Transparency
			descendant.Transparency = 1
		end
	end
	entry.Model:SetAttribute("GroundLogState", entry.State)
	entry.Model:SetAttribute("PileId", pile.PileId)
	entry.Model:SetAttribute("PileSlot", slotIndex)
	entry.Model:SetAttribute("PickupEnabled", false)
	pile.ItemsByUid[entry.LogRecord.UID] = entry
	pile.Slots[slotIndex] = entry
	pile.ItemCount += 1
	return pile
end

local function unregisterPileMembership(ownerUserId, uid, entry)
	local pileId = entry and entry.PileId
	if type(pileId) ~= "string" then return end
	local ownerPiles = pilesByPlayer[ownerUserId]
	local pile = ownerPiles and ownerPiles[pileId]
	if pile and pile.ItemsByUid[uid] == entry then
		pile.ItemsByUid[uid] = nil
		if pile.Slots[entry.PileSlot] == entry then
			pile.Slots[entry.PileSlot] = nil
		end
		pile.ItemCount = math.max(0, pile.ItemCount - 1)
		if pile.ItemCount == 0 then
			ownerPiles[pileId] = nil
			if next(ownerPiles) == nil then
				pilesByPlayer[ownerUserId] = nil
			end
		end
	end
	entry.PileId = nil
	entry.PileSlot = nil
	entry.PileTargetCFrame = nil
end

local function finishOverflowTransit(bundle, drop, uid, entry)
	if entry.State ~= "OverflowTransit"
		or activeGroundDrops[bundle] ~= drop
		or drop.LogRecordsByUid[uid] ~= entry
		or bundle.Parent ~= Workspace:FindFirstChild("WorldLogDrops")
		or entry.Model.Parent ~= bundle
		or os.clock() > entry.ReservedUntil
		or typeof(entry.PileTargetCFrame) ~= "CFrame" then
		return false
	end
	local pile = pilesByPlayer[entry.OwnerUserId] and pilesByPlayer[entry.OwnerUserId][entry.PileId]
	if not pile or pile.ItemsByUid[uid] ~= entry or pile.Slots[entry.PileSlot] ~= entry then
		return false
	end
	entry.Model:PivotTo(entry.PileTargetCFrame)
	for part, transparency in pairs(entry.TransitPartTransparencies or {}) do
		if part.Parent then part.Transparency = transparency end
	end
	entry.TransitPartTransparencies = nil
	entry.State = "Piled"
	entry.Model:SetAttribute("GroundLogState", entry.State)
	entry.Model:SetAttribute("PickupEnabled", false)
	entry.PickupEnabled = false
	local owner = Players:GetPlayerByUserId(entry.OwnerUserId)
	if owner then
		refreshPiledLogPickupEligibility(owner)
	end
	return true
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

local function getCarryTargetByUid(logRecords)
	local targets = {}
	local normalIndex = 0
	local rareIndex = 0
	for _, logRecord in ipairs(logRecords) do
		if type(logRecord) == "table" and logRecord.ItemType == "Log" and isValidUid(logRecord.UID) then
			if SpeciesVisuals.IsRareLog(logRecord) then
				rareIndex += 1
				targets[logRecord.UID] = { Stack = "Rare", Index = rareIndex }
			else
				normalIndex += 1
				targets[logRecord.UID] = { Stack = "Normal", Index = normalIndex }
			end
		end
	end
	return targets
end

local function makePickupFxPayload(claim, carryTarget, targetOffset, launchOffset)
	if not carryTarget or type(targetOffset) ~= "table" then return nil end
	local logRecord = claim.Entry.LogRecord
	local material = getMaterialDefinition(logRecord.SpeciesId)
	if not material then return nil end
	local palette = SpeciesVisuals.GetPalette(logRecord.SpeciesId)
	return {
		OwnerUserId = claim.OwnerUserId,
		UID = claim.UID,
		SpeciesId = logRecord.SpeciesId,
		Mutations = copyMutations(logRecord.Mutations),
		StartCFrame = claim.StartCFrame,
		BarkColor = palette.Bark,
		CutEndColor = palette.CutEnd,
		CarryVisualScale = material.CarryVisualScale,
		TargetStack = carryTarget.Stack,
		TargetIndex = carryTarget.Index,
		TargetOffset = targetOffset,
		TargetOffsetY = targetOffset.Y,
		LaunchOffset = launchOffset,
		PopDuration = PICKUP_POP_DURATION,
		FlightDuration = PICKUP_FLIGHT_DURATION,
		StartVisualScale = GROUND_DROP_VISUAL_SCALE,
		GroundToCarryScale = GROUND_DROP_VISUAL_SCALE,
	}
end

local function makeOverflowFxPayload(claim)
	local entry = claim.Entry
	local logRecord = entry.LogRecord
	local material = getMaterialDefinition(logRecord.SpeciesId)
	if not material or typeof(entry.PileTargetCFrame) ~= "CFrame" then return nil end
	local palette = SpeciesVisuals.GetPalette(logRecord.SpeciesId)
	return {
		Mode = "Overflow",
		OwnerUserId = claim.OwnerUserId,
		UID = claim.UID,
		SpeciesId = logRecord.SpeciesId,
		Mutations = copyMutations(logRecord.Mutations),
		StartCFrame = claim.StartCFrame,
		PileTargetCFrame = entry.PileTargetCFrame,
		BarkColor = palette.Bark,
		CutEndColor = palette.CutEnd,
		CarryVisualScale = material.CarryVisualScale,
		PopDuration = PICKUP_POP_DURATION,
		FlightDuration = OVERFLOW_FLIGHT_DURATION,
		StartVisualScale = GROUND_DROP_VISUAL_SCALE,
		GroundToCarryScale = GROUND_DROP_VISUAL_SCALE,
	}
end

local function getPendingGroundDrop(ownerUserId)
	local bundle = pendingGroundDropByUserId[ownerUserId]
	if not bundle then return nil, nil end
	local drop = activeGroundDrops[bundle]
	if not drop or not bundle:IsDescendantOf(Workspace) then
		activeGroundDrops[bundle] = nil
		pendingGroundDropByUserId[ownerUserId] = nil
		pilesByPlayer[ownerUserId] = nil
		if bundle.Parent then bundle:Destroy() end
		return nil, nil
	end
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
	pilesByPlayer[drop.OwnerUserId] = nil
	if bundle.Parent then bundle:Destroy() end
end

local function removeGroundDropLog(bundle, uid, expectedEntry)
	local drop = activeGroundDrops[bundle]
	local entry = drop and drop.LogRecordsByUid[uid]
	if not drop or not entry or (expectedEntry and entry ~= expectedEntry) then return false end

	-- Clear the UID before destroying its prompt/visual so repeated trigger or
	-- expiry callbacks cannot award the same record twice.
	drop.LogRecordsByUid[uid] = nil
	drop.Count -= 1
	unregisterPileMembership(drop.OwnerUserId, uid, entry)
	if entry.Model.Parent then entry.Model:Destroy() end
	if drop.Count <= 0 then
		clearGroundDropBundle(bundle, drop)
	end
	return true
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

local function animateGroundDropReveal(reveals)
	if #reveals == 0 then return end
	local startedAt = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - startedAt
		local alpha = math.clamp(elapsed / GROUND_LOG_REVEAL_DURATION, 0, 1)
		local eased = 1 - (1 - alpha) ^ 3
		for _, reveal in ipairs(reveals) do
			local entry = reveal.Entry
			local model = reveal.Model
			if isActiveGroundDropEntry(reveal.Bundle, reveal.Drop, reveal.UID, entry)
				and entry.PickupEnabled == false
				and model:GetAttribute("PickupEnabled") == false then
				local position = reveal.StartPosition:Lerp(reveal.FinalCFrame.Position, eased)
				position += Vector3.yAxis * (math.sin(math.pi * alpha) * GROUND_LOG_REVEAL_ARC_HEIGHT)
				-- Keep the log aligned with its final ground orientation throughout
				-- the reveal. The arc supplies the motion; no spin or wobble is needed.
				model:PivotTo(CFrame.new(position) * reveal.FinalCFrame.Rotation)

				for part, finalTransparency in pairs(entry.RevealPartTransparencies or {}) do
					if part.Parent then
						part.Transparency = 1 - ((1 - finalTransparency) * eased)
					end
				end
			end
		end

		if alpha >= 1 then
			connection:Disconnect()
			for _, reveal in ipairs(reveals) do
				local entry = reveal.Entry
				local model = reveal.Model
				if isActiveGroundDropEntry(reveal.Bundle, reveal.Drop, reveal.UID, entry)
					and entry.PickupEnabled == false
					and model:GetAttribute("PickupEnabled") == false then
					model:PivotTo(reveal.FinalCFrame)
					for part, finalTransparency in pairs(entry.RevealPartTransparencies or {}) do
						if part.Parent then
							part.Transparency = finalTransparency
						end
					end
					entry.RevealPartTransparencies = nil
				end
			end
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
						entry.RevealPartTransparencies = nil
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
		if processedCount >= MAX_PICKUP_BATCH then break end
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

	local overflowClaims = {}
	for _, overflow in ipairs(overflowCandidates) do
		-- All entries are server-owned and the ground object limit already bounds
		-- both available slots and total registry size to 96 per owner.
		if registerOverflowTransit(player, overflow.Entry, root) then
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
	end

	if drop.Count <= 0 then
		clearGroundDropBundle(bundle, drop)
	end
	LogService.NotifyState(player)
	local carryTargets = getCarryTargetByUid(data.Logs)
	for index, claim in ipairs(claims) do
		local launchOffset = math.min((index - 1) * PICKUP_LAUNCH_OFFSET_PER_LOG, MAX_PICKUP_LAUNCH_OFFSET)
		local targetOffset = LogCarryVisualService.GetTargetOffset(data.Logs, claim.UID)
		local payload = makePickupFxPayload(claim, carryTargets[claim.UID], targetOffset, launchOffset)
		if payload then
			-- Cosmetics are best-effort. Inventory was committed above and is never
			-- rolled back if client rendering or remote delivery fails.
			local fired, err = pcall(function()
				PickupLogFXRE:FireAllClients(payload)
			end)
			if not fired then
				warn("Could not broadcast picked-up log cosmetic", err)
			end
		end
		claim.Model:Destroy()
		task.delay(launchOffset + PICKUP_POP_DURATION + PICKUP_FLIGHT_DURATION, function()
			finishCarryArrival(player, claim.UID)
		end)
	end
	for _, overflow in ipairs(overflowClaims) do
		local payload = makeOverflowFxPayload(overflow)
		if payload then
			local fired, err = pcall(function()
				PickupLogFXRE:FireAllClients(payload)
			end)
			if not fired then
				warn("Could not broadcast overflow-log cosmetic", err)
			end
		end
		task.delay(OVERFLOW_TRANSIT_DURATION, function()
			finishOverflowTransit(bundle, drop, overflow.UID, overflow.Entry)
		end)
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

		local entry = {
			LogRecord = logRecord,
			Model = model,
			Bundle = bundle,
			Drop = drop,
			OwnerUserId = ownerUserId,
			HarvestBatchId = harvestBatchId,
			ReservedUntil = os.clock() + OWNER_RESERVATION_SECONDS,
			State = "Fresh",
			PileId = nil,
			PileSlot = nil,
			PickupEnabled = not hiddenUntilReveal,
			RevealPartTransparencies = if hiddenUntilReveal then revealTransparencyByPart else nil,
		}
		drop.LogRecordsByUid[logRecord.UID] = entry
		drop.Count += 1
		if hiddenUntilReveal then
			table.insert(reveals, {
				Bundle = bundle,
				Drop = drop,
				UID = logRecord.UID,
				Entry = entry,
				Model = model,
				StartPosition = startPosition,
				FinalCFrame = groundCFrame,
			})
		end

		task.delay(GROUND_LOG_LIFETIME_SECONDS, function()
			removeGroundDropLog(bundle, logRecord.UID, entry)
		end)
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
	local ownerBundle = pendingGroundDropByUserId[player.UserId]
	local ownerDrop = ownerBundle and activeGroundDrops[ownerBundle]
	if ownerBundle and ownerDrop then
		clearGroundDropBundle(ownerBundle, ownerDrop)
	elseif ownerBundle then
		pendingGroundDropByUserId[player.UserId] = nil
		if ownerBundle.Parent then ownerBundle:Destroy() end
	end
	for bundle, drop in pairs(activeGroundDrops) do
		if drop.OwnerUserId == player.UserId then
			clearGroundDropBundle(bundle, drop)
			break
		end
	end
	pilesByPlayer[player.UserId] = nil
	remoteBudgetByPlayer[player] = nil
	pendingCarryArrivalUids[player] = nil
	deferredCarryRecords[player] = nil
end)

return LogService
