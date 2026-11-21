-- Pure, server-authoritative weapon progression rules.
-- Phase 1A only: schema, validation, level caps and derived combat stats.
-- NO XP granting, rarity RNG, ascension or mutation ability rolls here.
local Rules = {}

Rules.SCHEMA_VERSION = 1
Rules.MAX_SAVED_XP = 1e12
Rules.MAX_ASCENSION_FAILURES = 1000000
Rules.RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Ultra" }

-- PROTOTYPE TUNING VALUES, not finalized economy design. All rarities may be
-- forged directly in future, and ascension will later reset Level to 1.
-- Growth applies to the forged weapon's base contribution, not to pet buffs.
Rules.RARITIES = {
	Common = { LevelCap = 10, BasePowerBonus = 0, GrowthPerLevel = 0.010 },
	Rare = { LevelCap = 20, BasePowerBonus = 0.03, GrowthPerLevel = 0.013 },
	Epic = { LevelCap = 30, BasePowerBonus = 0.06, GrowthPerLevel = 0.016 },
	Legendary = { LevelCap = 45, BasePowerBonus = 0.09, GrowthPerLevel = 0.019 },
	Ultra = { LevelCap = 65, BasePowerBonus = 0.12, GrowthPerLevel = 0.022 },
}

local function finite(value)
	return type(value) == "number" and value == value
		and value > -math.huge and value < math.huge
end

local function boundedInteger(value, minValue, maxValue, default)
	if not finite(value) or value % 1 ~= 0 then return default end
	-- A balance patch can lower a level cap. Clamp valid saved progress
	-- instead of silently resetting a previously valid weapon to Level 1.
	return math.clamp(value, minValue, maxValue)
end

function Rules.IsRarity(value)
	return type(value) == "string" and Rules.RARITIES[value] ~= nil
end

function Rules.GetLevelCap(rarity)
	local config = Rules.RARITIES[rarity]
	return config and config.LevelCap or nil
end

function Rules.NewProgression()
	return {
		SchemaVersion = Rules.SCHEMA_VERSION,
		Level = 1,
		XP = 0,
		AscensionFailures = 0,
	}
end

-- This function does not mutate the caller's data. Unknown future/legacy
-- progression payloads fail safe to currently recognized primitive fields.
function Rules.NormalizeProgression(value, rarity)
	local source = if type(value) == "table" then value else {}
	local cap = Rules.GetLevelCap(rarity) or Rules.RARITIES.Common.LevelCap
	return {
		SchemaVersion = Rules.SCHEMA_VERSION,
		Level = boundedInteger(source.Level, 1, cap, 1),
		XP = boundedInteger(source.XP, 0, Rules.MAX_SAVED_XP, 0),
		AscensionFailures = boundedInteger(
			source.AscensionFailures, 0, Rules.MAX_ASCENSION_FAILURES, 0
		),
	}
end

-- Operates only on a caller-verified, persisted weapon item. Keep Item.Rarity
-- as the sole rarity source; preserve all unrelated crafted and effect fields.
-- The caller MUST filter non-weapons and session-only debug weapons.
function Rules.NormalizeWeaponItem(item)
	if type(item) ~= "table" then return false end
	if not Rules.IsRarity(item.Rarity) then item.Rarity = "Common" end
	if type(item.WeaponData) ~= "table" then item.WeaponData = {} end
	item.WeaponData.Progression = Rules.NormalizeProgression(
		item.WeaponData.Progression, item.Rarity
	)
	return true
end

-- Runtime ItemDataBase records expose ItemRarity/ItemStats, while persisted
-- items use Rarity/Stats. This pure reader supports both, without migrations
-- or requiring any Roblox Instances.
function Rules.DerivedAttackBonus(weapon, playerBaseAttack)
	if type(weapon) ~= "table" then return 0 end
	local rarity = weapon.ItemRarity or weapon.Rarity
	local config = Rules.RARITIES[rarity]
	if not config then return 0 end -- e.g. session-only Debug weapon
	local data = weapon.WeaponData
	local progress = type(data) == "table" and data.Progression or nil
	local level = boundedInteger(
		type(progress) == "table" and progress.Level or nil,
		1, config.LevelCap, 1
	)
	local stats = weapon.ItemStats or weapon.Stats
	local baseStat = type(stats) == "table" and stats.Attack or nil
	if not finite(baseStat) or baseStat < 0 then return 0 end
	if not finite(playerBaseAttack) or playerBaseAttack < 0 then return 0 end
	local forgedPower = playerBaseAttack + baseStat
	local bonusFactor = config.BasePowerBonus + (level - 1) * config.GrowthPerLevel
	local bonus = forgedPower * bonusFactor
	-- Guard malformed/extreme saved numbers rather than feeding Inf or unsafe
	-- integers into StatsAggregator. This is a safety limit, not economy tuning.
	if not finite(bonus) or bonus < 0 or bonus > 1e12 then return 0 end
	-- The original forged ItemStats are NEVER modified by this function.
	return math.floor(bonus * 1000 + 0.5) / 1000
end

return Rules
