-- Static comparison pieces for the cliff-shape study.
--
-- Each footprint is a 10-16-sided polygon, filled as a fan of triangles.
-- Every triangle is split at its altitude into two right triangles, then
-- represented by upright WedgeParts. This uses built-in Roblox geometry at
-- runtime and does not depend on uploaded meshes or EditableMesh.
-- Keep this preview in the dev gallery: an exact 10-14 side prism costs about
-- two WedgeParts per side for every stone tier and its fitted grass cap.
local MesaShapeShowcase = {}

local TAU = math.pi * 2
local VERTICAL_EPSILON = 1e-4
local CAP_THICKNESS = 0.28
local CAP_OVERLAP = 0.06

local STONE_MATERIAL = Enum.Material.SmoothPlastic
local GRASS_MATERIAL = Enum.Material.SmoothPlastic
local GRASS_COLOR = Color3.fromRGB(92, 145, 72)

local function horizontal(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function makeOutline(center, radiusX, radiusZ, sideCount, phase)
	local anchor = Vector3.new(
		center.X + radiusX * 0.055,
		0,
		center.Z - radiusZ * 0.075
	)
	local points = table.create(sideCount)
	for index = 1, sideCount do
		local angle = phase + (index - 1) * TAU / sideCount
		local irregularity = 1
			+ 0.075 * math.sin(3 * angle + phase)
			+ 0.045 * math.cos(5 * angle - phase * 0.7)
			+ 0.025 * math.sin(2 * angle - 0.4)
		local shoulder = 1 + 0.035 * math.sin(angle + phase * 0.5)
		points[index] = anchor + Vector3.new(
			math.cos(angle) * radiusX * irregularity,
			0,
			math.sin(angle) * radiusZ * irregularity * shoulder
		)
	end
	return points, anchor
end

-- Keep most vertices close to the regular 12-side rhythm. Three controlled
-- departures add asymmetry: two small radius shifts and one shallow notch.
-- Small fixed angle offsets vary edge lengths without changing vertex order.
local REFINED_RADIAL_SCALES = {
	1.000, 1.035, 0.990, 1.020, 0.965, 0.800,
	0.985, 1.060, 0.970, 1.025, 0.940, 1.020,
}
local REFINED_ANGLE_OFFSETS = {
	0.0, 1.5, -1.2, 0.8, -2.0, 3.2,
	-0.8, -3.4, 1.2, 2.1, -2.5, 0.5,
}

local function makeRefinedOutline(center, radiusX, radiusZ, sideCount, phase)
	assert(sideCount == #REFINED_RADIAL_SCALES, "Refined mesa outline requires 12 sides")
	local anchor = Vector3.new(
		center.X + radiusX * 0.055,
		0,
		center.Z - radiusZ * 0.075
	)
	local points = table.create(sideCount)
	for index = 1, sideCount do
		local baseAngle = phase + (index - 1) * TAU / sideCount
		local angle = baseAngle + math.rad(REFINED_ANGLE_OFFSETS[index])
		local radius = REFINED_RADIAL_SCALES[index]
		local shoulder = 1 + 0.012 * math.sin(baseAngle + phase * 0.5)
		points[index] = anchor + Vector3.new(
			math.cos(angle) * radiusX * radius,
			0,
			math.sin(angle) * radiusZ * radius * shoulder
		)
	end
	return points, anchor
end

local function scaleOutline(points, anchor, scale)
	local scaled = table.create(#points)
	for index, point in ipairs(points) do
		scaled[index] = anchor + (point - anchor) * scale
	end
	return scaled
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

local function makeWedge(parent, name, rightCorner, endpointA, endpointB, bottomY, height, color, material)
	local legA = horizontal(endpointA - rightCorner)
	local legB = horizontal(endpointB - rightCorner)
	local lengthA = legA.Magnitude
	local lengthB = legB.Magnitude
	if lengthA <= VERTICAL_EPSILON or lengthB <= VERTICAL_EPSILON or height <= VERTICAL_EPSILON then
		return nil
	end

	-- Roblox WedgePart's six local vertices are:
	-- (-X/2,+Y/2,+Z/2), (-X/2,-Y/2,-Z/2), (-X/2,-Y/2,+Z/2),
	-- (+X/2,-Y/2,+Z/2), (+X/2,-Y/2,-Z/2), (+X/2,+Y/2,+Z/2).
	-- Its extrusion runs along local X; the right-angle corner is local
	-- (0,-Y/2,+Z/2), with legs along +Y and -Z. Orient local X vertically
	-- and use the two footprint legs for local Y and Z.
	local yAxis = legA.Unit
	local zAxis = -legB.Unit
	local xAxis = yAxis:Cross(zAxis).Unit
	local localRightCorner = horizontal(rightCorner)
	local partPosition = localRightCorner
		+ yAxis * (lengthA * 0.5)
		- zAxis * (lengthB * 0.5)
	partPosition = Vector3.new(partPosition.X, bottomY + height * 0.5, partPosition.Z)

	local wedge = Instance.new("WedgePart")
	wedge.Size = Vector3.new(height, lengthA, lengthB)
	wedge.CFrame = CFrame.fromMatrix(partPosition, xAxis, yAxis, zAxis)
	stylePart(wedge, color, material, name)
	wedge.Parent = parent
	return wedge
end

local function angleCosineAt(vertex, otherA, otherB)
	local toA = horizontal(otherA - vertex)
	local toB = horizontal(otherB - vertex)
	local denominator = toA.Magnitude * toB.Magnitude
	if denominator <= VERTICAL_EPSILON then
		return 1
	end
	return math.clamp(toA:Dot(toB) / denominator, -1, 1)
end

local function createTrianglePrism(parent, name, pA, pB, pC, bottomY, height, color, material)
	local candidates = {
		{ Apex = pA, BaseA = pB, BaseB = pC, Cosine = angleCosineAt(pA, pB, pC) },
		{ Apex = pB, BaseA = pC, BaseB = pA, Cosine = angleCosineAt(pB, pC, pA) },
		{ Apex = pC, BaseA = pA, BaseB = pB, Cosine = angleCosineAt(pC, pA, pB) },
	}
	table.sort(candidates, function(left, right)
		return left.Cosine < right.Cosine
	end)
	local triangle = candidates[1]
	local baseDirection = horizontal(triangle.BaseB - triangle.BaseA)
	local baseLengthSquared = baseDirection:Dot(baseDirection)
	if baseLengthSquared <= VERTICAL_EPSILON then
		return
	end
	local projection = horizontal(triangle.Apex - triangle.BaseA):Dot(baseDirection) / baseLengthSquared
	local foot = triangle.BaseA + baseDirection * math.clamp(projection, 0, 1)

	makeWedge(parent, name .. "_A", foot, triangle.Apex, triangle.BaseA, bottomY, height, color, material)
	makeWedge(parent, name .. "_B", foot, triangle.Apex, triangle.BaseB, bottomY, height, color, material)
end

local function createPolygonPrism(parent, name, points, interiorAnchor, bottomY, height, color, material)
	for index = 1, #points do
		local nextIndex = if index == #points then 1 else index + 1
		createTrianglePrism(
			parent,
			string.format("%s_Sector%02d", name, index),
			interiorAnchor,
			points[index],
			points[nextIndex],
			bottomY,
			height,
			color,
			material
		)
	end
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
	anchor:SetAttribute("WorldDecoration", "MesaShapeShowcase")
	anchor.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = name
	billboard.Adornee = anchor
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 350
	billboard.Size = UDim2.fromOffset(width or 220, 62)
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(31, 42, 42)
	label.BackgroundTransparency = 0.12
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = Color3.fromRGB(239, 242, 224)
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

local function createFormation(parent, origin, name, config, outlineFactory)
	local formation = Instance.new("Model")
	formation.Name = name
	markModel(formation, config.Kind)
	formation:SetAttribute("FootprintSides", config.SideCount)
	formation:SetAttribute("NominalRadius", config.NominalRadius)
	formation:SetAttribute("PeakHeight", config.TotalHeight)

	local center = origin + Vector3.new(config.OffsetX or 0, 0, config.OffsetZ or 0)
	local baseOutline, anchor = (outlineFactory or makeOutline)(
		center,
		config.RadiusX,
		config.RadiusZ,
		config.SideCount,
		config.Phase or 0
	)
	local currentY = origin.Y
	local currentOutline = baseOutline
	for layerIndex, layer in ipairs(config.Layers) do
		local layerOutline = scaleOutline(baseOutline, anchor, layer.Scale)
		createPolygonPrism(
			formation,
			string.format("%s_Layer%02d", name, layerIndex),
			layerOutline,
			anchor,
			currentY,
			layer.Height,
			layer.Color,
			STONE_MATERIAL
		)
		currentY += layer.Height
		currentOutline = layerOutline
	end

	local capOutline = scaleOutline(currentOutline, anchor, config.CapScale or 0.92)
	createPolygonPrism(
		formation,
		name .. "_GrassCap",
		capOutline,
		anchor,
		currentY - CAP_OVERLAP,
		CAP_THICKNESS,
		GRASS_COLOR,
		GRASS_MATERIAL
	)
	local grassTopY = currentY - CAP_OVERLAP + CAP_THICKNESS
	if config.Label then
		local labelAnchor = createLabel(
			formation,
			"SampleLabel",
			Vector3.new(anchor.X, grassTopY + 3.1, anchor.Z),
			config.Label,
			config.LabelWidth
		)
		formation.PrimaryPart = labelAnchor
	end
	formation.Parent = parent
	return formation
end

local COMPARISON_SHAPES = {
	{
		Name = "BroadMesa",
		Kind = "BroadMesa",
		Label = "BROAD MESA\n12 SIDES / r20",
		SideCount = 12,
		NominalRadius = 20,
		RadiusX = 20,
		RadiusZ = 18,
		OffsetX = -55,
		OffsetZ = 0,
		Phase = 0.2,
		TotalHeight = 26,
		LabelWidth = 210,
		Layers = {
			{ Scale = 1, Height = 26, Color = Color3.fromRGB(105, 114, 118) },
		},
		CapScale = 0.93,
	},
	{
		Name = "TallColumn",
		Kind = "TallColumn",
		Label = "TALL COLUMN\n12 SIDES / r15",
		SideCount = 12,
		NominalRadius = 15,
		RadiusX = 15.5,
		RadiusZ = 14.5,
		OffsetX = 0,
		OffsetZ = 1.2,
		Phase = 0.58,
		TotalHeight = 42,
		LabelWidth = 210,
		Layers = {
			{ Scale = 1, Height = 42, Color = Color3.fromRGB(111, 119, 123) },
		},
		CapScale = 0.91,
	},
	{
		Name = "WideTerraces",
		Kind = "WideTerraces",
		Label = "WIDE TERRACES\n12 SIDES / r24 → r19 → r14",
		SideCount = 12,
		NominalRadius = 24,
		RadiusX = 23,
		RadiusZ = 21,
		OffsetX = 58,
		OffsetZ = -0.8,
		Phase = 0.93,
		TotalHeight = 27,
		LabelWidth = 250,
		Layers = {
			{ Scale = 1, Height = 9, Color = Color3.fromRGB(97, 108, 113) },
			{ Scale = 0.79, Height = 9, Color = Color3.fromRGB(109, 117, 119) },
			{ Scale = 0.58, Height = 9, Color = Color3.fromRGB(122, 128, 126) },
		},
		CapScale = 0.91,
	},
}

function MesaShapeShowcase.Create(parent, origin)
	assert(parent ~= nil, "MesaShapeShowcase.Create requires a parent")
	assert(typeof(origin) == "Vector3", "MesaShapeShowcase.Create requires a Vector3 origin")

	local showcase = Instance.new("Model")
	showcase.Name = "MesaShapeShowcase"
	markModel(showcase, "SideBySideComparison")
	showcase:SetAttribute("SampleCount", #COMPARISON_SHAPES)

	for _, config in ipairs(COMPARISON_SHAPES) do
		createFormation(showcase, origin, config.Name, config)
	end
	showcase.Parent = parent
	return showcase
end

function MesaShapeShowcase.CreateRefinedPair(parent, origin)
	assert(parent ~= nil, "MesaShapeShowcase.CreateRefinedPair requires a parent")
	assert(typeof(origin) == "Vector3", "MesaShapeShowcase.CreateRefinedPair requires a Vector3 origin")

	local comparison = Instance.new("Model")
	comparison.Name = "MesaIrregularComparison"
	markModel(comparison, "CleanVsRefined")
	comparison:SetAttribute("SampleCount", 2)
	comparison:SetAttribute("GeometricRhythmPercent", 70)

	local shared = {
		SideCount = 12,
		NominalRadius = 16,
		RadiusX = 16,
		RadiusZ = 16,
		Phase = 0.18,
		TotalHeight = 22,
		LabelWidth = 270,
		Layers = {
			{ Scale = 1, Height = 22, Color = Color3.fromRGB(105, 114, 118) },
		},
		CapScale = 0.93,
	}
	local clean = table.clone(shared)
	clean.Name = "CleanPrismControl"
	clean.Kind = "CleanPrismControl"
	clean.Label = "CURRENT PRISM\n12 SIDES / SMOOTH RADIUS"
	clean.OffsetX = -21
	createFormation(comparison, origin, clean.Name, clean)

	local refined = table.clone(shared)
	refined.Name = "RefinedIrregularMesa"
	refined.Kind = "RefinedIrregularMesa"
	refined.Label = "REFINED MESA\n70% GEOMETRIC / NOTCH"
	refined.OffsetX = 21
	refined.Layers = {
		{ Scale = 1, Height = 14, Color = Color3.fromRGB(105, 114, 118) },
		{ Scale = 0.94, Height = 8, Color = Color3.fromRGB(105, 114, 118) },
	}
	refined.CapScale = 0.98
	createFormation(comparison, origin, refined.Name, refined, makeRefinedOutline)

	comparison.Parent = parent
	return comparison
end

local function makeClusterConfig(name, kind, label, offsetX, offsetZ, radiusX, radiusZ, sideCount, phase, layers, capScale)
	local height = 0
	for _, layer in ipairs(layers) do
		height += layer.Height
	end
	return {
		Name = name,
		Kind = kind,
		Label = label,
		SideCount = sideCount,
		NominalRadius = math.max(radiusX, radiusZ),
		RadiusX = radiusX,
		RadiusZ = radiusZ,
		OffsetX = offsetX,
		OffsetZ = offsetZ,
		Phase = phase,
		TotalHeight = height,
		Layers = layers,
		CapScale = capScale or 0.91,
		LabelWidth = 250,
	}
end

local CLUSTERED_SHAPES = {
	makeClusterConfig("WestOutcrop", "ClusteredOutcrop", nil, -49, 10, 22, 19, 10, 0.36, {
		{ Scale = 1, Height = 23, Color = Color3.fromRGB(110, 118, 120) },
	}),
	makeClusterConfig("LargeAnchor", "LargeAnchor", nil, 0, 0, 34, 28, 12, 0.13, {
		{ Scale = 1, Height = 42, Color = Color3.fromRGB(102, 111, 116) },
	}),
	makeClusterConfig("TallShoulder", "ClusteredColumn", nil, 48, 13, 23, 18, 10, 0.74, {
		{ Scale = 1, Height = 32, Color = Color3.fromRGB(111, 119, 123) },
	}),
	makeClusterConfig("EastOutcrop", "ClusteredOutcrop", nil, 84, -5, 18, 16, 10, 1.11, {
		{ Scale = 1, Height = 20, Color = Color3.fromRGB(116, 123, 122) },
	}),
}

function MesaShapeShowcase.CreateClusteredSegment(parent, origin)
	assert(parent ~= nil, "MesaShapeShowcase.CreateClusteredSegment requires a parent")
	assert(typeof(origin) == "Vector3", "MesaShapeShowcase.CreateClusteredSegment requires a Vector3 origin")

	local segment = Instance.new("Model")
	segment.Name = "MesaClusteredBoundaryStudy"
	markModel(segment, "ClusteredBoundarySection")
	segment:SetAttribute("SampleCount", #CLUSTERED_SHAPES)
	segment:SetAttribute("LargeAnchorNominalRadius", 34)

	for _, config in ipairs(CLUSTERED_SHAPES) do
		createFormation(segment, origin, config.Name, config)
	end
	createLabel(
		segment,
		"ClusteredSectionLabel",
		origin + Vector3.new(8, 49, -37),
		"CLUSTERED CLIFF SECTION\n34-STUD ANCHOR + SUPPORTING OUTCROPS",
		320
	)
	segment.Parent = parent
	return segment
end

return MesaShapeShowcase
