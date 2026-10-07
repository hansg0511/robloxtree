local profileType = require(script.Parent.DefaultPlayerData)
local playerProfileFolder = game.ServerScriptService.PlayerProfile
local profileBindableEvent = playerProfileFolder.ProfileInit.ProfileLoadedEvent
local profileRemoteEvent = game.ReplicatedStorage.Profile.ProfileLoadEvent
local ProfileService = playerProfileFolder.ProfileService
local AxeShopCatalog = require(game.ServerScriptService.Economy.AxeShopCatalog)
local MaterialDefinitions = require(game.ServerScriptService.Economy.MaterialDefinitions)

local PlayerProfileCache = {}

local Profiles: { [Player]: any } = {}

local function isNonnegativeInteger(value)
	return type(value) == "number"
		and value == value
		and value >= 0
		and value < math.huge
		and value % 1 == 0
end

local MAX_GROVE_UID_LENGTH = 80
local MAX_GROVE_COORDINATE = 512
local MIN_SIZE_POTENTIAL = 0.1
local MAX_SIZE_POTENTIAL = 2

local function isFiniteNumber(value)
	return type(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
end

local function isValidGroveUID(value)
	return type(value) == "string"
		and #value > 0
		and #value <= MAX_GROVE_UID_LENGTH
		and string.match(value, "%S") ~= nil
		and string.match(value, "[%c]") == nil
end

local function copyGroveMutations(value)
	local copy = {}
	if type(value) ~= "table" then return copy end
	for key, mutation in pairs(value) do
		if type(key) == "string" and #key > 0 and #key <= 80 and string.match(key, "[%c]") == nil then
			local mutationType = type(mutation)
			if mutationType == "string" and #mutation <= 80 and string.match(mutation, "[%c]") == nil then
				copy[key] = mutation
			elseif mutationType == "boolean" then
				copy[key] = mutation
			elseif mutationType == "number" and isFiniteNumber(mutation) then
				copy[key] = mutation
			end
		end
	end
	return copy
end

local function isValidGroveBaseRecord(record)
	return type(record) == "table"
		and isValidGroveUID(record.UID)
		and type(record.SpeciesId) == "string"
		and MaterialDefinitions.Get(record.SpeciesId) ~= nil
		and isFiniteNumber(record.SizePotential)
		and record.SizePotential >= MIN_SIZE_POTENTIAL
		and record.SizePotential <= MAX_SIZE_POTENTIAL
end

local function isValidSaplingRecord(record)
	return isValidGroveBaseRecord(record)
		and type(record.Mutations) == "table"
		and isFiniteNumber(record.CreatedAt)
		and record.CreatedAt >= 0
end

local function isValidGroveTreeRecord(record)
	return isValidGroveBaseRecord(record)
		and isValidGroveUID(record.SourceSaplingUID)
		and record.SourceSaplingUID ~= record.UID
		and type(record.Mutations) == "table"
		and isFiniteNumber(record.LocalX)
		and math.abs(record.LocalX) <= MAX_GROVE_COORDINATE
		and isFiniteNumber(record.LocalZ)
		and math.abs(record.LocalZ) <= MAX_GROVE_COORDINATE
		and isFiniteNumber(record.Yaw)
		and math.abs(record.Yaw) <= math.pi * 2
		and isFiniteNumber(record.PlantedAt)
		and record.PlantedAt >= 0
		and isFiniteNumber(record.MaturesAt)
		and record.MaturesAt > record.PlantedAt
end

local function isValidHeartwoodRecord(record)
	return isValidGroveBaseRecord(record)
		and record.MaterialType == "Heartwood"
		and type(record.Mutations) == "table"
		and isValidGroveUID(record.SourceGroveTreeUID)
		and isValidGroveUID(record.SourceSaplingUID)
		and record.SourceGroveTreeUID ~= record.SourceSaplingUID
		and record.UID ~= record.SourceGroveTreeUID
		and record.UID ~= record.SourceSaplingUID
		and isFiniteNumber(record.CreatedAt)
		and record.CreatedAt >= 0
end

local function countRawRecordUIDs(records, counts)
	if type(records) ~= "table" then return end
	for _, record in pairs(records) do
		if type(record) == "table" and isValidGroveUID(record.UID) then
			counts[record.UID] = (counts[record.UID] or 0) + 1
		end
	end
end

local function countRawSourceUIDs(records, fieldName, counts)
	if type(records) ~= "table" then return end
	for _, record in pairs(records) do
		if type(record) == "table" then
			local uid = record[fieldName]
			if isValidGroveUID(uid) then
				counts[uid] = (counts[uid] or 0) + 1
			end
		end
	end
end

-- Grove profile values are deliberately rebuilt from primitive fields only.
-- This drops Instances/userdata, malformed rows, duplicate record IDs, and
-- invalid world-placement/timestamp values before they can become runtime trees.
function PlayerProfileCache.NormalizeGroveData(data)
	if type(data) ~= "table" then return false end

	local rawSaplings = data.Saplings
	local rawGroveTrees = data.GroveTrees
	local rawGroveMaterials = data.GroveMaterials
	local uidCounts = {}
	countRawRecordUIDs(rawSaplings, uidCounts)
	countRawRecordUIDs(rawGroveTrees, uidCounts)
	countRawRecordUIDs(rawGroveMaterials, uidCounts)

	local sourceSaplingUIDCounts = {}
	countRawSourceUIDs(rawGroveTrees, "SourceSaplingUID", sourceSaplingUIDCounts)
	countRawSourceUIDs(rawGroveMaterials, "SourceSaplingUID", sourceSaplingUIDCounts)
	local sourceGroveTreeUIDCounts = {}
	countRawSourceUIDs(rawGroveMaterials, "SourceGroveTreeUID", sourceGroveTreeUIDCounts)

	local saplings = {}
	if type(rawSaplings) == "table" then
		for _, record in pairs(rawSaplings) do
			if isValidSaplingRecord(record)
				and uidCounts[record.UID] == 1 then
				table.insert(saplings, {
					UID = record.UID,
					SpeciesId = record.SpeciesId,
					Mutations = copyGroveMutations(record.Mutations),
					SizePotential = record.SizePotential,
					CreatedAt = record.CreatedAt,
				})
			end
		end
	end

	local groveTrees = {}
	if type(rawGroveTrees) == "table" then
		for _, record in pairs(rawGroveTrees) do
			if isValidGroveTreeRecord(record)
				and uidCounts[record.SourceSaplingUID] == nil
				and sourceSaplingUIDCounts[record.SourceSaplingUID] == 1
				and uidCounts[record.UID] == 1 then
				table.insert(groveTrees, {
					UID = record.UID,
					SourceSaplingUID = record.SourceSaplingUID,
					SpeciesId = record.SpeciesId,
					Mutations = copyGroveMutations(record.Mutations),
					SizePotential = record.SizePotential,
					LocalX = record.LocalX,
					LocalZ = record.LocalZ,
					Yaw = record.Yaw,
					PlantedAt = record.PlantedAt,
					MaturesAt = record.MaturesAt,
				})
			end
		end
	end

	local groveMaterials = {}
	if type(rawGroveMaterials) == "table" then
		for _, record in pairs(rawGroveMaterials) do
			if isValidHeartwoodRecord(record)
				and uidCounts[record.UID] == 1
				and uidCounts[record.SourceGroveTreeUID] == nil
				and uidCounts[record.SourceSaplingUID] == nil
				and sourceSaplingUIDCounts[record.SourceSaplingUID] == 1
				and sourceGroveTreeUIDCounts[record.SourceGroveTreeUID] == 1 then
				table.insert(groveMaterials, {
					UID = record.UID,
					MaterialType = "Heartwood",
					SpeciesId = record.SpeciesId,
					Mutations = copyGroveMutations(record.Mutations),
					SizePotential = record.SizePotential,
					SourceGroveTreeUID = record.SourceGroveTreeUID,
					SourceSaplingUID = record.SourceSaplingUID,
					CreatedAt = record.CreatedAt,
				})
			end
		end
	end
	data.Saplings = saplings
	data.GroveTrees = groveTrees
	data.GroveMaterials = groveMaterials
	-- Until Milestone 3, Grove trees are not represented as active/passive refs.
	data.ActiveGroveTreeUIDs = {}
	return true
end

local function normalizeProgressionData(data)
	if type(data.AxeHeads) ~= "table" then
		data.AxeHeads = {}
	end
	for headId, count in pairs(data.AxeHeads) do
		if type(headId) ~= "string" or not isNonnegativeInteger(count) then
			data.AxeHeads[headId] = nil
		end
	end
	for _, head in ipairs(AxeShopCatalog.AxeHeads) do
		if data.AxeHeads[head.Id] == nil then
			data.AxeHeads[head.Id] = 0
		end
	end

	if type(data.RunProgress) ~= "table" then
		data.RunProgress = {}
	end
	local runProgress = data.RunProgress
	if not isNonnegativeInteger(runProgress.StandardAxeTier) then
		runProgress.StandardAxeTier = 0
	end
	if type(runProgress.UnlockedForests) ~= "table" then
		runProgress.UnlockedForests = {}
	end
	local unlockedForests = runProgress.UnlockedForests
	-- The base and first forest are the entry point for every valid profile.
	unlockedForests.Base = true
	unlockedForests.Forest1 = true
	if unlockedForests.Forest2 == nil or type(unlockedForests.Forest2) ~= "boolean" then
		unlockedForests.Forest2 = false
	end
	for forestId, unlocked in pairs(unlockedForests) do
		if type(forestId) ~= "string" or type(unlocked) ~= "boolean" then
			unlockedForests[forestId] = nil
		end
	end
end

export type PlayerProfileCache = {
	Set: (player: Player, profile: profileType.PlayerData) -> (),
	Get: (player: Player) -> (profileType.PlayerData),
	Remove: (player: Player) -> (),
	NormalizeCarryCapacity: (data: { [string]: any }) -> number,
	NormalizeGroveData: (data: { [string]: any }) -> boolean,
	FireLoaded: (profile: profileType.PlayerData) -> ()
}

local function BuildRuntime(profile)
	local runtime = {
		Weapon = {},
		Pet = {},
		Seed= {},
		FinalStats= {},
		EquippedWeaponUID = nil,
		EquippedWeaponTool = nil,
		EphemeralWeaponUIDs = {},
		DebugProAxeUID = nil,
	}
	profile.Data.Runtime = runtime
end

-- CarryCapacityKg has the same prototype numeric tiers as the old LogCapacity
-- field, but now denotes kilograms. This runs before Profile:Reconcile so an
-- injected default cannot mask a legacy value.
function PlayerProfileCache.NormalizeCarryCapacity(data)
	if type(data) ~= "table" then return AxeShopCatalog.DEFAULT_CAPACITY_KG end
	-- Only profiles without the new field migrate from LogCapacity. If the new
	-- field exists but contains an unofficial value, normalization safely falls
	-- back to the starter tier instead of trusting stale/conflicting old data.
	local sourceCapacityKg = if data.CarryCapacityKg == nil then data.LogCapacity else data.CarryCapacityKg
	local capacityKg = AxeShopCatalog.NormalizeCarryCapacityKg(sourceCapacityKg)
	data.CarryCapacityKg = capacityKg
	data.LogCapacity = nil
	return capacityKg
end

function PlayerProfileCache.Set(player: Player, profile)
	if profile and type(profile.Data) == "table" then
		PlayerProfileCache.NormalizeCarryCapacity(profile.Data)
		PlayerProfileCache.NormalizeGroveData(profile.Data)
		normalizeProgressionData(profile.Data)
	end
	BuildRuntime(profile)
	Profiles[player] = profile
end

-- Get full profile
function PlayerProfileCache.GetProfile(player: Player)
	return Profiles[player]
end

-- Get typed data only (autocomplete!)
function PlayerProfileCache.GetData(player: Player): profileType.PlayerData?
	local profile = Profiles[player]
	if not profile then return nil end
	return profile.Data :: profileType.PlayerData
end

-- Build RunTimeCache


-- Cleanup
function PlayerProfileCache.Remove(player: Player)
	Profiles[player] = nil
end


return PlayerProfileCache
