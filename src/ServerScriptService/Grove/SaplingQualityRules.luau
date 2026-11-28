-- Shared server-owned acquisition quality; all numeric tuning provisional.
local Rules = {}
Rules.BANDS = {
	{ Weight=850, Min=0.70, Max=1.10 },
	{ Weight=120, Min=1.10, Max=1.50 },
	{ Weight=27, Min=1.50, Max=2.50 },
	{ Weight=3, Min=2.50, Max=3.50 },
}
Rules.GIANT_MULTIPLIER = 1.4
Rules.MAX_POTENTIAL = 5
Rules.PERFECT_ROLL_DENOMINATOR = 10000
Rules.PERFECT_WEIGHT = 1
Rules.GIANT_PERFECT_WEIGHT = 4
function Rules.WithMutation(base, mutations)
	local multiplier = if type(mutations)=="table" and mutations.Giant==true then Rules.GIANT_MULTIPLIER else 1
	-- Only the explicit wild jackpot can create exactly 5x potential,
	-- even if future ordinary size bands exceed today's 3.5x maximum.
	return math.min(Rules.MAX_POTENTIAL-0.001, math.floor(base*multiplier*1000+0.5)/1000)
end
function Rules.Wild(mutations, rng)
	local giant=type(mutations)=="table" and mutations.Giant==true
	local perfectWeight=if giant then Rules.GIANT_PERFECT_WEIGHT else Rules.PERFECT_WEIGHT
	if rng:NextInteger(1,Rules.PERFECT_ROLL_DENOMINATOR)<=perfectWeight then
		return Rules.MAX_POTENTIAL
	end
	local draw = rng:NextInteger(1,1000)
	local sum = 0
	for _, band in ipairs(Rules.BANDS) do
		sum += band.Weight
		if draw <= sum then
			return Rules.WithMutation(rng:NextNumber(band.Min,band.Max), mutations)
		end
	end
	error("Invalid wild quality distribution")
end
function Rules.Shop(mutations, rng)
	return Rules.WithMutation(rng:NextNumber(0.9,1.5),mutations)
end
return Rules
