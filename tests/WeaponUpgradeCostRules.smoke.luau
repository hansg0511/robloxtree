-- Phase 3 pure multi-resource recipe architecture smoke test.
-- Execute as a Roblox Studio SERVER script through the agent's runner.
local Rules=require(game.ServerScriptService.Economy.WeaponUpgradeCostRules)
local CostService=require(game.ServerScriptService.Economy.WeaponUpgradeCostService)
assert(type(CostService.Preview)=="function"
	and type(CostService.Take)=="function"
	and type(CostService.Rollback)=="function"
	and type(CostService.Finalize)=="function",
	"[UpgradeCost] server transaction adapter failed to initialize")
local function check(name,condition)
	assert(condition,"[UpgradeCost] "..name.." FAIL")
end
local sample={
	{Kind="Coins",Amount=1000},
	{Kind="Logs",Count=2,MutationFamily="$selected"},
	{Kind="Material",Source="GroveMaterials",MaterialType="TestMaterialA",Count=1},
	{Kind="Stack",Source="AxeHeads",Id="copper_head",Count=1},
	{Kind="Stack",Source="MaterialBalances",Id="future_essence",Count=2},
}
check("mixed independent resource types valid",Rules.Validate(sample))
check("bad count rejected",not Rules.Validate({{Kind="Logs",Count=-1}}))
check("unknown material source rejected",not Rules.Validate({
	{Kind="Material",Source="UntrustedStorage",MaterialType="TestMaterialA",Count=1},
}))
check("unknown generic source rejected",not Rules.Validate({
	{Kind="Stack",Source="Arbitrary",Id="future_essence",Count=1},
}))
check("empty recipe rejected",not Rules.Validate({}))
check("unknown resource kind rejected",not Rules.Validate({
	{Kind="Free",Amount=0},
}))
check("duplicate cost identifier rejected",not Rules.Validate({
	{Kind="Coins",Amount=1},{Kind="Coins",Amount=2},
}))
local sparseCosts=table.create(2)
sparseCosts[1]={Kind="Coins",Amount=1}
sparseCosts[2]={Kind="Stack",Source="AxeHeads",Id="copper_head",Count=1}
sparseCosts[1]=nil
check("sparse cost rows rejected",not Rules.Validate(sparseCosts))
check("duplicate material row rejected",not Rules.Validate({
	{Kind="Material",Source="GroveMaterials",MaterialType="TestMaterialA",Count=1},
	{Kind="Material",Source="GroveMaterials",MaterialType="TestMaterialA",Count=1},
}))
local described=Rules.Describe(sample)
check("UI recipe includes nonlog other materials",#described==5
	and described[3].MaterialType=="TestMaterialA"
	and described[5].Id=="future_essence")
described[1].Amount=42
check("preview is detached from recipe source",sample[1].Amount==1000)

local data={
	Coins=1200,
	GroveMaterials={
		{UID="heart-a",MaterialType="TestMaterialA"},
		{UID="heart-b",MaterialType="TestMaterialA"},
		{UID="other",MaterialType="Other"},
	},
	AxeHeads={copper_head=3},
	MaterialBalances={future_essence=4},
}
local logs={
	{UID="log-g1",SizeScale=5,Mutations={Golden=true}},
	{UID="log-g2",SizeScale=4,Mutations={Golden=true}},
	{UID="log-n",SizeScale=5,Mutations={}},
}
local chosen={LogUIDs={"log-g1","log-g2"},MaterialUIDs={"heart-a"}}
local plan=Rules.Plan(sample,data,logs,chosen,"Golden")
check("full payment plan affordable",plan and plan.CanAfford)
check("explicit exact UID reservations",plan.LogUIDs[1]=="log-g1"
	and plan.LogUIDs[2]=="log-g2" and plan.MaterialUIDs[1]=="heart-a")
check("coins and stacks fully represented",plan.Coins==1000
	and #plan.StackDeductions==2)
check("planning does not consume anything",data.Coins==1200
	and #data.GroveMaterials==3 and data.AxeHeads.copper_head==3
	and data.MaterialBalances.future_essence==4 and #logs==3)
plan.LogUIDs[1]="tampered"
check("plan is not alias of player selection",chosen.LogUIDs[1]=="log-g1")

local scarce=table.clone(data)
scarce.MaterialBalances={} -- newly required material cannot be silently waived
local notEnough=Rules.Plan(sample,scarce,logs,chosen,"Golden")
check("missing future-material balance blocks upgrade",notEnough
	and not notEnough.CanAfford
	and table.find(notEnough.Missing,"future_essence")~=nil)
local missingAll=Rules.Plan(sample,{Coins=1200,AxeHeads=data.AxeHeads,
	GroveMaterials=data.GroveMaterials},logs,chosen,"Golden")
check("absent future inventory fails closed",missingAll
	and not missingAll.CanAfford)
check("wrong-family mutated logs fail",not Rules.Plan(sample,data,logs,chosen,"Shocked").CanAfford)
check("spoofed ingredient UIDs fail",not Rules.Plan(sample,data,logs,{
	LogUIDs={"log-g1","spoofed"},MaterialUIDs={"heart-a"},
},"Golden").CanAfford)
local sparseLogUIDs=table.create(2)
sparseLogUIDs[1]="log-g1"
sparseLogUIDs[2]="log-g2"
sparseLogUIDs[1]=nil
check("sparse log UID selection rejected",Rules.Plan(sample,data,logs,{
	LogUIDs=sparseLogUIDs,MaterialUIDs={"heart-a"},
},"Golden")==nil)
check("duplicate UID selection rejected",Rules.Plan(sample,data,logs,{
	LogUIDs={"log-g1","log-g1"},MaterialUIDs={"heart-a"},
},"Golden")==nil)
check("wrong material type rejected",not Rules.Plan(sample,data,logs,{
	LogUIDs={"log-g1","log-g2"},MaterialUIDs={"other"},
},"Golden").CanAfford)
check("cross-source UID reuse rejected",Rules.Plan(sample,data,
	{{UID="heart-a",SizeScale=5,Mutations={Golden=true}},
		{UID="log-g2",SizeScale=5,Mutations={Golden=true}}},
	{LogUIDs={"heart-a","log-g2"},MaterialUIDs={"heart-a"}},"Golden")==nil)
-- Synthetic material types prove architecture flexibility; no specific
-- real upgrade material has been selected for gameplay.
local multiType={
	{Kind="Coins",Amount=20},
	{Kind="Logs",Count=1,MutationFamily="$selected"},
	{Kind="Material",Source="GroveMaterials",MaterialType="TestMaterialA",Count=1},
	{Kind="Material",Source="GroveMaterials",MaterialType="CrystalCatalyst",Count=1},
}
local multiData={
	Coins=100,GroveMaterials={
		{UID="heart-x",MaterialType="TestMaterialA"},
		{UID="crystal-y",MaterialType="CrystalCatalyst"},
	},
}
local multi=Rules.Plan(multiType,multiData,
	{{UID="log-g1",SizeScale=5,Mutations={Golden=true}}},
	{LogUIDs={"log-g1"},MaterialUIDsByType={
		TestMaterialA={"heart-x"},CrystalCatalyst={"crystal-y"},
	}},"Golden")
check("multiple unique material types coexist",multi and multi.CanAfford
	and #multi.MaterialGroups==2 and #multi.MaterialUIDs==2)
check("missing second type fails closed",Rules.Plan(multiType,multiData,
	{{UID="log-g1",SizeScale=5,Mutations={Golden=true}}},
	{LogUIDs={"log-g1"},MaterialUIDsByType={
		TestMaterialA={"heart-x"},CrystalCatalyst={"missing-y"},
	}},"Golden").CanAfford==false)
-- This intentionally keeps #selection == 2 while index 1 is missing;
-- previously it could produce a receipt without spending the material.
local sparseMaterialUIDs=table.create(2)
sparseMaterialUIDs[1]="heart-a"
sparseMaterialUIDs[2]="heart-b"
sparseMaterialUIDs[1]=nil
check("sparse material regression precondition",#sparseMaterialUIDs==2)
check("sparse material UID selection rejected",Rules.Plan({
	{Kind="Material",Source="GroveMaterials",MaterialType="TestMaterialA",Count=2},
},data,{}, {MaterialUIDs=sparseMaterialUIDs},nil)==nil)
check("duplicate cross-type resource UID rejected",Rules.Plan(multiType,multiData,
	{{UID="log-g1",SizeScale=5,Mutations={Golden=true}}},
	{LogUIDs={"log-g1"},MaterialUIDsByType={
		TestMaterialA={"heart-x"},CrystalCatalyst={"heart-x"},
	}},"Golden")==nil)

-- Phase 3A/3B PURE upgrade rules share this ONE existing test.
-- These tests do not consume profile materials or create any extra runner.
local Upgrades=require(game.ServerScriptService.Economy.WeaponUpgradeRules)
local Forge=require(game.ReplicatedStorage.Shared.ForgeMutationRules)
local Dispatcher=require(game.ServerScriptService.WeaponEffects.Dispatcher)
local function sampleAbility(family,roll)
	local mutated={}
	for _=1,3 do
		mutated[#mutated+1]={SpeciesId="Oak",SizeScale=5,Mutations={[family]=true}}
	end
	local preview=Forge.Preview(mutated,2)
	return Forge.Roll(preview,2,{NextNumber=function() return roll or 0.1 end})
end
local Premium=require(game.ReplicatedStorage.Shared.PremiumEconomyConfig)
local first=sampleAbility("Golden",0.1)
local second=sampleAbility("Frenzied",0.1)
local replacement=sampleAbility("Shocked",0.9)
local clean={ExperimentalClass="Axe",Progression={Level=12,XP=35},Effects={},Materials={{UID="original-log"}},CraftedPower=81}
check("ordinary rare weapon can awaken",Upgrades.Check("Awaken","Rare",clean,"Golden",2)~=nil)
check("cannot awaken at forge 1",not Upgrades.Check("Awaken","Rare",clean,"Golden",1))
local awakened=Upgrades.Build(clean,"Awaken",first,"Rare",2)
check("awakening preserves stats and leaves second empty",awakened and awakened.MutationSlots[1].Id==first.Id and awakened.MutationSlots[2]==false and awakened.Progression.Level==12 and awakened.CraftedPower==81)
check("pure build preserves source",clean.MutationAbility==nil and #clean.Effects==0)
check("second awakening rejected",not Upgrades.Check("Awaken","Rare",awakened,"Shocked",2))
check("paid infusion removed",not Upgrades.Check("Infuse","Legendary",awakened,"Shocked",25))
check("below threshold no free slot",Upgrades.GrantSecond(clean,"Epic",25,Random.new(1))==clean)
local rng={NextNumber=function(_,lo,hi) if lo then return lo+(hi-lo)*0.5 end return 0 end}
local onlySecond=Upgrades.GrantSecond(clean,"Legendary",25,rng)
check("Legendary without first receives independent second",onlySecond and onlySecond.MutationSlots[1]==false and onlySecond.MutationSlots[2] and onlySecond.MutationAbility==nil)
check("grant idempotent",Upgrades.GrantSecond(onlySecond,"Ultra",60,Random.new(9))==onlySecond)
check("awaken cannot match slot two family",not Upgrades.Check("Awaken","Legendary",onlySecond,onlySecond.MutationSlots[2].Family,25))
local both=Upgrades.Build(onlySecond,"Awaken",second,"Legendary",25)
check("awaken after free second preserves second",both and both.MutationSlots[1].Family=="Frenzied" and both.MutationSlots[2].Id==onlySecond.MutationSlots[2].Id)
local legend={ExperimentalClass="Battlehammer",Effects={{Id="Cleave",Trigger="OnHit",Source="WeaponClass",Params={Radius=10,DamageFraction=0.4}},first.Effect},MutationAbility={Family=first.Family,Id=first.Id,Potency=first.Potency,ForgeTier=first.Tier}}
local granted=Upgrades.GrantSecond(legend,"Legendary",25,rng)
check("free roll excludes first family and preserves Cleave",granted and granted.MutationSlots[2].Family~="Golden" and #Dispatcher.List(granted)==3)
check("replacement cannot match first family",not Upgrades.Check("Replace","Legendary",granted,"Golden",25))
local replaced=Upgrades.Build(granted,"Replace",replacement,"Ultra",60)
check("replacement preserves first and class effects",replaced and replaced.MutationSlots[1].Id==first.Id and replaced.MutationSlots[2].Id==replacement.Id and #Dispatcher.List(replaced)==3)
check("replacement does not mutate original",granted.MutationSlots[2].Id~=replacement.Id)
for _,mode in ipairs({"Awaken","Replace"}) do
	for count=1,Forge.Tier(200).MaxMutatedLogs do check("config recipe validates",Rules.Validate(Upgrades.Costs(mode,count))) end
end
check("replacement premium cost significantly higher",Premium.REPLACE.Premium>Premium.AWAKEN.Premium and Upgrades.ECONOMY_CONFIGURED)

print("UpgradeCost + WeaponUpgradeRules PASS: multiple ingredient types, unique UIDs, exact resources, fail-closed missing materials and non-mutating previews")
return true
