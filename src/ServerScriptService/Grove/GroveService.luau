-- Server authority for persistent Personal Grove records and their TreeObject
-- runtime forms. Profile records never contain Roblox Instances or CFrames.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProfileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local TreeObject = require(game.ServerScriptService.Trees.TreeObject)
local PlotManager = require(game.ServerStorage.PlotManager)
local MaterialDefinitions = require(game.ServerScriptService.Economy.MaterialDefinitions)

local GroveService = {}

GroveService.Constants = {
	Capacity = 25,
	PlacementMargin = 2,
	MinimumSpacing = 4.5,
	MaturitySeconds = 45,
	SaplingStageFraction = 0.25,
	PlantRequestCooldownSeconds = 0.75,
	StageUpdateIntervalSeconds = 1,
}

local GROVE_UID_MAX_LENGTH = 80
local GROVE_COORDINATE_LIMIT = 512
local MIN_SIZE_POTENTIAL = 0.1
local MAX_SIZE_POTENTIAL = 2
local GROVE_FOLDER = ReplicatedStorage:WaitForChild("Grove")
local GetGroveStateRF = GROVE_FOLDER:WaitForChild("GetGroveStateRF")
local PlantSaplingRE = GROVE_FOLDER:WaitForChild("PlantSaplingRE")
local GroveStateUpdatedRE = GROVE_FOLDER:WaitForChild("GroveStateUpdatedRE")

-- Required runtime index: persistent Grove UID -> non-farm TreeObject.
local RuntimeTreesByUID = {}
local PlayerRuntimeUIDs = {}
local RestoredPlotByPlayer = {}
local LastPlantRequestAt = {}
local Started = false

local function isFiniteNumber(value)
	return type(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
end

local function isValidUID(value)
	return type(value) == "string"
		and #value > 0
		and #value <= GROVE_UID_MAX_LENGTH
		and string.match(value, "%S") ~= nil
		and string.match(value, "[%c]") == nil
end

local function isKnownSpecies(speciesId)
	return type(speciesId) == "string" and MaterialDefinitions.Get(speciesId) ~= nil
end

local function copyMutations(mutations)
	local result = {}
	if type(mutations) ~= "table" then return result end
	for key, value in pairs(mutations) do
		if type(key) == "string" and #key > 0 and #key <= 80 and string.match(key, "[%c]") == nil then
			local valueType = type(value)
			if valueType == "string" and #value <= 80 and string.match(value, "[%c]") == nil then
				result[key] = value
			elseif valueType == "boolean" or (valueType == "number" and isFiniteNumber(value)) then
				result[key] = value
			end
		end
	end
	return result
end

local function isValidSapling(record)
	return type(record) == "table"
		and isValidUID(record.UID)
		and isKnownSpecies(record.SpeciesId)
		and type(record.Mutations) == "table"
		and isFiniteNumber(record.SizePotential)
		and record.SizePotential >= MIN_SIZE_POTENTIAL
		and record.SizePotential <= MAX_SIZE_POTENTIAL
		and isFiniteNumber(record.CreatedAt)
		and record.CreatedAt >= 0
end

local function isValidGroveTree(record)
	return type(record) == "table"
		and isValidUID(record.UID)
		and isValidUID(record.SourceSaplingUID)
		and record.SourceSaplingUID ~= record.UID
		and isKnownSpecies(record.SpeciesId)
		and type(record.Mutations) == "table"
		and isFiniteNumber(record.SizePotential)
		and record.SizePotential >= MIN_SIZE_POTENTIAL
		and record.SizePotential <= MAX_SIZE_POTENTIAL
		and isFiniteNumber(record.LocalX)
		and math.abs(record.LocalX) <= GROVE_COORDINATE_LIMIT
		and isFiniteNumber(record.LocalZ)
		and math.abs(record.LocalZ) <= GROVE_COORDINATE_LIMIT
		and isFiniteNumber(record.Yaw)
		and math.abs(record.Yaw) <= math.pi * 2
		and isFiniteNumber(record.PlantedAt)
		and record.PlantedAt >= 0
		and isFiniteNumber(record.MaturesAt)
		and record.MaturesAt > record.PlantedAt
end

local function getProfileData(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or not player:IsDescendantOf(Players) then
		return nil
	end
	local profile = ProfileCache.GetProfile(player)
	if not profile or type(profile.Data) ~= "table" then
		return nil
	end
	ProfileCache.NormalizeGroveData(profile.Data)
	return profile.Data
end

local function getAssignedGrove(player)
	local plot = PlotManager.playerPlotMap[player]
	if not plot or not plot.Parent then return nil end
	local ownerId = plot:FindFirstChild("OwnerID")
	if not ownerId or not ownerId:IsA("IntValue") or ownerId.Value ~= player.UserId then return nil end
	local plotModel = plot:FindFirstChild("PlotModel")
	local area = plotModel and plotModel:FindFirstChild("GroveArea")
	if not plotModel or not area or not area:IsA("BasePart") then return nil end
	return plot, plotModel, area
end

local function isInsidePlacementBounds(area, localX, localZ)
	local halfX = area.Size.X * 0.5 - GroveService.Constants.PlacementMargin
	local halfZ = area.Size.Z * 0.5 - GroveService.Constants.PlacementMargin
	return halfX > 0
		and halfZ > 0
		and math.abs(localX) <= halfX
		and math.abs(localZ) <= halfZ
end

local function deriveStage(record, now)
	local saplingEnd = record.PlantedAt
		+ (record.MaturesAt - record.PlantedAt) * GroveService.Constants.SaplingStageFraction
	if now < saplingEnd then return "sapling" end
	if now < record.MaturesAt then return "young" end
	return "mature"
end

local function copySapling(record)
	return {
		UID = record.UID,
		SpeciesId = record.SpeciesId,
		Mutations = copyMutations(record.Mutations),
		SizePotential = record.SizePotential,
		CreatedAt = record.CreatedAt,
	}
end

local function copyGroveTree(record, now)
	return {
		UID = record.UID,
		SourceSaplingUID = record.SourceSaplingUID,
		SpeciesId = record.SpeciesId,
		Mutations = copyMutations(record.Mutations),
		SizePotential = record.SizePotential,
		LocalX = record.LocalX,
		LocalZ = record.LocalZ,
		Yaw = record.Yaw,
		PlantedAt = record.PlantedAt,
		MaturesAt = record.MaturesAt,
		Stage = deriveStage(record, now),
	}
end

function GroveService.GetState(player)
	local data = getProfileData(player)
	local _, _, area = getAssignedGrove(player)
	local state = {
		HasAssignedGrove = data ~= nil and area ~= nil,
		Capacity = GroveService.Constants.Capacity,
		MinimumSpacing = GroveService.Constants.MinimumSpacing,
		PlacementMargin = GroveService.Constants.PlacementMargin,
		Saplings = {},
		GroveTrees = {},
		ActiveGroveTreeUIDs = {},
	}
	if not data then return state end

	for _, sapling in ipairs(data.Saplings) do
		if isValidSapling(sapling) then
			table.insert(state.Saplings, copySapling(sapling))
		end
	end
	local now = os.time()
	for _, groveTree in ipairs(data.GroveTrees) do
		if isValidGroveTree(groveTree) then
			table.insert(state.GroveTrees, copyGroveTree(groveTree, now))
			table.insert(state.ActiveGroveTreeUIDs, groveTree.UID)
		end
	end
	return state
end

local function publishState(player)
	if typeof(player) ~= "Instance" or not player:IsDescendantOf(Players) then return end
	local ok, snapshot = pcall(GroveService.GetState, player)
	if ok then
		pcall(function()
			GroveStateUpdatedRE:FireClient(player, snapshot)
		end)
	end
end

local function worldCFrameForRecord(area, record)
	return area.CFrame
		* CFrame.new(record.LocalX, -area.Size.Y * 0.5 + 0.05, record.LocalZ)
		* CFrame.Angles(0, record.Yaw, 0)
end

local function spawnGroveTree(player, plotModel, area, record)
	if not isValidGroveTree(record) or not isInsidePlacementBounds(area, record.LocalX, record.LocalZ) then
		return nil
	end
	if RuntimeTreesByUID[record.UID] then return nil end
	local treeObject
	local ok, model = pcall(function()
		treeObject = TreeObject.new({
			DefinitionId = "PersistentGroveTree",
			Parent = plotModel,
			CFrame = worldCFrameForRecord(area, record),
			OwnerUserId = player.UserId,
			GroveTreeUID = record.UID,
			SourceSaplingUID = record.SourceSaplingUID,
			SpeciesId = record.SpeciesId,
			SizePotential = record.SizePotential,
			PlantedAt = record.PlantedAt,
			MaturesAt = record.MaturesAt,
			GroveStage = deriveStage(record, os.time()),
		})
		return treeObject:Spawn()
	end)
	if not ok or not model then
		if treeObject then treeObject:Destroy() end
		return nil
	end
	RuntimeTreesByUID[record.UID] = treeObject
	PlayerRuntimeUIDs[player] = PlayerRuntimeUIDs[player] or {}
	PlayerRuntimeUIDs[player][record.UID] = true
	return treeObject
end

function GroveService.RestorePlayer(player)
	local data = getProfileData(player)
	local plot, plotModel, area = getAssignedGrove(player)
	if not data or not plot then return false end
	if RestoredPlotByPlayer[player] == plot then
		publishState(player)
		return true
	end

	-- A reassignment can change the world transform while preserving local records.
	GroveService.CleanRuntime(player)
	for _, record in ipairs(data.GroveTrees) do
		spawnGroveTree(player, plotModel, area, record)
	end
	RestoredPlotByPlayer[player] = plot
	publishState(player)
	return true
end

function GroveService.CleanRuntime(player)
	local uids = PlayerRuntimeUIDs[player]
	if uids then
		for uid in pairs(uids) do
			local treeObject = RuntimeTreesByUID[uid]
			if treeObject and treeObject.OwnerUserId == player.UserId then
				treeObject:Destroy()
				RuntimeTreesByUID[uid] = nil
			end
		end
	end
	PlayerRuntimeUIDs[player] = nil
	RestoredPlotByPlayer[player] = nil
end

function GroveService.CleanUp(player)
	GroveService.CleanRuntime(player)
	LastPlantRequestAt[player] = nil
end

local function uidRecordCount(data, uid)
	local count = 0
	for _, collectionName in ipairs({ "Saplings", "GroveTrees" }) do
		local collection = data[collectionName]
		if type(collection) == "table" then
			for _, record in pairs(collection) do
				if type(record) == "table" and record.UID == uid then count += 1 end
			end
		end
	end
	return count
end

local function findUniqueSapling(data, uid)
	local found, foundIndex, count = nil, nil, 0
	for index, record in ipairs(data.Saplings) do
		if type(record) == "table" and record.UID == uid then
			found = record
			foundIndex = index
			count += 1
		end
	end
	if count ~= 1 or uidRecordCount(data, uid) ~= 1 or not isValidSapling(found) then
		return nil
	end
	return found, foundIndex
end

local function hasSpacing(data, localX, localZ)
	local minimum = GroveService.Constants.MinimumSpacing
	for _, record in ipairs(data.GroveTrees) do
		if isValidGroveTree(record) then
			local dx = localX - record.LocalX
			local dz = localZ - record.LocalZ
			if dx * dx + dz * dz < minimum * minimum then return false end
		end
	end
	return true
end

local function uidAlreadyUsed(data, uid)
	if uidRecordCount(data, uid) > 0 or RuntimeTreesByUID[uid] then return true end
	for _, groveTree in ipairs(data.GroveTrees) do
		if type(groveTree) == "table" and groveTree.SourceSaplingUID == uid then return true end
	end
	return false
end

local function newGroveUID(data)
	for _ = 1, 8 do
		local uid = HttpService:GenerateGUID(false)
		if not uidAlreadyUsed(data, uid) then return uid end
	end
	return nil
end

local function removeByIdentity(collection, item)
	for index = #collection, 1, -1 do
		if collection[index] == item then
			table.remove(collection, index)
			return true
		end
	end
	return false
end

local function plantSapling(player, saplingUID, localX, localZ)
	local data = getProfileData(player)
	local plot, plotModel, area = getAssignedGrove(player)
	if not data or not plot then return false end
	if not isValidUID(saplingUID)
		or not isFiniteNumber(localX)
		or not isFiniteNumber(localZ)
		or math.abs(localX) > GROVE_COORDINATE_LIMIT
		or math.abs(localZ) > GROVE_COORDINATE_LIMIT then
		return false
	end
	if #data.GroveTrees >= GroveService.Constants.Capacity
		or not isInsidePlacementBounds(area, localX, localZ)
		or not hasSpacing(data, localX, localZ) then
		return false
	end
	local sapling, saplingIndex = findUniqueSapling(data, saplingUID)
	if not sapling then return false end
	for _, groveTree in ipairs(data.GroveTrees) do
		if groveTree.SourceSaplingUID == saplingUID then return false end
	end

	local uid = newGroveUID(data)
	if not uid then return false end
	local now = os.time()
	local yaw = Random.new():NextNumber(0, math.pi * 2)
	local groveRecord = {
		UID = uid,
		SourceSaplingUID = sapling.UID,
		SpeciesId = sapling.SpeciesId,
		Mutations = copyMutations(sapling.Mutations),
		SizePotential = sapling.SizePotential,
		LocalX = localX,
		LocalZ = localZ,
		Yaw = yaw,
		PlantedAt = now,
		MaturesAt = now + GroveService.Constants.MaturitySeconds,
	}

	-- Spawn before consuming. A missing visual or failed TreeObject leaves the
	-- source sapling untouched and creates no profile-side phantom tree.
	local treeObject = spawnGroveTree(player, plotModel, area, groveRecord)
	if not treeObject then return false end

	local sourceRecord = sapling
	local sourceIndex = saplingIndex
	local ok = pcall(function()
		table.insert(data.GroveTrees, groveRecord)
		table.insert(data.ActiveGroveTreeUIDs, uid)
		table.remove(data.Saplings, sourceIndex)
	end)
	if not ok then
		removeByIdentity(data.GroveTrees, groveRecord)
		for index = #data.ActiveGroveTreeUIDs, 1, -1 do
			if data.ActiveGroveTreeUIDs[index] == uid then table.remove(data.ActiveGroveTreeUIDs, index) end
		end
		local sourceStillPresent = false
		for _, existing in ipairs(data.Saplings) do
			if existing == sourceRecord then sourceStillPresent = true break end
		end
		if not sourceStillPresent then
			table.insert(data.Saplings, math.min(sourceIndex, #data.Saplings + 1), sourceRecord)
		end
		treeObject:Destroy()
		RuntimeTreesByUID[uid] = nil
		if PlayerRuntimeUIDs[player] then PlayerRuntimeUIDs[player][uid] = nil end
		return false
	end
	publishState(player)
	return true
end

local function updateRuntimeStages()
	local now = os.time()
	for _, treeObject in pairs(RuntimeTreesByUID) do
		if treeObject and not treeObject.destroyed then
			local record = {
				PlantedAt = treeObject.GrovePlantedAt,
				MaturesAt = treeObject.GroveMaturesAt,
			}
			local stage = deriveStage(record, now)
			if stage ~= treeObject.GroveStage then
				treeObject:SetGroveStage(stage)
			end
		end
	end
end

function GroveService.Start()
	if Started then return end
	Started = true
	GetGroveStateRF.OnServerInvoke = function(player, ...)
		if select("#", ...) ~= 0 then return nil end
		return GroveService.GetState(player)
	end
	PlantSaplingRE.OnServerEvent:Connect(function(player, ...)
		local now = os.clock()
		if now - (LastPlantRequestAt[player] or -math.huge) < GroveService.Constants.PlantRequestCooldownSeconds then
			return
		end
		LastPlantRequestAt[player] = now
		if select("#", ...) ~= 3 then return end
		local saplingUID, localX, localZ = ...
		if type(saplingUID) ~= "string" or type(localX) ~= "number" or type(localZ) ~= "number" then
			return
		end
		plantSapling(player, saplingUID, localX, localZ)
	end)
	task.spawn(function()
		while true do
			task.wait(GroveService.Constants.StageUpdateIntervalSeconds)
			updateRuntimeStages()
		end
	end)
end

return GroveService
