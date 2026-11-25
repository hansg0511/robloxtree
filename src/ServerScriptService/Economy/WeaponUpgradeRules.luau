-- Phase 3A/3B upgrade rules. Pure server-owned weapon-slot/recipe logic.
-- The user has NOT decided upgrade costs or non-log ingredients.
-- Keep the generic multi-resource payment service, but never assume
-- Heartwood, coins, axe heads, or anything else belongs in these recipes.
local Forge=require(game.ReplicatedStorage.Shared.ForgeMutationRules)
local Dispatcher=require(game.ServerScriptService.WeaponEffects.Dispatcher)
local RunService=game:GetService("RunService")
local Config=require(game.ReplicatedStorage.Shared.ProgressionConfig)
local Rules={}

Rules.MIN_FORGE_LEVEL=Config.AWAKEN_MIN_FORGE
-- IMPORTANT: this is a Studio-only mechanical test recipe, NOT an economy.
-- 2/3 mutated logs exercise ability rolling/potency and exact-UID spending.
-- Awakening's FINAL recipe will need additional materials, still UNDECIDED.
-- Live upgrades remain disabled until a deliberately approved, server-owned
-- multi-resource recipe replaces these fixtures.
Rules.ECONOMY_CONFIGURED=false
Rules.COST_POLICY="STUDIO_TEST_ONLY"
Rules.COSTS={
	Awaken={{Kind="Logs",Count=2,MutationFamily="$selected"}},
	Infuse={{Kind="Logs",Count=3,MutationFamily="$selected"}},
}
function Rules.CanUseUpgradeRecipe()
	return Rules.ECONOMY_CONFIGURED==true or RunService:IsStudio()
end
local familyIds={}
for _,family in ipairs(Forge.FAMILIES) do familyIds[family]=true end
local function finite(n)
	return type(n)=="number" and n==n and n>-math.huge and n<math.huge
end
local function copy(t)
	local new={}
	for k,v in pairs(t) do
		if type(v)=="table" then new[k]=copy(v) else new[k]=v end
	end
	return new
end
local function validSlot(slot)
	if type(slot)~="table" or not familyIds[slot.Family]
		or type(slot.Id)~="string" or #slot.Id==0
		or not finite(slot.Potency) or slot.Potency<=0 
		or type(slot.ForgeTier)~="number" or slot.ForgeTier%1~=0
		or slot.ForgeTier<1 then return false end
	-- Historical ability rolls remain valid when live caps/unlocks are retuned.
	local known=Forge.ABILITIES[slot.Family][Forge.MAX_LEVEL]
	return slot.Potency<=1 and known~=nil and table.find(known,slot.Id)~=nil
end

-- Treat either legacy MutationAbility (forged during Batch1/2) or the
-- new two-slot record as authoritative; never silently discard corrupt data.
function Rules.ReadSlots(weaponData)
	if type(weaponData)~="table" then return nil,"INVALID_WEAPON_DATA" end
	local slots={}
	if weaponData.MutationSlots~=nil then
		if type(weaponData.MutationSlots)~="table"
			or #weaponData.MutationSlots>2 then return nil,"INVALID_SLOTS" end
		if #weaponData.MutationSlots==0 and weaponData.MutationAbility~=nil then
			return nil,"CONFLICTING_LEGACY_MUTATION"
		end
		local count=0
		for index in pairs(weaponData.MutationSlots) do
			if type(index)~="number" or index%1~=0 or index<1 or index>2 then
				return nil,"INVALID_SLOTS"
			end
			count+=1
		end
		if count~=#weaponData.MutationSlots then return nil,"INVALID_SLOTS" end
		for i,slot in ipairs(weaponData.MutationSlots) do
			if not validSlot(slot) then return nil,"INVALID_SLOTS" end
			slots[i]=copy(slot)
		end
		local legacy=weaponData.MutationAbility
		if legacy~=nil then
			if not validSlot(legacy) or not slots[1]
				or slots[1].Id~=legacy.Id
				or slots[1].Family~=legacy.Family then
				return nil,"CONFLICTING_LEGACY_MUTATION"
			end
		elseif #slots>0 then
			return nil,"MISSING_FIRST_MUTATION"
		end
	elseif weaponData.MutationAbility~=nil then
		if not validSlot(weaponData.MutationAbility) then
			return nil,"INVALID_LEGACY_MUTATION"
		end
		slots[1]=copy(weaponData.MutationAbility)
	end
	if #slots>1 and (slots[1].Id==slots[2].Id
		or slots[1].Family==slots[2].Family) then return nil,"DUPLICATE_FAMILY" end
	if #slots==0 then
		-- Prevent overwriting an active unknown mutation when no known
		-- legacy metadata exists. Class effects are still permitted.
		for _,effect in ipairs(type(weaponData.Effects)=="table" and weaponData.Effects or {}) do
			if type(effect)=="table" and effect.Source=="WoodMutation" then
				return nil,"UNTRACKED_MUTATION"
			end
		end
	end
	return slots,nil
end

function Rules.Check(mode,rarity,weaponData,family,forgeLevel)
	if mode~="Awaken" and mode~="Infuse" then return nil,"INVALID_MODE" end
	if not Forge.Tier(forgeLevel) or forgeLevel<Rules.MIN_FORGE_LEVEL then
		return nil,"FORGE_LEVEL_TOO_LOW"
	end
	if not familyIds[family] then return nil,"INVALID_FAMILY" end
	local slots,reason=Rules.ReadSlots(weaponData)
	if not slots then return nil,reason end
	if mode=="Awaken" then
		if #slots~=0 then return nil,"ALREADY_AWAKENED" end
	else
		if not Config.HasSecondSlot(rarity) then
			return nil,"LEGENDARY_REQUIRED"
		end
		if #slots<1 then return nil,"AWAKEN_FIRST" end
		if family==slots[1].Family then return nil,"DUPLICATE_FAMILY" end
	end
	return {
		Mode=mode,Slots=slots,
		Replacing=mode=="Infuse" and #slots==2,
		Costs=Rules.COSTS[mode],
	},nil
end

-- Only the intended mutation slot is changed. Class Cleave and the
-- pre-existing first mutation effect survive Infuse and slot-2 replacement.
-- Validation before mutation guarantees the old saved record remains intact
-- on any malformed ability result.
function Rules.Build(weaponData,mode,ability,rarity,forgeLevel)
	if type(ability)~="table" or not validSlot({
		Family=ability.Family,Id=ability.Id,
		Potency=ability.Potency,ForgeTier=ability.Tier,
	}) or type(ability.Effect)~="table"
		or ability.Effect.Id~=ability.Id
		or ability.Effect.Source~="WoodMutation" then return nil,"INVALID_ABILITY" end
	local check,reason=Rules.Check(mode,rarity,weaponData,
		ability.Family,forgeLevel)
	if not check then return nil,reason end
	local effects=if type(weaponData.Effects)=="table" then weaponData.Effects
		else Dispatcher.List(weaponData) -- preserve valid legacy Cleave
	local base=copy(weaponData)
	local oldSlots=check.Slots
	local newSlot={
		Family=ability.Family,Id=ability.Id,
		Potency=ability.Potency,ForgeTier=ability.Tier,
	}
	local nextEffects={}
	local firstId=oldSlots[1] and oldSlots[1].Id
	local replacedId=oldSlots[2] and oldSlots[2].Id
	local foundFirst=false
	for _,effect in ipairs(effects) do
		if type(effect)~="table" or type(effect.Id)~="string" then
			return nil,"INVALID_EFFECT_LIST"
		end
		if effect.Id==replacedId and effect.Source=="WoodMutation" then
			-- Only the old second mutation is replaced.
			continue
		end
		if effect.Source=="WoodMutation" then
			if not firstId or effect.Id~=firstId or foundFirst then
				return nil,"UNTRACKED_MUTATION"
			end
			foundFirst=true
		end
		nextEffects[#nextEffects+1]=copy(effect)
	end
	if mode=="Infuse" and not foundFirst then
		return nil,"FIRST_EFFECT_MISSING"
	end
	nextEffects[#nextEffects+1]=copy(ability.Effect)
	local slots=oldSlots
	if mode=="Awaken" then slots[1]=newSlot
	else slots[2]=newSlot end
	base.MutationSlots=slots
	base.MutationAbility=copy(slots[1]) -- compatibility for existing UI/saves
	base.Effects=nextEffects
	return base,nil
end

return Rules
