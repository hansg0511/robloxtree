-- Reusable server-owned multi-resource cost adapter used by the Studio
-- Awakening/Infusion prototype. Final game economy recipes are UNDECIDED.
-- Never mistake an example material source for an approved production cost.
--
-- Usage in a single NONYIELDING weapon upgrade transaction:
--   local receipt, reason = Costs.Take(player, recipe.Costs, selections, family)
--   if not receipt then return {Reason=reason} end
--   local ok, err = pcall(function() <update saved AND runtime weapon> end)
--   if not ok then Costs.Rollback(receipt); return {Reason="UPGRADE_FAILED"} end
--   Costs.Finalize(receipt)
--
-- All quantities and material types originate in server recipe definitions.
-- The caller can only supply selected owned UIDs, never the prices.
local ProfileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local LogService = require(game.ServerScriptService.Inventory.LogService)
local Rules = require(script.Parent.WeaponUpgradeCostRules)

local Service = {}
local receipts = setmetatable({}, {__mode="k"})

local function nonnegativeInteger(n)
	return type(n)=="number" and n==n and n>=0 and n<math.huge and n%1==0
end

local function getMaterials(data, group)
	local source=data[group.Source]
	if type(source)~="table" then return nil end
	local indexed={}
	for i,record in ipairs(source) do
		if type(record)=="table" and type(record.UID)=="string" then
			if indexed[record.UID] then return nil end
			indexed[record.UID]={Record=record,Index=i}
		end
	end
	local selected={}
	for _,uid in ipairs(group.UIDs) do
		local found=indexed[uid]
		if not found or found.Record.MaterialType~=group.MaterialType then return nil end
		selected[#selected+1]=found
	end
	return selected
end

-- Fail-closed preflight. No resources are mutated until EVERY ingredient
-- is verified, including future stack balances not yet used by live gameplay.
function Service.Preview(player, recipeCosts, selections, family)
	local profile=ProfileCache.GetProfile(player)
	local data=profile and profile.Data
	if type(data)~="table" then return nil end
	return Rules.Plan(recipeCosts,data,LogService.GetEligibleCraftLogs(player),
		selections,family)
end

function Service.Take(player, recipeCosts, selections, family)
	local profile=ProfileCache.GetProfile(player)
	local data=profile and profile.Data
	if type(data)~="table" then return nil,"PROFILE_UNAVAILABLE" end
	local plan=Rules.Plan(recipeCosts,data,LogService.GetEligibleCraftLogs(player),
		selections,family)
	if not plan then return nil,"INVALID_RECIPE_OR_SELECTION" end
	if not plan.CanAfford then return nil,"INSUFFICIENT_RESOURCES" end

	local materialIndices={}
	local originalMaterialLists={}
	for _,group in ipairs(plan.MaterialGroups) do
		local located=getMaterials(data,group)
		if not located then return nil,"MATERIALS_CHANGED" end
		materialIndices[group.Source]=materialIndices[group.Source] or {}
		for _,entry in ipairs(located) do
			materialIndices[group.Source][entry.Index]=true
		end
		if not originalMaterialLists[group.Source] then
			originalMaterialLists[group.Source]=table.clone(data[group.Source])
		end
	end
	local originalCoins=data.Coins
	local originalStacks={}
	for _,deduction in ipairs(plan.StackDeductions) do
		local source=data[deduction.Source]
		local balance=type(source)=="table" and source[deduction.Id] or nil
		if not nonnegativeInteger(balance) or balance<deduction.Count then
			return nil,"MATERIALS_CHANGED"
		end
		originalStacks[#originalStacks+1]={
			Source=deduction.Source,Id=deduction.Id,Count=balance,
		}
	end
	if not nonnegativeInteger(originalCoins) or originalCoins<plan.Coins then
		return nil,"COINS_CHANGED"
	end

	-- The log API first atomically checks and removes exact owned UIDs from
	-- bag/storage (including lock/reservation rules). Other costs are only
	-- deducted if that succeeds. No yields or player callbacks are allowed.
	local takenLogs, logSources=nil,nil
	if #plan.LogUIDs>0 then
		local ok, records, sources=pcall(function()
			return LogService.TakeCraftLogUIDs(player,plan.LogUIDs,#plan.LogUIDs)
		end)
		if not ok or type(records)~="table" or #records~=#plan.LogUIDs
			or type(sources)~="table" then
			return nil,"LOGS_CHANGED"
		end
		takenLogs,logSources=records,sources
	end
	local receipt={
		Player=player,Data=data,State="Taken",
		Plan=plan,RemovedLogs=takenLogs,LogSources=logSources,
		OriginalCoins=originalCoins,
		OriginalStacks=originalStacks,
		OriginalMaterials=originalMaterialLists,
	}
	receipts[receipt]=true

	local ok,err=pcall(function()
		data.Coins=originalCoins-plan.Coins
		for _,deduction in ipairs(plan.StackDeductions) do
			local source=data[deduction.Source]
			source[deduction.Id]-=deduction.Count
		end
		for sourceName,indices in pairs(materialIndices) do
			local source=data[sourceName]
			for i=#source,1,-1 do
				if indices[i] then table.remove(source,i) end
			end
		end
	end)
	if not ok then
		warn("[WeaponUpgradeCostService] commit error, reversing cost:",err)
		local restored=Service.Rollback(receipt)
		if not restored then
			warn("[WeaponUpgradeCostService] CRITICAL: rollback incomplete; investigate affected profile")
		end
		return nil,"COST_TRANSACTION_FAILED"
	end
	return receipt,nil
end

-- Reverse an unfinalized transaction if the weapon update fails. Exact
-- input records and bag-vs-storage source maps are restored, not generic
-- replacement materials. Never allow the same receipt to refund twice.
function Service.Rollback(receipt)
	if type(receipt)~="table" or not receipts[receipt]
		or receipt.State~="Taken" then return false end
	local data=receipt.Data
	if type(data)~="table" or receipt.Player==nil then return false end
	if type(receipt.RemovedLogs)=="table" and #receipt.RemovedLogs>0 then
		local ok,restored=pcall(function()
			return LogService.RestoreCraftLogRecords(
				receipt.Player,receipt.RemovedLogs,receipt.LogSources)
		end)
		if not ok or restored~=true then
			-- Fail closed: do not also refund coins/materials while removed
			-- logs are unresolved, potentially doubling value.
			warn("[WeaponUpgradeCostService] log restore failed; transaction quarantined")
			receipt.State="QUARANTINED"
			return false
		end
	end
	data.Coins=receipt.OriginalCoins
	for _,entry in ipairs(receipt.OriginalStacks) do
		if type(data[entry.Source])=="table" then
			data[entry.Source][entry.Id]=entry.Count
		end
	end
	for sourceName,original in pairs(receipt.OriginalMaterials) do
		-- Keep existing table object for any consumers observing it.
		local container=data[sourceName]
		if type(container)=="table" then
			table.clear(container)
			for _,record in ipairs(original) do
				table.insert(container,record)
			end
		end
	end
	receipt.State="RolledBack"
	receipts[receipt]=nil
	return true
end

function Service.Finalize(receipt)
	if type(receipt)~="table" or not receipts[receipt]
		or receipt.State~="Taken" then return false end
	receipt.State="Finalized"
	receipts[receipt]=nil
	return true
end

return Service
