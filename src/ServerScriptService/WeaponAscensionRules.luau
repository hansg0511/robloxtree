-- Phase 1D: pure, configurable rarity ascension math and costs.
-- Does not touch inventories, remotes, RNG state or player data.
local Progression = require(game.ServerScriptService.WeaponProgressionRules)

local Rules = {}

-- Provisional balancing only: no player-facing cost or rate is finalized.
-- Ascension always advances exactly ONE step, never Secret.
Rules.STEPS = {
	Common = { To = "Rare", Chance = 0.50, Coins = 150, Logs = 1 },
	Rare = { To = "Epic", Chance = 0.25, Coins = 600, Logs = 2 },
	Epic = { To = "Legendary", Chance = 0.10, Coins = 2500, Logs = 3 },
	Legendary = { To = "Ultra", Chance = 0.02, Coins = 9000, Logs = 4 },
}

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
			and validInteger(step.Logs) and step.Logs > 0, "Invalid ascension config " .. rarity)
	else
		assert(step == nil, "Ultra must have no normal ascension step")
	end
end

function Rules.PityLimit(rarity)
	local step = Rules.STEPS[rarity]
	if not step then return nil end
	return math.ceil(1.5 / step.Chance)
end

-- All returned values are immutable by convention; do not mutate STEPS.
-- A capped weapon remains capped after failed attempts.
function Rules.Preview(rarity, progression)
	local step = Rules.STEPS[rarity]
	if not step then return nil end
	local current = Progression.NormalizeProgression(progression, rarity)
	local limit = Rules.PityLimit(rarity)
	local attemptNumber = math.min(limit, current.AscensionFailures + 1)
	local guaranteed = attemptNumber >= limit
	return {
		From = rarity,
		To = step.To,
		Coins = step.Coins,
		Logs = step.Logs,
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
function Rules.Resolve(rarity, progression, draw)
	local preview = Rules.Preview(rarity, progression)
	if not preview or not preview.Ready then return nil end
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
		nextProgress.Level = 1
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
