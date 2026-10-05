-- Requests owner-reserved ground-log pickups when the owner walks close enough.
-- The server resolves and validates every candidate before changing inventory.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local pickupRemote = ReplicatedStorage:WaitForChild("Economy"):WaitForChild("PickupGroundLogRE")

-- Keep the client cadence slower than the server's 0.08s minimum arrival gap,
-- with margin for timing jitter. Server validation remains authoritative.
local MAX_PICKUP_DISTANCE = 15
local SCAN_INTERVAL = 0.05
local REQUEST_INTERVAL = 0.12
local PER_MODEL_RETRY_INTERVAL = 0.25
local RECONCILE_INTERVAL = 1.5
local WORLD_LOG_DROPS_NAME = "WorldLogDrops"

-- Enable temporarily while diagnosing pickup behavior; keep false in production.
local DEBUG = false

local scanElapsed = 0
local reconcileElapsed = 0
local nextRequestAt = 0
local lastRequestAtByModel = setmetatable({}, { __mode = "k" })
local candidateModels = {}
local activeDropsFolder = nil
local folderConnections = {}

local function debugLog(message)
	if DEBUG then
		print("[AutoPickupGroundLogs] " .. message)
	end
end

local function getCurrentDropsFolder()
	local folder = Workspace:FindFirstChild(WORLD_LOG_DROPS_NAME)
	if folder and folder:IsA("Folder") then
		return folder
	end
	return nil
end

local function isActiveDropsFolderCurrent()
	return activeDropsFolder ~= nil
		and activeDropsFolder.Parent == Workspace
		and activeDropsFolder.Name == WORLD_LOG_DROPS_NAME
		and getCurrentDropsFolder() == activeDropsFolder
end

local function getLivingCharacterRoot()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then return nil end
	return root
end

local function isDropCandidate(instance)
	return instance:IsA("Model") and instance.Name == "DroppedLog"
end

local function getOwnedDropInfo(instance, folderIsCurrent)
	if not folderIsCurrent or not isDropCandidate(instance) or not instance:IsDescendantOf(activeDropsFolder) then
		return nil
	end
	if instance:GetAttribute("ItemType") ~= "Log"
		or instance:GetAttribute("OwnerUserId") ~= localPlayer.UserId then
		return nil
	end

	local uid = instance:GetAttribute("UID")
	local handle = instance.PrimaryPart
	if type(uid) ~= "string" or #uid == 0 or not handle or not handle:IsA("BasePart")
		or not handle:IsDescendantOf(instance) then
		return nil
	end

	return uid, handle
end

local function findNearestOwnedDrop(root, now)
	local nearestModel = nil
	local nearestUid = nil
	local nearestDistance = MAX_PICKUP_DISTANCE
	if not isActiveDropsFolderCurrent() then
		return nearestModel, nearestUid, nearestDistance
	end

	for instance in pairs(candidateModels) do
		local uid, handle = getOwnedDropInfo(instance, true)
		if uid and handle then
			local lastRequestAt = lastRequestAtByModel[instance] or -math.huge
			if now - lastRequestAt >= PER_MODEL_RETRY_INTERVAL then
				local distance = (root.Position - handle.Position).Magnitude
				if distance <= nearestDistance then
					nearestModel = instance
					nearestUid = uid
					nearestDistance = distance
				end
			end
		end
	end

	return nearestModel, nearestUid, nearestDistance
end

local function addCandidate(instance)
	if isDropCandidate(instance) and not candidateModels[instance] then
		candidateModels[instance] = true
		debugLog("add candidate " .. instance:GetFullName())
	end
end

local function removeCandidate(instance)
	if candidateModels[instance] then
		candidateModels[instance] = nil
		lastRequestAtByModel[instance] = nil
		debugLog("remove candidate " .. instance:GetFullName())
	end
end

local refreshDropsFolder

local function disconnectFolderBindings()
	for _, connection in ipairs(folderConnections) do
		connection:Disconnect()
	end
	table.clear(folderConnections)
end

local function bindDropsFolder(folder)
	activeDropsFolder = folder
	local function isCurrentBinding()
		return activeDropsFolder == folder
			and folder.Parent == Workspace
			and folder.Name == WORLD_LOG_DROPS_NAME
			and getCurrentDropsFolder() == folder
	end

	table.insert(folderConnections, folder.DescendantAdded:Connect(function(instance)
		if isCurrentBinding() then
			addCandidate(instance)
		end
	end))
	table.insert(folderConnections, folder.DescendantRemoving:Connect(function(instance)
		if isCurrentBinding() then
			removeCandidate(instance)
		end
	end))
	table.insert(folderConnections, folder.AncestryChanged:Connect(function()
		if not isCurrentBinding() then
			refreshDropsFolder()
		end
	end))
	table.insert(folderConnections, folder:GetPropertyChangedSignal("Name"):Connect(function()
		if not isCurrentBinding() then
			refreshDropsFolder()
		end
	end))

	-- Seed drops that existed before the folder was bound.
	for _, instance in ipairs(folder:GetDescendants()) do
		if isCurrentBinding() then
			addCandidate(instance)
		end
	end
	debugLog("bound folder " .. folder:GetFullName())
end

refreshDropsFolder = function()
	local folder = getCurrentDropsFolder()
	if folder == activeDropsFolder then
		return
	end

	disconnectFolderBindings()
	local oldFolder = activeDropsFolder
	activeDropsFolder = nil
	for instance in pairs(candidateModels) do
		removeCandidate(instance)
	end

	if folder then
		bindDropsFolder(folder)
	else
		debugLog(oldFolder and "active folder removed" or "active folder unavailable")
	end
end

local function reconcileCandidates()
	refreshDropsFolder()
	local folder = activeDropsFolder
	local seen = {}
	local addedCount = 0
	local removedCount = 0
	local cachedCount = 0

	if folder and isActiveDropsFolderCurrent() then
		for _, instance in ipairs(folder:GetDescendants()) do
			if isDropCandidate(instance) then
				seen[instance] = true
				if not candidateModels[instance] then
					addCandidate(instance)
					addedCount += 1
				end
			end
		end
	end

	for instance in pairs(candidateModels) do
		if not seen[instance] then
			removeCandidate(instance)
			removedCount += 1
		end
	end
	for _ in pairs(candidateModels) do
		cachedCount += 1
	end

	local folderName = folder and folder:GetFullName() or "none"
	debugLog(string.format(
		"reconcile folder=%s cached=%d added=%d removed=%d",
		folderName,
		cachedCount,
		addedCount,
		removedCount
	))
end

local function logCandidateSummary(root)
	if not DEBUG then return end
	local cachedCount = 0
	local ownedValidCount = 0
	local nearestUid = nil
	local nearestDistance = math.huge
	local folderIsCurrent = isActiveDropsFolderCurrent()

	for instance in pairs(candidateModels) do
		cachedCount += 1
		local uid, handle = getOwnedDropInfo(instance, folderIsCurrent)
		if uid and handle then
			ownedValidCount += 1
			if root then
				local distance = (root.Position - handle.Position).Magnitude
				if distance < nearestDistance then
					nearestUid = uid
					nearestDistance = distance
				end
			end
		end
	end

	local nearest = "none"
	if nearestUid then
		nearest = string.format("%s at %.1f studs", nearestUid, nearestDistance)
	end
	debugLog(string.format(
		"summary cached=%d ownedValid=%d nearest=%s",
		cachedCount,
		ownedValidCount,
		nearest
	))
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == WORLD_LOG_DROPS_NAME then
		refreshDropsFolder()
	end
end)

Workspace.ChildRemoved:Connect(function(child)
	if child == activeDropsFolder or child.Name == WORLD_LOG_DROPS_NAME then
		refreshDropsFolder()
	end
end)

refreshDropsFolder()

RunService.Heartbeat:Connect(function(deltaTime)
	reconcileElapsed += deltaTime
	if reconcileElapsed >= RECONCILE_INTERVAL then
		reconcileElapsed %= RECONCILE_INTERVAL
		reconcileCandidates()
		if DEBUG then
			logCandidateSummary(getLivingCharacterRoot())
		end
	end

	scanElapsed += deltaTime
	if scanElapsed < SCAN_INTERVAL then return end
	scanElapsed %= SCAN_INTERVAL

	local now = os.clock()
	if now < nextRequestAt then return end
	local root = getLivingCharacterRoot()
	if not root then return end

	local model, uid, distance = findNearestOwnedDrop(root, now)
	if not model then return end

	lastRequestAtByModel[model] = now
	nextRequestAt = now + REQUEST_INTERVAL
	pickupRemote:FireServer(model, uid)
	debugLog(string.format("request fired uid=%s distance=%.1f studs", uid, distance))
end)
