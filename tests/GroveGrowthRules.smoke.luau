-- Roblox Studio SERVER Command Bar. Fixed 30-second Grove pacing tests.
-- Existing records with different persisted deadlines must remain unchanged.
local rules = require(game.ServerScriptService.Grove.GroveGrowthRules)
local function check(name, ok) assert(ok, name .. " failed") end

check("old size migrates to genetic potential", rules.NormalizeCurrentSize(nil, 1.7) == 1.7)
check("old harvest count migrates to zero", rules.NormalizeHarvestCount(nil) == 0)
check("invalid current size repaired", rules.NormalizeCurrentSize(5, 1.4) == 1.4)
check("bad harvest count repaired", rules.NormalizeHarvestCount(-2) == 0)
check("low RNG within genetic cap", rules.RollSize(1.7, 0) <= 1.7)
check("high RNG equals genetic cap", rules.RollSize(1.7, 1) == 1.7)
check("higher roll bigger size", rules.RollSize(1.5, 0.8) > rules.RollSize(1.5, 0.2))
check("reject invalid gene", rules.RollSize(5, 0.5) == nil)
check("reject invalid roll", rules.RollSize(1, 1.5) == nil)

check("two seconds per interval", rules.SECONDS_PER_VISUAL_STEP == 2)
check("fixed total maturation of 30 seconds", rules.MATURITY_SECONDS == 30)
check("fifteen intervals per growth cycle", rules.TOTAL_CYCLE_STEPS == 15)
for _, size in ipairs({ 0.1, 0.5, 0.7, 1, 1.5, 2, 5 }) do
	check("steps independent of size " .. size, rules.StepsForSize(size) == 15)
	check("duration independent of size " .. size, rules.DurationForSize(size) == 30)
end
check("invalid size rejected", rules.StepsForSize(-1) == nil
	and rules.DurationForSize(-1) == nil)
check("4-second post-harvest stump included in 30-second cycle",
	rules.STUMP_SECONDS == 4 and rules.STUMP_SECONDS < rules.MATURITY_SECONDS)

local planted = 1000
local plantedCycle = { PlantedAt = planted, MaturesAt = 1030, HarvestCount = 0 }
local regrownCycle = { PlantedAt = planted, MaturesAt = 1030, HarvestCount = 1 }

check("initial sapling", rules.Stage(plantedCycle, planted) == "sapling")
check("initial young", rules.Stage(plantedCycle, 1015) == "young")
check("initial mature at 30 seconds", rules.Stage(plantedCycle, 1030) == "mature")
check("regrowth stump through 4-second hold", rules.Stage(regrownCycle, 1003) == "stump")
check("regrowth sapling after stump", rules.Stage(regrownCycle, 1004) == "sapling")
check("regrowth young", rules.Stage(regrownCycle, 1017) == "young")
check("regrowth mature at SAME 30-second deadline",
	rules.Stage(regrownCycle, 1030) == "mature")

local function checkSteps(record, firstTime, expectedTotal)
	for step = 0, expectedTotal do
		local fraction, actual, total = rules.VisualProgress(
			record, firstTime + step * 2)
		check("correct step " .. step, actual == step and total == expectedTotal)
		check("fraction at step " .. step,
			math.abs(fraction - step / expectedTotal) < 0.0001)
	end
	check("no advance before first 2-second boundary",
		select(2, rules.VisualProgress(record, firstTime + 1)) == 0)
	check("mature visual remains complete",
		select(2, rules.VisualProgress(record, 1040)) == expectedTotal)
end

checkSteps(plantedCycle, 1000, 15)
-- Regrowth uses two initial 2-second intervals for the fall/stump, then
-- 13 growth intervals. Both total exactly 15 intervals / 30 seconds.
checkSteps(regrownCycle, 1004, 13)
check("regrowth stays at visual step 0 during falling cinematic",
	select(2, rules.VisualProgress(regrownCycle, 1003)) == 0)

local cycleSmall = rules.NextCycle({ SizePotential = 0.7, HarvestCount = 2 }, 2000, 0.4)
local cycleLarge = rules.NextCycle({ SizePotential = 1.9, HarvestCount = 2 }, 2000, 0.4)
check("both new regrowth cycles valid", cycleSmall and cycleLarge)
check("both sizes mature at EXACTLY the same 30-second deadline",
	cycleSmall.MaturesAt == 2030 and cycleLarge.MaturesAt == 2030)
check("rolled sizes still differ", cycleSmall.CurrentSizeScale < cycleLarge.CurrentSizeScale)
check("lineage isn't modified", cycleSmall.SourceSaplingUID == nil)
check("harvest count increments once", cycleSmall.HarvestCount == 3)
check("invalid cycle rejected", rules.NextCycle({ SizePotential = 0 }, 2000, 0.5) == nil)

-- Legacy persisted cycle deadlines remain authoritative; we do not
-- rewrite or restart a tree that is already partway through growth.
local legacy = { PlantedAt = planted, MaturesAt = 1045, HarvestCount = 1 }
check("legacy deadline still determines growth steps",
	select(3, rules.VisualProgress(legacy, planted)) == math.ceil((45 - 4) / 2))
check("legacy matures only at saved deadline",
	rules.Stage(legacy, 1044) ~= "mature"
		and rules.Stage(legacy, 1045) == "mature")
check("legacy visuals finish at saved deadline",
	select(2, rules.VisualProgress(legacy, 1045))
		== select(3, rules.VisualProgress(legacy, planted)))

-- Phase 4 integration uses this EXISTING smoke suite, not a separate
-- file per Grove source, shop, or material adapter.
check("unapproved extra Grove harvest material rule removed",
	rules.HeartwoodEligible==nil
		and rules.HEARTWOOD_EVERY_HARVESTS==nil
		and rules.MAX_HEARTWOOD_HELD==nil)

local Shop=require(game.ServerScriptService.Grove.SaplingShopRules)
local Search=require(game.ServerScriptService.Grove.SaplingDiscoveryService)
local now=2000000000
local first=Shop.Offers(now)
local again=Shop.Offers(now)
check("shop is deterministic within a restock window",
	first and again and first.Cycle==again.Cycle
	and first.RestockAt==again.RestockAt
	and #first.Offers==#again.Offers)
for i=1,3 do
	check("normal saplings never rotate out",
		first.Offers[i] and first.Offers[i].Id==Shop.COMMON[i].Id
		and first.Offers[i].Rare==false)
end
check("restock deadline is a future window",
	first.RestockAt>now and first.RestockAt<=now+Shop.RESTOCK_SECONDS)
local sawRare=false
local sawNoRare=false
for step=0,24 do
	local offers=Shop.Offers(now+step*Shop.RESTOCK_SECONDS)
	if #offers.Offers==4 then
		sawRare=true
		check("rare shop only adds one offer",offers.Offers[4].Rare==true
			and offers.Offers[4].Stock==1)
	else
		sawNoRare=true
		check("normal stock remains when rare is absent",#offers.Offers==3)
	end
end
check("shop cycles produce occasional rare and absent rare rotations",
	sawRare and sawNoRare)
check("shop rejects spoofed offer ids",Shop.Find(first,"made-up")==nil)
check("rare wild trees are genuinely rare",
	next(Search.RollWildTreeMutations(0.5,0))==nil)
check("discovery mutation originates on wild spawn",
	Search.RollWildTreeMutations(0,0).Golden==true
	and Search.RollWildTreeMutations(0,0.99).Shocked==true)
check("Giant and other types remain eligible",
	Search.RollWildTreeMutations(0,0.32).Giant==true)

-- Preserve existing serialized legacy Grove-material records, if any,
-- without granting NEW materials. Normalization must not delete the tree
-- when a historical record references it.
local Cache=require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local synthetic={
	Saplings={},
	GroveTrees={{
		UID="test-grove-tree",SourceSaplingUID="test-original-sapling",
		SpeciesId="Oak",Mutations={Golden=true},SizePotential=1,
		CurrentSizeScale=1,HarvestCount=3,
		LocalX=0,LocalZ=0,Yaw=0,
		PlantedAt=1000,MaturesAt=1030,
	}},
	GroveMaterials={{
		UID="test-heartwood",MaterialType="Heartwood",
		SpeciesId="Oak",Mutations={Golden=true},SizePotential=1,
		SourceGroveTreeUID="test-grove-tree",
		SourceSaplingUID="test-original-sapling",CreatedAt=1040,
	}},
}
check("Grove normalizer accepts linked records",Cache.NormalizeGroveData(synthetic))
check("existing Grove tree and legacy material survive normalization",
	#synthetic.GroveTrees==1 and #synthetic.GroveMaterials==1
	and synthetic.GroveMaterials[1].SourceGroveTreeUID==synthetic.GroveTrees[1].UID)
check("repeated normalization preserves legacy records",
	Cache.NormalizeGroveData(synthetic) and #synthetic.GroveTrees==1
	and #synthetic.GroveMaterials==1)

print("Grove growth + no extra harvest materials + rare wild inheritance + sapling shop rules passed")
return true
