-- Studio-only visual gallery for comparing tree builders and Grove metadata.
-- Enable manually for an inspection session, then sync/restart the server.
local ENABLED = false

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local TreeObject = require(ServerScriptService:WaitForChild("Trees"):WaitForChild("TreeObject"))
local TreeVisualModifiers = require(ServerStorage:WaitForChild("TreeVisualModifiers"))
local SpeciesVisuals = require(ServerStorage:WaitForChild("SpeciesVisuals"))

local GALLERY_NAME = "DevTreeGallery"
local GALLERY_ORIGIN = Vector3.new(6000, 120, 6000)
local GALLERY_FLOOR_SIZE = Vector3.new(360, 1, 620)
local GALLERY_FLOOR_OFFSET = Vector3.new(180, -1, 210)
local MIN_PLATFORM_SIZE = 24
local PLATFORM_PADDING = 12
local COLUMN_GAP = 20
local ROW_GAP = 46

if not ENABLED then
	-- Turning the Studio tool off removes a gallery created during an earlier
	-- inspection session, while published servers never reach this code path.
	local existingGallery = Workspace:FindFirstChild(GALLERY_NAME)
	if existingGallery then existingGallery:Destroy() end
	return
end

local MUTATION_VARIANTS = {
	{ Label = "No Mutation", Mutations = {} },
	{ Label = "Golden", Mutations = { Golden = true } },
	{ Label = "Giant", Mutations = { Giant = true } },
	{ Label = "Crystal", Mutations = { Crystal = true } },
	{ Label = "Golden + Crystal", Mutations = { Golden = true, Crystal = true } },
}

local function createPart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function addSign(parent, label, position, width, name)
	local post = createPart(
		parent,
		name .. "Post",
		Vector3.new(0.8, 2.5, 0.8),
		CFrame.new(position.X, GALLERY_ORIGIN.Y + 1.25, position.Z),
		Color3.fromRGB(70, 91, 77)
	)
	post.TopSurface = Enum.SurfaceType.Smooth
	post.BottomSurface = Enum.SurfaceType.Smooth

	local board = createPart(
		parent,
		name,
		Vector3.new(width, 4, 0.7),
		CFrame.new(position.X, GALLERY_ORIGIN.Y + 4.2, position.Z),
		Color3.fromRGB(31, 53, 43)
	)
	board.TopSurface = Enum.SurfaceType.Smooth
	board.BottomSurface = Enum.SurfaceType.Smooth

	local surface = Instance.new("SurfaceGui")
	surface.Name = "LabelSurface"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 36
	surface.LightInfluence = 0
	surface.Parent = board

	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = label
	text.TextColor3 = Color3.fromRGB(239, 246, 235)
	text.TextStrokeColor3 = Color3.fromRGB(16, 27, 20)
	text.TextStrokeTransparency = 0.35
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.Parent = surface
	return board
end

local function makeContext(stage, mutations)
	return {
		GroveStage = stage,
		SizePotential = 1,
		Mutations = table.clone(mutations),
	}
end

local function buildPreview(kind, speciesId, stage, mutations, displayLabel)
	local context = makeContext(stage, mutations)
	local model = TreeObject.BuildPreviewModel(kind, context)
	assert(model and model:IsA("Model"), "Tree preview builder returned no Model for " .. kind)

	-- Reapplying is intentional and idempotent: the gallery owns the displayed
	-- metadata context even if the builder later gains a separate caller.
	TreeVisualModifiers.Apply(model, {
		SpeciesId = speciesId,
		GroveStage = stage,
		SizePotential = context.SizePotential,
		Mutations = context.Mutations,
		CurrentScale = model:GetAttribute("VisualScale"),
	})

	model.Name = "Preview_" .. kind .. "_" .. string.gsub(displayLabel, "%W+", "_")
	model:SetAttribute("DevTreeGalleryPreview", true)
	model:SetAttribute("DevTreeGalleryLabel", displayLabel)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
	return model
end

local function makeEntry(kind, speciesId, stage, mutations, label)
	local model = buildPreview(kind, speciesId, stage, mutations, label)
	local _, bounds = model:GetBoundingBox()
	local platformSize = Vector3.new(
		math.max(MIN_PLATFORM_SIZE, bounds.X + PLATFORM_PADDING),
		1,
		math.max(MIN_PLATFORM_SIZE, bounds.Z + PLATFORM_PADDING)
	)
	return {
		Kind = kind,
		Label = label,
		Model = model,
		PlatformSize = platformSize,
	}
end

local function addPlatform(parent, name, position, size)
	local platform = createPart(
		parent,
		name,
		size,
		CFrame.new(position.X, GALLERY_ORIGIN.Y - 0.5, position.Z),
		Color3.fromRGB(73, 112, 82),
		Enum.Material.SmoothPlastic
	)
	platform.TopSurface = Enum.SurfaceType.Smooth
	platform.BottomSurface = Enum.SurfaceType.Smooth
	return platform
end

local function makeOakHarvestSectionReference()
	local referenceTree = TreeObject.BuildPreviewModel("WildOak", {
		GroveStage = "mature",
		SizePotential = 1,
		Mutations = {},
	})
	assert(referenceTree and referenceTree:IsA("Model"), "Wild Oak preview builder returned no Model")

	local sectionsFolder = referenceTree:FindFirstChild("OakHarvestSections")
	local baseSection = sectionsFolder and sectionsFolder:FindFirstChild("Base")
	assert(baseSection and baseSection:IsA("Model"), "Wild Oak preview has no authored Base section")

	local section = baseSection:Clone()
	for _, descendant in ipairs(section:GetDescendants()) do
		if descendant:IsA("WeldConstraint") or descendant:IsA("JointInstance") then
			local part0 = descendant.Part0
			local part1 = descendant.Part1
			local bothPartsRemainInSection = part0
				and part1
				and part0:IsDescendantOf(section)
				and part1:IsDescendantOf(section)
			if not bothPartsRemainInSection then
				descendant:Destroy()
			end
		end
	end
	referenceTree:Destroy()
	section.Name = "OakHarvestSectionReference"
	section:SetAttribute("DevTreeGalleryPreview", true)
	section:SetAttribute("DevTreeGalleryLabel", "Original Oak Harvest Section")
	return section
end

local function makeStandardOakLogModel()
	local model = Instance.new("Model")
	model.Name = "StandardOakLogReference"

	-- Use the production standardized log builder so the comparison shows the
	-- exact SpeciesVisuals Oak ground-drop geometry. Ground drops use four times
	-- the carry footprint in LogService.
	local handle, caps = SpeciesVisuals.CreateLogParts({
		SpeciesId = "Oak",
		Mutations = {},
	}, "LogHandle", 4)
	handle.Parent = model
	for _, cap in ipairs(caps) do
		cap.Parent = model
	end
	model.PrimaryPart = handle
	model:SetAttribute("DevTreeGalleryPreview", true)
	model:SetAttribute("DevTreeGalleryLabel", "Standardized Oak Log")
	return model
end

local function configureVisualOnlyModel(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
end

local function placeVisualOnPlatform(model, center, orientation)
	configureVisualOnlyModel(model)
	model:PivotTo(CFrame.new(center.X, GALLERY_ORIGIN.Y, center.Z) * (orientation or CFrame.new()))
	local boundsCFrame, boundsSize = model:GetBoundingBox()
	local bottomY = boundsCFrame.Position.Y - boundsSize.Y * 0.5
	model:PivotTo(model:GetPivot() + Vector3.new(0, GALLERY_ORIGIN.Y - bottomY + 0.04, 0))
end

local function hideTemplateForClientClone(model, role)
	configureVisualOnlyModel(model)
	model:SetAttribute("DevTreeGalleryTemplate", true)
	model:SetAttribute("DevTreeGalleryTemplateRole", role)
	model:SetAttribute("SpeciesId", "Oak")
	model:SetAttribute("ClientCloneTransparencyAttribute", "DevOriginalTransparency")
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			-- The client bridge restores this value on its local clone before the
			-- transformation preview, retaining any intentional source alpha.
			descendant:SetAttribute("DevOriginalTransparency", descendant.Transparency)
			descendant.Transparency = 1
		end
	end
end

local function addTransformationPlayground(gallery)
	local playground = Instance.new("Folder")
	playground.Name = "TransformationPlayground"
	playground:SetAttribute("DevOnly", true)
	playground:SetAttribute("VisualOnly", true)
	playground:SetAttribute("SpeciesId", "Oak")
	playground.Parent = gallery

	local center = GALLERY_ORIGIN + Vector3.new(300, 0, 40)
	local sampleOffset = 17
	local sampleWidth = 28
	local sampleDepth = 24
	local sourceCenter = Vector3.new(center.X - sampleOffset, GALLERY_ORIGIN.Y, center.Z + 3)
	local destinationCenter = Vector3.new(center.X + sampleOffset, GALLERY_ORIGIN.Y, center.Z + 3)

	addSign(gallery, "LOG TRANSFORMATION PLAYGROUND", Vector3.new(center.X, 0, center.Z - 31), 64, "TransformationPlaygroundHeader")
	addPlatform(gallery, "TransformationSourcePlatform", Vector3.new(sourceCenter.X, GALLERY_ORIGIN.Y - 0.5, sourceCenter.Z), Vector3.new(sampleWidth, 1, sampleDepth))
	addPlatform(gallery, "TransformationDestinationPlatform", Vector3.new(destinationCenter.X, GALLERY_ORIGIN.Y - 0.5, destinationCenter.Z), Vector3.new(sampleWidth, 1, sampleDepth))
	addSign(gallery, "IRREGULAR OAK / HARVEST SIZE", Vector3.new(sourceCenter.X, 0, center.Z - 14), 30, "TransformationSourceLabel")
	addSign(gallery, "STANDARD OAK / LOG SIZE", Vector3.new(destinationCenter.X, 0, center.Z - 14), 30, "TransformationDestinationLabel")

	local sourceReference = makeOakHarvestSectionReference()
	-- Production harvest lays the tree's local Y trunk axis along the horizontal
	-- fall direction. Align it with the standardized log's local X length axis.
	local fallenSectionOrientation = CFrame.fromMatrix(
		Vector3.zero,
		Vector3.yAxis,
		Vector3.xAxis,
		Vector3.yAxis:Cross(Vector3.xAxis)
	)
	placeVisualOnPlatform(sourceReference, sourceCenter, fallenSectionOrientation)
	sourceReference.Parent = playground

	local destinationReference = makeStandardOakLogModel()
	placeVisualOnPlatform(destinationReference, destinationCenter)
	destinationReference.Parent = playground

	local sourceTemplate = sourceReference:Clone()
	sourceTemplate.Name = "TransformationSourceTemplate"
	sourceTemplate:SetAttribute("DevTreeGalleryLabel", "Original Oak Harvest Section")
	hideTemplateForClientClone(sourceTemplate, "Source")
	sourceTemplate.Parent = playground

	local destinationTemplate = destinationReference:Clone()
	destinationTemplate.Name = "TransformationDestinationTemplate"
	destinationTemplate:SetAttribute("DevTreeGalleryLabel", "Standardized Oak Log")
	hideTemplateForClientClone(destinationTemplate, "Destination")
	destinationTemplate.Parent = playground

	-- This marker is a local-preview anchor only; it has no server behavior.
	local demoSlot = createPart(
		playground,
		"DemoSlot",
		Vector3.new(1, 1, 1),
		CFrame.new(center.X, GALLERY_ORIGIN.Y + 0.5, center.Z + 16),
		Color3.new(1, 1, 1)
	)
	demoSlot.Transparency = 1
	demoSlot:SetAttribute("SourceTemplateName", sourceTemplate.Name)
	demoSlot:SetAttribute("DestinationTemplateName", destinationTemplate.Name)
	demoSlot:SetAttribute("DevGalleryAction", "PreviewLogTransformation")

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TransformationPreviewPrompt"
	prompt.ActionText = "Preview Log Transformation"
	prompt.ObjectText = "Oak Log"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("DevTreeGalleryTransformationPrompt", true)
	prompt:SetAttribute("DevGalleryAction", "PreviewLogTransformation")
	prompt:SetAttribute("SpeciesId", "Oak")
	prompt:SetAttribute("SourceTemplateName", sourceTemplate.Name)
	prompt:SetAttribute("DestinationTemplateName", destinationTemplate.Name)
	prompt:SetAttribute("DemoSlotName", demoSlot.Name)
	prompt.Parent = demoSlot
end

local function arrangeRow(gallery, title, entries, rowZ)
	local rowDepth = MIN_PLATFORM_SIZE
	local rowWidth = 0
	for index, entry in ipairs(entries) do
		rowDepth = math.max(rowDepth, entry.PlatformSize.Z)
		rowWidth += entry.PlatformSize.X
		if index > 1 then
			rowWidth += COLUMN_GAP
		end
	end

	local cursorX = GALLERY_ORIGIN.X
	for index, entry in ipairs(entries) do
		local width = entry.PlatformSize.X
		local depth = entry.PlatformSize.Z
		local centerX = cursorX + width * 0.5
		local centerZ = GALLERY_ORIGIN.Z + rowZ
		local platformCenter = Vector3.new(centerX, GALLERY_ORIGIN.Y - 0.5, centerZ)
		addPlatform(gallery, "Platform_" .. title .. "_" .. index, platformCenter, entry.PlatformSize)

		local model = entry.Model
		model:PivotTo(CFrame.new(centerX, GALLERY_ORIGIN.Y, centerZ))
		local boxCFrame, boxSize = model:GetBoundingBox()
		local modelBottomY = boxCFrame.Position.Y - boxSize.Y * 0.5
		model:PivotTo(model:GetPivot() + Vector3.new(0, GALLERY_ORIGIN.Y - modelBottomY + 0.04, 0))
		model.Parent = gallery

		local frontZ = centerZ - depth * 0.5 - 2
		addSign(gallery, entry.Label, Vector3.new(centerX, 0, frontZ), math.clamp(width - 2, 18, 42), "Sign_" .. title .. "_" .. index)
		cursorX += width + COLUMN_GAP
	end

	local rowCenterX = GALLERY_ORIGIN.X + rowWidth * 0.5
	local headerZ = GALLERY_ORIGIN.Z + rowZ - rowDepth * 0.5 - 21
	addSign(gallery, title, Vector3.new(rowCenterX, 0, headerZ), math.clamp(rowWidth * 0.42, 28, 46), "Header_" .. title)

	return rowDepth, rowWidth, rowCenterX
end

local function createGallery()
	local gallery = Instance.new("Model")
	gallery.Name = GALLERY_NAME
	gallery:SetAttribute("DevOnly", true)
	gallery:SetAttribute("VisualOnly", true)
	gallery:SetAttribute("GalleryOrigin", GALLERY_ORIGIN)

	-- Preview trees remain completely non-colliding. This Studio-only floor is
	-- the sole walkable utility surface so a manually teleported tester can
	-- inspect the rows without falling from the isolated gallery area.
	local floorCenter = GALLERY_ORIGIN + GALLERY_FLOOR_OFFSET
	local floor = createPart(
		gallery,
		"GalleryFloor",
		GALLERY_FLOOR_SIZE,
		CFrame.new(floorCenter),
		Color3.fromRGB(54, 78, 62),
		Enum.Material.SmoothPlastic
	)
	floor.CanCollide = true
	floor.Transparency = 0.12

	local spawnPosition = GALLERY_ORIGIN + Vector3.new(20, 0.5, -78)
	local spawnMarker = createPart(
		gallery,
		"GallerySpawn",
		Vector3.new(1, 1, 1),
		CFrame.lookAt(spawnPosition, spawnPosition + Vector3.new(0, 0, 1)),
		Color3.new(1, 1, 1)
	)
	spawnMarker.Transparency = 1
	spawnMarker:SetAttribute("CommandBarHint", "PivotTo(GallerySpawn.CFrame + Vector3.new(0, 4, 0))")
	gallery.PrimaryPart = spawnMarker

	local firstHeaderPosition = GALLERY_ORIGIN + Vector3.new(20, 0, -57)
	addSign(gallery, "DEV TREE GALLERY - START HERE", firstHeaderPosition, 40, "GalleryWelcome")

	local nextZ = 0
	local function addRow(title, entries)
		local rowDepth = arrangeRow(gallery, title, entries, nextZ)
		nextZ += rowDepth + ROW_GAP
	end

	for _, species in ipairs({
		{ Label = "OAK", Kind = "GroveOak", SpeciesId = "Oak" },
		{ Label = "BAMBOO", Kind = "Bamboo", SpeciesId = "Bamboo" },
		{ Label = "IRONWOOD", Kind = "Ironwood", SpeciesId = "Ironwood" },
	}) do
		local entries = {}
		for _, variant in ipairs(MUTATION_VARIANTS) do
			table.insert(entries, makeEntry(
				species.Kind,
				species.SpeciesId,
				"mature",
				variant.Mutations,
				species.Label .. " - " .. variant.Label
			))
		end
		addRow("MATURE GROVE MUTATIONS / " .. species.Label, entries)
	end

	for _, species in ipairs({
		{ Label = "OAK", Kind = "GroveOak", SpeciesId = "Oak" },
		{ Label = "BAMBOO", Kind = "Bamboo", SpeciesId = "Bamboo" },
		{ Label = "IRONWOOD", Kind = "Ironwood", SpeciesId = "Ironwood" },
	}) do
		local entries = {}
		for _, stage in ipairs({
			{ Label = "Sapling", Id = "sapling" },
			{ Label = "Young", Id = "young" },
			{ Label = "Mature", Id = "mature" },
		}) do
			table.insert(entries, makeEntry(
				species.Kind,
				species.SpeciesId,
				stage.Id,
				{},
				species.Label .. " - " .. stage.Label
			))
		end
		addRow("GROWTH STAGES / " .. species.Label, entries)
	end

	addRow("MATURE OAK BUILDER COMPARISON", {
		makeEntry("WildOak", "Oak", "mature", {}, "Wild Oak"),
		makeEntry("GroveOak", "Oak", "mature", {}, "Grove Oak"),
	})

	addTransformationPlayground(gallery)

	return gallery
end

local ok, galleryOrError = pcall(createGallery)
if not ok then
	warn("[DevTreeGallery] Build failed: " .. tostring(galleryOrError))
	return
end

local previousGallery = Workspace:FindFirstChild(GALLERY_NAME)
if previousGallery then
	previousGallery:Destroy()
end

galleryOrError.Parent = Workspace
print(
	"[DevTreeGallery] Built at " .. tostring(GALLERY_ORIGIN)
		.. ". Server Command Bar: local p=game:GetService(\"Players\"):GetPlayers()[1]; local g=workspace:FindFirstChild(\"DevTreeGallery\"); local s=g and g:FindFirstChild(\"GallerySpawn\"); if p and p.Character and s then p.Character:PivotTo(s.CFrame + Vector3.new(0, 4, 0)) end"
)
