local RNG = {}

function RNG.WeightedRoll(weightTable)
	local totalWeight = 0

	for _, weight in pairs(weightTable) do
		totalWeight += weight
	end

	local roll = math.random() * totalWeight
	local cumulative = 0

	for key, weight in pairs(weightTable) do
		cumulative += weight
		if roll <= cumulative then
			return key
		end
	end
end

function RNG.RollRange(min, max)
	return min + math.random() * (max - min)
end

function RNG.PickN(pool, count)
	local copy = table.clone(pool)
	local result = {}

	for i = 1, math.min(count, #copy) do
		local index = math.random(1, #copy)
		table.insert(result, copy[index])
		table.remove(copy, index)
	end

	return result
end

function RNG.RollRarity(rarityRules)
	local weights = {}

	for rarity, data in pairs(rarityRules) do
		weights[rarity] = data.Weight
	end

	return RNG.WeightedRoll(weights)
end

return RNG
