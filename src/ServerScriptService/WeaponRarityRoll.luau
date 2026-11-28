-- Phase 1C: server-only, material-independent natural weapon rarity rolls.
-- This module never selects weapon class, power, mutation skills or materials.
-- The forge calls this exactly once for each successful weapon candidate.
local ProgressionRules = require(game.ServerScriptService.WeaponProgressionRules)

local RarityRoll = {}

local Config=require(game.ReplicatedStorage.Shared.ProgressionConfig)
RarityRoll.TOTAL_WEIGHT=Config.TOTAL_RARITY_WEIGHT
function RarityRoll.WeightsForLevel(level)
	return Config.RarityWeights(level)
end
RarityRoll.WEIGHTS=RarityRoll.WeightsForLevel(1)
-- Rolls require one independently generated integer in [1, TOTAL_WEIGHT].
-- The optional rng is only for deterministic synthetic tests. No client
-- payload or crafting ingredient controls rarity RNG.
function RarityRoll.Roll(rng, forgeLevel)
	local generator = rng or Random.new()
	local ok, draw = pcall(function()
		return generator:NextInteger(1, RarityRoll.TOTAL_WEIGHT)
	end)
	if not ok or type(draw) ~= "number" or draw ~= draw
		or draw % 1 ~= 0 or draw < 1
		or draw > RarityRoll.TOTAL_WEIGHT then
		return nil -- fail closed; the forge must restore consumed ingredients
	end
	local weights = RarityRoll.WeightsForLevel(forgeLevel)
	local upper = 0
	for _, rarity in ipairs(ProgressionRules.RARITY_ORDER) do
		upper += weights[rarity]
		if draw <= upper then return rarity end
	end
	return nil
end

return RarityRoll
