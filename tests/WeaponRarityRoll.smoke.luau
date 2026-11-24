-- Phase 1C: server-side natural rarity RNG and persistent weapon smoke test.
-- Run in Studio Play's SERVER Command Bar with the current Rojo sources synced.
-- Synthetic weapons only: no player resources, logs or live saves are changed.
local RarityRoll = require(game.ServerScriptService.WeaponRarityRoll)
local Progression = require(game.ServerScriptService.WeaponProgressionRules)
local ItemDataBase = require(game.ServerStorage.Items.ItemDataBase)
local Dispatcher = require(game.ServerScriptService.WeaponEffects.Dispatcher)

local function check(label, condition)
	assert(condition, label .. " failed")
end

local total = RarityRoll.TOTAL_WEIGHT
local running = 0
local ordered = {}
for _, rarity in ipairs(Progression.RARITY_ORDER) do
	local weight = RarityRoll.WEIGHTS[rarity]
	check(rarity .. " has nonzero odds", type(weight) == "number" and weight >= 1)
	running += weight
	table.insert(ordered, { Rarity = rarity, Upper = running })
end
check("integer rarity distribution sums exactly to one million",
	total == 1000000 and running == total)
check("Secret cannot be naturally forged", RarityRoll.WEIGHTS.Secret == nil)
check("Ultra has a tiny but nonzero basic-forge chance",
	RarityRoll.WEIGHTS.Ultra > 0 and RarityRoll.WEIGHTS.Ultra < total / 100)

local function fixedRoll(draw)
	local rng = { Calls = 0 }
	function rng:NextInteger(first, last)
		self.Calls += 1
		check("NextInteger must draw exactly in the configured integer domain",
			first == 1 and last == total)
		return draw
	end
	return rng
end

local previous = RarityRoll.WeightsForLevel(1)
for level = 2, 20 do
	local weights = RarityRoll.WeightsForLevel(level)
	local sum = 0
	for _, rarity in ipairs(Progression.RARITY_ORDER) do
		sum += weights[rarity]
		check("rarity weight remains positive", weights[rarity] > 0)
		if rarity ~= "Common" then check("higher forge improves rarity odds", weights[rarity] > previous[rarity]) end
	end
	check("higher forge weights sum to total", sum == total)
	check("higher forge roll uses current level", RarityRoll.Roll(fixedRoll(weights.Common+1), level) == "Rare")
	previous = weights
end

local lower = 1
for _, entry in ipairs(ordered) do
	local a, b = fixedRoll(lower), fixedRoll(entry.Upper)
	check(entry.Rarity .. " first roll boundary", RarityRoll.Roll(a) == entry.Rarity)
	check(entry.Rarity .. " last roll boundary", RarityRoll.Roll(b) == entry.Rarity)
	check(entry.Rarity .. " uses exactly one independent draw",
		a.Calls == 1 and b.Calls == 1)
	lower = entry.Upper + 1
end
check("all tiers partition entire domain", lower == total + 1)
for _, invalid in ipairs({ 0, -1, total + 1, 1.5, math.huge }) do
	check("invalid RNG roll rejects safely", RarityRoll.Roll(fixedRoll(invalid)) == nil)
end
check("NaN RNG roll rejects safely", RarityRoll.Roll(fixedRoll(0 / 0)) == nil)
check("broken RNG rejects safely", RarityRoll.Roll({}) == nil)

-- Rarity is not tied to log count, species, material quality, head tier
-- or weapon class: the roller accepts no such parameters.
local unchangedMaterials = { { SourceUID = "log-a", SpeciesId = "Oak" } }
local unchangedEffects = { { Id = "Cleave", Trigger = "OnHit",
	Source = "WeaponClass", Params = { Radius = 10, DamageFraction = 0.4 } } }
local rareWeapon = {
	ItemID = 105, UID = "synthetic-rare",
	Stats = { Attack = 100 }, Substat = {},
	Rarity = RarityRoll.Roll(fixedRoll(780001)),
	WeaponData = {
		ExperimentalClass = "Battlehammer",
		WeaponKind = "Battlehammer",
		AxeTier = 1, CraftedPower = 105,
		Effects = unchangedEffects, Materials = unchangedMaterials,
	},
}
check("Rare can be forged at the earliest tier", rareWeapon.Rarity == "Rare")
check("new Rare weapon normalizes to Level 1 with no stored XP",
	Progression.NormalizeWeaponItem(rareWeapon)
		and rareWeapon.WeaponData.Progression.Level == 1
		and rareWeapon.WeaponData.Progression.XP == 0)
check("rarity does not change forged class, base attack, materials or effects",
	rareWeapon.WeaponData.ExperimentalClass == "Battlehammer"
		and rareWeapon.Stats.Attack == 100
		and rareWeapon.WeaponData.Materials == unchangedMaterials
		and rareWeapon.WeaponData.Effects == unchangedEffects)
local parsed = ItemDataBase.ParseItem(rareWeapon)
check("ItemDataBase carries natural rarity into equipped runtime",
	parsed.ItemRarity == "Rare" and parsed.WeaponData.Progression.Level == 1)
check("existing class Cleave remains a class effect",
	#Dispatcher.List(parsed.WeaponData) == 1
		and Dispatcher.List(parsed.WeaponData)[1].Source == "WeaponClass")
check("rarity does not grant free mutation abilities",
	parsed.WeaponData.Abilities == nil and parsed.WeaponData.MutationAbilities == nil)
check("higher rarity has derived bonus without changing forged attack",
	Progression.DerivedAttackBonus(parsed, 5) > 0
		and parsed.ItemStats.Attack == 100)

local ultraWeapon = {
	ItemID = 102, UID = "synthetic-ultra",
	Stats = { Attack = 25 }, Substat = {},
	Rarity = RarityRoll.Roll(fixedRoll(total)), WeaponData = { Materials = {} },
}
check("ordinary-source Ultra naturally possible", ultraWeapon.Rarity == "Ultra")
Progression.NormalizeWeaponItem(ultraWeapon)
check("Ultra gains rarity level cap but no free abilities",
	Progression.GetLevelCap(ultraWeapon.Rarity) > Progression.GetLevelCap("Legendary")
		and ultraWeapon.WeaponData.Progression.Level == 1
		and ultraWeapon.WeaponData.Effects == nil)

-- Statistical sanity check with deterministic seed; intentionally wide
-- tolerances so this test cannot flake on normal random variance.
local samples = 50000
local counts = {}
local rng = Random.new(1507)
for _ = 1, samples do
	local rarity = RarityRoll.Roll(rng)
	check("native Roblox RNG always produces configured rarity", Progression.IsRarity(rarity))
	counts[rarity] = (counts[rarity] or 0) + 1
end
local tolerances = {
	Common = 0.015,
	Rare = 0.012,
	Epic = 0.005,
	Legendary = 0.002,
	Ultra = 0.001,
}
for _, rarity in ipairs(Progression.RARITY_ORDER) do
	local expected = RarityRoll.WEIGHTS[rarity] / total
	local observed = (counts[rarity] or 0) / samples
	check(rarity .. " seeded frequency near configured odds",
		math.abs(observed - expected) <= tolerances[rarity])
end

print("WeaponRarityRoll: boundaries, real RNG distribution, persistence, and class/effects independence passed")
return true
