-- Studio-only integration for the side-by-side boundary sample comparison.
-- The gallery extension and samples stay isolated from the production world.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local GALLERY_NAME = "DevTreeGallery"
local ROOT_NAME = "DevMesaShapeShowcase"
local BUILD_VERSION = 8
local buildingGalleries = setmetatable({}, { __mode = "k" })

-- The west extension is local X [-360, 0], Z [-180, 180]. The two runs
-- share a single Z row centered at -40 and sit side by side along X.
local EXTENSION_SIZE = Vector3.new(360, 1, 360)
local EXTENSION_CENTER_OFFSET = Vector3.new(-180, 0, 0)
local COMPARISON_ORIGIN_OFFSET = Vector3.new(-180, 0, -40)
local COMPARISON_TARGET_HEIGHT = 22
local MESA_COMPARISON_TELEPORT_OFFSET = Vector3.new(-180, 0, 165)
local WALKWAY_START_OFFSET = Vector3.new(20, 0, -78)
local WALKWAY_JUNCTION_OFFSET = Vector3.new(-20, 0, -78)
local WALKWAY_NORTH_END_OFFSET = Vector3.new(-20, 0, 165)
local WALKWAY_LANDING_OFFSET = MESA_COMPARISON_TELEPORT_OFFSET
local WALKWAY_WIDTH = 24
local WORLD_MARGIN = 2
local LANDING_MARGIN = 15

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

local function createDirectionSign(parent, galleryOrigin, floorTopY)
	local signCenter = galleryOrigin + Vector3.new(-5, floorTopY - galleryOrigin.Y + 8, -78)
	local signCFrame = CFrame.new(signCenter) * CFrame.Angles(0, math.rad(-90), 0)
	local board = createPart(
		parent,
		"BoundaryShowcaseDirectionBoard",
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
		label.Text = "← MESA BOUNDARY COMPARISON"
		label.TextColor3 = Color3.fromRGB(245, 240, 214)
		label.TextScaled = true
		label.TextStrokeTransparency = 0.45
		label.Parent = surface
	end

	-- These supports sit beyond the edge of the 24-stud approach path.
	for _, zOffset in ipairs({ -92, -64 }) do
		local post = createPart(
			parent,
			"BoundaryShowcaseDirectionPost",
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

local function validateVisualModel(model, support)
	assert(model and model:IsA("Model"), "Boundary showcase run must be a Model")
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

	local supportMinX = support.Position.X - support.Size.X * 0.5
	local supportMaxX = support.Position.X + support.Size.X * 0.5
	local supportMinZ = support.Position.Z - support.Size.Z * 0.5
	local supportMaxZ = support.Position.Z + support.Size.Z * 0.5
	assert(minX >= supportMinX + WORLD_MARGIN and maxX <= supportMaxX - WORLD_MARGIN,
		"Boundary showcase run extends beyond its support floor in X")
	assert(minZ >= supportMinZ + WORLD_MARGIN and maxZ <= supportMaxZ - WORLD_MARGIN,
		"Boundary showcase run extends beyond its support floor in Z")
	return {
		MinX = minX,
		MaxX = maxX,
		MinY = minY,
		MaxY = maxY,
		MinZ = minZ,
		MaxZ = maxZ,
	}
end

local function validateComparison(runs, support, comparisonOrigin)
	assert(runs and runs:IsA("Model") and runs.Name == "MesaBoundarySampleRuns",
		"Mesa boundary builder must return the MesaBoundarySampleRuns Model")
	assert(runs.ModelStreamingMode == Enum.ModelStreamingMode.Atomic,
		"Mesa boundary sample runs must stream as one atomic comparison")
	assert(runs:GetAttribute("BuildStatus") == "Ready",
		"Mesa boundary runs must be marked ready before exposing the teleport")
	assert(runs:GetAttribute("SampleCount") == 2,
		"Mesa boundary showcase must contain exactly two runs")
	assert(typeof(runs:GetAttribute("PairCenterX")) == "number"
		and math.abs(runs:GetAttribute("PairCenterX") - comparisonOrigin.X) <= 1,
		"Mesa boundary run pair is not centered at the requested X position")
	assert(typeof(runs:GetAttribute("PairCenterZ")) == "number"
		and math.abs(runs:GetAttribute("PairCenterZ") - comparisonOrigin.Z) <= 1,
		"Mesa boundary run pair is not centered on the requested viewing row")

	local terrainRun = runs:FindFirstChild("TerrainBoundarySample")
	local facetedRun = runs:FindFirstChild("FacetedBoundarySample")
	assert(terrainRun and terrainRun:IsA("Model"), "TerrainBoundarySample Model is required")
	assert(facetedRun and facetedRun:IsA("Model"), "FacetedBoundarySample Model is required")
	assert(terrainRun:GetAttribute("BuildStatus") == "Ready"
		and facetedRun:GetAttribute("BuildStatus") == "Ready",
		"Both mesa boundary sample models must be marked ready")
	local modelCount = 0
	for _, child in ipairs(runs:GetChildren()) do
		if child:IsA("Model") then
			modelCount += 1
		end
	end
	assert(modelCount == 2, "Mesa boundary showcase must have exactly two direct sample Models")

	local terrainBounds = validateVisualModel(terrainRun, support)
	local facetedBounds = validateVisualModel(facetedRun, support)
	assert(terrainBounds.MaxX < facetedBounds.MinX,
		"Boundary samples must sit side by side with a clear gap along X")
	local sharedRowDepth = math.min(terrainBounds.MaxZ, facetedBounds.MaxZ)
		- math.max(terrainBounds.MinZ, facetedBounds.MinZ)
	assert(sharedRowDepth >= 20,
		"Boundary samples must overlap in depth as one side-by-side viewing row")

	return {
		MinX = math.min(terrainBounds.MinX, facetedBounds.MinX),
		MaxX = math.max(terrainBounds.MaxX, facetedBounds.MaxX),
		MinZ = math.min(terrainBounds.MinZ, facetedBounds.MinZ),
		MaxZ = math.max(terrainBounds.MaxZ, facetedBounds.MaxZ),
		MaxY = math.max(terrainBounds.MaxY, facetedBounds.MaxY),
	}
end

local function createApproachSegment(parent, name, galleryOrigin, startOffset, endOffset, floorTopY)
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
		Vector3.new(WALKWAY_WIDTH, 0.12, horizontalLength),
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

local function validateLanding(support, floorTopY, galleryOrigin)
	local supportMinX = support.Position.X - support.Size.X * 0.5
	local supportMaxX = support.Position.X + support.Size.X * 0.5
	local supportMinZ = support.Position.Z - support.Size.Z * 0.5
	local supportMaxZ = support.Position.Z + support.Size.Z * 0.5
	local landing = galleryOrigin + MESA_COMPARISON_TELEPORT_OFFSET
	assert(landing.X >= supportMinX + LANDING_MARGIN and landing.X <= supportMaxX - LANDING_MARGIN,
		"Mesa comparison landing is too close to the support floor edge in X")
	assert(landing.Z >= supportMinZ + LANDING_MARGIN and landing.Z <= supportMaxZ - LANDING_MARGIN,
		"Mesa comparison landing must keep a 15-stud margin from the support floor edge in Z")
	return Vector3.new(landing.X, floorTopY + 4, landing.Z)
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
		and typeof(gallery:GetAttribute("MesaComparisonSampleCenter")) == "Vector3"
	then
		return
	end
	if buildingGalleries[gallery] then
		return
	end
	buildingGalleries[gallery] = true
	gallery:SetAttribute("MesaComparisonTeleportCFrame", nil)
	gallery:SetAttribute("MesaComparisonSampleCenter", nil)
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
		createApproachSegment(root, "BoundaryShowcaseLandingPath", galleryOrigin,
			WALKWAY_NORTH_END_OFFSET, WALKWAY_LANDING_OFFSET, floorTopY)

		local samples = Instance.new("Folder")
		samples.Name = "BoundarySamples"
		samples:SetAttribute("DevOnly", true)
		samples:SetAttribute("VisualOnly", true)
		samples.Parent = root

		local worldLayout = ServerScriptService:FindFirstChild("WorldLayout")
		local moduleScript = worldLayout and worldLayout:FindFirstChild("MesaShapeShowcase")
		assert(moduleScript and moduleScript:IsA("ModuleScript"),
			"ServerScriptService.WorldLayout.MesaShapeShowcase ModuleScript is required")
		local MesaShapeShowcase = require(moduleScript)
		assert(type(MesaShapeShowcase.Create) == "function",
			"MesaShapeShowcase module is missing its Create builder")

		local comparisonOrigin = galleryOrigin + COMPARISON_ORIGIN_OFFSET
		local runs = MesaShapeShowcase.Create(
			samples,
			Vector3.new(comparisonOrigin.X, floorTopY, comparisonOrigin.Z)
		)
		local comparisonBounds = validateComparison(runs, extensionFloor, comparisonOrigin)
		local landingPosition = validateLanding(extensionFloor, floorTopY, galleryOrigin)
		local sampleCenter = Vector3.new(
			comparisonOrigin.X,
			floorTopY + COMPARISON_TARGET_HEIGHT,
			comparisonOrigin.Z
		)
		assert(landingPosition.Z - comparisonBounds.MaxZ >= 160,
			"Mesa comparison landing must remain clear of the sample runs")
		gallery:SetAttribute("MesaComparisonSampleCenter", sampleCenter)
		local landingLookAt = Vector3.new(sampleCenter.X, landingPosition.Y, sampleCenter.Z)
		gallery:SetAttribute(
			"MesaComparisonTeleportCFrame",
			CFrame.lookAt(landingPosition, landingLookAt)
		)
	end)

	if not ok then
		if root then
			root:Destroy()
		end
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
