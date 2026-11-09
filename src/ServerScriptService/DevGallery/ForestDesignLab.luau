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
	Path = Color3.fromRGB(244, 207, 125),
	PathLight = Color3.fromRGB(251, 224, 166),
	PathShade = Color3.fromRGB(194, 144, 83),
	MesaRock = Color3.fromRGB(101, 47, 32),
	MesaRockMid = Color3.fromRGB(124, 59, 40),
	MesaRockLight = Color3.fromRGB(150, 81, 56),
	MesaGrass = Color3.fromRGB(70, 158, 54),
	MesaGrassLight = Color3.fromRGB(94, 177, 70),
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

local OCTAGON_CORNER_SCALE = math.sqrt(2) - 1

-- The approved World 1 mesa profile is an octagonal vertical prism built from
-- two bars and four corner wedges. Keep this local copy visual-only and small.
local function makeOctagonalMesaPrism(
	parent: Instance,
	name: string,
	center: Vector3,
	radius: number,
	bottomY: number,
	height: number,
	color: Color3,
	yaw: number
)
	local corner = radius * OCTAGON_CORNER_SCALE
	local barWidth = corner * 2
	local rotation = CFrame.Angles(0, yaw, 0)
	local centerFrame = CFrame.new(center.X, bottomY + height * 0.5, center.Z) * rotation
	local northSouth = makePart(
		parent,
		name .. "BarNS",
		Vector3.new(barWidth, height, radius * 2),
		centerFrame,
		color,
		false
	)
	local eastWest = makePart(
		parent,
		name .. "BarEW",
		Vector3.new(radius * 2, height, barWidth),
		centerFrame,
		color,
		false
	)
	for cornerIndex, signs in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
		local function worldPoint(x: number, z: number): Vector3
			return Vector3.new(center.X, bottomY, center.Z) + rotation:VectorToWorldSpace(Vector3.new(x, 0, z))
		end
		local inner = worldPoint(signs[1] * corner, signs[2] * corner)
		local edgeX = worldPoint(signs[1] * radius, signs[2] * corner)
		local edgeZ = worldPoint(signs[1] * corner, signs[2] * radius)
		local legA = edgeX - inner
		local legB = edgeZ - inner
		local lengthA = legA.Magnitude
		local lengthB = legB.Magnitude
		local yAxis = legA.Unit
		local zAxis = -legB.Unit
		local xAxis = yAxis:Cross(zAxis).Unit
		local wedgePosition = Vector3.new(inner.X, bottomY, inner.Z)
			+ yAxis * (lengthA * 0.5) - zAxis * (lengthB * 0.5)
		wedgePosition = Vector3.new(wedgePosition.X, bottomY + height * 0.5, wedgePosition.Z)
		local wedge = makeWedge(
			parent,
			name .. string.format("Corner%02d", cornerIndex),
			Vector3.new(height, lengthA, lengthB),
			CFrame.fromMatrix(wedgePosition, xAxis, yAxis, zAxis),
			color
		)
		wedge:SetAttribute("BoundaryStyle", "World1MixedMesa")
		wedge:SetAttribute("MesaProfile", "Mixed")
	end
	for _, part in ipairs({ northSouth, eastWest }) do
		part:SetAttribute("BoundaryStyle", "World1MixedMesa")
		part:SetAttribute("MesaProfile", "Mixed")
	end
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
end

local function addTrail(scene: Model, center: Vector3, style: string)
	local trail = makeModel(scene, "CurvingTrail", style)
	trail:SetAttribute("AssetVariant", if style == "Softer" then "HoneyStoneMeander" else "SculptedStepWay")

	local softSteps = {
		{ 0.0, 25.0, -7 }, { -0.3, 21.1, 2 }, { -1.0, 17.2, -4 },
		{ -1.4, 13.3, 5 }, { -0.9, 9.4, -3 }, { 0.1, 5.5, 4 },
	}
	local chunkySteps = {
		{ 0.0, 25.0, -5 }, { 0.8, 21.0, 4 }, { 1.8, 17.0, -3 },
		{ 1.1, 13.0, 5 }, { -0.4, 9.0, -4 }, { -1.1, 5.0, 3 },
	}
	local steps = if style == "Softer" then softSteps else chunkySteps
	for index, step in ipairs(steps) do
		local rotation = math.rad(step[3])
		local pathCenter = Vector3.new(center.X + step[1], center.Y + 0.042, center.Z + step[2])
		makePart(
			trail,
			"WarmEarthEdge" .. index,
			Vector3.new(if style == "Softer" then 8.6 else 9.1, 0.055, 4.8),
			CFrame.new(pathCenter) * CFrame.Angles(0, rotation, 0),
			PALETTE.PathShade,
			false
		)
		makePart(
			trail,
			"TrailStone" .. index,
			Vector3.new(if style == "Softer" then 7.9 else 8.25, 0.12, 4.35),
			CFrame.new(pathCenter.X, center.Y + 0.12, pathCenter.Z)
				* CFrame.Angles(0, rotation, 0),
			if index % 3 == 0 then PALETTE.PathLight else PALETTE.Path,
			false
		)
	end
end

local BUSH_CONFIGS = {
	Softer = {
		CushionFern = {
			Colors = { Color3.fromRGB(67, 133, 74), Color3.fromRGB(96, 166, 92), Color3.fromRGB(123, 186, 101) },
			Lobes = {
				{ -1.2, 0.45, 0.2, 2.8, 2.0, 2.2 },
				{ 0.9, 0.55, -0.35, 2.6, 2.25, 2.3 },
				{ 0.0, 1.05, -0.45, 2.15, 2.35, 2.05 },
			},
		},
		TwinSprout = {
			Colors = { Color3.fromRGB(61, 126, 70), Color3.fromRGB(92, 161, 86), Color3.fromRGB(129, 190, 104) },
			Lobes = {
				{ -1.0, 0.8, 0.25, 2.55, 2.5, 2.2 },
				{ 0.9, 0.8, -0.3, 2.5, 2.45, 2.25 },
				{ 0.35, 1.35, -0.5, 2.1, 2.25, 2.0 },
			},
		},
		CloverFan = {
			Colors = { Color3.fromRGB(65, 128, 70), Color3.fromRGB(105, 170, 91), Color3.fromRGB(139, 193, 112) },
			Lobes = {
				{ -1.15, 0.5, -0.25, 2.7, 1.9, 2.2 },
				{ 0.85, 0.65, 0.15, 2.55, 2.15, 2.2 },
				{ -0.1, 1.15, -0.4, 2.2, 2.3, 2.05 },
			},
		},
	},
	Chunkier = {
		AcornFan = {
			Colors = { Color3.fromRGB(58, 118, 66), Color3.fromRGB(87, 151, 78), Color3.fromRGB(119, 178, 91) },
			Lobes = {
				{ -1.3, 0.45, 0.2, 2.9, 2.15, 2.35 },
				{ 0.9, 0.65, -0.4, 2.7, 2.35, 2.4 },
				{ 0.1, 1.2, -0.5, 2.35, 2.55, 2.15 },
			},
		},
		RidgeBloom = {
			Colors = { Color3.fromRGB(55, 115, 63), Color3.fromRGB(84, 148, 74), Color3.fromRGB(120, 176, 90) },
			Lobes = {
				{ -1.1, 0.55, 0.2, 2.75, 2.05, 2.25 },
				{ 1.0, 0.65, -0.35, 2.85, 2.25, 2.45 },
				{ 0.2, 1.2, -0.5, 2.45, 2.45, 2.25 },
			},
		},
		PocketFern = {
			Colors = { Color3.fromRGB(56, 118, 66), Color3.fromRGB(92, 156, 79), Color3.fromRGB(129, 182, 94) },
			Lobes = {
				{ -1.2, 0.45, -0.15, 2.8, 2.0, 2.35 },
				{ 0.9, 0.55, 0.25, 2.7, 2.0, 2.35 },
				{ -0.1, 1.1, -0.4, 2.5, 2.25, 2.25 },
			},
		},
	},
}

local function addBush(scene: Model, center: Vector3, assetName: string, position: Vector3, style: string, yawDegrees: number)
	local definition = BUSH_CONFIGS[style][assetName]
	local bush = makeModel(scene, assetName, style)
	bush:SetAttribute("AssetVariant", assetName)
	bush:SetAttribute("ModularEnvironmentAsset", true)
	local base = Vector3.new(center.X + position.X, center.Y + 0.58, center.Z + position.Z)
	local yaw = math.rad(yawDegrees)
	makeCornerWedge(
		bush,
		"CutCornerLeafCushion",
		Vector3.new(4.2, 1.15, 3.35),
		CFrame.new(base) * CFrame.Angles(0, yaw, 0),
		definition.Colors[1]
	)
	for index, lobe in ipairs(definition.Lobes) do
		makeWedge(
			bush,
			"LayeredLeaf" .. index,
			Vector3.new(lobe[4], lobe[5], lobe[6]),
			CFrame.new(base + Vector3.new(lobe[1], lobe[2], lobe[3]))
				* CFrame.Angles(0, yaw + math.rad((index - 2) * 18), math.rad((index - 2) * 7)),
			definition.Colors[index]
		)
	end
	makePart(
		bush,
		"InsetLeafPlane",
		Vector3.new(1.8, 0.72, 0.34),
		CFrame.new(base + Vector3.new(-0.1, 0.72, -1.0)) * CFrame.Angles(math.rad(-13), yaw + math.rad(26), math.rad(8)),
		definition.Colors[2],
		false
	)
	if style == "Chunkier" then
		makeWedge(
			bush,
			"OutwardLeaf",
			Vector3.new(2.2, 1.25, 1.65),
			CFrame.new(base + Vector3.new(1.8, 0.2, 0.65)) * CFrame.Angles(0, yaw + math.rad(22), 0),
			definition.Colors[2]
		)
	end
end

local function addMesaCliff(scene: Model, center: Vector3, style: string)
	local edge = makeModel(scene, "BrokenWorld1MesaEdge", style)
	edge:SetAttribute("BoundaryStyle", "World1MixedMesa")
	edge:SetAttribute("MesaProfile", "Mixed")
	edge:SetAttribute("ModularEnvironmentAsset", true)

	-- Three offset polygonal outcrops make a compact broken mesa edge. Their
	-- radii, yaw, height and cap line vary, while each shape uses the approved
	-- two-bar/four-wedge octagonal construction and the production color palette.
	local layouts = if style == "Softer" then {
		{ -24.5, -23.5, 6.2, 6.2, -16 },
		{ -8.5, -25.0, 7.3, 7.6, 9 },
		{ 10.0, -22.7, 5.9, 5.9, -12 },
	} else {
		{ -25.0, -24.0, 6.5, 7.2, -20 },
		{ -8.7, -24.8, 7.6, 8.5, 14 },
		{ 10.3, -22.5, 6.2, 6.6, -10 },
	}
	for index, form in ipairs(layouts) do
		local radius = form[3]
		local height = form[4]
		local yaw = math.rad(form[5])
		local base = Vector3.new(center.X + form[1], center.Y, center.Z + form[2])
		local butte = makeModel(edge, "MesaOutcrop" .. index, style)
		butte:SetAttribute("AssetVariant", if style == "Softer" then "BroadTieredOutcrop" else "FacetedBrokenButte")
		butte:SetAttribute("ModularEnvironmentAsset", true)
		makeOctagonalMesaPrism(butte, "MesaRockBody", base, radius, base.Y, height, PALETTE.MesaRock, yaw)
		makeOctagonalMesaPrism(
			butte,
			"BrokenGreenCap",
			base,
			radius + 0.42,
			base.Y + height,
			0.82,
			PALETTE.MesaGrass,
			yaw + math.rad(if index == 2 then 4 else -3)
		)
		if index == 2 then
			local upperCenter = base + Vector3.new(0.45, height + 0.82, -0.15)
			local upperHeight = if style == "Softer" then 1.35 else 1.65
			makeOctagonalMesaPrism(butte, "SteppedUpperRock", upperCenter, radius * 0.62, upperCenter.Y, upperHeight, PALETTE.MesaRockMid, yaw + math.rad(9))
			makeOctagonalMesaPrism(
				butte,
				"UpperGrassCap",
				upperCenter,
				radius * 0.66,
				upperCenter.Y + upperHeight,
				0.62,
				PALETTE.MesaGrass,
				yaw + math.rad(13)
			)
		end
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
		makeWedge(rock, "BroadCutStone", mainSize, mainFrame, if variant == 1 then PALETTE.MesaRockMid else PALETTE.MesaRock)
		makeCornerWedge(
			rock,
			"LayeredTopFacet",
			Vector3.new(2.8, 1.55, 3.0),
			CFrame.new(x + 0.9, y + 0.66, z - 0.28) * CFrame.Angles(0, yaw - math.rad(21), math.rad(4)),
			PALETTE.MesaRockLight
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
	local origin = center + position + Vector3.new(0, 0.24, 0)
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
	for index, offset in ipairs(positions) do
		local tree = DevStarterOakGenerator.Generate(seeds[index], { Extreme = false })
		tree.Name = "ShowcaseStarterOak" .. index
		tree:SetAttribute("DevGalleryOwner", OWNER)
		tree:SetAttribute("DevOnly", true)
		tree:SetAttribute("VisualOnly", true)
		tree:SetAttribute("PrototypeOnly", true)
		tree:SetAttribute("NonHarvestable", true)
		tree:SetAttribute("HarvestingDisabled", true)
		tree:SetAttribute("ShowcaseVariation", style)
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
	scene:SetAttribute("TreeCount", 3)
	scene:SetAttribute("Harvestable", false)
	scene:SetAttribute("PaletteWorld1", true)

	createGround(scene, center, style)
	addTrail(scene, center, style)
	addMesaCliff(scene, center, style)
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
	for _, bush in ipairs(bushes) do
		addBush(scene, center, bush[1], bush[2], style, bush[3])
	end

	addBoulder(scene, center, style, "MesaBoulderWest", Vector3.new(-30, 0, 13), 1)
	addBoulder(scene, center, style, "MesaBoulderEast", Vector3.new(30, 0, 15), 2)

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
