-- Roblox Studio SERVER Command Bar; checks size-derived growth without
-- hardcoding the active prototype's visual cadence into every assertion.
local rules = require(game.ServerScriptService.Grove.GroveGrowthRules)
local function check(name, ok) assert(ok, name .. " failed") end
local cadence = rules.SECONDS_PER_VISUAL_STEP
local baselineSteps = rules.StepsForSize(1)
local baseDuration = rules.DurationForSize(1)
local stumpHold = rules.STUMP_SECONDS

check("old size migrates to genetic potential", rules.NormalizeCurrentSize(nil, 1.7) == 1.7)
check("old harvest count migrates to zero", rules.NormalizeHarvestCount(nil) == 0)
check("invalid current size repaired", rules.NormalizeCurrentSize(5, 1.4) == 1.4)
check("bad harvest count repaired", rules.NormalizeHarvestCount(-2) == 0)
check("low RNG within genetic cap", rules.RollSize(1.7, 0) <= 1.7)
check("high RNG equals genetic cap", rules.RollSize(1.7, 1) == 1.7)
check("higher roll bigger size", rules.RollSize(1.5, 0.8) > rules.RollSize(1.5, 0.2))
check("reject invalid gene", rules.RollSize(5, 0.5) == nil)
check("reject invalid roll", rules.RollSize(1, 1.5) == nil)

check("valid shared step interval", type(cadence) == "number"
	and cadence >= 1 and cadence % 1 == 0)
check("baseline six steps for size 1", baselineSteps == 6)
check("baseline duration derives from cadence",
	baseDuration == baselineSteps * cadence)
check("small trees get fewer steps", rules.StepsForSize(0.7) == 4)
check("large trees get more steps", rules.StepsForSize(1.5) == 9)
check("duration derives from size and shared step interval",
	rules.DurationForSize(0.7) == 4 * cadence
		and rules.DurationForSize(1.5) == 9 * cadence)
check("bounded steps", rules.StepsForSize(0.05) == 3
	and rules.StepsForSize(9) == 18)
check("reject invalid size", rules.StepsForSize(-1) == nil
	and rules.DurationForSize(-1) == nil)
check("stump hold exceeds cinematic delay", stumpHold > 2.6)
check("stump hold aligns to global cadence", stumpHold % cadence == 0)

local planted = 1000
local initial = {
	PlantedAt = planted, MaturesAt = planted + baseDuration, HarvestCount = 0,
}
local regrow = {
	PlantedAt = planted,
	MaturesAt = planted + stumpHold + baseDuration, HarvestCount = 1,
}
check("first planting starts as sapling", rules.Stage(initial, planted) == "sapling")
check("first planting progresses to young",
	rules.Stage(initial, planted + math.floor(baseDuration * 0.5)) == "young")
check("first planting matures at derived deadline",
	rules.Stage(initial, initial.MaturesAt) == "mature")
check("regrowth stays stump through hold",
	rules.Stage(regrow, planted + stumpHold - 1) == "stump")
check("regrowth has real sapling phase after hold",
	rules.Stage(regrow, planted + stumpHold) == "sapling")
check("regrowth progresses to young",
	rules.Stage(regrow, planted + stumpHold + math.floor(baseDuration * 0.5)) == "young")
check("regrowth matures at derived deadline",
	rules.Stage(regrow, regrow.MaturesAt) == "mature")

for _, cycle in ipairs({
	{ Record = initial, Start = planted },
	{ Record = regrow, Start = planted + stumpHold },
}) do
	for step = 0, baselineSteps do
		local fraction, actual, total = rules.VisualProgress(
			cycle.Record, cycle.Start + step * cadence)
		check("step derived from elapsed time", actual == step and total == baselineSteps)
		check("visual fraction matches derived step",
			math.abs(fraction - step / baselineSteps) < 0.0001)
	end
	check("no jump before interval finishes",
		select(2, rules.VisualProgress(cycle.Record, cycle.Start + cadence - 1)) == 0)
	check("mature visuals remain at final step",
		select(2, rules.VisualProgress(cycle.Record, cycle.Record.MaturesAt + 10))
			== baselineSteps)
end
check("cinematic stump visual stays at step zero",
	select(2, rules.VisualProgress(regrow, planted + stumpHold - 1)) == 0)

-- Existing records keep their previous MaturesAt even with new prototype
-- settings; legacy deadlines that don't align to the cadence still finish.
local legacy = { PlantedAt = planted, MaturesAt = 1045, HarvestCount = 1 }
local legacyTotal = math.ceil((legacy.MaturesAt - planted - stumpHold) / cadence)
check("legacy total steps use persisted timing",
	select(3, rules.VisualProgress(legacy, planted)) == legacyTotal)
check("legacy remains harvestable at its original deadline",
	select(2, rules.VisualProgress(legacy, 1045)) == legacyTotal)
local long = { PlantedAt = planted, MaturesAt = 1120, HarvestCount = 0 }
check("long saved timeline steps derived from its timestamps",
	select(3, rules.VisualProgress(long, planted)) == math.ceil(120 / cadence))

local cycle = rules.NextCycle({ SizePotential = 1.6, HarvestCount = 7 }, 2000, 0.6)
check("new cycle created", type(cycle) == "table")
check("source identity not part of cycle", cycle.SourceSaplingUID == nil)
check("new cycle within genetic cap",
	cycle.CurrentSizeScale > 0 and cycle.CurrentSizeScale <= 1.6)
check("regrowth maturity includes stump hold and size-derived duration",
	cycle.MaturesAt == 2000 + stumpHold
		+ rules.DurationForSize(cycle.CurrentSizeScale))
check("harvest count increments once", cycle.HarvestCount == 8)
check("reject invalid cycle", rules.NextCycle({ SizePotential = 0 }, 2000, 0.5) == nil)

print("Grove size-derived step timing passed; active cadence:", cadence, "seconds")
return true
