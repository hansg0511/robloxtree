-- Server-owned slots. Dense two-element array; false represents empty.
local Forge=require(game.ReplicatedStorage.Shared.ForgeMutationRules)
local Config=require(game.ReplicatedStorage.Shared.ProgressionConfig)
local Economy=require(game.ReplicatedStorage.Shared.PremiumEconomyConfig)
local Dispatcher=require(game.ServerScriptService.WeaponEffects.Dispatcher)
local Rules={}
Rules.MIN_FORGE_LEVEL=Config.AWAKEN_MIN_FORGE
Rules.ECONOMY_CONFIGURED=true
Rules.COST_POLICY="PREMIUM"
function Rules.CanUseUpgradeRecipe() return true end
local function copy(v)
	if type(v)~="table" then return v end
	local t={}
	for k,x in pairs(v) do t[k]=copy(x) end
	return t
end
local function validSlot(slot)
	if type(slot)~="table" or not table.find(Forge.FAMILIES,slot.Family)
		or type(slot.Potency)~="number" or not (slot.Potency>0 and slot.Potency<=1)
		or type(slot.ForgeTier)~="number" or slot.ForgeTier%1~=0 or slot.ForgeTier<1 then return false end
	local known=Forge.ABILITIES[slot.Family][Forge.MAX_LEVEL]
	return known and table.find(known,slot.Id)~=nil
end
function Rules.ReadSlots(data)
	if type(data)~="table" then return nil,"INVALID_WEAPON_DATA" end
	local slots={false,false}
	local raw=data.MutationSlots
	if raw~=nil then
		if type(raw)~="table" then return nil,"INVALID_SLOTS" end
		for k,v in pairs(raw) do
			if (k~=1 and k~=2) or (v~=false and not validSlot(v)) then return nil,"INVALID_SLOTS" end
			slots[k]=copy(v)
		end
	end
	local legacy=data.MutationAbility
	if legacy~=nil then
		if not validSlot(legacy) then return nil,"INVALID_LEGACY_MUTATION" end
		if raw~=nil and (not slots[1] or slots[1].Id~=legacy.Id or slots[1].Family~=legacy.Family) then
			return nil,"CONFLICTING_LEGACY_MUTATION"
		end
		slots[1]=copy(legacy)
	end
	if slots[1] and slots[2] and slots[1].Family==slots[2].Family then return nil,"DUPLICATE_FAMILY" end
	local found={}
	for _,effect in ipairs(type(data.Effects)=="table" and data.Effects or {}) do
		if type(effect)=="table" and effect.Source=="WoodMutation" then
			local index=if slots[1] and slots[1].Id==effect.Id then 1 elseif slots[2] and slots[2].Id==effect.Id then 2 else nil
			if not index or found[index] then return nil,"UNTRACKED_MUTATION" end
			found[index]=true
		end
	end
	for i=1,2 do if slots[i] and not found[i] then return nil,"MISSING_MUTATION_EFFECT" end end
	return slots
end
function Rules.Costs(mode,count)
	local price=if mode=="Awaken" then Economy.AWAKEN elseif mode=="Replace" then Economy.REPLACE else nil
	if not price then return nil end
	return {
		{Kind="Coins",Amount=price.Coins},
		{Kind="Logs",Count=count,MutationFamily="$selected"},
		{Kind="Stack",Source="MaterialBalances",Id=Economy.PREMIUM,Count=price.Premium},
	}
end
function Rules.Check(mode,rarity,data,family,level)
	if mode~="Awaken" and mode~="Replace" then return nil,"INVALID_MODE" end
	if not Forge.Tier(level) or level<Rules.MIN_FORGE_LEVEL then return nil,"FORGE_LEVEL_TOO_LOW" end
	if not table.find(Forge.FAMILIES,family) then return nil,"INVALID_FAMILY" end
	local slots,reason=Rules.ReadSlots(data)
	if not slots then return nil,reason end
	if mode=="Awaken" then
		if slots[1] then return nil,"ALREADY_AWAKENED" end
		if slots[2] and slots[2].Family==family then return nil,"DUPLICATE_FAMILY" end
	else
		if not Config.HasSecondSlot(rarity) then return nil,"LEGENDARY_REQUIRED" end
		if not slots[2] then return nil,"SECOND_SLOT_MISSING" end
		if slots[1] and slots[1].Family==family then return nil,"DUPLICATE_FAMILY" end
	end
	return {Mode=mode,Slots=slots,Replacing=mode=="Replace",Costs=Rules.Costs(mode,1),MaxLogs=Forge.Tier(level).MaxMutatedLogs}
end
local function assign(data,slots,index,ability)
	if type(ability)~="table" or type(ability.Effect)~="table"
		or ability.Effect.Id~=ability.Id or ability.Effect.Source~="WoodMutation" then return nil,"INVALID_ABILITY" end
	local slot={Family=ability.Family,Id=ability.Id,Potency=ability.Potency,ForgeTier=ability.Tier}
	if not validSlot(slot) then return nil,"INVALID_ABILITY" end
	local old=slots[index]
	local nextData=copy(data)
	local effects={}
	for _,effect in ipairs(type(data.Effects)=="table" and data.Effects or Dispatcher.List(data)) do
		if not (old and effect.Source=="WoodMutation" and effect.Id==old.Id) then
			effects[#effects+1]=copy(effect)
		end
	end
	effects[#effects+1]=copy(ability.Effect)
	slots[index]=slot
	nextData.MutationSlots=slots
	nextData.MutationAbility=if slots[1] then copy(slots[1]) else nil
	nextData.Effects=effects
	if #Dispatcher.List(nextData)~=#effects or #effects>Dispatcher.MAX_EFFECTS then return nil,"INVALID_UPGRADED_EFFECTS" end
	return nextData
end
function Rules.Build(data,mode,ability,rarity,level)
	if type(ability)~="table" then return nil,"INVALID_ABILITY" end
	local check,reason=Rules.Check(mode,rarity,data,ability.Family,level)
	if not check then return nil,reason end
	return assign(data,check.Slots,if mode=="Awaken" then 1 else 2,ability)
end
-- Only invoked on creation, rarity crossing, or legacy migration.
-- Existing slot 2 is never rerolled. Empty slot 1 does not block the grant.
function Rules.GrantSecond(data,rarity,level,rng)
	if not Config.HasSecondSlot(rarity) then return data end
	local slots,reason=Rules.ReadSlots(data)
	if not slots then return nil,reason end
	if slots[2] then return data end
	local tier=Forge.Tier(level)
	if not tier then return nil,"FORGE_LEVEL_TOO_LOW" end
	local total=0
	local eligible={}
	for _,family in ipairs(Forge.FAMILIES) do
		local weight=Economy.FREE_FAMILY_WEIGHTS[family] or 0
		if weight>0 and (not slots[1] or slots[1].Family~=family) and #Forge.AbilityOdds(family,level)>0 then
			total+=weight
			eligible[#eligible+1]={Family=family,Upper=total}
		end
	end
	if total<=0 then return nil,"NO_ELIGIBLE_FAMILY" end
	local draw=rng:NextNumber()*total
	local family=eligible[#eligible].Family
	for _,row in ipairs(eligible) do if draw<row.Upper then family=row.Family break end end
	local potency=tier.PotencyCap*rng:NextNumber(Economy.FREE_POTENCY_MIN,Economy.FREE_POTENCY_MAX)
	local ability=Forge.Roll({Family=family,Tier=level,Potency=potency},level,rng)
	return assign(data,slots,2,ability)
end
return Rules
