-- Studio-only shortcut. The gallery and its teleport button never exist in live servers.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "DevGalleryTeleport"
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = playerGui

local button = Instance.new("TextButton")
button.Name = "GoToDevGallery"
button.AnchorPoint = Vector2.new(1, 1)
button.Position = UDim2.new(1, -16, 1, -16)
button.Size = UDim2.fromOffset(164, 42)
button.BackgroundColor3 = Color3.fromRGB(44, 125, 66)
button.BorderSizePixel = 0
button.Font = Enum.Font.GothamBold
button.Text = "DEV GALLERY"
button.TextColor3 = Color3.new(1, 1, 1)
button.TextSize = 16
button.Visible = false
button.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = button

local gallery
local galleryAdded
local galleryRemoved
local destinationChanged

local function getDestination()
	if not gallery or gallery.Parent ~= Workspace then return nil end
	local playground = gallery:FindFirstChild("TransformationPlayground")
	local slot = playground and playground:FindFirstChild("DemoSlot")
	if slot and slot:IsA("BasePart") then return slot.CFrame + Vector3.new(0, 4, -5) end
	local spawn = gallery:FindFirstChild("GallerySpawn")
	local showcase = gallery:GetAttribute("ShowcaseTeleportCFrame")
	if typeof(showcase) == "CFrame" then return showcase end
	if spawn and spawn:IsA("BasePart") then return spawn.CFrame + Vector3.new(0, 4, -5) end
	return nil
end

local function updateButton()
	button.Visible = getDestination() ~= nil
end

local function setGallery(candidate)
	if galleryAdded then galleryAdded:Disconnect(); galleryAdded = nil end
	if galleryRemoved then galleryRemoved:Disconnect(); galleryRemoved = nil end
	if destinationChanged then destinationChanged:Disconnect(); destinationChanged = nil end
	gallery = candidate
	if gallery then
		destinationChanged = gallery:GetAttributeChangedSignal("ShowcaseTeleportCFrame"):Connect(updateButton)
		galleryAdded = gallery.DescendantAdded:Connect(updateButton)
		galleryRemoved = gallery.DescendantRemoving:Connect(function()
			-- DescendantRemoving fires before removal, so check on the next step.
			task.defer(updateButton)
		end)
	end
	updateButton()
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "DevTreeGallery" then setGallery(child) end
end)
Workspace.ChildRemoved:Connect(function(child)
	if child == gallery then setGallery(nil) end
end)
setGallery(Workspace:FindFirstChild("DevTreeGallery"))

local teleporting = false
button.Activated:Connect(function()
	local destination = getDestination()
	local character = player.Character
	if teleporting or not destination or not character or not character:FindFirstChild("HumanoidRootPart") then return end
	teleporting = true
	button.Text = "LOADING..."
	if Workspace.StreamingEnabled then
		local ok, err = pcall(function()
			player:RequestStreamAroundAsync(destination.Position, 5)
		end)
		if not ok then
			warn("[DevGalleryTeleport] Could not stream the gallery: " .. tostring(err))
			button.Text = "DEV GALLERY"
			teleporting = false
			return
		end
	end
	-- This local-only shortcut affects only the Studio test character.
	if player.Character == character and character.Parent and getDestination() then
		character:PivotTo(destination)
	end
	button.Text = "DEV GALLERY"
	teleporting = false
end)
