-- Server-only deterministic procedural Starter Oak model generator.

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local SpeciesVisuals = require(ServerStorage:WaitForChild("SpeciesVisuals"))

local Generator = {}

local MIN_SEED = -2147483647
local MAX_SEED = 2147483647
local STRUCTURE_VERSION = 1

-- These profiles are the single place to tune the tree's overall variation.
-- Extreme is a caller-selected gallery sample, not an economy or rarity roll.
local PROFILES = {
	Normal = {
		CoreHeight = { 12.0, 17.0 },
		TrunkThickness = { 1.75, 2.65 },
		TaperRatio = { 0.91, 0.985 },
		BranchCount = { 6, 8 },
		CanopyScale = { 0.82, 1.15 },
		CanopyVerticalScale = { 0.84, 1.24 },
		CrownDriftScale = 0.55,
		BranchJitter = 0.16,
		BranchRadius = { 2.65, 3.65 },
		BranchRise = { 0.80, 2.45 },
		TipHeightOffsetRatio = 0.035,
		LeafWidthX = { 4.25, 5.45 },
		LeafHeight = { 2.55, 3.70 },
		LeafWidthZ = { 4.15, 5.35 },
		SatelliteChance = 0.48,
	},
	Extreme = {
		CoreHeight = { 8.5, 22.0 },
		TrunkThickness = { 0.95, 3.35 },
		TaperRatio = { 0.80, 0.99 },
		BranchCount = { 5, 9 },
		CanopyScale = { 0.65, 1.50 },
		CanopyVerticalScale = { 0.62, 1.58 },
		CrownDriftScale = 1.75,
		BranchJitter = 0.34,
		BranchRadius = { 2.45, 4.10 },
		BranchRise = { 0.45, 3.30 },
		TipHeightOffsetRatio = 0.10,
		LeafWidthX = { 4.0, 5.8 },
		LeafHeight = { 2.55, 4.0 },
		LeafWidthZ = { 3.9, 5.7 },
		SatelliteChance = 0.60,
	},
}

local function normalizeSeed(seed)
	assert(
		type(seed) == "number" and seed == seed and seed > -math.huge and seed < math.huge,
		"StarterOakGenerator.Generate requires a finite numeric seed"
	)
	return math.clamp(math.floor(seed), MIN_SEED, MAX_SEED)
end

local function between(random, minimum, maximum)
	return random:NextNumber(minimum, maximum)
end

local function createFolder(parent, name)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function createBlock(parent, name, size, cframe, color)
	assert(size.X > 0 and size.Y > 0 and size.Z > 0, "Oak part dimensions must be positive")
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.FrontSurface = Enum.SurfaceType.Smooth
	part.BackSurface = Enum.SurfaceType.Smooth
	part.LeftSurface = Enum.SurfaceType.Smooth
	part.RightSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function orientedAlongY(startPosition, endPosition)
	local delta = endPosition - startPosition
	local direction = delta.Unit
	local reference = if math.abs(direction.Y) > 0.98
		then Vector3.new(0, 0, 1)
		else Vector3.new(0, 1, 0)
	local right = direction:Cross(reference).Unit
	local back = right:Cross(direction).Unit
	return CFrame.fromMatrix((startPosition + endPosition) * 0.5, right, direction, back), delta.Magnitude
end

local function tint(color, factor)
	return Color3.new(
		math.clamp(color.R * factor, 0, 1),
		math.clamp(color.G * factor, 0, 1),
		math.clamp(color.B * factor, 0, 1)
	)
end

local function foliageColor(palette, heightRatio, recessed, random)
	local roleRoll = random:NextNumber()
	local brightness = between(random, 0.98, 1.02)
	local role

	if heightRatio >= 0.84 then
		role = if roleRoll < 0.72 then "LeafHighlight" else "Leaf"
	elseif heightRatio >= 0.70 then
		if recessed and roleRoll < 0.20 then
			role = "LeafShadow"
		else
			role = if roleRoll < 0.30 then "Leaf" else "LeafHighlight"
		end
	else
		if recessed and roleRoll < 0.38 then
			role = "LeafShadow"
		else
			role = if roleRoll < 0.58 then "Leaf" else "LeafHighlight"
		end
	end

	return tint(palette[role], brightness)
end

local function addFoliagePart(
	parent,
	palette,
	random,
	name,
	center,
	size,
	yaw,
	coreHeight,
	recessed,
	clusterIndex,
	supportedBranchIndex,
	attachedClusterIndex
)
	local part = createBlock(
		parent,
		name,
		size,
		CFrame.new(center) * CFrame.Angles(0, yaw, 0),
		foliageColor(palette, center.Y / coreHeight, recessed, random)
	)
	part:SetAttribute("FoliageClusterIndex", clusterIndex)
	if supportedBranchIndex then
		part:SetAttribute("SupportedBranchIndex", supportedBranchIndex)
	end
	if attachedClusterIndex then
		part:SetAttribute("AttachedToClusterIndex", attachedClusterIndex)
	end
	return part
end

local function makeTrunk(random, model, palette, coreHeight, trunkThickness, taperRatio, seed)
	local trunkStructure = createFolder(model, "TrunkStructure")
	trunkStructure:SetAttribute("CoreHeight", coreHeight)
	trunkStructure:SetAttribute("BaseThickness", trunkThickness)
	trunkStructure:SetAttribute("TaperRatio", taperRatio)

	local harvestableCore = createFolder(trunkStructure, "HarvestableCore")
	local halfHeight = coreHeight * 0.5
	local topThickness = trunkThickness * taperRatio
	local sections = {
		{ Bottom = 0, Top = halfHeight, Width = trunkThickness },
		{ Bottom = halfHeight, Top = coreHeight, Width = topThickness },
	}
	local coreParts = {}

	for sectionIndex, definition in ipairs(sections) do
		local sectionHeight = definition.Top - definition.Bottom
		local section = Instance.new("Model")
		section.Name = "Section" .. sectionIndex
		section:SetAttribute("AuthoredHarvestSection", true)
		section:SetAttribute("HarvestSectionIndex", sectionIndex)
		section:SetAttribute("CoreBottomY", definition.Bottom)
		section:SetAttribute("CoreTopY", definition.Top)
		section:SetAttribute("CoreHeight", sectionHeight)
		section:SetAttribute("CoreThickness", definition.Width)
		section.Parent = harvestableCore

		local core = createBlock(
			section,
			"Core",
			Vector3.new(definition.Width, sectionHeight, definition.Width),
			CFrame.new(0, definition.Bottom + sectionHeight * 0.5, 0),
			palette.Bark
		)
		core.PivotOffset = CFrame.new(0, -sectionHeight * 0.5, 0)
		core:SetAttribute("HarvestableCore", true)
		core:SetAttribute("HarvestSectionIndex", sectionIndex)
		core:SetAttribute("CoreBottomY", definition.Bottom)
		core:SetAttribute("CoreTopY", definition.Top)
		core:SetAttribute("SourceTreeSeed", seed)
		section.PrimaryPart = core
		coreParts[sectionIndex] = core
	end

	local baseCore = coreParts[1]
	local bark = createFolder(model, "DecorativeBark")
	local footSize = trunkThickness * 1.48
	local rootFoot = createBlock(
		bark,
		"RootFoot",
		Vector3.new(footSize, 0.72, footSize),
		CFrame.new(0, 0.36, 0),
		palette.BarkShadow
	)
	rootFoot:SetAttribute("ConnectedToTrunk", true)
	rootFoot:SetAttribute("DecorativeOnly", true)

	for sectionIndex, definition in ipairs(sections) do
		local width = definition.Width
		local sectionHeight = definition.Top - definition.Bottom
		local stripHeight = sectionHeight * between(random, 0.62, 0.88)
		local stripCenterY = definition.Bottom + sectionHeight * between(random, 0.46, 0.56)
		local stripWidth = width * between(random, 0.13, 0.21)
		local stripDepth = 0.10
		local frontStrip = createBlock(
			bark,
			"WarmBarkAccent" .. sectionIndex,
			Vector3.new(stripWidth, stripHeight, stripDepth),
			CFrame.new(0, stripCenterY, -width * 0.5 - stripDepth * 0.5 + 0.01),
			palette.BarkHighlight
		)
		frontStrip:SetAttribute("DecorativeOnly", true)
		frontStrip:SetAttribute("CoreSectionIndex", sectionIndex)

		local sideStrip = createBlock(
			bark,
			"RecessedBarkAccent" .. sectionIndex,
			Vector3.new(stripDepth, stripHeight * between(random, 0.66, 0.92), stripWidth),
			CFrame.new(width * 0.5 + stripDepth * 0.5 - 0.01, stripCenterY, 0),
			palette.BarkShadow
		)
		sideStrip:SetAttribute("DecorativeOnly", true)
		sideStrip:SetAttribute("CoreSectionIndex", sectionIndex)
	end

	return baseCore, createFolder(model, "DecorativeBranches"), createFolder(model, "FoliageDecorations")
end

local function addBranch(parent, palette, branchIndex, startPosition, foliageCenter, thickness)
	local cframe, length = orientedAlongY(startPosition, foliageCenter)
	local branch = createBlock(
		parent,
		"Branch" .. branchIndex,
		Vector3.new(thickness, length, thickness * 0.92),
		cframe,
		if branchIndex % 3 == 0 then palette.BarkHighlight else palette.Bark
	)
	branch:SetAttribute("BranchIndex", branchIndex)
	branch:SetAttribute("ConnectedToTrunk", true)
	branch:SetAttribute("ConnectedToFoliage", true)
	branch:SetAttribute("DecorativeOnly", true)
	branch:SetAttribute("FoliageClusterIndex", branchIndex)
	branch:SetAttribute("TrunkAnchorLocal", startPosition)
	branch:SetAttribute("FoliageAnchorLocal", foliageCenter)
	return branch
end

local function addCentralCanopy(
	foliage,
	palette,
	random,
	coreHeight,
	trunkThickness,
	canopyScale,
	verticalScale,
	crownDrift
)
	local created = 0
	local definitions = {
		{ Name = "LowerCanopyCore", HeightRatio = 0.60, Width = 5.0, Height = 3.0, Recessed = true },
		{ Name = "MiddleCanopyCore", HeightRatio = 0.79, Width = 4.8, Height = 3.0, Recessed = false },
		{ Name = "UpperCanopyCore", HeightRatio = 0.97, Width = 4.5, Height = 2.8, Recessed = false },
	}
	local driftFactors = { 0.12, 0.20, 0.28 }

	for index, definition in ipairs(definitions) do
		local width = definition.Width * canopyScale * between(random, 0.92, 1.08)
		local clusterSize = Vector3.new(
			width,
			definition.Height * verticalScale * between(random, 0.90, 1.10),
			width * between(random, 0.91, 1.08)
		)
		local centerX = math.clamp(
			crownDrift.X * driftFactors[index],
			-trunkThickness * 0.30,
			trunkThickness * 0.30
		)
		local centerZ = math.clamp(
			crownDrift.Z * driftFactors[index],
			-trunkThickness * 0.30,
			trunkThickness * 0.30
		)
		local center = Vector3.new(centerX, coreHeight * definition.HeightRatio, centerZ)
		local clusterIndex = 100 + index
		local part = addFoliagePart(
			foliage,
			palette,
			random,
			definition.Name,
			center,
			clusterSize,
			between(random, -0.16, 0.16),
			coreHeight,
			definition.Recessed,
			clusterIndex,
			nil,
			nil
		)
		part:SetAttribute("ConnectedToTrunk", true)
		part:SetAttribute("DecorativeOnly", true)
		created += 1
	end

	return created
end

function Generator.Generate(seed, options)
	assert(RunService:IsServer(), "StarterOakGenerator.Generate must run on the server")
	assert(options == nil or type(options) == "table", "Generator options must be a table")

	local normalizedSeed = normalizeSeed(seed)
	local random = Random.new(normalizedSeed)
	local extreme = RunService:IsStudio() and options ~= nil and options.Extreme == true
	local profile = if extreme then PROFILES.Extreme else PROFILES.Normal
	local palette = SpeciesVisuals.GetPalette("Oak")

	local coreHeight = between(random, profile.CoreHeight[1], profile.CoreHeight[2])
	local trunkThickness = between(random, profile.TrunkThickness[1], profile.TrunkThickness[2])
	local taperRatio = between(random, profile.TaperRatio[1], profile.TaperRatio[2])
	local branchCount = random:NextInteger(profile.BranchCount[1], profile.BranchCount[2])
	local canopyScale = between(random, profile.CanopyScale[1], profile.CanopyScale[2])
	local verticalScale = between(random, profile.CanopyVerticalScale[1], profile.CanopyVerticalScale[2])
	local driftLimit = profile.CrownDriftScale * canopyScale
	local crownDrift = Vector3.new(
		between(random, -driftLimit, driftLimit),
		0,
		between(random, -driftLimit, driftLimit)
	)
	local branchPhase = between(random, 0, math.pi * 2)

	local model = Instance.new("Model")
	model.Name = "ProceduralStarterOak_" .. tostring(normalizedSeed)
	model:SetAttribute("GeneratedStarterOak", true)
	model:SetAttribute("SpeciesId", "Oak")
	model:SetAttribute("DesignDirection", "StarterOakStructuralStudy")
	model:SetAttribute("ProceduralGeneratorVersion", STRUCTURE_VERSION)
	model:SetAttribute("Seed", normalizedSeed)
	model:SetAttribute("Extreme", extreme)
	model:SetAttribute("CoreHeight", coreHeight)
	model:SetAttribute("TrunkThickness", trunkThickness)
	model:SetAttribute("TopThickness", trunkThickness * taperRatio)
	model:SetAttribute("TaperRatio", taperRatio)
	model:SetAttribute("BranchCount", branchCount)
	model:SetAttribute("CanopyScale", canopyScale)
	model:SetAttribute("CanopyVerticalScale", verticalScale)

	local _, branches, foliage = makeTrunk(
		random,
		model,
		palette,
		coreHeight,
		trunkThickness,
		taperRatio,
		normalizedSeed
	)
	local branchPlans = {}

	for branchIndex = 1, branchCount do
		local angleStep = math.pi * 2 / branchCount
		local angle = branchPhase + (branchIndex - 1) * angleStep
			+ between(random, -angleStep * profile.BranchJitter, angleStep * profile.BranchJitter)
		local startY = coreHeight * between(random, 0.53, 0.76)
		local radius = between(random, profile.BranchRadius[1], profile.BranchRadius[2]) * canopyScale
		local rise = between(random, profile.BranchRise[1], profile.BranchRise[2])
		local tipHeightOffset = between(
			random,
			-coreHeight * profile.TipHeightOffsetRatio,
			coreHeight * profile.TipHeightOffsetRatio
		)
		local driftFactor = between(random, 0.34, 0.72)
		local endPosition = Vector3.new(
			math.cos(angle) * radius + crownDrift.X * driftFactor,
			math.clamp(startY + rise + tipHeightOffset, startY + 0.35, coreHeight * 1.12),
			math.sin(angle) * radius + crownDrift.Z * driftFactor
		)
		local branchThickness = math.clamp(
			trunkThickness * between(random, 0.17, 0.27),
			0.28,
			0.92
		)
		local foliageSize = Vector3.new(
			between(random, profile.LeafWidthX[1], profile.LeafWidthX[2]) * canopyScale,
			between(random, profile.LeafHeight[1], profile.LeafHeight[2]) * verticalScale,
			between(random, profile.LeafWidthZ[1], profile.LeafWidthZ[2]) * canopyScale
		)
		local foliageYaw = angle + between(random, -0.40, 0.40)
		local satelliteRoll = random:NextNumber()
		local satelliteOffset = Vector3.new(
			between(random, -0.46, 0.46) * canopyScale,
			between(random, -0.24, 0.24) * verticalScale,
			between(random, -0.46, 0.46) * canopyScale
		)
		local satelliteSize = Vector3.new(
			between(random, 2.9, 3.7) * canopyScale,
			between(random, 1.8, 2.55) * verticalScale,
			between(random, 2.8, 3.6) * canopyScale
		)
		local satelliteYaw = between(random, -math.pi, math.pi)

		table.insert(branchPlans, {
			Index = branchIndex,
			Start = Vector3.new(0, startY, 0),
			End = endPosition,
			BranchThickness = branchThickness,
			FoliageSize = foliageSize,
			FoliageYaw = foliageYaw,
			SatelliteRoll = satelliteRoll,
			SatelliteOffset = satelliteOffset,
			SatelliteSize = satelliteSize,
			SatelliteYaw = satelliteYaw,
		})
	end

	local foliageClusterCount = addCentralCanopy(
		foliage,
		palette,
		random,
		coreHeight,
		trunkThickness,
		canopyScale,
		verticalScale,
		crownDrift
	)

	for _, plan in ipairs(branchPlans) do
		addBranch(branches, palette, plan.Index, plan.Start, plan.End, plan.BranchThickness)
		local leaf = addFoliagePart(
			foliage,
			palette,
			random,
			"BranchCanopy" .. plan.Index,
			plan.End,
			plan.FoliageSize,
			plan.FoliageYaw,
			coreHeight,
			plan.Index % 2 == 0,
			plan.Index,
			plan.Index,
			nil
		)
		leaf:SetAttribute("ConnectedToBranch", true)
		leaf:SetAttribute("DecorativeOnly", true)
		foliageClusterCount += 1

		if plan.SatelliteRoll < profile.SatelliteChance then
			local satellite = addFoliagePart(
				foliage,
				palette,
				random,
				"LeafLobe" .. plan.Index,
				plan.End + plan.SatelliteOffset,
				plan.SatelliteSize,
				plan.SatelliteYaw,
				coreHeight,
				plan.Index % 2 == 0,
				plan.Index,
				plan.Index,
				plan.Index
			)
			satellite:SetAttribute("ConnectedToFoliage", true)
			satellite:SetAttribute("DecorativeOnly", true)
			foliageClusterCount += 1
		end
	end

	local carrier = Instance.new("Part")
	carrier.Name = "OakRootCarrier"
	carrier.Size = Vector3.new(1, coreHeight, 1)
	carrier.CFrame = CFrame.new(0, coreHeight * 0.5, 0)
	carrier.PivotOffset = CFrame.new(0, -coreHeight * 0.5, 0)
	carrier.Transparency = 1
	carrier.Anchored = true
	carrier.Massless = true
	carrier.CanCollide = false
	carrier.CanTouch = false
	carrier.CanQuery = false
	carrier.CastShadow = false
	carrier:SetAttribute("AlwaysInvisible", true)
	carrier:SetAttribute("GeneratedTreeCarrier", true)
	carrier.Parent = model

	model.PrimaryPart = carrier
	local partCount = 0
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= carrier then
			descendant.Anchored = false
			descendant.Massless = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false

			local weld = Instance.new("WeldConstraint")
			weld.Name = "OakAssemblyWeld"
			weld.Part0 = carrier
			weld.Part1 = descendant
			weld.Parent = descendant
			partCount += 1
		end
	end
	partCount += 1
	model:SetAttribute("FoliageClusterCount", foliageClusterCount)
	model:SetAttribute("PartCount", partCount)
	return model
end

return Generator
