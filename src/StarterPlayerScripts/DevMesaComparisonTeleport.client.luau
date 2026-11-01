-- Studio-only shortcut for the focused TERRAIN-INSPIRED / BORDER-INSPIRED pair.
-- The existing DEV GALLERY button keeps its harvest-showcase destination.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

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
	if not gallery or gallery.Parent ~= Workspace then
		return nil
	end
	local destination = gallery:GetAttribute("MesaComparisonTeleportCFrame")
	return if typeof(destination) == "CFrame" then destination else nil
end

local function updateButton()
	button.Visible = getDestination() ~= nil
end

local function setGallery(candidate)
	if galleryAttributeChanged then
		galleryAttributeChanged:Disconnect()
		galleryAttributeChanged = nil
	end
	gallery = candidate
	if gallery then
		galleryAttributeChanged = gallery:GetAttributeChangedSignal("MesaComparisonTeleportCFrame"):Connect(updateButton)
	end
	updateButton()
end

local function getMesaComparison()
	if not gallery or gallery.Parent ~= Workspace then
		return nil
	end
	local showcaseRoot = gallery:FindFirstChild("DevMesaShapeShowcase")
	local support = showcaseRoot and showcaseRoot:FindFirstChild("MesaShowcaseSupport")
	local samples = showcaseRoot and showcaseRoot:FindFirstChild("CliffSamples")
	local comparison = samples and samples:FindFirstChild("MesaShapeShowcase")
	if not support or not support:IsA("BasePart") or not comparison or not comparison:IsA("Model") then
		return nil
	end
	if comparison:GetAttribute("SampleCount") ~= 2 then
		return nil
	end
	local terrainStudy = comparison:FindFirstChild("TerrainLikePlateau")
	local borderStudy = comparison:FindFirstChild("BorderLikePillar")
	if not terrainStudy or not terrainStudy:IsA("Model")
		or not borderStudy or not borderStudy:IsA("Model")
	then
		return nil
	end
	local formationCount = 0
	for _, child in ipairs(comparison:GetChildren()) do
		if child:IsA("Model") then
			formationCount += 1
		end
	end
	return if formationCount == 2 then comparison else nil
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

local function aimCameraAtMesaPair(destination)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local forward = destination.LookVector
	local cameraPosition = destination.Position - forward * 12 + Vector3.new(0, 8, 0)
	local aimPoint = destination.Position + forward * 68 + Vector3.new(0, 18, 0)
	camera.CFrame = CFrame.lookAt(cameraPosition, aimPoint)
	camera.Focus = CFrame.new(aimPoint)
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
	local character = player.Character
	if teleporting or not destination or not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end

	teleporting = true
	button.Text = "LOADING..."
	if Workspace.StreamingEnabled then
		local ok, err = pcall(function()
			player:RequestStreamAroundAsync(destination.Position, 5)
		end)
		if not ok then
			warn("[DevMesaComparisonTeleport] Could not stream the mesa comparison: " .. tostring(err))
			button.Text = "MESA COMPARISON"
			teleporting = false
			return
		end
	end
	if not waitForMesaComparison(5) then
		warn("[DevMesaComparisonTeleport] Mesa comparison did not become ready before teleport")
		button.Text = "MESA COMPARISON"
		teleporting = false
		return
	end

	local currentDestination = getDestination()
	if player.Character == character
		and character.Parent
		and character:FindFirstChild("HumanoidRootPart")
		and currentDestination
	then
		character:PivotTo(currentDestination)
		aimCameraAtMesaPair(currentDestination)
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
