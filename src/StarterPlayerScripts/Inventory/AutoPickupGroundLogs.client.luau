-- Requests owner-reserved ground-log pickups when the owner walks close enough.
-- The server resolves and validates every candidate before changing inventory.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local pickupRemote = ReplicatedStorage:WaitForChild("Economy"):WaitForChild("PickupGroundLogRE")

-- Keep these client scan values aligned with the server's pickup distance and
-- rate limit. Server validation remains authoritative.
local MAX_PICKUP_DISTANCE = 15
local SCAN_INTERVAL = 0.05
local REQUEST_INTERVAL = 0.08
local PER_MODEL_RETRY_INTERVAL = 0.75

local scanElapsed = 0
local nextRequestAt = 0
local lastRequestAtByModel = setmetatable({}, { __mode = "k" })

local function getLivingCharacterRoot()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then return nil end
	return root
end

local function findNearestOwnedDrop(root, now)
	local dropsFolder = Workspace:FindFirstChild("WorldLogDrops")
	if not dropsFolder then return nil end

	local nearestModel = nil
	local nearestUid = nil
	local nearestDistance = MAX_PICKUP_DISTANCE
	for _, instance in ipairs(dropsFolder:GetDescendants()) do
		if instance:IsA("Model")
			and instance.Name == "DroppedLog"
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
