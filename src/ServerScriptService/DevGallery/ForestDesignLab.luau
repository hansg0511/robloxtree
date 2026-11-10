--!strict
-- Studio-only, self-contained World 1 woodland clearing comparison.
-- This module creates visual scenery only; the landing surfaces are the sole
-- collidable parts. Oaks come from the approved Studio generator and are disabled
-- for harvesting in this showcase.
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local DevStarterOakGenerator = require(ServerScriptService:WaitForChild("DevStarterOakGenerator"))

local ForestDesignLab = {}

local OWNER = "ForestDesignLab"
local SOFT_OFFSET = Vector3.new(-46, 0, 0)
local CHUNKY_OFFSET = Vector3.new(46, 0, 0)
local PLATFORM_SIZE = Vector3.new(72, 0.55, 66)

local PALETTE = {
	Grass = Color3.fromRGB(128, 190, 104),
	GrassLight = Color3.fromRGB(151, 203, 126),
	GrassShade = Color3.fromRGB(103, 163, 89),
	Path = Color3.fromRGB(237, 188, 107),
	PathLight = Color3.fromRGB(249, 214, 151),
	PathShade = Color3.fromRGB(186, 130, 70),
	MesaRock = Color3.fromRGB(101, 47, 32),
	MesaRockMid = Color3.fromRGB(124, 59, 40),
	MesaRockLight = Color3.fromRGB(150, 81, 56),
	Wood = Color3.fromRGB(112, 78, 49),
	WoodLight = Color3.fromRGB(177, 129, 65),
	Cream = Color3.fromRGB(250, 239, 198),
	FlowerGold = Color3.fromRGB(244, 187, 63),
	FlowerCoral = Color3.fromRGB(231, 126, 103),
	FlowerLilac = Color3.fromRGB(178, 144, 207),
}

local function markVisual(instance: Instance)
	instance:SetAttribute("DevGalleryOwner", OWNER)
	instance:SetAttribute("DevOnly", true)
	instance:SetAttribute("VisualOnly", true)
	instance:SetAttribute("PrototypeOnly", true)
	instance:SetAttribute("NonHarvestable", true)
end

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	collidable: boolean?,
	shape: EnumItem?,
	queryable: boolean?
): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = collidable == true
	part.CanTouch = false
	part.CanQuery = queryable == true
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	markVisual(part)
	part.Parent = parent
	return part
end

local function makeWedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3
): BasePart
	local part = Instance.new("WedgePart")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	markVisual(part)
	part.Parent = parent
	return part
end

local function makeCornerWedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3
): BasePart
	local part = Instance.new("CornerWedgePart")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	markVisual(part)
	part.Parent = parent
	return part
end

local function makeModel(parent: Instance, name: string, variation: string?): Model
	local model = Instance.new("Model")
	model.Name = name
	markVisual(model)
	if variation then
		model:SetAttribute("Variation", variation)
	end
	model.Parent = parent
	return model
end

local function createGround(scene: Model, center: Vector3, style: string)
	local soil = makePart(
		scene,
		"EarthFoundation",
		Vector3.new(72, 1.0, 66),
		CFrame.new(center.X, center.Y - 1.05, center.Z),
		Color3.fromRGB(91, 132, 72),
		false
	)
	soil:SetAttribute("DecorativeGroundLayer", true)

	local surface = makePart(
		scene,
		"WalkableGrass",
		PLATFORM_SIZE,
		CFrame.new(center.X, center.Y - PLATFORM_SIZE.Y * 0.5, center.Z),
		if style == "Softer" then PALETTE.GrassLight else PALETTE.Grass,
		true,
		nil,
		false
	)
	surface:SetAttribute("WalkableUtilitySurface", true)
	surface:SetAttribute("NavigationTarget", true)
	surface:SetAttribute("DecorativeGroundLayer", true)

	-- Faceted low meadow washes keep the outer margins varied without making
	-- a repeated dotted texture or taking space from the chopping floor.
	local patches = if style == "Softer" then {
		{ -27, -19, 10, 4.8, PALETTE.Grass },
		{ 27, -22, 9, 5.4, PALETTE.Grass },
		{ -28, 10, 8.8, 4.7, PALETTE.Grass },
		{ 28, 11, 9.5, 5.0, PALETTE.GrassShade },
		{ 14, 27, 9.0, 4.2, PALETTE.Grass },
	} else {
		{ -29, -17, 9.5, 5.2, PALETTE.GrassShade },
		{ 29, -21, 10.5, 5.7, PALETTE.GrassLight },
		{ -29, 9, 9.0, 5.0, PALETTE.Grass },
		{ 29, 12, 10.0, 5.4, PALETTE.GrassShade },
		{ -13, 28, 10.5, 4.5, PALETTE.GrassLight },
	}
	for index, patch in ipairs(patches) do
		local patchPosition = Vector3.new(center.X + patch[1], center.Y + 0.018, center.Z + patch[2])
		local patchFrame = CFrame.new(patchPosition) * CFrame.Angles(0, math.rad((index * 19) % 43 - 21), 0)
		local patchPart = if index % 2 == 0 then
			makeCornerWedge(scene, "MeadowFacet" .. index, Vector3.new(patch[3], 0.035, patch[4]), patchFrame, patch[5])
		else
			makeWedge(scene, "MeadowFacet" .. index, Vector3.new(patch[3], 0.035, patch[4]), patchFrame, patch[5])
		patchPart:SetAttribute("DecorativeGroundLayer", true)
	end
	if style == "Chunkier" then
		-- Broad, flat meadow strokes carry the chunky palette through open grass
		-- while leaving the trail, oak bases, and perimeter props clear.
		local strokes = {
			{ -26.0, -25.0, 5.8, 2.2, PALETTE.GrassLight, -11 },
			{ -18.2, -27.5, 4.8, 1.8, PALETTE.GrassShade, 14 },
			{ -12.0, -23.4, 5.0, 1.9, PALETTE.GrassLight, 8 },
			{ -5.0, -26.2, 4.8, 1.7, PALETTE.GrassShade, -15 },
			{ 5.0, -24.6, 5.2, 2.0, PALETTE.GrassLight, 11 },
			{ 12.1, -27.0, 4.8, 1.8, PALETTE.GrassShade, -9 },
			{ 19.2, -23.3, 5.6, 2.3, PALETTE.GrassLight, 10 },
			{ 26.0, -26.8, 5.6, 2.2, PALETTE.GrassShade, -12 },
			{ -15.2, 3.5, 5.4, 2.0, PALETTE.GrassLight, -12 },
			{ 15.2, 3.5, 5.4, 2.0, PALETTE.GrassShade, 15 },
			{ -15.4, 10.0, 5.8, 2.3, PALETTE.GrassShade, 10 },
			{ 15.4, 10.0, 5.8, 2.3, PALETTE.GrassLight, -8 },
			{ -15.2, 16.7, 5.2, 1.9, PALETTE.GrassLight, -13 },
			{ 15.2, 16.7, 5.2, 1.9, PALETTE.GrassShade, 14 },
			{ -15.0, 23.0, 5.6, 2.2, PALETTE.GrassLight, -11 },
			{ 15.0, 23.0, 5.6, 2.2, PALETTE.GrassShade, 16 },
		}
		for index, stroke in ipairs(strokes) do
			local strokePosition = Vector3.new(center.X + stroke[1], center.Y + 0.045, center.Z + stroke[2])
			local strokeFrame = CFrame.new(strokePosition) * CFrame.Angles(0, math.rad(stroke[6]), 0)
			local strokeSize = Vector3.new(stroke[3], 0.07, stroke[4])
			local strokePart = if index % 3 == 0 then
				makeCornerWedge(scene, "GrassStroke" .. index, strokeSize, strokeFrame, stroke[5])
			else
				makeWedge(scene, "GrassStroke" .. index, strokeSize, strokeFrame, stroke[5])
			strokePart.CastShadow = false
			strokePart:SetAttribute("DecorativeGroundLayer", true)
			strokePart:SetAttribute("GroundTextureAccent", true)
		end
	end
end

local function addTrail(scene: Model, center: Vector3, style: string)
	local trail = makeModel(scene, "CurvingTrail", style)
	trail:SetAttribute("AssetVariant", if style == "Softer" then "HoneyStoneTileMeander" else "WarmStoneTileMeander")

	local softSteps = {
		{ 0.0, 25.0 }, { -0.35, 22.5 }, { -0.85, 20.0 },
		{ -1.15, 17.5 }, { -1.0, 15.0 }, { -0.25, 12.5 },
		{ 0.15, 10.0 }, { 0.0, 7.5 }, { -1.1, 5.0 },
	}
	local chunkySteps = {
		{ 0.0, 25.0 }, { 0.4, 22.5 }, { 1.1, 20.0 },
		{ 1.3, 17.5 }, { 0.6, 15.0 }, { -0.2, 12.5 },
		{ -0.8, 10.0 }, { -1.2, 7.5 }, { -1.1, 5.0 },
	}
	local steps = if style == "Softer" then softSteps else chunkySteps

	local function evaluatePath(segmentIndex: number, t: number): (number, number, number, number)
		local previous = steps[math.max(segmentIndex - 1, 1)]
		local start = steps[segmentIndex]
		local finish = steps[segmentIndex + 1]
		local following = steps[math.min(segmentIndex + 2, #steps)]
		local tSquared = t * t
		local tCubed = tSquared * t

		local x = 0.5
			* (2 * start[1]
				+ (-previous[1] + finish[1]) * t
				+ (2 * previous[1] - 5 * start[1] + 4 * finish[1] - following[1]) * tSquared
				+ (-previous[1] + 3 * start[1] - 3 * finish[1] + following[1]) * tCubed)
		local z = 0.5
			* (2 * start[2]
				+ (-previous[2] + finish[2]) * t
				+ (2 * previous[2] - 5 * start[2] + 4 * finish[2] - following[2]) * tSquared
				+ (-previous[2] + 3 * start[2] - 3 * finish[2] + following[2]) * tCubed)
		local tangentX = 0.5
			* ((-previous[1] + finish[1])
				+ 2 * (2 * previous[1] - 5 * start[1] + 4 * finish[1] - following[1]) * t
				+ 3 * (-previous[1] + 3 * start[1] - 3 * finish[1] + following[1]) * tSquared)
		local tangentZ = 0.5
			* ((-previous[2] + finish[2])
				+ 2 * (2 * previous[2] - 5 * start[2] + 4 * finish[2] - following[2]) * t
				+ 3 * (-previous[2] + 3 * start[2] - 3 * finish[2] + following[2]) * tSquared)
		return x, z, tangentX, tangentZ
	end

	local tileSize = Vector3.new(6.35, 0.075, 2.85)
	local maxSampleSpacing = 0.3
	local liftCycle = math.ceil(tileSize.X / maxSampleSpacing) + 5
	local samples = {}
	for segmentIndex = 1, #steps - 1 do
		local start = steps[segmentIndex]
		local finish = steps[segmentIndex + 1]
		local deltaX = finish[1] - start[1]
		local deltaZ = finish[2] - start[2]
		local segmentLength = math.sqrt(deltaX * deltaX + deltaZ * deltaZ)
		local subdivisionCount = math.max(1, math.ceil(segmentLength / maxSampleSpacing))
		for subdivisionIndex = 0, subdivisionCount - 1 do
			local t = subdivisionIndex / subdivisionCount
			local x, z, tangentX, tangentZ = evaluatePath(segmentIndex, t)
			table.insert(samples, { x, z, tangentX, tangentZ })
		end
	end
	local lastX, lastZ, lastTangentX, lastTangentZ = evaluatePath(#steps - 1, 1)
	table.insert(samples, { lastX, lastZ, lastTangentX, lastTangentZ })

	for index, sample in ipairs(samples) do
		local rotation = math.atan2(sample[3], sample[4])
		local pathCenter = Vector3.new(center.X + sample[1], center.Y, center.Z + sample[2])
		local rotationFrame = CFrame.Angles(0, rotation, 0)
		local tileLift = ((index - 1) % liftCycle) * 0.001
		local tile = makePart(
			trail,
			"TrailTile" .. index,
			tileSize,
			CFrame.new(pathCenter + Vector3.new(0, tileSize.Y * 0.5 + tileLift, 0)) * rotationFrame,
			PALETTE.Path,
			false
		)
		tile:SetAttribute("TrailPiece", "UniformWarmTile")
	end
end

local BUSH_CONFIGS = {
	Softer = {
		CushionFern = {
			Colors = { Color3.fromRGB(67, 133, 74), Color3.fromRGB(96, 166, 92), Color3.fromRGB(123, 186, 101) },
			Layers = {
				{ 0.0, 0.44, 0.0, 5.35, 0.88, 3.65, 1, 0 },
				{ -1.25, 0.78, 0.12, 3.35, 0.98, 2.85, 2, -12 },
				{ 1.15, 0.78, -0.12, 3.25, 0.92, 2.8, 1, 13 },
				{ -0.05, 1.17, -0.38, 3.2, 0.8, 2.3, 3, -3 },
			},
		},
		TwinSprout = {
			Colors = { Color3.fromRGB(61, 126, 70), Color3.fromRGB(92, 161, 86), Color3.fromRGB(129, 190, 104) },
			Layers = {
				{ 0.0, 0.44, 0.0, 5.15, 0.88, 3.55, 1, 0 },
				{ -1.3, 0.79, 0.2, 2.9, 1.0, 2.8, 2, -16 },
				{ 1.05, 0.8, -0.24, 3.45, 0.94, 2.75, 1, 12 },
				{ 0.12, 1.2, -0.48, 3.15, 0.82, 2.35, 3, 4 },
			},
		},
		CloverFan = {
			Colors = { Color3.fromRGB(65, 128, 70), Color3.fromRGB(105, 170, 91), Color3.fromRGB(139, 193, 112) },
			Layers = {
				{ 0.0, 0.44, 0.0, 5.0, 0.88, 3.75, 1, 0 },
				{ -1.2, 0.76, -0.22, 3.15, 0.94, 2.95, 2, -10 },
				{ 1.05, 0.8, 0.16, 3.5, 0.98, 2.65, 1, 16 },
				{ -0.05, 1.16, -0.5, 3.0, 0.78, 2.4, 3, -6 },
			},
		},
	},
	Chunkier = {
		AcornFan = {
			Colors = { Color3.fromRGB(58, 118, 66), Color3.fromRGB(87, 151, 78), Color3.fromRGB(119, 178, 91) },
			Layers = {
				{ 0.0, 0.46, 0.0, 5.75, 0.92, 3.95, 1, 0 },
				{ -1.45, 0.82, 0.2, 3.65, 1.02, 3.05, 2, -14 },
				{ 1.2, 0.84, -0.28, 3.75, 1.0, 2.95, 1, 13 },
				{ -0.1, 1.23, -0.5, 3.55, 0.86, 2.55, 3, -2 },
			},
		},
		RidgeBloom = {
			Colors = { Color3.fromRGB(55, 115, 63), Color3.fromRGB(84, 148, 74), Color3.fromRGB(120, 176, 90) },
			Layers = {
				{ 0.0, 0.46, 0.0, 5.55, 0.92, 4.0, 1, 0 },
				{ -1.3, 0.82, 0.15, 3.2, 0.98, 3.05, 2, -17 },
				{ 1.35, 0.85, -0.26, 3.8, 1.04, 3.0, 1, 12 },
				{ 0.12, 1.22, -0.52, 3.25, 0.84, 2.65, 3, 5 },
			},
		},
		PocketFern = {
			Colors = { Color3.fromRGB(56, 118, 66), Color3.fromRGB(92, 156, 79), Color3.fromRGB(129, 182, 94) },
			Layers = {
				{ 0.0, 0.45, 0.0, 5.25, 0.9, 3.8, 1, 0 },
				{ -1.3, 0.78, -0.15, 3.35, 0.96, 2.9, 2, -12 },
				{ 1.12, 0.79, 0.2, 3.5, 0.94, 2.85, 1, 15 },
				{ -0.08, 1.17, -0.44, 3.25, 0.8, 2.45, 3, -4 },
			},
		},
	},
}

local function addBush(scene: Model, center: Vector3, assetName: string, position: Vector3, style: string, yawDegrees: number)
	local definition = BUSH_CONFIGS[style][assetName]
	local bush = makeModel(scene, assetName, style)
	bush:SetAttribute("AssetVariant", assetName)
	bush:SetAttribute("ModularEnvironmentAsset", true)
	bush:SetAttribute("BushShape", if style == "Chunkier" then "LayeredTallBroadCuboids" else "LayeredLowBroadCuboids")
	local base = Vector3.new(center.X + position.X, center.Y, center.Z + position.Z)
	local yaw = math.rad(yawDegrees)
	local yawFrame = CFrame.Angles(0, yaw, 0)
	local verticalScale = if style == "Chunkier" then 2.2 else 1.6
	for index, layer in ipairs(definition.Layers) do
		local offset = yawFrame:VectorToWorldSpace(Vector3.new(layer[1], layer[2] * verticalScale, layer[3]))
		makePart(
			bush,
			"BroadLeafLayer" .. index,
			Vector3.new(layer[4], layer[5] * verticalScale, layer[6]),
			CFrame.new(base + offset) * CFrame.Angles(0, yaw + math.rad(layer[8]), 0),
			definition.Colors[layer[7]],
			false
		)
	end
end

local function addBoulder(scene: Model, center: Vector3, style: string, name: string, position: Vector3, variant: number)
	local rock = makeModel(scene, name, style)
	rock:SetAttribute("AssetVariant", if style == "Softer" then "SteppedMesaStone" .. variant else "CutFacetMesaStone" .. variant)
	rock:SetAttribute("ModularEnvironmentAsset", true)
	local x = center.X + position.X
	local y = center.Y + 0.72
	local z = center.Z + position.Z
	local yaw = math.rad(-17 + variant * 21)
	local mainSize = if style == "Softer" then Vector3.new(4.7 + variant * 0.3, 2.2 + variant * 0.2, 3.8) else Vector3.new(5.0 + variant * 0.35, 2.8, 4.0)
	local mainFrame = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
	if style == "Softer" then
		makeCornerWedge(rock, "CutCornerStone", mainSize, mainFrame, if variant == 1 then PALETTE.MesaRockMid else PALETTE.MesaRock)
		makeWedge(
			rock,
			"LayeredSunlitFacet",
			Vector3.new(2.5, 1.45, 2.7),
			CFrame.new(x + 1.05, y + 0.52, z - 0.34) * CFrame.Angles(0, yaw + math.rad(18), 0),
			PALETTE.MesaRockLight
		)
	else
		rock:SetAttribute("ShapeLanguage", "LowRoundedGroundedCluster")
		local bodySize = Vector3.new(4.0 + variant * 0.2, 1.5 + variant * 0.08, 3.15)
		makePart(
			rock,
			"RoundedStoneBody",
			bodySize,
			CFrame.new(x, center.Y + bodySize.Y * 0.5 - 0.02, z) * CFrame.Angles(0, yaw, 0),
			if variant == 1 then PALETTE.MesaRockMid else PALETTE.MesaRock,
			false,
			Enum.PartType.Ball
		)
		makePart(
			rock,
			"SunlitRoundedCap",
			Vector3.new(2.15, 0.72, 1.8),
			CFrame.new(x + 0.35, center.Y + bodySize.Y * 0.79, z - 0.24) * CFrame.Angles(0, yaw + math.rad(18), 0),
			PALETTE.MesaRockLight,
			false,
			Enum.PartType.Ball
		)
		makePart(
			rock,
			"GroundedSideLobe",
			Vector3.new(1.45, 0.78, 1.35),
			CFrame.new(x - 1.65, center.Y + 0.37, z + 1.12) * CFrame.Angles(0, yaw - math.rad(12), 0),
			PALETTE.MesaRockMid,
			false,
			Enum.PartType.Ball
		)
	end
end

local function addPebbleCluster(scene: Model, center: Vector3, position: Vector3, groupIndex: number)
	local group = makeModel(scene, "PebbleGroup" .. groupIndex, "Chunkier")
	group:SetAttribute("AssetVariant", "RoundedMeadowPebbles")
	group:SetAttribute("ModularEnvironmentAsset", true)
	local pebbles = {
		{ Vector3.new(-0.58, 0, 0.0), Vector3.new(0.82, 0.42, 0.68), PALETTE.MesaRockMid },
		{ Vector3.new(0.28, 0, -0.24), Vector3.new(0.72, 0.5, 0.62), PALETTE.MesaRockLight },
		{ Vector3.new(0.85, 0, 0.5), Vector3.new(0.64, 0.36, 0.54), PALETTE.MesaRock },
	}
	local yaw = math.rad(groupIndex * 19)
	local yawFrame = CFrame.Angles(0, yaw, 0)
	for index, pebble in ipairs(pebbles) do
		local offset = yawFrame:VectorToWorldSpace(pebble[1])
		local size = pebble[2]
		local pebblePosition = center + position + offset + Vector3.new(0, size.Y * 0.5 - 0.02, 0)
		makePart(
			group,
			"SmoothPebble" .. index,
			size,
			CFrame.new(pebblePosition) * CFrame.Angles(0, yaw + math.rad(index * 13), 0),
			pebble[3],
			false,
			Enum.PartType.Ball
		)
	end
end

local function addFenceSegment(scene: Model, center: Vector3, name: string, position: Vector3, length: number)
	local fence = makeModel(scene, name, "Chunkier")
	fence:SetAttribute("AssetVariant", "LowSplitRailOutskirts")
	fence:SetAttribute("ModularEnvironmentAsset", true)
	local span = length - 0.45
	local x = center.X + position.X
	local z = center.Z + position.Z
	for index, direction in ipairs({ -1, 1 }) do
		makePart(
			fence,
			"FencePost" .. index,
			Vector3.new(0.46, 2.25, 0.46),
			CFrame.new(x + direction * span * 0.5, center.Y + 1.125, z),
			PALETTE.Wood,
			false
		)
	end
	for index, height in ipairs({ 0.72, 1.55 }) do
		makePart(
			fence,
			"FenceRail" .. index,
			Vector3.new(span, 0.22, 0.26),
			CFrame.new(x, center.Y + height, z),
			if index == 1 then PALETTE.WoodLight else PALETTE.Wood,
			false
		)
	end
end

local function addTuft(parent: Instance, center: Vector3, position: Vector3, style: string, index: number)
	local tuft = makeModel(parent, "MeadowTuft" .. index, style)
	tuft:SetAttribute("AssetVariant", if style == "Softer" then "ThreeBladeSedge" else "BroadLeafTuft")
	tuft:SetAttribute("ModularEnvironmentAsset", true)
	local origin = center + position + Vector3.new(0, 0.03, 0)
	local leafColor = if index % 2 == 0 then PALETTE.GrassShade else Color3.fromRGB(76, 145, 79)
	for blade = 1, 3 do
		local yaw = math.rad((blade - 2) * (if style == "Softer" then 30 else 42))
		makeWedge(
			tuft,
			"LeafBlade" .. blade,
			Vector3.new(if style == "Softer" then 1.0 else 1.2, if style == "Softer" then 1.4 else 1.65, 0.5),
			CFrame.new(origin.X + (blade - 2) * 0.46, origin.Y + 0.65, origin.Z + (blade - 2) * 0.15)
				* CFrame.Angles(0, yaw, math.rad((blade - 2) * 7)),
			if blade == 3 then PALETTE.GrassLight else leafColor
		)
	end
end

local function addFlower(scene: Model, center: Vector3, position: Vector3, style: string, index: number)
	local flower = makeModel(scene, "WoodlandBloom" .. index, style)
	flower:SetAttribute("AssetVariant", if index % 2 == 0 then "GoldenBell" else "MeadowPinwheel")
	flower:SetAttribute("ModularEnvironmentAsset", true)
	local flowerBaseOffset = if style == "Chunkier" then 0.075 else 0.24
	local origin = center + position + Vector3.new(0, flowerBaseOffset, 0)
	local petalColor = if index % 3 == 0 then PALETTE.FlowerLilac elseif index % 2 == 0 then PALETTE.FlowerGold else PALETTE.FlowerCoral
	makePart(
		flower,
		"FlowerStem",
		Vector3.new(0.13, 0.55, 0.13),
		CFrame.new(origin.X, origin.Y + 0.2, origin.Z),
		PALETTE.GrassShade,
		false
	)
	for petal = 1, 4 do
		local angle = math.rad((petal - 1) * 90)
		makeWedge(
			flower,
			"AngularPetal" .. petal,
			Vector3.new(0.46, 0.2, 0.34),
			CFrame.new(origin.X + math.cos(angle) * 0.27, origin.Y + 0.58, origin.Z + math.sin(angle) * 0.27)
				* CFrame.Angles(0, angle, math.rad((petal % 2) * 5)),
			if index % 2 == 0 and petal % 2 == 0 then PALETTE.PathLight else petalColor
		)
	end
	makePart(
		flower,
		"FlowerHeart",
		Vector3.new(0.23, 0.2, 0.23),
		CFrame.new(origin.X, origin.Y + 0.69, origin.Z),
		PALETTE.FlowerGold,
		false
	)
end

local function addBushBloomCluster(scene: Model, center: Vector3, position: Vector3, yawDegrees: number, bushIndex: number)
	local flowerOffsets = {
		Vector3.new(-0.65, 3.2, 1.02),
		Vector3.new(0.65, 3.22, 1.02),
	}
	local yawFrame = CFrame.Angles(0, math.rad(yawDegrees), 0)
	for index, offset in ipairs(flowerOffsets) do
		local rotated = yawFrame:VectorToWorldSpace(Vector3.new(offset.X, 0, offset.Z))
		local flowerPosition = Vector3.new(position.X + rotated.X, offset.Y, position.Z + rotated.Z)
		addFlower(scene, center, flowerPosition, "Chunkier", 10 + (bushIndex - 1) * 2 + index)
	end
end

local function addSign(scene: Model, center: Vector3, style: string)
	local x = center.X + 28.2
	local z = center.Z + 24.2
	makePart(
		scene,
		"SignPost",
		Vector3.new(0.35, 2.7, 0.35),
		CFrame.new(x, center.Y + 1.35, z),
		PALETTE.Wood,
		false
	)
	local board = makePart(
		scene,
		"VariationPlaque",
		Vector3.new(7.2, 1.65, 0.28),
		CFrame.new(x - 0.2, center.Y + 2.45, z),
		if style == "Softer" then PALETTE.Wood else Color3.fromRGB(92, 62, 41),
		false
	)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "VariationLabel"
	surface.Face = Enum.NormalId.Back
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 32
	surface.LightInfluence = 0
	surface.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = if style == "Softer" then "A  ·  SOFTER" else "B  ·  CHUNKIER"
	label.TextColor3 = PALETTE.Cream
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = surface
end

local function addTrees(scene: Model, center: Vector3, style: string)
	-- Both directions use the same seeds and tree spacing so this is an environment
	-- comparison, not a test of different Oak silhouettes.
	local positions = {
		Vector3.new(-18, center.Y, -8),
		Vector3.new(1, center.Y, -15),
		Vector3.new(19, center.Y, -7),
	}
	local seeds = { 418031, 418047, 418063 }
	if style == "Chunkier" then
		table.insert(positions, Vector3.new(-12, center.Y, -26))
		table.insert(positions, Vector3.new(12, center.Y, -26))
		table.insert(seeds, 418079)
		table.insert(seeds, 418097)
	end
	for index, offset in ipairs(positions) do
		local tree = DevStarterOakGenerator.Generate(seeds[index], { Extreme = false })
		tree:ScaleTo(1.08)
		tree.Name = "ShowcaseStarterOak" .. index
		tree:SetAttribute("DevGalleryOwner", OWNER)
		tree:SetAttribute("DevOnly", true)
		tree:SetAttribute("VisualOnly", true)
		tree:SetAttribute("PrototypeOnly", true)
		tree:SetAttribute("NonHarvestable", true)
		tree:SetAttribute("HarvestingDisabled", true)
		tree:SetAttribute("ShowcaseVariation", style)
		tree:SetAttribute("ShowcaseVisualScale", 1.08)
		for _, descendant in ipairs(tree:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
				descendant:SetAttribute("DevOnly", true)
				descendant:SetAttribute("VisualOnly", true)
				descendant:SetAttribute("NonHarvestable", true)
				if descendant:GetAttribute("HarvestableCore") == true then
					descendant:SetAttribute("HarvestableCore", false)
				end
			end
		end
		tree:PivotTo(CFrame.new(center.X + offset.X, center.Y, center.Z + offset.Z))
		tree.Parent = scene
	end
end

local function buildVariation(parent: Model, name: string, center: Vector3, style: string)
	local scene = makeModel(parent, name, style)
	scene.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	scene:SetAttribute("DesignDirection", if style == "Softer" then "SofterStorybook" else "ChunkierStorybook")
	scene:SetAttribute("Theme", "World1BrightWoodland")
	scene:SetAttribute("TreeCount", if style == "Chunkier" then 5 else 3)
	scene:SetAttribute("Harvestable", false)
	scene:SetAttribute("PaletteWorld1", true)

	createGround(scene, center, style)
	addTrail(scene, center, style)
	addTrees(scene, center, style)

	local bushes = if style == "Softer" then {
		{ "CushionFern", Vector3.new(-30, 0, -20), -18 },
		{ "TwinSprout", Vector3.new(30, 0, -20), 21 },
		{ "CloverFan", Vector3.new(-30, 0, 4), 12 },
		{ "CushionFern", Vector3.new(30, 0, 5), -14 },
	} else {
		{ "AcornFan", Vector3.new(-30, 0, -19), -23 },
		{ "RidgeBloom", Vector3.new(30, 0, -20), 19 },
		{ "PocketFern", Vector3.new(-30, 0, 5), 14 },
		{ "AcornFan", Vector3.new(30, 0, 6), -18 },
	}
	for bushIndex, bush in ipairs(bushes) do
		addBush(scene, center, bush[1], bush[2], style, bush[3])
		if style == "Chunkier" then
			addBushBloomCluster(scene, center, bush[2], bush[3], bushIndex)
		end
	end

	addBoulder(scene, center, style, "MesaBoulderWest", Vector3.new(-30, 0, 13), 1)
	addBoulder(scene, center, style, "MesaBoulderEast", Vector3.new(30, 0, 15), 2)
	if style == "Chunkier" then
		addPebbleCluster(scene, center, Vector3.new(-25.8, 0, 15.7), 1)
		addPebbleCluster(scene, center, Vector3.new(25.8, 0, 18.4), 2)
		addFenceSegment(scene, center, "RearFenceWest", Vector3.new(-22.5, 0, -28.2), 11.5)
		addFenceSegment(scene, center, "RearFenceEast", Vector3.new(22.5, 0, -28.2), 11.5)
	end

	local tuftPositions = if style == "Softer" then {
		Vector3.new(-29, 0, 20), Vector3.new(-20, 0, 27), Vector3.new(25, 0, 22), Vector3.new(31, 0, -1),
	} else {
		Vector3.new(-29, 0, 20), Vector3.new(-20, 0, 27), Vector3.new(25, 0, 22), Vector3.new(31, 0, 0),
	}
	for index, position in ipairs(tuftPositions) do
		addTuft(scene, center, position, style, index)
	end

	local flowerPositions = if style == "Softer" then {
		Vector3.new(-26, 0, 25), Vector3.new(24, 0, 25), Vector3.new(-31, 0, -1),
	} else {
		Vector3.new(-26, 0, 25), Vector3.new(24, 0, 25),
	}
	for index, position in ipairs(flowerPositions) do
		addFlower(scene, center, position, style, index)
	end

	addSign(scene, center, style)

	local focus = Vector3.new(center.X, center.Y + 7, center.Z - 6)
	local landingPosition = Vector3.new(center.X, center.Y + 3.5, center.Z + 24)
	local landing = CFrame.lookAt(landingPosition, focus)
	scene:SetAttribute("LandingCFrame", landing)
	scene:SetAttribute("FocusPosition", focus)
	local instanceCount = 1
	local basePartCount = 0
	for _, descendant in ipairs(scene:GetDescendants()) do
		instanceCount += 1
		if descendant:IsA("BasePart") then
			basePartCount += 1
		end
	end
	scene:SetAttribute("InstanceCount", instanceCount)
	scene:SetAttribute("BasePartCount", basePartCount)
	return scene, landing, focus, instanceCount, basePartCount
end

function ForestDesignLab.Build(parent: Instance, center: Vector3)
	assert(RunService:IsStudio(), "ForestDesignLab is available only in Roblox Studio")
	assert(parent ~= nil, "ForestDesignLab.Build requires a parent")
	assert(typeof(center) == "Vector3", "ForestDesignLab.Build requires a world-space midpoint Vector3")

	local root = Instance.new("Model")
	root.Name = "ForestDesignLab"
	markVisual(root)
	root:SetAttribute("LabId", "Forest")
	root:SetAttribute("Theme", "World1BrightWoodland")
	root:SetAttribute("VariationCount", 2)
	root:SetAttribute("BuildStatus", "Building")

	local ok, result = pcall(function()
		local softerCenter = center + SOFT_OFFSET
		local chunkierCenter = center + CHUNKY_OFFSET
		local softer, softerLanding, softerFocus, softerCount, softerParts =
			buildVariation(root, "SofterStorybookClearing", softerCenter, "Softer")
		local chunkier, chunkierLanding, chunkierFocus, chunkierCount, chunkierParts =
			buildVariation(root, "ChunkierStorybookClearing", chunkierCenter, "Chunkier")

		root:SetAttribute("BuildStatus", "Ready")
		root:SetAttribute("SofterStorybookInstanceCount", softerCount)
		root:SetAttribute("ChunkierStorybookInstanceCount", chunkierCount)
		root:SetAttribute("SofterStorybookBasePartCount", softerParts)
		root:SetAttribute("ChunkierStorybookBasePartCount", chunkierParts)
		root:SetAttribute("TotalInstanceCount", softerCount + chunkierCount + 1)
		root:SetAttribute("TotalBasePartCount", softerParts + chunkierParts)

		local metadata = {
			Variations = {
				Softer = softerLanding,
				Chunkier = chunkierLanding,
			},
			FocusByVariation = {
				Softer = softerFocus,
				Chunkier = chunkierFocus,
			},
			Focus = (softerFocus + chunkierFocus) * 0.5,
			InstanceCounts = {
				Softer = softerCount,
				Chunkier = chunkierCount,
				Total = softerCount + chunkierCount + 1,
			},
			BasePartCounts = {
				Softer = softerParts,
				Chunkier = chunkierParts,
				Total = softerParts + chunkierParts,
			},
		}
		return metadata
	end)

	if not ok then
		root:Destroy()
		error(result, 2)
	end

	root.Parent = parent
	return root, result
end

return ForestDesignLab
