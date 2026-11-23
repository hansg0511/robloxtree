-- Small client-only interaction for testing Personal Grove sapling planting.
-- The server remains authoritative for sapling ownership and placement validity.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local shopRF = ReplicatedStorage:WaitForChild("Grove"):WaitForChild("GetSaplingShopRF")
local buySaplingRE = ReplicatedStorage:WaitForChild("Grove"):WaitForChild("BuySaplingRE")

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
panel.Size = UDim2.fromOffset(372, 307)
panel.BackgroundColor3 = Color3.fromRGB(21, 29, 25)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Parent = screenGui

-- The Grove prototype HUD must not sit on top of Bag/Shop/Forge details.
-- It returns automatically when the last economy panel closes.
local function syncGrovePanelWithEconomy()
	panel.Visible = playerGui:GetAttribute("EconomyModalOpen") ~= true
end
keepConnection(playerGui:GetAttributeChangedSignal("EconomyModalOpen"):Connect(syncGrovePanelWithEconomy))
syncGrovePanelWithEconomy()

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
titleLabel.Text = "PERSONAL GROVE"

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

local heartwoodLabel = makeLabel(
	panel,
	"Heartwood",
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

-- Shop is a compact strip beneath the EXISTING Grove controls, not
-- another modal to maintain. Normal stock stays present during rare resets.
local shopHeading = makeLabel(panel,"SaplingShopHeading",
	UDim2.fromOffset(13,207),UDim2.new(1,-26,0,16),
	Enum.Font.GothamBold,12,Color3.fromRGB(232,218,153))
shopHeading.Text="SAPLING SHOP • COMMON ALWAYS STOCKED"
local function createShopButton(name,x,y,w)
	local b=Instance.new("TextButton")
	b.Name=name
	b.Size=UDim2.fromOffset(w,33)
	b.Position=UDim2.fromOffset(x,y)
	b.BackgroundColor3=Color3.fromRGB(59,106,71)
	b.TextColor3=Color3.fromRGB(240,255,228)
	b.TextSize=11
	b.TextWrapped=true
	b.Font=Enum.Font.GothamBold
	b.BorderSizePixel=0
	b.Parent=panel
	local corner=Instance.new("UICorner")
	corner.CornerRadius=UDim.new(0,6)
	corner.Parent=b
	return b
end
local shopCommonButtons={
	common_bamboo=createShopButton("BuyBambooSapling",13,226,111),
	common_oak=createShopButton("BuyOakSapling",129,226,111),
	common_ironwood=createShopButton("BuyIronwoodSapling",245,226,111),
}
local shopRareButton=createShopButton("BuyRareSapling",13,266,343)
local shopSnapshot
local shopPending=false
local shopBusy=false
local refreshSaplingShop
local function renderSaplingShop()
	local stock={}
	if type(shopSnapshot)=="table" then
		for _,offer in ipairs(shopSnapshot.Offers or {}) do
			stock[offer.Id]=offer
			if offer.Rare then stock._Rare=offer end
		end
	end
	for id,b in pairs(shopCommonButtons) do
		local offer=stock[id]
		b.Text=if offer then
			(string.upper(tostring(offer.SpeciesId)).."  "..tostring(offer.Price))
			else "LOADING..."
		b.Active=offer~=nil and offer.CanBuy==true and not shopPending
		b.AutoButtonColor=b.Active
		b.BackgroundColor3=if b.Active then Color3.fromRGB(59,106,71)
			else Color3.fromRGB(81,89,83)
	end
	local rare=stock._Rare
	if rare then
		shopRareButton.Text=if rare.SoldOut then
			"SOLD OUT • "..string.upper(rare.Name)
			else string.upper(rare.Name).." • "..tostring(rare.Price).." COINS"
		shopRareButton.Active=rare.CanBuy==true and not shopPending
	else
		shopRareButton.Text="RARE SAPLING: NONE THIS RESTOCK"
		shopRareButton.Active=false
	end
	shopRareButton.AutoButtonColor=shopRareButton.Active
	shopRareButton.BackgroundColor3=if shopRareButton.Active
		then Color3.fromRGB(113,83,165) else Color3.fromRGB(81,89,83)
end
local function buyOffer(id)
	if shopPending or not shopSnapshot then return end
	local offer
	for _,o in ipairs(shopSnapshot.Offers or {}) do
		if o.Id==id and o.CanBuy==true then offer=o break end
	end
	if not offer then return end
	shopPending=true
	renderSaplingShop()
	buySaplingRE:FireServer(id)
	-- Network problems must not leave buttons disabled indefinitely.
	task.delay(3,function()
		if shopPending and not cleanedUp then
			shopPending=false
			renderSaplingShop()
		end
	end)
end
for id,b in pairs(shopCommonButtons) do
	b.Activated:Connect(function() buyOffer(id) end)
end
shopRareButton.Activated:Connect(function()
	if type(shopSnapshot)~="table" then return end
	for _,o in ipairs(shopSnapshot.Offers or {}) do
		if o.Rare then buyOffer(o.Id) return end
	end
end)
refreshSaplingShop=function()
	if shopBusy or cleanedUp then return end
	shopBusy=true
	task.spawn(function()
		local ok,result=pcall(function() return shopRF:InvokeServer() end)
		shopBusy=false
		if cleanedUp then return end
		if ok and type(result)=="table" then
			shopSnapshot=result
		end
		renderSaplingShop()
	end)
end
keepConnection(buySaplingRE.OnClientEvent:Connect(function(result)
	shopPending=false
	if type(result)=="table" and result.Reason=="PURCHASED" then
		setFeedback("Bought "..tostring(result.Name or "sapling").."! Plant with [G].","success")
		if refreshState then refreshState() end
	else
		local names={
			NOT_ENOUGH_COINS="Not enough coins for this sapling.",
			SOLD_OUT="Rare sapling already purchased this restock.",
			OFFER_NOT_AVAILABLE="Offer rotated. Please check the shop again.",
			SAPLING_STORAGE_FULL="Too many unplanted saplings.",
			FOREST_LOCKED="Unlock this forest before buying its saplings.",
		}
		setFeedback(names[result and result.Reason]
			or "Sapling purchase unavailable. Try again.","error")
	end
	refreshSaplingShop()
	renderSaplingShop()
end))
renderSaplingShop()

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

local function render()
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
		groveStatusLabel.Text = "Grove: available"
		groveStatusLabel.TextColor3 = Color3.fromRGB(160, 218, 158)
	end

	local selected = getSelectedSapling()
	saplingsLabel.Text = string.format("Saplings remaining: %d", #saplings)
	local mature = 0
	for _, groveTree in ipairs(groveTrees) do
		if groveTree.Stage == "mature" then mature += 1 end
	end
	heartwoodLabel.Text = string.format("Grove: %d planted • %d mature • Heartwood: %d",
		#groveTrees, mature, #groveMaterials)
	if selected then
		selectedSaplingLabel.Text = string.format(
			"Selected: %s\nSize: %.2fx",
			describeSapling(selected),
			type(selected.SizePotential) == "number" and selected.SizePotential or 1
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
	hasAssignedGrove = snapshot.HasAssignedGrove == true
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

keepConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.G then
		setPlantingMode(not plantingMode, true)
	elseif input.KeyCode == Enum.KeyCode.Q then
		cycleSapling(-1)
	elseif input.KeyCode == Enum.KeyCode.E then
		cycleSapling(1)
	elseif input.KeyCode == Enum.KeyCode.Escape then
		setPlantingMode(false, true)
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
	end
end))
keepConnection(player:GetAttributeChangedSignal("PlotNumber"):Connect(render))
keepConnection(player.CharacterRemoving:Connect(function()
	setPlantingMode(false, false)
end))
keepConnection(player.CharacterAdded:Connect(function()
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

render()
refreshRemotes()
