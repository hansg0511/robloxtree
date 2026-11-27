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
check("mixed effective strength is mean of per-log products",
	near(mixed.AverageEffectiveWoodStrength, (10 * 0.2 + 16 * 0.8) / 2))
check("quantity bonus increases ceiling, not material quality",
	near(mixed.QuantityQualityMultiplier, 1.01) and near(mixed.ForgedQuality, 0.505))
check("quantity scales only effective wood, no random damage",
	near(mixed.Ranges.Axe.Damage.Min, (25 + 7.4 * 1.01) * Rules.CLASS_PROFILES.Axe.Damage)
	and mixed.Ranges.Axe.Damage.Min == mixed.Ranges.Axe.Damage.Max)
check("speed follows forged quality deterministically",
	near(mixed.Ranges.Axe.AttacksPerSecond.Min, 1.2 + 0.6 * 0.505)
	and mixed.Ranges.Axe.AttacksPerSecond.Min == mixed.Ranges.Axe.AttacksPerSecond.Max)
local perfect = {}
for i = 1, 96 do perfect[i] = { SpeciesId = "Oak", SizeScale = 5 } end
local capped = Rules.Preview(25, perfect)
check("perfect 96-log submission has 195% forged quality",
	near(capped.MaterialQuality, 1) and near(capped.ForgedQuality, 1.95))
check("damage bonus remains uncapped within offered log bound",
	near(capped.Ranges.Battlehammer.Damage.Min, (25 + 10 * 1.95) * Rules.CLASS_PROFILES.Battlehammer.Damage))
check("speed and cleave respect configured ceilings",
	near(capped.Ranges.Dagger.AttacksPerSecond.Max, 3.2)
	and near(capped.Ranges.Battlehammer.CleaveDamageFraction.Max, 0.75)
	and near(capped.Ranges.Battlehammer.CleaveRadius.Max, 24))
local dagger = capped.Ranges.Dagger
local axe = capped.Ranges.Axe
local hammer = capped.Ranges.Battlehammer
check("comparable single-target DPS class order",
	near(dagger.Damage.Min * dagger.AttacksPerSecond.Min /
		(hammer.Damage.Min * hammer.AttacksPerSecond.Min), 1.1)
	and axe.Damage.Min * axe.AttacksPerSecond.Min > hammer.Damage.Min * hammer.AttacksPerSecond.Min
	and axe.Damage.Min * axe.AttacksPerSecond.Min < dagger.Damage.Min * dagger.AttacksPerSecond.Min)
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
}, fixedRng({ 0.2, 0.5, 0.5 }))
check("class is deterministic at one log", result.Class == "Dagger")
check("one perfect log has no quantity bonus", near(result.ForgedQuality, 1))
check("damage is deterministic", near(result.Damage, (25 + 10) * Rules.CLASS_PROFILES.Dagger.Damage))
check("100% normal quality attack speed", near(result.AttacksPerSecond, 3))
check("legacy reach still has its own roll", near(result.Reach, 0.75))
check("legacy Golden metadata gets its own roll", near(result.GoldenBonus, 0.30))

local noMutation = Rules.Roll(25,
	{ { SpeciesId = "Bamboo", SizeScale = 1 } },
	fixedRng({ 0, 0.5, 0.5, 0.5 }))
check("ordinary logs cannot gain Golden by chance", noMutation.GoldenBonus == 0)

print("Experimental forge preview, odds, quantity bonus and deterministic stats passed")
return true
