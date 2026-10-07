-- Prototype progression configuration. Standard axes are deterministic recipes;
-- special/RNG crafting is intentionally outside this catalog for now.
local AxeShopCatalog = {}

AxeShopCatalog.AxeHeads = {
	{
		Id = "copper_head",
		Name = "Copper Axe Head",
		Price = 150,
		RequiredForestId = "Forest1",
		Tier = 1,
	},
	{
		Id = "iron_head",
		Name = "Iron Axe Head",
		Price = 750,
		RequiredForestId = "Forest2",
		Tier = 2,
	},
}

AxeShopCatalog.StandardAxeRecipes = {
	{
		Id = "copper_axe",
		Name = "Copper Axe",
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
		HeadId = "iron_head",
		OutputItemID = 103,
		Tier = 2,
		RequiredLogCount = 3,
		HeadBasePower = 17,
		RequiredForestId = "Forest2",
	},
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
