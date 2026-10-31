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
local BUILD_VERSION = 2
local buildingGalleries = setmetatable({}, { __mode = "k" })

-- Gallery-relative footprint. The extension's east edge meets the existing
-- GalleryFloor at X=0; its Z span overlaps that floor so the walking surface
-- stays continuous while the samples remain wholly west of existing rows.
local EXTENSION_SIZE = Vector3.new(360, 1, 240)
local EXTENSION_CENTER_OFFSET = Vector3.new(-180, 0, 0)
local COMPARISON_ORIGIN_OFFSET = Vector3.new(-180, 0, -40)
local REFINED_PAIR_ORIGIN_OFFSET = Vector3.new(-180, 0, 3)
local CLUSTER_ORIGIN_OFFSET = Vector3.new(-180, 0, 70)
local WALKWAY_START_OFFSET = Vector3.new(20, 0, -78)
local WALKWAY_END_OFFSET = Vector3.new(-68, 0, -78)
local WORLD_MARGIN = 2

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
	if existingRoot and gallery:GetAttribute("MesaShapeShowcaseVersion") == BUILD_VERSION then
		return
	end
	if buildingGalleries[gallery] then
		return
	end
	buildingGalleries[gallery] = true
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
	end)

	if not ok then
		if root then
			root:Destroy()
		end
		buildingGalleries[gallery] = nil
		warn("[DevMesaShowcase] Could not build the Studio gallery extension: " .. tostring(err))
		return
	end

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
