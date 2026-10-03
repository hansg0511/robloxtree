-- Prototype shop values. These are deliberately centralized and are not final balance.
local AxeShopCatalog = {}

AxeShopCatalog.Axes = {
	{
		Id = "starter_hatchet",
		Name = "Starter Hatchet",
		ItemID = 101,
		Power = 10,
		Price = 0,
	},
	{
		Id = "copper_axe",
		Name = "Copper Axe",
		ItemID = 102,
		Power = 16,
		Price = 150,
	},
	{
		Id = "iron_axe",
		Name = "Iron Axe",
		ItemID = 103,
		Power = 26,
		Price = 750,
	},
	{
		Id = "steel_axe",
		Name = "Steel Axe",
		ItemID = 104,
		Power = 42,
		Price = 3000,
	},
	{
		Id = "heavy_cleaver",
		Name = "Heavy Cleaver",
		ItemID = 105,
		Power = 68,
		Price = 12000,
	},
}

AxeShopCatalog.CapacityUpgrades = {
	{ Capacity = 15, Price = 250 },
	{ Capacity = 20, Price = 1000 },
	{ Capacity = 30, Price = 4000 },
	{ Capacity = 40, Price = 15000 },
}

-- StatsAggregator currently contributes a base Attack of 5, so fixed axe records
-- store only the additional amount needed to reach the displayed Power.
AxeShopCatalog.BaseAttack = 5

return AxeShopCatalog
