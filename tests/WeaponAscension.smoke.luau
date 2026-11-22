-- Phase 1D: deterministic ascension + hard pity smoke tests.
-- Paste in Roblox Studio SERVER Command Bar during Play (Rojo synced).
-- This uses pure rules and synthetic weapons; spends no real coins/logs.
local Progression = require(game.ServerScriptService.WeaponProgressionRules)
local Ascension = require(game.ServerScriptService.WeaponAscensionRules)
local AscensionService = require(game.ServerScriptService.WeaponAscensionService)

local function test(description, condition)
	assert(condition, "[Ascension] " .. description)
end

-- Ascension cannot silently consume mutated logs or protected storage.
local eligible = AscensionService.SelectOrdinaryBagLogs({
	{ UID = "stored", Source = "Storage", CraftPowerBonus = 1, Mutations = {} },
	{ UID = "mutated", Source = "Bag", CraftPowerBonus = 1, Mutations = { Golden = true } },
	{ UID = "bigger", Source = "Bag", CraftPowerBonus = 2, SizeScale = 4, Mutations = {} },
	{ UID = "smaller", Source = "Bag", CraftPowerBonus = 2, SizeScale = 0.5, Mutations = {} },
	{ UID = "cheapest", Source = "Bag", CraftPowerBonus = 1, SizeScale = 1, Mutations = {} },
})
test("only normal carry-bag logs eligible and cheapest used first",
	#eligible == 3 and eligible[1].UID == "cheapest"
		and eligible[2].UID == "smaller" and eligible[3].UID == "bigger")

local ladder = Progression.RARITY_ORDER
test("five normal rarities", #ladder == 5 and ladder[5] == "Ultra")
test("Ultra is terminal", Ascension.Preview("Ultra", Progression.NewProgression()) == nil)
test("Secret is not normal ascension", Ascension.Preview("Secret", {}) == nil)

for index = 1, #ladder - 1 do
	local rarity, nextRarity = ladder[index], ladder[index + 1]
	local cap = Progression.GetLevelCap(rarity)
	local step = Ascension.STEPS[rarity]
	local pity = Ascension.PityLimit(rarity)
	local maxed = { SchemaVersion = 1, Level = cap, XP = 0, AscensionFailures = 0 }

	test(rarity .. " has positive costs and roll chance",
		step.To == nextRarity and step.Coins > 0 and step.Logs > 0
			and step.Chance > 0 and step.Chance <= 1)
	test(rarity .. " pity uses ceil(1.5/p)",
		pity == math.ceil(1.5 / step.Chance))
	test(rarity .. " cannot ascend early",
		Ascension.Resolve(rarity, { Level = cap - 1 }, 0) == nil)
	local p = Ascension.Preview(rarity, maxed)
	test(rarity .. " available at level cap and shows cost/pity",
		p.Ready and p.To == nextRarity and p.PityLimit == pity
			and p.Coins == step.Coins and p.Logs == step.Logs)

	-- At level cap: fails cost one attempt, never damage the weapon,
	-- and independently advance this weapon's per-step counter.
	local current = maxed
	for failureCount = 1, pity - 1 do
		local outcome = Ascension.Resolve(rarity, current, 0.999999)
		test(rarity .. " failure is non-destructive",
			outcome and not outcome.Success and outcome.Rarity == rarity
				and outcome.Progression.Level == cap
				and outcome.Progression.XP == 0
				and outcome.Progression.AscensionFailures == failureCount)
		test(rarity .. " source counter not mutated",
			current.AscensionFailures == failureCount - 1)
		current = outcome.Progression
	end

	local guaranteed = Ascension.Preview(rarity, current)
	test(rarity .. " final attempt guaranteed",
		guaranteed.Guaranteed and guaranteed.AttemptNumber == pity
			and guaranteed.AttemptsUntilGuarantee == 1)
	local resolved = Ascension.Resolve(rarity, current, nil)
	test(rarity .. " final pity succeeds without RNG draw",
		resolved and resolved.Success and resolved.Rarity == nextRarity
			and resolved.Progression.Level == 1
			and resolved.Progression.XP == 0
			and resolved.Progression.AscensionFailures == 0)
	test(rarity .. " old weapon state preserved",
		current.Level == cap and current.AscensionFailures == pity - 1)

	-- Success before pity does not require prior ascension; resets all
	-- level-only stats and the failure counter.
	local forcedSuccess = Ascension.Resolve(rarity, {
		Level = cap, XP = 0, AscensionFailures = 1,
	}, 0)
	test(rarity .. " early success resets level and per-step pity",
		forcedSuccess.Success and forcedSuccess.Rarity == nextRarity
			and forcedSuccess.Progression.Level == 1
			and forcedSuccess.Progression.AscensionFailures == 0)
	local p2 = Ascension.Preview(nextRarity, forcedSuccess.Progression)
	if p2 then
		test(nextRarity .. " next step has fresh pity",
			p2.Failures == 0 and p2.AttemptNumber == 1 and not p2.Ready)
	end
end

local commonCap = Progression.GetLevelCap("Common")
local maxCommon = { Level = commonCap, XP = 0, AscensionFailures = 0 }
test("invalid RNG must fail closed",
	Ascension.Resolve("Common", maxCommon, -0.1) == nil
		and Ascension.Resolve("Common", maxCommon, 1) == nil
		and Ascension.Resolve("Common", maxCommon, 0/0) == nil)
test("below chance succeeds and above chance fails",
	Ascension.Resolve("Common", maxCommon, 0.499999).Success
		and not Ascension.Resolve("Common", maxCommon, 0.5).Success)
test("zero rarity upgrade on invalid data",
	Ascension.Preview("Debug", { Level = 999 }) == nil)

-- Normal armor/mutation/effect/provenance fields aren't part of the
-- ascension result: the service updates ONLY Rarity + Progression.
local effects = { { Id = "Cleave", Source = "WeaponClass",
	Trigger = "OnHit", Params = { DamageFraction = 0.4, Radius = 10 } } }
local materials = { { SourceUID = "oak-1", SpeciesId = "Oak",
	Mutations = { Golden = true }, SizeScale = 2.1 } }
local item = { ItemID = 105, UID = "battlehammer-1",
	Stats = { Attack = 91 }, Substat = {}, Rarity = "Common",
	WeaponData = {
		WeaponKind = "Battlehammer", ExperimentalClass = "Battlehammer",
		Materials = materials, Effects = effects, CraftedPower = 96,
		Progression = table.clone(maxCommon),
	},
}
local basePower = Progression.DerivedAttackBonus(item, 5)
local result = Ascension.Resolve(item.Rarity, item.WeaponData.Progression, 0)
item.Rarity = result.Rarity
item.WeaponData.Progression = result.Progression
local newPower = Progression.DerivedAttackBonus(item, 5)
test("success preserves forged stats, material metadata and Cleave",
	item.Stats.Attack == 91 and item.WeaponData.CraftedPower == 96
		and item.WeaponData.Materials == materials
		and item.WeaponData.Effects == effects)
test("new rarity Level 1 recalculates non-destructive power",
	newPower ~= basePower and item.WeaponData.Progression.Level == 1)
test("pity isolates separate weapons",
	Ascension.Preview("Common", maxCommon).Failures == 0)

print("WeaponAscension: rarity ladder, cost previews, non-destructive failure, exact hard pity, resets and preservation passed")
return true
