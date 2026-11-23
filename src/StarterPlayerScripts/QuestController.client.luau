-- Minimal one-time story-quest UI. No daily/weekly loops or premium wallet
-- until their reset, reward and currency policies are approved.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local remotes=ReplicatedStorage:WaitForChild("Quests")
local getState=remotes:WaitForChild("GetQuestStateRF")
local updated=remotes:WaitForChild("QuestStateUpdatedRE")
local claim=remotes:WaitForChild("ClaimQuestRE")

local gui=Instance.new("ScreenGui")
gui.Name="QuestVerticalSlice"
gui.ResetOnSpawn=false
gui.DisplayOrder=19
gui.IgnoreGuiInset=true
gui.Parent=playerGui

local function button(parent,name,text,pos,size)
	local b=Instance.new("TextButton")
	b.Name=name
	b.Text=text
	b.Position=pos
	b.Size=size
	b.BorderSizePixel=0
	b.Font=Enum.Font.GothamBold
	b.TextSize=13
	b.TextColor3=Color3.fromRGB(245,242,222)
	b.BackgroundColor3=Color3.fromRGB(51,97,67)
	b.Parent=parent
	local corner=Instance.new("UICorner")
	corner.CornerRadius=UDim.new(0,8)
	corner.Parent=b
	return b
end
local function label(parent,name,text,pos,size,weight,fontSize)
	local l=Instance.new("TextLabel")
	l.Name=name
	l.Text=text
	l.Position=pos
	l.Size=size
	l.BackgroundTransparency=1
	l.Font=weight or Enum.Font.Gotham
	l.TextSize=fontSize or 13
	l.TextColor3=Color3.fromRGB(236,240,220)
	l.TextXAlignment=Enum.TextXAlignment.Left
	l.TextYAlignment=Enum.TextYAlignment.Top
	l.TextWrapped=true
	l.Parent=parent
	return l
end

local toggle=button(gui,"QuestToggle","QUESTS",UDim2.new(1,-139,1,-60),UDim2.fromOffset(120,36))
local panel=Instance.new("Frame")
panel.Name="QuestPanel"
panel.AnchorPoint=Vector2.new(1,1)
panel.Position=UDim2.new(1,-19,1,-106)
panel.Size=UDim2.fromOffset(345,251)
panel.BackgroundColor3=Color3.fromRGB(20,31,25)
panel.BackgroundTransparency=0.03
panel.BorderSizePixel=0
panel.Visible=false
panel.Parent=gui
local corner=Instance.new("UICorner")
corner.CornerRadius=UDim.new(0,10)
corner.Parent=panel
local stroke=Instance.new("UIStroke")
stroke.Color=Color3.fromRGB(108,146,106)
stroke.Transparency=0.18
stroke.Parent=panel

local heading=label(panel,"Heading","STORY QUESTS",UDim2.fromOffset(13,10),UDim2.fromOffset(315,24),Enum.Font.GothamBold,15)
local title=label(panel,"Title","Loading...",UDim2.fromOffset(13,42),UDim2.fromOffset(315,24),Enum.Font.GothamBold,15)
local objective=label(panel,"Objective","",UDim2.fromOffset(13,71),UDim2.fromOffset(315,45),Enum.Font.Gotham,13)
local progress=label(panel,"Progress","",UDim2.fromOffset(13,124),UDim2.fromOffset(315,22),Enum.Font.GothamMedium,13)
local reward=label(panel,"Reward","",UDim2.fromOffset(13,146),UDim2.fromOffset(315,24),Enum.Font.GothamMedium,13)
local claimButton=button(panel,"ClaimStoryReward","NOT READY",UDim2.fromOffset(13,176),UDim2.fromOffset(319,38))
local future=label(panel,"FutureTasks","Daily / Weekly: planned • No active rewards yet",
	UDim2.fromOffset(13,223),UDim2.fromOffset(315,20),Enum.Font.Gotham,11)
future.TextColor3=Color3.fromRGB(161,179,159)

local current
local revision=-1
local claimPending=false
local fetching=false
local opened=false
local destroyed=false
local feedbackText

local function syncVisible()
	local modal=playerGui:GetAttribute("EconomyModalOpen")==true
	toggle.Visible=not modal
	panel.Visible=opened and not modal
end
playerGui:GetAttributeChangedSignal("EconomyModalOpen"):Connect(syncVisible)

local function render()
	local state=current
	future.Text=feedbackText or "Daily / Weekly: planned • No active rewards yet"
	future.TextColor3=if feedbackText then Color3.fromRGB(251,181,135)
		else Color3.fromRGB(161,179,159)
	if not state then
		title.Text="Quest state loading..."
		objective.Text="Progress comes from verified chopping and Grove harvesting."
		progress.Text=""
		reward.Text=""
		claimButton.Text="NOT READY"
		claimButton.Active=false
	elseif state.Completed then
		heading.Text="STORY QUESTS  •  COMPLETE"
		title.Text="You're a Grove Keeper!"
		objective.Text="Both introductory quests are complete. More quests will come later."
		progress.Text="2 / 2 stages complete"
		reward.Text=""
		claimButton.Text="ALL CLAIMED"
		claimButton.Active=false
	else
		heading.Text=string.format("STORY QUESTS  •  %d / %d",
			state.Stage or 1,state.TotalStages or 2)
		title.Text=tostring(state.Title or "Story quest")
		objective.Text=tostring(state.Description or "")
		progress.Text=string.format("PROGRESS: %d / %d",
			state.Count or 0,state.Target or 1)
		reward.Text="REWARD: "..tostring(state.Reward or "Sapling")
		local ready=state.CanClaim==true and not claimPending
		claimButton.Active=ready
		claimButton.Text=if claimPending then "CLAIMING..."
			else if ready then "CLAIM REWARD"
			else "COMPLETE OBJECTIVE TO CLAIM"
	end
	claimButton.AutoButtonColor=claimButton.Active
	claimButton.BackgroundColor3=if claimButton.Active
		then Color3.fromRGB(65,123,69) else Color3.fromRGB(77,83,78)
	toggle.Text=if state and state.CanClaim then "QUEST READY!" else "QUESTS"
end

local function applyState(snapshot)
	if destroyed or type(snapshot)~="table" then return end
	local nextRevision=snapshot.Revision
	if type(nextRevision)=="number" and nextRevision<revision then return end
	if type(nextRevision)=="number" then revision=nextRevision end
	current=snapshot
	render()
end

local function refresh()
	if fetching or destroyed then return end
	fetching=true
	task.spawn(function()
		local ok,result=pcall(function() return getState:InvokeServer() end)
		fetching=false
		if ok and type(result)=="table" then applyState(result) end
	end)
end

toggle.Activated:Connect(function()
	opened=not opened
	syncVisible()
	if opened then refresh() end
end)
claimButton.Activated:Connect(function()
	if not current or current.Completed or not current.CanClaim or claimPending then return end
	feedbackText=nil
	local id=current.Id
	if type(id)~="string" then return end
	claimPending=true
	render()
	claim:FireServer(id)
	task.delay(5,function()
		if claimPending and not destroyed then
			claimPending=false
			refresh()
			render()
		end
	end)
end)
updated.OnClientEvent:Connect(applyState)
claim.OnClientEvent:Connect(function(result)
	if type(result)~="table" then return end
	claimPending=false
	if result.Success==true then
		feedbackText=nil
		refresh()
	else
		-- Failed claims (e.g., full sapling inventory) leave the objective
		-- claimable. Show a short, actionable reason in the existing panel.
		local reasons={
			SAPLING_STORAGE_FULL="Sapling storage full. Plant a sapling and try again.",
			NOT_COMPLETE="Objective not complete.",
			INVALID_QUEST="This quest is no longer active.",
			SERVER_ERROR="Unable to claim reward; try again.",
		}
		feedbackText=reasons[result.Reason] or "Reward unavailable; try again."
		refresh()
	end
	render()
end)
player:GetAttributeChangedSignal("ProfileReady"):Connect(function()
	if player:GetAttribute("ProfileReady")==true then
		-- The initial snapshot request may still be in flight at profile
		-- load time; retry after it settles instead of remaining blank.
		task.delay(0.3,refresh)
	end
end)
gui.Destroying:Connect(function() destroyed=true end)
syncVisible()
render()
refresh()
