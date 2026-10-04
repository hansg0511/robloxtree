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
local pendingCarryArrivals = {}
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

local function beginCarryArrival(player)
	pendingCarryArrivals[player] = (pendingCarryArrivals[player] or 0) + 1
end

local function finishCarryArrival(player)
	local remaining = math.max(0, (pendingCarryArrivals[player] or 1) - 1)
	if remaining > 0 then
		pendingCarryArrivals[player] = remaining
		return
	end
	pendingCarryArrivals[player] = nil
	local records = deferredCarryRecords[player] or LogService.GetOwnedLogs(player)
	deferredCarryRecords[player] = nil
	if records then
		rebuildCarryVisuals(player, records)
	end
end

LogService.LogsChanged:Connect(function(player, records)
	if (pendingCarryArrivals[player] or 0) > 0 then
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

local function getCarryArrivalCFrame(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
	if not humanoid or humanoid.Health <= 0 or not torso or not torso:IsA("BasePart") then
		return nil
	end
	return torso.CFrame * CFrame.new(0, 0.5, 0.7)
end

-- The inventory record is already committed before this runs. This is a
-- replicated, disposable presentation of a real reward, never its authority.
local function playHarvestArrival(player, logRecord, origin)
	task.spawn(function()
		local ok, err = xpcall(function()
			local model, handle = createLogVisualModel("HarvestLog", logRecord)
			local horizontalOffset = Vector3.new(math.random(-18, 18) / 10, 0, math.random(-18, 18) / 10)
			local landingPosition = Vector3.new(
				origin.X + horizontalOffset.X,
				getGroundHeight(origin) + handle.Size.Y * 0.5 + 0.08,
				origin.Z + horizontalOffset.Z
			)
			local landing = CFrame.new(landingPosition) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0)
			model:PivotTo(landing * CFrame.new(0, 3.4, 0))
			model.Parent = getHarvestVisualFolder()

			tweenModelPivot(model, landing, 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tweenModelPivot(model, landing * CFrame.new(0, 0.28, 0), 0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			tweenModelPivot(model, landing, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.wait(0.28)

			local arrival = getCarryArrivalCFrame(player)
			if arrival and model.Parent then
				tweenModelPivot(model, arrival, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
			if model.Parent then
				model:Destroy()
			end
		end, debug.traceback)
		if not ok then
			warn("Harvest log visual failed", err)
		end
		finishCarryArrival(player)
	end)
end

local function tryPickupGroundLog(player, model)
	local drop = activeGroundDrops[model]
	local handle = model and model.PrimaryPart
	if not drop or not model.Parent or not model:IsDescendantOf(Workspace) or not handle then return false end
	if not consumeRemoteBudget(player, "Pickup") then return false end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then return false end
	if (root.Position - handle.Position).Magnitude > MAX_PICKUP_DISTANCE then return false end
	if player.UserId ~= drop.OwnerUserId then return false end

	local data = getPlayerData(player)
	if not data or logCount(data) >= data.LogCapacity then return false end
	if findLog(data, drop.LogRecord.UID) then return false end

	-- Remove the server registry entry before mutating the profile or destroying
	-- the physical pickup. Prompt spam cannot award the same UID twice.
	activeGroundDrops[model] = nil
	if pendingGroundDropByUserId[drop.OwnerUserId] == model then
		pendingGroundDropByUserId[drop.OwnerUserId] = nil
	end
	table.insert(data.Logs, drop.LogRecord)
	model:Destroy()
	LogService.NotifyState(player)
	return true
end

local function spawnGroundDrop(logRecord, ownerUserId, position)
	if pendingGroundDropByUserId[ownerUserId] then
		return false
	end
	local model, handle = createLogVisualModel("DroppedLog", logRecord)
	model:PivotTo(CFrame.new(
		position.X,
		getGroundHeight(position) + handle.Size.Y * 0.5 + 0.08,
		position.Z
	))
	model:SetAttribute("UID", logRecord.UID)
	model:SetAttribute("ItemType", "Log")
	model:SetAttribute("SpeciesId", logRecord.SpeciesId)
	model:SetAttribute("OwnerUserId", ownerUserId)
	model:SetAttribute("OwnerReservationSeconds", OWNER_RESERVATION_SECONDS)
	model.Parent = getGroundDropFolder()

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.ActionText = "Pick up"
	prompt.ObjectText = tostring(logRecord.SpeciesId) .. " log"
	prompt.HoldDuration = 0.15
	prompt.MaxActivationDistance = MAX_PICKUP_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = handle

	activeGroundDrops[model] = {
		LogRecord = logRecord,
		OwnerUserId = ownerUserId,
		ReservedUntil = os.clock() + OWNER_RESERVATION_SECONDS,
	}
	pendingGroundDropByUserId[ownerUserId] = model
	prompt.Triggered:Connect(function(player)
		tryPickupGroundLog(player, model)
	end)

	task.delay(GROUND_LOG_LIFETIME_SECONDS, function()
		if activeGroundDrops[model] then
			local dropped = activeGroundDrops[model]
			activeGroundDrops[model] = nil
			if pendingGroundDropByUserId[dropped.OwnerUserId] == model then
				pendingGroundDropByUserId[dropped.OwnerUserId] = nil
			end
			if model.Parent then model:Destroy() end
		end
	end)
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

function LogService.AwardTreeLog(tree, contributions)
	if not tree or tree.YieldsLog ~= true then return false end
	if type(tree.SpeciesId) ~= "string"
		or not logValueBySpecies[tree.SpeciesId]
		or not isFinitePositive(tree.LogValue)
		or math.floor(tree.LogValue + 0.5) ~= logValueBySpecies[tree.SpeciesId] then
		return false
	end

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
	local logRecord = createLogRecord(tree)
	local origin = tree.InteractionPart and tree.InteractionPart.Position or tree.CFrame.Position
	if logCount(data) < data.LogCapacity then
		table.insert(data.Logs, logRecord)
		beginCarryArrival(winner)
		LogService.NotifyState(winner)
		-- This starts after the persistent commit and leaves the just-earned
		-- record out of the back stack until the visible flight completes.
		playHarvestArrival(winner, logRecord, origin)
	else
		if not spawnGroundDrop(logRecord, winner.UserId, origin) then
			return false
		end
		LogService.NotifyState(winner)
	end
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
	pendingCarryArrivals[player] = nil
	deferredCarryRecords[player] = nil
end)

return LogService
