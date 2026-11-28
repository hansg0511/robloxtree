-- Server authority for persistent Personal Grove records and their TreeObject
-- runtime forms. Profile records never contain Roblox Instances or CFrames.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProfileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local TreeObject = require(game.ServerScriptService.Trees.TreeObject)
local PlotManager = require(game.ServerStorage.PlotManager)
local MaterialDefinitions = require(game.ServerScriptService.Economy.MaterialDefinitions)
local MutationDefinitions = require(script.Parent.MutationDefinitions)
local GroveGrowthRules = require(script.Parent.GroveGrowthRules)
local Passives = require(script.Parent.GrovePassiveRules)
local Upgrades = require(script.Parent.GroveUpgradeRules)
local QuestService = require(game.ServerScriptService.Quests.QuestService)
local LogService = require(game.ServerScriptService.Inventory.LogService)
local GroveHarvestPresentation = require(ReplicatedStorage.Shared.GroveHarvestPresentation)

local GroveService = {}

GroveService.Constants = {
	Capacity = Passives.START_CAPACITY,
	PlacementMargin = 2,
	MinimumSpacing = 4.5,
	MaturitySeconds = GroveGrowthRules.MATURITY_SECONDS, -- 1.0-size prototype baseline only
	SecondsPerVisualStep = GroveGrowthRules.SECONDS_PER_VISUAL_STEP,
	SaplingStageFraction = GroveGrowthRules.SAPLING_FRACTION,
	StumpSeconds = GroveGrowthRules.STUMP_SECONDS,
	PlantRequestCooldownSeconds = 0.75,
	StageUpdateIntervalSeconds = 1,
}

local GROVE_UID_MAX_LENGTH = 80
local GROVE_COORDINATE_LIMIT = 512
local MIN_SIZE_POTENTIAL = 0.1
local MAX_SIZE_POTENTIAL = GroveGrowthRules.MAX_POTENTIAL
local GROVE_FOLDER = ReplicatedStorage:WaitForChild("Grove")
local GetGroveStateRF = GROVE_FOLDER:WaitForChild("GetGroveStateRF")
local PlantSaplingRE = GROVE_FOLDER:WaitForChild("PlantSaplingRE")
local UpgradeGroveRE = GROVE_FOLDER:WaitForChild("UpgradeGroveRE")
local EconomyUpdated = ReplicatedStorage:WaitForChild("Economy"):WaitForChild("EconomyUpdated")
local LastUpgradeAt = setmetatable({}, { __mode = "k" })
local UprootGroveTreeRE = GROVE_FOLDER:WaitForChild("UprootGroveTreeRE")
local GroveStateUpdatedRE = GROVE_FOLDER:WaitForChild("GroveStateUpdatedRE")
local GroveHarvestFXRE = GROVE_FOLDER:WaitForChild("GroveHarvestFXRE")

-- Required runtime index: persistent Grove UID -> non-farm TreeObject.
local RuntimeTreesByUID = {}
local PlayerRuntimeUIDs = {}
local RestoredPlotByPlayer = {}
local LastPlantRequestAt = {}
local LastUprootRequestAt = {}
local LastSuccessfulHarvestAt = {}
-- A state response and a state-update event travel over separate remotes. Keep a
-- monotonically increasing revision so an older RemoteFunction response cannot
-- overwrite a newer pushed update on the client during player initialization.
local StateRevisionByPlayer = {}
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
	return MutationDefinitions.CopyKnown(mutations)
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
		and GroveGrowthRules.NormalizeCurrentSize(record.CurrentSizeScale, record.SizePotential) == record.CurrentSizeScale
		and GroveGrowthRules.NormalizeHarvestCount(record.HarvestCount) == record.HarvestCount
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

local function isValidHeartwood(record)
	return type(record) == "table"
		and isValidUID(record.UID)
		and record.MaterialType == "Heartwood"
		and isKnownSpecies(record.SpeciesId)
		and type(record.Mutations) == "table"
		and isFiniteNumber(record.SizePotential)
		and record.SizePotential >= MIN_SIZE_POTENTIAL
		and record.SizePotential <= MAX_SIZE_POTENTIAL
		and isValidUID(record.SourceGroveTreeUID)
		and isValidUID(record.SourceSaplingUID)
		and record.SourceGroveTreeUID ~= record.SourceSaplingUID
		and record.UID ~= record.SourceGroveTreeUID
		and record.UID ~= record.SourceSaplingUID
		and isFiniteNumber(record.CreatedAt)
		and record.CreatedAt >= 0
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
	return GroveGrowthRules.Stage(record, now)
end

local function copySapling(record)
	return {
		UID = record.UID,
		SpeciesId = record.SpeciesId,
		Mutations = copyMutations(record.Mutations),
		SizePotential = record.SizePotential,
		GeneticPassive = record.GeneticPassive,
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
		GeneticPassive = record.GeneticPassive,
		CurrentSizeScale = record.CurrentSizeScale,
		HarvestCount = record.HarvestCount,
		LocalX = record.LocalX,
		LocalZ = record.LocalZ,
		Yaw = record.Yaw,
		PlantedAt = record.PlantedAt,
		MaturesAt = record.MaturesAt,
		Stage = deriveStage(record, now),
		Passives = Passives.ForTree(record, now),
	}
end

local function copyHeartwood(record)
	return {
		UID = record.UID,
		MaterialType = "Heartwood",
		SpeciesId = record.SpeciesId,
		Mutations = copyMutations(record.Mutations),
		SizePotential = record.SizePotential,
		SourceGroveTreeUID = record.SourceGroveTreeUID,
		SourceSaplingUID = record.SourceSaplingUID,
		CreatedAt = record.CreatedAt,
	}
end

function GroveService.GetState(player)
	local data = getProfileData(player)
	local _, _, area = getAssignedGrove(player)
	local level = Upgrades.NormalizeLevel(data and data.GroveLevel)
	local current = Upgrades.Current(level)
	local nextUpgrade = Upgrades.Next(level)
	local state = {
		GroveLevel = level,
		MaxMutations = current.MaxMutations,
		Upgrade = nextUpgrade,
		Revision = StateRevisionByPlayer[player] or 0,
		HasAssignedGrove = data ~= nil and area ~= nil,
		Capacity = current.Capacity,
		MinimumSpacing = GroveService.Constants.MinimumSpacing,
		PlacementMargin = GroveService.Constants.PlacementMargin,
		Saplings = {},
		GroveTrees = {},
		GroveMaterials = {},
		ActiveGroveTreeUIDs = {},
		PassiveTotals = Passives.Empty(),
	}
	if not data then return state end

	for _, sapling in ipairs(data.Saplings) do
		if isValidSapling(sapling) then
			table.insert(state.Saplings, copySapling(sapling))
		end
	end
	local now = os.time()
	state.PassiveTotals = Passives.Totals(data, now)
	-- Only presentation reads this attribute; combat recomputes on the server.
	player:SetAttribute("GroveHaste", state.PassiveTotals.Haste)
	for _, groveTree in ipairs(data.GroveTrees) do
		if isValidGroveTree(groveTree) then
			table.insert(state.GroveTrees, copyGroveTree(groveTree, now))
		end
	end
	for _, material in ipairs(data.GroveMaterials) do
		if isValidHeartwood(material) then
			table.insert(state.GroveMaterials, copyHeartwood(material))
		end
	end
	return state
end

local function publishState(player)
	if typeof(player) ~= "Instance" or not player:IsDescendantOf(Players) then return end
	StateRevisionByPlayer[player] = (StateRevisionByPlayer[player] or 0) + 1
	local ok, snapshot = pcall(GroveService.GetState, player)
	if ok then
		pcall(function()
			GroveStateUpdatedRE:FireClient(player, snapshot)
		end)
	end
end

-- Server-only callers that mutate a Grove collection use this narrow seam so
-- their change participates in the same ordered client-state stream.
function GroveService.NotifyState(player)
	publishState(player)
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
			-- Pass an allowlisted copy so runtime TreeObjects never share the
			-- mutable persisted record table or trust unknown mutation identifiers.
			Mutations = MutationDefinitions.CopyKnown(record.Mutations),
			SizePotential = record.SizePotential,
			CurrentSizeScale = record.CurrentSizeScale,
			HarvestCount = record.HarvestCount,
			PlantedAt = record.PlantedAt,
			MaturesAt = record.MaturesAt,
			GroveStage = deriveStage(record, os.time()),
			CanChopCallback = function(chopper, candidate)
				return GroveService.CanChopPersistentTree(chopper, candidate)
			end,
			OnPersistentHarvest = function(chopper, candidate)
				return GroveService.HarvestPersistentTree(chopper, candidate)
			end,
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
		-- Recover a missing runtime incarnation after a failed visual rebuild.
		-- During the brief tree-fall interval, the scheduled regrowth callback
		-- handles the replacement; do not overlap the falling tree.
		for _, record in ipairs(data.GroveTrees) do
			if isValidGroveTree(record) and not RuntimeTreesByUID[record.UID]
				and os.time() >= record.PlantedAt + GroveGrowthRules.STUMP_SECONDS then
				spawnGroveTree(player, plotModel, area, record)
			end
		end
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
	LastUprootRequestAt[player] = nil
	LastSuccessfulHarvestAt[player] = nil
	StateRevisionByPlayer[player] = nil
end

local function uidRecordCount(data, uid)
	local count = 0
	for _, collectionName in ipairs({ "Saplings", "GroveTrees", "GroveMaterials" }) do
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
	for _, material in ipairs(data.GroveMaterials) do
		if type(material) == "table"
			and (material.SourceGroveTreeUID == uid or material.SourceSaplingUID == uid) then
			return true
		end
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

local function findUniqueGroveTree(data, uid)
	local found, foundIndex, count = nil, nil, 0
	for index, record in ipairs(data.GroveTrees) do
		if type(record) == "table" and record.UID == uid then
			found = record
			foundIndex = index
			count += 1
		end
	end
	if count ~= 1 or uidRecordCount(data, uid) ~= 1 or not isValidGroveTree(found) then
		return nil
	end
	return found, foundIndex
end

local function sourceSaplingReferenceCount(data, uid)
	local count = 0
	for _, record in ipairs(data.GroveTrees) do
		if type(record) == "table" and record.SourceSaplingUID == uid then count += 1 end
	end
	-- Existing legacy materials may reference a planted sapling.
	-- Only the active Grove tree counts for its unique plant identity.
	return count
end

-- Explicit, permanent uprooting is a PLAYER-OWNED Grove operation, not
-- a sapling recovery or harvest. The server resolves a unique saved UID in
-- the caller's assigned Grove before changing anything. A regrowth timer
-- cannot resurrect a removed tree because it rechecks this saved record.
function GroveService.UprootTree(player, groveTreeUID)
	if not isValidUID(groveTreeUID) then return false, "INVALID_TREE_UID" end
	local data = getProfileData(player)
	local plot, plotModel, area = getAssignedGrove(player)
	if not data or not plot or RestoredPlotByPlayer[player] ~= plot then
		return false, "GROVE_NOT_READY"
	end

	local record, index = findUniqueGroveTree(data, groveTreeUID)
	if not record or not isInsidePlacementBounds(area, record.LocalX, record.LocalZ) then
		return false, "TREE_NOT_OWNED"
	end
	local runtime = RuntimeTreesByUID[groveTreeUID]
	if runtime and (runtime.OwnerUserId ~= player.UserId
		or runtime.GroveTreeUID ~= groveTreeUID
		or runtime.SourceSaplingUID ~= record.SourceSaplingUID
		or runtime.Parent ~= plotModel
		or runtime.IsPersistentGrove ~= true) then
		return false, "TREE_NOT_OWNED"
	end
	-- Do not allow one player to remove another player's runtime entry,
	-- including during plot reassignment. Missing runtime is permitted for
	-- the short falling-stump interval or a failed visual restoration.
	if runtime and (not PlayerRuntimeUIDs[player]
		or PlayerRuntimeUIDs[player][groveTreeUID] ~= true) then
		return false, "GROVE_NOT_READY"
	end

	-- Single nonyielding authoritative commit: remove the saved tree first,
	-- then its runtime incarnation. The consumed source sapling is NOT
	-- restored to Saplings, and no logs, currency or materials are granted.
	table.remove(data.GroveTrees, index)
	if type(data.ActiveGroveTreeUIDs) == "table" then
		data.ActiveGroveTreeUIDs[groveTreeUID] = nil
	end
	RuntimeTreesByUID[groveTreeUID] = nil
	if PlayerRuntimeUIDs[player] then
		PlayerRuntimeUIDs[player][groveTreeUID] = nil
	end
	if runtime then
		local destroyed, err = pcall(function() runtime:Destroy() end)
		if not destroyed then
			warn("[Grove] Uproot runtime cleanup failed for", groveTreeUID, err)
			-- Even if a visual lingers, its removed saved UID can never
			-- authorize a harvest or regain this Grove slot.
		end
	end
	publishState(player)
	return true, nil
end

local function validateRuntimeGroveTree(player, treeObject)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or not player:IsDescendantOf(Players) then
		return nil
	end
	if type(treeObject) ~= "table"
		or treeObject.IsPersistentGrove ~= true
		or treeObject.destroyed
		or treeObject.isDead then
		return nil
	end
	local data = getProfileData(player)
	local plot, plotModel, area = getAssignedGrove(player)
	if not data or not plot or RestoredPlotByPlayer[player] ~= plot then return nil end
	if plotModel ~= treeObject.Parent
		or not treeObject.model
		or not treeObject.model:IsDescendantOf(plotModel)
		or treeObject.OwnerUserId ~= player.UserId then
		return nil
	end
	local uid = treeObject.GroveTreeUID
	if not isValidUID(uid)
		or RuntimeTreesByUID[uid] ~= treeObject
		or not PlayerRuntimeUIDs[player]
		or PlayerRuntimeUIDs[player][uid] ~= true
		or TreeObject.ActiveTrees[treeObject] ~= true then
		return nil
	end
	local record, recordIndex = findUniqueGroveTree(data, uid)
	if not record
		or record.SourceSaplingUID ~= treeObject.SourceSaplingUID
		or record.SpeciesId ~= treeObject.SpeciesId
		or record.SizePotential ~= treeObject.GroveSizePotential
		or record.PlantedAt ~= treeObject.GrovePlantedAt
		or record.MaturesAt ~= treeObject.GroveMaturesAt
		or record.CurrentSizeScale ~= treeObject.GroveCurrentSize
		or treeObject.CFrame ~= worldCFrameForRecord(area, record)
		or sourceSaplingReferenceCount(data, record.SourceSaplingUID) ~= 1
		or os.time() < record.MaturesAt then
		return nil
	end
	return data, plot, plotModel, area, record, recordIndex
end

function GroveService.CanChopPersistentTree(player, treeObject)
	local data, _, _, _, record = validateRuntimeGroveTree(player, treeObject)
	return data ~= nil and record ~= nil
end

-- A successful harvest never consumes the planted tree: instead it creates
-- one unique protected log and starts another timed growth on the same stump.
-- This is server-only and triggered exclusively by TreeObject's lethal chop.
function GroveService.HarvestPersistentTree(player, treeObject)
	local data, plot, plotModel, area, record = validateRuntimeGroveTree(player, treeObject)
	if not data or not record or not isValidGroveTree(record) then return false end
	if os.clock() - (LastSuccessfulHarvestAt[player] or -math.huge)
		< GroveHarvestPresentation.HarvestCooldownSeconds then return false end

	local now = os.time()
	local cycle = GroveGrowthRules.NextCycle(record, now, Random.new():NextNumber())
	if not cycle then return false end

	-- Do not harvest (and do not reset growth) when protected storage cannot
	-- accept the one unique output. No coins, overflow or temporary cargo.
	local logUID = LogService.GrantGroveHarvestLog(player, {
		SpeciesId = record.SpeciesId,
		Mutations = copyMutations(record.Mutations),
		SizeScale = record.CurrentSizeScale,
		SourceGroveTreeUID = record.UID,
		SourceSaplingUID = record.SourceSaplingUID,
	})
	if not logUID then
		local economy = ReplicatedStorage:FindFirstChild("Economy")
		local notice = economy and economy:FindFirstChild("LogProcessingFXRE")
		if notice then
			notice:FireClient(player, {
				Mode = "StorageNotice",
				Message = "GROVE HARVEST BLOCKED: SAVED LOG STORAGE IS FULL.",
			})
		end
		return false
	end

	local groveUID = record.UID
	-- Atomic within this synchronous server callback: all validations above
	-- complete before the next cycle is committed and before a new TreeObject
	-- can be registered. A second lethal hit is rejected as stale.
	record.PlantedAt = cycle.PlantedAt
	record.MaturesAt = cycle.MaturesAt
	record.CurrentSizeScale = cycle.CurrentSizeScale
	record.HarvestCount = cycle.HarvestCount
	LastSuccessfulHarvestAt[player] = os.clock()
	RuntimeTreesByUID[groveUID] = nil
	-- This event is earned ONLY after a successful protected log award and
	-- committed persistent regrowth. No credit for early/blocked harvests.
	local questOk,questErr=pcall(QuestService.RecordGroveHarvested,
		player,groveUID,cycle.HarvestCount)
	if not questOk then warn("[Quests] Grove harvest credit failed",questErr) end

	-- Keep PlayerRuntimeUIDs[groveUID] reserved for cleanup until the new
	-- incarnation appears. The old dying tree is removed from ActiveTrees by
	-- TreeObject after this callback accepts the harvest.
	-- Inventory is already committed. The cinematic only reveals the reward;
	-- it does not control or authorize item grants.
	local reward = {
		RewardUID = logUID,
		GroveTreeUID = groveUID,
		SourceSaplingUID = record.SourceSaplingUID,
		SpeciesId = record.SpeciesId,
		SizeScale = treeObject.GroveCurrentSize,
		Mutations = copyMutations(record.Mutations),
		WorldCFrame = worldCFrameForRecord(area, record),
	}
	-- Post-commit presentation must NEVER throw back into TreeObject.Die:
	-- the log and growth-cycle change are already authoritative at this point.
	local inventoryNotified, inventoryError = pcall(LogService.NotifyState, player)
	if not inventoryNotified then warn("[Grove] Inventory state notice failed", inventoryError) end
	local groveNotified, groveError = pcall(publishState, player)
	if not groveNotified then warn("[Grove] Grove state notice failed", groveError) end
	local cinematicSent, cinematicError = pcall(function()
		GroveHarvestFXRE:FireClient(player, {
			Mode = "Start",
			RewardUID = logUID,
			GroveTreeUID = groveUID,
			TreeModel = treeObject.model,
			WorldCFrame = reward.WorldCFrame,
			SpeciesId = reward.SpeciesId,
			Mutations = copyMutations(reward.Mutations),
			SizeScale = reward.SizeScale,
		})
	end)
	if not cinematicSent then warn("[Grove] Cosmetic harvest start failed", cinematicError) end

	-- Leave enough time for the existing tree-fall animation to complete,
	-- then spawn an explicit stump; its lifetime is driven by plantedAt.
	task.delay(2.6, function()
		if not player:IsDescendantOf(Players) then return end
		if RestoredPlotByPlayer[player] ~= plot or RuntimeTreesByUID[groveUID] then return end
		local fresh = getProfileData(player)
		local assigned, freshPlotModel, freshArea = getAssignedGrove(player)
		local current = fresh and findUniqueGroveTree(fresh, groveUID)
		if assigned ~= plot or not freshPlotModel or not current
			or current.PlantedAt ~= cycle.PlantedAt
			or current.MaturesAt ~= cycle.MaturesAt
			or current.HarvestCount ~= cycle.HarvestCount then return end
		if not spawnGroveTree(player, freshPlotModel, freshArea, current) then
			warn("[Grove] Failed to spawn regrowing tree; recover on next plot restore", groveUID)
		end
	end)
	return true, reward
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
	if #data.GroveTrees >= Upgrades.Current(data.GroveLevel).Capacity
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
	local rolledSize = GroveGrowthRules.RollSize(sapling.SizePotential, Random.new():NextNumber())
	if not rolledSize then return false end
	local duration = GroveGrowthRules.DurationForSize(rolledSize,sapling.SpeciesId)
	if not duration then return false end
	local groveRecord = {
		UID = uid,
		SourceSaplingUID = sapling.UID,
		SpeciesId = sapling.SpeciesId,
		Mutations = copyMutations(sapling.Mutations),
		SizePotential = sapling.SizePotential,
		GeneticPassive = sapling.GeneticPassive,
		CurrentSizeScale = rolledSize,
		HarvestCount = 0,
		LocalX = localX,
		LocalZ = localZ,
		Yaw = yaw,
		PlantedAt = now,
		MaturesAt = now + duration,
	}

	-- Spawn before consuming. A missing visual or failed TreeObject leaves the
	-- source sapling untouched and creates no profile-side phantom tree.
	local treeObject = spawnGroveTree(player, plotModel, area, groveRecord)
	if not treeObject then return false end

	local sourceRecord = sapling
	local sourceIndex = saplingIndex
	local ok = pcall(function()
		table.insert(data.GroveTrees, groveRecord)
		table.remove(data.Saplings, sourceIndex)
	end)
	if not ok then
		removeByIdentity(data.GroveTrees, groveRecord)
		data.ActiveGroveTreeUIDs = {}
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
	local ownersChanged = {}
	for _, treeObject in pairs(RuntimeTreesByUID) do
		if treeObject and not treeObject.destroyed then
			local record = {
				PlantedAt = treeObject.GrovePlantedAt,
				MaturesAt = treeObject.GroveMaturesAt,
				HarvestCount = treeObject.GroveHarvestCount,
			}
			local stage = deriveStage(record, now)
			local stageChanged = stage ~= treeObject.GroveStage
			local progress = GroveGrowthRules.VisualProgress(record, now)
			-- Server polls every second for harvest stage changes, but visible
			-- geometry changes only at the configured visual milestone boundaries.
			if treeObject:SetGroveStage(stage, progress) and stageChanged then
				local player = Players:GetPlayerByUserId(treeObject.OwnerUserId)
				if player then ownersChanged[player] = true end
			end
		end
	end
	for owner in pairs(ownersChanged) do publishState(owner) end
end

function GroveService.Start()
	local station=require(game.ServerScriptService.WorldLayout.BaseStationAccess)
	if Started then return end
	Started = true
	GetGroveStateRF.OnServerInvoke = function(player, ...)
		if select("#", ...) ~= 0 then return nil end
		return GroveService.GetState(player)
	end
	UpgradeGroveRE.OnServerEvent:Connect(function(player, expectedLevel, ...)
		if select("#", ...) ~= 0 then return end
		local now = os.clock()
		if now - (LastUpgradeAt[player] or -math.huge) < 0.5 then return end
		LastUpgradeAt[player] = now
		if not station.CanUseGroveShop(player) then
			UpgradeGroveRE:FireClient(player,{Success=false,Reason="NOT_AT_GROVE_SHOP"})
			return
		end
		local data = getProfileData(player)
		local plot = getAssignedGrove(player)
		local reason = "GROVE_NOT_READY"
		local success = false
		if data and plot then
			local level = Upgrades.NormalizeLevel(data.GroveLevel)
			local nextUpgrade = Upgrades.Next(level)
			if expectedLevel ~= level then reason = "STALE_LEVEL"
			elseif not nextUpgrade then reason = "MAX_LEVEL"
			elseif not isFiniteNumber(data.Coins) or data.Coins < nextUpgrade.CoinCost then reason = "NOT_ENOUGH_COINS"
			else
				-- Non-yielding transaction. Only server configuration controls the price.
				data.Coins -= nextUpgrade.CoinCost
				data.GroveLevel = nextUpgrade.ToLevel
				success = true
				reason = "UPGRADED"
				EconomyUpdated:FireClient(player, "Coins", data.Coins)
			end
		end
		publishState(player)
		UpgradeGroveRE:FireClient(player, { Success = success, Reason = reason, Level = data and data.GroveLevel })
	end)
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
	UprootGroveTreeRE.OnServerEvent:Connect(function(player, ...)
		if select("#", ...) ~= 1 then return end
		local uid = ...
		if not isValidUID(uid) then return end
		local now = os.clock()
		if now - (LastUprootRequestAt[player] or -math.huge) < 0.4 then
			return
		end
		LastUprootRequestAt[player] = now
		if not station.CanUseGroveShop(player) then
			UprootGroveTreeRE:FireClient(player,{UID=uid,Success=false,Reason="NOT_AT_GROVE_SHOP"})
			return
		end
		local ok, success, reason = pcall(GroveService.UprootTree, player, uid)
		if not ok then
			warn("[Grove] Uproot request failed:", success)
			UprootGroveTreeRE:FireClient(player, {UID=uid, Success=false, Reason="SERVER_ERROR"})
			return
		end
		UprootGroveTreeRE:FireClient(player, {
			UID=uid,
			Success=success==true,
			Reason=if success then "UPROOTED" else reason or "INVALID_TREE",
		})
	end)
	task.spawn(function()
		while true do
			task.wait(GroveService.Constants.StageUpdateIntervalSeconds)
			updateRuntimeStages()
		end
	end)
end

return GroveService
