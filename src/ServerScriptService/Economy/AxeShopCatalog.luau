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
		Wood = {
			SpeciesId = "Oak",
			Count = 3,
		},
		OutputItemID = 102,
		Tier = 1,
		Power = 16,
		RequiredForestId = "Forest1",
	},
	{
		Id = "iron_axe",
		Name = "Iron Axe",
		HeadId = "iron_head",
		Wood = {
			SpeciesId = "Ironwood",
			Count = 3,
		},
		OutputItemID = 103,
		Tier = 2,
		Power = 26,
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
-- the amount needed to reach the fixed Power configured above.
AxeShopCatalog.BaseAttack = 5

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

return AxeShopCatalog
