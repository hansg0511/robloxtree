-- Server-owned wild-tree sapling acquisition. This service intentionally does
-- not participate in ordinary log spawning, cargo capacity, or ground pickup.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LogService = require(game.ServerScriptService.Inventory.LogService)
local ProfileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local MutationDefinitions = require(script.Parent.MutationDefinitions)
local Passives = require(script.Parent.GrovePassiveRules)
local Quality = require(script.Parent.SaplingQualityRules)

local SaplingDiscoveryService = {}

SaplingDiscoveryService.Config = {
	-- Provisional; shop/quest sources and later economy balancing can
	-- change these without touching persistent mutation provenance.
	DropChance = 0.10, -- ordinary wild tree: ordinary sapling
	WildMutationChance = 0.06, -- visible rare wild tree per life
	MutatedDropChance = 0.20, -- rare wild tree -> matching rare sapling
}

-- Explicit definition-to-species eligibility prevents category-based or Grove
-- harvest rewards from ever becoming sapling discovery sources.
local ELIGIBLE_WILD_TREE_SPECIES = {
	StarterForestTree = "Oak",
	BambooClump = "Bamboo",
	Forest2Tree = "Ironwood",
}

local random = Random.new()
local processedTreeDeaths = setmetatable({}, { __mode = "k" })

local function getProfileData(player)
	local profile = ProfileCache.GetProfile(player)
	return profile and type(profile.Data) == "table" and profile.Data or nil
end

local function identityUIDIsUsed(data, uid)
	for _, collectionName in ipairs({ "Saplings", "GroveTrees", "GroveMaterials" }) do
		local collection = data[collectionName]
		if type(collection) == "table" then
			for _, record in pairs(collection) do
				if type(record) == "table"
					and (record.UID == uid
						or record.SourceSaplingUID == uid
						or record.SourceGroveTreeUID == uid) then
					return true
				end
			end
		end
	end
	return false
end

local function newSaplingUID(data)
	for _ = 1, 8 do
		local uid = HttpService:GenerateGUID(false)
		if type(uid) == "string" and #uid > 0 and not identityUIDIsUsed(data, uid) then
			return uid
		end
	end
	return nil
end

-- Every wild tree's mutation is rolled ON SPAWN and is visible in
-- its model. A discovered sapling inherits exactly that server-owned
-- mutation; it is never independently mutated by discovery RNG.
-- One mutation family per wild tree avoids unforgeable mixed-family wood.
function SaplingDiscoveryService.RollWildTreeMutations(chanceDraw,kindDraw)
	local chance=if type(chanceDraw)=="number" then chanceDraw else random:NextNumber()
	if type(chance)~="number" or chance~=chance or chance<0 or chance>=1
		or chance>=SaplingDiscoveryService.Config.WildMutationChance then return {} end
	local total=0
	for _,id in ipairs(MutationDefinitions.OrderedIds) do
		local definition=MutationDefinitions.ById[id]
		if definition and definition.Weight>0 then total+=definition.Weight end
	end
	if total<=0 then return {} end
	local roll=if type(kindDraw)=="number" then kindDraw else random:NextNumber()
	if type(roll)~="number" or roll~=roll or roll<0 or roll>=1 then return {} end
	local threshold=roll*total
	local count=0
	for _,id in ipairs(MutationDefinitions.OrderedIds) do
		local definition=MutationDefinitions.ById[id]
		if definition and definition.Weight>0 then
			count+=definition.Weight
			if threshold<count then return {[id]=true} end
		end
	end
	return {}
end

local function rollSizePotential(mutations,speciesId)
	return Quality.Wild(mutations, random,speciesId)
end

local function makeClientRecord(record)
	return {
		UID = record.UID,
		SpeciesId = record.SpeciesId,
		Mutations = MutationDefinitions.CopyKnown(record.Mutations),
		SizePotential = record.SizePotential,
		GeneticPassive = record.GeneticPassive,
	}
end

local function isEligibleTree(tree)
	if type(tree) ~= "table"
		or tree.isDead ~= true
		or tree.destroyed
		or tree.IsPersistentGrove
		or tree.YieldsLog ~= true then
		return nil
	end
	local speciesId = ELIGIBLE_WILD_TREE_SPECIES[tree.DefinitionId]
	if type(speciesId) ~= "string" or tree.SpeciesId ~= speciesId then return nil end
	return speciesId
end

function SaplingDiscoveryService.AwardForTreeDeath(tree, contributions, deathGeneration)
	if type(tree) ~= "table"
		or type(deathGeneration) ~= "number"
		or deathGeneration % 1 ~= 0
		or tree.DeathGeneration ~= deathGeneration
		or processedTreeDeaths[tree] == deathGeneration then
		return nil
	end
	processedTreeDeaths[tree] = deathGeneration

	local speciesId = isEligibleTree(tree)
	if not speciesId then return nil end

	-- This is the same highest-valid-damage / lowest-UserId-on-tie rule used by
	-- ordinary wild-log rewards. It remains independent of log pickup success.
	local winner = LogService.GetTreeAwardWinner(contributions)
	local inherited=MutationDefinitions.CopyKnown(tree.Mutations)
	local hasMutation=next(inherited)~=nil
	local chance=if hasMutation then SaplingDiscoveryService.Config.MutatedDropChance
		else SaplingDiscoveryService.Config.DropChance
	if not winner then return nil end
	local data = getProfileData(winner)
	if not data then return nil end
	chance = math.clamp(chance * (1 + Passives.Totals(data, os.time()).SaplingChance), 0, 1)
	if random:NextNumber() >= chance then return nil end
	if type(data.Saplings) ~= "table" then data.Saplings = {} end

	local uid = newSaplingUID(data)
	if not uid then return nil end
	local record = {
		UID = uid,
		SpeciesId = speciesId,
		Mutations = inherited,
		SizePotential = rollSizePotential(inherited,speciesId),
		GeneticPassive = Passives.RollGenetic(),
		CreatedAt = os.time(),
	}
	if type(record.CreatedAt) ~= "number" or record.CreatedAt < 0 then return nil end

	table.insert(data.Saplings, record)
	require(game.ServerScriptService.LifetimeStatsRules).RecordSaplingDiscovery(data,record.SizePotential)
	-- Resolve lazily to avoid a TreeObject → discovery → GroveService require
	-- cycle at module load. A discovery must advance the snapshot revision before
	-- the client performs its normal refresh.
	pcall(function()
		local GroveService = require(game.ServerScriptService.Grove.GroveService)
		GroveService.NotifyState(winner)
	end)
	local groveFolder = ReplicatedStorage:FindFirstChild("Grove")
	local discoveredEvent = groveFolder and groveFolder:FindFirstChild("SaplingDiscoveredRE")
	if discoveredEvent and discoveredEvent:IsA("RemoteEvent") then
		discoveredEvent:FireClient(winner, makeClientRecord(record))
	end
	return record
end

return SaplingDiscoveryService
