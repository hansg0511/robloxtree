-- Phase 1D: pure, configurable rarity ascension math and costs.
-- Does not touch inventories, remotes, RNG state or player data.
local Progression = require(game.ServerScriptService.WeaponProgressionRules)

local Rules = {}

-- Provisional balancing only: no player-facing cost or rate is finalized.
-- Ascension always advances exactly ONE step, never Secret.
local Config=require(game.ReplicatedStorage.Shared.ProgressionConfig)
local Economy=require(game.ReplicatedStorage.Shared.PremiumEconomyConfig)
Rules.STEPS={}
for i,row in ipairs(Config.RARITIES) do
	local nextRow=Config.RARITIES[i+1]
	if nextRow then
		Rules.STEPS[row.Id]={To=nextRow.Id,Chance=row.AscendChance,Coins=row.Coins,Logs=row.Logs,Crystals=Economy.ASCENSION_CRYSTALS[row.Id],Pity=row.Pity,RequiredForge=nextRow.Unlock}
	end
end

local function validInteger(n)
	return type(n) == "number" and n == n
		and n >= 0 and n < math.huge and n % 1 == 0
end

for i, rarity in ipairs(Progression.RARITY_ORDER) do
	local step = Rules.STEPS[rarity]
	if i < #Progression.RARITY_ORDER then
		assert(step and step.To == Progression.RARITY_ORDER[i + 1]
			and type(step.Chance) == "number" and step.Chance > 0 and step.Chance <= 1
			and validInteger(step.Coins) and step.Coins > 0
			and validInteger(step.Logs) and step.Logs > 0 and validInteger(step.Crystals) and step.Crystals>0, "Invalid ascension config " .. rarity)
	else
		assert(step == nil, "Highest rarity must have no normal ascension step")
	end
end

function Rules.PityLimit(rarity)
	local step = Rules.STEPS[rarity]
	if not step then return nil end
	return step.Pity or math.min(Config.PITY_MAX,math.ceil(Config.PITY_FACTOR / step.Chance))
end

-- All returned values are immutable by convention; do not mutate STEPS.
-- A capped weapon remains capped after failed attempts.
function Rules.Preview(rarity, progression, forgeLevel)
	local step = Rules.STEPS[rarity]
	if not step then return nil end
	local current = Progression.NormalizeProgression(progression, rarity)
	local limit = Rules.PityLimit(rarity)
	local attemptNumber = math.min(limit, current.AscensionFailures + 1)
	local guaranteed = attemptNumber >= limit
	return {
		From = rarity,
		To = step.To,
		RequiredForge = step.RequiredForge,
		ForgeUnlocked = Config.ValidForge(forgeLevel) and forgeLevel >= step.RequiredForge,
		Coins = step.Coins,
		Logs = step.Logs,
		Crystals=step.Crystals,
		Chance = step.Chance,
		PityLimit = limit,
		Failures = current.AscensionFailures,
		AttemptNumber = attemptNumber,
		AttemptsUntilGuarantee = math.max(0, limit - current.AscensionFailures),
		Guaranteed = guaranteed,
		MaxLevel = Progression.GetLevelCap(rarity),
		Ready = current.Level >= Progression.GetLevelCap(rarity),
	}
end

-- Deterministic pure evaluation; production passes server-owned Random.
-- Draw is never taken from the client. Under hard pity, it isn't needed.
function Rules.Resolve(rarity, progression, draw, forgeLevel)
	local preview = Rules.Preview(rarity, progression, forgeLevel)
	if not preview or not preview.Ready or not preview.ForgeUnlocked then return nil end
	local success
	if preview.Guaranteed then
		success = true
	elseif type(draw) ~= "number" or draw ~= draw
		or draw < 0 or draw >= 1 or draw == math.huge then
		return nil
	else
		success = draw < preview.Chance
	end

	local nextProgress = Progression.NormalizeProgression(progression, rarity)
	local nextRarity = rarity
	if success then
		nextRarity = preview.To
		-- Retain the attained level. XP at the previous cap is zero.
		nextProgress.XP = 0
		nextProgress.AscensionFailures = 0
	else
		nextProgress.AscensionFailures = math.min(
			Progression.MAX_ASCENSION_FAILURES,
			nextProgress.AscensionFailures + 1
		)
	end
	return {
		Success = success,
		Rarity = nextRarity,
		Progression = nextProgress,
		Preview = preview,
	}
end

return Rules
