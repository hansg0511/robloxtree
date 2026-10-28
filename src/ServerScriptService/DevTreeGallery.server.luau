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
-- Gallery-only dimensions and a deliberately small proportion check prevent
-- the Starter Oak preview from producing short, blocky harvest pieces.
local STARTER_OAK_HARVEST_TRUNK_LENGTH = 12
local STARTER_OAK_HARVEST_TRUNK_THICKNESS = 2.4
local STARTER_OAK_MIN_HARVEST_SECTION_LENGTH = 4.5
local STARTER_OAK_MIN_HARVEST_LENGTH_TO_THICKNESS_RATIO = 2.5

local function isAcceptableStarterOakSectionLength(sectionLength)
	return sectionLength >= STARTER_OAK_MIN_HARVEST_SECTION_LENGTH
		and sectionLength / STARTER_OAK_HARVEST_TRUNK_THICKNESS
			>= STARTER_OAK_MIN_HARVEST_LENGTH_TO_THICKNESS_RATIO
end

local function chooseStarterOakHarvestSectionCount()
	local twoSectionLength = STARTER_OAK_HARVEST_TRUNK_LENGTH / 2
	if isAcceptableStarterOakSectionLength(twoSectionLength) then
		return 2
	end
	assert(isAcceptableStarterOakSectionLength(STARTER_OAK_HARVEST_TRUNK_LENGTH),
		"Starter Oak gallery trunk is too short or thin for one acceptable harvest section")
	return 1
end

-- The normal Starter Oak uses two sections. If its gallery-only trunk is
-- shortened later, it falls back to one rather than creating cubic pieces.
local STARTER_OAK_HARVEST_SHOWCASE_YIELD = chooseStarterOakHarvestSectionCount()

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

-- One gallery-only foliage recipe keeps the visual prototype and harvest
-- showcase aligned. Each block is a full, overlapping volume so the crown
-- reads as a compact, rounded Oak from more than one camera angle.
local function addStarterOakCanopy(parent, palette)
	local foliage = {
		{ "CanopyCore", Vector3.new(6.4, 5.8, 6.4), Vector3.new(0, 14.45, 0), palette.LeafShadow },
		{ "CanopyLeftShoulder", Vector3.new(5.0, 5.0, 5.5), Vector3.new(-3.0, 14.1, 0.1), palette.LeafShadow },
		{ "CanopyRightShoulder", Vector3.new(5.0, 5.0, 5.5), Vector3.new(2.9, 14.15, -0.15), palette.Leaf },
		{ "CanopyFrontLobe", Vector3.new(5.6, 4.6, 4.5), Vector3.new(0.2, 13.9, -2.3), palette.Leaf },
		{ "CanopyBackLobe", Vector3.new(5.3, 4.7, 4.4), Vector3.new(-0.35, 13.85, 2.35), palette.LeafShadow },
		{ "CanopyTop", Vector3.new(5.2, 4.8, 5.2), Vector3.new(-0.45, 16.55, 0.45), palette.LeafHighlight },
	}
	-- The right shoulder's bottom is 11.65 studs high and its +X edge is 5.4.
	-- Against the 1.19-stud half-width base, it meets the ground at
	-- atan(11.65 / (5.4 - 1.19)) ~= 70.1 degrees; the nearest branch stays
	-- about 1.03 studs above that contact, so foliage remains the first support.
	for _, definition in ipairs(foliage) do
		createStarterOakBlock(parent, definition[1], definition[2], definition[3], definition[4])
	end
end

-- The static prototype and the harvest showcase use the same six trunk
-- components, so their visible 12 x 2.4 proportions and bark accents agree.
local function getStarterOakTrunkComponents(palette)
	local halfTrunkLength = STARTER_OAK_HARVEST_TRUNK_LENGTH * 0.5
	local halfTrunkThickness = STARTER_OAK_HARVEST_TRUNK_THICKNESS * 0.5
	local trunkCoreThickness = STARTER_OAK_HARVEST_TRUNK_THICKNESS - 0.02
	return {
		{
			{ "BaseCore", Vector3.new(trunkCoreThickness, halfTrunkLength, trunkCoreThickness), Vector3.new(0, halfTrunkLength * 0.5, 0), palette.Bark },
			{ "BaseWarmFace", Vector3.new(0.12, halfTrunkLength * 0.7, 1.75), Vector3.new(-halfTrunkThickness + 0.06, halfTrunkLength * 0.517, -0.08), palette.BarkHighlight },
			{ "BaseShadowFace", Vector3.new(1.75, halfTrunkLength * 0.467, 0.12), Vector3.new(0.08, halfTrunkLength * 0.317, halfTrunkThickness - 0.06), palette.BarkShadow },
		},
		{
			{ "TopCore", Vector3.new(trunkCoreThickness, halfTrunkLength, trunkCoreThickness), Vector3.new(0, halfTrunkLength * 1.5, 0), palette.Bark },
			{ "TopWarmFace", Vector3.new(0.12, halfTrunkLength * 0.65, 1.75), Vector3.new(halfTrunkThickness - 0.06, halfTrunkLength * 1.467, 0.08), palette.BarkHighlight },
			{ "TopShadowFace", Vector3.new(1.75, halfTrunkLength * 0.433, 0.12), Vector3.new(-0.08, halfTrunkLength * 1.683, -halfTrunkThickness + 0.06), palette.BarkShadow },
		},
	}
end

local function addStarterOakBranches(parent, palette)
	createStarterOakBlock(parent, "BranchLeft", Vector3.new(3.5, 2.1, 2.8), Vector3.new(-2.5, 11.7, 0.2), palette.BarkHighlight)
	createStarterOakBlock(parent, "BranchRight", Vector3.new(3.3, 2.1, 2.8), Vector3.new(2.4, 12.0, -0.15), palette.BarkHighlight)
	createStarterOakBlock(parent, "BranchFront", Vector3.new(2.7, 1.9, 3.2), Vector3.new(0.15, 12.3, -2.25), palette.Bark)
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

	-- Keep the static trunk identical to the harvest trunk, including the slim
	-- two-section proportions, instead of displaying a separate chunky column.
	local trunkCore
	for _, component in ipairs(getStarterOakTrunkComponents(palette)) do
		for _, definition in ipairs(component) do
			local part = createStarterOakBlock(trunkGroup, definition[1], definition[2], definition[3], definition[4])
			if definition[1] == "BaseCore" then trunkCore = part end
		end
	end
	model.PrimaryPart = trunkCore

	-- These small, embedded blocks read as simple branch junctions without
	-- becoming roots, sprawling boughs, or separate collectible geometry.
	addStarterOakBranches(branchGroup, palette)

	-- Shared chunky volumes give both Oak versions the same compact crown.
	addStarterOakCanopy(foliageGroup, palette)

	return model
end

local STARTER_OAK_NORMALIZED_LOG_LENGTH = 7
local STARTER_OAK_NORMALIZED_LOG_DIAMETER = 1.8
local STARTER_OAK_NORMALIZED_LOG_BODY_DIAMETER = STARTER_OAK_NORMALIZED_LOG_DIAMETER - 0.02

-- Gallery-only authored version of the approved Starter Oak. The sections are
-- actual pieces of its trunk; canopy and branch blocks deliberately remain
-- outside them so they cannot prop a fallen section above the ground.
local function makeStarterOakHarvestTree(sectionCount)
	local rangesByYield = {
		[1] = { { 1, 2 } },
		[2] = { { 1, 1 }, { 2, 2 } },
	}
	local ranges = rangesByYield[sectionCount]
	assert(ranges, "Starter Oak supports only 1 or 2 harvest sections")

	local palette = SpeciesVisuals.GetPalette("Oak")
	local model = Instance.new("Model")
	model.Name = "StarterOakHarvestTree"
	model:SetAttribute("DevTreeGalleryPreview", true)
	model:SetAttribute("VisualOnly", true)
	model:SetAttribute("PrototypeOnly", true)
	model:SetAttribute("SpeciesId", "Oak")
	model:SetAttribute("SupportedHarvestYields", "1,2")
	model:SetAttribute("HarvestYieldPreview", sectionCount)

	local pivot = createStarterOakBlock(model, "StarterOakPivot", Vector3.new(0.2, 0.2, 0.2), Vector3.new(0, 0.1, 0), palette.Bark)
	pivot.Transparency = 1
	pivot.CastShadow = false
	pivot:SetAttribute("AlwaysInvisible", true)
	pivot.PivotOffset = CFrame.new(0, -0.1, 0)
	model.PrimaryPart = pivot

	local sectionsFolder = Instance.new("Folder")
	sectionsFolder.Name = "StarterOakHarvestSections"
	sectionsFolder.Parent = model
	local components = getStarterOakTrunkComponents(palette)

	for sectionIndex, range in ipairs(ranges) do
		local section = Instance.new("Model")
		section.Name = "Section" .. sectionIndex
		section:SetAttribute("AuthoredHarvestSection", true)
		section:SetAttribute("HarvestSectionIndex", sectionIndex)
		section:SetAttribute("SpeciesId", "Oak")
		section.Parent = sectionsFolder
		for componentIndex = range[1], range[2] do
			for _, definition in ipairs(components[componentIndex]) do
				local part = createStarterOakBlock(section, definition[1], definition[2], definition[3], definition[4])
				if not section.PrimaryPart then section.PrimaryPart = part end
			end
		end
	end

	local branches = Instance.new("Folder")
	branches.Name = "DecorativeBranches"
	branches.Parent = model
	addStarterOakBranches(branches, palette)

	local foliage = Instance.new("Folder")
	foliage.Name = "FoliageDecorations"
	foliage.Parent = model
	addStarterOakCanopy(foliage, palette)

	return model
end

-- Smooth logs carry a shared 7 x 1.8 x 1.8 outer footprint. The
-- source section determines the bark accent placement, preserving its visual
-- identity while removing branches and uneven geometry that would stack badly.
local function makeStarterOakNormalizedLogTemplate(sectionIndex)
	local palette = SpeciesVisuals.GetPalette("Oak")
	local model = Instance.new("Model")
	model.Name = "StarterOakNormalizedLog" .. sectionIndex
	model:SetAttribute("DevTreeGalleryPreview", true)
	model:SetAttribute("VisualOnly", true)
	model:SetAttribute("PrototypeOnly", true)
	model:SetAttribute("SpeciesId", "Oak")
	model:SetAttribute("NormalizedFromSection", sectionIndex)
	model:SetAttribute("NormalizedOuterLength", STARTER_OAK_NORMALIZED_LOG_LENGTH)
	model:SetAttribute("NormalizedOuterDiameter", STARTER_OAK_NORMALIZED_LOG_DIAMETER)

	local length = STARTER_OAK_NORMALIZED_LOG_LENGTH
	local diameter = STARTER_OAK_NORMALIZED_LOG_DIAMETER
	local bodyDiameter = STARTER_OAK_NORMALIZED_LOG_BODY_DIAMETER
	local handle = createStarterOakBlock(model, "LogHandle", Vector3.new(length, bodyDiameter, bodyDiameter), Vector3.zero, palette.Bark)
	model.PrimaryPart = handle
	createStarterOakBlock(model, "CutEndLeft", Vector3.new(0.18, diameter * 0.82, diameter * 0.82), Vector3.new(-length * 0.5 + 0.09, 0, 0), palette.CutEnd)
	createStarterOakBlock(model, "CutEndRight", Vector3.new(0.18, diameter * 0.82, diameter * 0.82), Vector3.new(length * 0.5 - 0.09, 0, 0), palette.CutEnd)

	if sectionIndex == 1 then
		createStarterOakBlock(model, "BaseWarmBark", Vector3.new(length * 0.52, 0.08, diameter * 0.72), Vector3.new(-0.38, diameter * 0.5 - 0.04, -0.12), palette.BarkHighlight)
		createStarterOakBlock(model, "BaseShadowBark", Vector3.new(length * 0.32, diameter * 0.56, 0.08), Vector3.new(0.85, -0.12, diameter * 0.5 - 0.04), palette.BarkShadow)
	elseif sectionIndex == 2 then
		createStarterOakBlock(model, "MiddleWarmBark", Vector3.new(length * 0.42, 0.08, diameter * 0.74), Vector3.new(0.36, diameter * 0.5 - 0.04, 0.08), palette.BarkHighlight)
		createStarterOakBlock(model, "MiddleShadowBark", Vector3.new(length * 0.2, diameter * 0.48, 0.08), Vector3.new(-1.0, 0.12, -diameter * 0.5 + 0.04), palette.BarkShadow)
	else
		createStarterOakBlock(model, "TopWarmBark", Vector3.new(length * 0.30, 0.08, diameter * 0.72), Vector3.new(0.8, diameter * 0.5 - 0.04, 0), palette.BarkHighlight)
		createStarterOakBlock(model, "TopBarkKnot", Vector3.new(0.48, 0.38, 0.08), Vector3.new(-0.72, 0.12, -diameter * 0.5 + 0.04), palette.BarkShadow)
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
	playground:SetAttribute("DevHarvestShowcase", true)
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

local function addStarterOakHarvestPlayground(gallery)
	local playground = Instance.new("Folder")
	playground.Name = "StarterOakHarvestPlayground"
	playground:SetAttribute("DevOnly", true)
	playground:SetAttribute("VisualOnly", true)
	playground:SetAttribute("DevHarvestShowcase", true)
	playground:SetAttribute("SpeciesId", "Oak")
	playground:SetAttribute("SourceTreeName", "StarterOakHarvestTree")
	playground:SetAttribute("SectionFolderName", "StarterOakHarvestSections")
	playground:SetAttribute("NormalizationTemplateFolder", "StarterOakNormalizedLogTemplates")
	playground:SetAttribute("SupportedHarvestYields", "1,2")
	playground:SetAttribute("FallStyle", "CanopySupported")
	playground.Parent = gallery

	local center = GALLERY_ORIGIN + Vector3.new(75, 0, 485)
	local demoSlotCFrame = CFrame.new(center.X - 15, GALLERY_ORIGIN.Y + 1.5, center.Z - 13)
	addSign(gallery, "STARTER OAK — TREE-DERIVED LOG SHOWCASE", Vector3.new(center.X, 0, center.Z - 25), 58, "StarterOakHarvestHeader")
	addPlatform(playground, "ShowcaseStage", center, Vector3.new(82, 1, 44))

	assert(STARTER_OAK_HARVEST_SHOWCASE_YIELD >= 1 and STARTER_OAK_HARVEST_SHOWCASE_YIELD <= 2,
		"Starter Oak gallery yield must be 1 or 2")
	local tree = makeStarterOakHarvestTree(STARTER_OAK_HARVEST_SHOWCASE_YIELD)
	configureVisualOnlyModel(tree)
	tree.Name = "StarterOakHarvestTree"
	tree:PivotTo(CFrame.new(center.X - 15, GALLERY_ORIGIN.Y + 0.04, center.Z))
	tree.Parent = playground

	local templateFolder = Instance.new("Folder")
	templateFolder.Name = "StarterOakNormalizedLogTemplates"
	templateFolder.Parent = playground
	for index = 1, STARTER_OAK_HARVEST_SHOWCASE_YIELD do
		local template = makeStarterOakNormalizedLogTemplate(index)
		template.Name = "Section" .. index
		template.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		template:PivotTo(demoSlotCFrame)
		hideTemplateForClientClone(template, "StarterOakSection" .. index)
		template.Parent = templateFolder
	end

	local demoSlot = createPart(
		playground,
		"DemoSlot",
		Vector3.new(1, 1, 1),
		demoSlotCFrame,
		Color3.new(1, 1, 1)
	)
	demoSlot.Transparency = 1
	demoSlot:SetAttribute("GroundY", GALLERY_ORIGIN.Y)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StarterOakHarvestPreviewPrompt"
	prompt.ActionText = "Preview Starter Oak Harvest"
	prompt.ObjectText = "Starter Oak (" .. STARTER_OAK_HARVEST_SHOWCASE_YIELD
		.. (STARTER_OAK_HARVEST_SHOWCASE_YIELD == 1 and " log)" or " logs)")
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

	addStarterOakHarvestPlayground(gallery)
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
