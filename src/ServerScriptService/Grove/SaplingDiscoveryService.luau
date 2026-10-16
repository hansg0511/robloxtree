-- Server-owned wild-tree sapling acquisition. This service intentionally does
-- not participate in ordinary log spawning, cargo capacity, or ground pickup.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LogService = require(game.ServerScriptService.Inventory.LogService)
local ProfileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local MutationDefinitions = require(script.Parent.MutationDefinitions)

local SaplingDiscoveryService = {}

SaplingDiscoveryService.Config = {
	-- Provisional 3A balance values. Keep these centralized for later tuning.
	DropChance = 0.10,
	MutationCountWeights = {
		{ Count = 0, Weight = 0.75 },
		{ Count = 1, Weight = 0.22 },
		{ Count = 2, Weight = 0.03 },
	},
	SizePotentialMinimum = 0.85,
	SizePotentialMaximum = 1.15,
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

local function rollMutationCount()
	local totalWeight = 0
	for _, entry in ipairs(SaplingDiscoveryService.Config.MutationCountWeights) do
		totalWeight += entry.Weight
	end
	if totalWeight <= 0 then return 0 end

	local roll = random:NextNumber(0, totalWeight)
	local accumulated = 0
	for _, entry in ipairs(SaplingDiscoveryService.Config.MutationCountWeights) do
		accumulated += entry.Weight
		if roll <= accumulated then return entry.Count end
	end
	return 0
end

local function rollMutations()
	local selected = {}
	local excluded = {}
	for _ = 1, rollMutationCount() do
		local totalWeight = 0
		for _, id in ipairs(MutationDefinitions.OrderedIds) do
			local definition = MutationDefinitions.ById[id]
			if not excluded[id] and definition then totalWeight += definition.Weight end
		end
		if totalWeight <= 0 then break end

		local roll = random:NextNumber(0, totalWeight)
		local accumulated = 0
		for _, id in ipairs(MutationDefinitions.OrderedIds) do
			local definition = MutationDefinitions.ById[id]
			if not excluded[id] and definition then
				accumulated += definition.Weight
				if roll <= accumulated then
					selected[id] = true
					excluded[id] = true
					break
				end
			end
		end
	end
	return selected
end

local function rollSizePotential()
	local minimum = SaplingDiscoveryService.Config.SizePotentialMinimum
	local maximum = SaplingDiscoveryService.Config.SizePotentialMaximum
	-- Averaging three uniform samples creates a modest center-weighted roll while
	-- retaining the explicitly bounded Grove validation range.
	local normalized = (random:NextNumber() + random:NextNumber() + random:NextNumber()) / 3
	local value = minimum + (maximum - minimum) * normalized
	return math.floor(value * 1000 + 0.5) / 1000
end

local function makeClientRecord(record)
	return {
		UID = record.UID,
		SpeciesId = record.SpeciesId,
		Mutations = MutationDefinitions.CopyKnown(record.Mutations),
		SizePotential = record.SizePotential,
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
	if not winner or random:NextNumber() >= SaplingDiscoveryService.Config.DropChance then
		return nil
	end

	local data = getProfileData(winner)
	if not data then return nil end
	if type(data.Saplings) ~= "table" then data.Saplings = {} end

	local uid = newSaplingUID(data)
	if not uid then return nil end
	local record = {
		UID = uid,
		SpeciesId = speciesId,
		Mutations = rollMutations(),
		SizePotential = rollSizePotential(),
		CreatedAt = os.time(),
	}
	if type(record.CreatedAt) ~= "number" or record.CreatedAt < 0 then return nil end

	table.insert(data.Saplings, record)
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
