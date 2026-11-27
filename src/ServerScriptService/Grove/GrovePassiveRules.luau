-- Pure, server-owned Grove passive rules. No persisted derived buffs.
-- Fractions are additive; crit fields are percentage points.
local Growth = require(script.Parent.GroveGrowthRules)
local Rules = {}
Rules.START_CAPACITY = 3
-- Neutral placeholders until joint weapon/Grove/economy balancing.
-- Later forest species should receive progressively stronger passives.
-- This is independent of material strength, sale price and growth duration.
Rules.SPECIES_PASSIVE_MULTIPLIERS = {
	Sapwood = 1,
	Bamboo = 1,
	Oak = 1,
	Ironwood = 1,
}
Rules.GENETICS = {
	Strength = { Damage = 0.03 },
	Seedfinder = { SaplingChance = 0.10 },
	Impact = { CritDamage = 10 },
	Prosperity = { Sale = 0.05 },
	Haste = { Haste = 0.05 },
	Precision = { CritChance = 2 },
}
Rules.GENETIC_IDS = { "Strength", "Seedfinder", "Impact", "Prosperity", "Haste", "Precision" }
local rng = Random.new()
function Rules.RollGenetic()
	return Rules.GENETIC_IDS[rng:NextInteger(1, #Rules.GENETIC_IDS)]
end
-- Existing records receive a stable UID-derived assignment once; normalization
-- preserves valid saved genetics, including across harvests and rejoining.
function Rules.NormalizeGenetic(value, uid)
	if type(value) == "string" and Rules.GENETICS[value] then return value end
	local hash = 0
	for i = 1, #uid do hash = (hash * 31 + string.byte(uid, i)) % 2147483647 end
	return Rules.GENETIC_IDS[hash % #Rules.GENETIC_IDS + 1]
end
Rules.MUTATIONS = {
	Golden = { Sale = 0.05 },
	Frenzied = { Haste = 0.05 },
	Shocked = { CritChance = 2 },
}
function Rules.Empty()
	return { Damage = 0, SaplingChance = 0, CritDamage = 0, Sale = 0, Haste = 0, CritChance = 0 }
end
local function finite(x)
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end
function Rules.ForTree(record, now)
	local result = Rules.Empty()
	if type(record) ~= "table" or not finite(now)
		or not finite(record.PlantedAt) or not finite(record.MaturesAt)
		or record.MaturesAt <= record.PlantedAt or now < record.MaturesAt
		or not Growth.ValidPotential(record.SizePotential)
		or not finite(record.CurrentSizeScale)
		or record.CurrentSizeScale < Growth.MIN_POTENTIAL * Growth.MIN_RELATIVE_SIZE
		or record.CurrentSizeScale > record.SizePotential then return result end
	local genetic = Rules.GENETICS[record.GeneticPassive]
	if not genetic then return result end
	local speciesMultiplier = Rules.SPECIES_PASSIVE_MULTIPLIERS[record.SpeciesId] or 1
	local passiveScale = record.CurrentSizeScale * speciesMultiplier
	local function add(source)
		for stat, value in pairs(source) do
			result[stat] += value * passiveScale
		end
	end
	add(genetic)
	if type(record.Mutations) == "table" then
		for mutation, source in pairs(Rules.MUTATIONS) do
			if record.Mutations[mutation] == true then add(source) end
		end
	end
	-- Giant affects actual size, not a second multiplier.
	return result
end
function Rules.Totals(data, now)
	local result = Rules.Empty()
	if type(data) ~= "table" or type(data.GroveTrees) ~= "table" then return result end
	local seen = {}
	for _, record in ipairs(data.GroveTrees) do
		if type(record) == "table" and type(record.UID) == "string" and not seen[record.UID] then
			seen[record.UID] = true
			for stat, value in pairs(Rules.ForTree(record, now)) do
				result[stat] += value
			end
		end
	end
	return result
end
function Rules.SaleValue(base, bonuses)
	return math.floor(base * (1 + bonuses.Sale) + 0.5)
end
return Rules
