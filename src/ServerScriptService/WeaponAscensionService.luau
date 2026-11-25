-- Phase 1D: one server-authoritative ascension transaction.
-- Never accepts client-provided prices, odds, materials, rarity or XP.
local ProfileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local LogService = require(game.ServerScriptService.Inventory.LogService)
local BaseStationAccess = require(game.ServerScriptService.WorldLayout.BaseStationAccess)
local ItemDataBase = require(game.ServerStorage.Items.ItemDataBase)
local StatsAggregator = require(game.ServerStorage.Items.StatsAggregator)
local Progression = require(game.ServerScriptService.WeaponProgressionRules)
local Ascension = require(game.ServerScriptService.WeaponAscensionRules)
local Slots=require(game.ServerScriptService.Economy.WeaponUpgradeRules)
local Economy=require(game.ReplicatedStorage.Shared.PremiumEconomyConfig)
local Costs=require(game.ServerScriptService.Economy.WeaponUpgradeCostService)
local Config=require(game.ReplicatedStorage.Shared.ProgressionConfig)

local Service = {}
local rng = Random.new()

local function isFiniteMoney(value)
	return type(value) == "number" and value == value
		and value >= 0 and value < math.huge
end

local function getUniqueWeapon(data, uid)
	if type(data) ~= "table" or type(data.Inventory) ~= "table"
		or type(uid) ~= "string" or #uid < 1 or #uid > 128 then return nil end
	local result
	for _, item in ipairs(data.Inventory) do
		if type(item) == "table" and item.UID == uid then
			if result then return nil end -- duplicate saved UID: fail closed
			result = item
		end
	end
	if not result or result.ItemID == 9001
		or not ItemDataBase.Info[result.ItemID]
		or ItemDataBase.Info[result.ItemID].Type ~= "Weapon"
		or not Progression.IsRarity(result.Rarity)
		or type(result.WeaponData) ~= "table" then
		return nil
	end
	local runtime = data.Runtime
	local live = type(runtime) == "table" and type(runtime.Weapon) == "table"
		and runtime.Weapon[uid] or nil
	if type(live) ~= "table" or live.ItemUID ~= uid
		or live.ItemID ~= result.ItemID or live.ItemType ~= "Weapon"
		or type(live.WeaponData) ~= "table"
		or (runtime.EphemeralWeaponUIDs and runtime.EphemeralWeaponUIDs[uid]) then
		return nil
	end
	return result, live
end

local function hasMutation(material)
	-- Favor valuable/rare logs: never automatically consume any log with
	-- mutation metadata, even if the prototype does not yet activate it.
	if type(material.Mutations) ~= "table" then return material.Mutations ~= nil end
	return next(material.Mutations) ~= nil
end

-- Ordinary unlocked carry-bag logs only. Protected storage and mutated
-- logs are intentionally excluded; weakest/smallest are chosen first.
-- Pure filter also used by the smoke test with synthetic snapshots.
function Service.SelectOrdinaryBagLogs(candidates)
	local logs = {}
	for _, log in ipairs(type(candidates) == "table" and candidates or {}) do
		if type(log) == "table" and log.Source == "Bag"
			and type(log.UID) == "string"
			and type(log.CraftPowerBonus) == "number"
			and not hasMutation(log) then
			logs[#logs + 1] = log
		end
	end
	table.sort(logs, function(a, b)
		local strengthA = type(a.CraftPowerBonus) == "number" and a.CraftPowerBonus or math.huge
		local strengthB = type(b.CraftPowerBonus) == "number" and b.CraftPowerBonus or math.huge
		if strengthA ~= strengthB then return strengthA < strengthB end
		local sizeA = type(a.SizeScale) == "number" and a.SizeScale or math.huge
		local sizeB = type(b.SizeScale) == "number" and b.SizeScale or math.huge
		if sizeA ~= sizeB then return sizeA < sizeB end
		return a.UID < b.UID
	end)
	return logs
end

function Service.EligibleLogs(player)
	return Service.SelectOrdinaryBagLogs(LogService.GetEligibleCraftLogs(player))
end

function Service.Preview(player, item, eligibleCount)
	if type(item) ~= "table" or item.ItemID == 9001
		or not Progression.IsRarity(item.Rarity) then return nil end
	local profile = ProfileCache.GetProfile(player)
	local data = profile and profile.Data
	local forgeLevel=data and data.RunProgress and data.RunProgress.ForgeLevel or 1
	local snapshot=Ascension.Preview(item.Rarity,type(item.WeaponData)=="table" and item.WeaponData.Progression or nil,forgeLevel)
	if not snapshot then return nil end
	local coins = data and data.Coins
	local atForge = BaseStationAccess.CanUseForge(player) == true
	local available = if type(eligibleCount) == "number" then eligibleCount
		else #Service.EligibleLogs(player)
	snapshot.EligibleLogs = available
	snapshot.CrystalBalance=data and data.MaterialBalances and data.MaterialBalances[Economy.CRYSTAL] or 0
	snapshot.CanAfford = isFiniteMoney(coins) and coins >= snapshot.Coins
		and available >= snapshot.Logs and snapshot.CrystalBalance>=snapshot.Crystals
	snapshot.AtForge = atForge
	snapshot.CanAscend = snapshot.Ready and snapshot.ForgeUnlocked and snapshot.CanAfford and atForge
	return snapshot
end

-- Returns one safe result for the caller to send to the requesting player.
-- Invariant: all eligibility and resource checks happen before any mutation.
function Service.Attempt(player, uid)
	local profile = ProfileCache.GetProfile(player)
	local data = profile and profile.Data
	if not data or type(data.Runtime) ~= "table" then
		return { Reason = "PROFILE_UNAVAILABLE" }
	end
	local saved, live = getUniqueWeapon(data, uid)
	if not saved then return { Reason = "INVALID_WEAPON" } end
	local forgeLevel=data.RunProgress and data.RunProgress.ForgeLevel or 1
	local preview = Ascension.Preview(saved.Rarity, saved.WeaponData.Progression,forgeLevel)
	if not preview then return { Reason = "MAX_RARITY" } end
	if not preview.Ready then return { Reason = "NOT_MAX_LEVEL" } end
	if not preview.ForgeUnlocked then return { Reason="FORGE_RARITY_LOCKED", RequiredForge=preview.RequiredForge } end
	if BaseStationAccess.CanUseForge(player) ~= true then
		return { Reason = "NOT_AT_FORGE" }
	end
	if not isFiniteMoney(data.Coins) or data.Coins < preview.Coins then
		return { Reason = "NOT_ENOUGH_COINS" }
	end

	if not data.MaterialBalances or (data.MaterialBalances[Economy.CRYSTAL] or 0)<preview.Crystals then return {Reason="NOT_ENOUGH_CRYSTALS"} end
	local available = Service.EligibleLogs(player)
	if #available < preview.Logs then return { Reason = "NOT_ENOUGH_LOGS" } end
	local selectedUIDs = {}
	for i = 1, preview.Logs do selectedUIDs[i] = available[i].UID end

	-- Resolve the outcome once, prior to charging anything. Pity is checked
	-- in the pure rules; the client cannot set the draw or request a reroll.
	local outcome = Ascension.Resolve(saved.Rarity,
		saved.WeaponData.Progression, rng:NextNumber(),forgeLevel)
	if not outcome then return { Reason = "ROLL_FAILED" } end

	-- Generate before charging. Both failure and success consume crystals.
	local nextData=table.clone(saved.WeaponData)
	nextData.Progression=outcome.Progression
	if outcome.Success and Config.HasSecondSlot(outcome.Rarity) then
		local granted,reason=Slots.GrantSecond(nextData,outcome.Rarity,forgeLevel,rng)
		if not granted then return {Reason=reason or "ROLL_FAILED"} end
		nextData=granted
	end
	local recipe={{Kind="Coins",Amount=preview.Coins},{Kind="Logs",Count=preview.Logs},
		{Kind="Stack",Source="MaterialBalances",Id=Economy.CRYSTAL,Count=preview.Crystals}}
	local receipt,reason=Costs.Take(player,recipe,{LogUIDs=selectedUIDs})
	if not receipt then return {Reason=reason or "LOGS_UNAVAILABLE"} end
	local oldRarity,oldSaved,oldLive,oldItem=saved.Rarity,saved.WeaponData,live.WeaponData,live.ItemWeaponData
	local function copy(v)
		if type(v)~="table" then return v end
		local t={} for k,x in pairs(v) do t[k]=copy(x) end return t
	end
	local ok,err=pcall(function()
		saved.Rarity=outcome.Rarity
		saved.WeaponData=nextData
		live.ItemRarity=outcome.Rarity
		live.WeaponData=copy(nextData)
		if type(oldItem)=="table" then live.ItemWeaponData=copy(nextData) end
	end)
	if not ok then
		saved.Rarity=oldRarity; saved.WeaponData=oldSaved
		live.ItemRarity=oldRarity; live.WeaponData=oldLive; live.ItemWeaponData=oldItem
		Costs.Rollback(receipt)
		warn("[Ascension] update failed",err)
		return {Reason="WEAPON_UPDATE_FAILED"}
	end
	Costs.Finalize(receipt)

	if data.Runtime.EquippedWeaponUID == uid then
		local ok, err = pcall(function() StatsAggregator.Aggregate(player) end)
		if not ok then warn("[Ascension] equipped stat refresh failed:", err) end
	end
	local updated = Ascension.Preview(saved.Rarity, saved.WeaponData.Progression,forgeLevel)
	-- The reward is already committed: cosmetic notifications must not
	-- retroactively turn a success into a free retry.
	local notifyOk, notifyError = pcall(function() LogService.NotifyState(player) end)
	if not notifyOk then warn("[Ascension] log refresh failed:", notifyError) end
	return {
		Reason = "ATTEMPT_RESOLVED",
		UID = uid,
		Success = outcome.Success,
		From = preview.From,
		To = preview.To,
		Rarity = saved.Rarity,
		Level = outcome.Progression.Level,
		CoinsSpent = preview.Coins,
		CrystalsSpent=preview.Crystals,
		LogsSpent = preview.Logs,
		Failures = outcome.Progression.AscensionFailures,
		AttemptsUntilGuarantee = updated and updated.AttemptsUntilGuarantee or 0,
	}
end

return Service
