-- Pure save-safe Main Quest and recurring quest rules.
-- All time/window calculations use server-supplied Unix seconds (UTC).
local Rules={}
local Premium=require(game.ReplicatedStorage.Shared.PremiumEconomyConfig)
Rules.Categories={Story="Story",Daily="Daily",Weekly="Weekly"}
local Config=require(game.ReplicatedStorage.Shared.ProgressionConfig)
local function coins(amount) return {Kind="Coins",Amount=amount,Label=tostring(amount).." Coins"} end
local function objective(id,title,description,metric,target,reward)
	return {Id=id,Category=Rules.Categories.Story,Title=title,Description=description,Metric=metric,Target=target,Reward=reward}
end
Rules.Story={
	objective("first_chops","First Steps","Chop 3 wild trees to earn an Oak sapling.","Chops",3,{Kind="Sapling",SpeciesId="Oak",Mutations={},SizePotential=0.8,Label="Oak Sapling"}),
	objective("first_sale","First Sale","Collect logs and sell them at the lumber depot.","LogsSold",1,coins(10)),
	objective("first_head","Ready to Forge","Purchase a Copper head from the head shop.","CopperHead",1,coins(5)),
	objective("first_craft","Your First Weapon","Forge a weapon using a head and logs.","Crafts",1,coins(15)),
	objective("first_equip","Gear Up","Equip a weapon you own.","Equipped",1,coins(10)),
	objective("weapon_level_3","Getting Stronger","Reach weapon level 3.","WeaponLevel",3,coins(20)),
	objective("first_plant","Plant Your Grove","Plant a sapling in your personal Grove.","Plant",1,coins(15)),
	objective("first_harvest","The Grove's First Harvest","Harvest a fully grown tree from your personal Grove.","Harvests",1,{Kind="Sapling",SpeciesId="Oak",Mutations={Golden=true},SizePotential=0.8,Label="Golden Oak Sapling"}),
	objective("guardian_1","Beyond the First Forest","Defeat the Forest 1 Guardian to unlock Forest 2.","Forest2",1,coins(75)),
	objective("forge_level_2","Upgrade the Forge","Upgrade your Forge to level 2.","ForgeLevel",2,coins(50)),
	objective("chop_100","Lumberjack","Chop 100 wild trees in total.","Chops",100,coins(100)),
	objective("forge_level_3","Better Possibilities","Upgrade your Forge to level 3 to unlock Uncommon rarity.","ForgeLevel",3,coins(100)),
	objective("uncommon_craft","A Better Blade","Forge an Uncommon or higher rarity weapon.","ForgedRarity",2,coins(125)),
	objective("guardian_2","Into the Oak Forest","Defeat the Forest 2 Guardian to unlock Forest 3.","Forest3",1,coins(200)),
	objective("iron_craft","The Iron Age","Forge a weapon using an Iron head.","MetalTier",2,coins(150)),
	objective("forge_level_5","Forge Development","Reach Forge level 5.","ForgeLevel",5,coins(200)),
	objective("weapon_level_10","Ready for Ascension","Reach weapon level 10. Claim crystals to try ascension at the Forge.","WeaponLevel",10,{Kind="Crystals",Amount=2,Label="2 Ascension Crystals"}),
	objective("first_ascension","Ascend a Weapon","At its level cap, successfully ascend a weapon at the Forge.","Ascensions",1,coins(250)),
}
Rules.CompleteStage=#Rules.Story+1
Rules.MAIN_VERSION=2

-- Provisional TASK COUNTS only, not reward rates or economy commitments.
-- Concurrent tasks are intentionally independent of Story and one another.
Rules.Recurring={
	Daily={
		{Id="daily_wild_chops",Title="Daily Lumberjack",Description="Chop 150 wild trees.",Event="WildTreeChopped",Target=150},
		{Id="daily_grove_harvest",Title="Grove Care",Description="Harvest 6 mature Grove trees.",Event="GroveHarvested",Target=6},
	},
	Weekly={
		{Id="weekly_wild_chops",Title="Weekly Lumberjack",Description="Complete Daily Lumberjack on 7 different days this week.",DailyTaskId="daily_wild_chops",Target=7},
		{Id="weekly_grove_harvest",Title="Weekly Grove Keeper",Description="Complete Grove Care on 7 different days this week.",DailyTaskId="daily_grove_harvest",Target=7},
	},
}
Rules.DAILY_SECONDS=86400
Rules.WEEKLY_SECONDS=604800
-- 1970-01-01 was Thursday. Adding three days anchors 0 to Monday.
local WEEK_ALIGNMENT=3*Rules.DAILY_SECONDS
local recurringCategories={Rules.Categories.Daily,Rules.Categories.Weekly}

local function nonnegativeInteger(value)
	return type(value)=="number" and value==value and value<math.huge
		and value>=0 and value%1==0
end

-- Preserve rewards and partial progress from the original two-stage quest.
local function skipLegacyHarvest(p)
	if p.LegacyHarvestClaimed and Rules.Story[p.Stage] and Rules.Story[p.Stage].Id=="first_harvest" then
		p.Stage+=1
		p.Count=0
	end
	return p
end
function Rules.Normalize(raw)
	local input=type(raw)=="table" and raw or {}
	local stage=nonnegativeInteger(input.Stage) and input.Stage or 1
	local count=nonnegativeInteger(input.Count) and input.Count or 0
	local legacyClaimed=input.LegacyHarvestClaimed==true
	local legacyReady=input.LegacyHarvestReady==true
	if input.Version~=Rules.MAIN_VERSION then
		legacyClaimed=stage==3
		legacyReady=stage==2 and count>=1
		stage=if stage==2 or stage==3 then 2 else 1
		count=if stage==1 then math.min(count,3) else 0
	end
	if stage<1 or stage>Rules.CompleteStage then stage=1 count=0 end
	local def=Rules.Story[stage]
	return skipLegacyHarvest({Version=Rules.MAIN_VERSION,Stage=stage,Count=if def then math.min(count,def.Target) else 0,LegacyHarvestClaimed=legacyClaimed,LegacyHarvestReady=legacyReady})
end

function Rules.Evaluate(raw,data)
	local p=Rules.Normalize(raw)
	local def=Rules.Story[p.Stage]
	if not def or type(data)~="table" then return p end
	local s=type(data.LifetimeStats)=="table" and data.LifetimeStats or {}
	local run=type(data.RunProgress)=="table" and data.RunProgress or {}
	local leaderboard=type(data.ChopLeaderboard)=="table" and data.ChopLeaderboard or {}
	local forests=type(run.UnlockedForests)=="table" and run.UnlockedForests or {}
	local heads=type(data.AxeHeads)=="table" and data.AxeHeads or {}
	local rarity=Config.ById[s.HighestRarityForged]
	local metal=tonumber(run.StandardAxeTier) or 0
	local crafted=math.max(tonumber(s.WeaponsForged) or 0,if metal>=1 then 1 else 0)
	local level=tonumber(s.HighestWeaponLevel) or 0
	for _,item in ipairs(type(data.Inventory)=="table" and data.Inventory or {}) do
		local wd=type(item)=="table" and item.WeaponData or nil
		if type(wd)=="table" and type(wd.RecipeId)=="string" and item.ItemID~=9001 then
			local progress=wd.Progression
			if type(progress)=="table" then level=math.max(level,tonumber(progress.Level) or 1) end
		end
	end
	local equipped=type(data.Equipped)=="table" and data.Equipped.Weapon or nil
	local groveCount=type(data.GroveTrees)=="table" and #data.GroveTrees or 0
	local values={
		Chops=tonumber(leaderboard.Lifetime) or 0,
		LogsSold=math.max(tonumber(s.LogsSold) or 0,if crafted>0 then 1 else 0),
		CopperHead=math.max(tonumber(s.CopperHeadsPurchased) or 0,tonumber(heads.copper_head) or 0,if crafted>0 then 1 else 0),
		Crafts=crafted,
		Equipped=if type(equipped)=="string" and #equipped>0 then 1 else 0,
		WeaponLevel=level,
		Plant=math.max(tonumber(s.SaplingsPlanted) or 0,groveCount,tonumber(s.GroveHarvests) or 0,if p.LegacyHarvestClaimed or p.LegacyHarvestReady then 1 else 0),
		Harvests=math.max(tonumber(s.GroveHarvests) or 0,if p.LegacyHarvestReady then 1 else 0),
		Forest2=if forests.Forest2 then 1 else 0,
		Forest3=if forests.Forest3 then 1 else 0,
		ForgeLevel=tonumber(run.ForgeLevel) or 1,
		ForgedRarity=if rarity then rarity.Index else 0,
		MetalTier=metal,
		Ascensions=tonumber(s.SuccessfulAscensions) or 0,
	}
	p.Count=math.max(p.Count,math.min(def.Target,math.floor(values[def.Metric] or 0)))
	return p
end

function Rules.Advance(raw,event,amount)
	local p=Rules.Normalize(raw)
	local def=Rules.Story[p.Stage]
	local matching=def and ((def.Id=="first_chops" and event=="WildTreeChopped") or (def.Id=="first_harvest" and event=="GroveHarvested"))
	if not matching or not nonnegativeInteger(amount) or amount<1 or amount>100 then return p,false end
	local before=p.Count
	p.Count=math.min(def.Target,p.Count+amount)
	return p,p.Count~=before
end
function Rules.Ready(raw)
	local p=Rules.Normalize(raw)
	local def=Rules.Story[p.Stage]
	return def~=nil and p.Count==def.Target
end
function Rules.NextAfterClaim(raw)
	local p=Rules.Normalize(raw)
	if not Rules.Ready(p) then return nil end
	p.Stage+=1
	p.Count=0
	return skipLegacyHarvest(p)
end

-- Returns a monotonically increasing ID and the exact next reset timestamp.
-- Daily boundary is 00:00 UTC; weekly boundary is Monday 00:00 UTC.
function Rules.Window(category,now)
	if not nonnegativeInteger(now) then return nil,nil end
	if category==Rules.Categories.Daily then
		local id=math.floor(now/Rules.DAILY_SECONDS)
		return id,(id+1)*Rules.DAILY_SECONDS
	elseif category==Rules.Categories.Weekly then
		local id=math.floor((now+WEEK_ALIGNMENT)/Rules.WEEKLY_SECONDS)
		return id,(id+1)*Rules.WEEKLY_SECONDS-WEEK_ALIGNMENT
	end
	return nil,nil
end

-- Weekly counts are derived from unique completed UTC daily windows.
-- Existing claim IDs stay stable to prevent double payment across migration.
local function creditDailyCompletions(progress)
	local daily,weekly=progress.Daily,progress.Weekly
	local changed=false
	for _,definition in ipairs(Rules.Recurring.Weekly) do
		for _,task in ipairs(Rules.Recurring.Daily) do
			if task.Id==definition.DailyTaskId and daily.Counts[task.Id]>=task.Target
				and weekly.Counts[definition.Id]<definition.Target
				and (weekly.LastDailyWindowId[definition.Id] or -math.huge)<daily.WindowId then
				weekly.LastDailyWindowId[definition.Id]=daily.WindowId
				weekly.Counts[definition.Id]+=1
				changed=true
			end
		end
	end
	return changed
end

-- Save shape: Daily={WindowId,Counts,Claimed};
-- Weekly={WindowId,Counts,Claimed,LastDailyWindowId}.
-- Only current known IDs and integer counts within each target are retained.
-- A stale/future/invalid window is replaced rather than carrying old credit.
function Rules.NormalizeRecurring(raw,now)
	local clean={}
	local changed=type(raw)~="table"
	for _,category in ipairs(recurringCategories) do
		local id=Rules.Window(category,now)
		if id==nil then return nil,false end
		local source=type(raw)=="table" and raw[category] or nil
		local counts=type(source)=="table" and source.Counts or nil
		local current=type(source)=="table" and source.WindowId==id
			and type(counts)=="table"
		local normalizedCounts={}
		local claimed={}
		local lastDays={}
		local previousClaims=if current and type(source.Claimed)=="table" then source.Claimed else {}
		if not current then changed=true end
		local allowed={}
		for _,definition in ipairs(Rules.Recurring[category]) do
			allowed[definition.Id]=true
			local count=current and counts[definition.Id] or nil
			if not nonnegativeInteger(count) or count>definition.Target then
				if count~=nil then changed=true end
				count=0
			end
			if previousClaims[definition.Id]==true then claimed[definition.Id]=true end
			if category==Rules.Categories.Daily and claimed[definition.Id] then count=definition.Target end
			if category==Rules.Categories.Weekly then
				local last=current and type(source.LastDailyWindowId)=="table" and source.LastDailyWindowId[definition.Id] or nil
				local firstDay=id*7-3
				local today=Rules.Window(Rules.Categories.Daily,now)
				local validLast=nonnegativeInteger(last) and last>=firstDay and last<=today
				-- Legacy raw-chop counts are not evidence of distinct completed days.
				local corrected=if claimed[definition.Id] then definition.Target
					elseif validLast then math.min(count,last-firstDay+1) else 0
				if corrected~=count or (last~=nil and not validLast) then changed=true end
				count=corrected
				if validLast then lastDays[definition.Id]=last end
			end
			normalizedCounts[definition.Id]=count
		end
		if current then
			for key in pairs(counts) do
				if not allowed[key] then changed=true end
			end
		end
		clean[category]={WindowId=id,Counts=normalizedCounts,Claimed=claimed}
		if category==Rules.Categories.Weekly then clean[category].LastDailyWindowId=lastDays end
	end
	if creditDailyCompletions(clean) then changed=true end
	return clean,changed
end

-- One *verified* server event credits every matching task, once per callback.
-- Returns (new save, any change including rollover, credited progress).
function Rules.AdvanceRecurring(raw,event,now)
	local nextProgress,changed=Rules.NormalizeRecurring(raw,now)
	if not nextProgress then return nil,false,false end
	local credited=false
	if type(event)~="string" then return nextProgress,changed,false end
	local counts=nextProgress.Daily.Counts
	for _,definition in ipairs(Rules.Recurring.Daily) do
		if definition.Event==event and counts[definition.Id]<definition.Target then
			counts[definition.Id]+=1
			credited=true
		end
	end
	if creditDailyCompletions(nextProgress) then credited=true end
	return nextProgress,changed or credited,credited
end

function Rules.RecurringSnapshot(progress,category,now)
	local id,resetAt=Rules.Window(category,now)
	if id==nil or not Rules.Recurring[category] then return nil end
	local period=type(progress)=="table" and progress[category] or nil
	local counts=type(period)=="table" and type(period.Counts)=="table"
		and period.Counts or {}
	local tasks={}
	for _,definition in ipairs(Rules.Recurring[category]) do
		local count=math.clamp(tonumber(counts[definition.Id]) or 0,0,definition.Target)
		tasks[#tasks+1]={
			Id=definition.Id,Title=definition.Title,Description=definition.Description,
			Count=count,Target=definition.Target,Completed=count>=definition.Target,
			Claimed=period and period.Claimed and period.Claimed[definition.Id]==true or false,
			ClaimId=definition.Id..":"..tostring(id),Reward=Premium.QUEST_REWARDS[definition.Id],
		}
	end
	return {WindowId=id,ResetAt=resetAt,Tasks=tasks,RewardsConfigured=true}
end

-- Exact current-window claim token; stale claims cannot claim new tasks.
function Rules.ClaimRecurring(raw,claimId,now)
	local normalized=Rules.NormalizeRecurring(raw,now)
	if not normalized then return nil,"INVALID_QUEST" end
	for _,category in ipairs(recurringCategories) do
		local period=normalized[category]
		for _,definition in ipairs(Rules.Recurring[category]) do
			if claimId==definition.Id..":"..tostring(period.WindowId) then
				if period.Claimed[definition.Id] then return nil,"ALREADY_CLAIMED" end
				if period.Counts[definition.Id]<definition.Target then return nil,"NOT_COMPLETE" end
				local reward=Premium.QUEST_REWARDS[definition.Id]
				if not nonnegativeInteger(reward) or reward<1 then return nil,"REWARD_NOT_CONFIGURED" end
				period.Claimed[definition.Id]=true
				return normalized,reward
			end
		end
	end
	return nil,"INVALID_QUEST"
end
return Rules
