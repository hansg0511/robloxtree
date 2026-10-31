-- Studio-only integration for the isolated cliff-shape comparison area.
-- This stays outside WorldLayoutService so the live World1 boundaries remain unchanged.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local GALLERY_NAME = "DevTreeGallery"
local ROOT_NAME = "DevMesaShapeShowcase"
local BUILD_VERSION = 4
local buildingGalleries = setmetatable({}, { __mode = "k" })

-- Gallery-relative footprint. The extension's east edge meets the existing
-- GalleryFloor at X=0; its Z span overlaps that floor so the walking surface
-- stays continuous while the samples remain wholly west of existing rows.
local EXTENSION_SIZE = Vector3.new(360, 1, 240)
local EXTENSION_CENTER_OFFSET = Vector3.new(-180, 0, 0)
local COMPARISON_ORIGIN_OFFSET = Vector3.new(-180, 0, -40)
local REFINED_PAIR_ORIGIN_OFFSET = Vector3.new(-275, 0, 3)
local CLUSTER_ORIGIN_OFFSET = Vector3.new(-180, 0, 70)
local WALKWAY_START_OFFSET = Vector3.new(20, 0, -78)
local WALKWAY_END_OFFSET = Vector3.new(-68, 0, -78)
local WORLD_MARGIN = 2

-- This inspection landing point is separate from the existing harvest showcase teleport.
local MESA_COMPARISON_TELEPORT_OFFSET = Vector3.new(-280, 0, 55)
-- Keep the source clones near the clean/refined pair while clear of its footprint
-- and the teleport landing point. Both remain on the isolated extension floor.
local REFERENCE_CLIFF_OFFSET = Vector3.new(-335, 0, -55)
local REFERENCE_BORDER_OFFSET = Vector3.new(-298, 0, -55)

local function createPart(parent, name, size, cframe, color, material, canCollide, canQuery)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = canCollide == true
	part.CanTouch = false
	part.CanQuery = canQuery == true
	part.CastShadow = false
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createSpawnSign(parent, galleryOrigin, floorTopY)
	local signCenter = galleryOrigin + Vector3.new(-5, floorTopY - galleryOrigin.Y + 8, -78)
	local signCFrame = CFrame.new(signCenter) * CFrame.Angles(0, math.rad(-90), 0)
	local board = createPart(
		parent,
		"CliffShowcaseDirectionBoard",
		Vector3.new(30, 4.5, 0.6),
		signCFrame,
		Color3.fromRGB(47, 66, 54),
		Enum.Material.WoodPlanks,
		false,
		false
	)
	board:SetAttribute("DevOnly", true)
	board:SetAttribute("VisualOnly", true)

	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local surface = Instance.new("SurfaceGui")
		surface.Name = "Direction" .. face.Name
		surface.Face = face
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 32
		surface.LightInfluence = 0
		surface.Parent = board

		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.Text = "← CLIFF SHAPE SHOWCASE"
		label.TextColor3 = Color3.fromRGB(245, 240, 214)
		label.TextScaled = true
		label.TextStrokeTransparency = 0.45
		label.Parent = surface
	end

	-- These two visual supports sit outside the 24-stud path and do not collide.
	for _, zOffset in ipairs({ -92, -64 }) do
		local post = createPart(
			parent,
			"CliffShowcaseDirectionPost",
			Vector3.new(0.7, 8, 0.7),
			CFrame.new(galleryOrigin.X - 5, floorTopY + 4, galleryOrigin.Z + zOffset),
			Color3.fromRGB(91, 69, 45),
			Enum.Material.Wood,
			false,
			false
		)
		post:SetAttribute("DevOnly", true)
		post:SetAttribute("VisualOnly", true)
	end
end

local function createPath(parent, galleryOrigin, floorTopY)
	local startPosition = galleryOrigin + WALKWAY_START_OFFSET
	local endPosition = galleryOrigin + WALKWAY_END_OFFSET
	local delta = endPosition - startPosition
	local horizontalLength = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local center = Vector3.new(
		(startPosition.X + endPosition.X) * 0.5,
		floorTopY + 0.06,
		(startPosition.Z + endPosition.Z) * 0.5
	)
	local path = createPart(
		parent,
		"CliffShowcaseWalkway",
		Vector3.new(24, 0.12, horizontalLength),
		CFrame.lookAt(center, Vector3.new(endPosition.X, center.Y, endPosition.Z)),
		Color3.fromRGB(151, 139, 112),
		Enum.Material.Slate,
		false,
		false
	)
	path:SetAttribute("DevOnly", true)
	path:SetAttribute("VisualOnly", true)
	path:SetAttribute("WorldDecoration", "CliffShowcaseWalkway")
	return path
end

local function getPartBounds(part)
	local half = part.Size * 0.5
	local right = part.CFrame.RightVector
	local up = part.CFrame.UpVector
	local look = part.CFrame.LookVector
	local halfX = math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(look.X) * half.Z
	local halfY = math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(look.Y) * half.Z
	local halfZ = math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(look.Z) * half.Z
	local position = part.Position
	return position.X - halfX, position.X + halfX, position.Y - halfY, position.Y + halfY, position.Z - halfZ, position.Z + halfZ
end

local function validateVisualModel(model, support)
	assert(model and model:IsA("Model"), "Mesa showcase builder did not return a Model")
	local minX, maxX, minZ, maxZ
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			assert(descendant.Anchored, "Mesa showcase parts must be anchored")
			assert(not descendant.CanCollide, "Mesa showcase parts must not collide")
			assert(not descendant.CanTouch, "Mesa showcase parts must not touch")
			assert(not descendant.CanQuery, "Mesa showcase parts must not be queryable")
			local partMinX, partMaxX, _, _, partMinZ, partMaxZ = getPartBounds(descendant)
			minX = minX and math.min(minX, partMinX) or partMinX
			maxX = maxX and math.max(maxX, partMaxX) or partMaxX
			minZ = minZ and math.min(minZ, partMinZ) or partMinZ
			maxZ = maxZ and math.max(maxZ, partMaxZ) or partMaxZ
		end
	end
	assert(minX and minZ, "Mesa showcase Model has no BaseParts")
	local supportMinX = support.Position.X - support.Size.X * 0.5
	local supportMaxX = support.Position.X + support.Size.X * 0.5
	local supportMinZ = support.Position.Z - support.Size.Z * 0.5
	local supportMaxZ = support.Position.Z + support.Size.Z * 0.5
	assert(minX >= supportMinX + WORLD_MARGIN and maxX <= supportMaxX - WORLD_MARGIN,
		"Mesa showcase extends beyond its support floor in X")
	assert(minZ >= supportMinZ + WORLD_MARGIN and maxZ <= supportMaxZ - WORLD_MARGIN,
		"Mesa showcase extends beyond its support floor in Z")
end

local function findReferenceTerrainFolder()
	for _, child in ipairs(Workspace:GetChildren()) do
		if child.Name == "Terrain" and child:IsA("Folder") then
			return child
		end
	end
	return nil
end

local function findReferenceCliff(terrainFolder)
	if not terrainFolder then
		return nil, 0
	end
	local firstCliff
	local cliffCount = 0
	for _, descendant in ipairs(terrainFolder:GetDescendants()) do
		if descendant:IsA("UnionOperation") and descendant.Name == "Cliff" then
			cliffCount += 1
			firstCliff = firstCliff or descendant
		end
	end
	return firstCliff, cliffCount
end

local function findReferenceBorder()
	for _, child in ipairs(Workspace:GetChildren()) do
		if child.Name == "Border" and child:IsA("Model") then
			return child
		end
	end
	return nil
end

local function makeCloneVisualOnly(instance)
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("Script")
			or descendant:IsA("LocalScript")
			or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		end
	end

	local function configurePart(part)
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part:SetAttribute("DevOnly", true)
		part:SetAttribute("VisualOnly", true)
		part:SetAttribute("ReferenceOnly", true)
	end

	if instance:IsA("BasePart") then
		configurePart(instance)
	end
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			configurePart(descendant)
		end
	end
end

local function cloneReferenceAsset(source, cloneName)
	if not source then
		return nil
	end
	local ok, cloneOrError = pcall(function()
		return source:Clone()
	end)
	if not ok or not cloneOrError then
		warn(string.format("[DevMesaShowcase] Could not clone reference %s: %s", cloneName, tostring(cloneOrError)))
		return nil
	end

	local clone = cloneOrError
	clone.Name = cloneName
	clone:SetAttribute("DevOnly", true)
	clone:SetAttribute("VisualOnly", true)
	clone:SetAttribute("ReferenceOnly", true)
	clone:SetAttribute("ReferenceSource", source:GetFullName())
	makeCloneVisualOnly(clone)
	return clone
end

local function createReferenceLabel(parent, name, position, text, width)
	local anchor = createPart(
		parent,
		name .. "Anchor",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(position),
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		false,
		false
	)
	anchor.Transparency = 1
	anchor.CastShadow = false
	anchor:SetAttribute("DevOnly", true)
	anchor:SetAttribute("VisualOnly", true)
	anchor:SetAttribute("ReferenceOnly", true)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = name
	billboard.Adornee = anchor
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 350
	billboard.Size = UDim2.fromOffset(width or 260, 62)
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(31, 42, 42)
	label.BackgroundTransparency = 0.12
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = Color3.fromRGB(239, 242, 224)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = billboard

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 9)
	padding.PaddingRight = UDim.new(0, 9)
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingBottom = UDim.new(0, 5)
	padding.Parent = label
	return anchor
end

local function countMeshParts(model)
	local count = 0
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("MeshPart") then
			count += 1
		end
	end
	return count
end

local function getVerticalHalfExtent(part)
	local half = part.Size * 0.5
	local right = part.CFrame.RightVector
	local up = part.CFrame.UpVector
	local look = part.CFrame.LookVector
	return math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(look.Y) * half.Z
end

local function createReferenceStudy(parent, galleryOrigin, floorTopY)
	local terrainFolder = findReferenceTerrainFolder()
	local cliffSource, cliffCount = findReferenceCliff(terrainFolder)
	local borderSource = findReferenceBorder()
	if not cliffSource and not borderSource then
		warn("[DevMesaShowcase] Reference study skipped: no Terrain Folder Cliff union or Workspace.Border Model was found")
		return nil
	end

	local study = Instance.new("Model")
	study.Name = "MesaReferenceStudy"
	study.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	study:SetAttribute("DevOnly", true)
	study:SetAttribute("VisualOnly", true)
	study:SetAttribute("ReferenceOnly", true)
	study:SetAttribute("ReferenceSourceCliffCount", cliffCount)

	local hasClone = false
	if cliffSource then
		local cliffClone = cloneReferenceAsset(cliffSource, "SourceCliffUnionClone")
		if cliffClone and cliffClone:IsA("UnionOperation") then
			local target = galleryOrigin + REFERENCE_CLIFF_OFFSET
			local halfHeight = getVerticalHalfExtent(cliffClone)
			local rotation = cliffClone.CFrame.Rotation
			cliffClone.CFrame = CFrame.new(target.X, floorTopY + halfHeight, target.Z) * rotation
			cliffClone.Parent = study
			createReferenceLabel(
				study,
				"SourceCliffLabel",
				Vector3.new(target.X, floorTopY + halfHeight * 2 + 3.1, target.Z),
				string.format("REFERENCE CLONE — CLIFF\n1 of %d Terrain Folder unions", cliffCount),
				285
			)
			hasClone = true
		else
			if cliffClone then cliffClone:Destroy() end
			warn("[DevMesaShowcase] Reference Cliff sample skipped: the clone was not a UnionOperation")
		end
	else
		warn("[DevMesaShowcase] Reference Cliff sample skipped: Workspace Terrain Folder Cliff union was not found")
	end

	if borderSource then
		local borderClone = cloneReferenceAsset(borderSource, "SourceBorderModelClone")
		if borderClone and borderClone:IsA("Model") then
			local meshPartCount = countMeshParts(borderClone)
			if meshPartCount > 0 then
				local target = galleryOrigin + REFERENCE_BORDER_OFFSET
				local boxCFrame, boxSize = borderClone:GetBoundingBox()
				local currentPivot = borderClone:GetPivot()
				local targetBoxCenter = Vector3.new(target.X, floorTopY + boxSize.Y * 0.5, target.Z)
				local pivotPosition = currentPivot.Position + (targetBoxCenter - boxCFrame.Position)
				borderClone:PivotTo(CFrame.new(pivotPosition) * currentPivot.Rotation)
				borderClone.Parent = study
				createReferenceLabel(
					study,
					"SourceBorderLabel",
					Vector3.new(target.X, floorTopY + boxSize.Y + 3.1, target.Z),
					string.format("REFERENCE CLONE — BORDER\n%d-part MeshPart model", meshPartCount),
					260
				)
				hasClone = true
			else
				borderClone:Destroy()
				warn("[DevMesaShowcase] Border reference skipped: the cloned model has no MeshParts")
			end
		elseif borderClone then
			borderClone:Destroy()
			warn("[DevMesaShowcase] Border reference skipped: the clone was not a Model")
		end
	else
		warn("[DevMesaShowcase] Border reference skipped: Workspace.Border Model was not found")
	end

	if not hasClone then
		study:Destroy()
		return nil
	end

	study.Parent = parent
	return study
end

local function buildOnGallery(gallery)
	if not gallery or gallery.Parent ~= Workspace or gallery.Name ~= GALLERY_NAME then
		return
	end
	if gallery:GetAttribute("DevOnly") ~= true or gallery:GetAttribute("VisualOnly") ~= true then
		return
	end
	local galleryOrigin = gallery:GetAttribute("GalleryOrigin")
	local existingFloor = gallery:FindFirstChild("GalleryFloor")
	if typeof(galleryOrigin) ~= "Vector3" or not existingFloor or not existingFloor:IsA("BasePart") then
		return
	end
	local existingRoot = gallery:FindFirstChild(ROOT_NAME)
	if existingRoot
		and gallery:GetAttribute("MesaShapeShowcaseVersion") == BUILD_VERSION
		and typeof(gallery:GetAttribute("MesaComparisonTeleportCFrame")) == "CFrame"
	then
		return
	end
	if buildingGalleries[gallery] then
		return
	end
	buildingGalleries[gallery] = true
	gallery:SetAttribute("MesaComparisonTeleportCFrame", nil)
	if existingRoot then
		existingRoot:Destroy()
	end

	local floorTopY = existingFloor.Position.Y + existingFloor.Size.Y * 0.5
	local root
	local ok, err = pcall(function()
		root = Instance.new("Folder")
		root.Name = ROOT_NAME
		root:SetAttribute("DevOnly", true)
		root:SetAttribute("VisualOnly", true)
		root:SetAttribute("BuildStatus", "StudioPrototype")
		root.Parent = gallery

		local worldLayout = ServerScriptService:FindFirstChild("WorldLayout")
		local moduleScript = worldLayout and worldLayout:FindFirstChild("MesaShapeShowcase")
		assert(moduleScript and moduleScript:IsA("ModuleScript"),
			"ServerScriptService.WorldLayout.MesaShapeShowcase ModuleScript is required")
		local MesaShapeShowcase = require(moduleScript)
		assert(type(MesaShapeShowcase.Create) == "function"
			and type(MesaShapeShowcase.CreateRefinedPair) == "function"
			and type(MesaShapeShowcase.CreateClusteredSegment) == "function",
			"MesaShapeShowcase module is missing a required builder")

		local extensionCenter = galleryOrigin + EXTENSION_CENTER_OFFSET
		local extensionFloor = createPart(
			root,
			"MesaShowcaseSupport",
			EXTENSION_SIZE,
			CFrame.new(extensionCenter.X, floorTopY - EXTENSION_SIZE.Y * 0.5, extensionCenter.Z),
			Color3.fromRGB(54, 78, 62),
			Enum.Material.SmoothPlastic,
			true,
			true
		)
		extensionFloor.Transparency = 0.12
		extensionFloor:SetAttribute("DevOnly", true)
		extensionFloor:SetAttribute("WalkableUtilitySurface", true)
		createPath(root, galleryOrigin, floorTopY)
		createSpawnSign(root, galleryOrigin, floorTopY)

		local samples = Instance.new("Folder")
		samples.Name = "CliffSamples"
		samples:SetAttribute("DevOnly", true)
		samples:SetAttribute("VisualOnly", true)
		samples.Parent = root

		local comparisonOrigin = galleryOrigin + COMPARISON_ORIGIN_OFFSET
		local comparison = MesaShapeShowcase.Create(samples, Vector3.new(comparisonOrigin.X, floorTopY, comparisonOrigin.Z))
		validateVisualModel(comparison, extensionFloor)

		local refinedPairOrigin = galleryOrigin + REFINED_PAIR_ORIGIN_OFFSET
		local refinedPair = MesaShapeShowcase.CreateRefinedPair(
			samples,
			Vector3.new(refinedPairOrigin.X, floorTopY, refinedPairOrigin.Z)
		)
		validateVisualModel(refinedPair, extensionFloor)

		local clusterOrigin = galleryOrigin + CLUSTER_ORIGIN_OFFSET
		local cluster = MesaShapeShowcase.CreateClusteredSegment(
			samples,
			Vector3.new(clusterOrigin.X, floorTopY, clusterOrigin.Z)
		)
		validateVisualModel(cluster, extensionFloor)

		local referenceBuildOk, referenceStudy = pcall(createReferenceStudy, samples, galleryOrigin, floorTopY)
		if not referenceBuildOk then
			warn("[DevMesaShowcase] Reference study skipped after clone error: " .. tostring(referenceStudy))
			referenceStudy = nil
		end
		if referenceStudy then
			local referenceValid, validationError = pcall(validateVisualModel, referenceStudy, extensionFloor)
			if not referenceValid then
				referenceStudy:Destroy()
				warn("[DevMesaShowcase] Reference study skipped after bounds validation: " .. tostring(validationError))
			end
		end
	end)

	if not ok then
		if root then
			root:Destroy()
		end
		buildingGalleries[gallery] = nil
		warn("[DevMesaShowcase] Could not build the Studio gallery extension: " .. tostring(err))
		return
	end

	local teleportPosition = galleryOrigin + MESA_COMPARISON_TELEPORT_OFFSET
	local comparisonCenter = galleryOrigin + REFINED_PAIR_ORIGIN_OFFSET
	gallery:SetAttribute(
		"MesaComparisonTeleportCFrame",
		CFrame.lookAt(
			Vector3.new(teleportPosition.X, floorTopY + 4, teleportPosition.Z),
			Vector3.new(comparisonCenter.X, floorTopY + 4, comparisonCenter.Z)
		)
	)
	gallery:SetAttribute("MesaShapeShowcaseVersion", BUILD_VERSION)
	buildingGalleries[gallery] = nil
end

-- Listen before checking the current Workspace so both startup orders work.
-- When DevTreeGallery is disabled, this remains quiet and creates nothing.
Workspace.ChildAdded:Connect(function(child)
	if child.Name == GALLERY_NAME then
		task.defer(buildOnGallery, child)
	end
end)

local currentGallery = Workspace:FindFirstChild(GALLERY_NAME)
if currentGallery then
	task.defer(buildOnGallery, currentGallery)
end
