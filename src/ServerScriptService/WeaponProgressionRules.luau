-- Pure, server-authoritative weapon progression rules.
-- Phase 1B: schema, validation, level caps, XP progression and derived stats.
-- Natural rarity RNG, ascension and mutation ability rolls are future phases.
local Rules = {}

Rules.SCHEMA_VERSION = 1
Rules.MAX_SAVED_XP = 1e12
Rules.MAX_ASCENSION_FAILURES = 1000000
-- Provisional active-chopping XP tune values; adjust via playtesting.
local Config = require(game.ReplicatedStorage.Shared.ProgressionConfig)
Rules.XP_PER_DAMAGE = Config.XP.PerDamage
Rules.KILL_XP_PER_MAX_HP = Config.XP.KillPerMaxHP
Rules.MAX_TREE_HP_FOR_XP = 10000000
Rules.RARITY_ORDER = Config.Order
Rules.RARITIES = {}
for _,row in ipairs(Config.RARITIES) do
	Rules.RARITIES[row.Id]={LevelCap=row.LevelCap,PowerMultiplier=row.Power,BasePowerBonus=row.Power-1,GrowthPerLevel=Config.LEVEL_POWER_GROWTH}
end

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

-- XP represents progress within the current level, not lifetime total.
-- XP at cap is always zero. No AFK or per-hit XP sources are involved.
function Rules.XPToNextLevel(rarity, level)
	local cap = Rules.GetLevelCap(rarity)
	if not cap or type(level) ~= "number" or level % 1 ~= 0
		or level < 1 or level >= cap then return nil end
	-- Placeholder curve; cap-safe integer. Higher rarity has more levels.
	return math.max(1, math.floor(Config.XP.Base + Config.XP.PerLevel * level + 0.5))
end

function Rules.XPForAppliedHit(appliedDamage, maxHP, killed)
	if not finite(appliedDamage) or appliedDamage <= 0
		or not finite(maxHP) or maxHP <= 0 or maxHP > Rules.MAX_TREE_HP_FOR_XP
		or appliedDamage > maxHP then return 0 end
	-- The caller supplies HP-clamped applied damage from the trusted server
	-- tree object, NEVER calculated hit damage or a client claim.
	local damageXP = math.floor(appliedDamage * Rules.XP_PER_DAMAGE)
	local killBonus = if killed == true
		then math.floor(maxHP * Rules.KILL_XP_PER_MAX_HP) else 0
	return math.max(0, damageXP + killBonus)
end

-- Pure, non-mutating advancement. One large hit can pass multiple level
-- boundaries, and XP at the cap is discarded (no hidden pre-ascension bank).
function Rules.ApplyXP(progression, rarity, xpGain)
	local current = Rules.NormalizeProgression(progression, rarity)
	local cap = Rules.GetLevelCap(rarity)
	if not cap or not finite(xpGain) or xpGain <= 0
		or xpGain % 1 ~= 0 then return current, 0 end
	if current.Level >= cap then
		current.XP = 0
		return current, 0
	end
	local xp = math.min(Rules.MAX_SAVED_XP, current.XP + xpGain)
	local level = current.Level
	local startingLevel = level
	while level < cap do
		local required = Rules.XPToNextLevel(rarity, level)
		if not required or xp < required then break end
		xp -= required
		level += 1
	end
	current.Level = level
	current.XP = if level >= cap then 0 else xp
	return current, level - startingLevel
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
	local level = boundedInteger(source.Level, 1, cap, 1)
	local xp = boundedInteger(source.XP, 0, Rules.MAX_SAVED_XP, 0)
	return {
		SchemaVersion = Rules.SCHEMA_VERSION,
		Level = level,
		XP = if level >= cap then 0 else xp,
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
	local bonusFactor = config.PowerMultiplier * (1 + (level - 1) * config.GrowthPerLevel) - 1
	local bonus = forgedPower * bonusFactor
	-- Guard malformed/extreme saved numbers rather than feeding Inf or unsafe
	-- integers into StatsAggregator. This is a safety limit, not economy tuning.
	if not finite(bonus) or bonus < 0 or bonus > 1e12 then return 0 end
	-- The original forged ItemStats are NEVER modified by this function.
	return math.floor(bonus * 1000 + 0.5) / 1000
end

return Rules
