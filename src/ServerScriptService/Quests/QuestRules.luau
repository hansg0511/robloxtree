-- Pure, save-safe quest progression rules. Only Story runs in this slice.
-- Daily/Weekly are reserved task categories; no reset or premium wallet yet.
local Rules={}
Rules.Categories={Story="Story",Daily="Daily",Weekly="Weekly"}
Rules.Story={
	{
		Id="first_chops",
		Category=Rules.Categories.Story,
		Title="First Steps",
		Description="Chop 3 wild trees to earn an Oak sapling.",
		Event="WildTreeChopped",
		Target=3,
		Reward={
			Kind="Sapling",SpeciesId="Oak",Mutations={},
			SizePotential=1,Label="Oak Sapling",
		},
	},
	{
		Id="first_harvest",
		Category=Rules.Categories.Story,
		Title="The Grove's First Harvest",
		Description="Harvest 1 fully grown tree from your personal Grove.",
		Event="GroveHarvested",
		Target=1,
		Reward={
			Kind="Sapling",SpeciesId="Oak",Mutations={Golden=true},
			SizePotential=1.1,Label="Golden Oak Sapling",
		},
	},
}
Rules.CompleteStage=#Rules.Story+1

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

return Rules
