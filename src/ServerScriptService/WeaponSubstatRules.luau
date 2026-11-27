-- Ordered permanent base rolls. Never store the derived level-scaled values.
local Config = require(game.ReplicatedStorage.Shared.WeaponSubstatConfig)
local Progression = require(game.ReplicatedStorage.Shared.ProgressionConfig)
local Rules = {}
local function finite(x)
	return type(x)=="number" and x==x and x>=0 and x<math.huge
end
function Rules.SlotCount(rarity)
	return Config.Slots[rarity] or 0
end
local function roll(rng)
	local total=0
	for _, row in ipairs(Config.Stats) do total+=row.Weight end
	local pick=rng:NextNumber(0,total)
	local chosen=Config.Stats[#Config.Stats]
	for _, row in ipairs(Config.Stats) do
		pick-=row.Weight
		if pick<0 then chosen=row; break end
	end
	local precision=Config.RollPrecision
	return {Id=chosen.Id, BaseValue=rng:NextInteger(math.ceil(chosen.Min*precision),math.floor(chosen.Max*precision))/precision}
end
local function read(data, rarity)
	local result={}
	if type(data)~="table" or type(data.PassiveSubstats)~="table" then return result end
	for index=1,Rules.SlotCount(rarity) do
		local slot=data.PassiveSubstats[index]
		if type(slot)=="table" and type(slot.Id)=="string" and Config.ById[slot.Id]
			and finite(slot.BaseValue) and slot.BaseValue>0 and slot.BaseValue<=10000 then
			result[#result+1]={Id=slot.Id,BaseValue=slot.BaseValue}
		end
	end
	return result
end
function Rules.GrantSlots(data,rarity,rng)
	local nextData=table.clone(data)
	local slots=read(data,rarity)
	while #slots<Rules.SlotCount(rarity) do slots[#slots+1]=roll(rng) end
	nextData.PassiveSubstats=slots
	return nextData
end
function Rules.Snapshot(weapon)
	local result={}
	if type(weapon)~="table" then return result end
	local rarity=weapon.ItemRarity or weapon.Rarity
	local data=weapon.WeaponData
	local row=Progression.ById[rarity]
	if not row then return result end
	local progress=type(data)=="table" and data.Progression
	local level=type(progress)=="table" and progress.Level or 1
	level=if finite(level) then math.clamp(math.floor(level),1,row.LevelCap) else 1
	for _, slot in ipairs(read(data,rarity)) do
		local def=Config.ById[slot.Id]
		result[#result+1]={
			Id=slot.Id,Label=def.Label,BaseValue=slot.BaseValue,
			Value=slot.BaseValue*(1+def.Growth*(level-1)),Points=def.Points==true,
		}
	end
	return result
end
function Rules.Totals(weapon)
	local totals={}
	for _, slot in ipairs(Rules.Snapshot(weapon)) do
		local value=if slot.Points then slot.Value else slot.Value/100
		totals[slot.Id]=(totals[slot.Id] or 0)+value
	end
	return totals
end
return Rules
