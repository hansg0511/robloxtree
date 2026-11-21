-- Studio SERVER Command Bar. Pure forge math, no player profiles touched.
local Rules = require(game.ReplicatedStorage.Shared.ExperimentalForgeRules)
local function check(name, condition)
	assert(condition, name .. " failed")
end
local function near(a, b)
	return math.abs(a - b) < 0.00001
end

check("global maximum reference size", Rules.MAX_LOG_SIZE == 5)
check("1x log is 20% absolute quality", near(Rules.LogQuality(1), 0.2))
check("5x is 100% quality", near(Rules.LogQuality(5), 1))
check("6x cannot exceed 100%", near(Rules.LogQuality(6), 1))
check("invalid size rejected", Rules.LogQuality(-1) == nil)
check("reasonable upper transaction bound", Rules.ValidateCount(96)
	and not Rules.ValidateCount(97) and not Rules.ValidateCount(0))
for n = 1, Rules.MAX_OFFERED_LOGS do
	local odds = Rules.Odds(n)
	check("odds exist at count " .. n, odds ~= nil)
	check("probabilities sum to 1 at count " .. n,
		near(odds.Dagger + odds.Axe + odds.Battlehammer, 1))
end
check("one log guarantees Dagger", near(Rules.Odds(1).Dagger, 1))
check("five logs mostly Axe", near(Rules.Odds(5).Axe, 0.65))
check("ten logs mostly Battlehammer", near(Rules.Odds(10).Battlehammer, 0.6))
check("twenty logs guarantee Battlehammer", near(Rules.Odds(20).Battlehammer, 1))

local mixed = Rules.Preview(25, {
	{ SpeciesId = "Oak", SizeScale = 1 },
	{ SpeciesId = "Ironwood", SizeScale = 4, Mutations = { Golden = true } },
})
check("mix accepted", mixed ~= nil)
check("absolute material quality averages to 50%", near(mixed.MaterialQuality, 0.5))
check("wood strength averages", near(mixed.AverageWoodStrength, 13))
check("mutation quality is diluted by ordinary wood",
	near(mixed.GoldenQuality, 0.4))
check("quality floor increases effective stats",
	near(mixed.Ranges.Axe.Damage.Min, 38 * 1.25 * 0.75 * 0.9))
check("mutation has independent quality-weighted range",
	near(mixed.GoldenBonusRange.Max, 0.30 * 0.4 * 1.1))
check("unknown species rejected",
	Rules.Preview(25, { { SpeciesId = "Unknown", SizeScale = 1 } }) == nil)

local function fixedRng(values)
	local nextIndex = 0
	return {
		NextNumber = function(self)
			nextIndex += 1
			return values[nextIndex]
		end,
	}
end
local result = Rules.Roll(25, {
	{ SpeciesId = "Oak", SizeScale = 5, Mutations = { Golden = true } },
}, fixedRng({ 0.2, 0, 1, 0.5, 0.5 }))
check("class is deterministic at one log", result.Class == "Dagger")
check("100% quality still rolls damage 90%-110% range",
	near(result.Damage, (25 + 10) * 0.55 * 0.9))
check("attack speed independent from damage roll",
	near(result.AttacksPerSecond, 2.2 * 1.1))
check("reach has its own roll", near(result.Reach, 0.75))
check("Golden mutation gets its own roll", near(result.GoldenBonus, 0.30))

local noMutation = Rules.Roll(25,
	{ { SpeciesId = "Bamboo", SizeScale = 1 } },
	fixedRng({ 0, 0.5, 0.5, 0.5 }))
check("ordinary logs cannot gain Golden by chance", noMutation.GoldenBonus == 0)

print("Experimental forge preview, odds, independent stat rolls passed")
return true
