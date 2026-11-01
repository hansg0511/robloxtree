-- Studio-only, isolated display for the source-owned reference models.
-- Install under ServerScriptService. This script only clones from
-- ServerStorage.DevAssetReferences; it never edits the stored originals.

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local GATE_NAME = "DevTreeGallery"
local SOURCE_FOLDER_NAME = "DevAssetReferences"
local SCENE_NAME = "DevStudioReferenceGallery"
local NAV_MODEL_NAME = "DevStudioReferenceTeleport"
local OWNER_ATTRIBUTE = "DevStudioReferenceGalleryOwner"
local OWNER_VALUE = "DevStudioReferenceGallery.server"

-- Place the island west of the existing tree and mesa rows, but within the
-- same isolated Studio gallery region. TerrainReference is about 260 studs
-- wide, leaving several hundred studs between it and the mesa support floor.
local REFERENCE_OFFSET = Vector3.new(-1450, 0, 0)
local ASSET_GAP = 20
local SIDE_MARGIN = 24
local FRONT_BACK_MARGIN = 42

local activeGate
local activeScene
local activeNav
local reconcileScheduled = false

local function isOwned(instance)
	return instance and instance:GetAttribute(OWNER_ATTRIBUTE) == OWNER_VALUE
end

local function getGateGallery()
	local gallery = Workspace:FindFirstChild(GATE_NAME)
	if not gallery or not gallery:IsA("Model") then
		return nil
	end
	if gallery:GetAttribute("DevOnly") ~= true or gallery:GetAttribute("VisualOnly") ~= true then
		return nil
	end
	if typeof(gallery:GetAttribute("GalleryOrigin")) ~= "Vector3" then
		return nil
	end
	return gallery
end

local function getPartBounds(root)
	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)
	local foundPart = false

	local function includePart(part)
		foundPart = true
		local halfSize = part.Size * 0.5
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local corner = part.CFrame:PointToWorldSpace(Vector3.new(
						halfSize.X * sx,
						halfSize.Y * sy,
						halfSize.Z * sz
					))
					minimum = Vector3.new(
						math.min(minimum.X, corner.X),
						math.min(minimum.Y, corner.Y),
						math.min(minimum.Z, corner.Z)
					)
					maximum = Vector3.new(
						math.max(maximum.X, corner.X),
						math.max(maximum.Y, corner.Y),
						math.max(maximum.Z, corner.Z)
					)
				end
			end
		end
	end

	if root:IsA("BasePart") then
		includePart(root)
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") then
			includePart(descendant)
		end
	end

	if not foundPart then
		return nil
	end
	return minimum, maximum
end

local function sanitizeClone(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("LuaSourceContainer")
			or descendant:IsA("Camera")
			or descendant:IsA("ClickDetector")
			or descendant:IsA("ProximityPrompt")
			or descendant:IsA("Sound")
		then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
end

local function cloneDisplay(templateFolder, assetName)
	local template = templateFolder:FindFirstChild(assetName)
	if not template then
		warn(("[DevStudioReferenceGallery] Missing ServerStorage.%s.%s; skipping this display.")
			:format(SOURCE_FOLDER_NAME, assetName))
		return nil
	end
	if not template:IsA("Folder") and not template:IsA("Model") then
		warn(("[DevStudioReferenceGallery] %s must be a Folder or Model; skipping this display.")
			:format(assetName))
		return nil
	end

	local cloneOk, cloned = pcall(function()
		return template:Clone()
	end)
	if not cloneOk or not cloned then
		warn(("[DevStudioReferenceGallery] Could not clone %s: %s")
			:format(assetName, tostring(cloned)))
		return nil
	end

	local display = Instance.new("Model")
	display.Name = assetName .. "Display"
	display:SetAttribute("DevOnly", true)
	display:SetAttribute("VisualOnly", true)
	display:SetAttribute("ReferenceAssetName", assetName)
	cloned.Parent = display
	sanitizeClone(display)

	local minimum, maximum = getPartBounds(display)
	if not minimum then
		warn(("[DevStudioReferenceGallery] %s has no displayable BaseParts; skipping it."):format(assetName))
		display:Destroy()
		return nil
	end

	local baseplateTopY
	local baseplate = display:FindFirstChild("Baseplate", true)
	if baseplate and baseplate:IsA("BasePart") then
		local _, baseplateMaximum = getPartBounds(baseplate)
		baseplateTopY = baseplateMaximum.Y
	end

	return {
		Name = assetName,
		Model = display,
		Minimum = minimum,
		Maximum = maximum,
		Size = maximum - minimum,
		BaseplateTopY = baseplateTopY,
	}
end

local function createPart(parent, name, size, cframe, color, material, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = canCollide == true
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function addLabelBoard(parent, name, text, position, target, width)
	local board = createPart(
		parent,
		name,
		Vector3.new(width, 6, 0.6),
		CFrame.lookAt(position, target),
		Color3.fromRGB(29, 43, 37),
		Enum.Material.SmoothPlastic,
		false
	)
	board.CastShadow = true

	local surface = Instance.new("SurfaceGui")
	surface.Name = "Label"
	surface.Face = Enum.NormalId.Front
	surface.AlwaysOnTop = true
	surface.LightInfluence = 0
	surface.CanvasSize = Vector2.new(960, 240)
	surface.Parent = board

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = Color3.fromRGB(247, 244, 229)
	label.TextScaled = true
	label.TextWrapped = true
	label.TextStrokeTransparency = 0.75
	label.Parent = surface
	return board
end

local function moveDisplayTo(display, bounds, centerX, centerZ, sourceY, targetY)
	local sourceCenterX = (bounds.Minimum.X + bounds.Maximum.X) * 0.5
	local sourceCenterZ = (bounds.Minimum.Z + bounds.Maximum.Z) * 0.5
	local translation = Vector3.new(
		centerX - sourceCenterX,
		targetY - sourceY,
		centerZ - sourceCenterZ
	)
	display:PivotTo(CFrame.new(translation) * display:GetPivot())
end

local function setStreamingMode(model, mode)
	local ok, err = pcall(function()
		model.ModelStreamingMode = mode
	end)
	if not ok then
		warn("[DevStudioReferenceGallery] Could not set model streaming mode: " .. tostring(err))
	end
end

local function buildScene(galleryOrigin)
	local referenceOrigin = galleryOrigin + REFERENCE_OFFSET
	local templateFolder = ServerStorage:FindFirstChild(SOURCE_FOLDER_NAME)
	if not templateFolder or not templateFolder:IsA("Folder") then
		warn(("[DevStudioReferenceGallery] ServerStorage.%s is unavailable; no reference island was built.")
			:format(SOURCE_FOLDER_NAME))
		return nil
	end

	local terrain = cloneDisplay(templateFolder, "TerrainReference")
	local border = cloneDisplay(templateFolder, "BorderReference")
	if not terrain and not border then
		warn("[DevStudioReferenceGallery] No reference models were available; no reference island was built.")
		return nil
	end

	local borderStageSize
	if border then
		borderStageSize = Vector3.new(
			math.max(border.Size.X + 6, 18),
			1,
			math.max(border.Size.Z + 6, 20)
		)
	end

	local terrainCenterX = referenceOrigin.X
	local borderCenterX = referenceOrigin.X
	local terrainCenterZ = referenceOrigin.Z
	local borderCenterZ = referenceOrigin.Z
	if terrain and border then
		terrainCenterX = referenceOrigin.X - (ASSET_GAP + border.Size.X) * 0.5
		borderCenterX = referenceOrigin.X + (terrain.Size.X + ASSET_GAP) * 0.5
		-- Put the small Border study at the front edge, beside the arrival
		-- point, rather than making it a long walk across the Terrain footprint.
		borderCenterZ = referenceOrigin.Z - terrain.Size.Z * 0.5 - borderStageSize.Z * 0.5 - ASSET_GAP
	elseif terrain then
		terrainCenterX = referenceOrigin.X
	else
		borderCenterX = referenceOrigin.X
	end

	local layoutMinX = math.huge
	local layoutMaxX = -math.huge
	local layoutMinZ = math.huge
	local layoutMaxZ = -math.huge
	local function includeFootprint(centerX, centerZ, sizeX, sizeZ)
		layoutMinX = math.min(layoutMinX, centerX - sizeX * 0.5)
		layoutMaxX = math.max(layoutMaxX, centerX + sizeX * 0.5)
		layoutMinZ = math.min(layoutMinZ, centerZ - sizeZ * 0.5)
		layoutMaxZ = math.max(layoutMaxZ, centerZ + sizeZ * 0.5)
	end

	if terrain then
		includeFootprint(terrainCenterX, terrainCenterZ, terrain.Size.X, terrain.Size.Z)
	end
	if border then
		includeFootprint(borderCenterX, borderCenterZ, borderStageSize.X, borderStageSize.Z)
	end

	local floorMinimumX = layoutMinX - SIDE_MARGIN
	local floorMaximumX = layoutMaxX + SIDE_MARGIN
	local floorMinimumZ = layoutMinZ - FRONT_BACK_MARGIN
	local floorMaximumZ = layoutMaxZ + FRONT_BACK_MARGIN
	local floorCenterX = (floorMinimumX + floorMaximumX) * 0.5
	local floorCenterZ = (floorMinimumZ + floorMaximumZ) * 0.5
	local floorTopY = referenceOrigin.Y
	local focus = Vector3.new(floorCenterX, floorTopY + 6, referenceOrigin.Z)

	local scene = Instance.new("Model")
	scene.Name = SCENE_NAME
	scene:SetAttribute(OWNER_ATTRIBUTE, OWNER_VALUE)
	scene:SetAttribute("DevOnly", true)
	scene:SetAttribute("VisualOnly", true)
	scene:SetAttribute("ReferenceGalleryOrigin", referenceOrigin)
	setStreamingMode(scene, Enum.ModelStreamingMode.Atomic)

	local floor = createPart(
		scene,
		"ReferenceGalleryFloor",
		Vector3.new(floorMaximumX - floorMinimumX, 1, floorMaximumZ - floorMinimumZ),
		CFrame.new(floorCenterX, floorTopY - 0.5, floorCenterZ),
		Color3.fromRGB(54, 78, 62),
		Enum.Material.SmoothPlastic,
		true
	)
	-- The floor remains collidable under the whole island but invisible. This
	-- lets the imported Terrain Baseplate stay visible at its own top plane,
	-- even where lower cliff pieces extend below it.
	floor.Transparency = 1
	floor:SetAttribute("DevOnly", true)
	floor:SetAttribute("WalkableUtilitySurface", true)

	if terrain then
		local sourceAlignmentY = terrain.BaseplateTopY or terrain.Minimum.Y
		if not terrain.BaseplateTopY then
			warn("[DevStudioReferenceGallery] TerrainReference has no Baseplate; aligning its lowest point instead.")
		end
		moveDisplayTo(
			terrain.Model,
			terrain,
			terrainCenterX,
			terrainCenterZ,
			sourceAlignmentY,
			floorTopY + 0.04
		)
		terrain.Model.Parent = scene
		addLabelBoard(
			scene,
			"TerrainReferenceLabel",
			"TERRAIN REFERENCE\nWhole composition · original scale",
			Vector3.new(terrainCenterX, floorTopY + 7, terrainCenterZ - terrain.Size.Z * 0.5 - 7),
			Vector3.new(terrainCenterX, floorTopY + 7, terrainCenterZ),
			36
		)
	end

	if border then
		local stageTopY = floorTopY + borderStageSize.Y
		createPart(
			scene,
			"BorderReferenceStage",
			borderStageSize,
			CFrame.new(borderCenterX, floorTopY + borderStageSize.Y * 0.5, borderCenterZ),
			Color3.fromRGB(92, 105, 96),
			Enum.Material.Slate,
			true
		)
		moveDisplayTo(
			border.Model,
			border,
			borderCenterX,
			borderCenterZ,
			border.Minimum.Y,
			stageTopY + 0.04
		)
		border.Model.Parent = scene
		addLabelBoard(
			scene,
			"BorderReferenceLabel",
			"BORDER REFERENCE\n4 mesh parts · original scale",
			Vector3.new(borderCenterX, floorTopY + 7, borderCenterZ - borderStageSize.Z * 0.5 - 7),
			Vector3.new(borderCenterX, floorTopY + 7, borderCenterZ),
			24
		)
	end

	addLabelBoard(
		scene,
		"ReferenceGalleryWelcome",
		"REFERENCE ASSETS · STUDIO ONLY",
		Vector3.new(floorCenterX, floorTopY + 8, floorMinimumZ + 4),
		focus,
		math.clamp(floorMaximumX - floorMinimumX - 12, 36, 64)
	)

	local spawnX = border and borderCenterX or terrainCenterX
	local spawnPosition = Vector3.new(spawnX, floorTopY + 4, floorMinimumZ + 20)
	local teleportCFrame = CFrame.lookAt(spawnPosition, focus)

	local nav = Instance.new("Model")
	nav.Name = NAV_MODEL_NAME
	nav:SetAttribute(OWNER_ATTRIBUTE, OWNER_VALUE)
	nav:SetAttribute("DevOnly", true)
	nav:SetAttribute("ReferenceTeleportCFrame", teleportCFrame)
	nav:SetAttribute("ReferenceFocusPosition", focus)
	setStreamingMode(nav, Enum.ModelStreamingMode.Persistent)
	local marker = createPart(
		nav,
		"ReferenceTeleportMarker",
		Vector3.new(1, 1, 1),
		teleportCFrame,
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		false
	)
	marker.Transparency = 1

	return scene, nav
end

local function destroyOwnedScene()
	if isOwned(activeNav) then
		activeNav:Destroy()
	end
	if isOwned(activeScene) then
		activeScene:Destroy()
	end
	activeNav = nil
	activeScene = nil
	activeGate = nil
end

local function removeStaleOwnedInstance(name)
	local existing = Workspace:FindFirstChild(name)
	if existing and isOwned(existing) then
		existing:Destroy()
		return true
	end
	if existing then
		warn(("[DevStudioReferenceGallery] %s is already used by another instance; leaving it untouched.")
			:format(name))
		return false
	end
	return true
end

local function reconcile()
	local gate = getGateGallery()
	if not gate then
		destroyOwnedScene()
		return
	end
	if activeGate == gate
		and activeScene and activeScene.Parent == Workspace
		and activeNav and activeNav.Parent == Workspace
	then
		return
	end

	destroyOwnedScene()
	if not removeStaleOwnedInstance(SCENE_NAME) or not removeStaleOwnedInstance(NAV_MODEL_NAME) then
		return
	end

	local ok, sceneOrError, nav = pcall(buildScene, gate:GetAttribute("GalleryOrigin"))
	if not ok then
		warn("[DevStudioReferenceGallery] Build failed: " .. tostring(sceneOrError))
		if sceneOrError and typeof(sceneOrError) == "Instance" then
			sceneOrError:Destroy()
		end
		return
	end
	if not sceneOrError or not nav then
		return
	end

	activeGate = gate
	activeScene = sceneOrError
	activeNav = nav
	activeScene.Parent = Workspace
	activeNav.Parent = Workspace
	print("[DevStudioReferenceGallery] Built at " .. tostring(activeScene:GetAttribute("ReferenceGalleryOrigin")))
end

local function scheduleReconcile()
	if reconcileScheduled then
		return
	end
	reconcileScheduled = true
	task.defer(function()
		reconcileScheduled = false
		reconcile()
	end)
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == GATE_NAME then
		scheduleReconcile()
	end
end)
Workspace.ChildRemoved:Connect(function(child)
	if child.Name == GATE_NAME then
		scheduleReconcile()
	end
end)

scheduleReconcile()
