-- Forge progression configuration. RNG is the only active craft path.
-- Legacy fixed recipe definitions remain solely for saved-item compatibility.
local AxeShopCatalog = {}

AxeShopCatalog.AxeHeads = {
	{
		Id = "copper_head",
		Name = "Copper Axe Head",
		Price = 60, -- first full starter bag can fund a head while retaining three logs
		RequiredForestId = "Forest1",
		Tier = 1,
	},
	{
		Id = "iron_head",
		Name = "Iron Axe Head",
		Price = 750,
		RequiredForestId = "Forest3",
		Tier = 2,
	},
}

AxeShopCatalog.StandardAxeRecipes = {
	{
		Id = "copper_axe",
		Name = "Copper Axe",
		WeaponKind = "Axe",
		HeadId = "copper_head",
		OutputItemID = 102,
		Tier = 1,
		RequiredLogCount = 3,
		HeadBasePower = 13,
		RequiredForestId = "Forest1",
	},
	{
		Id = "iron_axe",
		Name = "Iron Axe",
		WeaponKind = "Axe",
		HeadId = "iron_head",
		OutputItemID = 103,
		Tier = 2,
		RequiredLogCount = 3,
		HeadBasePower = 17,
		RequiredForestId = "Forest3",
	},
}

-- Active RNG recipes. Keep component IDs and recipe IDs stable for existing saves.
-- Legacy fixed recipes above are not exposed or accepted by the forge.
-- OutputItemID values refer to existing Tool models, not final dagger/hammer art.
AxeShopCatalog.ExperimentalForgeRecipes = {
	{
		Id = "experiment_copper",
		Name = "COPPER BLANK • FORGE",
		HeadId = "copper_head",
		Tier = 1,
		HeadBasePower = 25,
		RequiredForestId = "Forest1",
		Outputs = { Dagger = 101, Axe = 102, Battlehammer = 105 },
	},
	{
		Id = "experiment_iron",
		Name = "IRON BLANK • FORGE",
		HeadId = "iron_head",
		Tier = 2,
		HeadBasePower = 55,
		RequiredForestId = "Forest3",
		Outputs = { Dagger = 101, Axe = 103, Battlehammer = 105 },
	},
}

function AxeShopCatalog.FindExperimentalForgeRecipe(recipeId)
	if type(recipeId) ~= "string" then return nil end
	for _, entry in ipairs(AxeShopCatalog.ExperimentalForgeRecipes) do
		if entry.Id == recipeId then return entry end
	end
	return nil
end

-- Prototype one-step workstation upgrade; more forge tiers later.
AxeShopCatalog.ForgeLevelUpgrade = {
	ToLevel = 2,
	CoinCost = require(game.ReplicatedStorage.Shared.ProgressionConfig).UpgradeCost(2),
}

AxeShopCatalog.DEFAULT_CAPACITY_KG = 10
AxeShopCatalog.MAX_CAPACITY_KG = 40
AxeShopCatalog.CAPACITY_TIERS_KG = { 10, 15, 20, 30, 40 }

AxeShopCatalog.CapacityUpgrades = {
	{ CapacityKg = 15, Price = 250 },
	{ CapacityKg = 20, Price = 1000 },
	{ CapacityKg = 30, Price = 4000 },
	{ CapacityKg = 40, Price = 15000 },
}

function AxeShopCatalog.NormalizeCarryCapacityKg(value)
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return AxeShopCatalog.DEFAULT_CAPACITY_KG
	end
	for _, capacityTierKg in ipairs(AxeShopCatalog.CAPACITY_TIERS_KG) do
		if value == capacityTierKg then
			return capacityTierKg
		end
	end
	return AxeShopCatalog.DEFAULT_CAPACITY_KG
end

function AxeShopCatalog.FindNextCapacityUpgrade(currentCapacityKg)
	if type(currentCapacityKg) ~= "number" or currentCapacityKg ~= currentCapacityKg
		or math.abs(currentCapacityKg) == math.huge then
		return nil
	end
	for _, entry in ipairs(AxeShopCatalog.CapacityUpgrades) do
		if entry.CapacityKg > currentCapacityKg then
			return entry
		end
	end
	return nil
end

-- StatsAggregator contributes a base Attack of 5. Crafted records store only
-- the amount needed to reach the power derived from the head and materials.
AxeShopCatalog.BaseAttack = 5

local function isNonnegativeFinite(value)
	return type(value) == "number"
		and value == value
		and value >= 0
		and math.abs(value) < math.huge
end

function AxeShopCatalog.FindAxeHead(headId)
	if type(headId) ~= "string" then return nil end
	for _, entry in ipairs(AxeShopCatalog.AxeHeads) do
		if entry.Id == headId then return entry end
	end
	return nil
end

function AxeShopCatalog.FindStandardAxeRecipe(recipeId)
	if type(recipeId) ~= "string" then return nil end
	for _, entry in ipairs(AxeShopCatalog.StandardAxeRecipes) do
		if entry.Id == recipeId then return entry end
	end
	return nil
end

function AxeShopCatalog.FindRecipeForOutput(itemId)
	for _, entry in ipairs(AxeShopCatalog.StandardAxeRecipes) do
		if entry.OutputItemID == itemId then return entry end
	end
	return nil
end

-- Resolve progression from persisted weapon metadata first, then legacy item
-- identities. Unknown or malformed weapons fail closed instead of receiving
-- an implicit tier.
function AxeShopCatalog.ResolveAxeTier(itemRecord)
	if type(itemRecord) ~= "table" then return nil end
	local weaponData = itemRecord.WeaponData
	if type(weaponData) == "table" and weaponData.AxeTier ~= nil then
		if isNonnegativeFinite(weaponData.AxeTier) then
			return weaponData.AxeTier
		end
		return nil
	end

	local legacyTiers = {
		[101] = 0,
		[102] = 1,
		[103] = 2,
		[9001] = 999,
	}
	return legacyTiers[itemRecord.ItemID]
end

return AxeShopCatalog
