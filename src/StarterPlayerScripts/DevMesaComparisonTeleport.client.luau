-- Studio-only shortcut for the clean-versus-refined mesa pair.
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
	if typeof(destination) == "CFrame" then
		return destination
	end
	return nil
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

local function hasWedgeGeometry(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("WedgePart") then
			return true
		end
	end
	return false
end

local function isMesaComparisonReady()
	if not gallery or gallery.Parent ~= Workspace then
		return false
	end

	local showcase = gallery:FindFirstChild("DevMesaShapeShowcase")
	local support = showcase and showcase:FindFirstChild("MesaShowcaseSupport")
	local samples = showcase and showcase:FindFirstChild("CliffSamples")
	local comparison = samples and samples:FindFirstChild("MesaIrregularComparison")
	if not support or not support:IsA("BasePart") or not comparison or not comparison:IsA("Model") then
		return false
	end

	local clean = comparison:FindFirstChild("CleanPrismControl")
	local refined = comparison:FindFirstChild("RefinedIrregularMesa")
	return clean ~= nil
		and clean:IsA("Model")
		and hasWedgeGeometry(clean)
		and refined ~= nil
		and refined:IsA("Model")
		and hasWedgeGeometry(refined)
end

local function waitForMesaComparison(timeout)
	local deadline = os.clock() + timeout
	repeat
		if isMesaComparisonReady() then
			return true
		end
		if os.clock() >= deadline then
			break
		end
		RunService.Heartbeat:Wait()
	until not gallery or gallery.Parent ~= Workspace
	return false
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
	end

	button.Text = "MESA COMPARISON"
	teleporting = false
end)

script.Destroying:Connect(function()
	if galleryAttributeChanged then
		galleryAttributeChanged:Disconnect()
	end
	if galleryAdded then
		galleryAdded:Disconnect()
	end
	if galleryRemoved then
		galleryRemoved:Disconnect()
	end
	if gui.Parent then
		gui:Destroy()
	end
end)
