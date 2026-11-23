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
local first=sampleAbility("Golden",0.1)
local second=sampleAbility("Frenzied",0.1)
local replacement=sampleAbility("Shocked",0.9)
check("phase 3 test abilities exist",first and second and replacement)
local clean={
	ExperimentalClass="Axe",Progression={SchemaVersion=1,Level=22,XP=35},
	Effects={},Materials={{UID="original-log"}},CraftedPower=81,
}
local canAwaken,allowReason=Upgrades.Check("Awaken","Rare",clean,"Golden",2)
check("ordinary rare weapon can awaken",canAwaken and not allowReason)
check("cannot awaken at forge level 1",
	not Upgrades.Check("Awaken","Rare",clean,"Golden",1))
local awakened,reason=Upgrades.Build(clean,"Awaken",first,"Rare",2)
check("awakening gives first slot",awakened and not reason
	and #awakened.MutationSlots==1 and awakened.MutationSlots[1].Id==first.Id)
check("awakening preserves existing stats/XP/materials",
	awakened.Progression.Level==22 and awakened.Progression.XP==35
	and awakened.CraftedPower==81 and #awakened.Materials==1)
check("pure build never mutates original weapon",
	clean.MutationAbility==nil and #clean.Effects==0)
check("second awakening rejected",
	not Upgrades.Check("Awaken","Rare",awakened,"Shocked",2))
check("rare cannot infuse second slot",
	not Upgrades.Check("Infuse","Rare",awakened,"Shocked",2))
check("must awaken before infusion",
	not Upgrades.Check("Infuse","Legendary",clean,"Frenzied",2))
check("same-family infusion denied",
	not Upgrades.Check("Infuse","Legendary",awakened,"Golden",2))
local legend={
	ExperimentalClass="Battlehammer",
	CleaveRadius=10,CleaveDamageFraction=0.4,
	Progression={Level=45,XP=0},Effects={
		{Id="Cleave",Trigger="OnHit",Source="WeaponClass",
			Params={Radius=10,DamageFraction=0.4}},
		first.Effect,
	},
	MutationAbility={
		Family=first.Family,Id=first.Id,Potency=first.Potency,
		ForgeTier=first.Tier,
	},
}
local infused,reason=Upgrades.Build(legend,"Infuse",second,"Legendary",2)
check("legacy one-slot weapon gains second",infused and not reason
	and #infused.MutationSlots==2)
check("first legacy ability is unchanged",infused.MutationSlots[1].Id==first.Id)
check("infusion preserves Cleave AND two mutations",
	#Dispatcher.List(infused)==3 and infused.Effects[1].Id=="Cleave"
	and infused.Effects[2].Id==first.Id and infused.Effects[3].Id==second.Id)
check("infusion leaves original legacy item untouched",
	legend.MutationSlots==nil and #legend.Effects==2)
check("infused weapon refuses same-family duplicate",
	not Upgrades.Check("Infuse","Legendary",infused,"Golden",2))
local replaced,why=Upgrades.Build(infused,"Infuse",replacement,"Ultra",2)
check("infusion replacement rewrites ONLY slot 2",replaced and not why
	and replaced.MutationSlots[1].Id==first.Id
	and replaced.MutationSlots[2].Id==replacement.Id)
check("replacement retains first mutation and Cleave but drops old second",
	#Dispatcher.List(replaced)==3 and replaced.Effects[1].Id=="Cleave"
	and replaced.Effects[2].Id==first.Id
	and replaced.Effects[3].Id==replacement.Id)
check("replacement does not mutate the already infused source",
	infused.MutationSlots[2].Id==second.Id)
local legacyHammer={
	ExperimentalClass="Battlehammer",
	CleaveRadius=11,CleaveDamageFraction=0.4,
}
local awakenedHammer=Upgrades.Build(legacyHammer,"Awaken",first,"Common",2)
check("old Battlehammer scalar Cleave preserved on awakening",
	awakenedHammer and #Dispatcher.List(awakenedHammer)==2
	and Dispatcher.List(awakenedHammer)[1].Id=="Cleave")
check("live upgrade economy is explicitly unconfigured",
	Upgrades.ECONOMY_CONFIGURED==false
	and Upgrades.COST_POLICY=="STUDIO_TEST_ONLY")
check("only temporary mutated-log inputs remain for Studio testing",
	#Upgrades.COSTS.Awaken==1 and #Upgrades.COSTS.Infuse==1
	and Upgrades.COSTS.Awaken[1].Kind=="Logs"
	and Upgrades.COSTS.Awaken[1].Count==2
	and Upgrades.COSTS.Infuse[1].Kind=="Logs"
	and Upgrades.COSTS.Infuse[1].Count==3)
check("there are no unapproved material, coin or head costs",
	Upgrades.COSTS.Awaken[1].MutationFamily=="$selected"
	and Upgrades.COSTS.Infuse[1].MutationFamily=="$selected")
check("all actual recipes are accepted by shared cost planner",
	Rules.Validate(Upgrades.COSTS.Awaken)
	and Rules.Validate(Upgrades.COSTS.Infuse))

print("UpgradeCost + WeaponUpgradeRules PASS: multiple ingredient types, unique UIDs, exact resources, fail-closed missing materials and non-mutating previews")
return true
