-- Permanent Grove infrastructure; numbers are provisional economy knobs.
local Rules = {}
Rules.LEVELS = {
	[1] = { Capacity = 3, MaxMutations = 1, UpgradeCoins = 0 },
	[2] = { Capacity = 4, MaxMutations = 1, UpgradeCoins = 500 },
	[3] = { Capacity = 5, MaxMutations = 2, UpgradeCoins = 2500 },
	[4] = { Capacity = 6, MaxMutations = 2, UpgradeCoins = 10000 },
	[5] = { Capacity = 8, MaxMutations = 3, UpgradeCoins = 40000 },
	[6] = { Capacity = 10, MaxMutations = 4, UpgradeCoins = 120000 },
}
function Rules.NormalizeLevel(level)
	return if type(level) == "number" and level == level and Rules.LEVELS[level] then level else 1
end
function Rules.Current(level)
	return Rules.LEVELS[Rules.NormalizeLevel(level)]
end
function Rules.Next(level)
	local target = Rules.NormalizeLevel(level) + 1
	local entry = Rules.LEVELS[target]
	if not entry then return nil end
	return {
		ToLevel = target, Capacity = entry.Capacity,
		MaxMutations = entry.MaxMutations, CoinCost = entry.UpgradeCoins,
	}
end
return Rules
