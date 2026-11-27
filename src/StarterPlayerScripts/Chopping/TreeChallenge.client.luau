-- Personal presentation. The server owns unlocks, eligibility, HP and timer.
local Players=game:GetService("Players")
local CollectionService=game:GetService("CollectionService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local cancel=game.ReplicatedStorage.Economy:WaitForChild("CancelTreeChallengeRE")
local gui=Instance.new("ScreenGui")
gui.Name="TreeChallengeUI"
gui.ResetOnSpawn=false
gui.DisplayOrder=25
gui.Parent=player:WaitForChild("PlayerGui")
local frame=Instance.new("Frame")
frame.AnchorPoint=Vector2.new(0.5,0)
frame.Position=UDim2.new(0.5,0,0,72)
frame.Size=UDim2.new(0.8,0,0,154)
frame.BackgroundColor3=Color3.fromRGB(25,38,32)
frame.BackgroundTransparency=0.08
frame.Visible=false
frame.Parent=gui
local constraint=Instance.new("UISizeConstraint")
constraint.MaxSize=Vector2.new(460,154)
constraint.Parent=frame
local corner=Instance.new("UICorner")
corner.CornerRadius=UDim.new(0,12)
corner.Parent=frame
local function text(y,height,size)
	local label=Instance.new("TextLabel")
	label.Position=UDim2.new(0,8,0,y)
	label.Size=UDim2.new(1,-16,0,height)
	label.BackgroundTransparency=1
	label.TextColor3=Color3.fromRGB(245,248,234)
	label.Font=Enum.Font.GothamBold
	label.TextSize=size
	label.TextWrapped=true
	label.Parent=frame
	return label
end
local title=text(5,24,18)
local timer=text(30,26,22)
local track=Instance.new("Frame")
track.Position=UDim2.new(0,12,0,62)
track.Size=UDim2.new(1,-24,0,12)
track.BorderSizePixel=0
track.BackgroundColor3=Color3.fromRGB(60,70,64)
track.Parent=frame
local fill=Instance.new("Frame")
fill.Size=UDim2.fromScale(1,1)
fill.BorderSizePixel=0
fill.BackgroundColor3=Color3.fromRGB(111,205,99)
fill.Parent=track
local hp=text(77,28,14)
local button=Instance.new("TextButton")
button.AnchorPoint=Vector2.new(0.5,0)
button.Position=UDim2.new(0.5,0,0,111)
button.Size=UDim2.new(0.65,0,0,32)
button.BackgroundColor3=Color3.fromRGB(66,98,76)
button.TextColor3=Color3.new(1,1,1)
button.Font=Enum.Font.GothamBold
button.TextSize=14
button.Parent=frame
local dismissed=false
button.Activated:Connect(function()
	local phase=player:GetAttribute("TreeChallengePhase")
	if phase=="Preparing" or phase=="Active" then cancel:FireServer()
	else dismissed=true; frame.Visible=false end
end)
player:GetAttributeChangedSignal("TreeChallengePhase"):Connect(function() dismissed=false end)

local gateConnections={}
local function updateGate(model)
	local unlock=model:GetAttribute("GuardianUnlock")
	if type(unlock)~="string" then return end
	local open=player:GetAttribute("ForestAccess_"..unlock)==true
	for _,part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier=if open then 1 else 0
			part.CanCollide=not open and part:GetAttribute("GuardianSolid")==true
		elseif part:IsA("ProximityPrompt") and part.Name=="GuardianPrompt" then
			part.Enabled=not open
		end
	end
end
local function watch(model)
	if gateConnections[model] then return end
	local unlock=model:GetAttribute("GuardianUnlock")
	if type(unlock)~="string" then return end
	gateConnections[model]={
		player:GetAttributeChangedSignal("ForestAccess_"..unlock):Connect(function() updateGate(model) end),
		model.DescendantAdded:Connect(function() task.defer(updateGate,model) end),
	}
	updateGate(model)
end
local function unwatch(model)
	for _,connection in ipairs(gateConnections[model] or {}) do connection:Disconnect() end
	gateConnections[model]=nil
end
CollectionService:GetInstanceAddedSignal("PersonalGuardianGate"):Connect(watch)
CollectionService:GetInstanceRemovedSignal("PersonalGuardianGate"):Connect(unwatch)
for _,model in ipairs(CollectionService:GetTagged("PersonalGuardianGate")) do watch(model) end

RunService.RenderStepped:Connect(function()
	local phase=player:GetAttribute("TreeChallengePhase")
	if not phase or dismissed then frame.Visible=false; return end
	local max=player:GetAttribute("TreeChallengeMaxHP") or 1
	local current=player:GetAttribute("TreeChallengeHP") or max
	local duration=player:GetAttribute("TreeChallengeSeconds") or 1
	local start=player:GetAttribute("TreeChallengeStart") or 0
	local deadline=player:GetAttribute("TreeChallengeEnd") or 0
	local time=workspace:GetServerTimeNow()
	frame.Visible=true
	title.Text=player:GetAttribute("TreeChallengeName") or "Guardian"
	fill.Size=UDim2.fromScale(math.clamp(current/math.max(1,max),0,1),1)
	if phase=="Preparing" then
		timer.Text="GET READY  "..math.max(0,math.ceil(start-time))
	elseif phase=="Active" then
		timer.Text=string.format("%.1f s",math.max(0,deadline-time))
	elseif phase=="Success" then timer.Text="VICTORY! FOREST UNLOCKED"
	elseif phase=="Failed" then timer.Text="TIME'S UP!"
	else timer.Text="CHALLENGE CANCELLED" end
	if phase=="Failed" then
		hp.Text=string.format("%d / %d damage  •  %.1f / %.1f DPS",max-current,max,(max-current)/duration,max/duration)
	else hp.Text=string.format("%d / %d HP",current,max) end
	button.Text=if phase=="Preparing" or phase=="Active" then "Cancel" else "Close"
end)
