-- Server-authoritative unique log inventory, ground pickups, and selling.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
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
local MAX_PICKUP_DISTANCE = 12
local REMOTE_INTERVALS = {
	Sell = 1,
	Lock = 0.15,
	Pickup = 0.25,
}

local economyRemotes = ReplicatedStorage:WaitForChild("Economy")
local GetLogsDataRF = economyRemotes:WaitForChild("GetLogsDataRF")
local GetSellSummaryRF = economyRemotes:WaitForChild("GetSellSummaryRF")
local SellUnlockedLogsRE = economyRemotes:WaitForChild("SellUnlockedLogsRE")
local SetLogLockedRE = economyRemotes:WaitForChild("SetLogLockedRE")
local EconomyStateUpdated = economyRemotes:WaitForChild("EconomyStateUpdated")

local profileLoaded = game.ServerScriptService.PlayerProfile.ProfileInit.ProfileLoadedEvent
local activeGroundDrops = {}
local pendingGroundDropByUserId = {}
local remoteBudgetByPlayer = {}
local logValueBySpecies = {}
local conflictingLogValues = {}
local pendingCarryArrivalUids = {}
local carryArrivalQueueByPlayer = {}
local carryArrivalRunnerByPlayer = {}
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

local function getHarvestVisualFolder()
	local folder = Workspace:FindFirstChild("HarvestLogVisuals")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "HarvestLogVisuals"
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

local function createLogVisualModel(name, logRecord)
	local model = Instance.new("Model")
	model.Name = name
	local handle, caps = SpeciesVisuals.CreateLogParts(logRecord, "LogHandle")
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
		end
	end
	return model, handle
end

local function tweenModelPivot(model, destination, duration, easingStyle, easingDirection)
	if not model.Parent then return false end
	local pivot = Instance.new("CFrameValue")
	pivot.Value = model:GetPivot()
	local connection = pivot:GetPropertyChangedSignal("Value"):Connect(function()
		if model.Parent then
			model:PivotTo(pivot.Value)
		end
	end)
	local tween = TweenService:Create(
		pivot,
		TweenInfo.new(duration, easingStyle or Enum.EasingStyle.Quad, easingDirection or Enum.EasingDirection.Out),
		{ Value = destination }
	)
	tween:Play()
	tween.Completed:Wait()
	connection:Disconnect()
	pivot:Destroy()
	return model.Parent ~= nil
end

local function tweenModelPivotAlongArc(model, getDestination, duration, arcHeight)
	if not model.Parent then return false end
	local initialDestination = getDestination()
	if not initialDestination then return false end

	local start = model:GetPivot()
	local startPosition = start.Position
	local lastDestination = initialDestination
	local progress = Instance.new("NumberValue")
	progress.Value = 0
	local connection = progress:GetPropertyChangedSignal("Value"):Connect(function()
		if model.Parent then
			local destination = getDestination()
			if destination then
				lastDestination = destination
			end

			local alpha = progress.Value
			local destinationPosition = lastDestination.Position
			-- A quadratic arc adds 4h*t*(1-t) to the straight start-to-target
			-- path. That puts the log about arcHeight studs above the path at
			-- mid-flight, with a natural upward launch and downward arrival.
			local position = startPosition:Lerp(destinationPosition, alpha)
				+ Vector3.new(0, 4 * arcHeight * alpha * (1 - alpha), 0)

			local rotation = start - startPosition
			model:PivotTo(CFrame.new(position) * rotation)
		end
	end)
	local tween = TweenService:Create(
		progress,
		TweenInfo.new(duration, Enum.EasingStyle.Linear),
		{ Value = 1 }
	)
	tween:Play()
	tween.Completed:Wait()
	connection:Disconnect()
	local finalDestination = getDestination()
	if model.Parent and finalDestination then
		model:PivotTo(finalDestination)
	end
	progress:Destroy()
	return model.Parent ~= nil
end

-- The inventory record is already committed before this runs. This is a
-- replicated, disposable presentation of a real reward, never its authority.
local function playHarvestArrival(player, logRecord, origin, arrivalIndex)
	local ok, err = xpcall(function()
		local model, handle = createLogVisualModel("HarvestLog", logRecord)
		model:SetAttribute("OwnerUserId", player.UserId)
		local angle = (arrivalIndex - 1) * 2.399963229728653
		local radius = 1.2 + ((arrivalIndex - 1) % 3) * 0.35
		local horizontalOffset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local landingPosition = Vector3.new(
			origin.X + horizontalOffset.X,
			getGroundHeight(origin) + handle.Size.Y * 0.5 + 0.08,
			origin.Z + horizontalOffset.Z
		)
		local landing = CFrame.new(landingPosition)
		model:PivotTo(landing * CFrame.new(0, 3.4, 0))
		model.Parent = getHarvestVisualFolder()

		tweenModelPivot(model, landing, 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tweenModelPivot(model, landing * CFrame.new(0, 0.28, 0), 0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		tweenModelPivot(model, landing, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.28)

		-- Take one full authoritative snapshot for the batch. It includes sibling
		-- arrivals, so the arcs have distinct final slots without normalizing the
		-- player profile every frame during the flight.
		local stagedRecords = LogService.GetOwnedLogs(player)
		local function getArrivalCFrame()
			if not stagedRecords then return nil end
			return LogCarryVisualService.GetArrivalCFrame(player, stagedRecords, logRecord.UID)
		end

		if model.Parent and getArrivalCFrame() then
			model:SetAttribute("PickupFlightStarted", true)
			-- Every log in the harvest batch launches together. Tiny per-index
			-- arrival offsets preserve the inventory's append order while keeping
			-- the stack integrations visually simultaneous.
			local flightDuration = 1.0 + (arrivalIndex - 1) * 0.08
			tweenModelPivotAlongArc(model, getArrivalCFrame, flightDuration, 20)
		end
		if model.Parent then
			model:Destroy()
		end
	end, debug.traceback)
	if not ok then
		warn("Harvest log visual failed", err)
	end
end

local function processCarryArrivalQueue(player)
	if carryArrivalRunnerByPlayer[player] then return end
	carryArrivalRunnerByPlayer[player] = true

	task.spawn(function()
		local queue = carryArrivalQueueByPlayer[player]
		while queue and #queue > 0 and player:IsDescendantOf(Players) do
			local batch = table.remove(queue, 1)
			local completedSignal = Instance.new("BindableEvent")
			local completedCount = 0

			for _, arrival in ipairs(batch) do
				local currentArrival = arrival
				task.spawn(function()
					playHarvestArrival(player, currentArrival.LogRecord, currentArrival.Origin, currentArrival.Index)

					local pendingUids = pendingCarryArrivalUids[player]
					if pendingUids then
						pendingUids[currentArrival.LogRecord.UID] = nil
						if next(pendingUids) == nil then
							pendingCarryArrivalUids[player] = nil
						end
					end

					local visibleRecords = getVisibleCarryRecords(player)
					if visibleRecords then
						rebuildCarryVisuals(player, visibleRecords)
					end

					completedCount += 1
					completedSignal:Fire()
				end)
			end

			while completedCount < #batch do
				completedSignal.Event:Wait()
			end
			completedSignal:Destroy()
			queue = carryArrivalQueueByPlayer[player]
		end

		carryArrivalRunnerByPlayer[player] = nil
		if not player:IsDescendantOf(Players) then
			carryArrivalQueueByPlayer[player] = nil
			pendingCarryArrivalUids[player] = nil
			deferredCarryRecords[player] = nil
			return
		end

		queue = carryArrivalQueueByPlayer[player]
		if queue and #queue > 0 then
			processCarryArrivalQueue(player)
			return
		end
		carryArrivalQueueByPlayer[player] = nil
		pendingCarryArrivalUids[player] = nil

		local records = LogService.GetOwnedLogs(player) or deferredCarryRecords[player]
		deferredCarryRecords[player] = nil
		if records then
			rebuildCarryVisuals(player, records)
		end
	end)
end

local function enqueueCarryArrivals(player, logRecords, origin)
	if #logRecords == 0 then return end
	local queue = carryArrivalQueueByPlayer[player]
	if not queue then
		queue = {}
		carryArrivalQueueByPlayer[player] = queue
	end
	local pendingUids = pendingCarryArrivalUids[player]
	if not pendingUids then
		pendingUids = {}
		pendingCarryArrivalUids[player] = pendingUids
	end
	local batch = {}
	for index, logRecord in ipairs(logRecords) do
		pendingUids[logRecord.UID] = true
		table.insert(batch, {
			LogRecord = logRecord,
			Origin = origin,
			Index = index,
		})
	end
	table.insert(queue, batch)
	processCarryArrivalQueue(player)
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

local function tryPickupGroundLog(player, bundle, uid, visualModel)
	local drop = activeGroundDrops[bundle]
	local entry = drop and drop.LogRecordsByUid[uid]
	local model = entry and entry.Model
	local handle = model and model.PrimaryPart
	if not drop or not entry or model ~= visualModel or not bundle:IsDescendantOf(Workspace)
		or not model:IsDescendantOf(bundle) or not handle then
		return false
	end
	if not consumeRemoteBudget(player, "Pickup") then return false end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then return false end
	if (root.Position - handle.Position).Magnitude > MAX_PICKUP_DISTANCE then return false end
	if player.UserId ~= drop.OwnerUserId then return false end

	local data = getPlayerData(player)
	if not data or logCount(data) >= data.LogCapacity then return false end
	if findLog(data, uid) then return false end

	-- Remove the server registry entry before mutating the profile or destroying
	-- the physical pickup. Prompt spam cannot award the same UID twice.
	drop.LogRecordsByUid[uid] = nil
	drop.Count -= 1
	table.insert(data.Logs, entry.LogRecord)
	if drop.Count <= 0 then
		clearGroundDropBundle(bundle, drop)
	elseif model.Parent then
		model:Destroy()
	end
	LogService.NotifyState(player)
	return true
end

local function spawnGroundDrops(logRecords, ownerUserId, position)
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

	for index, logRecord in ipairs(logRecords) do
		local model, handle = createLogVisualModel("DroppedLog", logRecord)
		local horizontalOffset = Vector3.new(0, 0, (index - (#logRecords + 1) * 0.5) * 0.9)
		local landingPosition = position + horizontalOffset
		model:PivotTo(CFrame.new(
			landingPosition.X,
			getGroundHeight(landingPosition) + handle.Size.Y * 0.5 + 0.08,
			landingPosition.Z
		))
		model:SetAttribute("UID", logRecord.UID)
		model:SetAttribute("ItemType", "Log")
		model:SetAttribute("SpeciesId", logRecord.SpeciesId)
		model:SetAttribute("OwnerUserId", ownerUserId)
		model:SetAttribute("OwnerReservationSeconds", OWNER_RESERVATION_SECONDS)
		model.Parent = bundle

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PickupPrompt"
		prompt.ActionText = "Pick up"
		prompt.ObjectText = tostring(logRecord.SpeciesId) .. " log"
		prompt.HoldDuration = 0.15
		prompt.MaxActivationDistance = MAX_PICKUP_DISTANCE
		prompt.RequiresLineOfSight = false
		prompt.Parent = handle

		local entry = {
			LogRecord = logRecord,
			Model = model,
			ReservedUntil = os.clock() + OWNER_RESERVATION_SECONDS,
		}
		drop.LogRecordsByUid[logRecord.UID] = entry
		drop.Count += 1
		prompt.Triggered:Connect(function(player)
			tryPickupGroundLog(player, bundle, logRecord.UID, model)
		end)

		task.delay(GROUND_LOG_LIFETIME_SECONDS, function()
			removeGroundDropLog(bundle, logRecord.UID, entry)
		end)
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

function LogService.AwardTreeLog(tree, contributions)
	if not tree or tree.YieldsLog ~= true then return false end
	if type(tree.SpeciesId) ~= "string"
		or not logValueBySpecies[tree.SpeciesId]
		or not isFinitePositive(tree.LogValue)
		or math.floor(tree.LogValue + 0.5) ~= logValueBySpecies[tree.SpeciesId] then
		return false
	end
	local rewardCount = getTreeLogYieldCount(tree)
	if not rewardCount or rewardCount > MAX_HARVEST_LOGS then return false end

	local winner
	local winnerUserId
	local winnerDamage = -1
	for userId, contribution in pairs(contributions or {}) do
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
	local inventorySpace = math.max(0, data.LogCapacity - logCount(data))
	local inventoryRecords = {}
	local overflowRecords = {}
	for index = 1, rewardCount do
		local logRecord = createLogRecord(tree)
		if index <= inventorySpace then
			table.insert(inventoryRecords, logRecord)
		else
			table.insert(overflowRecords, logRecord)
		end
	end

	local origin
	if tree.InteractionPart and tree.InteractionPart:IsA("BasePart") then
		origin = tree.InteractionPart.Position
	elseif typeof(tree.CFrame) == "CFrame" then
		origin = tree.CFrame.Position
	else
		origin = Vector3.zero
	end

	-- Preflight the bounded owner-only overflow before adding any records so a
	-- full inventory never receives only part of a size-tier reward.
	if #overflowRecords > 0 and not canSpawnGroundDrops(winner.UserId, #overflowRecords) then
		return false
	end
	if #overflowRecords > 0 and not spawnGroundDrops(overflowRecords, winner.UserId, origin) then
		return false
	end

	for _, logRecord in ipairs(inventoryRecords) do
		table.insert(data.Logs, logRecord)
	end
	if #inventoryRecords > 0 then
		-- UIDs are committed before any presentation runs. Arrivals are serialized
		-- per player and each settled UID is added to the back stack individually.
		enqueueCarryArrivals(winner, inventoryRecords, origin)
	end
	LogService.NotifyState(winner)
	return true
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

profileLoaded.Event:Connect(function(player)
	getPlayerData(player)
	LogService.NotifyState(player)
end)

Players.PlayerRemoving:Connect(function(player)
	remoteBudgetByPlayer[player] = nil
	pendingCarryArrivalUids[player] = nil
	carryArrivalQueueByPlayer[player] = nil
	carryArrivalRunnerByPlayer[player] = nil
	deferredCarryRecords[player] = nil
end)

return LogService
