-- Pure save-safe story and recurring quest rules. No rewards for recurring tasks.
-- All time/window calculations use server-supplied Unix seconds (UTC).
local Rules={}
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
		{Id="weekly_wild_chops",Title="Weekly Forest Clearing",Description="Chop 25 wild trees.",Event="WildTreeChopped",Target=25},
		{Id="weekly_grove_harvest",Title="Weekly Grove Keeper",Description="Harvest 5 mature Grove trees.",Event="GroveHarvested",Target=5},
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

-- Save shape: {Daily={WindowId=int, Counts={taskId=count}}, Weekly=...}.
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
		if not current then changed=true end
		local allowed={}
		for _,definition in ipairs(Rules.Recurring[category]) do
			allowed[definition.Id]=true
			local count=current and counts[definition.Id] or nil
			if not nonnegativeInteger(count) or count>definition.Target then
				if count~=nil then changed=true end
				count=0
			end
			normalizedCounts[definition.Id]=count
		end
		if current then
			for key in pairs(counts) do
				if not allowed[key] then changed=true end
			end
		end
		clean[category]={WindowId=id,Counts=normalizedCounts}
	end
	return clean,changed
end

-- One *verified* server event credits every matching task, once per callback.
-- Returns (new save, any change including rollover, credited progress).
function Rules.AdvanceRecurring(raw,event,now)
	local nextProgress,changed=Rules.NormalizeRecurring(raw,now)
	if not nextProgress then return nil,false,false end
	local credited=false
	if type(event)~="string" then return nextProgress,changed,false end
	for _,category in ipairs(recurringCategories) do
		local counts=nextProgress[category].Counts
		for _,definition in ipairs(Rules.Recurring[category]) do
			if definition.Event==event and counts[definition.Id]<definition.Target then
				counts[definition.Id]+=1
				credited=true
			end
		end
	end
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
		}
	end
	return {WindowId=id,ResetAt=resetAt,Tasks=tasks,RewardsConfigured=false}
end

return Rules
