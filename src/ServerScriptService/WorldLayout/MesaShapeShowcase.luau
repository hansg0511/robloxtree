-- Gallery-only comparison of three long mesa boundary profiles.
--
-- This keeps the approved Terrain and Border contours/profile language, while
-- using a fixed local seed to vary each run's size, height, yaw and placement.
-- The generated parts are visual-only; this module does not create gameplay
-- collision, touch, or query geometry.
local MesaShapeShowcase = {}

local EPSILON = 1e-4
local TAU = math.pi * 2
local SIDE_PANEL_THICKNESS = 1.1
local LAYER_OVERLAP = 0.06
local CAP_OVERLAP = 0.08

local ROCK_MATERIAL = Enum.Material.SmoothPlastic
local GRASS_MATERIAL = Enum.Material.SmoothPlastic
local ROCK_COLOR = Color3.fromRGB(101, 47, 32)
local GRASS_COLOR = Color3.fromRGB(70, 158, 54)

local ROOT_NAME = "MesaBoundarySampleRuns"
local TERRAIN_NAME = "TerrainBoundarySample"
local FACETED_NAME = "FacetedBoundarySample"
local MIXED_NAME = "MixedBoundarySample"
local MIN_DEPTH_STAGGER_BY_NAME = {
	[ TERRAIN_NAME ] = 18,
	[ FACETED_NAME ] = 22,
	[ MIXED_NAME ] = 26,
}

local PAIR_CENTER_X = -460
local PAIR_CENTER_Z = -40
local PAIR_X_OFFSETS = { -240, 0, 240 }
local RUN_CENTER_Z = 0
local MAX_RUN_HALF_WIDTH = 42
local MAX_RUN_HALF_DEPTH = 123
local MIN_CORE_OVERLAP = 0.5
local FORMATION_COUNT = 9
local FORMATION_SPACING_Z = 21.5
local MIN_VISIBLE_WALL_LENGTH = 200

-- Bounds of the temporary gallery extension. These checks are intentionally
-- local to the candidate; they do not affect the live world layout service.
local GALLERY_FLOOR = {
	MinX = -960,
	MaxX = 0,
	MinZ = -180,
	MaxZ = 180,
}

-- The approved broad Terrain-like contour and irregular Border-like contour.
local TERRAIN_CONTOUR = {
	{ -0.90, -0.62 }, { -0.25, -1.00 }, { 0.61, -0.94 }, { 1.00, -0.44 },
	{ 0.92, 0.55 }, { 0.38, 0.98 }, { -0.54, 0.91 }, { -1.00, 0.28 },
}

local BORDER_CONTOUR = {
	{ 1.00, 0.16 }, { 0.77, 0.73 }, { 0.25, 1.00 }, { -0.34, 0.94 },
	{ -0.88, 0.62 }, { -1.00, -0.14 }, { -0.68, -0.84 }, { 0.02, -1.00 },
	{ 0.79, -0.72 }, { 1.00, -0.10 },
}

local BORDER_UPPER_VERTEX_SCALES = {
	1.02, 0.97, 1.04, 0.96, 1.02, 0.95, 1.01, 1.04, 0.95, 1.02,
}

local MAX_POSITION_JITTER_X = 0.6
local MAX_POSITION_JITTER_Z = 0.35
local MIN_RADIUS_SCALE = 0.93
local MAX_RADIUS_SCALE = 1.06
local MAX_YAW_DEGREES = 3.5
local MIN_LAYER_SCALE = 0.97
local CORE_HALF_X_SCALE = 0.50
local CORE_HALF_Z_SCALE = 0.75

local TERRAIN_CENTER_X_PATTERN = { -10, -6, -1, 5, 10, 7, 1, -6, -10 }
local FACETED_CENTER_X_PATTERN = { -12, -7, -2, 4, 12, 8, 2, -5, -12 }
local MIXED_CENTER_X_PATTERN = { -14, -9, -3, 4, 14, 9, 2, -7, -14 }
local RADIUS_X_PATTERN = { 18, 21, 17, 22, 19, 16, 22, 18, 20 }
local RADIUS_Z_PATTERN = { 24.5, 23.5, 25, 24, 31.5, 23.5, 25, 24, 24.5 }
local HEIGHT_PATTERN = { 28, 35, 25, 39, 32, 27, 37, 30, 34 }

local function makeWallConfigs(namePrefix, kind, centerXPattern)
	local configs = table.create(FORMATION_COUNT)
	for index = 1, FORMATION_COUNT do
		local isFaceted = kind == "Faceted" or (kind == "Mixed" and index % 2 == 0)
		local source = {
			Name = string.format("%sAnchor%02d", namePrefix, index),
			ProfileKind = if isFaceted then "Faceted" else "Terrain",
			CenterX = centerXPattern[index],
			CenterZ = (index - (FORMATION_COUNT + 1) * 0.5) * FORMATION_SPACING_Z,
			RadiusX = RADIUS_X_PATTERN[index],
			RadiusZ = RADIUS_Z_PATTERN[index],
			RotationDegrees = ({ -2.5, 1.5, 0, 2, -1.5, 1, -2, 2.5, -0.5 })[index],
			CapScale = if isFaceted then 1.16 + (index % 3) * 0.01 else 1.00 + (index % 2) * 0.01,
			CapThickness = if isFaceted then 3.0 + (index % 3) * 0.2 else 0.85,
		}
		if isFaceted then
			source.Layers = {
				{ TopScale = 0.76 + (index % 3) * 0.025, Height = HEIGHT_PATTERN[index] * 0.48 },
				{ TopScale = 0.57 + (index % 3) * 0.025, Height = HEIGHT_PATTERN[index] * 0.52 },
			}
		else
			source.TopScale = 0.75 + (index % 4) * 0.025
			source.Height = HEIGHT_PATTERN[index]
		end
		configs[index] = source
	end
	return configs
end

local TERRAIN_FORMS = makeWallConfigs("Plateau", "Terrain", TERRAIN_CENTER_X_PATTERN)
local FACETED_FORMS = makeWallConfigs("BorderPillar", "Faceted", FACETED_CENTER_X_PATTERN)
local MIXED_FORMS = makeWallConfigs("MixedRim", "Mixed", MIXED_CENTER_X_PATTERN)

local function horizontal(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function makeOutline(center, radiusX, radiusZ, yawRadians, contour, phase)
	local points = table.create(#contour)
	local cosine = math.cos(yawRadians)
	local sine = math.sin(yawRadians)
	for index, normalized in ipairs(contour) do
		local wobble = 1
			+ 0.025 * math.sin(index * 1.73 + phase)
			+ 0.018 * math.cos(index * 2.41 - phase * 0.7)
		local x = normalized[1] * radiusX * wobble
		local z = normalized[2] * radiusZ * wobble
		points[index] = center + Vector3.new(
			x * cosine - z * sine,
			0,
			x * sine + z * cosine
		)
	end
	return points, center
end

local function scaleOutline(points, anchor, scale, vertexScales)
	local scaled = table.create(#points)
	assert(not vertexScales or #vertexScales == #points,
		"Outline vertex-scale count must match its contour")
	for index, point in ipairs(points) do
		local vertexScale = if vertexScales then vertexScales[index] else 1
		scaled[index] = anchor + (point - anchor) * (scale * vertexScale)
	end
	return scaled
end

local function makeCapOutline(points, anchor, scale, phase, variation)
	local cap = table.create(#points)
	for index, point in ipairs(points) do
		local radial = point - anchor
		local angle = math.atan2(radial.Z, radial.X)
		local factor = scale * (1 + variation * math.sin(2 * angle + phase * 1.7))
		cap[index] = anchor + radial * factor
	end
	return cap
end

local function stylePart(part, color, material, name)
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.Material = material
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("VisualOnly", true)
	part:SetAttribute("WorldDecoration", ROOT_NAME)
	return part
end

-- Built-in WedgeParts fill a right triangle in their local Y/Z plane and
-- extrude along local X. The horizontal version is used for the green cap.
local function makeFootprintWedge(parent, name, rightCorner, endpointA, endpointB, bottomY, height)
	local legA = horizontal(endpointA - rightCorner)
	local legB = horizontal(endpointB - rightCorner)
	local lengthA = legA.Magnitude
	local lengthB = legB.Magnitude
	if lengthA <= EPSILON or lengthB <= EPSILON or height <= EPSILON then
		return nil
	end

	local yAxis = legA.Unit
	local zAxis = -legB.Unit
	local xAxis = yAxis:Cross(zAxis).Unit
	local partPosition = horizontal(rightCorner) + yAxis * (lengthA * 0.5) - zAxis * (lengthB * 0.5)
	partPosition = Vector3.new(partPosition.X, bottomY + height * 0.5, partPosition.Z)

	local wedge = Instance.new("WedgePart")
	wedge.Size = Vector3.new(height, lengthA, lengthB)
	wedge.CFrame = CFrame.fromMatrix(partPosition, xAxis, yAxis, zAxis)
	stylePart(wedge, GRASS_COLOR, GRASS_MATERIAL, name)
	wedge.Parent = parent
	return wedge
end

local function createFootprintTriangle(parent, name, pointA, pointB, pointC, bottomY, height)
	local candidates = {
		{ Apex = pointA, BaseA = pointB, BaseB = pointC },
		{ Apex = pointB, BaseA = pointC, BaseB = pointA },
		{ Apex = pointC, BaseA = pointA, BaseB = pointB },
	}
	for _, candidate in ipairs(candidates) do
		local first = horizontal(candidate.BaseA - candidate.Apex)
		local second = horizontal(candidate.BaseB - candidate.Apex)
		local denominator = first.Magnitude * second.Magnitude
		candidate.Cosine = denominator <= EPSILON
			and 1
			or math.clamp(first:Dot(second) / denominator, -1, 1)
	end
	table.sort(candidates, function(left, right)
		return left.Cosine < right.Cosine
	end)

	local triangle = candidates[1]
	local baseDirection = horizontal(triangle.BaseB - triangle.BaseA)
	local baseLengthSquared = baseDirection:Dot(baseDirection)
	if baseLengthSquared <= EPSILON then
		return 0
	end
	local projection = horizontal(triangle.Apex - triangle.BaseA):Dot(baseDirection) / baseLengthSquared
	local foot = triangle.BaseA + baseDirection * math.clamp(projection, 0, 1)

	local count = 0
	if makeFootprintWedge(parent, name .. "_A", foot, triangle.Apex, triangle.BaseA, bottomY, height) then
		count += 1
	end
	if makeFootprintWedge(parent, name .. "_B", foot, triangle.Apex, triangle.BaseB, bottomY, height) then
		count += 1
	end
	return count
end

local function createPolygonCap(parent, name, points, interiorAnchor, bottomY, height)
	for index = 1, #points do
		local nextIndex = if index == #points then 1 else index + 1
		createFootprintTriangle(
			parent,
			string.format("%s_Facet%02d", name, index),
			interiorAnchor,
			points[index],
			points[nextIndex],
			bottomY,
			height
		)
	end
end

local function angleCosineAt3D(vertex, pointA, pointB)
	local toA = pointA - vertex
	local toB = pointB - vertex
	local denominator = toA.Magnitude * toB.Magnitude
	if denominator <= EPSILON then
		return 1
	end
	return math.clamp(toA:Dot(toB) / denominator, -1, 1)
end

-- A thin triangular WedgePart panel keeps the sloping outer face visible.
local function makeSlopePanel(parent, name, rightCorner, endpointA, endpointB)
	local legA = endpointA - rightCorner
	local legB = endpointB - rightCorner
	local lengthA = legA.Magnitude
	local lengthB = legB.Magnitude
	if lengthA <= EPSILON or lengthB <= EPSILON then
		return nil
	end

	local yAxis = legA.Unit
	local zAxis = -legB.Unit
	local xAxis = yAxis:Cross(zAxis).Unit
	local partPosition = rightCorner + yAxis * (lengthA * 0.5) - zAxis * (lengthB * 0.5)

	local wedge = Instance.new("WedgePart")
	wedge.Size = Vector3.new(SIDE_PANEL_THICKNESS, lengthA, lengthB)
	wedge.CFrame = CFrame.fromMatrix(partPosition, xAxis, yAxis, zAxis)
	stylePart(wedge, ROCK_COLOR, ROCK_MATERIAL, name)
	wedge.Parent = parent
	return wedge
end

local function createSlopeTriangle(parent, name, pointA, pointB, pointC)
	local candidates = {
		{ Apex = pointA, BaseA = pointB, BaseB = pointC },
		{ Apex = pointB, BaseA = pointC, BaseB = pointA },
		{ Apex = pointC, BaseA = pointA, BaseB = pointB },
	}
	for _, candidate in ipairs(candidates) do
		candidate.Cosine = angleCosineAt3D(candidate.Apex, candidate.BaseA, candidate.BaseB)
	end
	table.sort(candidates, function(left, right)
		return left.Cosine < right.Cosine
	end)

	local triangle = candidates[1]
	local baseDirection = triangle.BaseB - triangle.BaseA
	local baseLengthSquared = baseDirection:Dot(baseDirection)
	if baseLengthSquared <= EPSILON then
		return 0
	end
	local projection = (triangle.Apex - triangle.BaseA):Dot(baseDirection) / baseLengthSquared
	local foot = triangle.BaseA + baseDirection * math.clamp(projection, 0, 1)

	local count = 0
	if makeSlopePanel(parent, name .. "_A", foot, triangle.Apex, triangle.BaseA) then
		count += 1
	end
	if makeSlopePanel(parent, name .. "_B", foot, triangle.Apex, triangle.BaseB) then
		count += 1
	end
	return count
end

local function createSlopeShell(parent, name, lowerOutline, upperOutline, bottomY, height)
	assert(#lowerOutline == #upperOutline, "Tapered rings must have matching vertex counts")
	for index = 1, #lowerOutline do
		local nextIndex = if index == #lowerOutline then 1 else index + 1
		local lowerA = Vector3.new(lowerOutline[index].X, bottomY, lowerOutline[index].Z)
		local lowerB = Vector3.new(lowerOutline[nextIndex].X, bottomY, lowerOutline[nextIndex].Z)
		local upperA = Vector3.new(upperOutline[index].X, bottomY + height, upperOutline[index].Z)
		local upperB = Vector3.new(upperOutline[nextIndex].X, bottomY + height, upperOutline[nextIndex].Z)
		createSlopeTriangle(parent, string.format("%s_Slope%02d_1", name, index), lowerA, lowerB, upperB)
		createSlopeTriangle(parent, string.format("%s_Slope%02d_2", name, index), lowerA, upperB, upperA)
	end
end

local function markModel(model, kind)
	model:SetAttribute("DevOnly", true)
	model:SetAttribute("VisualOnly", true)
	model:SetAttribute("ShowcaseOnly", true)
	model:SetAttribute("WorldDecoration", ROOT_NAME)
	model:SetAttribute("ShowcaseKind", kind)
end

local function createLabel(parent, name, position, text, width)
	local anchor = Instance.new("Part")
	anchor.Name = name .. "Anchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor:SetAttribute("VisualOnly", true)
	anchor:SetAttribute("WorldDecoration", ROOT_NAME)
	anchor.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = name
	billboard.Adornee = anchor
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 400
	billboard.Size = UDim2.fromOffset(width, 82)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(31, 42, 42)
	label.BackgroundTransparency = 0.08
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = Color3.fromRGB(244, 242, 225)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = billboard

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 13)
	padding.PaddingRight = UDim.new(0, 13)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = label
	return anchor
end

local function copyAndVary(config, random, profileKind)
	local selectedProfile = config.ProfileKind or profileKind
	local variation = {
		Name = config.Name,
		CenterX = config.CenterX + random:NextNumber(-MAX_POSITION_JITTER_X, MAX_POSITION_JITTER_X),
		CenterZ = config.CenterZ + random:NextNumber(-MAX_POSITION_JITTER_Z, MAX_POSITION_JITTER_Z),
		RadiusX = config.RadiusX * random:NextNumber(0.94, 1.06),
		RadiusZ = config.RadiusZ * random:NextNumber(0.94, 1.06),
		RotationRadians = math.rad(config.RotationDegrees + random:NextNumber(-0.75, 0.75)),
		Phase = random:NextNumber(0, TAU),
		CapScale = config.CapScale * random:NextNumber(0.98, 1.02),
		CapThickness = config.CapThickness,
		ProfileKind = selectedProfile,
		Contour = if selectedProfile == "Terrain" then TERRAIN_CONTOUR else BORDER_CONTOUR,
		Layers = {},
	}
	local heightScale = random:NextNumber(0.90, 1.10)
	if selectedProfile == "Terrain" then
		variation.Layers[1] = {
			TopScale = config.TopScale * random:NextNumber(0.97, 1.03),
			Height = config.Height * heightScale,
		}
	else
		for index, layer in ipairs(config.Layers) do
			variation.Layers[index] = {
				TopScale = layer.TopScale * random:NextNumber(0.97, 1.03),
				Height = layer.Height * heightScale,
				VertexScales = BORDER_UPPER_VERTEX_SCALES,
			}
		end
	end
	return variation
end

local function createFormation(parent, origin, config, kind)
	local formation = Instance.new("Model")
	formation.Name = config.Name
	markModel(formation, kind)
	formation:SetAttribute("FootprintSides", #config.Contour)
	formation:SetAttribute("NominalRadius", math.max(config.RadiusX, config.RadiusZ))
	formation:SetAttribute("RotationDegrees", math.deg(config.RotationRadians))

	local center = origin + Vector3.new(config.CenterX, 0, config.CenterZ)
	local baseOutline, anchor = makeOutline(
		center,
		config.RadiusX,
		config.RadiusZ,
		config.RotationRadians,
		config.Contour,
		config.Phase
	)
	local currentY = origin.Y
	local currentOutline = baseOutline
	for layerIndex, layer in ipairs(config.Layers) do
		local nextOutline = scaleOutline(baseOutline, anchor, layer.TopScale, layer.VertexScales)
		local layerBottom = currentY - (if layerIndex > 1 then LAYER_OVERLAP else 0)
		local layerHeight = layer.Height + (if layerIndex > 1 then LAYER_OVERLAP else 0)

		-- Each lower-band core is inscribed inside its tapered ring. Neighboring
		-- cores overlap at the ground line, which fills the seam between facade
		-- panels while preserving the stepped, separate landform silhouettes.
		local core = Instance.new("Part")
		core.Name = string.format("%s_Core%02d", config.Name, layerIndex)
		core.Size = Vector3.new(
			2 * config.RadiusX * layer.TopScale * CORE_HALF_X_SCALE,
			layerHeight,
			2 * config.RadiusZ * layer.TopScale * CORE_HALF_Z_SCALE
		)
		core.CFrame = CFrame.new(center.X, layerBottom + layerHeight * 0.5, center.Z)
			* CFrame.Angles(0, config.RotationRadians, 0)
		stylePart(core, ROCK_COLOR, ROCK_MATERIAL, core.Name)
		core.Parent = formation

		createSlopeShell(
			formation,
			string.format("%s_Band%02d", config.Name, layerIndex),
			currentOutline,
			nextOutline,
			layerBottom,
			layerHeight
		)
		currentY += layer.Height
		currentOutline = nextOutline
	end

	local capOutline = makeCapOutline(
		currentOutline,
		anchor,
		config.CapScale,
		config.Phase,
		0.025
	)
	createPolygonCap(
		formation,
		config.Name .. "_GrassCap",
		capOutline,
		anchor,
		currentY - CAP_OVERLAP,
		config.CapThickness
	)
	local capTopY = currentY - CAP_OVERLAP + config.CapThickness
	formation:SetAttribute("LayerCount", #config.Layers)
	formation:SetAttribute("PeakHeight", capTopY - origin.Y)
	formation.Parent = parent
	return formation, capTopY
end

local measureContourZ

local function createRun(parent, name, labelText, kind, origin, configs, seed, profileKind)
	local run = Instance.new("Model")
	run.Name = name
	run.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	markModel(run, kind)
	run:SetAttribute("BuildStatus", "Building")
	run:SetAttribute("Seed", seed)
	run:SetAttribute("FormationCount", #configs)
	run:SetAttribute("ProfileKind", profileKind)

	local random = Random.new(seed)
	local highestTop = origin.Y
	local contourMinZ = math.huge
	local contourMaxZ = -math.huge
	local minimumCenterX = math.huge
	local maximumCenterX = -math.huge
	for _, sourceConfig in ipairs(configs) do
		local config = copyAndVary(sourceConfig, random, profileKind)
		minimumCenterX = math.min(minimumCenterX, config.CenterX)
		maximumCenterX = math.max(maximumCenterX, config.CenterX)
		local minZ, maxZ = measureContourZ(config)
		contourMinZ = math.min(contourMinZ, minZ)
		contourMaxZ = math.max(contourMaxZ, maxZ)
		local _, topY = createFormation(run, origin, config, kind)
		highestTop = math.max(highestTop, topY)
	end
	local visibleLength = contourMaxZ - contourMinZ
	assert(visibleLength >= MIN_VISIBLE_WALL_LENGTH,
		string.format("%s contour length is only %.2f studs", name, visibleLength))
	local depthStaggerRange = maximumCenterX - minimumCenterX
	local minimumStagger = MIN_DEPTH_STAGGER_BY_NAME[name]
	assert(minimumStagger and depthStaggerRange >= minimumStagger,
		string.format("%s depth stagger is only %.2f studs", name, depthStaggerRange))
	run:SetAttribute("VisibleContourMinZ", contourMinZ)
	run:SetAttribute("VisibleContourMaxZ", contourMaxZ)
	run:SetAttribute("VisibleLengthZ", visibleLength)
	run:SetAttribute("DepthStaggerRangeX", depthStaggerRange)

	local labelAnchor = createLabel(
		run,
		"BoundaryRunLabel",
		Vector3.new(origin.X, highestTop + 3.1, origin.Z),
		labelText,
		340
	)
	run.PrimaryPart = labelAnchor
	run:SetAttribute("TopY", highestTop)
	run:SetAttribute("LabelAnchorY", labelAnchor.Position.Y)
	run:SetAttribute("BuildStatus", "Ready")
	run.Parent = parent
	return run
end

measureContourZ = function(config)
	local center = Vector3.new(config.CenterX, 0, config.CenterZ)
	local points = makeOutline(
		center,
		config.RadiusX,
		config.RadiusZ,
		config.RotationRadians,
		config.Contour,
		config.Phase
	)
	local minimumZ = math.huge
	local maximumZ = -math.huge
	for _, point in ipairs(points) do
		minimumZ = math.min(minimumZ, point.Z)
		maximumZ = math.max(maximumZ, point.Z)
	end
	return minimumZ, maximumZ
end

local function projectedHalfExtent(radiusX, radiusZ, yawRadians, axis)
	if axis == "X" then
		return math.abs(radiusX * math.cos(yawRadians)) + math.abs(radiusZ * math.sin(yawRadians))
	end
	return math.abs(radiusX * math.sin(yawRadians)) + math.abs(radiusZ * math.cos(yawRadians))
end

local function coreLayerScale(config)
	if config.TopScale then
		return config.TopScale
	end
	return config.Layers[1].TopScale
end

-- This computes an axis-aligned rectangle that is inscribed inside the
-- rotated lower-band core. If the rectangles overlap in both axes, the rock
-- cores overlap with a positive margin, so the run cannot have base gaps.
local function inscribedCoreHalfExtents(config)
	local scale = coreLayerScale(config) * MIN_LAYER_SCALE
	local halfX = config.RadiusX * MIN_RADIUS_SCALE * scale * CORE_HALF_X_SCALE
	local halfZ = config.RadiusZ * MIN_RADIUS_SCALE * scale * CORE_HALF_Z_SCALE
	local yaw = math.rad(MAX_YAW_DEGREES)
	return
		halfX * math.cos(yaw) - halfZ * math.sin(yaw),
		halfZ * math.cos(yaw) - halfX * math.sin(yaw)
end

local function worstCaseContourReach(config, direction)
	local contour = if config.ProfileKind == "Terrain" then TERRAIN_CONTOUR else BORDER_CONTOUR
	local maxNormalizedZ = 0
	local maxNormalizedX = 0
	for _, point in ipairs(contour) do
		maxNormalizedZ = math.max(maxNormalizedZ, point[2] * direction)
		maxNormalizedX = math.max(maxNormalizedX, math.abs(point[1]))
	end
	local yaw = math.rad(MAX_YAW_DEGREES)
	local innerZ = config.RadiusZ * MIN_RADIUS_SCALE * 0.957 * maxNormalizedZ * math.cos(yaw)
	local outerX = config.RadiusX * MAX_RADIUS_SCALE * maxNormalizedX * math.sin(yaw)
	return innerZ - outerX
end

local function minimumVisibleWallLength(configs)
	local first = configs[1]
	local last = configs[#configs]
	return math.abs(last.CenterZ - first.CenterZ)
		- 2 * MAX_POSITION_JITTER_Z
		+ worstCaseContourReach(first, -1)
		+ worstCaseContourReach(last, 1)
end

local function validateRun(name, configs)
	assert(#configs == FORMATION_COUNT,
		string.format("%s must contain exactly %d formations", name, FORMATION_COUNT))
	local previous
	for _, config in ipairs(configs) do
		local xRadius = config.RadiusX * MAX_RADIUS_SCALE
		local zRadius = config.RadiusZ * MAX_RADIUS_SCALE
		local yaw = math.rad(MAX_YAW_DEGREES)
		local halfWidth = math.abs(config.CenterX) + MAX_POSITION_JITTER_X
			+ projectedHalfExtent(xRadius, zRadius, yaw, "X") * 1.045
		local halfDepth = math.abs(config.CenterZ) + MAX_POSITION_JITTER_Z
			+ projectedHalfExtent(xRadius, zRadius, yaw, "Z") * 1.045
		assert(halfWidth <= MAX_RUN_HALF_WIDTH,
			string.format("%s exceeds its bounded run width (%.2f)", name, halfWidth))
		assert(halfDepth <= MAX_RUN_HALF_DEPTH,
			string.format("%s exceeds its bounded run depth (%.2f)", name, halfDepth))

		if previous then
			local horizontalSpacing = math.abs(config.CenterX - previous.CenterX)
				+ 2 * MAX_POSITION_JITTER_X
			local lateralSpacing = math.abs(config.CenterZ - previous.CenterZ)
				+ 2 * MAX_POSITION_JITTER_Z
			local previousHalfX, previousHalfZ = inscribedCoreHalfExtents(previous)
			local currentHalfX, currentHalfZ = inscribedCoreHalfExtents(config)
			assert(horizontalSpacing + MIN_CORE_OVERLAP <= previousHalfX + currentHalfX,
				string.format("%s lower cores may gap between %s and %s", name, previous.Name, config.Name))
			assert(lateralSpacing + MIN_CORE_OVERLAP <= previousHalfZ + currentHalfZ,
				string.format("%s lower cores may gap laterally between %s and %s", name, previous.Name, config.Name))
		end
		previous = config
	end
	local minCenterX = math.huge
	local maxCenterX = -math.huge
	for _, config in ipairs(configs) do
		minCenterX = math.min(minCenterX, config.CenterX)
		maxCenterX = math.max(maxCenterX, config.CenterX)
	end
	local minimumStagger = MIN_DEPTH_STAGGER_BY_NAME[name]
	assert(minimumStagger
		and maxCenterX - minCenterX - 2 * MAX_POSITION_JITTER_X >= minimumStagger,
		string.format("%s depth stagger is not robustly noticeable", name))
	local visibleLength = minimumVisibleWallLength(configs)
	assert(visibleLength >= MIN_VISIBLE_WALL_LENGTH,
		string.format("%s is too short in actual contour length (%.2f studs)", name, visibleLength))
end

local function findGalleryAncestor(instance)
	local ancestor = instance
	while ancestor do
		if ancestor.Name == "DevTreeGallery" then
			return ancestor
		end
		ancestor = ancestor.Parent
	end
	return nil
end

-- Static layout checks use the rock outlines and inscribed cores, never the
-- billboard label or the oriented bounding boxes of the wedge parts.
validateRun(TERRAIN_NAME, TERRAIN_FORMS)
validateRun(FACETED_NAME, FACETED_FORMS)
validateRun(MIXED_NAME, MIXED_FORMS)
assert(#PAIR_X_OFFSETS == 3 and PAIR_X_OFFSETS[2] == 0,
	"The boundary comparison needs three centered gallery bays")
for index, offset in ipairs(PAIR_X_OFFSETS) do
	assert(PAIR_CENTER_X + offset - MAX_RUN_HALF_WIDTH >= GALLERY_FLOOR.MinX,
		string.format("Boundary bay %d exceeds the west extension floor", index))
	assert(PAIR_CENTER_X + offset + MAX_RUN_HALF_WIDTH <= GALLERY_FLOOR.MaxX,
		string.format("Boundary bay %d crosses into the original gallery", index))
	if index > 1 then
		assert(offset - PAIR_X_OFFSETS[index - 1] > 2 * MAX_RUN_HALF_WIDTH,
			"Boundary bays must stay separated for independent viewing angles")
	end
end
assert(PAIR_CENTER_Z + RUN_CENTER_Z - MAX_RUN_HALF_DEPTH >= GALLERY_FLOOR.MinZ,
	"The boundary walls exceed the front extension floor edge")
assert(PAIR_CENTER_Z + RUN_CENTER_Z + MAX_RUN_HALF_DEPTH <= GALLERY_FLOOR.MaxZ,
	"The boundary walls exceed the rear extension floor edge")

function MesaShapeShowcase.Create(parent, origin)
	assert(parent ~= nil, "MesaShapeShowcase.Create requires a parent")
	assert(typeof(origin) == "Vector3", "MesaShapeShowcase.Create requires a Vector3 midpoint origin")

	local gallery = findGalleryAncestor(parent)
	local galleryOrigin = gallery and gallery:GetAttribute("GalleryOrigin")
	if typeof(galleryOrigin) == "Vector3" then
		assert(math.abs((origin.X - galleryOrigin.X) - PAIR_CENTER_X) <= 1,
			"MesaShapeShowcase.Create expects the three-bay midpoint at GalleryOrigin X-460")
		assert(math.abs((origin.Z - galleryOrigin.Z) - PAIR_CENTER_Z) <= 1,
			"MesaShapeShowcase.Create expects the three-bay row at GalleryOrigin Z-40")
	end

	local existing = parent:FindFirstChild(ROOT_NAME)
	if existing then
		existing:Destroy()
	end

	local samples = Instance.new("Model")
	samples.Name = ROOT_NAME
	-- Child runs stream atomically and independently across the wide gallery.
	samples.ModelStreamingMode = Enum.ModelStreamingMode.Default
	samples:SetAttribute("DevOnly", true)
	samples:SetAttribute("VisualOnly", true)
	samples:SetAttribute("ShowcaseOnly", true)
	samples:SetAttribute("WorldDecoration", ROOT_NAME)
	samples:SetAttribute("SampleCount", 3)
	samples:SetAttribute("BuildStatus", "Building")
	samples:SetAttribute("PairCenterX", origin.X)
	samples:SetAttribute("PairCenterZ", origin.Z)
	samples:SetAttribute("VisibleLengthMinimum", MIN_VISIBLE_WALL_LENGTH)

	local terrainOrigin = origin + Vector3.new(PAIR_X_OFFSETS[1], 0, RUN_CENTER_Z)
	local facetedOrigin = origin + Vector3.new(PAIR_X_OFFSETS[2], 0, RUN_CENTER_Z)
	local mixedOrigin = origin + Vector3.new(PAIR_X_OFFSETS[3], 0, RUN_CENTER_Z)
	local terrainRun = createRun(
		samples,
		TERRAIN_NAME,
		"TERRAIN INSPIRED\nBROAD PLATEAU WALL",
		"TerrainBoundary",
		terrainOrigin,
		TERRAIN_FORMS,
		314_159,
		"Terrain"
	)
	local facetedRun = createRun(
		samples,
		FACETED_NAME,
		"BORDER INSPIRED\nFACETED TERRACE WALL",
		"FacetedBoundary",
		facetedOrigin,
		FACETED_FORMS,
		271_828,
		"Faceted"
	)
	local mixedRun = createRun(
		samples,
		MIXED_NAME,
		"MIXED PROFILE\nBROAD + FACETED WALL",
		"MixedBoundary",
		mixedOrigin,
		MIXED_FORMS,
		161_803,
		"Mixed"
	)
	assert(terrainRun.Parent == samples and facetedRun.Parent == samples and mixedRun.Parent == samples,
		"All three boundary samples must be direct children of the sample root")
	assert(terrainRun.ModelStreamingMode == Enum.ModelStreamingMode.Atomic
		and facetedRun.ModelStreamingMode == Enum.ModelStreamingMode.Atomic
		and mixedRun.ModelStreamingMode == Enum.ModelStreamingMode.Atomic,
		"Each comparison lane must stream as its own atomic sample")
	local directModelCount = 0
	for _, child in ipairs(samples:GetChildren()) do
		if child:IsA("Model") then
			directModelCount += 1
		end
	end
	assert(directModelCount == 3, "MesaBoundarySampleRuns must contain exactly three direct sample Models")
	samples.PrimaryPart = terrainRun.PrimaryPart
	samples:SetAttribute("BuildStatus", "Ready")
	samples.Parent = parent
	return samples
end

return MesaShapeShowcase
