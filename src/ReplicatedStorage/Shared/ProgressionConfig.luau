-- Authoritative, provisional weapon/Forge balance. Edit tables here; never
-- duplicate rarity gates or probability tables in client/server services.
local C={}
C.MAX_FORGE_LEVEL=200
C.TOTAL_RARITY_WEIGHT=1000000
C.XP={Base=100,PerLevel=25,PerDamage=1,KillPerMaxHP=0.25}
C.LEVEL_POWER_GROWTH=0.01
C.FORGE_COST={FirstUpgrade=2000,Scale=10,Exponent=3.5,Round=50}
-- Rarity rows in increasing order. Stable Ids are persisted.
-- Unlock = maximum rarity gate; RetireBelowAt = level this becomes minimum.
-- AscendChance/Coins/Logs/Pity are costs for leaving this rarity.
C.RARITIES={
	{Id="Common",Unlock=1,RetireBelowAt=1,LevelCap=10,Power=1,Color={200,200,200},AscendChance=0.85,Coins=150,Logs=1},
	{Id="Uncommon",Unlock=3,RetireBelowAt=40,LevelCap=15,Power=1.05,Color={115,210,112},AscendChance=0.70,Coins=300,Logs=1},
	{Id="Rare",Unlock=7,RetireBelowAt=60,LevelCap=20,Power=1.12,Color={80,160,255},AscendChance=0.50,Coins=600,Logs=2},
	{Id="Epic",Unlock=15,RetireBelowAt=85,LevelCap=30,Power=1.25,Color={200,135,255},AscendChance=0.35,Coins=2500,Logs=3},
	{Id="Legendary",Unlock=25,RetireBelowAt=110,LevelCap=45,Power=1.5,Color={255,199,60},AscendChance=0.20,Coins=9000,Logs=4},
	{Id="Mythical",Unlock=40,RetireBelowAt=140,LevelCap=55,Power=1.9,Color={255,100,105},AscendChance=0.12,Coins=20000,Logs=5},
	{Id="Ultra",Unlock=60,RetireBelowAt=200,LevelCap=65,Power=2.5,Color={245,102,198},AscendChance=0.08,Coins=45000,Logs=6},
	{Id="Divine",Unlock=85,LevelCap=80,Power=3.5,Color={255,222,105},AscendChance=0.05,Coins=100000,Logs=7},
	{Id="Celestial",Unlock=110,LevelCap=100,Power=5,Color={89,220,255},AscendChance=0.03,Coins=250000,Logs=8},
	{Id="Eternal",Unlock=140,LevelCap=125,Power=7.5,Color={174,143,255},AscendChance=0.02,Coins=600000,Logs=9},
	{Id="Primordial",Unlock=170,LevelCap=150,Power=12,Color={255,133,91},AscendChance=0.01,Coins=1500000,Logs=10},
	{Id="Transcendent",Unlock=200,LevelCap=200,Power=20,Color={255,239,171}},
}
C.PITY_FACTOR=1.5
C.SECOND_SLOT_RARITY="Legendary"
-- Cumulative probability of at least a rarity as a function of Forge levels
-- since that rarity unlocked. The previous rarity's tail bounds each tail.
-- Floors force retired rarity weights to zero. Integer rounding preserves total.
C.RARITY_TAIL={{0,0.001},{5,0.025},{15,0.15},{30,0.55},{55,0.92},{80,0.98}}
C.POTENCY={{1,0.35},{2,0.70},{50,0.80},{110,0.90},{200,1}}
C.MUTATED_LOG_LIMIT={{1,3},{50,4},{110,5},{200,6}}
C.CLASS_COUNT_OFFSET={{1,0},{2,2},{60,3},{140,4}}
C.ABILITY_POOL_TIER={{1,1},{2,2}}
C.AWAKEN_MIN_FORGE=2
C.Order={}
C.ById={}
local lastUnlock,lastCap,lastPower,lastFloor=0,0,0,0
for i,row in ipairs(C.RARITIES) do
	assert(type(row.Id)=="string" and not C.ById[row.Id],"duplicate rarity")
	assert(row.Unlock%1==0 and row.Unlock>lastUnlock and row.Unlock<=C.MAX_FORGE_LEVEL,"rarity unlock ordering")
	assert(row.LevelCap%1==0 and row.LevelCap>lastCap and row.Power>=lastPower,"rarity power/cap ordering")
	if row.RetireBelowAt then
		assert(row.RetireBelowAt>=row.Unlock and row.RetireBelowAt>lastFloor and row.RetireBelowAt<=C.MAX_FORGE_LEVEL,"rarity floor ordering")
		lastFloor=row.RetireBelowAt
	end
	if i<#C.RARITIES then
		assert(row.AscendChance>0 and row.AscendChance<=1 and row.Coins>0 and row.Logs>0,"invalid ascension")
	end
	row.Index=i
	C.Order[i]=row.Id
	C.ById[row.Id]=row
	lastUnlock,lastCap,lastPower=row.Unlock,row.LevelCap,row.Power
end
assert(C.TOTAL_RARITY_WEIGHT%1==0 and C.TOTAL_RARITY_WEIGHT>=#C.RARITIES,"integer weight domain too small")
assert(C.RARITIES[1].Unlock==1 and C.RARITIES[1].RetireBelowAt==1 and C.ById[C.SECOND_SLOT_RARITY],"missing starting rarity or slot milestone")
local function validateMilestones(rows,low,high)
	local lastX,lastY=-1,-math.huge
	for _,row in ipairs(rows) do
		assert(row[1]>lastX and row[2]>=lastY and row[2]>=low and row[2]<=high,"invalid balance milestone")
		lastX,lastY=row[1],row[2]
	end
end
validateMilestones(C.RARITY_TAIL,0,1)
validateMilestones(C.POTENCY,0,1)
validateMilestones(C.MUTATED_LOG_LIMIT,1,96)
validateMilestones(C.CLASS_COUNT_OFFSET,0,96)
validateMilestones(C.ABILITY_POOL_TIER,1,2)
function C.At(rows,x,interpolate)
	local prev=rows[1]
	for i=2,#rows do
		local nextRow=rows[i]
		if x<nextRow[1] then
			if not interpolate or x<=prev[1] then return prev[2] end
			return prev[2]+(nextRow[2]-prev[2])*(x-prev[1])/(nextRow[1]-prev[1])
		end
		prev=nextRow
	end
	return prev[2]
end
function C.ValidForge(level)
	return type(level)=="number" and level%1==0 and level>=1 and level<=C.MAX_FORGE_LEVEL
end
function C.RarityWindow(level)
	if not C.ValidForge(level) then level=1 end
	local floor,ceiling=1,1
	for i,row in ipairs(C.RARITIES) do
		if level>=row.Unlock then ceiling=i end
		if row.RetireBelowAt and level>=row.RetireBelowAt then floor=i end
	end
	return floor,ceiling
end
function C.RequiredForge(rarity)
	return C.ById[rarity] and C.ById[rarity].Unlock
end
function C.HasSecondSlot(rarity)
	local row=C.ById[rarity]
	return row~=nil and row.Index>=C.ById[C.SECOND_SLOT_RARITY].Index
end
function C.UpgradeCost(target)
	local p=C.FORGE_COST
	return math.max(p.Round,math.floor(p.FirstUpgrade*(1+(target-2)/p.Scale)^p.Exponent/p.Round+0.5)*p.Round)
end
function C.RarityWeights(level)
	if not C.ValidForge(level) then level=1 end
	local floor,ceiling=C.RarityWindow(level)
	local weights={}
	local tail=C.TOTAL_RARITY_WEIGHT
	for i,row in ipairs(C.RARITIES) do
		if i<floor or i>ceiling then
			weights[row.Id]=0
		else
			local nextRow=C.RARITIES[i+1]
			local nextTail=0
			if i<ceiling then
				-- Reserve one integer weight for every eligible rarity, even if
				-- adjacent tail milestones coincide after rounding.
				nextTail=math.clamp(math.floor(C.TOTAL_RARITY_WEIGHT*C.At(C.RARITY_TAIL,level-nextRow.Unlock,true)+0.5),ceiling-i,tail-1)
			end
			weights[row.Id]=tail-nextTail
			tail=nextTail
		end
	end
	return weights
end
return C
