-- Phase 1C: server-only, material-independent natural weapon rarity rolls.
-- This module never selects weapon class, power, mutation skills or materials.
-- The forge calls this exactly once for each successful weapon candidate.
local ProgressionRules = require(game.ServerScriptService.WeaponProgressionRules)

local RarityRoll = {}

-- PROVISIONAL: adjust after a meaningful forge sample. Every normal rarity
-- has a non-zero chance even on the first forge tier and ordinary logs.
-- Integer weights avoid floating-point gaps at very rare boundaries.
RarityRoll.TOTAL_WEIGHT = 1000000
RarityRoll.WEIGHTS = {
	Common = 780000,    -- 78.00%
	Rare = 185000,      -- 18.50%
	Epic = 30000,       --  3.00%
	Legendary = 4500,   --  0.45%
	Ultra = 500,        --  0.05%
}

local cumulative = {}
local total = 0
for _, rarity in ipairs(ProgressionRules.RARITY_ORDER) do
	local weight = RarityRoll.WEIGHTS[rarity]
	assert(type(weight) == "number" and weight > 0 and weight % 1 == 0,
		"Every configured normal rarity must have a positive integer roll weight")
	assert(ProgressionRules.IsRarity(rarity), "Unknown rarity in configured rarity order")
	total += weight
	table.insert(cumulative, { Rarity = rarity, UpperBound = total })
end
assert(total == RarityRoll.TOTAL_WEIGHT,
	"Natural rarity odds must sum exactly to TOTAL_WEIGHT")

-- Rolls require one independently generated integer in [1, TOTAL_WEIGHT].
-- The optional rng is only for deterministic synthetic tests. No client
-- payload or crafting ingredient controls rarity RNG.
function RarityRoll.Roll(rng)
	local generator = rng or Random.new()
	local ok, draw = pcall(function()
		return generator:NextInteger(1, RarityRoll.TOTAL_WEIGHT)
	end)
	if not ok or type(draw) ~= "number" or draw ~= draw
		or draw % 1 ~= 0 or draw < 1
		or draw > RarityRoll.TOTAL_WEIGHT then
		return nil -- fail closed; the forge must restore consumed ingredients
	end
	for _, entry in ipairs(cumulative) do
		if draw <= entry.UpperBound then
			return entry.Rarity
		end
	end
	return nil
end

return RarityRoll
