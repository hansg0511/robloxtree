-- Roblox Studio SERVER Command Bar. Legacy deadlines and species growth pacing.
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
check("new minimum is half potential", rules.RollSize(3,0)==1.5)
check("midpoint draw slightly favors upper sizes", rules.RollSize(2,0.5)>1.5 and rules.RollSize(2,0.5)<1.55)
check("minimum supported sapling remains valid", rules.RollSize(0.1,0)==0.05)
check("new small size survives normalization", rules.NormalizeCurrentSize(0.05,0.1)==0.05)
check("reject invalid gene", rules.RollSize(7.001, 0.5) == nil)
check("Giant perfect potential grows up to 7x",rules.RollSize(7,0.995)==7)
check("Giant nonjackpot cannot round to 7x",rules.RollSize(7,0.994999)<7)
check("perfect sapling has exact perfect growth outcome", rules.RollSize(5,0.995)==5)
check("nonjackpot cannot round up to perfect", rules.RollSize(5,0.994999)<5)
check("minimum of perfect sapling", rules.RollSize(5,0)==2.5)
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
for _,spec in ipairs({{"Sapwood",90},{"Bamboo",120},{"Oak",180},{"Ironwood",240}}) do
	local species,duration=spec[1],spec[2]
	check("species initial growth "..species,rules.DurationForSize(1,species)==duration)
	check("species large growth "..species,rules.DurationForSize(5,species)==duration)
	local cycle=rules.NextCycle({SpeciesId=species,SizePotential=1,HarvestCount=1},2000,0.5)
	check("species regrowth equals initial "..species,cycle and cycle.MaturesAt==2000+duration)
	check("species deadline authoritative "..species,rules.Stage(cycle,2000+duration-1)~="mature" and rules.Stage(cycle,2000+duration)=="mature")
end
check("unknown species fails closed",rules.DurationForSize(1,"Unknown")==nil)

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
local Quality=require(game.ServerScriptService.Grove.SaplingQualityRules)
check("legacy giant size supported", rules.RollSize(4.9,1)==4.9)
local function jackpotRng(draw)
	return {NextInteger=function(_,lo,hi) return if hi==10000 then draw else 1000 end,NextNumber=function(_,lo,hi) return hi end}
end
check("ordinary jackpot exact 5x",Quality.Wild({},jackpotRng(1))==5)
check("ordinary jackpot boundary",Quality.Wild({},jackpotRng(2))==3.5)
check("Giant jackpot exact 7x",Quality.Wild({Giant=true},jackpotRng(4))==7)
check("Giant jackpot boundary",Quality.Wild({Giant=true},jackpotRng(5))==4.9)
check("Giant transform exceeds 5x",Quality.WithMutation(3.6,{Giant=true})==5.04)
check("Giant transform reaches 7x",Quality.WithMutation(5,{Giant=true})==7)
check("non-Giant transform cannot round up to perfect",Quality.WithMutation(5,{})<5)
for _, draw in ipairs({1,850,851,970,971,997,998,1000}) do
	local rng={NextInteger=function(_,lo,hi) return if hi==10000 then 10000 else draw end,NextNumber=function(_,lo,hi) return hi end}
	local expected=if draw<=850 then 1.1 elseif draw<=970 then 1.5 elseif draw<=997 then 2.5 else 3.5
	check("wild size band boundary",Quality.Wild({},rng)==expected)
	check("Giant uses same band with multiplier",math.abs(Quality.Wild({Giant=true},rng)-expected*1.4)<0.001)
end
for _,spec in ipairs({{"Bamboo",850,970},{"Oak",800,950},{"Ironwood",750,930}}) do
	local species,first,second=spec[1],spec[2],spec[3]
	for _,draw in ipairs({1,first,first+1,second,second+1,997,998,1000}) do
		local rng={NextInteger=function(_,lo,hi) return if hi==10000 then 10000 else draw end,NextNumber=function(_,lo,hi) return hi end}
		local expected=if draw<=first then 1.1 elseif draw<=second then 1.5 elseif draw<=997 then 2.5 else 3.5
		check("species band boundary "..species,Quality.Wild({},rng,species)==expected)
	end
end
for step=0,24 do
	local t=now+step*Shop.RESTOCK_SECONDS
	local offers=Shop.Offers(t)
	local duplicate=Shop.Offers(t)
	check("ordinary catalogue never disappears",#offers.Offers>=3)
	for i,offer in ipairs(offers.Offers) do
		local same=duplicate.Offers[i]
		check("global stock and quality deterministic",offer.Id==same.Id and offer.Stock==same.Stock and offer.SizePotential==same.SizePotential)
		check("numeric stock",type(offer.Stock)=="number" and offer.Stock>=0 and offer.Stock%1==0)
		if offer.Rare then check("rare listed only if available",offer.Stock>=1 and offer.Stock<=2 and offer.SizePotential<=2.1) end
		local own={Cycle=offers.Cycle,Purchased={[offer.Id]=offer.Stock}}
		check("sold out quota persists",Shop.Remaining(own,offers.Cycle,offer)==0)
		check("another player gets independent stock",Shop.Remaining({},offers.Cycle,offer)==offer.Stock)
		check("restock resets quota",Shop.Remaining(own,offers.Cycle+1,offer)==offer.Stock)
	end
end
check("shop rejects spoofed offer ids",Shop.Find(first,"made-up")==nil)
check("rare wild trees are genuinely rare",
	next(Search.RollWildTreeMutations(0.5,0))==nil)
check("discovery mutation originates on wild spawn",
	Search.RollWildTreeMutations(0,0).Golden==true
	and Search.RollWildTreeMutations(0,0.99).Shocked==true)
check("Giant and other types remain eligible",
	Search.RollWildTreeMutations(0,0.32).Giant==true)

-- Wild-tree harvests must preserve the same mutation shown on the
-- tree, regardless of the separate RNG roll for discovering its sapling.
-- CaptureTreeLogAward is also used for the normal multi-log award path.
local LogService=require(game.ServerScriptService.Inventory.LogService)
local wildTree={
	YieldsLog=true,SpeciesId="Oak",DefinitionId="StarterForestTree",
	SizeScale=1,CFrame=CFrame.new(1,2,3),LogYield=2,
	Mutations={Golden=true},
}
local goldenWild=LogService.CaptureTreeLogAward(wildTree,{},CFrame.new())
check("wild Golden tree preserves its mutation in the log award",
	goldenWild and goldenWild.Mutations.Golden==true
	and goldenWild.LogYield==2 and goldenWild.SpeciesId=="Oak")
wildTree.Mutations.Golden=nil
check("log award owns a detached copy of source mutation",
	goldenWild.Mutations.Golden==true)
for _,family in ipairs({"Frenzied","Shocked","Giant"}) do
	wildTree.Mutations={[family]=true}
	local capture=LogService.CaptureTreeLogAward(wildTree,{},CFrame.new())
	check("wild tree log inherits "..family,
		capture and capture.Mutations[family]==true)
end
wildTree.Mutations={}
local ordinaryWild=LogService.CaptureTreeLogAward(wildTree,{},CFrame.new())
check("ordinary wild tree still grants ordinary logs",
	ordinaryWild and next(ordinaryWild.Mutations)==nil)

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

-- Quest vertical slice: extend the existing Grove suite rather than
-- creating a new runner. These are pure, safe fake profiles.
local QuestRules=require(game.ServerScriptService.Quests.QuestRules)
check("daily/weekly tasks coexist with Story",
	QuestRules.Categories.Daily=="Daily" and QuestRules.Categories.Weekly=="Weekly"
	and QuestRules.Story[1].Category=="Story"
	and #QuestRules.Recurring.Daily==2 and #QuestRules.Recurring.Weekly==2)
local fresh=QuestRules.Normalize(nil)
check("legacy profile begins at first quest",fresh.Stage==1 and fresh.Count==0)
local ignored,changed=QuestRules.Advance(fresh,"GroveHarvested",1)
check("wrong event cannot advance story",not changed and ignored.Count==0)
local partial,didProgress=QuestRules.Advance(fresh,"WildTreeChopped",2)
check("valid wild death advances first objective",
	didProgress and partial.Stage==1 and partial.Count==2)
local complete=QuestRules.Advance(partial,"WildTreeChopped",1)
check("three wild chops complete but do not auto-claim",
	QuestRules.Ready(complete) and complete.Stage==1)
local overCap=QuestRules.Advance(complete,"WildTreeChopped",1)
check("duplicate/extra kills cannot overcount",overCap.Count==3)
check("invalid event amounts cannot grant arbitrary progress",
	not select(2,QuestRules.Advance(fresh,"WildTreeChopped",999))
		and not select(2,QuestRules.Advance(fresh,"WildTreeChopped",-1)))
local stage2=QuestRules.NextAfterClaim(complete)
check("claim advances to Grove harvest objective exactly once",
	stage2.Stage==2 and stage2.Count==0
	and QuestRules.NextAfterClaim(stage2)==nil)
local wrongGrove=QuestRules.Advance(stage2,"WildTreeChopped",1)
check("wild chopping does not satisfy Grove harvest",
	wrongGrove.Count==0)
local groveDone=QuestRules.Advance(stage2,"GroveHarvested",1)
local finished=QuestRules.NextAfterClaim(groveDone)
check("Grove stage completes once and ends story",
	finished and finished.Stage==QuestRules.CompleteStage
	and not QuestRules.Ready(finished)
	and QuestRules.NextAfterClaim(finished)==nil)
check("stage 1/2 rewards defined as saplings, no currency invented",
	QuestRules.Story[1].Reward.Kind=="Sapling"
	and QuestRules.Story[2].Reward.Kind=="Sapling"
	and QuestRules.Story[2].Reward.Mutations.Golden==true)
local fakeData={QuestProgress={Stage=math.huge,Count=-50}}
check("quest normalization repairs invalid profile values",
	Cache.NormalizeQuestProgress(fakeData)
	and fakeData.QuestProgress.Stage==1
	and fakeData.QuestProgress.Count==0)
check("completed quest persists through normalization",
	Cache.NormalizeQuestProgress({QuestProgress=finished}))

-- Recurring quests: the same verified event advances both active windows,
-- while Story still requires a separate explicit reward claim.
-- A Monday 00:00 UTC is Unix 345600 (1970-01-05).
local monday=345600
local prevDaily,prevDailyAt=QuestRules.Window("Daily",monday-1)
local newDaily,newDailyAt=QuestRules.Window("Daily",monday)
local prevWeekly,prevWeeklyAt=QuestRules.Window("Weekly",monday-1)
local newWeekly,newWeeklyAt=QuestRules.Window("Weekly",monday)
check("daily UTC midnight boundary",prevDailyAt==monday
	and newDaily==prevDaily+1 and newDailyAt==monday+86400)
check("weekly Monday UTC boundary",prevWeeklyAt==monday
	and newWeekly==prevWeekly+1 and newWeeklyAt==monday+604800)
check("invalid window timestamp rejected",QuestRules.Window("Daily",-1)==nil)

local freshRecurring,wasCreated=QuestRules.NormalizeRecurring(nil,monday)
check("legacy save receives both current windows",wasCreated
	and freshRecurring.Daily.WindowId==newDaily
	and freshRecurring.Weekly.WindowId==newWeekly)
local both,changedBoth,creditedBoth=QuestRules.AdvanceRecurring(freshRecurring,
	"WildTreeChopped",monday)
check("one kill advances both task categories",changedBoth and creditedBoth
	and both.Daily.Counts.daily_wild_chops==1
	and both.Weekly.Counts.weekly_wild_chops==1
	and both.Daily.Counts.daily_grove_harvest==0)
local harvested,changedHarvest=QuestRules.AdvanceRecurring(both,"GroveHarvested",monday)
check("one Grove harvest advances both windows",changedHarvest
	and harvested.Daily.Counts.daily_grove_harvest==1
	and harvested.Weekly.Counts.weekly_grove_harvest==1)
local unchanged,changedInvalid=QuestRules.AdvanceRecurring(harvested,"ClientFakeEvent",monday)
check("invalid event cannot grant progress",not changedInvalid
	and unchanged.Weekly.Counts.weekly_wild_chops==1)
local capped=unchanged
for _=1,40 do capped=QuestRules.AdvanceRecurring(capped,"WildTreeChopped",monday) end
check("concurrent tasks cap independently",
	capped.Daily.Counts.daily_wild_chops==5
	and capped.Weekly.Counts.weekly_wild_chops==25)
local secondDay,resetDay=QuestRules.NormalizeRecurring(capped,monday+86400)
check("daily resets but weekly remains",resetDay
	and secondDay.Daily.Counts.daily_wild_chops==0
	and secondDay.Weekly.Counts.weekly_wild_chops==25)
local nextWeek,resetWeek=QuestRules.NormalizeRecurring(secondDay,monday+604800)
check("weekly resets on Monday",resetWeek
	and nextWeek.Weekly.Counts.weekly_wild_chops==0)
local invalidRaw={
	Daily={WindowId=newDaily,Counts={daily_wild_chops=math.huge,garbage=999}},
	Weekly={WindowId=newWeekly+5000,Counts={weekly_wild_chops=25}},
}
local repaired,repairChanged=QuestRules.NormalizeRecurring(invalidRaw,monday)
check("bad values, stale/implausible future windows and old tasks reset",
	repairChanged and repaired.Daily.Counts.daily_wild_chops==0
	and repaired.Daily.Counts.garbage==nil
	and repaired.Weekly.Counts.weekly_wild_chops==0)
local snapshot=QuestRules.RecurringSnapshot(both,"Daily",monday)
check("client projection has deadlines, counts and no pending fake rewards",
	snapshot.ResetAt==monday+86400 and #snapshot.Tasks==2
	and snapshot.Tasks[1].Count==1 and snapshot.RewardsConfigured==true
	and snapshot.Tasks[1].Reward>0)
local token="daily_wild_chops:"..tostring(newDaily)
check("incomplete reward not claimable",QuestRules.ClaimRecurring(both,token,monday)==nil)
local claimed,amount=QuestRules.ClaimRecurring(capped,token,monday)
check("completed recurring task grants configured reward",claimed and amount>0 and claimed.Daily.Claimed.daily_wild_chops==true)
check("duplicate claim rejected",QuestRules.ClaimRecurring(claimed,token,monday)==nil)
local reloaded=QuestRules.NormalizeRecurring(claimed,monday)
check("claim persists after normalization",QuestRules.ClaimRecurring(reloaded,token,monday)==nil)
check("old token rejected at next reset",QuestRules.ClaimRecurring(reloaded,token,monday+86400)==nil)
local oldSave={QuestProgress=finished}
check("legacy save gains recurring without touching completed Story",
	Cache.NormalizeRecurringQuestProgress(oldSave)
	and oldSave.QuestProgress.Stage==QuestRules.CompleteStage
	and oldSave.QuestRecurring.Daily~=nil)

-- Leaderboard record counters are source-backed by the same verified wild
-- tree deaths as the quest progress (no client-submitted damage or claims).
local ChopRules=require(game.ServerScriptService.ChopLeaderboardRules)
local empty,initiallyMigrated=ChopRules.Normalize(nil,monday)
check("legacy leaderboard migrates without fake chop history",
	initiallyMigrated and empty.Lifetime==0 and empty.WeeklyCount==0
	and empty.WeeklyWindowId==newWeekly)
local chopOnce=ChopRules.Record(empty,monday)
local chopTwice=ChopRules.Record(chopOnce,monday+1)
check("lifetime and weekly count confirmed deaths",
	chopTwice.Lifetime==2 and chopTwice.WeeklyCount==2)
check("recording is pure, no mutation of persisted input",
	empty.Lifetime==0 and empty.WeeklyCount==0)
local rollover,changedWindow=ChopRules.Normalize(chopTwice,monday+604800)
check("weekly leaderboard resets Monday, lifetime persists",
	changedWindow and rollover.Lifetime==2 and rollover.WeeklyCount==0
	and rollover.WeeklyWindowId==newWeekly+1)
local firstNextWeek=ChopRules.Record(chopTwice,monday+604800)
check("new week begins at one and lifetime continues",
	firstNextWeek.Lifetime==3 and firstNextWeek.WeeklyCount==1)
local bad=ChopRules.Normalize({
	Lifetime=-100,WeeklyWindowId=newWeekly,WeeklyCount=math.huge,
},monday)
check("invalid leaderboard counters cannot inflate progress",
	bad.Lifetime==0 and bad.WeeklyCount==0)
local oldCount=ChopRules.Normalize({
	Lifetime=7,WeeklyWindowId=newWeekly+15,WeeklyCount=100,
},monday)
check("future weekly window does not credit current week",
	oldCount.Lifetime==7 and oldCount.WeeklyCount==0)
local cap=ChopRules.Record({
	Lifetime=ChopRules.MAX_COUNT,WeeklyWindowId=newWeekly,
	WeeklyCount=ChopRules.MAX_COUNT,
},monday)
check("long-running leaderboard counters saturate safely",
	cap.Lifetime==ChopRules.MAX_COUNT
	and cap.WeeklyCount==ChopRules.MAX_COUNT)
local migratedProfile={QuestProgress=finished}
check("profile normalization doesn't affect existing Story data",
	Cache.NormalizeChopLeaderboard(migratedProfile)
	and migratedProfile.ChopLeaderboard.WeeklyCount==0
	and migratedProfile.QuestProgress.Stage==QuestRules.CompleteStage)

print("Grove, Story, recurring quests and basic chop leaderboard rules passed")
return true
