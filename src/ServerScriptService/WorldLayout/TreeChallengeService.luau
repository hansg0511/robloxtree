-- A single shared visual at each entrance, independent server-owned
-- TreeObject combat state per participant. No shared HP or kill-to-unlock.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local CollectionService=game:GetService("CollectionService")
local World=require(game.ServerScriptService.WorldProgressService)
local Tree=require(game.ServerScriptService.Trees.TreeObject)
local Config=require(script.Parent.TreeChallengeConfig)
local Cancel=game.ReplicatedStorage.Economy:WaitForChild("CancelTreeChallengeRE")
local Service={}
local gates={}
local active={}
local lastStart={}
local function now() return workspace:GetServerTimeNow() end
local function rootOf(player)
	local character=player.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health<=0 or humanoid.SeatPart
		or not character:IsDescendantOf(workspace) then return nil end
	return root,character
end
local function publish(player,state,phase)
	player:SetAttribute("TreeChallengeName",state.Spec.Name)
	player:SetAttribute("TreeChallengeMaxHP",state.Spec.HP)
	player:SetAttribute("TreeChallengeHP",state.Target.HP)
	player:SetAttribute("TreeChallengeStart",state.Start)
	player:SetAttribute("TreeChallengeEnd",state.End)
	player:SetAttribute("TreeChallengeSeconds",state.Spec.Seconds)
	player:SetAttribute("TreeChallengePhase",phase)
end
local function detach(target)
	-- The shared presentation is not owned by this per-player combat record.
	Tree.ActiveTrees[target]=nil
	target.destroyed=true
	target.isDead=true
	target.model=nil
	target.InteractionPart=nil
end
local function finish(player,state,phase)
	if active[player]~=state then return end
	active[player]=nil
	if phase=="Success" then
		if now()>state.End or state.Target.HP~=0 or not state.Complete(player) then
			phase="Failed"
		end
	end
	if phase=="Success" and state.Spec.Unlock then
		require(game.ServerScriptService.LifetimeStatsRules).RecordGuardian(require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache).GetData(player),state.Spec.Unlock)
		player:SetAttribute("ForestAccess_"..state.Spec.Unlock,true)
	end
	detach(state.Target)
	if player.Parent==Players then publish(player,state,phase) end
end

-- Same entry point for a future world boss arena. Gate-specific prompt and
-- progression enforcement are outside the encounter lifecycle.
function Service.Start(player,gate,spec,complete)
	local root,character=rootOf(player)
	if not root or not World.GetEquippedRuntimeWeapon(player) or active[player]
		or not gate.model or not gate.model.Parent
		or type(complete)~="function" then return false end
	local stamp=now()
	if stamp-(lastStart[player] or -math.huge)<0.75 then return false end
	lastStart[player]=stamp
	local target=Tree.new({DefinitionId=gate.DefinitionId,Parent=gate.Parent,
		CFrame=gate.CFrame,ForestId=gate.ForestId,OwnerUserId=player.UserId})
	target.OwnerOnly=true
	target.FirstHitClaimEnabled=false
	target.UnlockForestId=nil
	target.YieldsLog=false
	target.RespawnSeconds=nil
	target.BaseHP=spec.HP
	target.MaxHP=spec.HP
	target.HP=spec.HP
	target.model=gate.model
	target.InteractionPart=gate.InteractionPart
	target.IsChallengeTarget=true
	local start=stamp+Config.PreparationSeconds
	local state={Target=target,Gate=gate,Spec=spec,Start=start,End=start+spec.Seconds,
		Character=character,Complete=complete}
	target.ChallengeCanChop=function(who)
		local currentRoot,currentCharacter=rootOf(who)
		local time=now()
		return who==player and active[player]==state and currentCharacter==character
			and currentRoot~=nil and (currentRoot.Position-gate.CFrame.Position).Magnitude<=55
			and World.CanAccessForest(who,gate.ForestId)
			and World.GetEquippedRuntimeWeapon(who)~=nil
			and time>=state.Start and time<state.End
	end
	target.ChallengeOnHit=function(who)
		if who~=player or active[player]~=state then return end
		if target.HP==0 then finish(player,state,"Success")
		else player:SetAttribute("TreeChallengeHP",target.HP) end
	end
	active[player]=state
	publish(player,state,"Preparing")
	return true
end
function Service.RegisterGuardian(gate)
	local spec=Config.Guardians[gate.DefinitionId]
	if not spec or not gate.model or not gate.InteractionPart then return false end
	-- Never let this presentation enter the damage/ordinary death path.
	gate.Choppable=false
	gate.UnlockForestId=nil
	Tree.ActiveTrees[gate]=nil
	local model=gate.model
	model:SetAttribute("GuardianUnlock",spec.Unlock)
	for _,part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part:SetAttribute("GuardianSolid",part.CanCollide)
			part.CanCollide=false
			part.CanTouch=false
		end
	end
	local anchor=Instance.new("Part")
	anchor.Name="GuardianPromptAnchor"
	anchor.Size=Vector3.new(1,1,1)
	anchor.Anchored=true
	anchor.Transparency=1
	anchor.CanCollide=false
	anchor.CanTouch=false
	anchor.CanQuery=false
	anchor.CFrame=gate.CFrame*CFrame.new(0,3,-22)
	anchor.Parent=model
	local prompt=Instance.new("ProximityPrompt")
	prompt.Name="GuardianPrompt"
	prompt.ActionText="Start Challenge"
	prompt.ObjectText=spec.Name
	prompt.MaxActivationDistance=16
	prompt.RequiresLineOfSight=false
	prompt.Parent=anchor
	prompt.Triggered:Connect(function(player)
		local root=rootOf(player)
		if not root or (root.Position-anchor.Position).Magnitude>18
			or not World.CanAccessForest(player,gate.ForestId)
			or World.CanAccessForest(player,spec.Unlock) then return end
		Service.Start(player,gate,spec,function(who)
			return World.CanAccessForest(who,gate.ForestId)
				and World.UnlockForest(who,spec.Unlock)
		end)
	end)
	CollectionService:AddTag(model,"PersonalGuardianGate")
	gates[model]={Gate=gate,Spec=spec}
	return true
end

Cancel.OnServerEvent:Connect(function(player)
	local state=active[player]
	if state then finish(player,state,"Cancelled") end
end)
Players.PlayerRemoving:Connect(function(player)
	local state=active[player]
	if state then active[player]=nil; detach(state.Target) end
	lastStart[player]=nil
end)

local elapsed=0
RunService.Heartbeat:Connect(function(dt)
	elapsed+=dt
	if elapsed<0.15 then return end
	elapsed=0
	local stamp=now()
	for player,state in pairs(active) do
		local root,character=rootOf(player)
		if not root or character~=state.Character or not state.Gate.model
			or not state.Gate.model.Parent
			or (root.Position-state.Gate.CFrame.Position).Magnitude>55 then
			finish(player,state,"Cancelled")
		elseif stamp>=state.End then
			finish(player,state,"Failed")
		elseif stamp>=state.Start and player:GetAttribute("TreeChallengePhase")=="Preparing" then
			player:SetAttribute("TreeChallengePhase","Active")
		end
	end
	-- Server-owned access enforcement complements client-only gate collision.
	-- Existing world/resource access remains authoritative even if a client
	-- modifies its local presentation. This corridor rule applies to the two
	-- current northbound World 1 entrances only.
	for model,record in pairs(gates) do
		if not model.Parent then gates[model]=nil end
	end
	for _,player in ipairs(Players:GetPlayers()) do
		local root,character=rootOf(player)
		local blocking=nil
		for model,record in pairs(gates) do
			local gate,spec=record.Gate,record.Spec
			local unlocked=World.CanAccessForest(player,spec.Unlock)
			local key="ForestAccess_"..spec.Unlock
			if player:GetAttribute(key)~=unlocked then player:SetAttribute(key,unlocked) end
			local z=gate.CFrame.Position.Z
			if model.Parent and root and not unlocked and root.Position.X<0
				and root.Position.Z>=z and (not blocking or z<blocking.CFrame.Position.Z) then
				blocking=gate
			end
		end
		if blocking and character then
			local state=active[player]
			if state then finish(player,state,"Cancelled") end
			character:PivotTo(blocking.CFrame*CFrame.new(0,5,-25))
			root.AssemblyLinearVelocity=Vector3.zero
		end
	end
end)
return Service
