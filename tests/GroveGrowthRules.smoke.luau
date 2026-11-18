-- Roblox Studio SERVER Command Bar; pure rules with no player data mutation.
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

check("shared two-second test cadence", rules.SECONDS_PER_VISUAL_STEP == 2)
check("steps for size 1 are derived from the baseline", rules.StepsForSize(1) == 6)
check("six two-second milestones finish in 12 seconds",
	rules.DurationForSize(1) == 12)
check("small trees get fewer steps", rules.StepsForSize(0.7) == 4)
check("large trees get more steps", rules.StepsForSize(1.5) == 9)
check("small tree 8-second grow", rules.DurationForSize(0.7) == 8)
check("big tree 18-second grow", rules.DurationForSize(1.5) == 18)
check("duration is derived from steps and cadence", rules.DurationForSize(1.7)
	== rules.StepsForSize(1.7) * rules.SECONDS_PER_VISUAL_STEP)
check("bounded step counts", rules.StepsForSize(0.05) == 3
	and rules.StepsForSize(9) == 18)
check("reject invalid size", rules.StepsForSize(-1) == nil
	and rules.DurationForSize(-1) == nil)
check("stump hold safely exceeds harvest-fall presentation",
	rules.STUMP_SECONDS == 4)

local initial = { PlantedAt = 1000, MaturesAt = 1012, HarvestCount = 0 }
check("first planting starts as sapling", rules.Stage(initial, 1000) == "sapling")
check("first planting young", rules.Stage(initial, 1005) == "young")
check("first planting mature at 12 seconds", rules.Stage(initial, 1012) == "mature")

local harvested = { PlantedAt = 1000, MaturesAt = 1016, HarvestCount = 1 }
check("regrowth stump at 2 seconds", rules.Stage(harvested, 1002) == "stump")
check("regrowth stump at 3 seconds", rules.Stage(harvested, 1003) == "stump")
check("stump hold ends at four seconds", rules.Stage(harvested, 1004) == "sapling")
check("regrowth young", rules.Stage(harvested, 1009) == "young")
check("regrowth mature after hold + six updates",
	rules.Stage(harvested, 1016) == "mature")

for _, entry in ipairs({
	{ Record = initial, Start = 1000 },
	{ Record = harvested, Start = 1004 },
}) do
	for step = 0, 6 do
		local fraction, actualStep, total = rules.VisualProgress(
			entry.Record, entry.Start + step * 2)
		check("six exact two-second milestones", actualStep == step and total == 6)
		check("fraction matches current milestone", math.abs(fraction - step / 6) < 0.0001)
	end
	check("no jump between milestones",
		select(2, rules.VisualProgress(entry.Record, entry.Start + 1)) == 0)
	check("fully grown remains at final milestone",
		select(2, rules.VisualProgress(entry.Record, entry.Record.MaturesAt + 10)) == 6)
end
check("regrowth visual still stump during cinematic",
	select(2, rules.VisualProgress(harvested, 1003)) == 0)

-- Earlier persisted maturity deadlines remain authoritative even if they do
-- not land on a new two-second interval; no profile data is rewritten.
local legacy = { PlantedAt = 1000, MaturesAt = 1045, HarvestCount = 1 }
check("legacy 45-second cycle uses remaining time after stump",
	select(3, rules.VisualProgress(legacy, 1000)) == 21)
check("legacy saves mature at their original deadline",
	select(2, rules.VisualProgress(legacy, 1045)) == 21)
local long = { PlantedAt = 1000, MaturesAt = 1120, HarvestCount = 0 }
check("120-second saved cycle has 60 two-second intervals",
	select(3, rules.VisualProgress(long, 1000)) == 60)
check("long cycle half way", select(2, rules.VisualProgress(long, 1060)) == 30)

local cycle = rules.NextCycle({ SizePotential = 1.6, HarvestCount = 7 }, 2000, 0.6)
check("new cycle allocated", type(cycle) == "table")
check("source identity not part of cycle", cycle.SourceSaplingUID == nil)
check("cycle size within genetic cap",
	cycle.CurrentSizeScale > 0 and cycle.CurrentSizeScale <= 1.6)
check("regrowth duration derived plus cinematic stump hold",
	cycle.MaturesAt == 2000 + rules.STUMP_SECONDS
		+ rules.DurationForSize(cycle.CurrentSizeScale))
check("harvest count increments once", cycle.HarvestCount == 8)
check("reject invalid cycle", rules.NextCycle({ SizePotential = 0 }, 2000, 0.5) == nil)

print("Grove two-second size-derived growth rules passed")
return true
