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

local function createStarterOakBlock(parent, name, size, position, color)
	local part = createPart(parent, name, size, CFrame.new(position), color, Enum.Material.SmoothPlastic)
	-- This prototype deliberately has no toy-brick studs. Its identity comes
	-- from a small, stepped assembly of crisp rectangular forms instead.
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.FrontSurface = Enum.SurfaceType.Smooth
	part.BackSurface = Enum.SurfaceType.Smooth
	part.LeftSurface = Enum.SurfaceType.Smooth
	part.RightSurface = Enum.SurfaceType.Smooth
	part.CastShadow = true
	return part
end

-- A static visual study for the next Starter Oak direction. It intentionally
-- lives in the gallery rather than TreeObject: it creates no Tree instance,
-- hitbox, rewards, or harvesting registration. The named groups provide an
-- obvious future seam for authored trunk sections and decorative foliage.
local function makeStarterOakPrototype()
	local palette = SpeciesVisuals.GetPalette("Oak")
	local model = Instance.new("Model")
	model.Name = "StarterOakPrototype"
	model:SetAttribute("DevTreeGalleryPreview", true)
	model:SetAttribute("VisualOnly", true)
	model:SetAttribute("PrototypeOnly", true)
	model:SetAttribute("SpeciesId", "Oak")
	model:SetAttribute("DesignDirection", "StarterOakStudFree")

	local trunkGroup = Instance.new("Folder")
	trunkGroup.Name = "FutureHarvestTrunk"
	trunkGroup.Parent = model
	local branchGroup = Instance.new("Folder")
	branchGroup.Name = "DecorativeBranches"
	branchGroup.Parent = model
	local foliageGroup = Instance.new("Folder")
	foliageGroup.Name = "FoliageDecorations"
	foliageGroup.Parent = model

	-- A sturdy, straight starter trunk. The two shallow shade blocks add only
	-- enough definition to avoid a flat brown column.
	local trunk = createStarterOakBlock(trunkGroup, "TrunkCore", Vector3.new(3.2, 10, 3.2), Vector3.new(0, 5, 0), palette.Bark)
	model.PrimaryPart = trunk
	createStarterOakBlock(trunkGroup, "TrunkWarmFace", Vector3.new(0.28, 4.3, 2.45), Vector3.new(-1.47, 6.1, -0.1), palette.BarkHighlight)
	createStarterOakBlock(trunkGroup, "TrunkShadowFace", Vector3.new(2.45, 3.2, 0.28), Vector3.new(0.08, 3.0, 1.47), palette.BarkShadow)
	createStarterOakBlock(trunkGroup, "TrunkCrown", Vector3.new(3.8, 3.4, 3.8), Vector3.new(0, 10.5, 0), palette.Bark)

	-- These small, embedded blocks read as simple branch junctions without
	-- becoming roots, sprawling boughs, or separate collectible geometry.
	createStarterOakBlock(branchGroup, "BranchLeft", Vector3.new(3.5, 2.1, 2.8), Vector3.new(-2.5, 11.7, 0.2), palette.BarkHighlight)
	createStarterOakBlock(branchGroup, "BranchRight", Vector3.new(3.3, 2.1, 2.8), Vector3.new(2.4, 12.0, -0.15), palette.BarkHighlight)
	createStarterOakBlock(branchGroup, "BranchFront", Vector3.new(2.7, 1.9, 3.2), Vector3.new(0.15, 12.3, -2.25), palette.Bark)

	-- Layered, axis-aligned canopy: broad at the base, compact through the
	-- middle, and visibly stepped into a soft Oak silhouette from all sides.
	local foliage = {
		{ "CanopyLowCenter", Vector3.new(8.4, 3.8, 8.6), Vector3.new(0, 13.7, 0.1), palette.LeafShadow },
		{ "CanopyLowLeft", Vector3.new(4.8, 3.7, 5.8), Vector3.new(-4.15, 13.9, 0.35), palette.LeafShadow },
		{ "CanopyLowRight", Vector3.new(4.8, 3.7, 5.8), Vector3.new(4.15, 14.1, -0.2), palette.Leaf },
		{ "CanopyFront", Vector3.new(6.8, 3.5, 4.1), Vector3.new(0.2, 14.4, -3.65), palette.Leaf },
		{ "CanopyMiddle", Vector3.new(8.7, 3.9, 8.1), Vector3.new(0, 16.7, 0), palette.Leaf },
		{ "CanopyMiddleLeft", Vector3.new(4.7, 3.5, 5.4), Vector3.new(-2.85, 17.1, 0.85), palette.LeafHighlight },
		{ "CanopyMiddleBack", Vector3.new(5.6, 3.4, 4.5), Vector3.new(1.85, 17.4, 2.75), palette.LeafShadow },
		{ "CanopyUpper", Vector3.new(6.8, 3.8, 6.5), Vector3.new(-0.15, 19.5, 0.1), palette.LeafHighlight },
		{ "CanopyCrown", Vector3.new(3.9, 2.6, 3.8), Vector3.new(0.45, 22.1, -0.15), palette.Leaf },
	}
	for _, definition in ipairs(foliage) do
		createStarterOakBlock(foliageGroup, definition[1], definition[2], definition[3], definition[4])
	end

	return model
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

local function makeStaticEntry(model, label)
	local _, bounds = model:GetBoundingBox()
	model.Name = "Preview_StarterOakPrototype"
	model:SetAttribute("DevTreeGalleryLabel", label)
	return {
		Kind = "StarterOakPrototype",
		Label = label,
		Model = model,
		PlatformSize = Vector3.new(
			math.max(MIN_PLATFORM_SIZE, bounds.X + PLATFORM_PADDING),
			1,
			math.max(MIN_PLATFORM_SIZE, bounds.Z + PLATFORM_PADDING)
		),
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

	local center = GALLERY_ORIGIN + Vector3.new(275, 0, 485)
	local demoSlotCFrame = CFrame.new(center.X - 24, GALLERY_ORIGIN.Y + 1.5, center.Z - 15)
	addSign(gallery, "FULL TREE HARVEST SHOWCASE", Vector3.new(center.X + 12, 0, center.Z - 24), 58, "TransformationPlaygroundHeader")
	addPlatform(playground, "ShowcaseStage", center, Vector3.new(90, 1, 44))

	-- The normal three-section wild Oak builder is enlarged only for this
	-- gallery. Irregular protrusions already belong to the trunk sections.
	local tree = TreeObject.BuildPreviewModel("WildOak", {
		GroveStage = "mature",
		SizePotential = 1.55,
		Mutations = {},
	})
	assert(tree and tree.PrimaryPart, "Full harvest preview needs the wild Oak builder")
	local sections = tree:FindFirstChild("OakHarvestSections")
	assert(sections, "Full harvest preview needs authored Oak sections")
	for index, name in ipairs({ "Base", "Middle", "Top" }) do
		local section = sections:FindFirstChild(name)
		assert(section and section.PrimaryPart, "Missing authored Oak section: " .. name)
		local core = section.PrimaryPart
		local direction = if index == 2 then -1 else 1
		local branch = createPart(section, "ShowcaseTrunkProtrusion", Vector3.new(4.4, 2.3, 2.1),
			core.CFrame * CFrame.new(direction * (core.Size.X * 0.5 + 1.3), core.Size.Y * 0.14, 0)
				* CFrame.Angles(0, 0, direction * 0.32), core.Color, core.Material)
		branch:SetAttribute("DevShowcaseGeometry", true)
		local knot = createPart(section, "ShowcaseBarkKnot", Vector3.new(1.4, 2.8, 1.4),
			core.CFrame * CFrame.new(-direction * core.Size.X * 0.45, -core.Size.Y * 0.22, core.Size.Z * 0.55),
			core.Color, core.Material)
		knot:SetAttribute("DevShowcaseGeometry", true)
	end
	configureVisualOnlyModel(tree)
	tree.Name = "ShowcaseTree"
	tree:PivotTo(CFrame.new(center.X - 24, GALLERY_ORIGIN.Y + 0.04, center.Z))
	tree.Parent = playground

	local destinationTemplate = makeStandardOakLogModel()
	destinationTemplate.Name = "TransformationDestinationTemplate"
	-- The builder creates parts at the world origin. Keep the invisible
	-- template beside the showcase so StreamingEnabled clients receive it,
	-- and stream its complete geometry as one model.
	destinationTemplate.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	destinationTemplate:PivotTo(demoSlotCFrame)
	hideTemplateForClientClone(destinationTemplate, "Destination")
	destinationTemplate.Parent = playground

	-- This marker is a local-preview anchor only; it has no server behavior.
	local demoSlot = createPart(
		playground,
		"DemoSlot",
		Vector3.new(1, 1, 1),
		demoSlotCFrame,
		Color3.new(1, 1, 1)
	)
	demoSlot.Transparency = 1
	demoSlot:SetAttribute("GroundY", GALLERY_ORIGIN.Y)
	-- Attributes on the gallery model replicate even when the distant marker is
	-- not streamed to the client yet.
	gallery:SetAttribute("ShowcaseTeleportCFrame", demoSlot.CFrame + Vector3.new(0, 4, -5))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TransformationPreviewPrompt"
	prompt.ActionText = "Preview Full Harvest"
	prompt.ObjectText = "Large Oak"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("DevTreeGalleryTransformationPrompt", true)
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

	addRow("STARTER OAK — STUD-FREE VISUAL PROTOTYPE", {
		makeStaticEntry(makeStarterOakPrototype(), "Approved Starter Oak Direction"),
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
