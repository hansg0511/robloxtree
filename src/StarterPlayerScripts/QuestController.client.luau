-- Compact Story / Daily / Weekly panel. Recurring objectives have no rewards
-- or claim buttons until the actual reward economy has been agreed.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
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
panel.Size=UDim2.fromOffset(365,330)
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

local mainHeading=label(panel,"MainHeading","QUESTS",UDim2.fromOffset(13,10),
	UDim2.fromOffset(330,22),Enum.Font.GothamBold,16)
local tabs={}
for index,category in ipairs({"Story","Daily","Weekly"}) do
	local b=button(panel,"Tab"..category,if category=="Story" then "MAIN QUEST" else string.upper(category),
		UDim2.fromOffset(13+(index-1)*115,38),UDim2.fromOffset(108,30))
	b.TextSize=12
	tabs[category]=b
end
local storyPage=Instance.new("Frame")
storyPage.Name="StoryPage"
storyPage.Size=UDim2.new(1,0,1,-75)
storyPage.Position=UDim2.fromOffset(0,75)
storyPage.BackgroundTransparency=1
storyPage.Parent=panel

local recurringPage=Instance.new("Frame")
recurringPage.Name="RecurringPage"
recurringPage.Size=UDim2.new(1,0,1,-75)
recurringPage.Position=UDim2.fromOffset(0,75)
recurringPage.BackgroundTransparency=1
recurringPage.Visible=false
recurringPage.Parent=panel
local recurringHeading=label(recurringPage,"RecurringHeading","",UDim2.fromOffset(13,8),
	UDim2.fromOffset(330,24),Enum.Font.GothamBold,14)
local resetLabel=label(recurringPage,"ResetTimer","",UDim2.fromOffset(13,35),
	UDim2.fromOffset(332,24),Enum.Font.Gotham,12)
local taskRows={}
for i=1,2 do
	local y=70+(i-1)*70
	local titleRow=label(recurringPage,"TaskTitle"..i,"",UDim2.fromOffset(13,y),
		UDim2.fromOffset(328,22),Enum.Font.GothamBold,13)
	local description=label(recurringPage,"TaskDescription"..i,"",UDim2.fromOffset(13,y+21),
		UDim2.fromOffset(328,20),Enum.Font.Gotham,12)
	local count=label(recurringPage,"TaskProgress"..i,"",UDim2.fromOffset(13,y+43),
		UDim2.fromOffset(195,20),Enum.Font.GothamMedium,12)
	local claimRow=button(recurringPage,"ClaimTask"..i,"CLAIM",UDim2.fromOffset(218,y+38),UDim2.fromOffset(122,28))
	claimRow.TextSize=11
	taskRows[i]={Title=titleRow,Description=description,Progress=count,Claim=claimRow}
end
local recurringFooter=label(recurringPage,"NoRecurringRewards",
	"Complete daily and weekly tasks to earn Gems.",UDim2.fromOffset(13,222),
	UDim2.fromOffset(332,23),Enum.Font.Gotham,11)
recurringFooter.TextColor3=Color3.fromRGB(161,179,159)

local heading=label(storyPage,"Heading","STORY QUESTS",UDim2.fromOffset(13,10),UDim2.fromOffset(315,24),Enum.Font.GothamBold,15)
local title=label(storyPage,"Title","Loading...",UDim2.fromOffset(13,42),UDim2.fromOffset(315,24),Enum.Font.GothamBold,15)
local objective=label(storyPage,"Objective","",UDim2.fromOffset(13,71),UDim2.fromOffset(315,45),Enum.Font.Gotham,13)
local progress=label(storyPage,"Progress","",UDim2.fromOffset(13,124),UDim2.fromOffset(315,22),Enum.Font.GothamMedium,13)
local reward=label(storyPage,"Reward","",UDim2.fromOffset(13,146),UDim2.fromOffset(315,24),Enum.Font.GothamMedium,13)
local claimButton=button(storyPage,"ClaimStoryReward","NOT READY",UDim2.fromOffset(13,176),UDim2.fromOffset(319,38))
local future=label(storyPage,"FutureTasks","Daily / Weekly: earn Gems",
	UDim2.fromOffset(13,223),UDim2.fromOffset(315,20),Enum.Font.Gotham,11)
future.TextColor3=Color3.fromRGB(161,179,159)

local current
local revision=-1
local claimPending=false
local fetching=false
local opened=false
local destroyed=false
local feedbackText
local selectedTab="Story"

local function formatRemaining(resetAt)
	if type(resetAt)~="number" then return "Syncing..." end
	local seconds=math.max(0,math.ceil(resetAt-Workspace:GetServerTimeNow()))
	local days=math.floor(seconds/86400)
	local hours=math.floor((seconds%86400)/3600)
	local minutes=math.floor((seconds%3600)/60)
	local secs=seconds%60
	if days>0 then return string.format("%dd %02dh %02dm",days,hours,minutes) end
	return string.format("%02dh %02dm %02ds",hours,minutes,secs)
end

local function syncVisible()
	local modal=playerGui:GetAttribute("EconomyModalOpen")==true
	toggle.Visible=not modal
	panel.Visible=opened and not modal
end
playerGui:GetAttributeChangedSignal("EconomyModalOpen"):Connect(syncVisible)

local function render()
	local state=current
	storyPage.Visible=selectedTab=="Story"
	recurringPage.Visible=selectedTab~="Story"
	for category,b in pairs(tabs) do
		b.BackgroundColor3=if selectedTab==category
			then Color3.fromRGB(65,123,69) else Color3.fromRGB(48,65,53)
	end
	if selectedTab~="Story" then
		local period=state and state[selectedTab]
		recurringHeading.Text=string.upper(selectedTab).." TASKS"
		resetLabel.Text="RESET IN: "..formatRemaining(period and period.ResetAt)
		for i,row in ipairs(taskRows) do
			local taskState=period and type(period.Tasks)=="table" and period.Tasks[i] or nil
			row.Title.Visible=taskState~=nil
			row.Description.Visible=taskState~=nil
			row.Progress.Visible=taskState~=nil
			row.Claim.Visible=taskState~=nil
			if taskState then
				row.Title.Text=tostring(taskState.Title or "Task").."  •  +"..tostring(taskState.Reward or 0).." Gems"
				row.Claim.Active=taskState.Completed==true and not taskState.Claimed and not claimPending
				row.Claim.AutoButtonColor=row.Claim.Active
				row.Claim.Text=if taskState.Claimed then "CLAIMED" elseif row.Claim.Active then "CLAIM" else "NOT READY"
				row.Claim.BackgroundColor3=if row.Claim.Active then Color3.fromRGB(65,123,69) else Color3.fromRGB(77,83,78)
				row.Description.Text=tostring(taskState.Description or "")
				row.Progress.Text=if taskState.Completed
					then string.format("COMPLETE  •  %d / %d",taskState.Count or 0,taskState.Target or 1)
					else string.format("PROGRESS: %d / %d",taskState.Count or 0,taskState.Target or 1)
				row.Progress.TextColor3=if taskState.Completed
					then Color3.fromRGB(153,222,144) else Color3.fromRGB(236,240,220)
			end
		end
	end
	recurringFooter.Text=feedbackText or ("GEMS: "..tostring(state and state.PremiumBalance or 0).." • Claim before reset")
	future.Text=feedbackText or "Daily / Weekly: earn Gems"
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
		heading.Text=string.format("MAIN QUEST  •  %d / %d",
			state.Stage or 1,state.TotalStages or 2)
		title.Text=tostring(state.Title or "Main quest")
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
for i,row in ipairs(taskRows) do
	row.Claim.Activated:Connect(function()
		local period=current and current[selectedTab]
		local taskState=period and period.Tasks and period.Tasks[i]
		if claimPending or not row.Claim.Active or not taskState or type(taskState.ClaimId)~="string" then return end
		claimPending=true; feedbackText=nil; render(); claim:FireServer(taskState.ClaimId)
		task.delay(5,function()
			if claimPending and not destroyed then claimPending=false; refresh(); render() end
		end)
	end)
end
updated.OnClientEvent:Connect(applyState)
claim.OnClientEvent:Connect(function(result)
	if type(result)~="table" then return end
	claimPending=false
	if result.Success==true then
		feedbackText="Claimed "..tostring(result.Reward or "reward").."!"
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
for category,b in pairs(tabs) do
	b.Activated:Connect(function()
		selectedTab=category
		render()
		refresh()
	end)
end
-- The server also pushes rollovers. This lightweight local timer keeps the
-- countdown moving and retries a snapshot if the reset boundary has passed.
task.spawn(function()
	local lastBoundaryRefresh=-math.huge
	while not destroyed do
		task.wait(1)
		if opened and selectedTab~="Story" then
			render()
			local period=current and current[selectedTab]
			local now=Workspace:GetServerTimeNow()
			if period and type(period.ResetAt)=="number"
				and now>=period.ResetAt and now-lastBoundaryRefresh>=3 then
				lastBoundaryRefresh=now
				refresh()
			end
		end
	end
end)
syncVisible()
render()
refresh()
