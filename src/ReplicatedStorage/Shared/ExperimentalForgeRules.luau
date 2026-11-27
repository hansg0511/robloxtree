-- Shared, pure preview / roll rules for RNG forging.
-- These are deliberately provisional balance values. Server verifies owned UIDs.
local Rules = {}
local ForgeMutations = require(script.Parent.ForgeMutationRules)

local Geometry = require(script.Parent.MaterialGeometry)
Rules.MAX_LOG_SIZE = Geometry.MAX_LOG_SIZE
Rules.MAX_OFFERED_LOGS = 96 -- defensive transaction bound, not game economy design
Rules.QUANTITY_QUALITY_RATE = 0.01
Rules.MAX_SPEED_QUALITY = 1.20 -- provisional; stays within existing server cadence cap
Rules.ROLL_MIN = 0.9
Rules.ROLL_MAX = 1.1
Rules.GOLDEN_MAX_BONUS = 0.30 -- prototype metadata only; no combat effect yet
-- First passive prototype: only freshly forged Battlehammers have Cleave.
-- Hits up to two additional server-eligible trees per successful primary hit.
Rules.CLEAVE_MIN_DAMAGE_FRACTION = 0.15
Rules.CLEAVE_DAMAGE_FRACTION = 0.65 -- at 100% forged quality
Rules.CLEAVE_MAX_DAMAGE_FRACTION = 0.75 -- matches server effect resolver
Rules.CLEAVE_MIN_RADIUS_STUDS = 8
Rules.CLEAVE_RADIUS_STUDS = 20 -- at 100% forged quality
Rules.CLEAVE_MAX_RADIUS_STUDS = 24 -- matches server effect resolver
Rules.CLEAVE_MAX_TARGETS = 2
-- World 1 first-pass material balance; Ironwood retained until its forest is assigned.
Rules.WOOD_STRENGTH = { Sapwood = 20, Bamboo = 30, Oak = 45, Ironwood = 16 }
Rules.CLASS_PROFILES = {
	-- Provisional equal-quality single-target DPS: Dagger 10% above Hammer;
	-- Axe ~5% above Hammer. No material-independent damage/speed roll.
	-- MaxAPS is the value at normal 100% quality; MAX_SPEED_QUALITY
	-- controls limited extrapolation for quantity-enhanced quality.
	Dagger = { Damage = 0.825, MinAPS = 2, MaxAPS = 3, AttacksPerSecond = 3, Reach = 0.75 },
	Axe = { Damage = 1.3125, MinAPS = 1.2, MaxAPS = 1.8, AttacksPerSecond = 1.8, Reach = 1 },
	Battlehammer = { Damage = 25 / 12, MinAPS = 0.72, MaxAPS = 1.08, AttacksPerSecond = 1.08, Reach = 1.4 },
}
Rules.CLASSES = { "Dagger", "Axe", "Battlehammer" }
Rules.COUNT_ANCHORS = {
	{ 1, 1, 0, 0 },
	{ 3, 0.8, 0.2, 0 },
	{ 5, 0.35, 0.65, 0 },
	{ 8, 0.1, 0.7, 0.2 },
	{ 10, 0.02, 0.38, 0.6 },
	{ 15, 0, 0.15, 0.85 },
	{ 20, 0, 0, 1 },
}

local function finite(value)
	return type(value) == "number" and value == value
		and value > -math.huge and value < math.huge
end

function Rules.ValidateCount(count)
	return type(count) == "number" and count % 1 == 0
		and count >= 1 and count <= Rules.MAX_OFFERED_LOGS
end

function Rules.LogQuality(sizeScale)
	if not finite(sizeScale) or sizeScale <= 0 then return nil end
	return math.clamp(sizeScale / Rules.MAX_LOG_SIZE, 0, 1)
end

function Rules.Odds(count, forgeTier)
	if not Rules.ValidateCount(count) then return nil end
	local adjustedCount = ForgeMutations.ClassCount(count, forgeTier or 1)
	if not adjustedCount then return nil end
	count = adjustedCount
	local anchors = Rules.COUNT_ANCHORS
	local last = anchors[#anchors]
	if count >= last[1] then
		return { Dagger = last[2], Axe = last[3], Battlehammer = last[4] }
	end
	for i = 1, #anchors - 1 do
		local a, b = anchors[i], anchors[i + 1]
		if count >= a[1] and count <= b[1] then
			local alpha = (count - a[1]) / (b[1] - a[1])
			local odds = {}
			for j, class in ipairs(Rules.CLASSES) do
				odds[class] = a[j + 1] + (b[j + 1] - a[j + 1]) * alpha
			end
			return odds
		end
	end
	return nil
end

function Rules.Preview(metalBase, logs, forgeTier)
	if not finite(metalBase) or metalBase <= 0
		or type(logs) ~= "table" or not Rules.ValidateCount(#logs) then return nil end
	local sumQuality, sumStrength, sumEffectiveStrength, sumGolden, sumVolume = 0, 0, 0, 0, 0
	for index = 1, #logs do
		local record = logs[index]
		if type(record) ~= "table" then return nil end
		local quality = Rules.LogQuality(record.SizeScale)
		local strength = Rules.WOOD_STRENGTH[record.SpeciesId]
		local volume = Geometry.Volume(record.SpeciesId, record.SizeScale)
		if not quality or not strength or not volume then return nil end
		sumVolume += volume
		sumQuality += quality
		sumStrength += strength
		sumEffectiveStrength += strength * quality
		if type(record.Mutations) == "table" and record.Mutations.Golden == true then
			sumGolden += quality
		end
	end
	local quality = sumQuality / #logs
	local goldenQuality = sumGolden / #logs
	local averageVolume = sumVolume / #logs
	local weaponScale = Geometry.WeaponScale(averageVolume)
	local quantityBonus = 1 + Rules.QUANTITY_QUALITY_RATE * (#logs - 1)
	local forgedQuality = quality * quantityBonus
	local averageEffectiveStrength = sumEffectiveStrength / #logs
	local reference = metalBase + averageEffectiveStrength * quantityBonus
	local function exact(value)
		return { Min = value, Max = value }
	end
	local function lerp(minimum, maximum, q)
		return minimum + (maximum - minimum) * q
	end
	local classRanges = {}
	for _, class in ipairs(Rules.CLASSES) do
		local profile = Rules.CLASS_PROFILES[class]
		classRanges[class] = {
			Damage = exact(reference * profile.Damage),
			AttacksPerSecond = exact(lerp(profile.MinAPS, profile.MaxAPS,
				math.min(forgedQuality, Rules.MAX_SPEED_QUALITY))),
			Reach = exact(Geometry.Reach(weaponScale)),
		}
		if class == "Battlehammer" then
			classRanges[class].CleaveDamageFraction = exact(math.min(
				Rules.CLEAVE_MAX_DAMAGE_FRACTION, lerp(Rules.CLEAVE_MIN_DAMAGE_FRACTION,
					Rules.CLEAVE_DAMAGE_FRACTION, forgedQuality)))
			classRanges[class].CleaveRadius = exact(math.min(
				Rules.CLEAVE_MAX_RADIUS_STUDS, lerp(Rules.CLEAVE_MIN_RADIUS_STUDS,
					Rules.CLEAVE_RADIUS_STUDS, forgedQuality)))
		end
	end
	return {
		LogCount = #logs,
		MaterialQuality = quality,
		ForgedQuality = forgedQuality,
		AverageLogVolume = averageVolume,
		WeaponScale = weaponScale,
		QuantityQualityMultiplier = quantityBonus,
		AverageEffectiveWoodStrength = averageEffectiveStrength,
		GoldenQuality = goldenQuality,
		AverageWoodStrength = sumStrength / #logs,
		Odds = Rules.Odds(#logs, forgeTier or 1),
		Ranges = classRanges,
		GoldenBonusRange = {
			Min = Rules.GOLDEN_MAX_BONUS * goldenQuality * Rules.ROLL_MIN,
			Max = Rules.GOLDEN_MAX_BONUS * goldenQuality * Rules.ROLL_MAX,
		},
	}
end

-- The server supplies a Random object. Preview never consumes an RNG draw.
function Rules.Roll(metalBase, logs, rng, forgeTier)
	local preview = Rules.Preview(metalBase, logs, forgeTier)
	if not preview or not rng then return nil end
	local draw = rng:NextNumber()
	local cumulative, class = 0, Rules.CLASSES[#Rules.CLASSES]
	for _, name in ipairs(Rules.CLASSES) do
		cumulative += preview.Odds[name]
		if draw < cumulative then
			class = name
			break
		end
	end
	local ranges = preview.Ranges[class]
	local function stat(range)
		if range.Min == range.Max then return range.Min end
		return range.Min + (range.Max - range.Min) * rng:NextNumber()
	end
	return {
		Class = class,
		MaterialQuality = preview.MaterialQuality,
		ForgedQuality = preview.ForgedQuality,
		AverageLogVolume = preview.AverageLogVolume,
		WeaponScale = preview.WeaponScale,
		QuantityQualityMultiplier = preview.QuantityQualityMultiplier,
		AverageEffectiveWoodStrength = preview.AverageEffectiveWoodStrength,
		GoldenQuality = preview.GoldenQuality,
		AverageWoodStrength = preview.AverageWoodStrength,
		Damage = stat(ranges.Damage),
		AttacksPerSecond = stat(ranges.AttacksPerSecond),
		Reach = stat(ranges.Reach),
		CleaveDamageFraction = if ranges.CleaveDamageFraction
			then stat(ranges.CleaveDamageFraction) else nil,
		CleaveRadius = if ranges.CleaveRadius
			then stat(ranges.CleaveRadius) else nil,
		GoldenBonus = if preview.GoldenQuality > 0
			then stat(preview.GoldenBonusRange) else 0,
	}
end

return Rules
