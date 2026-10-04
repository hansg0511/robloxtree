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

local scanElapsed = 0
local nextRequestAt = 0
local lastRequestAtByModel = setmetatable({}, { __mode = "k" })
local candidateModels = setmetatable({}, { __mode = "k" })
local boundFolders = setmetatable({}, { __mode = "k" })

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

local function findNearestOwnedDrop(root, now)
	local nearestModel = nil
	local nearestUid = nil
	local nearestDistance = MAX_PICKUP_DISTANCE
	for instance in pairs(candidateModels) do
		if instance:IsDescendantOf(Workspace)
			and isDropCandidate(instance)
			and instance:GetAttribute("ItemType") == "Log"
			and instance:GetAttribute("OwnerUserId") == localPlayer.UserId then
			local uid = instance:GetAttribute("UID")
			local handle = instance.PrimaryPart
			local lastRequestAt = lastRequestAtByModel[instance] or -math.huge
			if type(uid) == "string" and #uid > 0 and handle and now - lastRequestAt >= PER_MODEL_RETRY_INTERVAL then
				local distance = (root.Position - handle.Position).Magnitude
				if distance <= nearestDistance then
					nearestModel = instance
					nearestUid = uid
					nearestDistance = distance
				end
			end
		end
	end

	return nearestModel, nearestUid
end

local function addCandidate(instance)
	if isDropCandidate(instance) then
		candidateModels[instance] = true
	end
end

local function removeCandidate(instance)
	if isDropCandidate(instance) then
		candidateModels[instance] = nil
		lastRequestAtByModel[instance] = nil
	end
end

local function bindDropsFolder(folder)
	if not folder:IsA("Folder") or boundFolders[folder] then return end
	boundFolders[folder] = true

	folder.DescendantAdded:Connect(addCandidate)
	folder.DescendantRemoving:Connect(removeCandidate)
	folder.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			for instance in pairs(candidateModels) do
				if not instance:IsDescendantOf(Workspace) then
					removeCandidate(instance)
				end
			end
		end
	end)

	-- One initial index pass handles drops that existed before this LocalScript
	-- started. All later changes are maintained by the folder signals above.
	for _, instance in ipairs(folder:GetDescendants()) do
		addCandidate(instance)
	end
end

local existingDropsFolder = Workspace:FindFirstChild("WorldLogDrops")
if existingDropsFolder then
	bindDropsFolder(existingDropsFolder)
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "WorldLogDrops" then
		bindDropsFolder(child)
	end
end)

RunService.Heartbeat:Connect(function(deltaTime)
	scanElapsed += deltaTime
	if scanElapsed < SCAN_INTERVAL then return end
	scanElapsed %= SCAN_INTERVAL

	local now = os.clock()
	if now < nextRequestAt then return end
	local root = getLivingCharacterRoot()
	if not root then return end

	local model, uid = findNearestOwnedDrop(root, now)
	if not model then return end

	lastRequestAtByModel[model] = now
	nextRequestAt = now + REQUEST_INTERVAL
	pickupRemote:FireServer(model, uid)
end)
