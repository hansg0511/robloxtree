-- Shared, pure preview / roll rules for STUDIO-ONLY experimental forging.
-- These are deliberately provisional balance values. Server verifies owned UIDs.
local Rules = {}

Rules.MAX_LOG_SIZE = 5
Rules.MAX_OFFERED_LOGS = 96 -- defensive transaction bound, not game economy design
Rules.QUALITY_FLOOR = 0.5
Rules.ROLL_MIN = 0.9
Rules.ROLL_MAX = 1.1
Rules.GOLDEN_MAX_BONUS = 0.30 -- prototype metadata only; no combat effect yet
Rules.WOOD_STRENGTH = { Bamboo = 6, Oak = 10, Ironwood = 16 }
Rules.CLASS_PROFILES = {
	Dagger = { Damage = 0.55, AttacksPerSecond = 2.2, Reach = 0.75 },
	Axe = { Damage = 1.25, AttacksPerSecond = 1.2, Reach = 1 },
	Battlehammer = { Damage = 3.6, AttacksPerSecond = 0.7, Reach = 1.4 },
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

function Rules.Odds(count)
	if not Rules.ValidateCount(count) then return nil end
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

function Rules.Preview(metalBase, logs)
	if not finite(metalBase) or metalBase <= 0
		or type(logs) ~= "table" or not Rules.ValidateCount(#logs) then return nil end
	local sumQuality, sumStrength, sumGolden = 0, 0, 0
	for index = 1, #logs do
		local record = logs[index]
		if type(record) ~= "table" then return nil end
		local quality = Rules.LogQuality(record.SizeScale)
		local strength = Rules.WOOD_STRENGTH[record.SpeciesId]
		if not quality or not strength then return nil end
		sumQuality += quality
		sumStrength += strength
		if type(record.Mutations) == "table" and record.Mutations.Golden == true then
			sumGolden += quality
		end
	end
	local quality = sumQuality / #logs
	local goldenQuality = sumGolden / #logs
	local factor = Rules.QUALITY_FLOOR + (1 - Rules.QUALITY_FLOOR) * quality
	local reference = metalBase + sumStrength / #logs
	local classRanges = {}
	for _, class in ipairs(Rules.CLASSES) do
		local profile = Rules.CLASS_PROFILES[class]
		local function statRange(base)
			return { Min = base * factor * Rules.ROLL_MIN, Max = base * factor * Rules.ROLL_MAX }
		end
		classRanges[class] = {
			Damage = statRange(reference * profile.Damage),
			AttacksPerSecond = statRange(profile.AttacksPerSecond),
			Reach = statRange(profile.Reach),
		}
	end
	return {
		LogCount = #logs,
		MaterialQuality = quality,
		GoldenQuality = goldenQuality,
		AverageWoodStrength = sumStrength / #logs,
		Odds = Rules.Odds(#logs),
		Ranges = classRanges,
		GoldenBonusRange = {
			Min = Rules.GOLDEN_MAX_BONUS * goldenQuality * Rules.ROLL_MIN,
			Max = Rules.GOLDEN_MAX_BONUS * goldenQuality * Rules.ROLL_MAX,
		},
	}
end

-- The server supplies a Random object. Preview never consumes an RNG draw.
function Rules.Roll(metalBase, logs, rng)
	local preview = Rules.Preview(metalBase, logs)
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
		return range.Min + (range.Max - range.Min) * rng:NextNumber()
	end
	return {
		Class = class,
		MaterialQuality = preview.MaterialQuality,
		GoldenQuality = preview.GoldenQuality,
		AverageWoodStrength = preview.AverageWoodStrength,
		Damage = stat(ranges.Damage),
		AttacksPerSecond = stat(ranges.AttacksPerSecond),
		Reach = stat(ranges.Reach),
		GoldenBonus = if preview.GoldenQuality > 0
			then stat(preview.GoldenBonusRange) else 0,
	}
end

return Rules
