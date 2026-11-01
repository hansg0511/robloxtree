-- Separate Studio-only shortcut for the isolated reference island.
-- Install under StarterPlayerScripts; it does not alter DEV GALLERY controls.

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local NAV_MODEL_NAME = "DevStudioReferenceTeleport"
local SCENE_NAME = "DevStudioReferenceGallery"

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "DevStudioReferenceTeleport"
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = playerGui

local button = Instance.new("TextButton")
button.Name = "GoToReferenceAssets"
button.AnchorPoint = Vector2.new(1, 1)
-- The existing mesa comparison panel occupies right offsets [-256, -14].
-- This button sits 10 pixels to its left and does not edit either existing GUI.
button.Position = UDim2.new(1, -266, 1, -16)
button.Size = UDim2.fromOffset(174, 42)
button.BackgroundColor3 = Color3.fromRGB(88, 105, 132)
button.BorderSizePixel = 0
button.Font = Enum.Font.GothamBold
button.Text = "REFERENCE ASSETS"
button.TextColor3 = Color3.new(1, 1, 1)
button.TextSize = 13
button.Visible = false
button.ZIndex = 10
button.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = button

local navModel
local destinationChanged
local teleporting = false

local function getDestination()
	if not navModel or navModel.Parent ~= Workspace then
		return nil
	end
	local destination = navModel:GetAttribute("ReferenceTeleportCFrame")
	if typeof(destination) == "CFrame" then
		return destination
	end
	return nil
end

local function aimCameraAtIsland(character, destination)
	local camera = Workspace.CurrentCamera
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local focus = navModel and navModel:GetAttribute("ReferenceFocusPosition")
	if not camera or not humanoid then
		return
	end
	if typeof(focus) ~= "Vector3" then
		focus = destination.Position + destination.LookVector * 80
	end

	local cameraPosition = destination.Position - destination.LookVector * 20 + Vector3.new(0, 8, 0)
	local cameraCFrame = CFrame.lookAt(cameraPosition, focus)
	local function applyView()
		if Workspace.CurrentCamera ~= camera or player.Character ~= character then
			return
		end
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = humanoid
		camera.CFrame = cameraCFrame
		camera.Focus = CFrame.new(focus)
	end

	applyView()
	task.delay(0.12, applyView)
end

local function updateButton()
	button.Visible = getDestination() ~= nil
end

local function setNavModel(candidate)
	if destinationChanged then
		destinationChanged:Disconnect()
		destinationChanged = nil
	end
	navModel = candidate
	if navModel then
		destinationChanged = navModel:GetAttributeChangedSignal("ReferenceTeleportCFrame"):Connect(updateButton)
	end
	updateButton()
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == NAV_MODEL_NAME then
		setNavModel(child)
	end
end)
Workspace.ChildRemoved:Connect(function(child)
	if child == navModel then
		setNavModel(nil)
	end
end)
setNavModel(Workspace:FindFirstChild(NAV_MODEL_NAME))

local function restoreButton()
	button.Text = "REFERENCE ASSETS"
	teleporting = false
	updateButton()
end

button.Activated:Connect(function()
	local destination = getDestination()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if teleporting or not destination or not character or not root then
		return
	end

	teleporting = true
	button.Text = "LOADING..."
	if Workspace.StreamingEnabled then
		local ok, err = pcall(function()
			player:RequestStreamAroundAsync(destination.Position, 8)
		end)
		if not ok then
			warn("[DevStudioReferenceTeleport] Could not stream the reference island: " .. tostring(err))
			restoreButton()
			return
		end

		local deadline = os.clock() + 8
		while os.clock() < deadline and not Workspace:FindFirstChild(SCENE_NAME) do
			task.wait(0.1)
		end
	end

	if not Workspace:FindFirstChild(SCENE_NAME) then
		warn("[DevStudioReferenceTeleport] The reference island is no longer available.")
		restoreButton()
		return
	end

	-- Like DEV GALLERY, this shortcut moves only the local Studio test character.
	local latestDestination = getDestination()
	if latestDestination and player.Character == character and character.Parent and root.Parent == character then
		character:PivotTo(latestDestination)
		aimCameraAtIsland(character, latestDestination)
	end
	restoreButton()
end)
