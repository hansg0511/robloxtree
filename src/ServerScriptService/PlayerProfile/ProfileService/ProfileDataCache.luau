local profileType = require(script.Parent.DefaultPlayerData)
local playerProfileFolder = game.ServerScriptService.PlayerProfile
local profileBindableEvent = playerProfileFolder.ProfileInit.ProfileLoadedEvent
local profileRemoteEvent = game.ReplicatedStorage.Profile.ProfileLoadEvent
local ProfileService = playerProfileFolder.ProfileService
local AxeShopCatalog = require(game.ServerScriptService.Economy.AxeShopCatalog)
local MaterialDefinitions = require(game.ServerScriptService.Economy.MaterialDefinitions)
local MutationDefinitions = require(game.ServerScriptService.Grove.MutationDefinitions)
local GroveGrowthRules = require(game.ServerScriptService.Grove.GroveGrowthRules)
local GroveUpgrades = require(game.ServerScriptService.Grove.GroveUpgradeRules)
local GrovePassives = require(game.ServerScriptService.Grove.GrovePassiveRules)
local QuestRules = require(game.ServerScriptService.Quests.QuestRules)
local ChopLeaderboardRules = require(game.ServerScriptService.ChopLeaderboardRules)
local ItemDataBase = require(game.ServerStorage.Items.ItemDataBase)
local WeaponProgressionRules = require(game.ServerScriptService.WeaponProgressionRules)
local SlotRules=require(game.ServerScriptService.Economy.WeaponUpgradeRules)
local ProgressionConfig=require(game.ReplicatedStorage.Shared.ProgressionConfig)
local Premium=require(game.ReplicatedStorage.Shared.PremiumEconomyConfig)

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
local MAX_SIZE_POTENTIAL = GroveGrowthRules.MAX_POTENTIAL

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
	return MutationDefinitions.CopyKnown(value)
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

	-- Grove trees and earned Heartwood may refer to the SAME planted
	-- sapling. These are separate, legitimate provenance relationships.
	-- Counting both in one map used to silently DELETE the entire Grove
	-- tree and Heartwood upon profile reload after the first harvest.
	local sourceSaplingUIDCounts = {}
	countRawSourceUIDs(rawGroveTrees, "SourceSaplingUID", sourceSaplingUIDCounts)
	local heartwoodSaplingUIDCounts = {}
	countRawSourceUIDs(rawGroveMaterials, "SourceSaplingUID", heartwoodSaplingUIDCounts)
	local sourceGroveTreeUIDCounts = {}
	countRawSourceUIDs(rawGroveMaterials, "SourceGroveTreeUID", sourceGroveTreeUIDCounts)
	local rawTreeByUID = {}
	if type(rawGroveTrees)=="table" then
		for _,tree in pairs(rawGroveTrees) do
			if type(tree)=="table" and isValidGroveUID(tree.UID)
				and uidCounts[tree.UID]==1 then
				rawTreeByUID[tree.UID]=tree
			end
		end
	end

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
					GeneticPassive = GrovePassives.NormalizeGenetic(record.GeneticPassive, record.UID),
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
					GeneticPassive = GrovePassives.NormalizeGenetic(record.GeneticPassive, record.SourceSaplingUID),
					CurrentSizeScale = GroveGrowthRules.NormalizeCurrentSize(record.CurrentSizeScale, record.SizePotential),
					HarvestCount = GroveGrowthRules.NormalizeHarvestCount(record.HarvestCount),
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
				and (uidCounts[record.SourceGroveTreeUID]==nil
					or (uidCounts[record.SourceGroveTreeUID]==1
						and rawTreeByUID[record.SourceGroveTreeUID]~=nil
						and rawTreeByUID[record.SourceGroveTreeUID].SourceSaplingUID
							==record.SourceSaplingUID
						and rawTreeByUID[record.SourceGroveTreeUID].SpeciesId
							==record.SpeciesId))
				and uidCounts[record.SourceSaplingUID] == nil
				and heartwoodSaplingUIDCounts[record.SourceSaplingUID] == 1
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
	data.GroveLevel = GroveUpgrades.NormalizeLevel(data.GroveLevel)
	data.Saplings = saplings
	data.GroveTrees = groveTrees
	data.GroveMaterials = groveMaterials
	-- Until Milestone 3, Grove trees are not represented as active/passive refs.
	data.ActiveGroveTreeUIDs = {}
	return true
end

-- The tutorial campaign is a small, one-time persisted state machine.
-- Normalize legacy/malformed saves without changing any currency/materials.
function PlayerProfileCache.NormalizeQuestProgress(data)
	if type(data)~="table" then return false end
	data.QuestProgress=QuestRules.Normalize(data.QuestProgress)
	return true
end

-- Migrates old saves without recurring tasks; never changes coins or rewards.
function PlayerProfileCache.NormalizeRecurringQuestProgress(data)
	if type(data)~="table" then return false end
	local clean=QuestRules.NormalizeRecurring(data.QuestRecurring,os.time())
	if not clean then return false end
	data.QuestRecurring=clean
	return true
end

-- Normalize legacy leaderboard data without granting past or unverified kills.
function PlayerProfileCache.NormalizeChopLeaderboard(data)
	if type(data) ~= "table" then return false end
	local clean = ChopLeaderboardRules.Normalize(data.ChopLeaderboard, os.time())
	if not clean then return false end
	data.ChopLeaderboard = clean
	return true
end

-- Normalize persisted, unique weapon records BEFORE ItemDataBase parses them
-- into the transient runtime equipment cache. Skip non-weapons and the
-- session-only debug axe (which must never become a progression candidate).
function PlayerProfileCache.NormalizeWeaponData(data)
	if type(data) ~= "table" or type(data.Inventory) ~= "table" then return false end
	for _, item in ipairs(data.Inventory) do
		if type(item) == "table" and item.ItemID ~= 9001 then
			local definition = ItemDataBase.Info[item.ItemID]
			if definition and definition.Type == "Weapon" then
				WeaponProgressionRules.NormalizeWeaponItem(item)
				if ProgressionConfig.HasSecondSlot(item.Rarity) then
					local level=type(data.RunProgress)=="table" and data.RunProgress.ForgeLevel or 1
					if not ProgressionConfig.ValidForge(level) then level=1 end
					level=math.max(level,ProgressionConfig.RequiredForge(item.Rarity))
					local granted,reason=SlotRules.GrantSecond(item.WeaponData,item.Rarity,level,Random.new())
					if granted then item.WeaponData=granted else warn("[Mutation migration]",item.UID,reason) end
				end
			end
		end
	end
	return true
end

local function normalizeProgressionData(data)
	-- Persistent per-offer purchase counts for the current restock.
	if type(data.SaplingShop)~="table" then data.SaplingShop={} end
	local shop=data.SaplingShop
	if not isNonnegativeInteger(shop.Cycle) or shop.Cycle>1000000000 then shop.Cycle=-1; shop.Purchased={} end
	if type(shop.Purchased)~="table" then shop.Purchased={} end
	for id,count in pairs(shop.Purchased) do
		if type(id)~="string" or #id>90 or not isNonnegativeInteger(count) or count>96 then shop.Purchased[id]=nil end
	end
	if not isNonnegativeInteger(shop.RareBoughtCycle) or shop.RareBoughtCycle>1000000000 then shop.RareBoughtCycle=-1 end
	-- Future stackable upgrade ingredients. Keep owned nonnegative counts
	-- during migration, reject malformed IDs, NaN and negative balances.
	if type(data.MaterialBalances) ~= "table" then
		data.MaterialBalances = {}
	end
	for id, count in pairs(data.MaterialBalances) do
		if type(id) ~= "string" or #id < 1 or #id > 80
			or id:find("[%c]") or not isNonnegativeInteger(count) then
			data.MaterialBalances[id] = nil
		end
	end

	for _,id in ipairs({Premium.PREMIUM,Premium.CRYSTAL}) do
		if data.MaterialBalances[id]==nil then data.MaterialBalances[id]=0 end
	end
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
	-- Permanent Forge workstation upgrade, separate from existing axe
	-- progression. Older profiles start at tier 1 with no data loss.
	if not isNonnegativeInteger(runProgress.ForgeLevel) then runProgress.ForgeLevel=1 end
	runProgress.ForgeLevel=math.clamp(runProgress.ForgeLevel,1,require(game.ReplicatedStorage.Shared.ForgeMutationRules).MAX_LEVEL)
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
	NormalizeQuestProgress: (data: { [string]: any }) -> boolean,
	NormalizeRecurringQuestProgress: (data: { [string]: any }) -> boolean,
	NormalizeChopLeaderboard: (data: { [string]: any }) -> boolean,
	NormalizeWeaponData: (data: { [string]: any }) -> boolean,
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
		PlayerProfileCache.NormalizeQuestProgress(profile.Data)
		PlayerProfileCache.NormalizeRecurringQuestProgress(profile.Data)
		PlayerProfileCache.NormalizeChopLeaderboard(profile.Data)
		PlayerProfileCache.NormalizeWeaponData(profile.Data)
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
