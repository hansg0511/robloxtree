-- Pure, server-owned Grove passive rules. No persisted derived buffs.
-- Fractions are additive; crit fields are percentage points.
local Growth = require(script.Parent.GroveGrowthRules)
local Rules = {}
Rules.START_CAPACITY = 3
Rules.SPECIES = {
	Oak = { Damage = 0.03 },
	Bamboo = { SaplingChance = 0.10 },
	Ironwood = { CritDamage = 10 },
}
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
	local species = Rules.SPECIES[record.SpeciesId]
	if not species then return result end
	local function add(source)
		for stat, value in pairs(source) do
			result[stat] += value * record.CurrentSizeScale
		end
	end
	add(species)
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
