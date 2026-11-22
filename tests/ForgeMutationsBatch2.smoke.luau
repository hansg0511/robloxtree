-- Studio SERVER smoke test: Phase 2 Batch 2 weighted forge abilities.
-- Synthetic effects only; no player profiles, materials or coins mutated.
local Forge=require(game.ReplicatedStorage.Shared.ForgeMutationRules)
local Dispatcher=require(game.ServerScriptService.WeaponEffects.Dispatcher)
local GoldenRush=require(game.ServerScriptService.WeaponEffects.GoldenRush)
local GoldenJackpot=require(game.ServerScriptService.WeaponEffects.GoldenJackpot)
local Bloodrush=require(game.ServerScriptService.WeaponEffects.Bloodrush)
local Rampage=require(game.ServerScriptService.WeaponEffects.Rampage)
local ChainLightning=require(game.ServerScriptService.WeaponEffects.ChainLightning)
local function check(name, condition)
	assert(condition,"[MutationBatch2] "..name.." FAIL")
end
local function near(a,b) return math.abs(a-b)<0.000001 end
local function mockLog(family)
	return {SizeScale=5,SpeciesId="Oak",Mutations={[family]=true}}
end
local families={
	Golden={GoldenTouch=50,GoldenRush=30,GoldenJackpot=20},
	Frenzied={Fervor=50,Bloodrush=25,Rampage=25},
	Shocked={Thunderstrike=65,ChainLightning=35},
}
for family,weights in pairs(families) do
	local tierOne=Forge.Preview({mockLog(family)},1)
	check(family.." tier1 one guaranteed ability",tierOne and #tierOne.AbilityOdds==1
		and near(tierOne.AbilityOdds[1].Chance,1))
	local tierTwo=Forge.Preview({mockLog(family)},2)
	local sum=0
	local expectedCount=0
	for _ in pairs(weights) do expectedCount+=1 end
	check(family.." tier2 full pool size",#tierTwo.AbilityOdds==expectedCount)
	for _,choice in ipairs(tierTwo.AbilityOdds) do
		sum+=choice.Chance
		check(family.." weight "..choice.Id,choice.Weight==weights[choice.Id])
	end
	check(family.." weighted probabilities sum to one",near(sum,1))
	for _,choice in ipairs(tierTwo.AbilityOdds) do
		-- Pick the center of each deterministic interval, proving no
		-- introduced ability is unreachable or assigned zero weight.
		local midpoint=0
		for _,item in ipairs(tierTwo.AbilityOdds) do
			if item.Id==choice.Id then
				midpoint+=item.Chance/2
				break
			end
			midpoint+=item.Chance
		end
		local selected=Forge.SelectAbility(family,2,midpoint)
		check(family.." reachable "..choice.Id,selected==choice.Id)
		local rng={NextNumber=function() return midpoint end}
		local rolled=Forge.Roll(tierTwo,2,rng)
		check("roll "..choice.Id,rolled and rolled.Id==choice.Id
			and rolled.Family==family and rolled.Tier==2)
		local accepted=Dispatcher.List({Effects={rolled.Effect}})
		check("dispatcher registers "..choice.Id,#accepted==1
			and accepted[1].Id==choice.Id)
	end
end
check("Golden boundaries",Forge.SelectAbility("Golden",2,0.499)=="GoldenTouch"
	and Forge.SelectAbility("Golden",2,0.5)=="GoldenRush"
	and Forge.SelectAbility("Golden",2,0.8)=="GoldenJackpot")
check("Shock boundaries",Forge.SelectAbility("Shocked",2,0.649)=="Thunderstrike"
	and Forge.SelectAbility("Shocked",2,0.65)=="ChainLightning")
check("invalid RNG rejected",Forge.SelectAbility("Golden",2,-0.1)==nil
	and Forge.SelectAbility("Golden",2,1.1)==nil)
check("cannot roll tier2 preview using tier1",Forge.Roll(
	Forge.Preview({mockLog("Golden")},2),1,Random.new())==nil)
local ordinary=Forge.Preview({{SpeciesId="Oak",SizeScale=5}},2)
check("normal log remains unmutated",ordinary.Family==nil and #ordinary.AbilityOdds==0
	and Forge.Roll(ordinary,2,Random.new())==nil)
local mixed=Forge.Preview({mockLog("Golden"),mockLog("Frenzied")},2)
check("mixed mutation families still rejected",mixed.InvalidReason=="MIXED_MUTATION_FAMILIES")

local p={}
local coins=0
local payout=function(n) coins+=n end
local rushParams={CoinFractionPerStack=0.25,MaxStacks=4,WindowSeconds=8}
local rush=GoldenRush.Prepare(rushParams,{})
local rushContext={Player=p,WeaponUID="rush",Killed=true,TreeCoinBase=100,
	Now=100,AwardCoins=payout}
for i=1,6 do
	rushContext.Now=100+i
	GoldenRush.Apply(rush,rushContext)
end
check("Golden Rush capped at 4 stacks",coins==25+50+75+100+100+100)
rushContext.Now=130
GoldenRush.Apply(rush,rushContext)
check("Golden Rush streak expires",coins==25+50+75+100+100+100+25)
GoldenRush.OnWeaponEquipped(p,"rush","other")
rushContext.Now=131
GoldenRush.Apply(rush,rushContext)
check("Golden Rush resets on equip change",coins==25+50+75+100+100+100+25+25)
-- Both the expired streak and the post-equip streak start at one stack.
GoldenRush.Clear(p)
rushContext.Killed=false
local oldCoins=coins
GoldenRush.Apply(rush,rushContext)
check("Golden Rush no reward without kill",coins==oldCoins)

local jackpotParams={Chance=0.20,PayoutMultiplier=5}
local jackpot=GoldenJackpot.Prepare(jackpotParams,{})
local jackpotContext={Killed=true,TreeCoinBase=100,AwardCoins=payout,
	RandomUnit=function() return 0.19 end}
GoldenJackpot.Apply(jackpot,jackpotContext)
check("Jackpot adds 5x reward on server RNG success",coins==oldCoins+500)
jackpotContext.RandomUnit=function() return 0.2 end
GoldenJackpot.Apply(jackpot,jackpotContext)
check("Jackpot boundary fail",coins==oldCoins+500)
jackpotContext.Killed=false
jackpotContext.RandomUnit=function() return 0 end
GoldenJackpot.Apply(jackpot,jackpotContext)
check("Jackpot ignores non-kills",coins==oldCoins+500)

local rampageParams={DamageMultiplier=1.35,DurationSeconds=8}
local rampage=Rampage.Prepare(rampageParams,{})
check("Rampage not active before kill",Rampage.Multiplier(p,"ramp",100)==1)
Rampage.Apply(rampage,{Player=p,WeaponUID="ramp",Killed=true,Now=100})
check("Rampage applies only to future hits",
	near(Rampage.Multiplier(p,"ramp",101),1.35))
Rampage.Apply(rampage,{Player=p,WeaponUID="ramp",Killed=true,Now=104})
check("Rampage refreshes without stacking",
	near(Rampage.Multiplier(p,"ramp",110),1.35)
	and Rampage.Multiplier(p,"ramp",112)==1)
Rampage.Apply(rampage,{Player=p,WeaponUID="ramp",Killed=true,Now=200})
Rampage.OnWeaponEquipped(p,"ramp","other")
check("Rampage wiped on equip change",Rampage.Multiplier(p,"ramp",201)==1)
Rampage.Clear(p)

local dummyCharacter=Instance.new("Model")
dummyCharacter.Name="TemporaryBloodrushSmokeDummy"
dummyCharacter.Parent=game.ServerStorage -- no world/rig simulation
local humanoid=Instance.new("Humanoid")
humanoid.RequiresNeck=false
humanoid.Parent=dummyCharacter
humanoid.Health=100
humanoid.WalkSpeed=28
local bloodrush=Bloodrush.Prepare({SpeedMultiplier=1.25,DurationSeconds=7},{})
local bloodContext={Player=p,WeaponUID="blood",Killed=true,
	Humanoid=humanoid,NoTimer=true}
Bloodrush.Apply(bloodrush,bloodContext)
check("Bloodrush boosts real humanoid walk speed",near(humanoid.WalkSpeed,35))
Bloodrush.Apply(bloodrush,bloodContext)
check("Bloodrush refresh does not compound speed",near(humanoid.WalkSpeed,35))
Bloodrush.OnWeaponEquipped(p,"blood","other")
check("Bloodrush restores baseline on weapon change",near(humanoid.WalkSpeed,28))
Bloodrush.Apply(bloodrush,bloodContext)
humanoid.WalkSpeed=31 -- another movement system changed the baseline
Bloodrush.Clear(p)
check("Bloodrush does not stomp other speed controller",near(humanoid.WalkSpeed,31))
dummyCharacter:Destroy()

local chainParams={
	Chance=0.5,DamageFraction=0.6,JumpFalloff=0.7,MaxJumps=3,Radius=12,
}
local chain=ChainLightning.Resolve(chainParams)
check("chain parameters accepted",chain~=nil)
local function tree(id,x)
	local t={CreationId=id,CFrame=CFrame.new(x,0,0),MaxHP=200,HP=200,Hits=0}
	function t:TakeDamage(hit,_player)
		local amount=math.min(self.HP,math.floor(hit.Damage))
		if amount<=0 then return false end
		self.HP-=amount
		self.Hits+=1
		return true,amount,self.HP==0
	end
	return t
end
local primary=tree(1,0)
local a=tree(2,8)
local b=tree(3,16)
local c=tree(4,24)
local blocked=tree(5,3)
local active={[primary]=true,[a]=true,[b]=true,[c]=true,[blocked]=true}
local records={}
local eligible=function(t) return t~=blocked end
local chainContext={
	Player=p,PrimaryTree=primary,PrimaryDamage=100,PrimarySucceeded=true,
	ActiveTrees=active,EligibleSecondary=eligible,
	RandomUnit=function() return 0.1 end,
	OnAppliedHit=function(t,applied,killed,maxHP)
		records[#records+1]={Tree=t,Damage=applied,Killed=killed,MaxHP=maxHP}
	end,
}
local ready=ChainLightning.Prepare(chainParams,chainContext)
check("chain rolls server-side on successful proc",ready and ready.Proc)
local hits=ChainLightning.Apply(ready,chainContext)
check("chain hits exactly 3 unique trees",hits==3 and #records==3
	and a.Hits==1 and b.Hits==1 and c.Hits==1)
check("chain follows nearest viable neighbor in sequence",
	records[1].Tree==a and records[2].Tree==b and records[3].Tree==c)
check("chain falloff damage equals actual HP removed",
	records[1].Damage==60 and records[2].Damage==42
	and records[3].Damage==29)
check("primary and restricted target never hit by chain",
	primary.HP==200 and blocked.HP==200 and blocked.Hits==0)
local sum=0
for _,hit in ipairs(records) do sum+=hit.Damage end
check("secondary XP callback reports HP clamp exactly once",sum==60+42+29)
chainContext.RandomUnit=function() return 0.9 end
local miss=ChainLightning.Prepare(chainParams,chainContext)
check("chain chance failure never hits",miss and not miss.Proc
	and ChainLightning.Apply(miss,chainContext)==0 and #records==3)
chainContext.RandomUnit=function() return 0 end
local aborted=ChainLightning.Prepare(chainParams,chainContext)
chainContext.PrimarySucceeded=false
check("unsuccessful primary cannot chain",
	ChainLightning.Apply(aborted,chainContext)==0 and #records==3)
for _,child in ipairs(workspace:GetChildren()) do
	if child:IsA("BasePart") and child.Name=="ChainLightningArc" then child:Destroy() end
end

-- Both sources may coexist; class Cleave remains separate from mutation.
local dual=Dispatcher.List({Effects={
	{Id="Cleave",Trigger="OnHit",Source="WeaponClass",
		Params={Radius=12,DamageFraction=0.4}},
	{Id="ChainLightning",Trigger="OnHit",Source="WoodMutation",Params=chainParams},
}})
check("Cleave and Chain Lightning are independent",#dual==2)
print("ForgeMutations Batch 2 PASS: weighted pools, all five effects, timeouts, bounded chains and Cleave coexistence")
return true
