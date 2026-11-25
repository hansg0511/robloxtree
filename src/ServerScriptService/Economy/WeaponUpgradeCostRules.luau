-- Phase 3 upgrade recipe COST contract (pure, no mutations).
-- Awakening and Infusion share one extensible ingredient schema.
--
-- IMPORTANT: a preview is never a spending authorization. A future server
-- transaction must resolve UIDs again against authoritative LogService and
-- verify all inputs immediately before an all-or-nothing commit.
--
-- Schema example ONLY, not a real recipe or approved material source:
-- {
--   { Kind = "Coins", Amount = 1000 },
--   { Kind = "Logs", Count = 3, MutationFamily = "$selected" },
--   { Kind = "Material", Source = "GroveMaterials", MaterialType = "unselected_future_type", Count = 1 },
--   { Kind = "Stack", Source = "AxeHeads", Id = "copper_head", Count = 1 },
--   { Kind = "Stack", Source = "MaterialBalances", Id = "future_essence", Count = 2 },
-- }
-- Schema supports adding new keyed material inventories via validated adapters
-- rather than having separate hardcoded awakening-specific cost checks.
local Rules = {}
local Forge=require(game.ReplicatedStorage.Shared.ForgeMutationRules)

Rules.MAX_INGREDIENTS = 16
Rules.MAX_PER_INGREDIENT = 96
Rules.ALLOWED_STACK_SOURCES = { AxeHeads = true, MaterialBalances = true }
Rules.ALLOWED_UID_SOURCES = { GroveMaterials = true }

local function integer(n)
	return type(n)=="number" and n==n and n>=0 and n<math.huge and n%1==0
end
local function validId(id)
	return type(id)=="string" and #id>0 and #id<=80
		and not id:find("[%c]")
end
local function denseLength(list)
	if type(list)~="table" then return nil end
	local count=0
	local maxIndex=0
	for k in pairs(list) do
		if not integer(k) or k<1 then return nil end
		count+=1
		if k>maxIndex then maxIndex=k end
	end
	-- Counting present numeric keys rather than trusting Luau's length
	-- operator rejects table.create(...) arrays with deleted interior entries.
	if count~=maxIndex then return nil end
	return maxIndex
end
local function copyCost(row)
	local out={}
	for key,value in pairs(row) do out[key]=value end
	return out
end

function Rules.Validate(costs)
	local n=denseLength(costs)
	if not n or n<1 or n>Rules.MAX_INGREDIENTS then return false end
	local seen={}
	local logGroups=0
	for _,c in ipairs(costs) do
		if type(c)~="table" then return false end
		local kind=c.Kind
		local key
		if kind=="Coins" then
			if not integer(c.Amount) or c.Amount<1 or c.Amount>1000000000 then return false end
			key="Coins"
		elseif kind=="Logs" then
			if not integer(c.Count) or c.Count<1 or c.Count>Rules.MAX_PER_INGREDIENT then return false end
			if c.MutationFamily~=nil and c.MutationFamily~="$selected"
				and not table.find(Forge.FAMILIES,c.MutationFamily) then return false end
			logGroups+=1
			if logGroups>1 then return false end -- one log selection, one family
			key="Logs"
		elseif kind=="Material" then
			if not Rules.ALLOWED_UID_SOURCES[c.Source]
				or not validId(c.MaterialType)
				or not integer(c.Count) or c.Count<1
				or c.Count>Rules.MAX_PER_INGREDIENT then return false end
			key="Material:"..c.Source..":"..c.MaterialType
		elseif kind=="Stack" then
			if not Rules.ALLOWED_STACK_SOURCES[c.Source] or not validId(c.Id)
				or not integer(c.Count) or c.Count<1
				or c.Count>1000000 then return false end
			key="Stack:"..c.Source..":"..c.Id
		else
			return false -- no implicit free/unrecognized cost kind
		end
		if seen[key] then return false end
		seen[key]=true
	end
	return true
end

-- Returns a display-safe preview of *every* ingredient, regardless of what
-- the player owns. The UI must not hide unavailable other-material costs.
function Rules.Describe(costs)
	if not Rules.Validate(costs) then return nil end
	local preview={}
	for _,c in ipairs(costs) do
		preview[#preview+1]=copyCost(c)
	end
	return preview
end

local function availableLog(record, family)
	if type(record)~="table" or not validId(record.UID)
		or type(record.SizeScale)~="number" or record.SizeScale<=0 then return false end
	if not family then return true end
	local mutation=record.Mutations
	return type(mutation)=="table" and mutation[family]==true
end
local function validateSelection(selection, expected)
	if denseLength(selection)~=expected then return false end
	local seen={}
	for _,uid in ipairs(selection) do
		if not validId(uid) or seen[uid] then return false end
		seen[uid]=true
	end
	return true
end

-- data = authoritative profile snapshot, eligibleLogs = LogService's
-- filtered eligible *bag and storage* logs, selections = trusted server
-- copies of client UID lists only (client never supplies prices or types).
-- Never changes data. A missing or unsupported resource makes CanAfford false.
function Rules.Plan(costs, data, eligibleLogs, selections, selectedFamily)
	if not Rules.Validate(costs) or type(data)~="table"
		or type(selections)~="table" then return nil end
	local plan={
		CanAfford=true, Missing={}, Coins=0, LogUIDs={},
		MaterialUIDs={}, MaterialGroups={}, StackDeductions={},
		Ingredients=Rules.Describe(costs),
	}
	local ownedLogs={}
	for _,log in ipairs(type(eligibleLogs)=="table" and eligibleLogs or {}) do
		if type(log)=="table" and validId(log.UID) and not ownedLogs[log.UID] then
			ownedLogs[log.UID]=log
		end
	end
	for _,c in ipairs(costs) do
		if c.Kind=="Coins" then
			plan.Coins=c.Amount
			if not integer(data.Coins) or data.Coins<c.Amount then
				plan.CanAfford=false
				plan.Missing[#plan.Missing+1]="Coins"
			end
		elseif c.Kind=="Logs" then
			local family=if c.MutationFamily=="$selected"
				then selectedFamily else c.MutationFamily
			if c.MutationFamily=="$selected"
				and not table.find(Forge.FAMILIES,family) then return nil end
			local selection=selections.LogUIDs
			if not validateSelection(selection,c.Count) then return nil end
			for _,uid in ipairs(selection) do
				if not availableLog(ownedLogs[uid],family) then
					plan.CanAfford=false
					plan.Missing[#plan.Missing+1]="Logs"
					break
				end
			end
			plan.LogUIDs=table.clone(selection)
		elseif c.Kind=="Material" then
			local container=data[c.Source]
			if type(container)~="table" then
				plan.CanAfford=false
				plan.Missing[#plan.Missing+1]=c.MaterialType
				continue
			end
			-- Supports multiple distinct unique-material ingredients. Client
			-- sends exact UIDs per (source,type); type/count always server-owned.
			local map=selections.MaterialUIDsByType
			local selected=if type(map)=="table" then
				(map[c.Source..":"..c.MaterialType] or map[c.MaterialType])
				else selections.MaterialUIDs
			if not validateSelection(selected,c.Count) then return nil end
			local seen={}
			for _,record in ipairs(container) do
				if type(record)=="table" and validId(record.UID)
					and not seen[record.UID] then
					seen[record.UID]=record
				end
			end
			for _,uid in ipairs(selected) do
				local record=seen[uid]
				if not record or record.MaterialType~=c.MaterialType then
					plan.CanAfford=false
					plan.Missing[#plan.Missing+1]=c.MaterialType
					break
				end
			end
			local group={Source=c.Source,MaterialType=c.MaterialType,UIDs=table.clone(selected)}
			plan.MaterialGroups[#plan.MaterialGroups+1]=group
			for _,uid in ipairs(selected) do
				plan.MaterialUIDs[#plan.MaterialUIDs+1]=uid
			end
		elseif c.Kind=="Stack" then
			local source=data[c.Source]
			local count=type(source)=="table" and source[c.Id] or nil
			if not integer(count) or count<c.Count then
				plan.CanAfford=false
				plan.Missing[#plan.Missing+1]=c.Id
			end
			plan.StackDeductions[#plan.StackDeductions+1]={
				Source=c.Source,Id=c.Id,Count=c.Count,
			}
		end
	end
	-- A UID may not be spent twice even if multiple source adapters are
	-- accidentally given overlapping identifiers.
	local seen={}
	for _,uids in ipairs({plan.LogUIDs,plan.MaterialUIDs}) do
		for _,uid in ipairs(uids) do
			if seen[uid] then return nil end
			seen[uid]=true
		end
	end
	return plan
end

return Rules
