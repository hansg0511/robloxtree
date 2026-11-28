-- Pure save-safe Main Quest and recurring quest rules.
-- All time/window calculations use server-supplied Unix seconds (UTC).
local Rules={}
local Premium=require(game.ReplicatedStorage.Shared.PremiumEconomyConfig)
Rules.Categories={Story="Story",Daily="Daily",Weekly="Weekly"}
Rules.Story={
	{
		Id="first_chops",Category=Rules.Categories.Story,Title="First Steps",
		Description="Chop 3 wild trees to earn an Oak sapling.",
		Event="WildTreeChopped",Target=3,
		Reward={Kind="Sapling",SpeciesId="Oak",Mutations={},SizePotential=0.8,Label="Oak Sapling"},
	},
	{
		Id="first_harvest",Category=Rules.Categories.Story,Title="The Grove's First Harvest",
		Description="Harvest 1 fully grown tree from your personal Grove.",
		Event="GroveHarvested",Target=1,
		Reward={Kind="Sapling",SpeciesId="Oak",Mutations={Golden=true},SizePotential=0.8,Label="Golden Oak Sapling"},
	},
}
Rules.CompleteStage=#Rules.Story+1

-- Provisional TASK COUNTS only, not reward rates or economy commitments.
-- Concurrent tasks are intentionally independent of Story and one another.
Rules.Recurring={
	Daily={
		{Id="daily_wild_chops",Title="Daily Lumberjack",Description="Chop 5 wild trees.",Event="WildTreeChopped",Target=5},
		{Id="daily_grove_harvest",Title="Grove Care",Description="Harvest 1 mature Grove tree.",Event="GroveHarvested",Target=1},
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

function Rules.Normalize(raw)
	local stage=type(raw)=="table" and raw.Stage or nil
	if type(stage)~="number" or stage%1~=0 or stage<1
		or stage>Rules.CompleteStage then stage=1 end
	local definition=Rules.Story[stage]
	local count=type(raw)=="table" and raw.Count or nil
	if type(count)~="number" or count%1~=0 or count<0
		or (definition and count>definition.Target)
		or (not definition and count~=0) then count=0 end
	return {Stage=stage,Count=count}
end

function Rules.Advance(raw,event,amount)
	local progress=Rules.Normalize(raw)
	local definition=Rules.Story[progress.Stage]
	if not definition or type(event)~="string"
		or event~=definition.Event then return progress,false end
	if type(amount)~="number" or amount%1~=0 or amount<=0 or amount>100 then
		return progress,false
	end
	local nextCount=math.min(definition.Target,progress.Count+amount)
	local changed=nextCount~=progress.Count
	progress.Count=nextCount
	return progress,changed
end

function Rules.Ready(raw)
	local p=Rules.Normalize(raw)
	local definition=Rules.Story[p.Stage]
	return definition~=nil and p.Count==definition.Target
end

function Rules.NextAfterClaim(raw)
	local p=Rules.Normalize(raw)
	if not Rules.Ready(p) then return nil end
	return {Stage=p.Stage+1,Count=0}
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
