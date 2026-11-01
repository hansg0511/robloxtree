-- Studio-only quick travel for the boundary overview and its three side views.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local BUILD_VERSION = 11
local MIN_SAMPLE_LENGTH = 200
local CAMERA_REAR_OFFSET = 12
local SAMPLE_DEFINITIONS = {
	{
		Text = "MESA COMPARISON",
		TeleportAttribute = "MesaComparisonTeleportCFrame",
		CenterAttribute = "MesaComparisonSampleCenter",
		Color = Color3.fromRGB(65, 105, 72),
	},
	{
		Text = "TERRAIN BOUNDARY",
		SampleName = "TerrainBoundarySample",
		MinimumDepthStagger = 18,
		TeleportAttribute = "MesaTerrainBoundaryTeleportCFrame",
		CenterAttribute = "MesaTerrainBoundarySampleCenter",
		Color = Color3.fromRGB(76, 113, 82),
	},
	{
		Text = "FACETED BOUNDARY",
		SampleName = "FacetedBoundarySample",
		MinimumDepthStagger = 22,
		TeleportAttribute = "MesaFacetedBoundaryTeleportCFrame",
		CenterAttribute = "MesaFacetedBoundarySampleCenter",
		Color = Color3.fromRGB(100, 94, 72),
	},
	{
		Text = "MIXED BOUNDARY",
		SampleName = "MixedBoundarySample",
		MinimumDepthStagger = 26,
		TeleportAttribute = "MesaMixedBoundaryTeleportCFrame",
		CenterAttribute = "MesaMixedBoundarySampleCenter",
		Color = Color3.fromRGB(87, 101, 110),
	},
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "DevMesaComparisonTeleport"
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "BoundaryNavigation"
panel.AnchorPoint = Vector2.new(1, 1)
panel.Position = UDim2.new(1, -14, 1, -14)
panel.Size = UDim2.fromOffset(242, 224)
panel.BackgroundColor3 = Color3.fromRGB(27, 35, 35)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(184, 191, 168)
panelStroke.Transparency = 0.72
panelStroke.Thickness = 1
panelStroke.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.fromOffset(12, 8)
title.Size = UDim2.new(1, -24, 0, 20)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "BOUNDARY SAMPLES"
title.TextColor3 = Color3.fromRGB(244, 242, 225)
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Instructions"
subtitle.Position = UDim2.fromOffset(12, 29)
subtitle.Size = UDim2.new(1, -24, 0, 17)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "Hub or jump to one sample"
subtitle.TextColor3 = Color3.fromRGB(192, 200, 184)
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = panel

local status = Instance.new("TextLabel")
status.Name = "Status"
status.AnchorPoint = Vector2.new(0, 1)
status.Position = UDim2.new(0, 12, 1, -7)
status.Size = UDim2.new(1, -24, 0, 15)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.Text = ""
status.TextColor3 = Color3.fromRGB(225, 198, 138)
status.TextSize = 10
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = panel

local buttons = {}
local gallery
local galleryAttributeChanged
local galleryAdded
local galleryRemoved
local teleporting = false

local function hasCurrentGallery()
	return gallery ~= nil
		and gallery.Parent == Workspace
		and gallery:GetAttribute("MesaShapeShowcaseVersion") == BUILD_VERSION
end

local function getComparisonHub()
	if not hasCurrentGallery() then
		return nil
	end
	local showcaseRoot = gallery:FindFirstChild("DevMesaShapeShowcase")
	local support = showcaseRoot and showcaseRoot:FindFirstChild("MesaShowcaseSupport")
	if not support or not support:IsA("BasePart")
		or support:GetAttribute("WalkableUtilitySurface") ~= true
	then
		return nil
	end
	return support
end

local function getSampleRun(definition)
	if not definition.SampleName or not hasCurrentGallery() then
		return nil
	end
	local showcaseRoot = gallery:FindFirstChild("DevMesaShapeShowcase")
	local samplesFolder = showcaseRoot and showcaseRoot:FindFirstChild("BoundarySamples")
	local runs = samplesFolder and samplesFolder:FindFirstChild("MesaBoundarySampleRuns")
	if not runs or not runs:IsA("Model")
		or runs:GetAttribute("BuildStatus") ~= "Ready"
		or runs:GetAttribute("SampleCount") ~= #SAMPLE_DEFINITIONS - 1
	then
		return nil
	end
	local run = runs:FindFirstChild(definition.SampleName)
	if not run or not run:IsA("Model") or run.ModelStreamingMode ~= Enum.ModelStreamingMode.Atomic
		or run:GetAttribute("BuildStatus") ~= "Ready" or not run.PrimaryPart
	then
		return nil
	end
	local visibleLength = run:GetAttribute("VisibleLengthZ")
	local depthStagger = run:GetAttribute("DepthStaggerRangeX")
	if type(visibleLength) ~= "number" or visibleLength < MIN_SAMPLE_LENGTH
		or type(depthStagger) ~= "number" or depthStagger < definition.MinimumDepthStagger
	then
		return nil
	end
	return run
end

local function getDestination(definition)
	if not hasCurrentGallery() then
		return nil, nil
	end
	local destination = gallery:GetAttribute(definition.TeleportAttribute)
	local center = gallery:GetAttribute(definition.CenterAttribute)
	if typeof(destination) ~= "CFrame" or typeof(center) ~= "Vector3" then
		return nil, nil
	end
	return destination, center
end

local function updatePanel()
	local ready = hasCurrentGallery()
	for _, definition in ipairs(SAMPLE_DEFINITIONS) do
		local destination, center = getDestination(definition)
		if not destination or not center then
			ready = false
			break
		end
	end
	panel.Visible = ready
end

local function setGallery(candidate)
	if galleryAttributeChanged then
		galleryAttributeChanged:Disconnect()
		galleryAttributeChanged = nil
	end
	gallery = candidate
	if gallery then
		galleryAttributeChanged = gallery.AttributeChanged:Connect(updatePanel)
	end
	updatePanel()
end

local function isSelectedViewReady(definition)
	if definition.SampleName then
		return getSampleRun(definition) ~= nil
	end
	return getComparisonHub() ~= nil
end

local function waitForSelectedView(definition, timeout)
	local deadline = os.clock() + timeout
	repeat
		if isSelectedViewReady(definition) then
			return true
		end
		if os.clock() >= deadline then
			break
		end
		RunService.Heartbeat:Wait()
	until not gallery or gallery.Parent ~= Workspace
	return false
end

local function aimCameraAtSample(destination, sampleCenter)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local direction = sampleCenter - destination.Position
	if direction.Magnitude <= 0.01 then
		return
	end
	local cameraPosition = destination.Position - direction.Unit * CAMERA_REAR_OFFSET + Vector3.new(0, 34, 0)
	camera.CFrame = CFrame.lookAt(cameraPosition, sampleCenter)
	camera.Focus = CFrame.new(sampleCenter)
end

local function setBusy(isBusy, activeDefinition)
	for _, entry in ipairs(buttons) do
		entry.Button.Active = not isBusy
		entry.Button.AutoButtonColor = not isBusy
		entry.Button.BackgroundTransparency = if isBusy then 0.24 else 0
		entry.Button.Text = if isBusy and entry.Definition == activeDefinition
			then "LOADING..."
			else entry.Definition.Text
	end
	if isBusy then
		status.Text = "Loading the selected view..."
	end
end

local function teleportTo(definition)
	local destination, sampleCenter = getDestination(definition)
	local character = player.Character
	if teleporting or not destination or not sampleCenter or not character
		or not character:FindFirstChild("HumanoidRootPart")
	then
		return
	end

	teleporting = true
	setBusy(true, definition)
	if Workspace.StreamingEnabled then
		local ok, err = pcall(function()
			player:RequestStreamAroundAsync(sampleCenter, 6)
			player:RequestStreamAroundAsync(destination.Position, 6)
		end)
		if not ok then
			warn("[DevMesaComparisonTeleport] Could not stream the boundary view: " .. tostring(err))
			status.Text = "Could not load that view. Try again."
			setBusy(false, nil)
			teleporting = false
			return
		end
	end

	if not waitForSelectedView(definition, 6) then
		status.Text = if definition.SampleName
			then "The selected sample is still loading. Try again shortly."
			else "The comparison is still loading. Try again shortly."
		setBusy(false, nil)
		teleporting = false
		return
	end

	local currentDestination, currentSampleCenter = getDestination(definition)
	local teleported = false
	if player.Character == character
		and character.Parent
		and character:FindFirstChild("HumanoidRootPart")
		and currentDestination
		and currentSampleCenter
	then
		character:PivotTo(currentDestination)
		RunService.RenderStepped:Wait()
		aimCameraAtSample(currentDestination, currentSampleCenter)
		teleported = true
	else
		status.Text = "The character changed before the view was ready."
	end

	if teleported then
		status.Text = ""
	end
	setBusy(false, nil)
	teleporting = false
end

for index, definition in ipairs(SAMPLE_DEFINITIONS) do
	local button = Instance.new("TextButton")
	button.Name = if index == 1 then "GoToMesaComparison" else "GoTo" .. definition.SampleName
	button.Position = UDim2.fromOffset(12, 52 + (index - 1) * 38)
	button.Size = UDim2.new(1, -24, 0, 33)
	button.BackgroundColor3 = definition.Color
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = definition.Text
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = 12
	button.AutoButtonColor = true
	button.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = button
	button.Activated:Connect(function()
		teleportTo(definition)
	end)
	table.insert(buttons, { Definition = definition, Button = button })
end

galleryAdded = Workspace.ChildAdded:Connect(function(child)
	if child.Name == "DevTreeGallery" then
		setGallery(child)
	end
end)
galleryRemoved = Workspace.ChildRemoved:Connect(function(child)
	if child == gallery then
		setGallery(nil)
	end
end)
setGallery(Workspace:FindFirstChild("DevTreeGallery"))

script.Destroying:Connect(function()
	if galleryAttributeChanged then galleryAttributeChanged:Disconnect() end
	if galleryAdded then galleryAdded:Disconnect() end
	if galleryRemoved then galleryRemoved:Disconnect() end
	if gui.Parent then gui:Destroy() end
end)
