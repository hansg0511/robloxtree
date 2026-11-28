-- Small client-only interaction for testing Personal Grove sapling planting.
-- The server remains authoritative for sapling ownership and placement validity.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local ProximityPromptService=game:GetService("ProximityPromptService")
local shopRF = ReplicatedStorage:WaitForChild("Grove"):WaitForChild("GetSaplingShopRF")
local buySaplingRE = ReplicatedStorage:WaitForChild("Grove"):WaitForChild("BuySaplingRE")
local uprootGroveTreeRE = ReplicatedStorage:WaitForChild("Grove"):WaitForChild("UprootGroveTreeRE")
local upgradeGroveRE = ReplicatedStorage:WaitForChild("Grove"):WaitForChild("UpgradeGroveRE")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ACTION_NAME = "PersonalGrovePlantPrimary"
local PLANT_DEBOUNCE_SECONDS = 0.55
local STATE_CHECK_DELAY_SECONDS = 0.85

local connections = {}
local refreshState
local stateFunction
local plantEvent
local stateUpdatedEvent
local stateUpdatedConnection
local saplingDiscoveredEvent
local saplingDiscoveredConnection
local groveFolder
local refreshInProgress = false
local refreshCallbacks = {}
local cleanedUp = false

local stateLoaded = false
local hasAssignedGrove = false
local latestStateRevision = -1
local saplings = {}
local groveMaterials = {}
local groveTrees = {}
local selectedSaplingUID
local selectedGroveTreeUID
local groveCapacity = 3 -- overwritten by the server snapshot
local groveLevel = 1
local groveMaxMutations = 1
local nextGroveUpgrade
local upgradePending = false
local passiveTotals = {}
local managerOpen = false
local stallOpen=false
local uprootPending = false
local confirmUprootUID
local confirmUprootUntil = 0
local groveManagerPanel
local selectionHighlight
local renderTreeManager
local render
local plantingMode = false
local pendingPlantUID
local plantingAttemptId = 0
local lastPlantAttemptAt = 0
local lastCycleAt = 0
local previewModel
local previewTrunk
local previewLeaves
local previewUpdateConnection

local function keepConnection(connection)
	if connection then
		table.insert(connections, connection)
	end
	return connection
end

local function makeLabel(parent, name, position, size, font, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = font
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.RichText = false
	label.Parent = parent
	return label
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PersonalGroveMilestone1"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 20
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "StatusPanel"
panel.AnchorPoint = Vector2.new(0, 1)
panel.Position = UDim2.new(0, 18, 1, -18)
panel.Size = UDim2.fromOffset(372, 486)
panel.BackgroundColor3 = Color3.fromRGB(21, 29, 25)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Parent = screenGui

-- Debug management panel is strictly contextual. Leaving the stall or
-- opening another economy modal closes it, never automatically reopens it.
local function nearGroveStall()
	local world=Workspace:FindFirstChild("SourceWorld")
	local station=world and world:FindFirstChild("GroveShopStation")
	local interaction=station and station:FindFirstChild("Interaction")
	local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not interaction or not interaction:IsA("BasePart") or not root then return false end
	local distance=interaction:GetAttribute("UseDistance")
	if type(distance)~="number" or distance<=0 then return false end
	local pos=interaction.CFrame:PointToObjectSpace(root.Position)
	local half=interaction.Size*0.5
	local closest=Vector3.new(math.clamp(pos.X,-half.X,half.X),math.clamp(pos.Y,-half.Y,half.Y),math.clamp(pos.Z,-half.Z,half.Z))
	return (pos-closest).Magnitude<=distance
end
local function syncGrovePanelWithEconomy()
	if playerGui:GetAttribute("EconomyModalOpen")==true or not nearGroveStall() then stallOpen=false end
	panel.Visible=stallOpen
	if not stallOpen then
		managerOpen=false
		confirmUprootUID=nil
		confirmUprootUntil=0
		if selectionHighlight then selectionHighlight.Enabled=false end
	end
	if groveManagerPanel then groveManagerPanel.Visible=stallOpen and managerOpen end
end
local function closeStall()
	stallOpen=false
	syncGrovePanelWithEconomy()
end
keepConnection(playerGui:GetAttributeChangedSignal("EconomyModalOpen"):Connect(syncGrovePanelWithEconomy))
syncGrovePanelWithEconomy()
local closeButton=Instance.new("TextButton")
closeButton.Name="CloseGroveShop"
closeButton.Size=UDim2.fromOffset(30,26)
closeButton.Position=UDim2.new(1,-36,0,5)
closeButton.Text="×"
closeButton.TextSize=21
closeButton.Font=Enum.Font.GothamBold
closeButton.TextColor3=Color3.fromRGB(235,240,225)
closeButton.BackgroundColor3=Color3.fromRGB(64,91,67)
closeButton.Parent=panel
keepConnection(closeButton.Activated:Connect(closeStall))

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 8)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(104, 145, 108)
panelStroke.Transparency = 0.22
panelStroke.Thickness = 1
panelStroke.Parent = panel

local titleLabel = makeLabel(
	panel,
	"Title",
	UDim2.fromOffset(13, 8),
	UDim2.new(1, -26, 0, 20),
	Enum.Font.GothamBold,
	14,
	Color3.fromRGB(225, 240, 220)
)
titleLabel.Text = "GROVE SHOP • PROTOTYPE"
titleLabel.Size=UDim2.new(1,-52,0,20)

local groveStatusLabel = makeLabel(
	panel,
	"GroveStatus",
	UDim2.fromOffset(13, 31),
	UDim2.new(1, -26, 0, 19),
	Enum.Font.GothamMedium,
	13,
	Color3.fromRGB(192, 209, 190)
)

local saplingsLabel = makeLabel(
	panel,
	"Saplings",
	UDim2.fromOffset(13, 52),
	UDim2.new(1, -26, 0, 19),
	Enum.Font.GothamMedium,
	13,
	Color3.fromRGB(234, 236, 224)
)

local groveSummaryLabel = makeLabel(
	panel,
	"GroveTreeSummary",
	UDim2.fromOffset(13, 73),
	UDim2.new(1, -26, 0, 19),
	Enum.Font.GothamMedium,
	13,
	Color3.fromRGB(234, 236, 224)
)

local selectedSaplingLabel = makeLabel(
	panel,
	"SelectedSapling",
	UDim2.fromOffset(13, 94),
	UDim2.new(1, -26, 0, 40),
	Enum.Font.GothamMedium,
	12,
	Color3.fromRGB(234, 236, 224)
)

local feedbackLabel = makeLabel(
	panel,
	"Feedback",
	UDim2.fromOffset(13, 138),
	UDim2.new(1, -26, 0, 23),
	Enum.Font.Gotham,
	12,
	Color3.fromRGB(185, 203, 183)
)

local controlsLabel = makeLabel(
	panel,
	"Controls",
	UDim2.fromOffset(13, 164),
	UDim2.new(1, -26, 0, 38),
	Enum.Font.Gotham,
	11,
	Color3.fromRGB(155, 174, 156)
)

local feedbackKind = "info"
local feedbackText = "Waiting for Grove state…"

local function setFeedback(message, kind)
	feedbackText = message
	feedbackKind = kind or "info"
	feedbackLabel.Text = feedbackText
	if feedbackKind == "error" then
		feedbackLabel.TextColor3 = Color3.fromRGB(238, 170, 152)
	elseif feedbackKind == "success" then
		feedbackLabel.TextColor3 = Color3.fromRGB(160, 218, 158)
	else
		feedbackLabel.TextColor3 = Color3.fromRGB(185, 203, 183)
	end
end

-- Global stock catalogue; only offers with positive initial stock appear in
-- the mutated tab. Bought-out rows remain until the next restock.
local shopHeading = makeLabel(panel,"SaplingShopHeading",
	UDim2.fromOffset(13,207),UDim2.new(1,-26,0,16),
	Enum.Font.GothamBold,12,Color3.fromRGB(232,218,153))
local function shopButton(parent,name,x,y,w,h)
	local b=Instance.new("TextButton")
	b.Name=name
	b.Size=UDim2.fromOffset(w,h)
	b.Position=UDim2.fromOffset(x,y)
	b.BackgroundColor3=Color3.fromRGB(59,106,71)
	b.TextColor3=Color3.fromRGB(240,255,228)
	b.TextSize=12
	b.TextWrapped=true
	b.Font=Enum.Font.GothamBold
	b.BorderSizePixel=0
	b.Parent=parent
	local corner=Instance.new("UICorner")
	corner.CornerRadius=UDim.new(0,6)
	corner.Parent=b
	return b
end
local ordinaryTab=shopButton(panel,"OrdinaryTab",13,227,169,27)
ordinaryTab.Text="ORDINARY"
local mutatedTab=shopButton(panel,"MutatedTab",187,227,169,27)
mutatedTab.Text="MUTATED"
local stockList=Instance.new("ScrollingFrame")
stockList.Name="SaplingStockList"
stockList.Position=UDim2.fromOffset(13,260)
stockList.Size=UDim2.fromOffset(343,123)
stockList.BackgroundTransparency=1
stockList.BorderSizePixel=0
stockList.ScrollBarThickness=5
stockList.ScrollingDirection=Enum.ScrollingDirection.Y
stockList.AutomaticCanvasSize=Enum.AutomaticSize.Y
stockList.CanvasSize=UDim2.fromOffset(0,0)
stockList.Parent=panel
local stockLayout=Instance.new("UIListLayout")
stockLayout.Padding=UDim.new(0,4)
stockLayout.SortOrder=Enum.SortOrder.LayoutOrder
stockLayout.Parent=stockList
local shopSnapshot
local shopPending=false
local shopBusy=false
local shopTab="ordinary"
local refreshSaplingShop
local buyOffer
local function renderRestock()
	local remaining=if type(shopSnapshot)=="table" and type(shopSnapshot.RestockAt)=="number"
		then math.max(0,shopSnapshot.RestockAt-os.time()) else 0
	shopHeading.Text=if shopSnapshot then string.format("SAPLING SHOP  •  RESTOCK %02d:%02d",math.floor(remaining/60),remaining%60)
		else "SAPLING SHOP • LOADING"
end
local function renderSaplingShop()
	renderRestock()
	ordinaryTab.BackgroundColor3=if shopTab=="ordinary" then Color3.fromRGB(70,122,78) else Color3.fromRGB(64,72,66)
	mutatedTab.BackgroundColor3=if shopTab=="mutated" then Color3.fromRGB(113,83,165) else Color3.fromRGB(64,72,66)
	for _,child in ipairs(stockList:GetChildren()) do
		if child~=stockLayout then child:Destroy() end
	end
	local count=0
	for _,offer in ipairs(type(shopSnapshot)=="table" and shopSnapshot.Offers or {}) do
		if (offer.Rare==true)~=(shopTab=="mutated") then continue end
		if offer.Rare and (offer.InitialStock or 0)<=0 then continue end
		count+=1
		local row=Instance.new("Frame")
		row.Name=offer.Id
		row.Size=UDim2.new(1,-7,0,40)
		row.BackgroundColor3=Color3.fromRGB(36,48,40)
		row.BorderSizePixel=0
		row.LayoutOrder=count
		row.Parent=stockList
		local label=makeLabel(row,"Offer",UDim2.fromOffset(6,0),UDim2.new(1,-112,1,0),
			Enum.Font.GothamMedium,12,Color3.fromRGB(234,236,224))
		local status=if offer.Stock<=0 then "SOLD OUT" else tostring(offer.Stock).." in stock"
		label.Text=string.format("%s\n%.2fx  •  %s",offer.Name,offer.SizePotential,status)
		local buy=shopButton(row,"Buy",0,3,100,34)
		buy.Position=UDim2.new(1,-103,0,3)
		buy.Text=if not offer.Unlocked then "FOREST LOCKED" elseif offer.Stock<=0 then "SOLD OUT" else tostring(offer.Price).." COINS"
		buy.Active=offer.CanBuy==true and not shopPending
		buy.AutoButtonColor=buy.Active
		buy.BackgroundColor3=if buy.Active then Color3.fromRGB(59,106,71) else Color3.fromRGB(81,89,83)
		local id=offer.Id
		buy.Activated:Connect(function() if buy.Active then buyOffer(id) end end)
	end
	if count==0 then
		local empty=makeLabel(stockList,"Empty",UDim2.fromOffset(0,0),UDim2.new(1,-8,0,44),
			Enum.Font.GothamMedium,12,Color3.fromRGB(192,209,190))
		empty.Text=if not shopSnapshot then "Loading saplings..." elseif shopTab=="mutated" then "No mutated saplings this restock." else "No ordinary saplings available."
	end
end
buyOffer=function(id)
	if shopPending or not shopSnapshot then return end
	local offer
	for _,o in ipairs(shopSnapshot.Offers or {}) do
		if o.Id==id and o.CanBuy==true then offer=o break end
	end
	if not offer then return end
	shopPending=true
	renderSaplingShop()
	buySaplingRE:FireServer(id,shopSnapshot.Cycle)
	task.delay(3,function()
		if shopPending and not cleanedUp then
			shopPending=false
			renderSaplingShop()
			if refreshSaplingShop then refreshSaplingShop() end
		end
	end)
end
ordinaryTab.Activated:Connect(function()
	shopTab="ordinary"
	stockList.CanvasPosition=Vector2.zero
	renderSaplingShop()
end)
mutatedTab.Activated:Connect(function()
	shopTab="mutated"
	stockList.CanvasPosition=Vector2.zero
	renderSaplingShop()
end)
refreshSaplingShop=function()
	if shopBusy or cleanedUp or not panel.Visible then return end
	shopBusy=true
	task.spawn(function()
		local ok,result=pcall(function() return shopRF:InvokeServer() end)
		shopBusy=false
		if cleanedUp then return end
		if ok and type(result)=="table" then shopSnapshot=result end
		renderSaplingShop()
	end)
end
keepConnection(buySaplingRE.OnClientEvent:Connect(function(result)
	shopPending=false
	if type(result)=="table" and result.Reason=="PURCHASED" then
		setFeedback("Bought "..tostring(result.Name or "sapling").."! Plant with [G].","success")
		if refreshState then refreshState() end
		-- Do not briefly re-enable a stale last copy before the snapshot arrives.
		for _,o in ipairs(shopSnapshot and shopSnapshot.Offers or {}) do
			if o.Id==result.OfferId and result.Cycle==shopSnapshot.Cycle then
				o.Stock=math.max(0,o.Stock-1)
				o.CanBuy=false
			end
		end
	else
		local names={
			NOT_AT_GROVE_SHOP="Return to the Grove shop.",
			NOT_ENOUGH_COINS="Not enough coins for this sapling.",
			SOLD_OUT="Your stock is sold out until restock.",
			OFFER_NOT_AVAILABLE="Stock rotated. Please check the shop again.",
			SAPLING_STORAGE_FULL="Too many unplanted saplings.",
			FOREST_LOCKED="Unlock this forest before buying its saplings.",
		}
		setFeedback(names[result and result.Reason] or "Sapling purchase unavailable. Try again.","error")
	end
	renderSaplingShop()
	refreshSaplingShop()
end))
renderSaplingShop()

-- Management is an optional contextual panel. Keep the existing shop
-- and planting HUD compact instead of adding a full-screen inventory.
local function makeManagerButton(parent,name,caption,x,y,width,height,color)
	local b=Instance.new("TextButton")
	b.Name=name
	b.Text=caption
	b.Position=UDim2.fromOffset(x,y)
	b.Size=UDim2.fromOffset(width,height)
	b.BackgroundColor3=color or Color3.fromRGB(60,99,70)
	b.TextColor3=Color3.fromRGB(245,244,234)
	b.Font=Enum.Font.GothamBold
	b.TextSize=12
	b.TextWrapped=true
	b.BorderSizePixel=0
	b.Parent=parent
	local corner=Instance.new("UICorner")
	corner.CornerRadius=UDim.new(0,6)
	corner.Parent=b
	return b
end

local managerToggle=makeManagerButton(panel,"ManagePlantedTrees",
	"MANAGE PLANTED TREES",13,390,343,31)
local upgradeButton=makeManagerButton(panel,"UpgradeGrove","GROVE UPGRADE",13,429,343,46,Color3.fromRGB(113,83,165))
local function renderUpgrade()
	local nextLevel = nextGroveUpgrade
	upgradeButton.Text = if upgradePending then "UPGRADING..."
		elseif type(nextLevel)=="table" then string.format("GROVE LV %d → %d • %d COINS\n%d PLANTING SLOTS • %d MAX MUTATIONS (PLANNED)",
			groveLevel,nextLevel.ToLevel,nextLevel.CoinCost,nextLevel.Capacity,nextLevel.MaxMutations)
		elseif stateLoaded then "GROVE LV "..tostring(groveLevel).." • MAX LEVEL"
		else "GROVE UPGRADE • LOADING"
	upgradeButton.Active = stateLoaded and hasAssignedGrove and type(nextLevel)=="table" and not upgradePending
	upgradeButton.AutoButtonColor = upgradeButton.Active
	upgradeButton.BackgroundColor3 = if upgradeButton.Active then Color3.fromRGB(113,83,165) else Color3.fromRGB(81,89,83)
end
keepConnection(upgradeButton.Activated:Connect(function()
	if not upgradeButton.Active then return end
	upgradePending = true
	renderUpgrade()
	upgradeGroveRE:FireServer(groveLevel)
	task.delay(3,function()
		if upgradePending and not cleanedUp then
			upgradePending = false
			if refreshState then refreshState() end
			renderUpgrade()
		end
	end)
end))
keepConnection(upgradeGroveRE.OnClientEvent:Connect(function(result)
	upgradePending = false
	if type(result)=="table" and result.Success then
		setFeedback("Grove upgraded to level "..tostring(result.Level).."!","success")
	elseif type(result)=="table" and result.Reason=="NOT_ENOUGH_COINS" then
		setFeedback("Not enough coins for Grove upgrade.","error")
	else
		setFeedback("Grove upgrade unavailable. Please refresh.","error")
	end
	if refreshState then refreshState() end
	renderUpgrade()
	refreshSaplingShop()
end))
renderUpgrade()
groveManagerPanel=Instance.new("Frame")
groveManagerPanel.Name="SelectedGroveTree"
groveManagerPanel.AnchorPoint=Vector2.new(0,1)
groveManagerPanel.Position=UDim2.new(0,401,1,-18)
groveManagerPanel.Size=UDim2.fromOffset(340,354)
groveManagerPanel.BackgroundColor3=Color3.fromRGB(21,29,25)
groveManagerPanel.BackgroundTransparency=0.04
groveManagerPanel.BorderSizePixel=0
groveManagerPanel.Visible=false
groveManagerPanel.Parent=screenGui
local managerCorner=Instance.new("UICorner")
managerCorner.CornerRadius=UDim.new(0,8)
managerCorner.Parent=groveManagerPanel
local managerStroke=Instance.new("UIStroke")
managerStroke.Color=Color3.fromRGB(104,145,108)
managerStroke.Transparency=0.12
managerStroke.Parent=groveManagerPanel
local managerTitle=makeLabel(groveManagerPanel,"ManageTitle",
	UDim2.fromOffset(12,7),UDim2.fromOffset(312,22),
	Enum.Font.GothamBold,14,Color3.fromRGB(225,240,220))
managerTitle.Text="SELECT A PLANTED TREE"
local managerPrevious=makeManagerButton(groveManagerPanel,
	"PreviousTree","<",12,34,40,32)
local managerNext=makeManagerButton(groveManagerPanel,
	"NextTree",">",286,34,40,32)
local managerPosition=makeLabel(groveManagerPanel,"TreeIndex",
	UDim2.fromOffset(58,34),UDim2.fromOffset(222,32),
	Enum.Font.GothamBold,12,Color3.fromRGB(225,240,220))
managerPosition.TextXAlignment=Enum.TextXAlignment.Center
local managerDetails=makeLabel(groveManagerPanel,"TreeDetails",
	UDim2.fromOffset(12,75),UDim2.fromOffset(314,80),
	Enum.Font.GothamMedium,13,Color3.fromRGB(231,229,211))
managerDetails.TextYAlignment=Enum.TextYAlignment.Top
local managerPassives=makeLabel(groveManagerPanel,"TreePassives",
	UDim2.fromOffset(12,157),UDim2.fromOffset(314,42),
	Enum.Font.GothamBold,12,Color3.fromRGB(160,218,158))
local managerTotals=makeLabel(groveManagerPanel,"TotalPassives",
	UDim2.fromOffset(12,201),UDim2.fromOffset(314,58),
	Enum.Font.GothamMedium,12,Color3.fromRGB(225,240,220))
local uprootButton=makeManagerButton(groveManagerPanel,
	"UprootTree","UPROOT SELECTED TREE",12,265,314,41,Color3.fromRGB(131,68,57))
local uprootWarning=makeLabel(groveManagerPanel,"PermanentRemovalWarning",
	UDim2.fromOffset(12,310),UDim2.fromOffset(314,33),
	Enum.Font.Gotham,11,Color3.fromRGB(235,177,154))

local function containsSaplingUID(list, uid)
	for _, sapling in ipairs(list) do
		if sapling.UID == uid then
			return true
		end
	end
	return false
end

local function getSelectedSapling()
	for _, sapling in ipairs(saplings) do
		if sapling.UID == selectedSaplingUID then
			return sapling
		end
	end
	return nil
end

local function formatMutationNames(mutations)
	local names = {}
	if type(mutations) == "table" then
		for mutationId, enabled in pairs(mutations) do
			if type(mutationId) == "string" and enabled == true then
				table.insert(names, mutationId)
			end
		end
	end
	table.sort(names)
	return table.concat(names, " + ")
end

local function describeSapling(sapling)
	local speciesId = type(sapling) == "table" and sapling.SpeciesId or nil
	local prefix = type(sapling) == "table" and formatMutationNames(sapling.Mutations) or ""
	local name = tostring(speciesId or "Unknown")
	if prefix ~= "" then
		name = prefix .. " " .. name
	end
	return name .. " Sapling"
end

local function getAreaFromPlot(plot)
	if not plot then
		return nil
	end

	local model = plot:FindFirstChild("PlotModel")
	local area = model and model:FindFirstChild("GroveArea")
	if area and area:IsA("BasePart") and area:IsDescendantOf(Workspace) then
		return area
	end
	return nil
end

local function getAssignedGroveArea()
	local plots = Workspace:FindFirstChild("PlayerPlots")
	if not plots then
		return nil
	end

	local plotNumber = player:GetAttribute("PlotNumber")
	if typeof(plotNumber) == "number" then
		local plot = plots:FindFirstChild("Plot" .. tostring(math.floor(plotNumber)))
		local owner = plot and plot:FindFirstChild("OwnerID")
		if plot and owner and owner.Value == player.UserId then
			local area = getAreaFromPlot(plot)
			if area then
				return area
			end
		end
	end

	for _, plot in ipairs(plots:GetChildren()) do
		local owner = plot:FindFirstChild("OwnerID")
		if owner and owner.Value == player.UserId then
			local area = getAreaFromPlot(plot)
			if area then
				return area
			end
		end
	end

	return nil
end

local function selectedManagedTree()
	for i,tree in ipairs(groveTrees) do
		if tree.UID==selectedGroveTreeUID then return tree,i end
	end
	return nil,nil
end

local function highlightManagedTree()
	if not managerOpen or not panel.Visible or not selectedGroveTreeUID then
		if selectionHighlight then selectionHighlight.Enabled=false end
		return
	end
	local area=getAssignedGroveArea()
	local plotModel=area and area.Parent
	local model
	if plotModel then
		for _,item in ipairs(plotModel:GetChildren()) do
			if item:IsA("Model") and item:GetAttribute("PersistentGrove")==true
				and item:GetAttribute("OwnerUserId")==player.UserId
				and item:GetAttribute("GroveTreeUID")==selectedGroveTreeUID then
				model=item
				break
			end
		end
	end
	if model and not selectionHighlight then
		selectionHighlight=Instance.new("Highlight")
		selectionHighlight.Name="LocalSelectedGroveTreeOutline"
		selectionHighlight.FillTransparency=1
		selectionHighlight.OutlineColor=Color3.fromRGB(245,238,115)
		selectionHighlight.OutlineTransparency=0
		selectionHighlight.DepthMode=Enum.HighlightDepthMode.Occluded
		selectionHighlight.Parent=Workspace
	end
	if selectionHighlight then
		selectionHighlight.Adornee=model
		selectionHighlight.Enabled=model~=nil
	end
end

local function selectManagedTree(uid)
	if uprootPending then return false end
	for _,tree in ipairs(groveTrees) do
		if tree.UID==uid then
			selectedGroveTreeUID=uid
			managerOpen=true
			confirmUprootUID=nil
			confirmUprootUntil=0
			render()
			return true
		end
	end
	return false
end

local PASSIVE_DISPLAY = {
	{ Key="Damage", Name="damage", Scale=100, Unit="%" },
	{ Key="Haste", Name="attack speed", Scale=100, Unit="%" },
	{ Key="Sale", Name="sale value", Scale=100, Unit="%" },
	{ Key="SaplingChance", Name="sapling chance (relative)", Scale=100, Unit="%" },
	{ Key="CritChance", Name="crit chance", Scale=1, Unit=" pp" },
	{ Key="CritDamage", Name="crit damage", Scale=1, Unit=" pp" },
	{ Key="BossDamage", Name="boss damage", Scale=100, Unit="%" },
}
local function formatPassives(values)
	local parts = {}
	for _, entry in ipairs(PASSIVE_DISPLAY) do
		local value = type(values) == "table" and values[entry.Key]
		if type(value) == "number" and value > 0 then
			table.insert(parts, string.format("+%.1f%s %s", value*entry.Scale, entry.Unit, entry.Name))
		end
	end
	return if #parts > 0 then table.concat(parts, "  •  ") else "None"
end

renderTreeManager=function()
	local count=#groveTrees
	managerToggle.Text=string.format("MANAGE PLANTED TREES  •  %d / %d",count,groveCapacity)
	managerToggle.Active=stateLoaded and hasAssignedGrove and count>0 and not uprootPending
	managerToggle.AutoButtonColor=managerToggle.Active
	managerToggle.BackgroundColor3=if managerToggle.Active
		then Color3.fromRGB(57,103,73) else Color3.fromRGB(79,87,79)
	if managerOpen and count>0 and not selectedManagedTree() then
		selectedGroveTreeUID=groveTrees[1].UID
		confirmUprootUID=nil
		confirmUprootUntil=0
	end
	groveManagerPanel.Visible=managerOpen and panel.Visible and count>0
	if not groveManagerPanel.Visible then
		highlightManagedTree()
		return
	end
	local tree,index=selectedManagedTree()
	if not tree then return end
	managerTitle.Text=string.format("TREE MANAGEMENT  •  %d / %d",count,groveCapacity)
	managerPosition.Text=string.format("TREE %d OF %d",index,count)
	local mutations=formatMutationNames(tree.Mutations)
	local name=if mutations=="" then tostring(tree.SpeciesId)
		else mutations.." "..tostring(tree.SpeciesId)
	local seconds=math.max(0,math.ceil((tonumber(tree.MaturesAt) or os.time())-os.time()))
	local stageText=if tree.Stage=="mature" then "mature" else string.format("%s • %dm %02ds remaining",tostring(tree.Stage or "growing"),math.floor(seconds/60),seconds%60)
	managerDetails.Text=string.format("%s\nGenetic potential: %.2fx  •  Current size: %.2fx\nStage: %s",
		name,tonumber(tree.SizePotential) or 1,tonumber(tree.CurrentSizeScale) or 1,stageText)
	managerPassives.Text=tostring(tree.GeneticPassive or "Unknown").." • "..(if tree.Stage == "mature" then "ACTIVE: "..formatPassives(tree.Passives)
		else "INACTIVE UNTIL MATURE")
	managerTotals.Text="TOTAL GROVE BONUSES\n"..formatPassives(passiveTotals)
	local rare=mutations~=""
	uprootWarning.Text=if rare
		then "WARNING: Mutated sapling LOST FOREVER. No materials refunded."
		else "Permanent removal. Planted sapling is NOT returned to inventory."
	uprootWarning.TextColor3=if rare then Color3.fromRGB(255,157,127)
		else Color3.fromRGB(235,187,154)
	managerPrevious.Active=not uprootPending and count>1
	managerNext.Active=not uprootPending and count>1
	local armed=confirmUprootUID==tree.UID and os.clock()<=confirmUprootUntil
	uprootButton.Active=not uprootPending
	uprootButton.AutoButtonColor=uprootButton.Active
	uprootButton.BackgroundColor3=if armed then Color3.fromRGB(185,56,50)
		else Color3.fromRGB(130,68,57)
	uprootButton.Text=if uprootPending then "UPROOTING..."
		else if armed then "CONFIRM PERMANENT DESTRUCTION"
		else "UPROOT SELECTED TREE"
	highlightManagedTree()
end

managerToggle.Activated:Connect(function()
	if uprootPending or not stateLoaded or not hasAssignedGrove or #groveTrees==0 then return end
	managerOpen=not managerOpen
	confirmUprootUID=nil
	confirmUprootUntil=0
	if managerOpen and not selectedManagedTree() then
		selectedGroveTreeUID=groveTrees[1].UID
	end
	render()
end)

local function cycleManagedTree(direction)
	if uprootPending or #groveTrees==0 then return end
	local _,index=selectedManagedTree()
	local nextIndex=(((index or 1)-1+direction)%#groveTrees)+1
	selectManagedTree(groveTrees[nextIndex].UID)
end
managerPrevious.Activated:Connect(function() cycleManagedTree(-1) end)
managerNext.Activated:Connect(function() cycleManagedTree(1) end)

uprootButton.Activated:Connect(function()
	if uprootPending or not managerOpen or not uprootButton.Active then return end
	local tree=selectedManagedTree()
	if not tree then return end
	local uid=tree.UID
	if confirmUprootUID~=uid or os.clock()>confirmUprootUntil then
		confirmUprootUID=uid
		confirmUprootUntil=os.clock()+7
		renderTreeManager()
		task.delay(7,function()
			if not cleanedUp and confirmUprootUID==uid
				and os.clock()>=confirmUprootUntil then
				confirmUprootUID=nil
				renderTreeManager()
			end
		end)
		return
	end
	-- Second click required for the SAME owned Grove UID, within 7 seconds.
	confirmUprootUID=nil
	uprootPending=true
	renderTreeManager()
	uprootGroveTreeRE:FireServer(uid)
	task.delay(5,function()
		if not cleanedUp and uprootPending then
			uprootPending=false
			setFeedback("Uproot result delayed. Refresh before retrying.","error")
			refreshState()
			render()
		end
	end)
end)

keepConnection(uprootGroveTreeRE.OnClientEvent:Connect(function(payload)
	if type(payload)~="table" then return end
	uprootPending=false
	confirmUprootUID=nil
	confirmUprootUntil=0
	if payload.Success==true then
		managerOpen=false
		if selectedGroveTreeUID==payload.UID then selectedGroveTreeUID=nil end
		setFeedback("Tree permanently uprooted. Grove slot freed.","success")
	else
		local reasons={
			INVALID_TREE_UID="Invalid tree selection.",
			TREE_NOT_OWNED="Tree not found in your Grove. Refresh selection.",
			GROVE_NOT_READY="Grove is not ready. Try again.",
			SERVER_ERROR="Tree removal failed on the server.",
		}
		setFeedback(reasons[payload.Reason] or "Could not remove tree.","error")
	end
	refreshState()
	render()
end))

render = function()
	if cleanedUp then
		return
	end

	local area = getAssignedGroveArea()
	if not stateLoaded then
		groveStatusLabel.Text = stateFunction and "Grove: loading state…" or "Grove: waiting for server remotes…"
		groveStatusLabel.TextColor3 = Color3.fromRGB(192, 209, 190)
	elseif not hasAssignedGrove then
		groveStatusLabel.Text = "Grove: unavailable (no assigned plot)"
		groveStatusLabel.TextColor3 = Color3.fromRGB(220, 172, 151)
	elseif not area then
		groveStatusLabel.Text = "Grove: assigned area is still loading"
		groveStatusLabel.TextColor3 = Color3.fromRGB(231, 207, 151)
	else
		groveStatusLabel.Text = string.format("Grove Lv %d • %d planting slots", groveLevel, groveCapacity)
		groveStatusLabel.TextColor3 = Color3.fromRGB(160, 218, 158)
	end

	renderUpgrade()
	local selected = getSelectedSapling()
	saplingsLabel.Text = string.format("Saplings remaining: %d", #saplings)
	local mature = 0
	for _, groveTree in ipairs(groveTrees) do
		if groveTree.Stage == "mature" then mature += 1 end
	end
	groveSummaryLabel.Text = string.format("Grove: %d / %d planted • %d mature • %d growing",
		#groveTrees, groveCapacity, mature, #groveTrees - mature)
	if selected then
		selectedSaplingLabel.Text = string.format(
			"Selected: %s\nSize: %.2fx • %s",
			describeSapling(selected),
			type(selected.SizePotential) == "number" and selected.SizePotential or 1,
			tostring(selected.GeneticPassive or "Unknown")
		)
	else
		selectedSaplingLabel.Text = "Selected: none"
	end
	controlsLabel.Text = plantingMode
		and "[G] or [Esc] exit  •  [Q/E] select  •  click to plant"
		or "[G] planting mode  •  [Q/E] select sapling  •  [Esc] exit"
	feedbackLabel.Text = feedbackText
	if feedbackKind == "error" then
		feedbackLabel.TextColor3 = Color3.fromRGB(238, 170, 152)
	elseif feedbackKind == "success" then
		feedbackLabel.TextColor3 = Color3.fromRGB(160, 218, 158)
	else
		feedbackLabel.TextColor3 = Color3.fromRGB(185, 203, 183)
	end
	renderTreeManager()
end

local function createPreviewPart(name, size, color, material, shape, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Locked = true
	part.Color = color
	part.Material = material
	part.Transparency = transparency
	if shape then
		part.Shape = shape
	end
	part.Parent = previewModel
	return part
end

local function destroyPreview()
	if previewModel then
		previewModel:Destroy()
	end
	previewModel = nil
	previewTrunk = nil
	previewLeaves = nil
end

local function makePreview()
	destroyPreview()
	previewModel = Instance.new("Model")
	previewModel.Name = "LocalGrovePlantingPreview"
	previewTrunk = createPreviewPart(
		"PreviewTrunk",
		Vector3.new(0.65, 3.8, 0.65),
		Color3.fromRGB(126, 87, 57),
		Enum.Material.Wood,
		nil,
		0.12
	)
	previewLeaves = createPreviewPart(
		"PreviewCanopy",
		Vector3.new(2.6, 1.9, 2.4),
		Color3.fromRGB(105, 174, 93),
		Enum.Material.Plastic,
		nil,
		0.22
	)
	previewModel.PrimaryPart = previewTrunk
	previewModel.Parent = Workspace
end

local function getMousePlaneCoordinates(area)
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	-- GroveArea has CanQuery=false, so intersect its transformed top plane directly.
	local mouseLocation = UserInputService:GetMouseLocation()
	local guiInset = GuiService:GetGuiInset()
	local ray = camera:ViewportPointToRay(mouseLocation.X - guiInset.X, mouseLocation.Y - guiInset.Y)
	local planeNormal = area.CFrame.UpVector
	local planePoint = area.CFrame:PointToWorldSpace(Vector3.new(0, area.Size.Y * 0.5, 0))
	local denominator = ray.Direction:Dot(planeNormal)
	if math.abs(denominator) < 0.0001 then
		return nil
	end

	local distance = (planePoint - ray.Origin):Dot(planeNormal) / denominator
	if distance < 0 then
		return nil
	end

	local worldPoint = ray.Origin + ray.Direction * distance
	local localPoint = area.CFrame:PointToObjectSpace(worldPoint)
	local halfSize = area.Size * 0.5
	local visualInset = math.min(0.35, halfSize.X, halfSize.Z)
	return {
		localX = localPoint.X,
		localZ = localPoint.Z,
		visualX = math.clamp(localPoint.X, -halfSize.X + visualInset, halfSize.X - visualInset),
		visualZ = math.clamp(localPoint.Z, -halfSize.Z + visualInset, halfSize.Z - visualInset),
		groundY = -halfSize.Y + 0.05,
	}
end

local function updatePreview()
	if not plantingMode or not previewModel then
		return
	end

	local area = getAssignedGroveArea()
	local coordinates = area and getMousePlaneCoordinates(area)
	if not area or not coordinates then
		previewTrunk.Transparency = 1
		previewLeaves.Transparency = 1
		return
	end

	local selected = getSelectedSapling()
	local species = selected and selected.SpeciesId or "Oak"
	local trunkHeight = if species == "Bamboo" then 2.7
		else if species == "Ironwood" then 5.4 else 3.8
	previewTrunk.Size = Vector3.new(
		if species == "Bamboo" then 0.45 else if species == "Ironwood" then 0.95 else 0.65,
		trunkHeight,
		if species == "Bamboo" then 0.45 else if species == "Ironwood" then 0.95 else 0.65
	)
	previewLeaves.Size = if species == "Bamboo"
		then Vector3.new(2.3, 0.22, 0.6)
		else if species == "Ironwood"
		then Vector3.new(3.2, 2.3, 3.1)
		else Vector3.new(2.6, 1.9, 2.4)
	previewTrunk.Color = if species == "Bamboo"
		then Color3.fromRGB(127, 179, 80)
		else if species == "Ironwood" then Color3.fromRGB(79, 50, 36)
		else Color3.fromRGB(126, 87, 57)
	previewLeaves.Color = if species == "Bamboo"
		then Color3.fromRGB(63, 151, 68)
		else if species == "Ironwood" then Color3.fromRGB(48, 141, 91)
		else Color3.fromRGB(105, 174, 93)
	previewTrunk.Transparency = 0.12
	previewLeaves.Transparency = 0.22
	previewTrunk.CFrame = area.CFrame * CFrame.new(
		coordinates.visualX,
		coordinates.groundY + trunkHeight * 0.5,
		coordinates.visualZ
	)
	previewLeaves.CFrame = area.CFrame * CFrame.new(
		coordinates.visualX,
		coordinates.groundY + trunkHeight + 0.5,
		coordinates.visualZ
	)
end

local function setPlantingMode(enabled, showFeedback)
	if enabled then
		managerOpen=false
		confirmUprootUID=nil
		confirmUprootUntil=0
		if not stateLoaded or not hasAssignedGrove then
			setFeedback("Planting unavailable until an assigned Grove is ready.", "error")
			render()
			return false
		end
		if not getAssignedGroveArea() then
			setFeedback("Waiting for the assigned GroveArea to load.", "error")
			render()
			return false
		end
		if not plantEvent then
			setFeedback("Planting remote is unavailable; refresh and try again.", "error")
			render()
			return false
		end

		if not plantingMode then
			plantingMode = true
			makePreview()
			previewUpdateConnection = RunService.RenderStepped:Connect(updatePreview)
			if showFeedback then
				setFeedback("Planting mode active. Aim inside your Grove.", "info")
			end
		end
	else
		local wasPlanting = plantingMode
		plantingMode = false
		if previewUpdateConnection then
			previewUpdateConnection:Disconnect()
			previewUpdateConnection = nil
		end
		destroyPreview()
		if showFeedback and wasPlanting then
			setFeedback("Planting mode closed.", "info")
		end
	end

	render()
	return true
end

local function applySnapshot(snapshot)
	local revision = snapshot.Revision
	if type(revision) == "number" and revision == revision and revision >= 0 then
		if revision < latestStateRevision then
			return false
		end
		latestStateRevision = revision
	end

	stateLoaded = true
	groveLevel = tonumber(snapshot.GroveLevel) or 1
	groveMaxMutations = tonumber(snapshot.MaxMutations) or 1
	nextGroveUpgrade = snapshot.Upgrade
	passiveTotals = if type(snapshot.PassiveTotals) == "table" then snapshot.PassiveTotals else {}
	hasAssignedGrove = snapshot.HasAssignedGrove == true
	if type(snapshot.Capacity)=="number" and snapshot.Capacity>=1
		and snapshot.Capacity%1==0 then
		groveCapacity=snapshot.Capacity
	end
	saplings = {}
	if type(snapshot.Saplings) == "table" then
		for _, sapling in ipairs(snapshot.Saplings) do
			if type(sapling) == "table"
				and (type(sapling.UID) == "string" or type(sapling.UID) == "number")
				and sapling.UID ~= ""
			then
				table.insert(saplings, sapling)
			end
		end
	end

	groveTrees = {}
	if type(snapshot.GroveTrees) == "table" then
		for _, groveTree in ipairs(snapshot.GroveTrees) do
			if type(groveTree) == "table" and type(groveTree.UID) == "string" then
				table.insert(groveTrees, groveTree)
			end
		end
	end

	if selectedGroveTreeUID and not selectedManagedTree() then
		selectedGroveTreeUID=nil
		confirmUprootUID=nil
		confirmUprootUntil=0
	end
	if #groveTrees==0 or not hasAssignedGrove then
		managerOpen=false
	end

	groveMaterials = {}
	if type(snapshot.GroveMaterials) == "table" then
		for _, material in ipairs(snapshot.GroveMaterials) do
			if type(material) == "table" then
				table.insert(groveMaterials, material)
			end
		end
	end

	if not containsSaplingUID(saplings, selectedSaplingUID) then
		selectedSaplingUID = saplings[1] and saplings[1].UID or nil
	end

	if pendingPlantUID and not containsSaplingUID(saplings, pendingPlantUID) then
		pendingPlantUID = nil
		plantingAttemptId += 1
		setFeedback("Plant confirmed by Grove state.", "success")
	end

	if not hasAssignedGrove and plantingMode then
		setPlantingMode(false, false)
	end
	render()
	return true
end

refreshState = function(onComplete)
	if onComplete then
		table.insert(refreshCallbacks, onComplete)
	end
	if refreshInProgress then
		return
	end
	if not stateFunction then
		local callbacks = refreshCallbacks
		refreshCallbacks = {}
		for _, callback in ipairs(callbacks) do
			pcall(callback, false, nil)
		end
		render()
		return
	end

	refreshInProgress = true
	task.spawn(function()
		local succeeded, snapshot = pcall(function()
			return stateFunction:InvokeServer()
		end)
		local validSnapshot = succeeded and type(snapshot) == "table"
		if validSnapshot then
			applySnapshot(snapshot)
		else
			setFeedback("Could not refresh Grove state. Try again shortly.", "error")
			render()
		end

		refreshInProgress = false
		local callbacks = refreshCallbacks
		refreshCallbacks = {}
		for _, callback in ipairs(callbacks) do
			pcall(callback, validSnapshot, snapshot)
		end
	end)
end

local function setRemoteUpdateEvent(candidate)
	if stateUpdatedEvent == candidate then
		return
	end
	if stateUpdatedConnection then
		stateUpdatedConnection:Disconnect()
		stateUpdatedConnection = nil
	end
	stateUpdatedEvent = candidate
	if candidate then
		stateUpdatedConnection = candidate.OnClientEvent:Connect(function(snapshot)
			if type(snapshot) == "table" then
				applySnapshot(snapshot)
			else
				refreshState()
			end
		end)
	end
end

local function setSaplingDiscoveredEvent(candidate)
	if saplingDiscoveredEvent == candidate then
		return
	end
	if saplingDiscoveredConnection then
		saplingDiscoveredConnection:Disconnect()
		saplingDiscoveredConnection = nil
	end
	saplingDiscoveredEvent = candidate
	if candidate then
		saplingDiscoveredConnection = candidate.OnClientEvent:Connect(function(record)
			if type(record) == "table" then
				setFeedback("Discovered " .. describeSapling(record) .. "!", "success")
			end
			-- Server discovery is the source of truth; query the normal sanitized
			-- snapshot so the new UID becomes selectable without client prediction.
			refreshState()
		end)
	end
end

local function refreshRemotes()
	if cleanedUp then
		return
	end

	local foundFolder = ReplicatedStorage:FindFirstChild("Grove")
	if foundFolder ~= groveFolder then
		groveFolder = foundFolder
		if groveFolder then
			keepConnection(groveFolder.ChildAdded:Connect(refreshRemotes))
			keepConnection(groveFolder.ChildRemoved:Connect(refreshRemotes))
		end
	end

	stateFunction = nil
	plantEvent = nil
	local updateEvent
	local discoveredEvent
	if groveFolder then
		local stateCandidate = groveFolder:FindFirstChild("GetGroveStateRF")
		local plantCandidate = groveFolder:FindFirstChild("PlantSaplingRE")
		local updateCandidate = groveFolder:FindFirstChild("GroveStateUpdatedRE")
		local discoveryCandidate = groveFolder:FindFirstChild("SaplingDiscoveredRE")
		if stateCandidate and stateCandidate:IsA("RemoteFunction") then
			stateFunction = stateCandidate
		end
		if plantCandidate and plantCandidate:IsA("RemoteEvent") then
			plantEvent = plantCandidate
		end
		if updateCandidate and updateCandidate:IsA("RemoteEvent") then
			updateEvent = updateCandidate
		end
		if discoveryCandidate and discoveryCandidate:IsA("RemoteEvent") then
			discoveredEvent = discoveryCandidate
		end
	end
	setRemoteUpdateEvent(updateEvent)
	setSaplingDiscoveredEvent(discoveredEvent)
	if stateFunction and not stateLoaded then
		refreshState()
	else
		render()
	end
end

local function cycleSapling(direction)
	if #saplings == 0 then
		setFeedback("No saplings are available to select.", "error")
		render()
		return
	end

	local now = os.clock()
	if now - lastCycleAt < 0.12 then
		return
	end
	lastCycleAt = now

	local currentIndex = 1
	for index, sapling in ipairs(saplings) do
		if sapling.UID == selectedSaplingUID then
			currentIndex = index
			break
		end
	end
	local nextIndex = ((currentIndex - 1 + direction) % #saplings) + 1
	selectedSaplingUID = saplings[nextIndex].UID
	setFeedback("Selected " .. describeSapling(saplings[nextIndex]) .. ".", "info")
	render()
end

local function attemptPlant()
	if not plantingMode then
		return
	end
	local now = os.clock()
	if now - lastPlantAttemptAt < PLANT_DEBOUNCE_SECONDS then
		return
	end
	lastPlantAttemptAt = now

	local selected = getSelectedSapling()
	local area = getAssignedGroveArea()
	if not selected or not area or not plantEvent then
		setFeedback("Planting unavailable. Check the Grove and selected sapling.", "error")
		render()
		refreshState()
		return
	end

	local coordinates = getMousePlaneCoordinates(area)
	if not coordinates then
		setFeedback("Aim at the Grove area before planting.", "error")
		render()
		return
	end

	pendingPlantUID = selected.UID
	plantingAttemptId += 1
	local attemptId = plantingAttemptId
	setFeedback("Plant request sent; waiting for Grove state…", "info")
	render()

	local fired = pcall(function()
		-- Coordinates remain unclamped; the preview clamp is visual only.
		plantEvent:FireServer(selected.UID, coordinates.localX, coordinates.localZ)
	end)
	if not fired then
		pendingPlantUID = nil
		setFeedback("Plant request could not be sent. Check the Grove and try again.", "error")
		render()
		refreshState()
		return
	end

	task.delay(STATE_CHECK_DELAY_SECONDS, function()
		if cleanedUp or attemptId ~= plantingAttemptId then
			return
		end
		refreshState(function(refreshed, snapshot)
			if cleanedUp or attemptId ~= plantingAttemptId then
				return
			end
			if not refreshed then
				pendingPlantUID = nil
				setFeedback("Plant result could not be confirmed. Refresh and check again.", "error")
			elseif containsSaplingUID(saplings, selected.UID) then
				pendingPlantUID = nil
				setFeedback("Plant was not confirmed. Check Grove availability and try again.", "error")
			else
				pendingPlantUID = nil
				setFeedback("Plant confirmed by Grove state.", "success")
			end
			render()
		end)
	end)
end

local function isPointerOverPanel()
	local mouseLocation = UserInputService:GetMouseLocation()
	local succeeded, objects = pcall(function()
		return playerGui:GetGuiObjectsAtPosition(mouseLocation.X, mouseLocation.Y)
	end)
	if not succeeded then
		return false
	end
	for _, object in ipairs(objects) do
		if object:IsDescendantOf(screenGui) then
			return true
		end
	end
	return false
end

-- Click a planted tree to select it directly, or use the UI arrows
-- while it is still a stump/rebuilding. Server metadata is NOT trusted for
-- deletion; the UID is revalidated against the player's profile there.
local function selectClickedGroveTree()
	if plantingMode or uprootPending or not panel.Visible
		or not hasAssignedGrove or isPointerOverPanel() then return end
	local mouse=player:GetMouse()
	local current=mouse and mouse.Target
	while current and current~=Workspace do
		if current:IsA("Model") and current:GetAttribute("PersistentGrove")==true then
			if current:GetAttribute("OwnerUserId")==player.UserId then
				local uid=current:GetAttribute("GroveTreeUID")
				if type(uid)=="string" then selectManagedTree(uid) end
			end
			return
		end
		current=current.Parent
	end
end

keepConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType==Enum.UserInputType.MouseButton1 then
		selectClickedGroveTree()
		return
	end
	if input.KeyCode == Enum.KeyCode.G and (panel.Visible or plantingMode) then
		local wasPlanting=plantingMode
		if setPlantingMode(not plantingMode,true) and not wasPlanting then closeStall() end
	elseif input.KeyCode == Enum.KeyCode.Q and (panel.Visible or plantingMode) then
		cycleSapling(-1)
	elseif input.KeyCode == Enum.KeyCode.E and (panel.Visible or plantingMode) then
		cycleSapling(1)
	elseif input.KeyCode == Enum.KeyCode.Escape then
		setPlantingMode(false,true)
		closeStall()
	end
end))

ContextActionService:BindActionAtPriority(
	ACTION_NAME,
	function(_, inputState)
		if not plantingMode then
			return Enum.ContextActionResult.Pass
		end
		if inputState == Enum.UserInputState.Begin and not isPointerOverPanel() then
			attemptPlant()
		end
		return Enum.ContextActionResult.Sink
	end,
	false,
	3000,
	Enum.UserInputType.MouseButton1
)

keepConnection(ReplicatedStorage.ChildAdded:Connect(function(child)
	if child.Name == "Grove" then
		refreshRemotes()
	end
end))
keepConnection(ReplicatedStorage.ChildRemoved:Connect(function(child)
	if child == groveFolder then
		refreshRemotes()
	end
end))
keepConnection(Workspace.DescendantAdded:Connect(function(descendant)
	if descendant.Name == "GroveArea" or descendant.Name == "PlayerPlots" then
		render()
	elseif managerOpen and descendant:IsA("Model")
		and descendant.Name=="Tree" then
		task.defer(highlightManagedTree)
	end
end))
keepConnection(player:GetAttributeChangedSignal("PlotNumber"):Connect(render))
keepConnection(player.CharacterRemoving:Connect(function()
	closeStall()
	setPlantingMode(false, false)
end))
keepConnection(player.CharacterAdded:Connect(function()
	closeStall()
	setPlantingMode(false, false)
end))
keepConnection(script.Destroying:Connect(function()
	if cleanedUp then
		return
	end
	cleanedUp = true
	if previewUpdateConnection then
		previewUpdateConnection:Disconnect()
		previewUpdateConnection = nil
	end
	ContextActionService:UnbindAction(ACTION_NAME)
	destroyPreview()
	if selectionHighlight then
		selectionHighlight:Destroy()
		selectionHighlight=nil
	end
	if stateUpdatedConnection then
		stateUpdatedConnection:Disconnect()
		stateUpdatedConnection = nil
	end
	if saplingDiscoveredConnection then
		saplingDiscoveredConnection:Disconnect()
		saplingDiscoveredConnection = nil
	end
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	if screenGui.Parent then
		screenGui:Destroy()
	end
end))

-- Bind dynamically to survive world rebuilds and streaming.
keepConnection(ProximityPromptService.PromptTriggered:Connect(function(prompt,who)
	if who~=player or prompt.Name~="GroveShopPrompt" or not nearGroveStall() then return end
	local station=prompt.Parent and prompt.Parent.Parent
	local world=Workspace:FindFirstChild("SourceWorld")
	if not station or station.Parent~=world or station.Name~="GroveShopStation" then return end
	if playerGui:GetAttribute("EconomyModalOpen")==true then return end
	setPlantingMode(false,false)
	stallOpen=true
	syncGrovePanelWithEconomy()
	render()
	if refreshState then refreshState() end
	refreshSaplingShop()
end))
task.spawn(function()
	while not cleanedUp do
		task.wait(0.2)
		if stallOpen then syncGrovePanelWithEconomy() end
	end
end)
render()
refreshRemotes()
-- No client-side authority over stock: periodically refresh the actual
-- server snapshot so rare restocks and affordability appear automatically.
task.spawn(function()
	while not cleanedUp do
		task.wait(1)
		if not cleanedUp and panel.Visible then
			renderRestock()
			if managerOpen and groveManagerPanel.Visible then
				local tree=selectedManagedTree()
				if tree and tree.Stage~="mature" then
					local seconds=math.max(0,math.ceil((tonumber(tree.MaturesAt) or os.time())-os.time()))
					local mutations=formatMutationNames(tree.Mutations)
					local name=if mutations=="" then tostring(tree.SpeciesId) else mutations.." "..tostring(tree.SpeciesId)
					managerDetails.Text=string.format("%s\nGenetic potential: %.2fx  •  Current size: %.2fx\nStage: %s • %dm %02ds remaining",
						name,tonumber(tree.SizePotential) or 1,tonumber(tree.CurrentSizeScale) or 1,tostring(tree.Stage or "growing"),math.floor(seconds/60),seconds%60)
				end
			end
			if not shopSnapshot or os.time()>=shopSnapshot.RestockAt or os.time()%10==0 then refreshSaplingShop() end
		end
	end
end)
