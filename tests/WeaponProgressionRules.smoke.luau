-- Phase 1A synthetic smoke test. Run in Roblox Studio SERVER Command Bar
-- during Play, with Rojo sources synced; no player profile is modified.
local Rules = require(game.ServerScriptService.WeaponProgressionRules)

local function near(a, b)
	return math.abs(a - b) < 0.00001
end

assert(Rules.SCHEMA_VERSION == 1)
assert(#Rules.RARITY_ORDER == 5)
assert(not Rules.IsRarity("Debug") and not Rules.IsRarity("Secret"),
	"Secret is not a normal ascendable rarity")
for index, rarity in ipairs(Rules.RARITY_ORDER) do
	assert(Rules.IsRarity(rarity))
	local cap = Rules.GetLevelCap(rarity)
	assert(type(cap) == "number" and cap >= 1)
	if index > 1 then
		assert(cap > Rules.GetLevelCap(Rules.RARITY_ORDER[index - 1]),
			"Higher rarity should have a higher level cap")
	end
end

-- Existing weapons have no progression payload; migration preserves all
-- forged stats, effects, provenance and rarity.
local effects = { { Id = "Cleave", Trigger = "OnHit",
	Source = "WeaponClass", Params = { Radius = 12, DamageFraction = 0.4 } } }
local materials = { { SourceUID = "first-log", Mutations = { Golden = true } } }
local saved = {
	ItemID = 105, UID = "persisted-hammer",
	Stats = { Attack = 42 }, Substat = {}, Rarity = "Rare",
	WeaponData = { AxeTier = 2, CraftedPower = 47,
		ExperimentalClass = "Battlehammer", Materials = materials, Effects = effects },
}
assert(Rules.NormalizeWeaponItem(saved))
local progressed = saved.WeaponData.Progression
assert(progressed.SchemaVersion == 1 and progressed.Level == 1
	and progressed.XP == 0 and progressed.AscensionFailures == 0,
	"Legacy weapon starts at Level 1, XP 0 and no pity progress")
assert(saved.Rarity == "Rare" and saved.Stats.Attack == 42
	and saved.WeaponData.Materials == materials
	and saved.WeaponData.Effects == effects
	and saved.WeaponData.AxeTier == 2,
	"Migration must not reroll or destroy original weapon data")
local first = Rules.NormalizeProgression(saved.WeaponData.Progression, saved.Rarity)
assert(Rules.NormalizeWeaponItem(saved))
assert(saved.WeaponData.Progression.Level == first.Level
	and saved.WeaponData.Progression.XP == first.XP
	and saved.WeaponData.Progression.AscensionFailures == first.AscensionFailures,
	"Normalization should be idempotent")

local legacyStarter = { ItemID = 101, UID = "starter", Rarity = "Common",
	Stats = { Attack = 5 }, Substat = {} }
assert(Rules.NormalizeWeaponItem(legacyStarter))
assert(legacyStarter.WeaponData.Progression.Level == 1)
assert(near(Rules.DerivedAttackBonus(legacyStarter, 5), 0),
	"Common Level 1 must have zero level-derived bonus")

local malformed = {
	Rarity = "NotARealRarity", Stats = { Attack = 5 },
	WeaponData = { Effects = effects, Progression = {
		Level = 999999, XP = 8.5, AscensionFailures = -1, SchemaVersion = 999,
	} },
}
assert(Rules.NormalizeWeaponItem(malformed))
assert(malformed.Rarity == "Common" and malformed.WeaponData.Effects == effects)
assert(malformed.WeaponData.Progression.Level == 1
	and malformed.WeaponData.Progression.XP == 0
	and malformed.WeaponData.Progression.AscensionFailures == 0
	and malformed.WeaponData.Progression.SchemaVersion == Rules.SCHEMA_VERSION,
	"Invalid stored values should be replaced safely")

-- Progression is computed without modifying the original forged stats.
local runtime = {
	ItemType = "Weapon", ItemRarity = "Rare",
	ItemStats = { Attack = 95 },
	WeaponData = { Progression = { Level = 1, XP = 0 } },
}
local rareStart = Rules.DerivedAttackBonus(runtime, 5)
runtime.WeaponData.Progression.Level = Rules.GetLevelCap("Rare")
local rareMax = Rules.DerivedAttackBonus(runtime, 5)
assert(rareMax > rareStart and runtime.ItemStats.Attack == 95,
	"Level growth should increase derived power without mutating forged attack")

runtime.ItemRarity = "Epic"
runtime.WeaponData.Progression.Level = 1
local epicStart = Rules.DerivedAttackBonus(runtime, 5)
assert(epicStart < rareMax,
	"After ascension Epic Lv1 can be weaker than max-level Rare")
runtime.WeaponData.Progression.Level = Rules.GetLevelCap("Epic")
assert(Rules.DerivedAttackBonus(runtime, 5) > rareMax,
	"An Epic at its cap should surpass the same base weapon at Rare cap")

local debug = { ItemType = "Weapon", ItemRarity = "Debug",
	ItemStats = { Attack = 9995 }, WeaponData = { Progression = { Level = 65 } } }
assert(Rules.DerivedAttackBonus(debug, 5) == 0,
	"Session-only debug weapon cannot receive ordinary rarity growth")
assert(Rules.DerivedAttackBonus({ ItemRarity = "Ultra",
	ItemStats = { Attack = 1/0 } }, 5) == 0,
	"Malformed forged attack cannot produce infinite bonus")
assert(Rules.DerivedAttackBonus(nil, 5) == 0)
assert(Rules.NormalizeWeaponItem(nil) == false)

-- Exercise the real profile-load filtering and runtime adapter paths.
local ProfileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local ItemDataBase = require(game.ServerStorage.Items.ItemDataBase)
local unnormalizedWeapon = { ItemID = 102, UID = "saved-copper", Rarity = "Common",
	Stats = { Attack = 25 }, Substat = {}, WeaponData = { Effects = effects } }
local savedSeed = { ItemID = 201, UID = "saved-seed", Rarity = "Rare" }
local oldDebug = { ItemID = 9001, UID = "old-debug", Rarity = "Debug",
	Stats = { Attack = 9995 } }
local simulatedProfile = { Inventory = { unnormalizedWeapon, savedSeed, oldDebug } }
assert(ProfileCache.NormalizeWeaponData(simulatedProfile))
assert(unnormalizedWeapon.WeaponData.Progression.Level == 1
	and unnormalizedWeapon.WeaponData.Effects == effects)
assert(savedSeed.WeaponData == nil and oldDebug.WeaponData == nil
	and oldDebug.Rarity == "Debug",
	"Profile migration must exclude seeds and session-only debug weapons")
local parsed = ItemDataBase.ParseItem(unnormalizedWeapon)
assert(parsed.ItemRarity == "Common"
	and parsed.WeaponData.Progression.Level == 1
	and parsed.ItemStats.Attack == 25,
	"Real item parser must carry persisted progression into runtime data")
assert(parsed.WeaponData.Effects ~= effects and parsed.WeaponData.Effects[1].Id == "Cleave",
	"Runtime adapter must preserve copied effects without sharing original tables")

print("WeaponProgressionRules: migration, caps, rarity, growth, reset and safety passed")
return true
