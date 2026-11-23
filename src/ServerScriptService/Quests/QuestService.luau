-- Server-authoritative, one-time quest vertical slice. Progress is
-- recorded ONLY by verified server gameplay callbacks, never client events.
-- Daily/Weekly categories have no tasks, resets, wallet or rewards yet.
local Players=game:GetService("Players")
local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Profiles=require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local Rules=require(script.Parent.QuestRules)
local ShopRules=require(game.ServerScriptService.Grove.SaplingShopRules)
local QuestsFolder=ReplicatedStorage:WaitForChild("Quests")
local GetQuestStateRF=QuestsFolder:WaitForChild("GetQuestStateRF")
local QuestStateUpdatedRE=QuestsFolder:WaitForChild("QuestStateUpdatedRE")
local ClaimQuestRE=QuestsFolder:WaitForChild("ClaimQuestRE")

local Service={}
local started=false
local revisionByPlayer={}
local lastClaimAt=setmetatable({},{__mode="k"})
local processedWildTrees=setmetatable({},{__mode="k"})

local function playerData(player)
	if typeof(player)~="Instance" or not player:IsA("Player")
		or not player:IsDescendantOf(Players) then return nil end
	local profile=Profiles.GetProfile(player)
	if not profile or type(profile.Data)~="table" then return nil end
	Profiles.NormalizeQuestProgress(profile.Data)
	return profile.Data
end

local function makeState(player)
	local data=playerData(player)
	if not data then return nil end
	local progress=Rules.Normalize(data.QuestProgress)
	local definition=Rules.Story[progress.Stage]
	local state={
		Revision=revisionByPlayer[player] or 0,
		Category=Rules.Categories.Story,
		Stage=progress.Stage,
		TotalStages=#Rules.Story,
		Completed=definition==nil,
		-- Only the campaign is implemented. Daily/Weekly are disabled
		-- until their reward economy/reset policy is approved.
		DailyEnabled=false,
		WeeklyEnabled=false,
	}
	if definition then
		state.Id=definition.Id
		state.Title=definition.Title
		state.Description=definition.Description
		state.Count=progress.Count
		state.Target=definition.Target
		state.CanClaim=Rules.Ready(progress)
		state.Reward=definition.Reward.Label
		state.RewardKind=definition.Reward.Kind
	end
	return state
end

function Service.GetState(player)
	return makeState(player)
end

local function publish(player)
	revisionByPlayer[player]=(revisionByPlayer[player] or 0)+1
	local snapshot=makeState(player)
	if snapshot then
		-- A UI/remote delivery failure must never turn an already-granted
		-- unique sapling + claimed quest into an apparent server failure.
		local ok,err=pcall(function()
			QuestStateUpdatedRE:FireClient(player,snapshot)
		end)
		if not ok then warn("[Quests] State delivery failed",err) end
	end
end

local function creditEvent(player,event)
	local data=playerData(player)
	if not data then return false end
	local advanced,changed=Rules.Advance(data.QuestProgress,event,1)
	if not changed then return false end
	data.QuestProgress=advanced
	publish(player)
	return true
end

function Service.RecordWildTreeChopped(player,treeObject)
	if type(treeObject)~="table" or treeObject.IsPersistentGrove==true
		or treeObject.isDead~=true or treeObject.YieldsLog~=true
		or processedWildTrees[treeObject] then return false end
	-- TreeObject:Die calls this after it has validated the death and
	-- resolved the same winner as the server's normal log award path.
	processedWildTrees[treeObject]=true
	return creditEvent(player,"WildTreeChopped")
end

function Service.RecordGroveHarvested(player,groveTreeUID,harvestCount)
	if type(groveTreeUID)~="string" or #groveTreeUID==0
		or type(harvestCount)~="number" or harvestCount%1~=0
		or harvestCount<1 then return false end
	-- Only GroveService.HarvestPersistentTree invokes this after granting
	-- a stored log and committing the next growth cycle.
	return creditEvent(player,"GroveHarvested")
end

local function newSaplingUID(data)
	local function used(uid)
		for _,key in ipairs({"Saplings","GroveTrees","GroveMaterials","Logs","StoredLogs"}) do
			for _,row in ipairs(type(data[key])=="table" and data[key] or {}) do
				if type(row)=="table" and (row.UID==uid
					or row.SourceSaplingUID==uid or row.SourceGroveTreeUID==uid) then
					return true
				end
			end
		end
		return false
	end
	for _=1,8 do
		local uid=HttpService:GenerateGUID(false)
		if type(uid)=="string" and #uid>0 and not used(uid) then return uid end
	end
	return nil
end

function Service.Claim(player,questId)
	local data=playerData(player)
	if not data or type(data.Saplings)~="table" then
		return false,"PROFILE_UNAVAILABLE"
	end
	local progress=Rules.Normalize(data.QuestProgress)
	local definition=Rules.Story[progress.Stage]
	-- Client must name the exact active quest. Stale or replayed requests
	-- cannot accidentally claim a DIFFERENT stage later.
	if type(questId)~="string" or not definition or questId~=definition.Id then
		return false,"INVALID_QUEST"
	end
	local nextProgress=Rules.NextAfterClaim(progress)
	if not nextProgress then return false,"NOT_COMPLETE" end
	if #data.Saplings>=ShopRules.MAX_UNPLANTED_SAPLINGS then
		return false,"SAPLING_STORAGE_FULL"
	end
	local reward=definition.Reward
	if reward.Kind~="Sapling" then return false,"REWARD_NOT_CONFIGURED" end
	local uid=newSaplingUID(data)
	if not uid then return false,"UID_UNAVAILABLE" end
	local record={
		UID=uid,
		SpeciesId=reward.SpeciesId,
		Mutations=table.clone(reward.Mutations),
		SizePotential=reward.SizePotential,
		CreatedAt=os.time(),
	}
	-- Nonyielding commit of exactly ONE reward and the stage transition.
	-- Same-quest replays fail, because the active stage changes immediately.
	table.insert(data.Saplings,record)
	data.QuestProgress=nextProgress
	publish(player)
	-- Notify the Grove's existing state stream so a newly earned
	-- sapling appears without a UI reload. No hard require cycle at boot.
	local ok,err=pcall(function()
		require(game.ServerScriptService.Grove.GroveService).NotifyState(player)
	end)
	if not ok then warn("[Quests] Grove reward refresh failed",err) end
	return true,"CLAIMED",definition.Reward.Label
end

function Service.Start()
	if started then return end
	started=true
	GetQuestStateRF.OnServerInvoke=function(player,...)
		if select("#",...)~=0 then return nil end
		return Service.GetState(player)
	end
	ClaimQuestRE.OnServerEvent:Connect(function(player,questId,...)
		if select("#",...)~=0 or type(questId)~="string" or #questId>80 then return end
		local now=os.clock()
		if now-(lastClaimAt[player] or -math.huge)<0.35 then return end
		lastClaimAt[player]=now
		local ok,claimed,reason,reward=pcall(Service.Claim,player,questId)
		if not ok then
			warn("[Quests] Claim failed",claimed)
			ClaimQuestRE:FireClient(player,{Success=false,Reason="SERVER_ERROR"})
			return
		end
		ClaimQuestRE:FireClient(player,{
			Success=claimed==true,Reason=reason,Reward=reward,QuestId=questId,
		})
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastClaimAt[player]=nil
		revisionByPlayer[player]=nil
	end)
end

return Service
