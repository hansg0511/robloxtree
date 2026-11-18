-- Roblox Studio SERVER Command Bar; pure rules, no player data mutation.
local rules = require(game.ServerScriptService.Grove.GroveGrowthRules)
local function check(name, condition) assert(condition, name .. " failed") end

check("old size migrates to genetic potential", rules.NormalizeCurrentSize(nil, 1.7) == 1.7)
check("old harvest count migrates to zero", rules.NormalizeHarvestCount(nil) == 0)
check("invalid current size repaired", rules.NormalizeCurrentSize(5, 1.4) == 1.4)
check("bad harvest count repaired", rules.NormalizeHarvestCount(-2) == 0)
check("low RNG within genetic cap", rules.RollSize(1.7, 0) <= 1.7)
check("high RNG equals genetic cap", rules.RollSize(1.7, 1) == 1.7)
check("higher roll bigger size", rules.RollSize(1.5, 0.8) > rules.RollSize(1.5, 0.2))
check("reject invalid gene", rules.RollSize(5, 0.5) == nil)
check("reject invalid roll", rules.RollSize(1, 1.5) == nil)

check("shared five-second visual cadence", rules.SECONDS_PER_VISUAL_STEP == 5)
check("baseline size has six milestones", rules.DurationForSize(1) == 30)
check("smaller tree grows faster", rules.DurationForSize(0.7) < rules.DurationForSize(1))
check("larger tree grows slower", rules.DurationForSize(1.7) > rules.DurationForSize(1))
check("maturity durations are exact five-second multiples",
	rules.DurationForSize(1.7) % 5 == 0)
check("bounded tiny/giant durations", rules.DurationForSize(0.05) >= 15
	and rules.DurationForSize(9) <= 90)
check("reject invalid duration scale", rules.DurationForSize(-1) == nil)

local initial = { PlantedAt = 1000, MaturesAt = 1030, HarvestCount = 0 }
check("first planting sapling", rules.Stage(initial, 1000) == "sapling")
check("first planting no stump stage", rules.Stage(initial, 1002) == "sapling")
check("first planting young", rules.Stage(initial, 1015) == "young")
check("first planting mature", rules.Stage(initial, 1030) == "mature")

local harvested = { PlantedAt = 1000, MaturesAt = 1030, HarvestCount = 1 }
check("harvest stump stage", rules.Stage(harvested, 1002) == "stump")
check("regrowth progresses after stump", rules.Stage(harvested, 1006) == "sapling")
check("regrowth young", rules.Stage(harvested, 1015) == "young")
check("regrowth mature", rules.Stage(harvested, 1030) == "mature")
for _, record in ipairs({ initial, harvested }) do
	for step = 0, 6 do
		local fraction, actualStep, total = rules.VisualProgress(record, 1000 + step * 5)
		check("six exact five-second milestones", actualStep == step and total == 6)
		check("milestone fraction", math.abs(fraction - step / 6) < 0.0001)
	end
	check("no premature visual jump", select(2, rules.VisualProgress(record, 1004)) == 0)
	check("last milestone remains mature", select(2, rules.VisualProgress(record, 1035)) == 6)
end

-- Existing saves retain their own MaturesAt even when it differs from
-- the new 30-second baseline. Shorter and longer cycles use matching
-- derived step counts, with no migration of their planted timestamps.
local legacy = { PlantedAt = 1000, MaturesAt = 1045, HarvestCount = 1 }
check("existing 45-second cycle has 9 milestones",
	select(3, rules.VisualProgress(legacy, 1000)) == 9)
check("legacy cycle matures at saved deadline",
	select(2, rules.VisualProgress(legacy, 1045)) == 9)
local long = { PlantedAt = 1000, MaturesAt = 1120, HarvestCount = 0 }
check("120-second cycle has 24 milestones",
	select(3, rules.VisualProgress(long, 1000)) == 24)
check("120-second cycle at half progress", select(2, rules.VisualProgress(long, 1060)) == 12)

local nextCycle = rules.NextCycle({ SizePotential = 1.6, HarvestCount = 7 }, 2000, 0.6)
check("new cycle allocated", type(nextCycle) == "table")
check("source identity not part of cycle", nextCycle.SourceSaplingUID == nil)
check("new cycle size within genetics", nextCycle.CurrentSizeScale > 0 and nextCycle.CurrentSizeScale <= 1.6)
check("new cycle duration tied to actual size",
	nextCycle.MaturesAt == 2000 + rules.DurationForSize(nextCycle.CurrentSizeScale))
check("harvest count increases once", nextCycle.HarvestCount == 8)
check("reject invalid cycle", rules.NextCycle({ SizePotential = 0 }, 2000, 0.5) == nil)

print("Grove size-derived five-second growth rules passed")
return true
