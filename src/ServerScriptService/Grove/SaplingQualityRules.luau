-- Shared server-owned acquisition quality; all numeric tuning provisional.
local Geometry = require(game.ReplicatedStorage.Shared.MaterialGeometry)
local Rules = {}
Rules.BANDS = {
	{ Weight=850, Min=0.70, Max=1.10 },
	{ Weight=120, Min=1.10, Max=1.50 },
	{ Weight=27, Min=1.50, Max=2.50 },
	{ Weight=3, Min=2.50, Max=3.50 },
}
-- Conditional non-jackpot band weights. Faster growth trades quality
-- odds for harvest frequency. The extreme band and jackpot stay scarce.
Rules.WEIGHTS_BY_SPECIES = {
	Sapwood = {850,120,27,3},
	Bamboo = {850,120,27,3},
	Oak = {800,150,47,3},
	Ironwood = {750,180,67,3},
}
for _,weights in pairs(Rules.WEIGHTS_BY_SPECIES) do
	local total=0
	assert(#weights==#Rules.BANDS,"size band mismatch")
	for _,weight in ipairs(weights) do
		assert(weight>=0 and weight%1==0,"invalid size weight")
		total+=weight
	end
	assert(total==1000,"size weights must total 1000")
end
Rules.GIANT_MULTIPLIER = Geometry.GIANT_SIZE_MULTIPLIER
Rules.BASE_MAX_POTENTIAL = Geometry.MAX_LOG_SIZE
Rules.MAX_POTENTIAL = Geometry.MAX_PHYSICAL_LOG_SIZE
Rules.PERFECT_ROLL_DENOMINATOR = 10000
Rules.PERFECT_WEIGHT = 1
Rules.GIANT_PERFECT_WEIGHT = 4
function Rules.WithMutation(base, mutations)
	local giant=type(mutations)=="table" and mutations.Giant==true
	local multiplier=if giant then Rules.GIANT_MULTIPLIER else 1
	-- Giant scales the full ordinary range, including a perfect 5x base.
	-- Non-Giant perfect potential still requires the explicit jackpot.
	local cap=if giant then Rules.MAX_POTENTIAL else Rules.BASE_MAX_POTENTIAL-0.001
	return math.min(cap, math.floor(base*multiplier*1000+0.5)/1000)
end
function Rules.Wild(mutations, rng, speciesId)
	local giant=type(mutations)=="table" and mutations.Giant==true
	local perfectWeight=if giant then Rules.GIANT_PERFECT_WEIGHT else Rules.PERFECT_WEIGHT
	if rng:NextInteger(1,Rules.PERFECT_ROLL_DENOMINATOR)<=perfectWeight then
		return if giant then Rules.MAX_POTENTIAL else Rules.BASE_MAX_POTENTIAL
	end
	local draw = rng:NextInteger(1,1000)
	local sum = 0
	local weights=Rules.WEIGHTS_BY_SPECIES[speciesId]
	for i, band in ipairs(Rules.BANDS) do
		sum += if weights then weights[i] else band.Weight
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
