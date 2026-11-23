-- Phase 3A Awakening and 3B Legendary/Ultra second-slot Infusion.
-- All input from the player is an owned weapon UID, desired mutation family,
-- and selected ingredient UIDs. Recipes, ability rolls and validation are
-- ONLY resolved by the server. One request replaces slot 2 if it exists.
local ProfileCache=require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local LogService=require(game.ServerScriptService.Inventory.LogService)
local Costs=require(script.Parent.WeaponUpgradeCostService)
local CostRules=require(script.Parent.WeaponUpgradeCostRules)
local Rules=require(script.Parent.WeaponUpgradeRules)
local Forge=require(game.ReplicatedStorage.Shared.ForgeMutationRules)
local Dispatcher=require(game.ServerScriptService.WeaponEffects.Dispatcher)
local Progression=require(game.ServerScriptService.WeaponProgressionRules)
local BaseStation=require(game.ServerScriptService.WorldLayout.BaseStationAccess)
local ItemDataBase=require(game.ServerStorage.Items.ItemDataBase)
local StatsAggregator=require(game.ServerStorage.Items.StatsAggregator)
local Fervor=require(game.ServerScriptService.WeaponEffects.Fervor)
local Thunderstrike=require(game.ServerScriptService.WeaponEffects.Thunderstrike)
local GoldenRush=require(game.ServerScriptService.WeaponEffects.GoldenRush)
local Bloodrush=require(game.ServerScriptService.WeaponEffects.Bloodrush)
local Rampage=require(game.ServerScriptService.WeaponEffects.Rampage)

local Service={}
local random=Random.new()

local function findWeapon(data,uid)
	if type(data)~="table" or type(data.Inventory)~="table"
		or type(uid)~="string" or #uid==0 or #uid>128 then return nil end
	local saved
	for _,item in ipairs(data.Inventory) do
		if type(item)=="table" and item.UID==uid then
			if saved then return nil end
			saved=item
		end
	end
	if not saved or saved.ItemID==9001 or not Progression.IsRarity(saved.Rarity)
		or type(saved.WeaponData)~="table" then return nil end
	local info=ItemDataBase.Info[saved.ItemID]
	if not info or info.Type~="Weapon" then return nil end
	local runtime=data.Runtime
	local live=type(runtime)=="table" and type(runtime.Weapon)=="table"
		and runtime.Weapon[uid] or nil
	if type(live)~="table" or live.ItemUID~=uid
		or live.ItemID~=saved.ItemID or live.ItemType~="Weapon"
		or type(live.WeaponData)~="table"
		or (type(runtime.EphemeralWeaponUIDs)=="table"
			and runtime.EphemeralWeaponUIDs[uid]) then return nil end
	return saved,live
end

function Service.Preview(player,saved)
	local profile=ProfileCache.GetProfile(player)
	local data=profile and profile.Data
	if not data or type(saved)~="table" or type(saved.WeaponData)~="table" then
		return nil
	end
	local level=data.RunProgress and data.RunProgress.ForgeLevel or 1
	local slots,reason=Rules.ReadSlots(saved.WeaponData)
	if not slots then
		return {Reason=reason,AtForge=false}
	end
	local status={
		ForgeLevel=level,
		AtForge=BaseStation.CanUseForge(player)==true,
		Slots=slots,
		Awaken=nil,Infuse=nil,
	}
	for _,mode in ipairs({"Awaken","Infuse"}) do
		-- Family is a chosen input only at action time. Preview uses a
		-- permitted family to determine whether this mode is unlocked.
		local exampleFamily=if #slots>0 then
			(if slots[1].Family=="Golden" then "Frenzied" else "Golden")
			else "Golden"
		local allowed,why=Rules.Check(mode,saved.Rarity,saved.WeaponData,
			exampleFamily,level)
		status[mode]={
			Eligible=allowed~=nil,Reason=why,
			Replacing=allowed and allowed.Replacing or false,
			Costs=CostRules.Describe(Rules.COSTS[mode]),
		}
	end
	return status
end

local function selectedLogs(player,selection,requiredCount)
	if type(selection)~="table" or type(selection.LogUIDs)~="table"
		or #selection.LogUIDs~=requiredCount then return nil end
	local eligible={}
	for _,candidate in ipairs(LogService.GetEligibleCraftLogs(player)) do
		if type(candidate)=="table" and type(candidate.UID)=="string" then
			eligible[candidate.UID]=candidate
		end
	end
	local logs={}
	local seen={}
	for _,uid in ipairs(selection.LogUIDs) do
		if type(uid)~="string" or seen[uid] or not eligible[uid] then return nil end
		seen[uid]=true
		logs[#logs+1]=eligible[uid]
	end
	return logs
end

local function clearTransientEffects(player)
	Fervor.Clear(player)
	Thunderstrike.Clear(player)
	GoldenRush.Clear(player)
	Bloodrush.Clear(player)
	Rampage.Clear(player)
end

function Service.Attempt(player,uid,mode,family,selections)
	local profile=ProfileCache.GetProfile(player)
	local data=profile and profile.Data
	if not data or type(data.Runtime)~="table" then
		return {Reason="PROFILE_UNAVAILABLE"}
	end
	local saved,live=findWeapon(data,uid)
	if not saved then return {Reason="INVALID_WEAPON"} end
	if BaseStation.CanUseForge(player)~=true then
		return {Reason="NOT_AT_FORGE"}
	end
	local level=data.RunProgress and data.RunProgress.ForgeLevel or 1
	local check,why=Rules.Check(mode,saved.Rarity,saved.WeaponData,family,level)
	if not check then return {Reason=why} end
	if type(selections)~="table" then return {Reason="INVALID_SELECTION"} end
	local requiredLogCount
	for _,cost in ipairs(check.Costs) do
		if cost.Kind=="Logs" then requiredLogCount=cost.Count break end
	end
	local logs=selectedLogs(player,selections,requiredLogCount)
	if not logs then return {Reason="INVALID_LOG_SELECTION"} end
	local preview=Forge.Preview(logs,level)
	if not preview or preview.InvalidReason or preview.Family~=family
		or type(preview.Potency)~="number" or preview.Potency<=0 then
		return {Reason="WRONG_MUTATED_LOGS"}
	end
	-- Prepare a valid ability and next weapon record BEFORE spending a cent.
	-- No client-controlled rarity, odds, potency or effect parameters.
	local ability=Forge.Roll(preview,level,random)
	if not ability or ability.Family~=family then
		return {Reason="ABILITY_ROLL_FAILED"}
	end
	local updated,reason=Rules.Build(saved.WeaponData,mode,ability,
		saved.Rarity,level)
	if not updated then return {Reason=reason} end
	local verified=Dispatcher.List(updated)
	local expected=0
	for _,effect in ipairs(updated.Effects or {}) do
		if type(effect)=="table" then expected+=1 end
	end
	if #verified~=expected or #verified>Dispatcher.MAX_EFFECTS then
		return {Reason="INVALID_UPGRADED_EFFECTS"}
	end
	local allowed,reason2=Rules.Check(mode,saved.Rarity,saved.WeaponData,
		family,level)
	if not allowed then return {Reason=reason2} end
	local receipt,costReason=Costs.Take(player,check.Costs,selections,family)
	if not receipt then return {Reason=costReason or "PAYMENT_FAILED"} end

	-- Only replace WeaponData; rarity, XP/level, forged stats and class stay
	-- completely unchanged. Runtime and ItemWeaponData are separate copies.
	local beforeSaved=saved.WeaponData
	local beforeLive=live.WeaponData
	local beforeItem=live.ItemWeaponData
	local ok,err=pcall(function()
		saved.WeaponData=updated
		live.WeaponData=table.clone(updated)
		if type(beforeItem)=="table" then
			live.ItemWeaponData=table.clone(updated)
		end
	end)
	if not ok then
		saved.WeaponData=beforeSaved
		live.WeaponData=beforeLive
		live.ItemWeaponData=beforeItem
		local restored=Costs.Rollback(receipt)
		if not restored then
			warn("[WeaponUpgrade] transaction rollback failed for weapon",uid)
		end
		warn("[WeaponUpgrade] failed to update weapon:",err)
		return {Reason="WEAPON_UPDATE_FAILED"}
	end
	if not Costs.Finalize(receipt) then
		warn("[WeaponUpgrade] cost receipt finalization failed for weapon",uid)
		return {Reason="COST_FINALIZE_FAILED"}
	end
	clearTransientEffects(player)
	if data.Runtime.EquippedWeaponUID==uid then
		local aggregated,aggregateError=pcall(function()
			StatsAggregator.Aggregate(player)
		end)
		if not aggregated then
			warn("[WeaponUpgrade] stat refresh needs review:",aggregateError)
		end
	end
	local notified,notifyErr=pcall(function() LogService.NotifyState(player) end)
	if not notified then warn("[WeaponUpgrade] log refresh failed:",notifyErr) end
	local outcomeSlots=Rules.ReadSlots(updated)
	return {
		Reason="UPGRADED",
		Mode=mode,
		UID=uid,
		Family=family,
		AbilityId=ability.Id,
		Potency=ability.Potency,
		Replacing=check.Replacing,
		Slots=outcomeSlots,
		CoinsSpent=receipt.Plan.Coins,
		LogsSpent=#receipt.Plan.LogUIDs,
		MaterialsSpent=#receipt.Plan.MaterialUIDs,
	}
end

return Service
