-- Run in Roblox Studio's SERVER Command Bar after Rojo sync.
-- Not mapped to live place by default.project.json.
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

local initial = { PlantedAt = 1000, MaturesAt = 1045, HarvestCount = 0 }
check("first planting sapling", rules.Stage(initial, 1000) == "sapling")
check("first planting no stump", rules.Stage(initial, 1002) == "sapling")
check("first planting young", rules.Stage(initial, 1015) == "young")
check("first planting mature", rules.Stage(initial, 1045) == "mature")

local harvested = { PlantedAt = 1000, MaturesAt = 1045, HarvestCount = 1 }
check("harvest stump stage", rules.Stage(harvested, 1002) == "stump")
check("stump becomes sapling", rules.Stage(harvested, 1006) == "sapling")
check("regrowth young", rules.Stage(harvested, 1015) == "young")
check("regrowth mature", rules.Stage(harvested, 1045) == "mature")

local nextCycle = rules.NextCycle({ SizePotential = 1.6, HarvestCount = 7 }, 2000, 0.6)
check("new cycle allocated", type(nextCycle) == "table")
check("source identity not part of cycle", nextCycle.SourceSaplingUID == nil)
check("new cycle dates", nextCycle.PlantedAt == 2000 and nextCycle.MaturesAt == 2045)
check("new cycle size within genetics", nextCycle.CurrentSizeScale > 0 and nextCycle.CurrentSizeScale <= 1.6)
check("harvest count increases once", nextCycle.HarvestCount == 8)
check("reject invalid cycle", rules.NextCycle({ SizePotential = 0 }, 2000, 0.5) == nil)

print("GroveGrowthRules smoke checks passed")
return true
