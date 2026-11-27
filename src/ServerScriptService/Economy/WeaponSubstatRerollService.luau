-- Server-owned two-phase paid-in-earned-gems reroll. No Robux sales yet.
-- The charged candidate is persisted on the weapon; a disconnect cannot
-- regenerate it or undo the charge. Choice never charges a second time.
local HttpService = game:GetService("HttpService")
local Profile = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local Progression = require(game.ServerScriptService.WeaponProgressionRules)
local Substats = require(game.ServerScriptService.WeaponSubstatRules)
local Config = require(game.ReplicatedStorage.Shared.PremiumEconomyConfig)
local ItemDB = require(game.ServerStorage.Items.ItemDataBase)
local Aggregator = require(game.ServerStorage.Items.StatsAggregator)
local Station = require(game.ServerScriptService.WorldLayout.BaseStationAccess)
local Costs = require(script.Parent.WeaponUpgradeCostService)
local Service = {}
local rng = Random.new()

local function integer(n)
	return type(n)=="number" and n==n and n>=0 and n<math.huge and n%1==0
end
local function sequence(data)
	return if integer(data.PassiveRerollSequence) then data.PassiveRerollSequence else 0
end
local function copy(v)
	if type(v)~="table" then return v end
	local result={}
	for k,x in pairs(v) do result[k]=copy(x) end
	return result
end
local function getWeapon(data,uid)
	if type(data)~="table" or type(data.Inventory)~="table"
		or type(uid)~="string" or #uid<1 or #uid>128 then return nil end
	local saved
	for _, item in ipairs(data.Inventory) do
		if type(item)=="table" and item.UID==uid then
			if saved then return nil end
			saved=item
		end
	end
	if not saved or saved.ItemID==9001 or not Progression.IsRarity(saved.Rarity)
		or type(saved.WeaponData)~="table" then return nil end
	local info=ItemDB.Info[saved.ItemID]
	if not info or info.Type~="Weapon" then return nil end
	local runtime=data.Runtime
	local live=type(runtime)=="table" and type(runtime.Weapon)=="table" and runtime.Weapon[uid]
	if type(live)~="table" or live.ItemUID~=uid or live.ItemID~=saved.ItemID
		or live.ItemType~="Weapon" or type(live.WeaponData)~="table"
		or (runtime.EphemeralWeaponUIDs and runtime.EphemeralWeaponUIDs[uid]) then return nil end
	return saved,live
end
local function existingSlot(saved,index)
	if not integer(index) or index<1 or index>Substats.SlotCount(saved.Rarity) then return nil end
	local slots=saved.WeaponData.PassiveSubstats
	if type(slots)~="table" then return nil end
	-- Reject a malformed sparse array instead of shifting an expensive slot.
	for i=1,index do
		if not Substats.IsValidRoll(slots[i]) then return nil end
	end
	return slots[index]
end
local function pendingPreview(saved)
	local p=saved.WeaponData.PassiveRerollPending
	if type(p)~="table" then return nil end
	if type(p.Token)~="string" or #p.Token==0 or #p.Token>128
		or not integer(p.Cost) or p.Cost<1 or not Substats.IsValidRoll(p.Old)
		or not Substats.IsValidRoll(p.Candidate) then return {Invalid=true} end
	local old=existingSlot(saved,p.Slot)
	if not old or old.Id~=p.Old.Id or old.BaseValue~=p.Old.BaseValue then return {Invalid=true} end
	return {Token=p.Token,Slot=p.Slot,Cost=p.Cost,
		Old=Substats.DescribeRoll(saved,p.Old),Candidate=Substats.DescribeRoll(saved,p.Candidate)}
end
function Service.Preview(player,saved)
	if type(saved)~="table" or type(saved.WeaponData)~="table" then return nil end
	local price=Config.SUBSTAT_REROLL[saved.Rarity]
	if not price then return nil end
	local profile=Profile.GetProfile(player)
	local data=profile and profile.Data
	local balance=data and data.MaterialBalances and data.MaterialBalances[Config.PREMIUM] or 0
	return {Price=price,Balance=balance,AtForge=Station.CanUseForge(player)==true,
		Sequence=sequence(saved.WeaponData),Pending=pendingPreview(saved)}
end
local function install(saved,live,nextData)
	local nextLive=copy(nextData)
	local nextItem=if type(live.ItemWeaponData)=="table" then copy(nextData) else live.ItemWeaponData
	saved.WeaponData=nextData
	live.WeaponData=nextLive
	live.ItemWeaponData=nextItem
end
function Service.Attempt(player,uid,mode,indexOrToken,expectedOrChoice)
	local profile=Profile.GetProfile(player)
	local data=profile and profile.Data
	local saved,live=getWeapon(data,uid)
	if not saved then return {Reason="INVALID_WEAPON"} end
	local before=saved.WeaponData
	if mode=="Roll" then
		if Station.CanUseForge(player)~=true then return {Reason="NOT_AT_FORGE"} end
		if before.PassiveRerollPending~=nil then return {Reason="PENDING_CHOICE"} end
		if not integer(expectedOrChoice) or expectedOrChoice~=sequence(before) then return {Reason="STALE_REQUEST"} end
		local old=existingSlot(saved,indexOrToken)
		local price=Config.SUBSTAT_REROLL[saved.Rarity]
		if not old or not integer(price) or price<1 then return {Reason="INVALID_SLOT"} end
		local nextData=table.clone(before)
		nextData.PassiveRerollSequence=sequence(before)+1
		nextData.PassiveRerollPending={Token=HttpService:GenerateGUID(false),
			Slot=indexOrToken,Cost=price,Old=copy(old),Candidate=Substats.Roll(rng)}
		local receipt,why=Costs.Take(player,{{Kind="Stack",Source="MaterialBalances",Id=Config.PREMIUM,Count=price}},{})
		if not receipt then return {Reason=why or "PAYMENT_FAILED"} end
		local ok,err=pcall(install,saved,live,nextData)
		if not ok then Costs.Rollback(receipt); warn("[SubstatReroll] install failed",err); return {Reason="WEAPON_UPDATE_FAILED"} end
		Costs.Finalize(receipt)
		return {Reason="ROLLED",UID=uid,Spent=price}
	elseif mode=="Choose" then
		-- Resolve an already purchased choice anywhere, including after a rejoin.
		local p=before.PassiveRerollPending
		local preview=pendingPreview(saved)
		if type(preview)~="table" or preview.Invalid or type(p)~="table"
			or type(indexOrToken)~="string" or indexOrToken~=p.Token
			or (expectedOrChoice~="Keep" and expectedOrChoice~="Accept") then
			return {Reason="INVALID_CHOICE"}
		end
		local nextData=table.clone(before)
		if expectedOrChoice=="Accept" then
			local slots=copy(before.PassiveSubstats)
			slots[p.Slot]=copy(p.Candidate)
			nextData.PassiveSubstats=slots
		end
		nextData.PassiveRerollPending=nil
		install(saved,live,nextData)
		if data.Runtime.EquippedWeaponUID==uid then
			local ok,err=pcall(Aggregator.Aggregate,player)
			if not ok then warn("[SubstatReroll] aggregate failed",err) end
		end
		return {Reason=if expectedOrChoice=="Accept" then "ACCEPTED" else "KEPT",UID=uid}
	end
	return {Reason="INVALID_REQUEST"}
end
return Service
