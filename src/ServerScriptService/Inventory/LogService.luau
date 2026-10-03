-- Server-authoritative unique log inventory, ground pickups, holding, and selling.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ProfileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local EconomyManager = require(game.ServerScriptService.Economy.EconomyManager)
local TreeDefinitions = require(game.ServerScriptService.Trees.TreeDefinitions)

local LogService = {}

local DEFAULT_CAPACITY = 10
local MAX_CAPACITY = 40
local OWNER_RESERVATION_SECONDS = 60
-- Overflow is deliberately short-lived. The owner has the full lifetime to
-- free a slot and recover the exact UID; it is not converted into a public
-- loot race after the reservation expires.
local GROUND_LOG_LIFETIME_SECONDS = 60
local MAX_PICKUP_DISTANCE = 12
local MAX_SELL_DISTANCE = 14
local REMOTE_INTERVALS = {
	Sell = 1,
	Lock = 0.15,
	Hold = 0.3,
	Pickup = 0.25,
}

local economyRemotes = ReplicatedStorage:WaitForChild("Economy")
local GetLogsDataRF = economyRemotes:WaitForChild("GetLogsDataRF")
local SellUnlockedLogsRE = economyRemotes:WaitForChild("SellUnlockedLogsRE")
local SetLogLockedRE = economyRemotes:WaitForChild("SetLogLockedRE")
local SetHeldLogRE = economyRemotes:WaitForChild("SetHeldLogRE")
local EconomyStateUpdated = economyRemotes:WaitForChild("EconomyStateUpdated")

local profileLoaded = game.ServerScriptService.PlayerProfile.ProfileInit.ProfileLoadedEvent
local activeGroundDrops = {}
local heldLogByPlayer = {}
local remoteBudgetByPlayer = {}
local valuePerKgBySpecies = {}

for _, definition in pairs(TreeDefinitions) do
	if type(definition) == "table"
		and type(definition.SpeciesId) == "string"
		and type(definition.ValuePerKg) == "number"
		and definition.ValuePerKg > 0 then
		valuePerKgBySpecies[definition.SpeciesId] = definition.ValuePerKg
	end
end

local function isFinitePositive(number)
	return type(number) == "number"
		and number == number
		and number > 0
		and number < math.huge
end

local function isValidUid(uid)
	return type(uid) == "string" and #uid > 0 and #uid <= 80
end

local function getPlayerData(player)
	local profile = ProfileCache.GetProfile(player)
	if not profile or type(profile.Data) ~= "table" then return nil end
	if type(profile.Data.Logs) ~= "table" then profile.Data.Logs = {} end
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
	local valuePerKg = valuePerKgBySpecies[logRecord.SpeciesId]
	if not valuePerKg or not isFinitePositive(logRecord.WeightKg) then return nil end
	local rawValue = logRecord.WeightKg * valuePerKg
	if not isFinitePositive(rawValue) then return nil end
	return math.floor(rawValue + 0.5)
end

local function makeClientSnapshot(player)
	local data = getPlayerData(player)
	if not data then return nil end

	local logs = {}
	for _, logRecord in ipairs(data.Logs) do
		local value = getLogValue(logRecord)
		if value and isValidUid(logRecord.UID) then
			local mutations = {}
			if type(logRecord.Mutations) == "table" then
				for key, mutation in pairs(logRecord.Mutations) do
					if type(key) == "string" and (type(mutation) == "string" or type(mutation) == "number" or type(mutation) == "boolean") then
						mutations[key] = mutation
					end
				end
			end
			table.insert(logs, {
				UID = logRecord.UID,
				ItemType = "Log",
				SpeciesId = logRecord.SpeciesId,
				WeightKg = logRecord.WeightKg,
				SizeScale = isFinitePositive(logRecord.SizeScale) and math.clamp(logRecord.SizeScale, 0.45, 1.7) or 1,
				Mutations = mutations,
				Locked = logRecord.Locked == true,
				CreatedAt = type(logRecord.CreatedAt) == "number" and logRecord.CreatedAt or 0,
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

function LogService.NotifyState(player)
	local snapshot = makeClientSnapshot(player)
	if snapshot and player:IsDescendantOf(Players) then
		EconomyStateUpdated:FireClient(player, snapshot)
	end
	return snapshot
end

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

local function clearHeldLog(player)
	local held = heldLogByPlayer[player]
	if held and held.Parent then held:Destroy() end
	heldLogByPlayer[player] = nil
	player:SetAttribute("HeldLogUID", nil)
end

local function getHand(character)
	return character:FindFirstChild("RightHand")
		or character:FindFirstChild("Right Arm")
		or character:FindFirstChild("HumanoidRootPart")
end

local function makeLogPart(logRecord, name)
	local sizeScale = if isFinitePositive(logRecord.SizeScale) then math.clamp(logRecord.SizeScale, 0.45, 1.7) else 1
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(2, 0.65, 0.65) * sizeScale
	part.Material = Enum.Material.Wood
	part.Color = if logRecord.SpeciesId == "Ironwood"
		then Color3.fromRGB(95, 70, 51)
		else Color3.fromRGB(142, 91, 54)
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Inlet
	part:SetAttribute("ItemType", "Log")
	part:SetAttribute("SpeciesId", logRecord.SpeciesId)
	part:SetAttribute("SizeScale", sizeScale)
	return part
end

function LogService.HoldLog(player, uid)
	if uid == nil or uid == "" then
		clearHeldLog(player)
		return true
	end
	if not isValidUid(uid) then return false end
	local data = getPlayerData(player)
	if not data then return false end
	local logRecord = findLog(data, uid)
	if not logRecord then return false end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hand = character and getHand(character)
	if not humanoid or humanoid.Health <= 0 or not hand or not hand:IsA("BasePart") then return false end

	clearHeldLog(player)
	local heldPart = makeLogPart(logRecord, "HeldLog")
	heldPart.Anchored = false
	heldPart.Massless = true
	heldPart.CanCollide = false
	heldPart.CanTouch = false
	heldPart.CanQuery = false
	heldPart.CFrame = hand.CFrame * CFrame.new(0, -0.4, -0.7)
	heldPart.Parent = character
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = heldPart
	weld.Parent = heldPart
	heldLogByPlayer[player] = heldPart
	player:SetAttribute("HeldLogUID", uid)
	return true
end

local function getStationDistance(player)
	local station = Workspace:FindFirstChild("SourceWorld")
		and Workspace.SourceWorld:FindFirstChild("HomeEconomyStation")
		and Workspace.SourceWorld.HomeEconomyStation:FindFirstChild("Interaction")
	if not station or not station:IsA("BasePart") then return math.huge end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then return math.huge end

	local localPosition = station.CFrame:PointToObjectSpace(root.Position)
	local halfSize = station.Size * 0.5
	local closestLocalPoint = Vector3.new(
		math.clamp(localPosition.X, -halfSize.X, halfSize.X),
		math.clamp(localPosition.Y, -halfSize.Y, halfSize.Y),
		math.clamp(localPosition.Z, -halfSize.Z, halfSize.Z)
	)
	return (root.Position - station.CFrame:PointToWorldSpace(closestLocalPoint)).Magnitude
end

function LogService.CanSellAtBase(player)
	return getStationDistance(player) <= MAX_SELL_DISTANCE
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

local function tryPickupGroundLog(player, part)
	local drop = activeGroundDrops[part]
	if not drop or not part.Parent or not part:IsDescendantOf(Workspace) then return false end
	if not consumeRemoteBudget(player, "Pickup") then return false end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then return false end
	if (root.Position - part.Position).Magnitude > MAX_PICKUP_DISTANCE then return false end
	if player.UserId ~= drop.OwnerUserId then return false end

	local data = getPlayerData(player)
	if not data or logCount(data) >= data.LogCapacity then return false end
	if findLog(data, drop.LogRecord.UID) then return false end

	-- Remove the server registry entry before mutating the profile or destroying
	-- the physical pickup. Prompt spam cannot award the same UID twice.
	activeGroundDrops[part] = nil
	table.insert(data.Logs, drop.LogRecord)
	part:Destroy()
	LogService.NotifyState(player)
	return true
end

local function spawnGroundDrop(logRecord, ownerUserId, position)
	local part = makeLogPart(logRecord, "DroppedLog")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CFrame = CFrame.new(
		position.X,
		getGroundHeight(position) + part.Size.Y * 0.5 + 0.08,
		position.Z
	)
	part:SetAttribute("UID", logRecord.UID)
	part:SetAttribute("WeightKg", logRecord.WeightKg)
	part:SetAttribute("OwnerUserId", ownerUserId)
	part:SetAttribute("OwnerReservationSeconds", OWNER_RESERVATION_SECONDS)
	part.Parent = getGroundDropFolder()

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.ActionText = "Pick up"
	prompt.ObjectText = tostring(logRecord.SpeciesId) .. " log"
	prompt.HoldDuration = 0.15
	prompt.MaxActivationDistance = MAX_PICKUP_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	activeGroundDrops[part] = {
		LogRecord = logRecord,
		OwnerUserId = ownerUserId,
		ReservedUntil = os.clock() + OWNER_RESERVATION_SECONDS,
	}
	prompt.Triggered:Connect(function(player)
		tryPickupGroundLog(player, part)
	end)

	task.delay(GROUND_LOG_LIFETIME_SECONDS, function()
		if activeGroundDrops[part] then
			activeGroundDrops[part] = nil
			if part.Parent then part:Destroy() end
		end
	end)
end

local function createLogRecord(tree)
	local sizeScale = tree.SizeScale
	local weightKg = tree.BaseWeightKg * (sizeScale ^ 2)
	weightKg = math.floor(weightKg * 100 + 0.5) / 100
	return {
		UID = HttpService:GenerateGUID(false),
		ItemType = "Log",
		SpeciesId = tree.SpeciesId,
		WeightKg = weightKg,
		SizeScale = sizeScale,
		Mutations = {},
		Locked = false,
		CreatedAt = os.time(),
	}
end

function LogService.AwardTreeLog(tree, contributions)
	if not tree or tree.Category == "Barrier" then return false end
	if type(tree.SpeciesId) ~= "string"
		or not valuePerKgBySpecies[tree.SpeciesId]
		or not isFinitePositive(tree.BaseWeightKg)
		or not isFinitePositive(tree.SizeScale) then
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
	if logCount(data) < data.LogCapacity then
		table.insert(data.Logs, logRecord)
		LogService.NotifyState(winner)
	else
		local origin = tree.InteractionPart and tree.InteractionPart.Position or tree.CFrame.Position
		spawnGroundDrop(logRecord, winner.UserId, origin)
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
	-- A held representation is only a cosmetic projection of an owned record.
	-- Selling that record must immediately remove the projection as well.
	local heldUid = player:GetAttribute("HeldLogUID")
	if heldUid and not findLog(data, heldUid) then
		clearHeldLog(player)
	end
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

SetHeldLogRE.OnServerEvent:Connect(function(player, uid, ...)
	if select("#", ...) ~= 0 or not consumeRemoteBudget(player, "Hold") then return end
	if uid ~= "" and not isValidUid(uid) then return end
	if LogService.HoldLog(player, uid) then
		LogService.NotifyState(player)
	end
end)

profileLoaded.Event:Connect(function(player)
	getPlayerData(player)
	LogService.NotifyState(player)
	player.CharacterAdded:Connect(function()
		clearHeldLog(player)
	end)
	if player.Character then clearHeldLog(player) end
end)

Players.PlayerRemoving:Connect(function(player)
	clearHeldLog(player)
	remoteBudgetByPlayer[player] = nil
end)

return LogService
