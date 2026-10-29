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
local DevStarterOakGenerator = require(ServerScriptService:WaitForChild("DevStarterOakGenerator"))
local TreeVisualModifiers = require(ServerStorage:WaitForChild("TreeVisualModifiers"))
local SpeciesVisuals = require(ServerStorage:WaitForChild("SpeciesVisuals"))

local GALLERY_NAME = "DevTreeGallery"
local GALLERY_ORIGIN = Vector3.new(6000, 120, 6000)
local GALLERY_FLOOR_SIZE = Vector3.new(360, 1, 1000)
local GALLERY_FLOOR_OFFSET = Vector3.new(180, -1, 400)
local STARTER_OAK_REFERENCE_ROW_Z = 600
local STARTER_OAK_PROCEDURAL_ROW_START_Z = 680
-- Change this Studio-only seed and restart the server to build a new reproducible set.
local STARTER_OAK_GALLERY_SEED = 20261030
local STARTER_OAK_GALLERY_SAMPLE_COUNT = 12
local STARTER_OAK_GALLERY_TREES_PER_ROW = 4
local STARTER_OAK_GALLERY_EXTREME_SAMPLES = {
	[4] = true,
	[8] = true,
	[12] = true,
}
local STARTER_OAK_GALLERY_ROW_GAP = 34
assert(
	type(STARTER_OAK_GALLERY_SEED) == "number"
		and STARTER_OAK_GALLERY_SEED % 1 == 0
		and STARTER_OAK_GALLERY_SEED >= -2147483647
		and STARTER_OAK_GALLERY_SEED <= 2147483647 - (STARTER_OAK_GALLERY_SAMPLE_COUNT - 1),
	"Starter Oak gallery seed must be an integer in range so all sample seeds stay unique"
)
local STARTER_OAK_PROCEDURAL_ROW_START_X = 56
local STARTER_OAK_STRUCTURE_ROW_START_X = 4
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

-- Procedural harvest samples are still gallery-only. Change each Seed to move
-- the bounded deterministic search to a different reproducible seed range.
-- A sample is shown only when its generated dimensions match the requested
-- profile; the actual selected seed is written to the model and its sign.
-- RequiredHarvestSectionCount filters candidate seeds for coverage only; the
-- accepted count is always computed from the generated trunk dimensions.
local PROCEDURAL_STARTER_OAK_HARVEST = {
	MinimumSectionLength = 4.5,
	MinimumLengthToThicknessRatio = 2.5,
	SeedSearchCandidates = 512,
	StageCenterZ = 560,
	StageWidth = 66,
	StageDepth = 44,
	StageGap = 8,
	Samples = {
		{
			Key = "Short",
			Label = "SHORT / SMALL OAK",
			Seed = 20261030,
			ExactSeed = nil, -- Set an integer here to preview exactly that seed without category substitution.
			Extreme = true,
			MinimumCoreHeight = 8.5,
			MaximumCoreHeight = 8.99,
			RequiredHarvestSectionCount = 1,
		},
		{
			Key = "Normal",
			Label = "NORMAL OAK",
			Seed = 20261030,
			ExactSeed = nil,
			Extreme = false,
			MinimumCoreHeight = 12,
			MaximumCoreHeight = 17,
			RequiredHarvestSectionCount = 2,
		},
		{
			Key = "Tall",
			Label = "TALL OAK",
			Seed = 20261030,
			ExactSeed = nil,
			Extreme = true,
			MinimumCoreHeight = 18.5,
			MaximumCoreHeight = 22,
		},
		{
			Key = "ExtremeAsymmetrical",
			Label = "EXTREME / ASYMMETRICAL OAK",
			Seed = 20261030,
			ExactSeed = nil,
			Extreme = true,
			MinimumCanopyAsymmetryRatio = 0.12,
		},
	},
}
local PROCEDURAL_STARTER_OAK_MIN_SEED = -2147483647
local PROCEDURAL_STARTER_OAK_MAX_SEED = 2147483647

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

-- Five intentionally authored Starter Oak arrangements share one trunk,
-- palette, and part builder. Positions are relative to the trunk base; front
-- is -Z. The overlaps are planned in X, Y, and Z so the rear and side views
-- retain the same leafy structure as the front.
local STARTER_OAK_VARIANTS = {
	A = {
		Name = "Balanced",
		Foliage = {
			{ Name = "LowerLeftFront", Size = Vector3.new(5.0, 3.0, 4.6), Position = Vector3.new(2.5, 8.35, -1.4), ColorRole = "Leaf" },
			{ Name = "LowerRightFront", Size = Vector3.new(4.8, 2.8, 4.4), Position = Vector3.new(-2.5, 8.15, -1.3), ColorRole = "Leaf" },
			{ Name = "LowerLeftBack", Size = Vector3.new(4.4, 2.8, 4.8), Position = Vector3.new(-2.8, 8.35, 2.6), ColorRole = "LeafShadow" },
			{ Name = "LowerRightBack", Size = Vector3.new(4.4, 2.8, 4.4), Position = Vector3.new(2.1, 8.6, 2.35), ColorRole = "LeafShadow" },
			{ Name = "FrontAccent", Size = Vector3.new(3.4, 2.4, 3.8), Position = Vector3.new(1.0, 9.1, -2.6), ColorRole = "Leaf" },
			{ Name = "MiddleCore", Size = Vector3.new(6.2, 3.2, 5.8), Position = Vector3.new(0, 9.8, 0.1), ColorRole = "Leaf" },
			{ Name = "MiddleBack", Size = Vector3.new(4.8, 2.8, 4.8), Position = Vector3.new(0.4, 10.4, 2.2), ColorRole = "Leaf" },
			{ Name = "UpperCanopy", Size = Vector3.new(5.1, 2.8, 5.0), Position = Vector3.new(0.1, 11.9, 0.1), ColorRole = "LeafHighlight" },
			{ Name = "Crown", Size = Vector3.new(3.8, 2.0, 3.8), Position = Vector3.new(0.1, 13.45, 0.2), ColorRole = "LeafHighlight" },
		},
		Branches = {
			{ Name = "BranchLeft", Size = Vector3.new(2.75, 0.68, 0.72), Position = Vector3.new(-1.4, 6.95, 0), ColorRole = "BarkHighlight" },
			{ Name = "BranchRight", Size = Vector3.new(2.75, 0.7, 0.72), Position = Vector3.new(1.4, 7.2, 0.15), ColorRole = "BarkHighlight" },
			{ Name = "BranchFront", Size = Vector3.new(0.72, 0.62, 2.45), Position = Vector3.new(-0.35, 6.9, -1.45), RotationY = -18, ColorRole = "Bark" },
			{ Name = "BranchBack", Size = Vector3.new(0.72, 0.62, 2.4), Position = Vector3.new(0.9, 7.6, 1.3), RotationY = 16, ColorRole = "BarkHighlight" },
		},
	},
	B = {
		Name = "Left-Heavy",
		Foliage = {
			{ Name = "LeftWingFront", Size = Vector3.new(4.8, 3.2, 4.6), Position = Vector3.new(3.8, 10.5, -1.5), ColorRole = "Leaf" },
			{ Name = "LeftWingBack", Size = Vector3.new(4.6, 3.4, 5.2), Position = Vector3.new(3.2, 11.3, 2.3), ColorRole = "Leaf" },
			{ Name = "LeftShoulder", Size = Vector3.new(4.8, 3.6, 4.6), Position = Vector3.new(2.5, 9.9, 0.1), ColorRole = "Leaf" },
			{ Name = "RightCounterFront", Size = Vector3.new(4.2, 3.0, 5.0), Position = Vector3.new(-2.4, 8.5, -1.8), ColorRole = "LeafShadow" },
			{ Name = "RightCounterBack", Size = Vector3.new(3.8, 3.0, 5.0), Position = Vector3.new(-2.3, 9.2, 2.1), ColorRole = "Leaf" },
			{ Name = "MiddleCore", Size = Vector3.new(5.8, 3.4, 5.6), Position = Vector3.new(0.65, 10.0, 0), ColorRole = "Leaf" },
			{ Name = "FrontCore", Size = Vector3.new(3.8, 2.6, 3.6), Position = Vector3.new(0.1, 8.6, -1.8), ColorRole = "Leaf" },
			{ Name = "UpperCanopy", Size = Vector3.new(4.8, 3.1, 4.8), Position = Vector3.new(0.5, 12.5, 0.1), ColorRole = "LeafHighlight" },
			{ Name = "Crown", Size = Vector3.new(3.6, 2.2, 3.8), Position = Vector3.new(0.2, 14.2, 0.2), ColorRole = "LeafHighlight" },
		},
		Branches = {
			{ Name = "BranchRightCounter", Size = Vector3.new(2.6, 0.68, 0.72), Position = Vector3.new(-1.4, 7.0, -0.2), ColorRole = "Bark" },
			{ Name = "BranchLeftFront", Size = Vector3.new(2.35, 0.7, 0.72), Position = Vector3.new(2.15, 7.85, -0.7), ColorRole = "BarkHighlight" },
			{ Name = "BranchLeftBack", Size = Vector3.new(2.2, 0.66, 0.72), Position = Vector3.new(2.0, 7.95, 1.15), ColorRole = "BarkHighlight" },
			{ Name = "BranchFront", Size = Vector3.new(0.72, 0.62, 2.6), Position = Vector3.new(0, 7.15, -1.4), RotationY = -15, ColorRole = "Bark" },
			{ Name = "BranchBack", Size = Vector3.new(0.72, 0.62, 2.7), Position = Vector3.new(-0.55, 7.65, 1.35), RotationY = 15, ColorRole = "BarkHighlight" },
		},
	},
	C = {
		Name = "Tall & Slim",
		Foliage = {
			{ Name = "LowerLeftFront", Size = Vector3.new(4.4, 2.8, 4.6), Position = Vector3.new(2.3, 8.3, -1.5), ColorRole = "Leaf" },
			{ Name = "LowerRightBack", Size = Vector3.new(4.8, 2.8, 5.8), Position = Vector3.new(-2.1, 8.35, 2.5), ColorRole = "LeafShadow" },
			{ Name = "MiddleLeftFront", Size = Vector3.new(4.4, 3.0, 4.0), Position = Vector3.new(1.6, 10.4, -1.0), ColorRole = "Leaf" },
			{ Name = "MiddleRightBack", Size = Vector3.new(4.4, 3.2, 4.2), Position = Vector3.new(-1.45, 10.7, 1.5), ColorRole = "Leaf" },
			{ Name = "MiddleCore", Size = Vector3.new(5.0, 3.0, 5.0), Position = Vector3.new(0, 9.8, 0), ColorRole = "Leaf" },
			{ Name = "UpperShoulder", Size = Vector3.new(4.8, 3.0, 4.8), Position = Vector3.new(0.4, 12.2, 0.2), ColorRole = "Leaf" },
			{ Name = "UpperLeft", Size = Vector3.new(3.6, 3.0, 4.2), Position = Vector3.new(-0.9, 13.5, -1.1), ColorRole = "Leaf" },
			{ Name = "UpperRight", Size = Vector3.new(3.8, 3.2, 4.0), Position = Vector3.new(1.15, 13.8, 1.2), ColorRole = "LeafHighlight" },
			{ Name = "Crown", Size = Vector3.new(3.0, 2.2, 3.4), Position = Vector3.new(0.15, 15.45, 0.2), ColorRole = "LeafHighlight" },
		},
		Branches = {
			{ Name = "BranchLeft", Size = Vector3.new(2.7, 0.64, 0.72), Position = Vector3.new(-1.4, 6.95, -0.1), ColorRole = "Bark" },
			{ Name = "BranchRight", Size = Vector3.new(2.6, 0.66, 0.72), Position = Vector3.new(1.4, 7.2, 0.1), ColorRole = "BarkHighlight" },
			{ Name = "BranchFront", Size = Vector3.new(0.72, 0.62, 2.35), Position = Vector3.new(0.15, 7.05, -1.35), RotationY = -16, ColorRole = "BarkHighlight" },
			{ Name = "BranchBack", Size = Vector3.new(0.72, 0.62, 2.35), Position = Vector3.new(0.45, 7.55, 1.25), RotationY = 18, ColorRole = "Bark" },
		},
	},
	D = {
		Name = "Wide Canopy",
		Foliage = {
			{ Name = "LeftWideFront", Size = Vector3.new(4.8, 3.2, 4.8), Position = Vector3.new(-4.2, 9.1, -1.7), ColorRole = "Leaf" },
			{ Name = "LeftWideBack", Size = Vector3.new(4.6, 3.2, 5.6), Position = Vector3.new(-4.0, 9.35, 2.1), ColorRole = "LeafShadow" },
			{ Name = "RightOuterFront", Size = Vector3.new(4.8, 3.6, 5.4), Position = Vector3.new(3.95, 11.1, -2.0), ColorRole = "Leaf" },
			{ Name = "RightOuterBack", Size = Vector3.new(4.8, 3.6, 5.6), Position = Vector3.new(3.0, 11.9, 2.55), ColorRole = "LeafHighlight" },
			{ Name = "LowerCore", Size = Vector3.new(6.0, 3.0, 5.6), Position = Vector3.new(0, 8.4, 0), ColorRole = "LeafShadow" },
			{ Name = "MiddleCore", Size = Vector3.new(6.6, 3.3, 6.0), Position = Vector3.new(0, 10.0, 0), ColorRole = "Leaf" },
			{ Name = "LeftMiddle", Size = Vector3.new(5.0, 3.2, 5.0), Position = Vector3.new(-2.7, 10.4, -0.1), ColorRole = "Leaf" },
			{ Name = "RightMiddleFront", Size = Vector3.new(4.8, 3.2, 4.6), Position = Vector3.new(2.6, 10.5, -1.5), ColorRole = "Leaf" },
			{ Name = "UpperCanopy", Size = Vector3.new(5.8, 3.4, 5.7), Position = Vector3.new(0.1, 12.5, 0.1), ColorRole = "LeafHighlight" },
			{ Name = "Crown", Size = Vector3.new(4.0, 2.4, 4.1), Position = Vector3.new(0, 14.4, 0.1), ColorRole = "LeafHighlight" },
		},
		Branches = {
			{ Name = "BranchLeft", Size = Vector3.new(2.8, 0.68, 0.72), Position = Vector3.new(-1.45, 6.9, -0.1), ColorRole = "Bark" },
			{ Name = "BranchRight", Size = Vector3.new(2.9, 0.7, 0.72), Position = Vector3.new(1.5, 7.25, 0.2), ColorRole = "BarkHighlight" },
			{ Name = "BranchFront", Size = Vector3.new(0.72, 0.62, 2.5), Position = Vector3.new(-0.1, 6.95, -1.45), RotationY = -20, ColorRole = "BarkHighlight" },
			{ Name = "BranchBack", Size = Vector3.new(0.72, 0.62, 2.35), Position = Vector3.new(0.4, 7.55, 1.4), RotationY = 18, ColorRole = "Bark" },
		},
	},
	E = {
		Name = "Sparse & Chunky",
		Foliage = {
			{ Name = "LowerLeftFront", Size = Vector3.new(4.4, 3.0, 4.8), Position = Vector3.new(-2.85, 8.55, -1.9), ColorRole = "Leaf" },
			{ Name = "LowerRightFront", Size = Vector3.new(4.0, 2.8, 4.4), Position = Vector3.new(2.2, 8.55, -1.3), ColorRole = "Leaf" },
			{ Name = "OuterRight", Size = Vector3.new(3.0, 3.2, 4.0), Position = Vector3.new(3.6, 10.4, 0.3), ColorRole = "LeafHighlight" },
			{ Name = "BackLeft", Size = Vector3.new(4.2, 3.0, 5.4), Position = Vector3.new(-2.5, 9.6, 2.4), ColorRole = "LeafShadow" },
			{ Name = "BackRight", Size = Vector3.new(3.6, 2.8, 4.8), Position = Vector3.new(2.3, 9.5, 2.0), ColorRole = "Leaf" },
			{ Name = "MiddleCore", Size = Vector3.new(4.8, 3.4, 4.8), Position = Vector3.new(0, 10.05, 0), ColorRole = "Leaf" },
			{ Name = "UpperLeft", Size = Vector3.new(3.8, 3.2, 4.4), Position = Vector3.new(-1.3, 12.2, -0.6), ColorRole = "Leaf" },
			{ Name = "UpperRight", Size = Vector3.new(3.7, 3.0, 4.0), Position = Vector3.new(1.2, 12.55, 1.0), ColorRole = "LeafHighlight" },
			{ Name = "Crown", Size = Vector3.new(3.0, 2.2, 3.4), Position = Vector3.new(0, 14.35, 0.1), ColorRole = "LeafHighlight" },
		},
		Branches = {
			{ Name = "BranchLeft", Size = Vector3.new(2.6, 0.66, 0.72), Position = Vector3.new(-1.35, 6.9, -0.15), ColorRole = "Bark" },
			{ Name = "BranchRight", Size = Vector3.new(2.9, 0.65, 0.72), Position = Vector3.new(1.35, 7.2, 0.1), ColorRole = "BarkHighlight" },
			{ Name = "BranchFront", Size = Vector3.new(0.72, 0.62, 2.3), Position = Vector3.new(0.8, 7.05, -1.3), RotationY = -15, ColorRole = "Bark" },
			{ Name = "BranchBack", Size = Vector3.new(0.72, 0.62, 2.3), Position = Vector3.new(0.8, 7.95, 1.3), RotationY = 20, ColorRole = "BarkHighlight" },
		},
	},
}

local STARTER_OAK_VARIANT_KEYS = { "A", "B", "C", "D", "E" }
-- The gallery harvest showcase uses the approved structural-study layout.
local STARTER_OAK_HARVEST_LAYOUT = "StructuralStudy"
local STARTER_OAK_HARVEST_LAYOUT_NAME = "Structural Study"

local function getStarterOakVariant(variantKey)
	local variant = STARTER_OAK_VARIANTS[variantKey]
	assert(variant, "Unknown Starter Oak gallery variant: " .. tostring(variantKey))
	return variant
end

local function starterOakVariantLabel(variantKey)
	return variantKey .. " — " .. getStarterOakVariant(variantKey).Name
end

local function starterOakVariantModelName(prefix, variantKey)
	local variant = getStarterOakVariant(variantKey)
	return prefix .. "_" .. variantKey .. "_" .. string.gsub(variant.Name, "%W+", "_")
end

local function addStarterOakCanopy(parent, palette, variantKey)
	local variant = getStarterOakVariant(variantKey)
	for _, definition in ipairs(variant.Foliage) do
		local color = palette[definition.ColorRole]
		assert(color, "Missing Oak palette role " .. definition.ColorRole)
		createStarterOakBlock(parent, definition.Name, definition.Size, definition.Position, color)
	end
end

local function addStarterOakBranches(parent, palette, variantKey)
	local variant = getStarterOakVariant(variantKey)
	for _, definition in ipairs(variant.Branches) do
		local color = palette[definition.ColorRole]
		assert(color, "Missing Oak palette role " .. definition.ColorRole)
		local branch = createStarterOakBlock(parent, definition.Name, definition.Size, definition.Position, color)
		if definition.RotationY then
			-- RotationY is authored in degrees to break up the cardinal branch cross.
			branch.CFrame = CFrame.new(definition.Position) * CFrame.Angles(0, math.rad(definition.RotationY), 0)
		end
	end
end

-- The common base, shared by all variants, remains the same harvestable
-- twelve-stud trunk. The deliberate support edges are: A (x=5.0, y=6.85),
-- B (6.2, 8.9), C (4.5, 6.9), D (6.35, 9.3), and E (5.1, 8.8).
-- Those are the first foliage contacts in the current 60–82 degree solver;
-- each layout's branches stay clear of the base at those angles.

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

-- Static previews and the harvest tree use these same authored layout tables.
-- The preview remains gallery-only: it creates no Tree instance, hitbox, rewards,
-- or harvesting registration.
local function makeStarterOakPrototype(variantKey)
	variantKey = variantKey or "A"
	local variant = getStarterOakVariant(variantKey)
	local palette = SpeciesVisuals.GetPalette("Oak")
	local model = Instance.new("Model")
	model.Name = starterOakVariantModelName("StarterOakPreview", variantKey)
	model:SetAttribute("DevTreeGalleryPreview", true)
	model:SetAttribute("VisualOnly", true)
	model:SetAttribute("PrototypeOnly", true)
	model:SetAttribute("SpeciesId", "Oak")
	model:SetAttribute("DesignDirection", "StarterOakFamily")
	model:SetAttribute("StarterOakVariant", variantKey)
	model:SetAttribute("StarterOakVariantName", variant.Name)
	model:SetAttribute("DevTreeGalleryLabel", starterOakVariantLabel(variantKey))

	local trunkGroup = Instance.new("Folder")
	trunkGroup.Name = "FutureHarvestTrunk"
	trunkGroup.Parent = model
	local branchGroup = Instance.new("Folder")
	branchGroup.Name = "DecorativeBranches"
	branchGroup.Parent = model
	local foliageGroup = Instance.new("Folder")
	foliageGroup.Name = "FoliageDecorations"
	foliageGroup.Parent = model

	local trunkCore
	for _, component in ipairs(getStarterOakTrunkComponents(palette)) do
		for _, definition in ipairs(component) do
			local part = createStarterOakBlock(trunkGroup, definition[1], definition[2], definition[3], definition[4])
			if definition[1] == "BaseCore" then trunkCore = part end
		end
	end
	model.PrimaryPart = trunkCore

	addStarterOakBranches(branchGroup, palette, variantKey)
	addStarterOakCanopy(foliageGroup, palette, variantKey)
	return model
end

local function makeFolder(parent, name)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- These gallery-only visuals are shared byte-for-byte by the static study and
-- harvest preview. Harvestable sections stay the original two authored 6-stud
-- components; bark, branches, and canopy are separate display decoration.
local function addStarterOakStructuralVisuals(model, palette, foliageFolderName)
	local bark = makeFolder(model, "DecorativeBark")
	local branches = makeFolder(model, "DecorativeBranches")
	local foliage = makeFolder(model, foliageFolderName)

	createStarterOakBlock(
		bark,
		"LowerDecorativeSleeve",
		Vector3.new(2.98, 6, 2.98),
		Vector3.new(0, 3, 0),
		palette.Bark
	)
	createStarterOakBlock(
		bark,
		"RootFoot",
		Vector3.new(3.6, 1.4, 3.6),
		Vector3.new(0, 0.7, 0),
		palette.BarkShadow
	)

	-- Keep the original section faces untouched. These two small overlays preserve
	-- the approved study's warm and shadow accents on the wider sleeve.
	local baseDefinitions = getStarterOakTrunkComponents(palette)[1]
	local warmFace, shadowFace = baseDefinitions[2], baseDefinitions[3]
	createStarterOakBlock(
		bark,
		"LowerWarmAccent",
		warmFace[2],
		warmFace[3] + Vector3.new(-0.40, 0, 0),
		warmFace[4]
	)
	createStarterOakBlock(
		bark,
		"LowerShadowAccent",
		shadowFace[2],
		shadowFace[3] + Vector3.new(0, 0, 0.40),
		shadowFace[4]
	)

	for _, definition in ipairs({
		{ "BranchLeft", Vector3.new(3.45, 0.62, 0.78), Vector3.new(-1.65, 7.58, 0), palette.BarkHighlight },
		{ "BranchRight", Vector3.new(3.35, 0.62, 0.78), Vector3.new(1.62, 7.62, 0.15), palette.Bark },
		{ "BranchFront", Vector3.new(0.78, 0.58, 3.05), Vector3.new(-0.15, 7.58, -1.48), palette.Bark },
		{ "BranchBack", Vector3.new(0.78, 0.58, 2.85), Vector3.new(0.2, 7.62, 1.38), palette.BarkHighlight },
	}) do
		createStarterOakBlock(branches, definition[1], definition[2], definition[3], definition[4])
	end

	for _, definition in ipairs({
		{ "LowerCanopyCore", Vector3.new(8.0, 3.0, 7.2), Vector3.new(0, 9.2, 0), "Leaf" },
		{ "LowerFrontLeft", Vector3.new(5.6, 2.8, 5.0), Vector3.new(-3.2, 9.0, -1.85), "LeafHighlight" },
		{ "LowerBackRight", Vector3.new(5.8, 3.0, 5.2), Vector3.new(3.1, 9.35, 1.9), "LeafShadow" },
		{ "LowerFrontRight", Vector3.new(5.0, 2.6, 4.6), Vector3.new(3.0, 9.2, -1.9), "Leaf" },
		{ "LowerBackLeft", Vector3.new(5.0, 2.7, 5.0), Vector3.new(-3.0, 9.35, 1.95), "LeafHighlight" },

		{ "MiddleCanopyCore", Vector3.new(7.5, 3.2, 6.6), Vector3.new(0.1, 11.4, 0), "Leaf" },
		{ "MiddleLeftBack", Vector3.new(5.2, 2.8, 4.8), Vector3.new(-3.0, 11.55, 2.0), "LeafShadow" },
		{ "MiddleRightFront", Vector3.new(5.2, 2.7, 4.8), Vector3.new(3.1, 11.5, -2.0), "LeafHighlight" },
		{ "MiddleRightBack", Vector3.new(4.6, 2.6, 4.5), Vector3.new(2.8, 11.25, 2.15), "Leaf" },
		{ "MiddleLeftFront", Vector3.new(4.8, 2.7, 4.6), Vector3.new(-2.8, 11.2, -2.1), "LeafHighlight" },

		{ "UpperCanopyCore", Vector3.new(6.5, 3.0, 6.2), Vector3.new(0, 14.0, 0), "Leaf" },
		{ "UpperLeftBack", Vector3.new(4.6, 2.5, 4.7), Vector3.new(-1.5, 14.0, 1.7), "Leaf" },
		{ "UpperRightFront", Vector3.new(4.8, 2.6, 4.5), Vector3.new(1.6, 14.1, -1.6), "LeafHighlight" },
		{ "Crown", Vector3.new(4.0, 2.2, 3.8), Vector3.new(0.2, 16.0, 0.2), "Leaf" },
	}) do
		local color = palette[definition[4]]
		assert(color, "Missing Oak palette role " .. definition[4])
		createStarterOakBlock(foliage, definition[1], definition[2], definition[3], color)
	end

	return bark, branches, foliage
end

-- Gallery-only static counterpart of the harvest preview. The two section
-- models use the same authored component definitions as the harvest tree.
local function makeStarterOakStructuralStudy()
	local palette = SpeciesVisuals.GetPalette("Oak")
	local model = Instance.new("Model")
	model.Name = "StarterOakStructuralStudy"
	model:SetAttribute("DevTreeGalleryPreview", true)
	model:SetAttribute("VisualOnly", true)
	model:SetAttribute("PrototypeOnly", true)
	model:SetAttribute("SpeciesId", "Oak")
	model:SetAttribute("DesignDirection", "StarterOakStructuralStudy")
	model:SetAttribute("StarterOakVariant", STARTER_OAK_HARVEST_LAYOUT)
	model:SetAttribute("StarterOakVariantName", STARTER_OAK_HARVEST_LAYOUT_NAME)
	model:SetAttribute("StarterOakLayout", STARTER_OAK_HARVEST_LAYOUT)
	model:SetAttribute("VisualTrunkLength", 12)
	model:SetAttribute("VisualTrunkSectionCount", 2)
	model:SetAttribute("DevTreeGalleryLabel", "Starter Oak Structural Study")

	local trunk = makeFolder(model, "TrunkStructure")
	local baseCore
	for sectionIndex, component in ipairs(getStarterOakTrunkComponents(palette)) do
		local section = Instance.new("Model")
		section.Name = "Section" .. sectionIndex
		section:SetAttribute("AuthoredHarvestSection", true)
		section:SetAttribute("HarvestSectionIndex", sectionIndex)
		section.Parent = trunk
		for _, definition in ipairs(component) do
			local part = createStarterOakBlock(section, definition[1], definition[2], definition[3], definition[4])
			if definition[1] == "BaseCore" then
				part.PivotOffset = CFrame.new(0, -3, 0)
				section.PrimaryPart = part
				baseCore = part
			elseif definition[1] == "TopCore" then
				section.PrimaryPart = part
			end
		end
	end
	assert(baseCore, "Starter Oak structural study is missing its base core")
	model.PrimaryPart = baseCore

	addStarterOakStructuralVisuals(model, palette, "LayeredFoliage")
	return model
end

local STARTER_OAK_NORMALIZED_LOG_LENGTH = 7
local STARTER_OAK_NORMALIZED_LOG_DIAMETER = 1.8
local STARTER_OAK_NORMALIZED_LOG_BODY_DIAMETER = STARTER_OAK_NORMALIZED_LOG_DIAMETER - 0.02

-- Gallery-only harvest tree. Its authored trunk sections and structural-study
-- decorations match makeStarterOakStructuralStudy exactly.
local function makeStarterOakHarvestTree(sectionCount)
	local rangesByYield = {
		[1] = { { 1, 2 } },
		[2] = { { 1, 1 }, { 2, 2 } },
	}
	local ranges = rangesByYield[sectionCount]
	assert(ranges, "Starter Oak supports only 1 or 2 harvest sections")

	local palette = SpeciesVisuals.GetPalette("Oak")
	local model = Instance.new("Model")
	-- The client bridge depends on this exact name; the selected layout is in attributes.
	model.Name = "StarterOakHarvestTree"
	model:SetAttribute("DevTreeGalleryPreview", true)
	model:SetAttribute("VisualOnly", true)
	model:SetAttribute("PrototypeOnly", true)
	model:SetAttribute("SpeciesId", "Oak")
	model:SetAttribute("SupportedHarvestYields", "1,2")
	model:SetAttribute("HarvestYieldPreview", sectionCount)
	model:SetAttribute("StarterOakVariant", STARTER_OAK_HARVEST_LAYOUT)
	model:SetAttribute("StarterOakVariantName", STARTER_OAK_HARVEST_LAYOUT_NAME)
	model:SetAttribute("StarterOakLayout", STARTER_OAK_HARVEST_LAYOUT)
	model:SetAttribute("DesignDirection", "StarterOakStructuralStudy")
	model:SetAttribute("DevTreeGalleryLabel", "Starter Oak " .. STARTER_OAK_HARVEST_LAYOUT_NAME)

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

	addStarterOakStructuralVisuals(model, palette, "FoliageDecorations")

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
	model:SetAttribute("DevTreeGalleryLabel", label)
	return {
		Kind = model.Name,
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

local function makeProceduralStarterOakEntry(seed, extreme)
	local model = DevStarterOakGenerator.Generate(seed, { Extreme = extreme })
	assert(model and model:IsA("Model"), "Starter Oak generator returned no Model for seed " .. tostring(seed))
	configureVisualOnlyModel(model)
	model:SetAttribute("DevTreeGalleryPreview", true)
	model:SetAttribute("VisualOnly", true)
	model:SetAttribute("PrototypeOnly", true)
	model:SetAttribute("SpeciesId", "Oak")
	model:SetAttribute("DesignDirection", "ProceduralStarterOak")
	model:SetAttribute("DevTreeGallerySeed", seed)
	model:SetAttribute("DevTreeGalleryExtreme", extreme)
	local label = "SEED " .. tostring(seed) .. " | " .. (extreme and "EXTREME" or "NORMAL")
	model:SetAttribute("DevTreeGalleryLabel", label)

	local _, bounds = model:GetBoundingBox()
	return {
		Kind = "ProceduralStarterOak",
		Label = label,
		Model = model,
		PlatformSize = Vector3.new(
			math.max(MIN_PLATFORM_SIZE, bounds.X + PLATFORM_PADDING),
			1,
			math.max(MIN_PLATFORM_SIZE, bounds.Z + PLATFORM_PADDING)
		),
	}
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
	tree:SetAttribute("ExpectedAuthoredSectionCount", 3)
	tree.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
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
	playground:SetAttribute("StarterOakVariant", STARTER_OAK_HARVEST_LAYOUT)
	playground:SetAttribute("StarterOakVariantName", STARTER_OAK_HARVEST_LAYOUT_NAME)
	playground:SetAttribute("StarterOakLayout", STARTER_OAK_HARVEST_LAYOUT)
	playground:SetAttribute("DesignDirection", "StarterOakStructuralStudy")
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
	tree:SetAttribute("ExpectedAuthoredSectionCount", STARTER_OAK_HARVEST_SHOWCASE_YIELD)
	tree.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
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
	prompt.ObjectText = "Starter Oak " .. STARTER_OAK_HARVEST_LAYOUT_NAME
		.. " (" .. STARTER_OAK_HARVEST_SHOWCASE_YIELD
		.. (STARTER_OAK_HARVEST_SHOWCASE_YIELD == 1 and " log)" or " logs)")
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("DevTreeGalleryTransformationPrompt", true)
	prompt.Parent = demoSlot
end

local function isAcceptableProceduralStarterOakSection(sectionLength, thickness)
	return sectionLength >= PROCEDURAL_STARTER_OAK_HARVEST.MinimumSectionLength
		and thickness > 0
		and sectionLength / thickness
			>= PROCEDURAL_STARTER_OAK_HARVEST.MinimumLengthToThicknessRatio
end

local function chooseProceduralStarterOakHarvestSectionCount(coreHeight, baseThickness)
	local twoSectionLength = coreHeight * 0.5
	if isAcceptableProceduralStarterOakSection(twoSectionLength, baseThickness) then
		return 2, "Both generated halves meet the configured minimum length and length-to-thickness ratio"
	end
	if isAcceptableProceduralStarterOakSection(coreHeight, baseThickness) then
		return 1, "Two halves fail the configured limits; the full generated trunk meets them"
	end
	return 0, string.format(
		"Full generated trunk is too short or too thick (length %.2f, base thickness %.2f; requires length >= %.2f and ratio >= %.2f)",
		coreHeight,
		baseThickness,
		PROCEDURAL_STARTER_OAK_HARVEST.MinimumSectionLength,
		PROCEDURAL_STARTER_OAK_HARVEST.MinimumLengthToThicknessRatio
	)
end

local function measureProceduralStarterOakCanopyAsymmetry(tree)
	local foliage = tree:FindFirstChild("FoliageDecorations")
	if not foliage then return 0, 0 end

	local treePivot = tree:GetPivot()
	local weightedX, weightedZ, totalWeight = 0, 0, 0
	local positiveXWeight, negativeXWeight = 0, 0
	local positiveZWeight, negativeZWeight = 0, 0
	local canopyRadius = 0
	local centerDeadZone = (tree:GetAttribute("TrunkThickness") or 1) * 0.15
	for _, descendant in ipairs(foliage:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local localPosition = treePivot:PointToObjectSpace(descendant.Position)
			local weight = math.max(0.001, descendant.Size.X * descendant.Size.Y * descendant.Size.Z)
			weightedX += localPosition.X * weight
			weightedZ += localPosition.Z * weight
			totalWeight += weight
			if localPosition.X > centerDeadZone then
				positiveXWeight += weight
			elseif localPosition.X < -centerDeadZone then
				negativeXWeight += weight
			else
				positiveXWeight += weight * 0.5
				negativeXWeight += weight * 0.5
			end
			if localPosition.Z > centerDeadZone then
				positiveZWeight += weight
			elseif localPosition.Z < -centerDeadZone then
				negativeZWeight += weight
			else
				positiveZWeight += weight * 0.5
				negativeZWeight += weight * 0.5
			end
			local partRadius = Vector2.new(localPosition.X, localPosition.Z).Magnitude
				+ Vector2.new(descendant.Size.X, descendant.Size.Z).Magnitude * 0.5
			canopyRadius = math.max(canopyRadius, partRadius)
		end
	end

	if totalWeight <= 0 then return 0, 0 end
	local centroidOffset = Vector2.new(weightedX / totalWeight, weightedZ / totalWeight).Magnitude
	local xImbalance = math.abs(positiveXWeight - negativeXWeight) / totalWeight
	local zImbalance = math.abs(positiveZWeight - negativeZWeight) / totalWeight
	local asymmetryRatio = math.max(
		centroidOffset / math.max(canopyRadius, 0.001),
		xImbalance,
		zImbalance
	)
	return centroidOffset, asymmetryRatio
end

local function matchesProceduralStarterOakSample(tree, sample, asymmetryRatio)
	local isExtreme = tree:GetAttribute("Extreme") == true
	if isExtreme ~= sample.Extreme then return false end

	local coreHeight = tree:GetAttribute("CoreHeight")
	if type(coreHeight) ~= "number" then return false end
	if sample.MinimumCoreHeight and coreHeight < sample.MinimumCoreHeight then return false end
	if sample.MaximumCoreHeight and coreHeight > sample.MaximumCoreHeight then return false end
	if sample.MinimumCanopyAsymmetryRatio
		and asymmetryRatio < sample.MinimumCanopyAsymmetryRatio then
		return false
	end
	return true
end

local function proceduralStarterOakSeedAt(startSeed, offset)
	local seedCount = PROCEDURAL_STARTER_OAK_MAX_SEED - PROCEDURAL_STARTER_OAK_MIN_SEED + 1
	return PROCEDURAL_STARTER_OAK_MIN_SEED
		+ ((startSeed - PROCEDURAL_STARTER_OAK_MIN_SEED + offset) % seedCount)
end

local function makeProceduralStarterOakSampleData(tree, sample, seed, searchAttempts, customSeed)
	local coreHeight = tree:GetAttribute("CoreHeight") or 0
	local baseThickness = tree:GetAttribute("TrunkThickness") or 0
	local canopyOffset, canopyAsymmetryRatio = measureProceduralStarterOakCanopyAsymmetry(tree)
	local sectionCount, sectionReason = chooseProceduralStarterOakHarvestSectionCount(coreHeight, baseThickness)
	local categoryMatched = not customSeed
		and matchesProceduralStarterOakSample(tree, sample, canopyAsymmetryRatio)
	local sectionCountMatched = customSeed
		or not sample.RequiredHarvestSectionCount
		or sectionCount == sample.RequiredHarvestSectionCount
	local profileMatched = if customSeed
		then sectionCount > 0
		else categoryMatched and sectionCountMatched
	return {
		Tree = tree,
		Key = sample.Key,
		Seed = seed,
		CoreHeight = coreHeight,
		BaseThickness = baseThickness,
		TopThickness = tree:GetAttribute("TopThickness") or baseThickness,
		TaperRatio = tree:GetAttribute("TaperRatio") or 1,
		CanopyCentroidOffset = canopyOffset,
		CanopyAsymmetryRatio = canopyAsymmetryRatio,
		SectionCount = sectionCount,
		SectionReason = sectionReason,
		CategoryMatched = categoryMatched,
		ProfileMatched = profileMatched,
		SectionCountMatched = sectionCountMatched,
		CustomSeed = customSeed,
		SearchAttempts = searchAttempts,
	}
end

local function findProceduralStarterOakHarvestSample(sample, usedSeeds)
	local seedToValidate = if sample.ExactSeed ~= nil then sample.ExactSeed else sample.Seed
	assert(
		type(seedToValidate) == "number"
			and seedToValidate % 1 == 0
			and seedToValidate >= PROCEDURAL_STARTER_OAK_MIN_SEED
			and seedToValidate <= PROCEDURAL_STARTER_OAK_MAX_SEED,
		"Procedural Starter Oak sample " .. sample.Key .. " needs an integer seed in generator range"
	)
	if sample.ExactSeed ~= nil then
		local exactTree = DevStarterOakGenerator.Generate(sample.ExactSeed, { Extreme = sample.Extreme })
		return makeProceduralStarterOakSampleData(exactTree, sample, sample.ExactSeed, 1, true)
	end

	local fallbackInvalidProfile
	local fallbackSectionCountMismatch
	local fallbackFirst
	for offset = 0, PROCEDURAL_STARTER_OAK_HARVEST.SeedSearchCandidates - 1 do
		local seed = proceduralStarterOakSeedAt(sample.Seed, offset)
		if not usedSeeds[seed] then
			local tree = DevStarterOakGenerator.Generate(seed, { Extreme = sample.Extreme })
			local result = makeProceduralStarterOakSampleData(tree, sample, seed, offset + 1, false)
			local categoryMatched = result.CategoryMatched
			local sectionCount = result.SectionCount
			local sectionCountMatched = result.SectionCountMatched
			local profileMatched = result.ProfileMatched

			if profileMatched and sectionCountMatched and sectionCount > 0 then
				if fallbackFirst and fallbackFirst.Tree ~= result.Tree then fallbackFirst.Tree:Destroy() end
				if fallbackInvalidProfile and fallbackInvalidProfile.Tree ~= result.Tree then fallbackInvalidProfile.Tree:Destroy() end
				if fallbackSectionCountMismatch and fallbackSectionCountMismatch.Tree ~= result.Tree then
					fallbackSectionCountMismatch.Tree:Destroy()
				end
				return result
			end

			if categoryMatched and sectionCount == 0 then
				if not fallbackInvalidProfile then
					fallbackInvalidProfile = result
					if fallbackFirst and fallbackFirst.Tree ~= result.Tree then
						fallbackFirst.Tree:Destroy()
						fallbackFirst = nil
					end
					if fallbackSectionCountMismatch and fallbackSectionCountMismatch.Tree ~= result.Tree then
						fallbackSectionCountMismatch.Tree:Destroy()
						fallbackSectionCountMismatch = nil
					end
				else
					result.Tree:Destroy()
				end
			elseif categoryMatched and sectionCount > 0 and not sectionCountMatched then
				if not fallbackSectionCountMismatch then
					fallbackSectionCountMismatch = result
					if fallbackFirst and fallbackFirst.Tree ~= result.Tree then
						fallbackFirst.Tree:Destroy()
						fallbackFirst = nil
					end
				else
					result.Tree:Destroy()
				end
			elseif not fallbackFirst then
				fallbackFirst = result
			else
				result.Tree:Destroy()
			end
		end
	end

	local fallback = fallbackInvalidProfile or fallbackSectionCountMismatch or fallbackFirst
	if fallback then
		if fallbackFirst and fallbackFirst.Tree ~= fallback.Tree then fallbackFirst.Tree:Destroy() end
		if fallbackSectionCountMismatch and fallbackSectionCountMismatch.Tree ~= fallback.Tree then
			fallbackSectionCountMismatch.Tree:Destroy()
		end
		if fallbackInvalidProfile and fallbackInvalidProfile.Tree ~= fallback.Tree then
			fallbackInvalidProfile.Tree:Destroy()
		end
		fallback.SearchAttempts = PROCEDURAL_STARTER_OAK_HARVEST.SeedSearchCandidates
		if not fallback.ProfileMatched then
			warn(string.format(
				"[DevTreeGallery] No seed in %d candidates fully matched sample %s (categoryMatched=%s, sectionCount=%d, sectionCountMatched=%s); showing a disabled diagnostic tree",
				PROCEDURAL_STARTER_OAK_HARVEST.SeedSearchCandidates,
				sample.Key,
				tostring(fallback.CategoryMatched),
				fallback.SectionCount,
				tostring(fallback.SectionCountMatched)
			))
		end
		return fallback
	end
	warn(string.format(
		"[DevTreeGallery] No unused seed candidate was available for sample %s; the configured sample will be skipped",
		sample.Key
	))
	return nil
end

local function annotateProceduralStarterOakSection(section, sectionIndex, fullCoreHeight)
	local sectionLength = section:GetAttribute("CoreHeight") or 0
	local sectionThickness = section:GetAttribute("CoreThickness") or 0
	section:SetAttribute("AuthoredHarvestSection", true)
	section:SetAttribute("HarvestSectionIndex", sectionIndex)
	section:SetAttribute("SourceCoreHeight", fullCoreHeight)
	section:SetAttribute("SourceSectionLength", sectionLength)
	section:SetAttribute("SourceSectionThickness", sectionThickness)
	section.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
end

local function adaptProceduralStarterOakHarvestHierarchy(tree, sampleData)
	local trunkStructure = tree:FindFirstChild("TrunkStructure")
	local sourceFolder = trunkStructure and trunkStructure:FindFirstChild("HarvestableCore")
	assert(sourceFolder, "Generated Starter Oak is missing TrunkStructure/HarvestableCore")
	local authoredSections = {}
	for _, child in ipairs(sourceFolder:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("AuthoredHarvestSection") == true then
			table.insert(authoredSections, child)
		end
	end
	table.sort(authoredSections, function(a, b)
			return (a:GetAttribute("HarvestSectionIndex") or math.huge)
				< (b:GetAttribute("HarvestSectionIndex") or math.huge)
		end)
	assert(#authoredSections == 2, "Generated Starter Oak must retain its two authored source sections")

	sourceFolder.Name = "StarterOakHarvestSections"
	sourceFolder.Parent = tree
	local sectionFolder = sourceFolder
	local harvestSectionCount = sampleData.SectionCount
	if harvestSectionCount == 2 then
		for index, section in ipairs(authoredSections) do
			annotateProceduralStarterOakSection(section, index, sampleData.CoreHeight)
		end
	elseif harvestSectionCount == 1 then
		local mergedSection = Instance.new("Model")
		mergedSection.Name = "Section1"
		mergedSection:SetAttribute("AuthoredHarvestSection", true)
		mergedSection:SetAttribute("HarvestSectionIndex", 1)
		mergedSection:SetAttribute("CoreBottomY", 0)
		mergedSection:SetAttribute("CoreTopY", sampleData.CoreHeight)
		mergedSection:SetAttribute("CoreHeight", sampleData.CoreHeight)
		mergedSection:SetAttribute("CoreThickness", sampleData.BaseThickness)
		mergedSection:SetAttribute("MergedGeneratedSections", true)
		mergedSection.Parent = sectionFolder
		for index, section in ipairs(authoredSections) do
			section.Name = "SourceAuthoredSection" .. index
			section.Parent = mergedSection
		end
		mergedSection.PrimaryPart = authoredSections[1].PrimaryPart
		annotateProceduralStarterOakSection(mergedSection, 1, sampleData.CoreHeight)
	elseif harvestSectionCount == 0 then
		-- Keep the generated visual intact for inspection, but do not present its
		-- two source halves as collectible logs when neither satisfies policy.
		for index, section in ipairs(authoredSections) do
			section:SetAttribute("DisplayOnlyUnacceptableSection", true)
			annotateProceduralStarterOakSection(section, index, sampleData.CoreHeight)
		end
	else
		error("Unsupported procedural Starter Oak harvest section count " .. tostring(harvestSectionCount))
	end

	tree:SetAttribute("GeneratedStarterOak", true)
	tree:SetAttribute("SourceTreeSeed", sampleData.Seed)
	tree:SetAttribute("DevTreeGallerySeed", sampleData.Seed)
	tree:SetAttribute("DevTreeGalleryExtreme", tree:GetAttribute("Extreme") == true)
	tree:SetAttribute("DevTreeGalleryHarvestSample", sampleData.Key)
	tree:SetAttribute("DevTreeGalleryCustomSeed", sampleData.CustomSeed)
	tree:SetAttribute("HarvestSectionCount", harvestSectionCount)
	tree:SetAttribute("HarvestSectionValid", harvestSectionCount > 0)
	tree:SetAttribute("HarvestSectionInvalidReason", if harvestSectionCount == 0 then sampleData.SectionReason else "")
	tree:SetAttribute("HarvestSectionSelectionReason", sampleData.SectionReason)
	tree:SetAttribute("SourceCoreHeight", sampleData.CoreHeight)
	tree:SetAttribute("SourceBaseThickness", sampleData.BaseThickness)
	tree:SetAttribute("HarvestMinimumSectionLength", PROCEDURAL_STARTER_OAK_HARVEST.MinimumSectionLength)
	tree:SetAttribute(
		"HarvestMinimumLengthToThicknessRatio",
		PROCEDURAL_STARTER_OAK_HARVEST.MinimumLengthToThicknessRatio
	)
	tree:SetAttribute("CanopyCentroidOffset", sampleData.CanopyCentroidOffset)
	tree:SetAttribute("CanopyAsymmetryRatio", sampleData.CanopyAsymmetryRatio)
	tree:SetAttribute("HarvestSampleCategoryMatched", sampleData.CategoryMatched)
	tree:SetAttribute("HarvestSampleProfileMatched", sampleData.ProfileMatched)
	tree:SetAttribute("HarvestSampleSectionCountMatched", sampleData.SectionCountMatched)
	tree:SetAttribute("HarvestShowcaseReady", sampleData.ProfileMatched and harvestSectionCount > 0)
	tree:SetAttribute("HarvestSeedSearchAttempts", sampleData.SearchAttempts)
	tree:SetAttribute("HarvestYieldPreview", harvestSectionCount)
	tree:SetAttribute("SupportedHarvestYields", "1,2")

	return sectionFolder
end

local function makeProceduralStarterOakNormalizedLogTemplate(sectionIndex, sourceTree, sourceSection, sectionCount)
	local palette = SpeciesVisuals.GetPalette("Oak")
	local length = STARTER_OAK_NORMALIZED_LOG_LENGTH
	local diameter = STARTER_OAK_NORMALIZED_LOG_DIAMETER
	local bodyDiameter = STARTER_OAK_NORMALIZED_LOG_BODY_DIAMETER
	local sourceLength = sourceSection:GetAttribute("SourceSectionLength") or sourceSection:GetAttribute("CoreHeight") or 0
	local sourceThickness = sourceSection:GetAttribute("SourceSectionThickness") or sourceSection:GetAttribute("CoreThickness") or 0
	local core = sourceSection.PrimaryPart
	assert(core and core:IsA("BasePart"), "Procedural harvest section " .. sectionIndex .. " has no source core")
	assert(sourceLength > 0 and sourceThickness > 0, "Procedural harvest section has invalid source dimensions")

	local model = Instance.new("Model")
	model.Name = "ProceduralStarterOakNormalizedLog" .. sectionIndex
	model:SetAttribute("DevTreeGalleryPreview", true)
	model:SetAttribute("VisualOnly", true)
	model:SetAttribute("PrototypeOnly", true)
	model:SetAttribute("SpeciesId", "Oak")
	model:SetAttribute("GeneratedStarterOak", true)
	model:SetAttribute("NormalizedFromSection", sectionIndex)
	model:SetAttribute("NormalizedOuterLength", length)
	model:SetAttribute("NormalizedOuterDiameter", diameter)
	model:SetAttribute("SourceTreeSeed", sourceTree:GetAttribute("SourceTreeSeed"))
	model:SetAttribute("SourceSectionLength", sourceLength)
	model:SetAttribute("SourceSectionThickness", sourceThickness)
	model:SetAttribute("NormalizationLengthScale", length / sourceLength)
	model:SetAttribute("NormalizationDiameterScale", diameter / sourceThickness)

	local handle = createStarterOakBlock(
		model,
		"LogHandle",
		Vector3.new(length, bodyDiameter, bodyDiameter),
		Vector3.zero,
		core.Color
	)
	handle.Material = core.Material
	model.PrimaryPart = handle
	createStarterOakBlock(
		model,
		"CutEndLeft",
		Vector3.new(0.18, diameter * 0.82, diameter * 0.82),
		Vector3.new(-length * 0.5 + 0.09, 0, 0),
		palette.CutEnd
	)
	createStarterOakBlock(
		model,
		"CutEndRight",
		Vector3.new(0.18, diameter * 0.82, diameter * 0.82),
		Vector3.new(length * 0.5 - 0.09, 0, 0),
		palette.CutEnd
	)

	local barkFolder = sourceTree:FindFirstChild("DecorativeBark")
	local sourcePivot = sourceSection:GetPivot()
	local accentsCreated = 0
	if barkFolder then
		for _, sourceAccent in ipairs(barkFolder:GetChildren()) do
			if sourceAccent:IsA("BasePart") then
				local authoredIndex = sourceAccent:GetAttribute("CoreSectionIndex")
				local isWarmAccent = string.find(sourceAccent.Name, "WarmBarkAccent", 1, true) ~= nil
				local isShadowAccent = string.find(sourceAccent.Name, "RecessedBarkAccent", 1, true) ~= nil
				local belongsToSection = (isWarmAccent or isShadowAccent)
					and (sectionCount == 1 or authoredIndex == sectionIndex)
				if belongsToSection then
					local localPosition = sourcePivot:PointToObjectSpace(sourceAccent.Position)
					local alongLength = math.clamp(sourceAccent.Size.Y / sourceLength * length, 0.3, length * 0.78)
					local positionX = math.clamp(
						(localPosition.Y / sourceLength - 0.5) * length,
						-(length - alongLength) * 0.5,
						(length - alongLength) * 0.5
					)
					local accentCrossScale = math.clamp(
						(sourceAccent.Size.X / sourceThickness) * diameter,
						0.08,
						diameter * 0.64
					)
					local accent
					if isWarmAccent then
						local accentDepth = math.clamp(
							sourceAccent.Size.Z / sourceThickness * diameter,
							0.04,
							0.12
						)
						accent = createStarterOakBlock(
							model,
							"TreeDerivedWarmBark" .. tostring(authoredIndex),
							Vector3.new(alongLength, accentCrossScale, accentDepth),
							Vector3.new(positionX, 0, -diameter * 0.5 + accentDepth * 0.5),
							sourceAccent.Color
						)
					else
						local accentDepth = math.clamp(
							sourceAccent.Size.X / sourceThickness * diameter,
							0.04,
							0.12
						)
						local sideCrossScale = math.clamp(
							(sourceAccent.Size.Z / sourceThickness) * diameter,
							0.08,
							diameter * 0.64
						)
						accent = createStarterOakBlock(
							model,
							"TreeDerivedShadowBark" .. tostring(authoredIndex),
							Vector3.new(alongLength, accentDepth, sideCrossScale),
							Vector3.new(positionX, diameter * 0.5 - accentDepth * 0.5, 0),
							sourceAccent.Color
						)
					end
					accent.Material = sourceAccent.Material
					accentsCreated += 1
				end
			end
		end
	end
	model:SetAttribute("TreeDerivedBarkAccentCount", accentsCreated)
	if accentsCreated == 0 then
		-- Keep a recognizable bark surface even if a future generator version
		-- omits the decorative strips; colors still come from the generated core.
		createStarterOakBlock(
			model,
			"TreeDerivedWarmBarkFallback",
			Vector3.new(length * 0.52, 0.08, diameter * 0.08),
			Vector3.new(-0.1, diameter * 0.5 - 0.04, 0),
			core.Color:Lerp(palette.BarkHighlight, 0.45)
		)
	end

	if length / sourceLength > 2 or sourceLength / length > 2
		or diameter / sourceThickness > 2 or sourceThickness / diameter > 2 then
		model:SetAttribute("NormalizationScaleWarning", true)
		warn(string.format(
			"[DevTreeGallery] Severe normalization scale for seed %s section %d (source %.2f x %.2f, standardized %.2f x %.2f)",
			tostring(sourceTree:GetAttribute("SourceTreeSeed")),
			sectionIndex,
			sourceLength,
			sourceThickness,
			length,
			diameter
		))
	else
		model:SetAttribute("NormalizationScaleWarning", false)
	end
	return model
end

local function addProceduralStarterOakHarvestShowcase(gallery)
	local config = PROCEDURAL_STARTER_OAK_HARVEST
	local sampleCount = #config.Samples
	local totalWidth = sampleCount * config.StageWidth + (sampleCount - 1) * config.StageGap
	local firstStageX = GALLERY_ORIGIN.X + (GALLERY_FLOOR_SIZE.X - totalWidth) * 0.5 + config.StageWidth * 0.5
	local rowCenterX = GALLERY_ORIGIN.X + GALLERY_FLOOR_SIZE.X * 0.5
	local rowCenterZ = GALLERY_ORIGIN.Z + config.StageCenterZ
	local area = Instance.new("Folder")
	area.Name = "ProceduralStarterOakHarvestArea"
	area:SetAttribute("DevOnly", true)
	area:SetAttribute("VisualOnly", true)
	area.Parent = gallery

	addSign(
		gallery,
		"PROCEDURAL STARTER OAK HARVEST — SEEDED GEOMETRY TESTS",
		Vector3.new(rowCenterX, 0, rowCenterZ - config.StageDepth * 0.5 - 21),
		math.min(totalWidth - 8, 68),
		"ProceduralStarterOakHarvestHeader"
	)

	local usedSeeds = {}
	local firstDemoSlot
	for sampleIndex, sample in ipairs(config.Samples) do
		local sampleData = findProceduralStarterOakHarvestSample(sample, usedSeeds)
		local stageCenterX = firstStageX + (sampleIndex - 1) * (config.StageWidth + config.StageGap)
		local stageCenter = Vector3.new(stageCenterX, GALLERY_ORIGIN.Y, rowCenterZ)
		if not sampleData then
			local skippedPlayground = Instance.new("Folder")
			skippedPlayground.Name = "ProceduralStarterOakHarvestPlayground_" .. sample.Key
			skippedPlayground:SetAttribute("DevOnly", true)
			skippedPlayground:SetAttribute("VisualOnly", true)
			skippedPlayground:SetAttribute("HarvestSampleSkipped", true)
			skippedPlayground.Parent = area
			addPlatform(skippedPlayground, "ShowcaseStage",
				Vector3.new(stageCenter.X, GALLERY_ORIGIN.Y - 0.5, stageCenter.Z),
				Vector3.new(config.StageWidth, 1, config.StageDepth))
			addSign(gallery, sample.Label .. " | SAMPLE SKIPPED: NO UNUSED SEED CANDIDATE",
				Vector3.new(stageCenter.X, 0, stageCenter.Z - config.StageDepth * 0.5 - 2),
				config.StageWidth - 2, "ProceduralStarterOakHarvestSample" .. sampleIndex)
			continue
		end
		usedSeeds[sampleData.Seed] = true
		local tree = sampleData.Tree
		local sectionFolder = adaptProceduralStarterOakHarvestHierarchy(tree, sampleData)
		local demoSlotCFrame = CFrame.new(stageCenterX, GALLERY_ORIGIN.Y + 1.5, rowCenterZ - 13)
		local sampleDisplayLabel = if sampleData.CustomSeed then "CUSTOM SEED" else sample.Label
		local profileStatus = if sampleData.CustomSeed then "EXACT SEED"
			elseif not sampleData.CategoryMatched then "PROFILE SEARCH FAILED"
			elseif sampleData.SectionCount == 0 then "PROFILE MATCH / UNSPLITTABLE"
			elseif sampleData.ProfileMatched then "PROFILE + SECTION TARGET MATCH"
			else "PROFILE MATCH / SECTION TARGET NOT MET"
		local countStatus = if sampleData.SectionCount > 0
			then tostring(sampleData.SectionCount)
				.. " section(s)"
				.. (sampleData.SectionCountMatched and "" or " — TARGET NOT MET")
			else "UNSPLITTABLE — HARVEST DISABLED"
		local dimensionLabel = string.format(
			"%s | SEED %d | H %.1f / BASE %.2f / TOP %.2f | %s | %s",
			sampleDisplayLabel,
			sampleData.Seed,
			sampleData.CoreHeight,
			sampleData.BaseThickness,
			sampleData.TopThickness,
			countStatus,
			profileStatus
		)

		local playground = Instance.new("Folder")
		playground.Name = "ProceduralStarterOakHarvestPlayground_" .. sample.Key
		playground:SetAttribute("DevOnly", true)
		playground:SetAttribute("VisualOnly", true)
		playground:SetAttribute("DevHarvestShowcase", true)
		playground:SetAttribute("GeneratedStarterOak", true)
		playground:SetAttribute("SpeciesId", "Oak")
		playground:SetAttribute("SourceTreeName", "ProceduralStarterOakHarvestTree")
		playground:SetAttribute("SectionFolderName", "StarterOakHarvestSections")
		playground:SetAttribute("NormalizationTemplateFolder", "StarterOakNormalizedLogTemplates")
		playground:SetAttribute("FallStyle", "CanopySupported")
		playground:SetAttribute("StarterOakVariant", "Procedural")
		playground:SetAttribute("StarterOakVariantName", sampleDisplayLabel)
		playground:SetAttribute("StarterOakLayout", "DevStarterOakGenerator")
		playground:SetAttribute("DesignDirection", "ProceduralStarterOak")
		playground:SetAttribute("DevTreeGalleryLabel", dimensionLabel)
		playground:SetAttribute("DevTreeGallerySeed", sampleData.Seed)
		playground:SetAttribute("DevTreeGalleryExtreme", sampleData.Tree:GetAttribute("Extreme") == true)
		playground:SetAttribute("DevTreeGalleryCustomSeed", sampleData.CustomSeed)
		playground:SetAttribute("HarvestSectionCount", sampleData.SectionCount)
		playground:SetAttribute("HarvestSectionValid", sampleData.SectionCount > 0)
		playground:SetAttribute("HarvestSectionInvalidReason", if sampleData.SectionCount == 0 then sampleData.SectionReason else "")
		playground:SetAttribute("HarvestSectionSelectionReason", sampleData.SectionReason)
		playground:SetAttribute("HarvestSampleCategoryMatched", sampleData.CategoryMatched)
		playground:SetAttribute("HarvestSampleProfileMatched", sampleData.ProfileMatched)
		playground:SetAttribute("HarvestSampleSectionCountMatched", sampleData.SectionCountMatched)
		playground:SetAttribute("HarvestShowcaseReady", sampleData.ProfileMatched and sampleData.SectionCount > 0)
		playground:SetAttribute("HarvestMinimumSectionLength", config.MinimumSectionLength)
		playground:SetAttribute("HarvestMinimumLengthToThicknessRatio", config.MinimumLengthToThicknessRatio)
		playground:SetAttribute("SourceCoreHeight", sampleData.CoreHeight)
		playground:SetAttribute("SourceBaseThickness", sampleData.BaseThickness)
		playground:SetAttribute("SourceTopThickness", sampleData.TopThickness)
		playground:SetAttribute("CanopyCentroidOffset", sampleData.CanopyCentroidOffset)
		playground:SetAttribute("CanopyAsymmetryRatio", sampleData.CanopyAsymmetryRatio)
		playground:SetAttribute("SeedSearchAttempts", sampleData.SearchAttempts)
		playground:SetAttribute("SupportedHarvestYields", "1,2")
		playground.Parent = area

		addPlatform(playground, "ShowcaseStage", Vector3.new(stageCenter.X, GALLERY_ORIGIN.Y - 0.5, stageCenter.Z),
			Vector3.new(config.StageWidth, 1, config.StageDepth))
		addSign(gallery, dimensionLabel,
			Vector3.new(stageCenter.X, 0, stageCenter.Z - config.StageDepth * 0.5 - 2),
			config.StageWidth - 2, "ProceduralStarterOakHarvestSample" .. sampleIndex)

		tree.Name = "ProceduralStarterOakHarvestTree"
		tree:SetAttribute("DevTreeGalleryLabel", dimensionLabel)
		tree.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		configureVisualOnlyModel(tree)
		tree:PivotTo(CFrame.new(stageCenter.X, GALLERY_ORIGIN.Y + 0.04, stageCenter.Z))
		tree.Parent = playground

		local templateFolder = Instance.new("Folder")
		templateFolder.Name = "StarterOakNormalizedLogTemplates"
		templateFolder.Parent = playground
		if sampleData.ProfileMatched and sampleData.SectionCount > 0 then
			local sourceSections = {}
			for _, child in ipairs(sectionFolder:GetChildren()) do
				if child:IsA("Model") and child:GetAttribute("AuthoredHarvestSection") == true then
					table.insert(sourceSections, child)
				end
			end
			table.sort(sourceSections, function(a, b)
				return (a:GetAttribute("HarvestSectionIndex") or math.huge)
					< (b:GetAttribute("HarvestSectionIndex") or math.huge)
			end)
			assert(#sourceSections == sampleData.SectionCount,
				"Procedural Starter Oak adapted section count does not match the selected count")
			for index, sourceSection in ipairs(sourceSections) do
				local template = makeProceduralStarterOakNormalizedLogTemplate(
					index,
					tree,
					sourceSection,
					sampleData.SectionCount
				)
				template.Name = "Section" .. index
				template.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
				template:PivotTo(demoSlotCFrame)
				hideTemplateForClientClone(template, "ProceduralStarterOakSection" .. index)
				template.Parent = templateFolder
			end
		end

		local demoSlot = createPart(playground, "DemoSlot", Vector3.new(1, 1, 1), demoSlotCFrame, Color3.new(1, 1, 1))
		demoSlot.Transparency = 1
		demoSlot:SetAttribute("GroundY", GALLERY_ORIGIN.Y)
		if not firstDemoSlot then firstDemoSlot = demoSlot end

		if sampleData.ProfileMatched and sampleData.SectionCount > 0 then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "ProceduralStarterOakHarvestPreviewPrompt"
			prompt.ActionText = "Harvest Test Tree"
			prompt.ObjectText = sampleDisplayLabel
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt:SetAttribute("DevTreeGalleryTransformationPrompt", true)
			prompt.Parent = demoSlot
		else
			warn(string.format(
				"[DevTreeGallery] Procedural harvest sample %s is visible but disabled: categoryMatched=%s; sectionTargetMatched=%s; sections=%d; reason=%s",
				sample.Key,
				tostring(sampleData.CategoryMatched),
				tostring(sampleData.SectionCountMatched),
				sampleData.SectionCount,
				sampleData.SectionReason
			))
		end

		print(string.format(
			"[DevTreeGallery] Harvest sample %s: seed=%d height=%.2f baseThickness=%.2f topThickness=%.2f canopyOffset=%.2f asymmetry=%.3f sections=%d categoryMatched=%s sectionTargetMatched=%s profileMatched=%s searchAttempts=%d selection=%s",
			sample.Key,
			sampleData.Seed,
			sampleData.CoreHeight,
			sampleData.BaseThickness,
			sampleData.TopThickness,
			sampleData.CanopyCentroidOffset,
			sampleData.CanopyAsymmetryRatio,
			sampleData.SectionCount,
			tostring(sampleData.CategoryMatched),
			tostring(sampleData.SectionCountMatched),
			tostring(sampleData.ProfileMatched),
			sampleData.SearchAttempts,
			sampleData.SectionReason
		))
	end

	if firstDemoSlot then
		gallery:SetAttribute("ProceduralHarvestShowcaseTeleportCFrame", firstDemoSlot.CFrame + Vector3.new(0, 4, 0))
	else
		warn("[DevTreeGallery] Procedural harvest area has no generated sample slots")
	end
end

local function arrangeRow(gallery, title, entries, rowZ, startXOffset)
	local rowDepth = MIN_PLATFORM_SIZE
	local rowWidth = 0
	for index, entry in ipairs(entries) do
		rowDepth = math.max(rowDepth, entry.PlatformSize.Z)
		rowWidth += entry.PlatformSize.X
		if index > 1 then
			rowWidth += COLUMN_GAP
		end
	end

	local cursorX = GALLERY_ORIGIN.X + (startXOffset or 0)
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

	local rowCenterX = GALLERY_ORIGIN.X + (startXOffset or 0) + rowWidth * 0.5
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
	gallery:SetAttribute("StarterOakGallerySeed", STARTER_OAK_GALLERY_SEED)
	gallery:SetAttribute("StarterOakGallerySampleCount", STARTER_OAK_GALLERY_SAMPLE_COUNT)

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

	local structuralStudy = makeStarterOakStructuralStudy()
	local structuralComparisonEntries = {
		makeStaticEntry(structuralStudy, "Starter Oak Structural Study"),
	}
	local structuralRowDepth, structuralRowWidth = arrangeRow(
		gallery,
		"STARTER OAK STRUCTURAL STUDY",
		structuralComparisonEntries,
		STARTER_OAK_REFERENCE_ROW_Z,
		STARTER_OAK_STRUCTURE_ROW_START_X
	)
	assert(STARTER_OAK_STRUCTURE_ROW_START_X >= 4,
		"Starter Oak structure row has too little floor margin")
	assert(STARTER_OAK_STRUCTURE_ROW_START_X + structuralRowWidth <= GALLERY_FLOOR_SIZE.X - 8,
		"Starter Oak structure row exceeds the gallery floor width")
	assert(STARTER_OAK_REFERENCE_ROW_Z + structuralRowDepth * 0.5
		<= GALLERY_FLOOR_OFFSET.Z + GALLERY_FLOOR_SIZE.Z * 0.5 - 8,
		"Starter Oak structure row exceeds the gallery floor depth")
	assert(STARTER_OAK_REFERENCE_ROW_Z - structuralRowDepth * 0.5
		>= GALLERY_FLOOR_OFFSET.Z - GALLERY_FLOOR_SIZE.Z * 0.5 + 8,
		"Starter Oak structure row crosses the gallery floor's front edge")

	local proceduralEntries = {}
	for sampleIndex = 1, STARTER_OAK_GALLERY_SAMPLE_COUNT do
		local seed = STARTER_OAK_GALLERY_SEED + sampleIndex - 1
		local extreme = STARTER_OAK_GALLERY_EXTREME_SAMPLES[sampleIndex] == true
		table.insert(proceduralEntries, makeProceduralStarterOakEntry(seed, extreme))
	end

	assert(STARTER_OAK_GALLERY_SAMPLE_COUNT % STARTER_OAK_GALLERY_TREES_PER_ROW == 0,
		"Procedural Starter Oak sample count must fill complete rows")
	local proceduralRowZ = STARTER_OAK_PROCEDURAL_ROW_START_Z
	local proceduralRowCount = STARTER_OAK_GALLERY_SAMPLE_COUNT / STARTER_OAK_GALLERY_TREES_PER_ROW
	local staticReferenceBackZ = STARTER_OAK_REFERENCE_ROW_Z + structuralRowDepth * 0.5
	local previousProceduralBackZ
	for rowIndex = 1, proceduralRowCount do
		local rowEntries = {}
		for columnIndex = 1, STARTER_OAK_GALLERY_TREES_PER_ROW do
			local entryIndex = (rowIndex - 1) * STARTER_OAK_GALLERY_TREES_PER_ROW + columnIndex
			table.insert(rowEntries, proceduralEntries[entryIndex])
		end

		local rowDepth, rowWidth = arrangeRow(
			gallery,
			"PROCEDURAL STARTER OAKS / ROW " .. rowIndex,
			rowEntries,
			proceduralRowZ,
			STARTER_OAK_PROCEDURAL_ROW_START_X
		)
		assert(STARTER_OAK_PROCEDURAL_ROW_START_X + rowWidth <= GALLERY_FLOOR_SIZE.X - 8,
			"Procedural Starter Oak row exceeds the gallery floor width")
		assert(proceduralRowZ + rowDepth * 0.5
			<= GALLERY_FLOOR_OFFSET.Z + GALLERY_FLOOR_SIZE.Z * 0.5 - 8,
			"Procedural Starter Oak row exceeds the gallery floor depth")
		assert(proceduralRowZ - rowDepth * 0.5
			>= GALLERY_FLOOR_OFFSET.Z - GALLERY_FLOOR_SIZE.Z * 0.5 + 8,
			"Procedural Starter Oak row crosses the gallery floor front edge")
		assert(proceduralRowZ - rowDepth * 0.5
			>= 485 + 44 * 0.5 + 12,
			"Procedural Starter Oak row is too close to the harvest showcase stages")
		local rowHeaderZ = proceduralRowZ - rowDepth * 0.5 - 21
		if rowIndex == 1 then
			assert(rowHeaderZ >= staticReferenceBackZ + 2,
				"Procedural Starter Oak header overlaps the Structural Study")
		elseif previousProceduralBackZ then
			assert(rowHeaderZ >= previousProceduralBackZ + 2,
				"Procedural Starter Oak header overlaps the previous generated row")
		end

		previousProceduralBackZ = proceduralRowZ + rowDepth * 0.5
		proceduralRowZ += rowDepth + STARTER_OAK_GALLERY_ROW_GAP
	end
	addStarterOakHarvestPlayground(gallery)
	addTransformationPlayground(gallery)
	addProceduralStarterOakHarvestShowcase(gallery)

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
