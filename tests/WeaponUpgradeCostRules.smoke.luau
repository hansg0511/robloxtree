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
	{Kind="Material",Source="GroveMaterials",MaterialType="Heartwood",Count=1},
	{Kind="Stack",Source="AxeHeads",Id="copper_head",Count=1},
	{Kind="Stack",Source="MaterialBalances",Id="future_essence",Count=2},
}
check("mixed independent resource types valid",Rules.Validate(sample))
check("bad count rejected",not Rules.Validate({{Kind="Logs",Count=-1}}))
check("unknown material source rejected",not Rules.Validate({
	{Kind="Material",Source="UntrustedStorage",MaterialType="Heartwood",Count=1},
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
check("duplicate material row rejected",not Rules.Validate({
	{Kind="Material",Source="GroveMaterials",MaterialType="Heartwood",Count=1},
	{Kind="Material",Source="GroveMaterials",MaterialType="Heartwood",Count=1},
}))
local described=Rules.Describe(sample)
check("UI recipe includes nonlog other materials",#described==5
	and described[3].MaterialType=="Heartwood"
	and described[5].Id=="future_essence")
described[1].Amount=42
check("preview is detached from recipe source",sample[1].Amount==1000)

local data={
	Coins=1200,
	GroveMaterials={
		{UID="heart-a",MaterialType="Heartwood"},
		{UID="heart-b",MaterialType="Heartwood"},
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
-- Multi-type unique materials must coexist in one recipe. No one-to-one
-- "Heartwood only" shortcut is allowed in the future transaction adapter.
local multiType={
	{Kind="Coins",Amount=20},
	{Kind="Logs",Count=1,MutationFamily="$selected"},
	{Kind="Material",Source="GroveMaterials",MaterialType="Heartwood",Count=1},
	{Kind="Material",Source="GroveMaterials",MaterialType="CrystalCatalyst",Count=1},
}
local multiData={
	Coins=100,GroveMaterials={
		{UID="heart-x",MaterialType="Heartwood"},
		{UID="crystal-y",MaterialType="CrystalCatalyst"},
	},
}
local multi=Rules.Plan(multiType,multiData,
	{{UID="log-g1",SizeScale=5,Mutations={Golden=true}}},
	{LogUIDs={"log-g1"},MaterialUIDsByType={
		Heartwood={"heart-x"},CrystalCatalyst={"crystal-y"},
	}},"Golden")
check("multiple unique material types coexist",multi and multi.CanAfford
	and #multi.MaterialGroups==2 and #multi.MaterialUIDs==2)
check("missing second type fails closed",Rules.Plan(multiType,multiData,
	{{UID="log-g1",SizeScale=5,Mutations={Golden=true}}},
	{LogUIDs={"log-g1"},MaterialUIDsByType={
		Heartwood={"heart-x"},CrystalCatalyst={"missing-y"},
	}},"Golden").CanAfford==false)
check("duplicate cross-type resource UID rejected",Rules.Plan(multiType,multiData,
	{{UID="log-g1",SizeScale=5,Mutations={Golden=true}}},
	{LogUIDs={"log-g1"},MaterialUIDsByType={
		Heartwood={"heart-x"},CrystalCatalyst={"heart-x"},
	}},"Golden")==nil)

print("UpgradeCost PASS: multiple ingredient types, unique UIDs, exact resources, fail-closed missing materials and non-mutating previews")
return true
