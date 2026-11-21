-- Pure prototype Grove growth rules. A sapling's genetic SizePotential
-- stays fixed while each mature growth cycle rolls a bounded actual size.
local Rules = {}

-- Temporary test pacing: all newly planted / regrowing Grove trees take
-- exactly 30 seconds, regardless of actual or genetic size. There are
-- fifteen two-second clock intervals in the entire cycle.
Rules.SECONDS_PER_VISUAL_STEP = 2
Rules.MATURITY_SECONDS = 30
Rules.TOTAL_CYCLE_STEPS = Rules.MATURITY_SECONDS / Rules.SECONDS_PER_VISUAL_STEP
-- Following a harvest, the first two intervals are stump/cinematic hold
-- (the falling tree presentation lasts ~2.6 seconds). They are INCLUDED in
-- the 30-second deadline, not added on top.
Rules.STUMP_SECONDS = Rules.SECONDS_PER_VISUAL_STEP * 2
Rules.SAPLING_FRACTION = 0.25
Rules.MIN_POTENTIAL = 0.1
Rules.MAX_POTENTIAL = 2
Rules.MIN_RELATIVE_SIZE = 0.65
Rules.MAX_HARVEST_COUNT = 1000000

local function finite(x)
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

-- Keep the existing API while freezing size-dependent growth for testing.
-- We validate the input but intentionally ignore its magnitude. Once we're
-- ready to balance large-vs-small trees, only these rules need to change.
-- Existing saved trees retain their MaturesAt rather than being retimed.
function Rules.StepsForSize(currentSize)
	if not finite(currentSize) or currentSize <= 0 then return nil end
	return Rules.TOTAL_CYCLE_STEPS
end

function Rules.DurationForSize(currentSize)
	if not Rules.StepsForSize(currentSize) then return nil end
	return Rules.MATURITY_SECONDS
end

function Rules.ValidPotential(x)
	return finite(x) and x >= Rules.MIN_POTENTIAL and x <= Rules.MAX_POTENTIAL
end

function Rules.NormalizeCurrentSize(value, potential)
	if not Rules.ValidPotential(potential) then return nil end
	-- Older planted Grove trees used their potential as their actual size.
	-- Preserve that first generation exactly during profile migration.
	if finite(value) and value >= Rules.MIN_POTENTIAL * Rules.MIN_RELATIVE_SIZE
		and value <= potential then return value end
	return potential
end

function Rules.NormalizeHarvestCount(value)
	if finite(value) and value >= 0 and value <= Rules.MAX_HARVEST_COUNT
		and value % 1 == 0 then return value end
	return 0
end

function Rules.RollSize(potential, roll)
	if not Rules.ValidPotential(potential) then return nil end
	if not finite(roll) or roll < 0 or roll > 1 then return nil end
	local fraction = Rules.MIN_RELATIVE_SIZE + (1 - Rules.MIN_RELATIVE_SIZE) * roll
	local raw = potential * fraction
	return math.min(potential, math.max(Rules.MIN_POTENTIAL * Rules.MIN_RELATIVE_SIZE,
		math.floor(raw * 1000 + 0.5) / 1000))
end

-- A continuous 0..1 presentation value, independent of the legacy
-- sapling/young/mature labels used for gameplay status. Regrowth retains
-- a visible stump briefly before its trunk begins growing.
function Rules.Progress(record, now)
	if type(record) ~= "table" or not finite(record.PlantedAt)
		or not finite(record.MaturesAt) or not finite(now)
		or record.MaturesAt <= record.PlantedAt then return 0 end
	local start = record.PlantedAt
	if Rules.NormalizeHarvestCount(record.HarvestCount) > 0 then
		start += Rules.STUMP_SECONDS
	end
	if now <= start then return 0 end
	local duration = record.MaturesAt - start
	if duration <= 0 then return 1 end
	return math.clamp((now - start) / duration, 0, 1)
end

-- Discrete presentation-only progress. At initial planting, step zero is
-- the starting stump view; on regrowth, the harvested stump remains through
-- the separate cinematic/stump hold. Afterwards geometry advances at the
-- configured cadence. MaturesAt remains the only authoritative harvest gate.
function Rules.VisualProgress(record, now)
	if type(record) ~= "table" or not finite(record.PlantedAt)
		or not finite(record.MaturesAt) or not finite(now)
		or record.MaturesAt <= record.PlantedAt then return 0, 0, 0 end
	local start = record.PlantedAt
	if Rules.NormalizeHarvestCount(record.HarvestCount) > 0 then
		start += Rules.STUMP_SECONDS
	end
	local duration = record.MaturesAt - start
	if duration <= 0 then
		local done = now >= record.MaturesAt
		return if done then 1 else 0, if done then 1 else 0, 1
	end
	local total = math.max(1, math.ceil(duration / Rules.SECONDS_PER_VISUAL_STEP))
	local step = math.clamp(math.floor((now - start) / Rules.SECONDS_PER_VISUAL_STEP), 0, total)
	if now >= record.MaturesAt then step = total end
	return step / total, step, total
end

function Rules.Stage(record, now)
	if type(record) ~= "table" or not finite(record.PlantedAt)
		or not finite(record.MaturesAt) or not finite(now) then return "sapling" end
	local plantedAt, maturesAt = record.PlantedAt, record.MaturesAt
	if Rules.NormalizeHarvestCount(record.HarvestCount) > 0
		and now < plantedAt + Rules.STUMP_SECONDS then return "stump" end
	local growingStart = if Rules.NormalizeHarvestCount(record.HarvestCount) > 0
		then plantedAt + Rules.STUMP_SECONDS else plantedAt
	local saplingEnd = growingStart
		+ (maturesAt - growingStart) * Rules.SAPLING_FRACTION
	if now < saplingEnd then return "sapling" end
	if now < maturesAt then return "young" end
	return "mature"
end

function Rules.NextCycle(record, now, roll)
	if type(record) ~= "table" or not Rules.ValidPotential(record.SizePotential)
		or not finite(now) or now < 0 then return nil end
	local count = Rules.NormalizeHarvestCount(record.HarvestCount)
	if count >= Rules.MAX_HARVEST_COUNT then return nil end
	local size = Rules.RollSize(record.SizePotential, roll)
	if not size then return nil end
	return {
		PlantedAt = now,
		MaturesAt = now + Rules.DurationForSize(size),
		CurrentSizeScale = size,
		HarvestCount = count + 1,
	}
end

return Rules
