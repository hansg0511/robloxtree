-- Studio-gallery studies inspired by the project's Terrain and Border references.
-- The footprints, profiles, facets, and colors are generated here; no reference
-- Workspace geometry or uploaded mesh assets are copied into the showcase.
local MesaShapeShowcase = {}

local TAU = math.pi * 2
local EPSILON = 1e-4
local LAYER_OVERLAP = 0.025
local SHELL_THICKNESS = 1.1
local CAP_OVERLAP = 0.08

local ROCK_MATERIAL = Enum.Material.SmoothPlastic
local GRASS_MATERIAL = Enum.Material.SmoothPlastic
local GRASS_COLOR = Color3.fromRGB(70, 158, 54)

-- Blocky, nearly square contours with clipped and uneven corners. The long
-- faces and broad X/Z proportions keep the plateau from reading as a cylinder.
local TERRAIN_CONTOUR = {
	{ -0.90, -0.62 }, { -0.25, -1.00 }, { 0.61, -0.94 }, { 1.00, -0.44 },
	{ 0.92, 0.55 }, { 0.38, 0.98 }, { -0.54, 0.91 }, { -1.00, 0.28 },
}

-- A separate, unequal 10-facet profile for the narrower Border-like pillar.
local BORDER_CONTOUR = {
	{ 1.00, 0.16 }, { 0.77, 0.73 }, { 0.25, 1.00 }, { -0.34, 0.94 },
	{ -0.88, 0.62 }, { -1.00, -0.14 }, { -0.68, -0.84 }, { 0.02, -1.00 },
	{ 0.79, -0.72 }, { 1.00, -0.10 },
}

local BORDER_UPPER_VERTEX_SCALES = {
	1.02, 0.97, 1.04, 0.96, 1.02, 0.95, 1.01, 1.04, 0.95, 1.02,
}

local function horizontal(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function makeOutline(center, radiusX, radiusZ, phase, contour)
	local points = table.create(#contour)
	for index, normalized in ipairs(contour) do
		local wobble = 1
			+ 0.035 * math.sin(index * 1.73 + phase)
			+ 0.022 * math.cos(index * 2.41 - phase * 0.7)
		local x = normalized[1] * radiusX * wobble
		local z = normalized[2] * radiusZ * wobble
		local angle = phase * 0.06
		local rotatedX = x * math.cos(angle) - z * math.sin(angle)
		local rotatedZ = x * math.sin(angle) + z * math.cos(angle)
		points[index] = center + Vector3.new(rotatedX, 0, rotatedZ)
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

local function shadeColor(color, factor)
	return Color3.new(
		math.clamp(color.R * factor, 0, 1),
		math.clamp(color.G * factor, 0, 1),
		math.clamp(color.B * factor, 0, 1)
	)
end

local FACET_FACTORS = { 0.84, 1.06, 0.91, 1.13, 0.94, 1.02, 0.82, 1.09, 0.96, 1.04 }

local function facetColor(color, sideIndex)
	return shadeColor(color, FACET_FACTORS[(sideIndex - 1) % #FACET_FACTORS + 1])
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
	part:SetAttribute("WorldDecoration", "MesaShapeShowcase")
	return part
end

-- Built-in WedgeParts fill a right triangle in their local Y/Z plane and
-- extrude along local X. Here that plane is the intended horizontal footprint.
local function makeFootprintWedge(parent, name, rightCorner, endpointA, endpointB, bottomY, height, color, material)
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
	stylePart(wedge, color, material, name)
	wedge.Parent = parent
	return wedge
end

local function createFootprintTriangle(parent, name, pointA, pointB, pointC, bottomY, height, color, material)
	local candidates = {
		{ Apex = pointA, BaseA = pointB, BaseB = pointC },
		{ Apex = pointB, BaseA = pointC, BaseB = pointA },
		{ Apex = pointC, BaseA = pointA, BaseB = pointB },
	}
	for _, candidate in ipairs(candidates) do
		local first = horizontal(candidate.BaseA - candidate.Apex)
		local second = horizontal(candidate.BaseB - candidate.Apex)
		local denominator = first.Magnitude * second.Magnitude
		candidate.Cosine = denominator <= EPSILON and 1 or math.clamp(first:Dot(second) / denominator, -1, 1)
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
	projection = math.clamp(projection, 0, 1)
	local foot = triangle.BaseA + baseDirection * projection

	local count = 0
	if makeFootprintWedge(parent, name .. "_A", foot, triangle.Apex, triangle.BaseA,
		bottomY, height, color, material) then
		count += 1
	end
	if makeFootprintWedge(parent, name .. "_B", foot, triangle.Apex, triangle.BaseB,
		bottomY, height, color, material) then
		count += 1
	end
	return count
end

local function createPolygonPrism(parent, name, points, interiorAnchor, bottomY, height, color, material, faceted)
	local partCount = 0
	for index = 1, #points do
		local nextIndex = if index == #points then 1 else index + 1
		local partColor = if faceted then facetColor(color, index) else color
		partCount += createFootprintTriangle(
			parent,
			string.format("%s_Facet%02d", name, index),
			interiorAnchor,
			points[index],
			points[nextIndex],
			bottomY,
			height,
			partColor,
			material
		)
	end
	return partCount
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

-- A thin triangular WedgePart panel. Unlike the footprint helper above, this
-- keeps the full 3D panel plane so the visible outside face slopes inward.
local function makeSlopePanel(parent, name, rightCorner, endpointA, endpointB, color, material)
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
	wedge.Size = Vector3.new(SHELL_THICKNESS, lengthA, lengthB)
	wedge.CFrame = CFrame.fromMatrix(partPosition, xAxis, yAxis, zAxis)
	stylePart(wedge, color, material, name)
	wedge.Parent = parent
	return wedge
end

local function createSlopeTriangle(parent, name, pointA, pointB, pointC, color, material)
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
	if makeSlopePanel(parent, name .. "_A", foot, triangle.Apex, triangle.BaseA, color, material) then
		count += 1
	end
	if makeSlopePanel(parent, name .. "_B", foot, triangle.Apex, triangle.BaseB, color, material) then
		count += 1
	end
	return count
end

local function createSlopedPrism(parent, name, lowerOutline, upperOutline, anchor, bottomY, height, color, faceted)
	assert(#lowerOutline == #upperOutline, "Tapered rings must have matching vertex counts")
	local partCount = createPolygonPrism(
		parent,
		name .. "_InnerCore",
		upperOutline,
		anchor,
		bottomY,
		height,
		color,
		ROCK_MATERIAL,
		faceted
	)

	for index = 1, #lowerOutline do
		local nextIndex = if index == #lowerOutline then 1 else index + 1
		local lowerA = Vector3.new(lowerOutline[index].X, bottomY, lowerOutline[index].Z)
		local lowerB = Vector3.new(lowerOutline[nextIndex].X, bottomY, lowerOutline[nextIndex].Z)
		local upperA = Vector3.new(upperOutline[index].X, bottomY + height, upperOutline[index].Z)
		local upperB = Vector3.new(upperOutline[nextIndex].X, bottomY + height, upperOutline[nextIndex].Z)
		local sideColor = if faceted then facetColor(color, index) else color
		partCount += createSlopeTriangle(
			parent,
			string.format("%s_Slope%02d_1", name, index),
			lowerA,
			lowerB,
			upperB,
			sideColor,
			ROCK_MATERIAL
		)
		partCount += createSlopeTriangle(
			parent,
			string.format("%s_Slope%02d_2", name, index),
			lowerA,
			upperB,
			upperA,
			sideColor,
			ROCK_MATERIAL
		)
	end
	return partCount
end

local function markModel(model, kind)
	model:SetAttribute("DevOnly", true)
	model:SetAttribute("VisualOnly", true)
	model:SetAttribute("ShowcaseOnly", true)
	model:SetAttribute("WorldDecoration", "MesaShapeShowcase")
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
	anchor:SetAttribute("WorldDecoration", "MesaShapeShowcaseLabel")
	anchor.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = name
	billboard.Adornee = anchor
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 220
	billboard.Size = UDim2.fromOffset(width, 54)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(35, 44, 34)
	label.BackgroundTransparency = 0.08
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = Color3.fromRGB(244, 239, 211)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = billboard

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 9)
	padding.PaddingRight = UDim.new(0, 9)
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingBottom = UDim.new(0, 5)
	padding.Parent = label
	return anchor
end

local function createFormation(parent, origin, config)
	local formation = Instance.new("Model")
	formation.Name = config.Name
	markModel(formation, config.Kind)
	formation:SetAttribute("FootprintSides", #config.Contour)
	formation:SetAttribute("PeakHeight", config.TotalHeight)
	formation:SetAttribute("Profile", config.ProfileName)

	local center = origin + Vector3.new(config.OffsetX, 0, config.OffsetZ)
	local baseOutline, anchor = makeOutline(
		center,
		config.RadiusX,
		config.RadiusZ,
		config.Phase,
		config.Contour
	)
	local currentY = origin.Y
	local currentOutline = baseOutline
	local currentScale = 1
	local layerCount = 0
	local generatedPartCount = 0

	for layerIndex, layer in ipairs(config.Layers) do
		local nextScale = layer.TopScale
		local nextOutline = scaleOutline(baseOutline, anchor, nextScale, layer.VertexScales)
		local layerBottom = currentY - (if layerIndex > 1 then LAYER_OVERLAP else 0)
		local layerHeight = layer.Height + (if layerIndex > 1 then LAYER_OVERLAP else 0)
		generatedPartCount += createSlopedPrism(
			formation,
			string.format("%s_Band%02d", config.Name, layerIndex),
			currentOutline,
			nextOutline,
			anchor,
			layerBottom,
			layerHeight,
			layer.Color,
			config.Faceted == true
		)
		currentY += layer.Height
		currentOutline = nextOutline
		currentScale = nextScale
		layerCount += 1
	end

	local capOutline = makeCapOutline(
		currentOutline,
		anchor,
		config.CapScale,
		config.Phase,
		config.CapVariation
	)
	generatedPartCount += createPolygonPrism(
		formation,
		config.Name .. "_GrassCap",
		capOutline,
		anchor,
		currentY - CAP_OVERLAP,
		config.CapThickness,
		GRASS_COLOR,
		GRASS_MATERIAL,
		false
	)
	formation:SetAttribute("GeneratedPartCount", generatedPartCount)
	formation:SetAttribute("LayerCount", layerCount)
	formation:SetAttribute("LastProfileScale", currentScale)
	formation.Parent = parent
	return formation, currentY - CAP_OVERLAP + config.CapThickness
end

local TERRAIN_MASSES = {
	{
		Name = "MainPlateauMass",
		Kind = "TerrainPlateauMass",
		ProfileName = "BroadIrregularCliff",
		Contour = TERRAIN_CONTOUR,
		RadiusX = 30,
		RadiusZ = 21,
		OffsetX = -44,
		OffsetZ = 0,
		Phase = 0.35,
		TotalHeight = 25,
		Layers = {
			{ TopScale = 0.78, Height = 25, Color = Color3.fromRGB(79, 33, 24) },
		},
		CapScale = 1.02,
		CapVariation = 0.025,
		CapThickness = 0.85,
		Faceted = true,
	},
	{
		Name = "WestOutcropMass",
		Kind = "TerrainOutcropMass",
		ProfileName = "LowBlockyOutcrop",
		Contour = TERRAIN_CONTOUR,
		RadiusX = 18,
		RadiusZ = 14,
		OffsetX = -77,
		OffsetZ = -3,
		Phase = 1.1,
		TotalHeight = 18,
		Layers = {
			{ TopScale = 0.75, Height = 18, Color = Color3.fromRGB(91, 39, 27) },
		},
		CapScale = 1.02,
		CapVariation = 0.025,
		CapThickness = 0.85,
		Faceted = true,
	},
	{
		Name = "EastShoulderMass",
		Kind = "TerrainShoulderMass",
		ProfileName = "RaisedBlockyOutcrop",
		Contour = TERRAIN_CONTOUR,
		RadiusX = 20,
		RadiusZ = 16,
		OffsetX = -3,
		OffsetZ = 8,
		Phase = 2.0,
		TotalHeight = 27,
		Layers = {
			{ TopScale = 0.64, Height = 27, Color = Color3.fromRGB(73, 30, 23) },
		},
		CapScale = 1.02,
		CapVariation = 0.025,
		CapThickness = 0.85,
		Faceted = true,
	},
}

local BORDER_PILLAR = {
	Name = "BorderLikePillar",
	Kind = "BorderReferenceStudy",
	ProfileName = "ThreeUnequalTaperedBands",
	Contour = BORDER_CONTOUR,
	RadiusX = 21,
	RadiusZ = 17,
	OffsetX = 60,
	OffsetZ = 0,
	Phase = 0.72,
	TotalHeight = 40,
	Layers = {
		{ TopScale = 0.84, Height = 13, VertexScales = BORDER_UPPER_VERTEX_SCALES, Color = Color3.fromRGB(83, 37, 26) },
		{ TopScale = 0.68, Height = 16, VertexScales = BORDER_UPPER_VERTEX_SCALES, Color = Color3.fromRGB(126, 70, 42) },
		{ TopScale = 0.54, Height = 11, VertexScales = BORDER_UPPER_VERTEX_SCALES, Color = Color3.fromRGB(161, 108, 60) },
	},
	CapScale = 1.21,
	CapVariation = 0.07,
	CapThickness = 3.4,
	Faceted = true,
}

function MesaShapeShowcase.Create(parent, origin)
	assert(parent ~= nil, "MesaShapeShowcase.Create requires a parent")
	assert(typeof(origin) == "Vector3", "MesaShapeShowcase.Create requires a Vector3 origin")

	local showcase = Instance.new("Model")
	showcase.Name = "MesaShapeShowcase"
	showcase.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	markModel(showcase, "TerrainAndBorderReferenceStudies")
	showcase:SetAttribute("SampleCount", 2)

	local terrain = Instance.new("Model")
	terrain.Name = "TerrainLikePlateau"
	markModel(terrain, "BroadClusteredTerrainPlateau")
	terrain:SetAttribute("MassCount", #TERRAIN_MASSES)
	local highestTerrainTop = origin.Y
	for _, config in ipairs(TERRAIN_MASSES) do
		local _, topY = createFormation(terrain, origin, config)
		highestTerrainTop = math.max(highestTerrainTop, topY)
	end
	local terrainCenter = Vector3.new(origin.X - 43, highestTerrainTop + 3.1, origin.Z)
	terrain.PrimaryPart = createLabel(
		terrain,
		"TerrainStudyLabel",
		terrainCenter,
		"TERRAIN-INSPIRED\nBROAD CLUSTERED PLATEAU",
		300
	)
	terrain.Parent = showcase

	local border, borderTopY = createFormation(showcase, origin, BORDER_PILLAR)
	border.Name = "BorderLikePillar"
	border:SetAttribute("StudyLabel", "BORDER-INSPIRED - TAPERED FACETED PILLAR")
	local borderCenter = Vector3.new(
		origin.X + BORDER_PILLAR.OffsetX,
		borderTopY + 3.1,
		origin.Z + BORDER_PILLAR.OffsetZ
	)
	border.PrimaryPart = createLabel(
		border,
		"BorderStudyLabel",
		borderCenter,
		"BORDER-INSPIRED\nTAPERED FACETED PILLAR",
		280
	)

	showcase.Parent = parent
	return showcase
end

return MesaShapeShowcase
