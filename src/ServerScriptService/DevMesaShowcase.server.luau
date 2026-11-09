-- Studio-only gallery extension for three long boundary samples.
-- Every new platform, sign, walkway, and sample stays west of the existing gallery.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local configFolder = ServerScriptService:FindFirstChild("DevGallery")
local configModule = configFolder and configFolder:FindFirstChild("Config")
local configOk, loadedConfig = false, nil
if configModule and configModule:IsA("ModuleScript") then
	configOk, loadedConfig = pcall(require, configModule)
end
local galleryConfig = if configOk and type(loadedConfig) == "table" then loadedConfig else nil
if not galleryConfig then
	warn("[DevMesaShowcase] ServerScriptService.DevGallery.Config is unavailable; the terrain lab is disabled.")
end
local LAB_ENABLED = galleryConfig ~= nil
	and galleryConfig.Enabled == true
	and type(galleryConfig.Labs) == "table"
	and galleryConfig.Labs.Terrain == true

local GALLERY_NAME = "DevTreeGallery"
local ROOT_NAME = "DevMesaShapeShowcase"
local BUILD_VERSION = 11
local OWNER_ATTRIBUTE = "DevMesaShowcaseOwner"
local OWNER_VALUE = "DevMesaShowcase.server"
local buildingGalleries = setmetatable({}, { __mode = "k" })

-- The original gallery begins at local X=0. This west-only extension gives
-- each 200+ stud run a clean side-view station with no neighboring run in front.
local EXTENSION_SIZE = Vector3.new(960, 1, 360)
local EXTENSION_CENTER_OFFSET = Vector3.new(-480, 0, 0)
local COMPARISON_ORIGIN_OFFSET = Vector3.new(-460, 0, -40)
local COMPARISON_TELEPORT_OFFSET = Vector3.new(-20, 0, 150)
local CAMERA_STANDOFF = 180
-- Keep this aligned with DevMesaComparisonTeleport.client.luau.
local CAMERA_REAR_OFFSET = 12
local WALKWAY_START_OFFSET = Vector3.new(20, 0, -78)
local WALKWAY_JUNCTION_OFFSET = Vector3.new(-20, 0, -78)
local WALKWAY_NORTH_END_OFFSET = Vector3.new(-20, 0, 150)
local WALKWAY_SPINE_END_OFFSET = Vector3.new(-880, 0, 150)
local VIEWER_AISLE_Z = 150
local VIEWER_AISLE_END_Z = -40
local WALKWAY_WIDTH = 18
local VIEWER_WALKWAY_WIDTH = 12
local WORLD_MARGIN = 2
local LANDING_MARGIN = 15
local MIN_SAMPLE_LENGTH = 200
local MIN_LANE_GAP = 100
-- The multi-depth mixed cluster stays within the existing lane width.
local MAX_SAMPLE_HALF_WIDTH = 45
local MAX_SAMPLE_HALF_DEPTH = 130

local SAMPLE_DEFINITIONS = {
	{
		Name = "TerrainBoundarySample",
		Label = "TERRAIN BOUNDARY",
		MinimumDepthStagger = 18,
		TeleportAttribute = "MesaTerrainBoundaryTeleportCFrame",
		CenterAttribute = "MesaTerrainBoundarySampleCenter",
	},
	{
		Name = "FacetedBoundarySample",
		Label = "FACETED BOUNDARY",
		MinimumDepthStagger = 22,
		TeleportAttribute = "MesaFacetedBoundaryTeleportCFrame",
		CenterAttribute = "MesaFacetedBoundarySampleCenter",
	},
	{
		Name = "MixedBoundarySample",
		Label = "MIXED BOUNDARY",
		MinimumDepthStagger = 26,
		TeleportAttribute = "MesaMixedBoundaryTeleportCFrame",
		CenterAttribute = "MesaMixedBoundarySampleCenter",
	},
}

local TELEPORT_ATTRIBUTE_NAMES = {
	"MesaComparisonTeleportCFrame",
	"MesaComparisonSampleCenter",
	"MesaTerrainBoundaryTeleportCFrame",
	"MesaTerrainBoundarySampleCenter",
	"MesaFacetedBoundaryTeleportCFrame",
	"MesaFacetedBoundarySampleCenter",
	"MesaMixedBoundaryTeleportCFrame",
	"MesaMixedBoundarySampleCenter",
}

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

local function markVisual(part)
	part:SetAttribute("DevOnly", true)
	part:SetAttribute("VisualOnly", true)
	part:SetAttribute("WorldDecoration", "BoundaryShowcase")
	return part
end

local function createSurfaceLabel(board, name, face, text)
	local surface = Instance.new("SurfaceGui")
	surface.Name = name
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
	label.Text = text
	label.TextColor3 = Color3.fromRGB(245, 240, 214)
	label.TextScaled = true
	label.TextWrapped = true
	label.TextStrokeTransparency = 0.45
	label.Parent = surface
	return label
end

local function createDirectionSign(parent, galleryOrigin, floorTopY)
	local signCenter = galleryOrigin + Vector3.new(-5, floorTopY - galleryOrigin.Y + 8, -78)
	local board = markVisual(createPart(
		parent,
		"BoundaryShowcaseDirectionBoard",
		Vector3.new(30, 4.5, 0.6),
		CFrame.new(signCenter) * CFrame.Angles(0, math.rad(-90), 0),
		Color3.fromRGB(47, 66, 54),
		Enum.Material.WoodPlanks,
		false,
		false
	))
	createSurfaceLabel(board, "DirectionFront", Enum.NormalId.Front, "← MESA BOUNDARY COMPARISON")
	createSurfaceLabel(board, "DirectionBack", Enum.NormalId.Back, "← MESA BOUNDARY COMPARISON")

	for _, zOffset in ipairs({ -92, -64 }) do
		markVisual(createPart(
			parent,
			"BoundaryShowcaseDirectionPost",
			Vector3.new(0.7, 8, 0.7),
			CFrame.new(galleryOrigin.X - 5, floorTopY + 4, galleryOrigin.Z + zOffset),
			Color3.fromRGB(91, 69, 45),
			Enum.Material.Wood,
			false,
			false
		))
	end
end

local function createSampleStationSign(parent, galleryOrigin, floorTopY, definition, viewerX)
	local boardWidth = 58
	local boardCenter = Vector3.new(
		viewerX,
		floorTopY + 7,
		galleryOrigin.Z + VIEWER_AISLE_Z - 11
	)
	local board = markVisual(createPart(
		parent,
		definition.Name .. "StationBoard",
		Vector3.new(boardWidth, 5, 0.7),
		CFrame.new(boardCenter),
		Color3.fromRGB(47, 66, 54),
		Enum.Material.WoodPlanks,
		false,
		false
	))
	createSurfaceLabel(board, "StationLabelFront", Enum.NormalId.Front, definition.Label .. "\nSIDE VIEW")
	createSurfaceLabel(board, "StationLabelBack", Enum.NormalId.Back, definition.Label .. "\nSIDE VIEW")

	for _, side in ipairs({ -1, 1 }) do
		markVisual(createPart(
			parent,
			definition.Name .. "StationPost",
			Vector3.new(0.8, 7, 0.8),
			CFrame.new(viewerX + side * (boardWidth * 0.5 - 1), floorTopY + 3.5, boardCenter.Z),
			Color3.fromRGB(91, 69, 45),
			Enum.Material.Wood,
			false,
			false
		))
	end
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
	return position.X - halfX, position.X + halfX, position.Y - halfY, position.Y + halfY,
		position.Z - halfZ, position.Z + halfZ
end

local function validateVisualModel(model, support, definition)
	assert(model and model:IsA("Model"), "Boundary showcase run must be a Model")
	local primaryPart = model.PrimaryPart
	assert(primaryPart and primaryPart:IsA("BasePart"),
		model.Name .. " must expose its run origin as PrimaryPart")
	local visibleLength = model:GetAttribute("VisibleLengthZ")
	local contourMinZ = model:GetAttribute("VisibleContourMinZ")
	local contourMaxZ = model:GetAttribute("VisibleContourMaxZ")
	local depthStaggerRange = model:GetAttribute("DepthStaggerRangeX")
	assert(type(visibleLength) == "number" and type(contourMinZ) == "number"
		and type(contourMaxZ) == "number" and math.abs((contourMaxZ - contourMinZ) - visibleLength) <= 0.05,
		model.Name .. " must provide its measured contour length")
	assert(visibleLength >= MIN_SAMPLE_LENGTH,
		model.Name .. " must be at least 200 studs long along its visible contour")
	assert(type(depthStaggerRange) == "number"
		and depthStaggerRange >= definition.MinimumDepthStagger,
		model.Name .. " must meet its planned depth-stagger profile")
	local minX, maxX, minY, maxY, minZ, maxZ
	local hasReadableLabel = false
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			assert(descendant.Anchored, "Boundary showcase parts must be anchored")
			assert(not descendant.CanCollide, "Boundary showcase parts must not collide")
			assert(not descendant.CanTouch, "Boundary showcase parts must not touch")
			assert(not descendant.CanQuery, "Boundary showcase parts must not be queryable")
			local partMinX, partMaxX, partMinY, partMaxY, partMinZ, partMaxZ = getPartBounds(descendant)
			minX = minX and math.min(minX, partMinX) or partMinX
			maxX = maxX and math.max(maxX, partMaxX) or partMaxX
			minY = minY and math.min(minY, partMinY) or partMinY
			maxY = maxY and math.max(maxY, partMaxY) or partMaxY
			minZ = minZ and math.min(minZ, partMinZ) or partMinZ
			maxZ = maxZ and math.max(maxZ, partMaxZ) or partMaxZ
		elseif descendant:IsA("TextLabel") and descendant.Text:gsub("%s", "") ~= "" then
			hasReadableLabel = true
		end
	end
	assert(minX and minZ, "Boundary showcase run has no BaseParts")
	assert(hasReadableLabel, "Each boundary showcase run must have a readable label")
	assert(maxX - minX <= MAX_SAMPLE_HALF_WIDTH * 2,
		model.Name .. " exceeds the planned side-to-side footprint")
	assert(maxZ - minZ <= MAX_SAMPLE_HALF_DEPTH * 2,
		model.Name .. " exceeds the planned long-axis bound")

	local supportMinX = support.Position.X - support.Size.X * 0.5
	local supportMaxX = support.Position.X + support.Size.X * 0.5
	local supportMinZ = support.Position.Z - support.Size.Z * 0.5
	local supportMaxZ = support.Position.Z + support.Size.Z * 0.5
	assert(minX >= supportMinX + WORLD_MARGIN and maxX <= supportMaxX - WORLD_MARGIN,
		model.Name .. " extends beyond the support floor in X")
	assert(minZ >= supportMinZ + WORLD_MARGIN and maxZ <= supportMaxZ - WORLD_MARGIN,
		model.Name .. " extends beyond the support floor in Z")
	return {
		MinX = minX,
		MaxX = maxX,
		MinY = minY,
		MaxY = maxY,
		MinZ = minZ,
		MaxZ = maxZ,
		CenterX = primaryPart.Position.X,
		CenterZ = primaryPart.Position.Z + (contourMinZ + contourMaxZ) * 0.5,
		VisibleMinZ = primaryPart.Position.Z + contourMinZ,
		VisibleMaxZ = primaryPart.Position.Z + contourMaxZ,
		Length = visibleLength,
		DepthStaggerRange = depthStaggerRange,
	}
end

local function validateComparison(runs, support, comparisonOrigin)
	assert(runs and runs:IsA("Model") and runs.Name == "MesaBoundarySampleRuns",
		"Mesa boundary builder must return the MesaBoundarySampleRuns Model")
	assert(runs.ModelStreamingMode ~= Enum.ModelStreamingMode.Atomic,
		"Mesa boundary container must allow its individual lanes to stream independently")
	assert(runs:GetAttribute("BuildStatus") == "Ready",
		"Mesa boundary runs must be marked ready before exposing teleport options")
	assert(runs:GetAttribute("SampleCount") == #SAMPLE_DEFINITIONS,
		"Mesa boundary showcase must contain exactly three runs")
	assert(typeof(runs:GetAttribute("PairCenterX")) == "number"
		and math.abs(runs:GetAttribute("PairCenterX") - comparisonOrigin.X) <= 1,
		"Mesa boundary run row is not centered at the requested X position")
	assert(typeof(runs:GetAttribute("PairCenterZ")) == "number"
		and math.abs(runs:GetAttribute("PairCenterZ") - comparisonOrigin.Z) <= 1,
		"Mesa boundary run row is not centered at the requested Z position")

	local modelCount = 0
	for _, child in ipairs(runs:GetChildren()) do
		if child:IsA("Model") then
			modelCount += 1
		end
	end
	assert(modelCount == #SAMPLE_DEFINITIONS,
		"Mesa boundary showcase must have exactly three direct sample Models")

	local samples = table.create(#SAMPLE_DEFINITIONS)
	for index, definition in ipairs(SAMPLE_DEFINITIONS) do
		local run = runs:FindFirstChild(definition.Name)
		assert(run and run:IsA("Model"), definition.Name .. " Model is required")
		assert(run.ModelStreamingMode == Enum.ModelStreamingMode.Atomic,
			definition.Name .. " must stream as a complete lane")
		assert(run:GetAttribute("BuildStatus") == "Ready",
			definition.Name .. " must be marked ready before exposing its teleport")
		local bounds = validateVisualModel(run, support, definition)
		local expectedCenterX = comparisonOrigin.X + (index - 2) * 240
		assert(math.abs(bounds.CenterX - expectedCenterX) <= 14,
			definition.Name .. " is outside its assigned side-view lane")
		samples[index] = {
			Definition = definition,
			Model = run,
			Bounds = bounds,
		}
	end
	assert(samples[1].Bounds.DepthStaggerRange < samples[2].Bounds.DepthStaggerRange
		and samples[2].Bounds.DepthStaggerRange < samples[3].Bounds.DepthStaggerRange,
		"Terrain, Faceted, and Mixed samples must have progressively deeper profiles")

	for index = 2, #samples do
		local gap = samples[index].Bounds.MinX - samples[index - 1].Bounds.MaxX
		assert(gap >= MIN_LANE_GAP,
			"Boundary sample lanes need at least 100 studs of clear sightline spacing")
	end

	return samples
end

local function createApproachSegment(parent, name, galleryOrigin, startOffset, endOffset, floorTopY, width)
	local startPosition = galleryOrigin + startOffset
	local endPosition = galleryOrigin + endOffset
	local delta = endPosition - startPosition
	local horizontalLength = Vector3.new(delta.X, 0, delta.Z).Magnitude
	assert(horizontalLength > 0, "Boundary approach segment must have nonzero length")
	local center = Vector3.new(
		(startPosition.X + endPosition.X) * 0.5,
		floorTopY + 0.06,
		(startPosition.Z + endPosition.Z) * 0.5
	)
	local path = createPart(
		parent,
		name,
		Vector3.new(width or WALKWAY_WIDTH, 0.12, horizontalLength),
		CFrame.lookAt(center, Vector3.new(endPosition.X, center.Y, endPosition.Z)),
		Color3.fromRGB(151, 139, 112),
		Enum.Material.Slate,
		false,
		false
	)
	path:SetAttribute("DevOnly", true)
	path:SetAttribute("VisualOnly", true)
	path:SetAttribute("WorldDecoration", "BoundaryShowcaseWalkway")
	return path
end

local function validateLanding(support, floorTopY, galleryOrigin, offset)
	local supportMinX = support.Position.X - support.Size.X * 0.5
	local supportMaxX = support.Position.X + support.Size.X * 0.5
	local supportMinZ = support.Position.Z - support.Size.Z * 0.5
	local supportMaxZ = support.Position.Z + support.Size.Z * 0.5
	local landing = galleryOrigin + offset
	assert(landing.X >= supportMinX + LANDING_MARGIN and landing.X <= supportMaxX - LANDING_MARGIN,
		"Boundary comparison landing is too close to the support floor edge in X")
	assert(landing.Z >= supportMinZ + LANDING_MARGIN and landing.Z <= supportMaxZ - LANDING_MARGIN,
		"Boundary comparison landing is too close to the support floor edge in Z")
	return Vector3.new(landing.X, floorTopY + 4, landing.Z)
end

local function clearTeleportAttributes(gallery)
	for _, attributeName in ipairs(TELEPORT_ATTRIBUTE_NAMES) do
		gallery:SetAttribute(attributeName, nil)
	end
end

local function isOwnedShowcaseRoot(root)
	return root and root:IsA("Folder")
		and root:GetAttribute(OWNER_ATTRIBUTE) == OWNER_VALUE
end

local function isLegacyShowcaseRoot(root)
	return root and root:IsA("Folder")
		and root:GetAttribute("DevOnly") == true
		and root:GetAttribute("VisualOnly") == true
		and root:FindFirstChild("MesaShowcaseSupport") ~= nil
		and root:FindFirstChild("BoundarySamples") ~= nil
end

local function isShowcaseRoot(root, gallery)
	return isOwnedShowcaseRoot(root)
		or (gallery and gallery:GetAttribute("DevGalleryOwner") == "Coordinator"
			and isLegacyShowcaseRoot(root))
end

local function clearPublishedState(gallery)
	clearTeleportAttributes(gallery)
	gallery:SetAttribute("MesaShapeShowcaseVersion", nil)
end

local function cleanupGallery(gallery)
	if not gallery or gallery.Name ~= GALLERY_NAME or not gallery:IsA("Model")
		or gallery:GetAttribute("DevGalleryOwner") ~= "Coordinator"
	then
		return
	end
	local existingRoot = gallery:FindFirstChild(ROOT_NAME)
	if existingRoot and not isShowcaseRoot(existingRoot, gallery) then
		warn(("[DevMesaShowcase] %s is already used by another instance; leaving it untouched.")
			:format(ROOT_NAME))
		return
	end
	if existingRoot then
		existingRoot:Destroy()
	end
	clearPublishedState(gallery)
end

if not LAB_ENABLED then
	cleanupGallery(Workspace:FindFirstChild(GALLERY_NAME))
	-- The coordinator may parent its shell after this script starts. This
	-- one-shot cleanup listener does not wait for the shell or start a build.
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == GALLERY_NAME then
			task.defer(cleanupGallery, child)
		end
	end)
	return
end

local function buildOnGallery(gallery)
	if not gallery or gallery.Parent ~= Workspace or gallery.Name ~= GALLERY_NAME
		or not gallery:IsA("Model")
		or gallery:GetAttribute("DevGalleryOwner") ~= "Coordinator"
	then
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
	if typeof(galleryConfig.Origin) ~= "Vector3"
		or (galleryOrigin - galleryConfig.Origin).Magnitude > 0.01
	then
		return
	end
	local existingRoot = gallery:FindFirstChild(ROOT_NAME)
	if isShowcaseRoot(existingRoot, gallery) and gallery:GetAttribute("MesaShapeShowcaseVersion") == BUILD_VERSION then
		local hasAllTeleports = true
		for _, attributeName in ipairs(TELEPORT_ATTRIBUTE_NAMES) do
			if gallery:GetAttribute(attributeName) == nil then
				hasAllTeleports = false
				break
			end
		end
		if hasAllTeleports then
			return
		end
	end
	if existingRoot and not isShowcaseRoot(existingRoot, gallery) then
		warn(("[DevMesaShowcase] %s is already used by another instance; leaving it untouched.")
			:format(ROOT_NAME))
		return
	end
	if buildingGalleries[gallery] then
		return
	end
	buildingGalleries[gallery] = true
	clearPublishedState(gallery)
	if existingRoot then
		existingRoot:Destroy()
	end

	local floorTopY = existingFloor.Position.Y + existingFloor.Size.Y * 0.5
	local root
	local ok, err = pcall(function()
		root = Instance.new("Folder")
		root.Name = ROOT_NAME
		root:SetAttribute(OWNER_ATTRIBUTE, OWNER_VALUE)
		root:SetAttribute("DevOnly", true)
		root:SetAttribute("VisualOnly", true)
		root:SetAttribute("BuildStatus", "StudioPrototype")
		root.Parent = gallery

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
		createDirectionSign(root, galleryOrigin, floorTopY)

		createApproachSegment(root, "BoundaryShowcaseApproach", galleryOrigin,
			WALKWAY_START_OFFSET, WALKWAY_JUNCTION_OFFSET, floorTopY)
		createApproachSegment(root, "BoundaryShowcaseNorthAisle", galleryOrigin,
			WALKWAY_JUNCTION_OFFSET, WALKWAY_NORTH_END_OFFSET, floorTopY)
		createApproachSegment(root, "BoundaryShowcaseSampleCrosswalk", galleryOrigin,
			WALKWAY_NORTH_END_OFFSET, WALKWAY_SPINE_END_OFFSET, floorTopY, WALKWAY_WIDTH)

		local samplesFolder = Instance.new("Folder")
		samplesFolder.Name = "BoundarySamples"
		samplesFolder:SetAttribute("DevOnly", true)
		samplesFolder:SetAttribute("VisualOnly", true)
		samplesFolder.Parent = root

		local worldLayout = ServerScriptService:FindFirstChild("WorldLayout")
		local moduleScript = worldLayout and worldLayout:FindFirstChild("MesaShapeShowcase")
		assert(moduleScript and moduleScript:IsA("ModuleScript"),
			"ServerScriptService.WorldLayout.MesaShapeShowcase ModuleScript is required")
		local MesaShapeShowcase = require(moduleScript)
		assert(type(MesaShapeShowcase.Create) == "function",
			"MesaShapeShowcase module is missing its Create builder")

		local comparisonOrigin = galleryOrigin + COMPARISON_ORIGIN_OFFSET
		local runs = MesaShapeShowcase.Create(
			samplesFolder,
			Vector3.new(comparisonOrigin.X, floorTopY, comparisonOrigin.Z)
		)
		local samples = validateComparison(runs, extensionFloor, comparisonOrigin)
		local overviewPosition = validateLanding(
			extensionFloor,
			floorTopY,
			galleryOrigin,
			COMPARISON_TELEPORT_OFFSET
		)
		-- The overview is a central hub on the crosswalk. It stays responsive
		-- without requiring any of the separately streamed sample lanes.
		local overviewCenter = Vector3.new(
			galleryOrigin.X - 300,
			floorTopY + 6,
			galleryOrigin.Z + VIEWER_AISLE_Z
		)
		gallery:SetAttribute("MesaComparisonSampleCenter", overviewCenter)
		gallery:SetAttribute(
			"MesaComparisonTeleportCFrame",
			CFrame.lookAt(overviewPosition, overviewCenter)
		)

		for index, sample in ipairs(samples) do
			local definition = sample.Definition
			local bounds = sample.Bounds
			local center = Vector3.new(
				bounds.CenterX,
				(bounds.MinY + bounds.MaxY) * 0.5,
				bounds.CenterZ
			)
			local viewerX = center.X - CAMERA_STANDOFF
			local viewOffset = Vector3.new(viewerX - galleryOrigin.X, 0, center.Z - galleryOrigin.Z)
			local viewerPosition = validateLanding(extensionFloor, floorTopY, galleryOrigin, viewOffset)
			-- The client pulls its camera behind the landing, so keep it over the support floor.
			validateLanding(extensionFloor, floorTopY, galleryOrigin,
				viewOffset - Vector3.new(CAMERA_REAR_OFFSET, 0, 0))
			local cameraMinX = math.min(viewerPosition.X, center.X) - CAMERA_REAR_OFFSET
			local cameraMaxX = math.max(viewerPosition.X, center.X)
			local walkwayMinX = viewerPosition.X - VIEWER_WALKWAY_WIDTH * 0.5
			local walkwayMaxX = viewerPosition.X + VIEWER_WALKWAY_WIDTH * 0.5
			for otherIndex, otherSample in ipairs(samples) do
				if otherIndex ~= index then
					local other = otherSample.Bounds
					local sightlineOverlaps = other.MaxX >= cameraMinX - WORLD_MARGIN
						and other.MinX <= cameraMaxX + WORLD_MARGIN
					local walkwayOverlaps = other.MaxX >= walkwayMinX - WORLD_MARGIN
						and other.MinX <= walkwayMaxX + WORLD_MARGIN
					assert(not sightlineOverlaps,
						definition.Name .. " camera sightline crosses another sample lane")
					assert(not walkwayOverlaps,
						definition.Name .. " side-view walkway crosses another sample lane")
				end
			end

			createApproachSegment(
				root,
				definition.Name .. "SideViewPath",
				galleryOrigin,
				Vector3.new(viewerX - galleryOrigin.X, 0, VIEWER_AISLE_Z),
				Vector3.new(viewerX - galleryOrigin.X, 0, VIEWER_AISLE_END_Z),
				floorTopY,
				VIEWER_WALKWAY_WIDTH
			)
			createSampleStationSign(root, galleryOrigin, floorTopY, definition, viewerX)

			gallery:SetAttribute(definition.CenterAttribute, center)
			gallery:SetAttribute(
				definition.TeleportAttribute,
				CFrame.lookAt(viewerPosition, center)
			)
		end
	end)

	if not ok then
		if root then
			root:Destroy()
		end
		clearPublishedState(gallery)
		buildingGalleries[gallery] = nil
		warn("[DevMesaShowcase] Could not build the Studio boundary comparison: " .. tostring(err))
		return
	end

	gallery:SetAttribute("MesaShapeShowcaseVersion", BUILD_VERSION)
	buildingGalleries[gallery] = nil
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == GALLERY_NAME then
		task.defer(buildOnGallery, child)
	end
end)

local currentGallery = Workspace:FindFirstChild(GALLERY_NAME)
if currentGallery then
	task.defer(buildOnGallery, currentGallery)
end
