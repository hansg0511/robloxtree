-- Studio-only shortcut to the side-by-side boundary sample runs.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local BUILD_VERSION = 8
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "DevMesaComparisonTeleport"
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = playerGui

local button = Instance.new("TextButton")
button.Name = "GoToMesaComparison"
button.AnchorPoint = Vector2.new(1, 1)
button.Position = UDim2.new(1, -16, 1, -68)
button.Size = UDim2.fromOffset(186, 42)
button.BackgroundColor3 = Color3.fromRGB(65, 105, 72)
button.BorderSizePixel = 0
button.Font = Enum.Font.GothamBold
button.Text = "MESA COMPARISON"
button.TextColor3 = Color3.new(1, 1, 1)
button.TextSize = 14
button.Visible = false
button.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = button

local gallery
local galleryAttributeChanged
local galleryAdded
local galleryRemoved
local teleporting = false

local function getDestination()
	if not gallery or gallery.Parent ~= Workspace
		or gallery:GetAttribute("MesaShapeShowcaseVersion") ~= BUILD_VERSION
	then
		return nil
	end
	local destination = gallery:GetAttribute("MesaComparisonTeleportCFrame")
	return if typeof(destination) == "CFrame" then destination else nil
end

local function getSampleCenter()
	if not gallery or gallery.Parent ~= Workspace
		or gallery:GetAttribute("MesaShapeShowcaseVersion") ~= BUILD_VERSION
	then
		return nil
	end
	local center = gallery:GetAttribute("MesaComparisonSampleCenter")
	return if typeof(center) == "Vector3" then center else nil
end

local function updateButton()
	button.Visible = getDestination() ~= nil and getSampleCenter() ~= nil
end

local function setGallery(candidate)
	if galleryAttributeChanged then
		galleryAttributeChanged:Disconnect()
		galleryAttributeChanged = nil
	end
	gallery = candidate
	if gallery then
		galleryAttributeChanged = gallery.AttributeChanged:Connect(updateButton)
	end
	updateButton()
end

local function getMesaComparison()
	if not gallery or gallery.Parent ~= Workspace then
		return nil
	end
	local showcaseRoot = gallery:FindFirstChild("DevMesaShapeShowcase")
	local support = showcaseRoot and showcaseRoot:FindFirstChild("MesaShowcaseSupport")
	local samples = showcaseRoot and showcaseRoot:FindFirstChild("BoundarySamples")
	local runs = samples and samples:FindFirstChild("MesaBoundarySampleRuns")
	if not support or not support:IsA("BasePart") or not runs or not runs:IsA("Model") then
		return nil
	end
	if runs:GetAttribute("BuildStatus") ~= "Ready" or runs:GetAttribute("SampleCount") ~= 2 then
		return nil
	end
	local terrainRun = runs:FindFirstChild("TerrainBoundarySample")
	local facetedRun = runs:FindFirstChild("FacetedBoundarySample")
	if not terrainRun or not terrainRun:IsA("Model")
		or not facetedRun or not facetedRun:IsA("Model")
		or terrainRun:GetAttribute("BuildStatus") ~= "Ready"
		or facetedRun:GetAttribute("BuildStatus") ~= "Ready"
	then
		return nil
	end
	local modelCount = 0
	for _, child in ipairs(runs:GetChildren()) do
		if child:IsA("Model") then
			modelCount += 1
		end
	end
	return if modelCount == 2 then runs else nil
end

local function waitForMesaComparison(timeout)
	local deadline = os.clock() + timeout
	repeat
		if getMesaComparison() then
			return true
		end
		if os.clock() >= deadline then
			break
		end
		RunService.Heartbeat:Wait()
	until not gallery or gallery.Parent ~= Workspace
	return false
end

local function aimCameraAtBoundaryRuns(destination, sampleCenter)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local forward = (sampleCenter - destination.Position).Unit
	local cameraPosition = destination.Position - forward * 12 + Vector3.new(0, 8, 0)
	camera.CFrame = CFrame.lookAt(cameraPosition, sampleCenter)
	camera.Focus = CFrame.new(sampleCenter)
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

button.Activated:Connect(function()
	local destination = getDestination()
	local sampleCenter = getSampleCenter()
	local character = player.Character
	if teleporting or not destination or not sampleCenter or not character
		or not character:FindFirstChild("HumanoidRootPart")
	then
		return
	end

	teleporting = true
	button.Text = "LOADING..."
	if Workspace.StreamingEnabled then
		local ok, err = pcall(function()
			player:RequestStreamAroundAsync(sampleCenter, 5)
			player:RequestStreamAroundAsync(destination.Position, 5)
		end)
		if not ok then
			warn("[DevMesaComparisonTeleport] Could not stream the boundary comparison: " .. tostring(err))
			button.Text = "MESA COMPARISON"
			teleporting = false
			return
		end
	end
	if not waitForMesaComparison(5) then
		warn("[DevMesaComparisonTeleport] Boundary sample runs did not become ready before teleport")
		button.Text = "MESA COMPARISON"
		teleporting = false
		return
	end

	local currentDestination = getDestination()
	local currentSampleCenter = getSampleCenter()
	if player.Character == character
		and character.Parent
		and character:FindFirstChild("HumanoidRootPart")
		and currentDestination
		and currentSampleCenter
	then
		character:PivotTo(currentDestination)
		aimCameraAtBoundaryRuns(currentDestination, currentSampleCenter)
	end

	button.Text = "MESA COMPARISON"
	teleporting = false
end)

script.Destroying:Connect(function()
	if galleryAttributeChanged then galleryAttributeChanged:Disconnect() end
	if galleryAdded then galleryAdded:Disconnect() end
	if galleryRemoved then galleryRemoved:Disconnect() end
	if gui.Parent then gui:Destroy() end
end)
