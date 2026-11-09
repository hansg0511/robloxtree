-- One Studio-only navigator for the dev gallery and its independently enabled labs.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local REGISTRY_NAME = "DevGalleryNavRegistry"
local ENTRIES_NAME = "Entries"
local OWNER_ATTRIBUTE = "DevGalleryOwner"
local COORDINATOR_OWNER = "Coordinator"
local REFERENCE_OWNER_ATTRIBUTE = "DevStudioReferenceGalleryOwner"
local REFERENCE_OWNER = "DevStudioReferenceGallery.server"
local RETURN_TIMEOUT = 8
local TARGET_TIMEOUT = 8
local NAV_ORDER = {
	Entry = 1,
	Tree = 2,
	TreeOverview = 3,
	Terrain = 4,
	Mesa = 5,
	MesaFaceted = 6,
	MesaMixed = 7,
	References = 8,
	ForestSofter = 9,
	ForestChunkier = 10,
	Archive = 11,
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DevGalleryNavigation"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 1000
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "NavigationPanel"
panel.AnchorPoint = Vector2.new(1, 1)
panel.Position = UDim2.new(1, -14, 1, -58)
panel.Size = UDim2.fromOffset(278, 370)
panel.BackgroundColor3 = Color3.fromRGB(27, 36, 34)
panel.BackgroundTransparency = 0.06
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(184, 194, 173)
panelStroke.Transparency = 0.68
panelStroke.Thickness = 1
panelStroke.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.fromOffset(12, 8)
title.Size = UDim2.new(1, -24, 0, 22)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "STUDIO DEV LABS"
title.TextColor3 = Color3.fromRGB(245, 242, 225)
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Instructions"
subtitle.Position = UDim2.fromOffset(12, 29)
subtitle.Size = UDim2.new(1, -24, 0, 18)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "Jump to a ready section"
subtitle.TextColor3 = Color3.fromRGB(190, 200, 184)
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = panel

local list = Instance.new("ScrollingFrame")
list.Name = "Entries"
list.Position = UDim2.fromOffset(10, 52)
list.Size = UDim2.new(1, -20, 0, 232)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ScrollBarThickness = 4
list.ScrollBarImageColor3 = Color3.fromRGB(167, 179, 158)
list.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 5)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

local returnButton = Instance.new("TextButton")
returnButton.Name = "ReturnToWorld"
returnButton.AnchorPoint = Vector2.new(1, 1)
returnButton.Position = UDim2.new(1, -174, 1, -14)
returnButton.Size = UDim2.fromOffset(154, 40)
returnButton.BackgroundColor3 = Color3.fromRGB(131, 79, 59)
returnButton.BorderSizePixel = 0
returnButton.Font = Enum.Font.GothamBold
returnButton.Text = "RETURN TO WORLD"
returnButton.TextColor3 = Color3.fromRGB(255, 246, 230)
returnButton.TextSize = 13
returnButton.Visible = false
returnButton.Parent = screenGui

local returnCorner = Instance.new("UICorner")
returnCorner.CornerRadius = UDim.new(0, 7)
returnCorner.Parent = returnButton

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleNavigation"
toggleButton.AnchorPoint = Vector2.new(1, 1)
toggleButton.Position = UDim2.new(1, -14, 1, -14)
toggleButton.Size = UDim2.fromOffset(152, 40)
toggleButton.BackgroundColor3 = Color3.fromRGB(53, 111, 74)
toggleButton.BorderSizePixel = 0
toggleButton.Font = Enum.Font.GothamBold
toggleButton.Text = "DEV GALLERY"
toggleButton.TextColor3 = Color3.fromRGB(250, 248, 232)
toggleButton.TextSize = 13
toggleButton.Visible = false
toggleButton.Parent = screenGui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 7)
toggleCorner.Parent = toggleButton

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Position = UDim2.new(0, 12, 1, -28)
status.Size = UDim2.new(1, -24, 0, 17)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.Text = ""
status.TextColor3 = Color3.fromRGB(228, 198, 141)
status.TextSize = 10
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextTruncate = Enum.TextTruncate.AtEnd
status.Parent = panel

local registry
local entriesFolder
local registryConnections = {}
local entryConnections = {}
local entryButtons = {}
local busy = false
local menuOpen = false
local worldReturnCFrame
local insideDevArea = false
local returnWorldButtonConnection

local function disconnectAll(connections)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function isFiniteNumber(value)
	return type(value) == "number" and value == value and math.abs(value) < 1000000
end

local function isValidCFrame(value)
	if typeof(value) ~= "CFrame" then
		return false
	end
	local position = value.Position
	return isFiniteNumber(position.X) and isFiniteNumber(position.Y) and isFiniteNumber(position.Z)
end

local function getGalleryOrigin()
	local gallery = Workspace:FindFirstChild("DevTreeGallery")
	local origin = gallery and gallery:GetAttribute("GalleryOrigin")
	if typeof(origin) == "Vector3" and gallery:GetAttribute(OWNER_ATTRIBUTE) == COORDINATOR_OWNER then
		return origin
	end
	local registryOrigin = registry and registry:GetAttribute("GalleryOrigin")
	if typeof(registryOrigin) == "Vector3" then
		return registryOrigin
	end
	return nil
end

local function isDevAreaPosition(position)
	local origin = getGalleryOrigin()
	if origin then
		local dx = position.X - origin.X
		local dz = position.Z - origin.Z
		if dx * dx + dz * dz <= 2200 * 2200 and math.abs(position.Y - origin.Y) <= 1600 then
			return true
		end
	end

	local referenceScene = Workspace:FindFirstChild("DevStudioReferenceGallery")
	local referenceOrigin = referenceScene and referenceScene:GetAttribute("ReferenceGalleryOrigin")
	if typeof(referenceOrigin) == "Vector3" then
		local dx = position.X - referenceOrigin.X
		local dz = position.Z - referenceOrigin.Z
		if dx * dx + dz * dz <= 500 * 500 and math.abs(position.Y - referenceOrigin.Y) <= 300 then
			return true
		end
	end
	return false
end

local function findSafeWorldReturnCFrame()
	local spawnLocation = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLocation and not isDevAreaPosition(spawnLocation.Position) then
		local candidate = spawnLocation.CFrame + Vector3.new(0, 4, 0)
		if isValidCFrame(candidate) then
			return candidate
		end
	end

	local baseGround = Workspace:FindFirstChild("BaseGround", true)
	if baseGround and baseGround:IsA("BasePart") and not isDevAreaPosition(baseGround.Position) then
		local position = baseGround.Position + Vector3.new(0, baseGround.Size.Y * 0.5 + 5, 0)
		local candidate = CFrame.new(position)
		if isValidCFrame(candidate) then
			return candidate
		end
	end
	return nil
end

local function getCharacterRoot(timeout)
	local deadline = os.clock() + (timeout or 0)
	repeat
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			return character, root
		end
		if os.clock() >= deadline then
			break
		end
		task.wait(0.1)
	until false
	return nil, nil
end

local function saveWorldReturn(characterRoot)
	if worldReturnCFrame and isValidCFrame(worldReturnCFrame) and not isDevAreaPosition(worldReturnCFrame.Position) then
		return true
	end
	worldReturnCFrame = nil

	if not isDevAreaPosition(characterRoot.Position) then
		local candidate = characterRoot.CFrame
		if isValidCFrame(candidate) and not isDevAreaPosition(candidate.Position) then
			worldReturnCFrame = candidate
			return true
		end
	end

	worldReturnCFrame = findSafeWorldReturnCFrame()
	return worldReturnCFrame ~= nil
end

local function resolveEntry(entry)
	if not entry or not entry.Parent
		or entry:GetAttribute(OWNER_ATTRIBUTE) ~= COORDINATOR_OWNER
		or entry:GetAttribute("Ready") ~= true
		or entry:GetAttribute("Enabled") ~= true
	then
		return nil
	end
	if not registry or registry:GetAttribute(OWNER_ATTRIBUTE) ~= COORDINATOR_OWNER
		or registry:GetAttribute("BuildStatus") ~= "Ready"
		or entry.Parent ~= entriesFolder
	then
		return nil
	end
	local destination = entry:GetAttribute("DestinationCFrame")
	if not isValidCFrame(destination) then
		return nil
	end

	local targetRootName = entry:GetAttribute("TargetRootName")
	local targetName = entry:GetAttribute("TargetName")
	if type(targetRootName) ~= "string" or type(targetName) ~= "string" then
		return nil
	end
	if targetRootName ~= "DevTreeGallery" and targetRootName ~= "DevStudioReferenceGallery" then
		return nil
	end
	return destination, targetRootName, targetName
end

local function resolveTarget(entry)
	local destination, targetRootName, targetName = resolveEntry(entry)
	if not destination then
		return nil
	end
	local targetRoot = Workspace:FindFirstChild(targetRootName)
	if not targetRoot or targetRoot.Parent ~= Workspace then
		return nil
	end

	if targetRootName == "DevTreeGallery" then
		if targetRoot:GetAttribute(OWNER_ATTRIBUTE) ~= COORDINATOR_OWNER
			or targetRoot:GetAttribute("DevOnly") ~= true
			or targetRoot:GetAttribute("VisualOnly") ~= true
			or targetRoot:GetAttribute("BuildStatus") ~= "Ready"
		then
			return nil
		end
	elseif targetRootName == "DevStudioReferenceGallery" then
		if targetRoot:GetAttribute(REFERENCE_OWNER_ATTRIBUTE) ~= REFERENCE_OWNER
			or targetRoot:GetAttribute("DevOnly") ~= true
			or targetRoot:GetAttribute("VisualOnly") ~= true
		then
			return nil
		end
	else
		return nil
	end

	local target = if targetName == targetRootName then targetRoot else targetRoot:FindFirstChild(targetName, true)
	if not target or (target ~= targetRoot and not target:IsDescendantOf(targetRoot)) then
		return nil
	end
	if targetName == "SofterStorybookClearing" or targetName == "ChunkierStorybookClearing" then
		if not target:IsA("Model") then
			return nil
		end
		local walkableFloor = target:FindFirstChild("WalkableGrass", true)
		if not walkableFloor or not walkableFloor:IsA("BasePart")
			or walkableFloor:GetAttribute("WalkableUtilitySurface") ~= true
			or walkableFloor.CanCollide ~= true
		then
			return nil
		end
	end
	return destination, target
end

local function waitForTarget(entry, timeout)
	local deadline = os.clock() + timeout
	repeat
		local destination, target = resolveTarget(entry)
		if destination and target then
			return destination, target
		end
		if os.clock() >= deadline then
			break
		end
		task.wait(0.1)
	until false
	return nil, nil
end

local function requestStream(position, timeout)
	if not Workspace.StreamingEnabled then
		return true
	end
	local ok, err = pcall(function()
		player:RequestStreamAroundAsync(position, timeout)
	end)
	if not ok then
		warn("[DevGalleryNavigation] Stream request failed: " .. tostring(err))
	end
	return ok
end

local function requestEntryStream(entry, destination)
	local focusPosition = entry:GetAttribute("FocusPosition")
	local focusRequested = true
	if typeof(focusPosition) == "Vector3" then
		focusRequested = requestStream(focusPosition, TARGET_TIMEOUT)
	end
	local landingRequested = requestStream(destination.Position, TARGET_TIMEOUT)
	if not focusRequested then
		return false, "Could not stream the selected view."
	end
	if not landingRequested then
		return false, "Could not stream the selected landing."
	end
	return true, nil
end

local function aimCameraAt(character, destination, entry)
	local camera = Workspace.CurrentCamera
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local focus = entry and entry:GetAttribute("FocusPosition")
	if not camera or not humanoid or typeof(focus) ~= "Vector3" then
		return
	end

	local distance = entry:GetAttribute("CameraDistance")
	local height = entry:GetAttribute("CameraHeight")
	if type(distance) ~= "number" then distance = 20 end
	if type(height) ~= "number" then height = 8 end
	local direction = focus - destination.Position
	local cameraPosition
	if direction.Magnitude > 0.01 then
		cameraPosition = destination.Position - direction.Unit * distance + Vector3.new(0, height, 0)
	else
		cameraPosition = destination.Position - destination.LookVector * distance + Vector3.new(0, height, 0)
	end
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
	task.delay(0.15, applyView)
end

local function restoreCamera(character)
	local camera = Workspace.CurrentCamera
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if camera and humanoid then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = humanoid
	end
end

local function updateButtons()
	if not entriesFolder then
		panel.Visible = false
		toggleButton.Visible = false
		local canReturn = insideDevArea
			and isValidCFrame(worldReturnCFrame)
			and not isDevAreaPosition(worldReturnCFrame.Position)
		returnButton.Visible = canReturn
		returnButton.Active = not busy
		returnButton.AutoButtonColor = not busy
		return
	end

	local visibleEntries = {}
	for _, entry in ipairs(entriesFolder:GetChildren()) do
		if entry:IsA("Folder") then
			local destination = entry:GetAttribute("DestinationCFrame")
			if registry and registry:GetAttribute(OWNER_ATTRIBUTE) == COORDINATOR_OWNER
				and registry:GetAttribute("BuildStatus") == "Ready"
				and entry:GetAttribute(OWNER_ATTRIBUTE) == COORDINATOR_OWNER
				and entry:GetAttribute("Ready") == true
				and entry:GetAttribute("Enabled") == true
				and type(entry:GetAttribute("TargetRootName")) == "string"
				and type(entry:GetAttribute("TargetName")) == "string"
				and isValidCFrame(destination)
			then
				table.insert(visibleEntries, entry)
			end
		end
	end
	table.sort(visibleEntries, function(a, b)
		local orderA = NAV_ORDER[a.Name] or 100
		local orderB = NAV_ORDER[b.Name] or 100
		if orderA == orderB then
			return a.Name < b.Name
		end
		return orderA < orderB
	end)

	local wanted = {}
	for index, entry in ipairs(visibleEntries) do
		wanted[entry.Name] = true
		local button = entryButtons[entry.Name]
		if not button then
			local selectedEntryId = entry.Name
			button = Instance.new("TextButton")
			button.Name = entry.Name .. "Button"
			button.Size = UDim2.new(1, -6, 0, 38)
			button.BackgroundColor3 = Color3.fromRGB(55, 77, 64)
			button.BorderSizePixel = 0
			button.Font = Enum.Font.GothamBold
			button.TextColor3 = Color3.fromRGB(246, 244, 229)
			button.TextSize = 12
			button.TextWrapped = true
			button.LayoutOrder = NAV_ORDER[entry.Name] or 100
			button.Parent = list
			entryButtons[entry.Name] = button
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = button
			button.Activated:Connect(function()
				local selectedEntry = entriesFolder and entriesFolder:FindFirstChild(selectedEntryId)
				if busy or not selectedEntry then return end
				task.spawn(function()
					-- Destination metadata is persistent; the target scene may not be
					-- replicated until after RequestStreamAroundAsync completes.
					local initialDestination = resolveEntry(selectedEntry)
					if not initialDestination then
						status.Text = "This section is no longer ready."
						return
					end
					local _, currentRoot = getCharacterRoot(2)
					if not currentRoot then
						status.Text = "Waiting for your character..."
						return
					end
					if not saveWorldReturn(currentRoot) then
						status.Text = "No safe return point is available yet."
						return
					end

					busy = true
					status.Text = "Loading " .. tostring(selectedEntry:GetAttribute("Label")) .. "..."
					local streamed, streamMessage = requestEntryStream(selectedEntry, initialDestination)
					if not streamed then
						busy = false
						status.Text = streamMessage or "Could not stream the selected section."
						updateButtons()
						return
					end
					local destination, target = waitForTarget(selectedEntry, TARGET_TIMEOUT)
					if not destination or not target then
						busy = false
						status.Text = "The selected section did not finish streaming."
						updateButtons()
						return
					end
					local character, characterRoot = getCharacterRoot(4)
					if not character or not characterRoot then
						busy = false
						status.Text = "Your character is not ready. Try again."
						updateButtons()
						return
					end
					local latestDestination, latestTarget = resolveTarget(selectedEntry)
					if not latestDestination or not latestTarget then
						busy = false
						status.Text = "This section changed while it was loading."
						updateButtons()
						return
					end

					character:PivotTo(latestDestination)
					insideDevArea = true
					menuOpen = false
					task.wait()
					aimCameraAt(character, latestDestination, selectedEntry)
					busy = false
					status.Text = ""
					updateButtons()
				end)
			end)
		end
		button.LayoutOrder = NAV_ORDER[entry.Name] or (100 + index)
		local label = tostring(entry:GetAttribute("Label") or entry.Name)
		local summary = entry:GetAttribute("Summary")
		button.Text = if type(summary) == "string" and summary ~= ""
			then label .. "\n" .. summary
			else label
		button.Active = not busy
		button.AutoButtonColor = not busy
		button.BackgroundTransparency = if busy then 0.22 else 0
	end
	for entryId, button in pairs(entryButtons) do
		if not wanted[entryId] then
			button:Destroy()
			entryButtons[entryId] = nil
		end
	end

	local canReturn = insideDevArea
		and isValidCFrame(worldReturnCFrame)
		and not isDevAreaPosition(worldReturnCFrame.Position)
	returnButton.Visible = canReturn
	returnButton.Active = not busy
	returnButton.AutoButtonColor = not busy
	if #visibleEntries == 0 then
		menuOpen = false
	end
	toggleButton.Visible = #visibleEntries > 0
	toggleButton.Text = if menuOpen then "CLOSE DEV GALLERY" else "DEV GALLERY"
	toggleButton.Active = not busy
	toggleButton.AutoButtonColor = not busy
	panel.Visible = #visibleEntries > 0 and menuOpen
end

local function returnToWorld()
	if busy or not insideDevArea then return end
	local destination = worldReturnCFrame
	if not isValidCFrame(destination) or isDevAreaPosition(destination.Position) then
		destination = findSafeWorldReturnCFrame()
	end
	if not isValidCFrame(destination) or isDevAreaPosition(destination.Position) then
		status.Text = "No safe world return point is available."
		return
	end

	busy = true
	status.Text = "Returning to the world..."
	requestStream(destination.Position, RETURN_TIMEOUT)
	local character, characterRoot = getCharacterRoot(4)
	if not character or not characterRoot then
		busy = false
		status.Text = "Your character is not ready. Try again."
		updateButtons()
		return
	end
	character:PivotTo(destination)
	insideDevArea = false
	worldReturnCFrame = nil
	task.wait()
	restoreCamera(character)
	busy = false
	status.Text = ""
	updateButtons()
end

returnWorldButtonConnection = returnButton.Activated:Connect(returnToWorld)

toggleButton.Activated:Connect(function()
	if busy then return end
	menuOpen = not menuOpen
	updateButtons()
end)

local function watchEntriesFolder(folder)
	disconnectAll(entryConnections)
	entriesFolder = folder
	if not entriesFolder then
		menuOpen = false
	end
	if entriesFolder then
		table.insert(entryConnections, entriesFolder.ChildAdded:Connect(function(child)
			if child:IsA("Folder") then
				table.insert(entryConnections, child.AttributeChanged:Connect(updateButtons))
			end
			updateButtons()
		end))
		table.insert(entryConnections, entriesFolder.ChildRemoved:Connect(updateButtons))
		for _, child in ipairs(entriesFolder:GetChildren()) do
			if child:IsA("Folder") then
				table.insert(entryConnections, child.AttributeChanged:Connect(updateButtons))
			end
		end
	end
	updateButtons()
end

local function setRegistry(candidate)
	disconnectAll(registryConnections)
	registry = if candidate and candidate:GetAttribute(OWNER_ATTRIBUTE) == COORDINATOR_OWNER then candidate else nil
	if registry then
		table.insert(registryConnections, registry:GetAttributeChangedSignal("BuildStatus"):Connect(updateButtons))
		table.insert(registryConnections, registry.ChildAdded:Connect(function(child)
			if child.Name == ENTRIES_NAME and child:IsA("Folder") then
				watchEntriesFolder(child)
			end
		end))
		table.insert(registryConnections, registry.ChildRemoved:Connect(function(child)
			if child == entriesFolder then
				watchEntriesFolder(nil)
			end
		end))
		local folder = registry:FindFirstChild(ENTRIES_NAME)
		watchEntriesFolder(folder)
	else
		watchEntriesFolder(nil)
	end
	updateButtons()
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == REGISTRY_NAME then
		setRegistry(child)
	end
end)
Workspace.ChildRemoved:Connect(function(child)
	if child == registry then
		setRegistry(nil)
	end
end)
setRegistry(Workspace:FindFirstChild(REGISTRY_NAME))

player.CharacterAdded:Connect(function()
	-- The saved world CFrame intentionally survives respawns until Return is used.
	task.defer(updateButtons)
end)
