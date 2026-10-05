-- Server-authoritative unique log inventory, ground pickups, and selling.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ProfileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local EconomyManager = require(game.ServerScriptService.Economy.EconomyManager)
local TreeDefinitions = require(game.ServerScriptService.Trees.TreeDefinitions)
local SpeciesVisuals = require(game.ServerStorage:WaitForChild("SpeciesVisuals"))
local BaseStationAccess = require(game.ServerScriptService.WorldLayout.BaseStationAccess)
local LogCarryVisualService = require(game.ServerScriptService.Inventory.LogCarryVisualService)

local LogService = {}
local logsChangedEvent = Instance.new("BindableEvent")
LogService.LogsChanged = logsChangedEvent.Event

local DEFAULT_CAPACITY = 10
local MAX_CAPACITY = 40
local MAX_HARVEST_LOGS = 3
local MAX_GROUND_LOG_DROPS_PER_PLAYER = MAX_CAPACITY
local OWNER_RESERVATION_SECONDS = 60
-- Overflow is deliberately short-lived. The owner has the full lifetime to
-- free a slot and recover the exact UID; it is not converted into a public
-- loot race after the reservation expires.
local GROUND_LOG_LIFETIME_SECONDS = 60
local MAX_PICKUP_DISTANCE = 15
-- A single legitimate proximity request may collect a whole nearby tree reward.
-- This stays bounded by both capacity and this fixed server-side ceiling.
local MAX_PICKUP_BATCH = MAX_CAPACITY
local PICKUP_POP_DURATION = 0.10
local PICKUP_FLIGHT_DURATION = 0.36
local PICKUP_LAUNCH_OFFSET_PER_LOG = 0.015
local MAX_PICKUP_LAUNCH_OFFSET = 0.08
local GROUND_LOG_REVEAL_DURATION = 0.36
local GROUND_LOG_REVEAL_ARC_HEIGHT = 2.5
local GROUND_LOG_READABLE_PAUSE = 0.2
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
local remoteBudgetByPlayer = {}
local logValueBySpecies = {}
local conflictingLogValues = {}
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

for _, definition in pairs(TreeDefinitions) do
	if type(definition) == "table"
		and type(definition.SpeciesId) == "string"
		and isFinitePositive(definition.LogValue) then
		local baselineLogValue = math.floor(definition.LogValue + 0.5)
		local existingValue = logValueBySpecies[definition.SpeciesId]
		if existingValue and existingValue ~= baselineLogValue then
			conflictingLogValues[definition.SpeciesId] = true
		else
			logValueBySpecies[definition.SpeciesId] = baselineLogValue
		end
	end
end

for speciesId in pairs(conflictingLogValues) do
	logValueBySpecies[speciesId] = nil
	warn(string.format("Conflicting baseline log values found for species %q; logs of this species will not be awarded or sold", speciesId))
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
	if type(profile.Data.LogCapacity) ~= "number"
		or profile.Data.LogCapacity ~= profile.Data.LogCapacity
		or profile.Data.LogCapacity < 1 then
		profile.Data.LogCapacity = DEFAULT_CAPACITY
	end
	profile.Data.LogCapacity = math.clamp(math.floor(profile.Data.LogCapacity), 1, MAX_CAPACITY)
	if type(profile.Data.Coins) ~= "number"
		or profile.Data.Coins ~= profile.Data.Coins
		or profile.Data.Coins < 0
		or profile.Data.Coins == math.huge then
		profile.Data.Coins = 0
	end
	return profile.Data
end

local function getLogValue(logRecord)
	if type(logRecord) ~= "table" or logRecord.ItemType ~= "Log" then return nil end
	return logValueBySpecies[logRecord.SpeciesId]
end

local function makeClientSnapshot(player)
	local data = getPlayerData(player)
	if not data then return nil end

	local logs = {}
	for _, logRecord in ipairs(data.Logs) do
		if isValidUid(logRecord.UID) then
			local value = getLogValue(logRecord) or 0
			table.insert(logs, {
				UID = logRecord.UID,
				ItemType = "Log",
				SpeciesId = logRecord.SpeciesId,
				Mutations = copyMutations(logRecord.Mutations),
				Locked = logRecord.Locked == true,
				CreatedAt = type(logRecord.CreatedAt) == "number" and logRecord.CreatedAt or 0,
				LogValue = value,
				EstimatedSellValue = value,
			})
		end
	end

	return {
		Logs = logs,
		Capacity = data.LogCapacity,
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

	return {
		EligibleCount = eligibleCount,
		TotalValue = totalValue,
		Coins = data.Coins,
	}
end

function LogService.NotifyState(player)
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

	local trunkRadius = primary and math.max(primary.Size.X, primary.Size.Z) * 0.5 or 0

	return {
		Origin = origin,
		Direction = direction,
		Perpendicular = Vector3.new(-direction.Z, 0, direction.X),
		TrunkLength = trunkLength,
		-- Keep visible drops beside the fallen trunk instead of burying them under
		-- its body. The small per-log variation is only for legibility.
		DropSideOffset = math.max(2.2, trunkRadius + 1.8),
	}
end

local function getFallPathPosition(fallPlacement, index, totalCount)
	local count = math.max(1, math.floor(tonumber(totalCount) or 1))
	local rank = math.clamp(math.floor(tonumber(index) or 1), 1, count)
	local fraction = if count == 1 then 0.5 else 0.3 + 0.4 * ((rank - 1) / (count - 1))
	local sideOffset = fallPlacement.DropSideOffset + (rank - (count + 1) * 0.5) * 1.3
	return fallPlacement.Origin
		+ fallPlacement.Direction * (fallPlacement.TrunkLength * fraction)
		+ fallPlacement.Perpendicular * sideOffset
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

local function makePickupFxPayload(claim, carryTarget, launchOffset)
	if not carryTarget then return nil end
	local logRecord = claim.Entry.LogRecord
	local palette = SpeciesVisuals.GetPalette(logRecord.SpeciesId)
	return {
		OwnerUserId = claim.OwnerUserId,
		UID = claim.UID,
		SpeciesId = logRecord.SpeciesId,
		Mutations = copyMutations(logRecord.Mutations),
		StartCFrame = claim.StartCFrame,
		BarkColor = palette.Bark,
		CutEndColor = palette.CutEnd,
		TargetStack = carryTarget.Stack,
		TargetIndex = carryTarget.Index,
		LaunchOffset = launchOffset,
		PopDuration = PICKUP_POP_DURATION,
		FlightDuration = PICKUP_FLIGHT_DURATION,
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
		or model.Parent ~= bundle or not handle then
		return rejectPickup(player, uid, "invalid registry/model mismatch")
	end
	if entry.PickupEnabled ~= true or model:GetAttribute("PickupEnabled") ~= true then
		return rejectPickup(player, uid, "reveal pending")
	end
	if player.UserId ~= drop.OwnerUserId then
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
	if logCount(data) >= data.LogCapacity then
		return rejectPickup(player, uid, "bag full")
	end
	if findLog(data, uid) then
		return rejectPickup(player, uid, "duplicate UID already owned")
	end
	if not consumeRemoteBudget(player, "Pickup") then
		return rejectPickup(player, uid, "rate limited")
	end

	-- The client nominated only this first model. The server independently finds
	-- the rest of the owner-reserved, in-range batch, so huge-tree pickups feel
	-- simultaneous without allowing a client to choose extra rewards or amounts.
	local availableSlots = math.min(data.LogCapacity - logCount(data), MAX_PICKUP_BATCH)
	local nearby = {}
	for candidateUid, candidateEntry in pairs(drop.LogRecordsByUid) do
		local candidateModel = candidateEntry.Model
		local candidateHandle = candidateModel and candidateModel.PrimaryPart
		if candidateUid ~= uid
			and candidateEntry.HarvestBatchId == entry.HarvestBatchId
			and candidateEntry.PickupEnabled == true
			and candidateModel
			and candidateModel.Parent == bundle
			and candidateModel:GetAttribute("PickupEnabled") == true
			and candidateHandle
			and os.clock() <= candidateEntry.ReservedUntil
			and (root.Position - candidateHandle.Position).Magnitude <= MAX_PICKUP_DISTANCE
			and not findLog(data, candidateUid) then
			table.insert(nearby, {
			UID = candidateUid,
			Entry = candidateEntry,
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
		{ UID = uid, Entry = entry, Model = model, StartCFrame = model:GetPivot(), OwnerUserId = player.UserId },
	}
	for _, candidate in ipairs(nearby) do
		if #claims >= availableSlots then break end
		table.insert(claims, {
			UID = candidate.UID,
			Entry = candidate.Entry,
			Model = candidate.Entry.Model,
			StartCFrame = candidate.Entry.Model:GetPivot(),
			OwnerUserId = player.UserId,
		})
	end

	-- Atomically claim every selected UID before any visual delay or profile
	-- mutation. Repeated remotes cannot award or animate the same record twice.
	local pendingUids = pendingCarryArrivalUids[player]
	if not pendingUids then
		pendingUids = {}
		pendingCarryArrivalUids[player] = pendingUids
	end
	for _, claim in ipairs(claims) do
		drop.LogRecordsByUid[claim.UID] = nil
		drop.Count -= 1
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
		local payload = makePickupFxPayload(claim, carryTargets[claim.UID], launchOffset)
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
		local startPosition = groundCFrame.Position
		if hiddenUntilReveal then
			local revealRank = math.clamp(revealIndex, 1, revealCount)
			local footprintPosition = fallPlacement.Origin
				+ fallPlacement.Direction * math.min(fallPlacement.TrunkLength * 0.12, 3)
				+ fallPlacement.Perpendicular * ((revealRank - (revealCount + 1) * 0.5) * 0.65)
			startPosition = Vector3.new(
				footprintPosition.X,
				getGroundHeight(footprintPosition) + handle.Size.Y * 0.5 + 0.08,
				footprintPosition.Z
			)
			model:PivotTo(CFrame.new(startPosition) * groundCFrame.Rotation)
		else
			model:PivotTo(groundCFrame)
		end
		model:SetAttribute("UID", logRecord.UID)
		model:SetAttribute("ItemType", "Log")
		model:SetAttribute("SpeciesId", logRecord.SpeciesId)
		model:SetAttribute("OwnerUserId", ownerUserId)
		model:SetAttribute("OwnerReservationSeconds", OWNER_RESERVATION_SECONDS)
		model:SetAttribute("HarvestBatchId", harvestBatchId)
		model:SetAttribute("PickupEnabled", not hiddenUntilReveal)
		model.Parent = bundle

		local entry = {
			LogRecord = logRecord,
			Model = model,
			HarvestBatchId = harvestBatchId,
			ReservedUntil = os.clock() + OWNER_RESERVATION_SECONDS,
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
	local sizeScale = tree and tree.SizeScale
	if not isFinitePositive(sizeScale) then return nil end

	-- These thresholds match the server-owned rollTreeScale bands: small trees
	-- yield one log, ordinary trees two, and the largest trees three.
	if sizeScale < 0.7 then
		return 1
	elseif sizeScale < 1.3 then
		return 2
	end
	return MAX_HARVEST_LOGS
end

function LogService.CaptureTreeLogAward(tree, contributions, fallRotation)
	if not tree or tree.YieldsLog ~= true then return nil end

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
		LogValue = tree.LogValue,
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
	if type(awardSnapshot.SpeciesId) ~= "string"
		or not logValueBySpecies[awardSnapshot.SpeciesId]
		or not isFinitePositive(awardSnapshot.LogValue)
		or math.floor(awardSnapshot.LogValue + 0.5) ~= logValueBySpecies[awardSnapshot.SpeciesId] then
		return false
	end
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

LogService.DEFAULT_CAPACITY = DEFAULT_CAPACITY
LogService.MAX_CAPACITY = MAX_CAPACITY
LogService.CAPACITY_STEPS = { 10, 15, 20, 30, 40 }

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
	remoteBudgetByPlayer[player] = nil
	pendingCarryArrivalUids[player] = nil
	deferredCarryRecords[player] = nil
end)

return LogService
