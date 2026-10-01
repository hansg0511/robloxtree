local ItemsFolder = script.Parent
local RNG = require(ItemsFolder.RNGModule)
local ItemDatabase = require(ItemsFolder.ItemDataBase)
local StatDatabase = require(ItemsFolder.StatsDatabase)
local StatPools = ItemDatabase.StatPools
local RarityRules = require(ItemsFolder.RarityRules)

local ItemGenerator = {}

local HttpService = game:GetService("HttpService")

local function GenerateUID(itemID)
	return itemID .. "_" .. HttpService:GenerateGUID(false)
end

function ItemGenerator.GenerateItem(itemID)
	local itemDef = ItemDatabase.Info[itemID]
	if not itemDef then
		error("Invalid ItemID: " .. tostring(itemID))
	end

	-- 1️⃣ Roll rarity
	local rarity = RNG.RollRarity(RarityRules)

	-- 2️⃣ Roll stat count
	local statCount = RarityRules[rarity].StatCount

	-- 3️⃣ Get stat pool
	local pool = table.clone(StatPools[itemDef.Type])

	-- 4️⃣ Apply item-specific exclusions
	--if itemDef.StatOverrides and itemDef.StatOverrides.Exclude then
	--	for _, excluded in ipairs(itemDef.StatOverrides.Exclude) do
	--		table.remove(pool, table.find(pool, excluded))
	--	end
	--end

	-- 5️⃣ Pick stats
	local chosenStats = RNG.PickN(pool, statCount)

	-- 6️⃣ Roll stat values
	local rolledStats = {}

	for _, statName in ipairs(chosenStats) do
		local statDef = StatDatabase[statName]
		local base = RNG.RollRange(statDef.BaseRange.min, statDef.BaseRange.max)
		local scaled = base * statDef.Scaling[rarity]

		rolledStats[statName] = math.round(scaled * 10) / 10
	end

	-- 7️⃣ Apply base stats (always present)
	if itemDef.BaseStats then
		for stat, value in pairs(itemDef.BaseStats) do
			rolledStats[stat] = (rolledStats[stat] or 0) + value
		end
	end

	-- 8️⃣ Construct item instance
	return {
		UID = GenerateUID(itemID),
		ItemID = itemID,
		Rarity = rarity,
		Stats = rolledStats
	}
end

return ItemGenerator