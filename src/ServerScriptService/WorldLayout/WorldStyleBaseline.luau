-- World 1's light stylized palette, boundary geometry, and walk-up style samples.
-- Kept separate from route configuration so future worlds can replace the visual
-- language without changing progression or tree records.
local WorldStyleBaseline = {}

local BASELINE = {
	GroundMaterial = Enum.Material.SmoothPlastic,
	GroundColor = Color3.fromRGB(119, 181, 99),
	ForestColor = Color3.fromRGB(128, 190, 104),
	HubColor = Color3.fromRGB(225, 201, 145),
	PathColor = Color3.fromRGB(244, 207, 125),
	BoundaryColors = {
		Color3.fromRGB(96, 149, 91), -- shadow
		Color3.fromRGB(120, 174, 106), -- cliff body
		Color3.fromRGB(148, 195, 122), -- highlight
	},
	WoodColors = {
		Shadow = Color3.fromRGB(77, 55, 39),
		Main = Color3.fromRGB(112, 78, 49),
		Highlight = Color3.fromRGB(177, 129, 65),
	},
}

-- Keep the existing progression barrier flanks visually unchanged while the
-- surrounding World 1 boundary palette is refined.
local PROTECTED_BARRIER_COLORS = {
	Color3.fromRGB(104, 158, 101),
	Color3.fromRGB(126, 178, 111),
	Color3.fromRGB(150, 196, 125),
}

-- Ordinary World 1 boundaries use smooth toy-like stone with grass-colored caps.
-- The stone peaks are cosmetic: the full-height wall remains the sole
-- collision barrier, so these variations cannot create steps or a bypass.
local STONE_CORE_COLOR = Color3.fromRGB(100, 108, 112)
local STONE_COURSE_COLORS = {
	Color3.fromRGB(130, 137, 140),
	Color3.fromRGB(116, 124, 128),
	Color3.fromRGB(142, 148, 150),
}
local STONE_PEAK_COLORS = {
	Color3.fromRGB(109, 117, 121),
	Color3.fromRGB(121, 129, 132),
	Color3.fromRGB(96, 104, 108),
}
local GRASS_CAP_COLOR = Color3.fromRGB(100, 151, 79)
local WALL_TOP_HEIGHTS = {
	24, 24, 28, 28, 25, 24, 24, 29, 29, 26,
	24, 24, 27, 27, 24, 24, 29, 29, 25, 24,
}

-- The existing forest entrances and trail signs share these World 1 accents.
WorldStyleBaseline.WoodColors = BASELINE.WoodColors

local SAMPLE_STYLES = {
	BrightSimulator = {
		Title = "BRIGHT SIMULATOR",
		GroundMaterial = Enum.Material.Grass,
		PathMaterial = Enum.Material.Sand,
		BoundaryMaterial = Enum.Material.SmoothPlastic,
		BoundaryForm = "SoftCliff",
		GroundColor = Color3.fromRGB(126, 192, 105),
		PathColor = Color3.fromRGB(250, 216, 135),
		BoundaryColors = {
			Color3.fromRGB(102, 157, 98),
			Color3.fromRGB(127, 180, 109),
			Color3.fromRGB(157, 202, 128),
		},
		FoliageColor = Color3.fromRGB(91, 177, 112),
		AccentColor = Color3.fromRGB(255, 174, 91),
		SignColor = Color3.fromRGB(45, 91, 73),
		SignTextColor = Color3.fromRGB(255, 242, 197),
	},
	ChunkyBrick = {
		Title = "CHUNKY BRICK",
		GroundMaterial = Enum.Material.SmoothPlastic,
		PathMaterial = Enum.Material.Plastic,
		BoundaryMaterial = Enum.Material.Brick,
		BoundaryForm = "SteppedBlocks",
		GroundColor = Color3.fromRGB(118, 178, 112),
		PathColor = Color3.fromRGB(231, 177, 108),
		BoundaryColors = {
			Color3.fromRGB(148, 102, 70),
			Color3.fromRGB(177, 126, 82),
			Color3.fromRGB(211, 157, 93),
		},
		FoliageColor = Color3.fromRGB(104, 166, 99),
		AccentColor = Color3.fromRGB(244, 201, 92),
		SignColor = Color3.fromRGB(83, 57, 44),
		SignTextColor = Color3.fromRGB(255, 235, 190),
	},
	LightWhimsy = {
		Title = "LIGHT WHIMSY",
		GroundMaterial = Enum.Material.SmoothPlastic,
		PathMaterial = Enum.Material.SmoothPlastic,
		BoundaryMaterial = Enum.Material.SmoothPlastic,
		BoundaryForm = "MushroomRidge",
		GroundColor = Color3.fromRGB(139, 199, 160),
		PathColor = Color3.fromRGB(237, 190, 216),
		BoundaryColors = {
			Color3.fromRGB(105, 145, 166),
			Color3.fromRGB(130, 169, 190),
			Color3.fromRGB(166, 192, 209),
		},
		FoliageColor = Color3.fromRGB(103, 180, 148),
		AccentColor = Color3.fromRGB(245, 174, 207),
		SignColor = Color3.fromRGB(54, 75, 101),
		SignTextColor = Color3.fromRGB(244, 247, 255),
	},
}

local function markWorldPart(part, attributeName)
	part:SetAttribute("WorldLayoutOwned", true)
	if attributeName then
		part:SetAttribute(attributeName, true)
	end
	return part
end

local function createPart(parent, name, size, cframe, color, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	part.Parent = parent
	return part
end

function WorldStyleBaseline.ApplyGround(part, role)
	if not part or not part:IsA("BasePart") then
		return false
	end

	local color = BASELINE.GroundColor
	if role == "HubGround" or role == "Hub" then
		color = BASELINE.HubColor
	elseif role == "ForestGround" or role == "Forest" then
		color = BASELINE.ForestColor
	elseif role == "Path" then
		color = BASELINE.PathColor
	end

	-- These visual properties intentionally leave size, position, anchoring, and
	-- collision untouched. BaseGround remains the existing physical world shell.
	part.Material = BASELINE.GroundMaterial
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return true
end

local function markBoundary(part)
	markWorldPart(part, "WorldBoundary")
	part:SetAttribute("BoundaryStyle", "World1Baseline")
	return part
end

local function markCosmeticBoundary(part)
	markBoundary(part)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	return part
end

local function getPeakPhase(name)
	local phase = 0
	for index = 1, #name do
		phase = (phase + string.byte(name, index)) % #WALL_TOP_HEIGHTS
	end
	return phase
end

local function getPeakHeight(index, phase, coreHeight)
	local targetHeight = WALL_TOP_HEIGHTS[((index + phase - 1) % #WALL_TOP_HEIGHTS) + 1]
	return math.max(0, targetHeight - coreHeight)
end

local function createLayeredRunZ(parent, name, x, startZ, endZ, thickness, requestedHeight, floorY, interiorSide)
	if type(x) ~= "number" or type(startZ) ~= "number" or type(endZ) ~= "number" then
		return
	end

	local length = math.abs(endZ - startZ)
	if length <= 0 then
		return
	end

	local direction = endZ >= startZ and 1 or -1
	local segmentCount = math.max(1, math.ceil(length / 28))
	local segmentLength = length / segmentCount
	local wallThickness = math.max(10, thickness or 12)
	local nominalHeight = math.min(24, math.max(22, requestedHeight or 24))
	local phase = getPeakPhase(name)
	local sides = interiorSide == 0 and { -1, 1 } or { interiorSide or 1 }

	for index = 1, segmentCount do
		local segmentStart = startZ + direction * (index - 1) * segmentLength
		local segmentEnd = startZ + direction * index * segmentLength
		local centerZ = (segmentStart + segmentEnd) * 0.5
		local coreHeight = math.min(25, nominalHeight + (index % 4) * 0.6)
		local peakHeight = getPeakHeight(index, phase, coreHeight)
		local core = createPart(
			parent,
			name .. string.format("%02dCore", index),
			Vector3.new(wallThickness, coreHeight, segmentLength + 0.8),
			CFrame.new(x, floorY + coreHeight * 0.5, centerZ),
			STONE_CORE_COLOR,
			Enum.Material.SmoothPlastic
		)
		core.CanCollide = true
		markBoundary(core)

		-- Face stones alternate between low and high courses along the run. The
		-- overlapping core above is continuous even where these blocks have seams.
		local courseHeight = index % 2 == 0 and 10.5 or 5.0
		local courseOffset = index % 2 == 0 and -segmentLength * 0.05 or segmentLength * 0.05
		for sideIndex, side in ipairs(sides) do
			local course = createPart(
				parent,
				name .. string.format("%02dStoneCourse%d", index, sideIndex),
				Vector3.new(0.5, 3.6, segmentLength * 0.82),
				CFrame.new(x + side * (wallThickness * 0.5 + 0.12), floorY + courseHeight, centerZ + courseOffset),
				STONE_COURSE_COLORS[((index + sideIndex - 2) % #STONE_COURSE_COLORS) + 1],
				Enum.Material.SmoothPlastic
			)
			markCosmeticBoundary(course)
		end

		if peakHeight > 0 then
			local extension = createPart(
				parent,
				name .. string.format("%02dStonePeak", index),
				Vector3.new(wallThickness + 0.6, peakHeight + 0.8, segmentLength + 0.8),
				CFrame.new(x, floorY + coreHeight + (peakHeight - 0.8) * 0.5, centerZ),
				STONE_PEAK_COLORS[((index - 1) % #STONE_PEAK_COLORS) + 1],
				Enum.Material.SmoothPlastic
			)
			markCosmeticBoundary(extension)
		end

		local capHeight = 0.8
		local capTop = floorY + coreHeight + peakHeight + 0.05
		local cap = createPart(
			parent,
			name .. string.format("%02dGrassCap", index),
			Vector3.new(wallThickness + 2.4, capHeight, segmentLength + 0.8),
			CFrame.new(x, capTop - capHeight * 0.5, centerZ),
			GRASS_CAP_COLOR,
			Enum.Material.SmoothPlastic
		)
		markCosmeticBoundary(cap)
	end
end

local function createLayeredRunX(parent, name, startX, endX, z, thickness, requestedHeight, floorY, interiorSide)
	if type(startX) ~= "number" or type(endX) ~= "number" or type(z) ~= "number" then
		return
	end

	local length = math.abs(endX - startX)
	if length <= 0 then
		return
	end

	local direction = endX >= startX and 1 or -1
	local segmentCount = math.max(1, math.ceil(length / 28))
	local segmentLength = length / segmentCount
	local wallThickness = math.max(10, thickness or 12)
	local nominalHeight = math.min(24, math.max(22, requestedHeight or 24))
	local phase = getPeakPhase(name)
	local sides = interiorSide == 0 and { -1, 1 } or { interiorSide or 1 }

	for index = 1, segmentCount do
		local segmentStart = startX + direction * (index - 1) * segmentLength
		local segmentEnd = startX + direction * index * segmentLength
		local centerX = (segmentStart + segmentEnd) * 0.5
		local coreHeight = math.min(25, nominalHeight + (index % 4) * 0.6)
		local peakHeight = getPeakHeight(index, phase, coreHeight)
		local core = createPart(
			parent,
			name .. string.format("%02dCore", index),
			Vector3.new(segmentLength + 0.8, coreHeight, wallThickness),
			CFrame.new(centerX, floorY + coreHeight * 0.5, z),
			STONE_CORE_COLOR,
			Enum.Material.SmoothPlastic
		)
		core.CanCollide = true
		markBoundary(core)

		local courseHeight = index % 2 == 0 and 10.5 or 5.0
		local courseOffset = index % 2 == 0 and -segmentLength * 0.05 or segmentLength * 0.05
		for sideIndex, side in ipairs(sides) do
			local course = createPart(
				parent,
				name .. string.format("%02dStoneCourse%d", index, sideIndex),
				Vector3.new(segmentLength * 0.82, 3.6, 0.5),
				CFrame.new(centerX + courseOffset, floorY + courseHeight, z + side * (wallThickness * 0.5 + 0.12)),
				STONE_COURSE_COLORS[((index + sideIndex - 2) % #STONE_COURSE_COLORS) + 1],
				Enum.Material.SmoothPlastic
			)
			markCosmeticBoundary(course)
		end

		if peakHeight > 0 then
			local extension = createPart(
				parent,
				name .. string.format("%02dStonePeak", index),
				Vector3.new(segmentLength + 0.8, peakHeight + 0.8, wallThickness + 0.6),
				CFrame.new(centerX, floorY + coreHeight + (peakHeight - 0.8) * 0.5, z),
				STONE_PEAK_COLORS[((index - 1) % #STONE_PEAK_COLORS) + 1],
				Enum.Material.SmoothPlastic
			)
			markCosmeticBoundary(extension)
		end

		local capHeight = 0.8
		local capTop = floorY + coreHeight + peakHeight + 0.05
		local cap = createPart(
			parent,
			name .. string.format("%02dGrassCap", index),
			Vector3.new(segmentLength + 0.8, capHeight, wallThickness + 2.4),
			CFrame.new(centerX, capTop - capHeight * 0.5, z),
			GRASS_CAP_COLOR,
			Enum.Material.SmoothPlastic
		)
		markCosmeticBoundary(cap)
	end
end

local function createStyledRunZ(parent, name, x, startZ, endZ, thickness, requestedHeight, floorY, interiorSide, preserveBarrierStyle)
	if not preserveBarrierStyle then
		createLayeredRunZ(parent, name, x, startZ, endZ, thickness, requestedHeight, floorY, interiorSide)
		return
	end

	if type(x) ~= "number" or type(startZ) ~= "number" or type(endZ) ~= "number" then
		return
	end

	local length = math.abs(endZ - startZ)
	if length <= 0 then
		return
	end

	local direction = endZ >= startZ and 1 or -1
	local segmentCount = math.max(1, math.ceil(length / 28))
	local segmentLength = length / segmentCount
	local wallThickness = math.max(10, thickness or 12)
	local boundaryColors = preserveBarrierStyle and PROTECTED_BARRIER_COLORS or BASELINE.BoundaryColors
	local nominalHeight
	local maximumHeight
	if preserveBarrierStyle then
		nominalHeight = math.min(18, math.max(14, requestedHeight or 18))
		maximumHeight = 20
	else
		nominalHeight = math.min(24, math.max(22, requestedHeight or 24))
		maximumHeight = 25
	end

	for index = 1, segmentCount do
		local segmentStart = startZ + direction * (index - 1) * segmentLength
		local segmentEnd = startZ + direction * index * segmentLength
		local centerZ = (segmentStart + segmentEnd) * 0.5
		local capHeight = 2.2 + (index % 3) * 0.7
		local totalHeight = math.min(maximumHeight, nominalHeight + (index % 4) * 0.6)
		local coreHeight = totalHeight - capHeight
		local baseColor = boundaryColors[((index - 1) % #boundaryColors) + 1]
		local capColor = boundaryColors[(index % #boundaryColors) + 1]

		local core = createPart(
			parent,
			name .. string.format("%02dCore", index),
			Vector3.new(wallThickness, coreHeight, segmentLength + 0.8),
			CFrame.new(x, floorY + coreHeight * 0.5, centerZ),
			baseColor,
			Enum.Material.SmoothPlastic
		)
		markBoundary(core)

		local cap = createPart(
			parent,
			name .. string.format("%02dCap", index),
			Vector3.new(wallThickness + 2.4, capHeight, segmentLength * 0.64),
			CFrame.new(x, floorY + coreHeight + capHeight * 0.5 - 0.15, centerZ),
			capColor,
			Enum.Material.SmoothPlastic
		)
		markBoundary(cap)

		-- Alternating low shoulders make the edge read as chunky stepped terrain
		-- while the overlapping core remains a continuous collision boundary.
		if index % 3 == 1 then
			local sides = interiorSide == 0 and { -1, 1 } or { interiorSide or 1 }
			for _, side in ipairs(sides) do
				local shoulder = createPart(
					parent,
					name .. string.format("%02dShoulder", index),
					Vector3.new(wallThickness + 2.8, 2.6, segmentLength * 0.58),
					CFrame.new(x + side * wallThickness * 0.28, floorY + 1.3, centerZ),
					baseColor,
					Enum.Material.SmoothPlastic
				)
				markBoundary(shoulder)
			end
		end
	end
end

local function createStyledRunX(parent, name, startX, endX, z, thickness, requestedHeight, floorY, interiorSide, preserveBarrierStyle)
	if not preserveBarrierStyle then
		createLayeredRunX(parent, name, startX, endX, z, thickness, requestedHeight, floorY, interiorSide)
		return
	end

	if type(startX) ~= "number" or type(endX) ~= "number" or type(z) ~= "number" then
		return
	end

	local length = math.abs(endX - startX)
	if length <= 0 then
		return
	end

	local direction = endX >= startX and 1 or -1
	local segmentCount = math.max(1, math.ceil(length / 28))
	local segmentLength = length / segmentCount
	local wallThickness = math.max(10, thickness or 12)
	local boundaryColors = preserveBarrierStyle and PROTECTED_BARRIER_COLORS or BASELINE.BoundaryColors
	local nominalHeight
	local maximumHeight
	if preserveBarrierStyle then
		nominalHeight = math.min(18, math.max(14, requestedHeight or 18))
		maximumHeight = 20
	else
		nominalHeight = math.min(24, math.max(22, requestedHeight or 24))
		maximumHeight = 25
	end

	for index = 1, segmentCount do
		local segmentStart = startX + direction * (index - 1) * segmentLength
		local segmentEnd = startX + direction * index * segmentLength
		local centerX = (segmentStart + segmentEnd) * 0.5
		local capHeight = 2.2 + (index % 3) * 0.7
		local totalHeight = math.min(maximumHeight, nominalHeight + (index % 4) * 0.6)
		local coreHeight = totalHeight - capHeight
		local baseColor = boundaryColors[((index - 1) % #boundaryColors) + 1]
		local capColor = boundaryColors[(index % #boundaryColors) + 1]

		local core = createPart(
			parent,
			name .. string.format("%02dCore", index),
			Vector3.new(segmentLength + 0.8, coreHeight, wallThickness),
			CFrame.new(centerX, floorY + coreHeight * 0.5, z),
			baseColor,
			Enum.Material.SmoothPlastic
		)
		markBoundary(core)

		local cap = createPart(
			parent,
			name .. string.format("%02dCap", index),
			Vector3.new(segmentLength * 0.64, capHeight, wallThickness + 2.4),
			CFrame.new(centerX, floorY + coreHeight + capHeight * 0.5 - 0.15, z),
			capColor,
			Enum.Material.SmoothPlastic
		)
		markBoundary(cap)

		if index % 3 == 1 then
			local sides = interiorSide == 0 and { -1, 1 } or { interiorSide or 1 }
			for _, side in ipairs(sides) do
				local shoulder = createPart(
					parent,
					name .. string.format("%02dShoulder", index),
					Vector3.new(segmentLength * 0.58, 2.6, wallThickness + 2.8),
					CFrame.new(centerX, floorY + 1.3, z + side * wallThickness * 0.28),
					baseColor,
					Enum.Material.SmoothPlastic
				)
				markBoundary(shoulder)
			end
		end
	end
end

function WorldStyleBaseline.CreateBoundaries(parent, configuration)
	if not parent or type(configuration) ~= "table" then
		return
	end

	local boundaries = configuration.BOUNDARIES
	if type(boundaries) ~= "table" then
		return
	end

	local ground = configuration.WORLD_GROUND
	local floorY = -0.5
	if type(ground) == "table" and ground.Center and ground.Size then
		floorY = ground.Center.Y + ground.Size.Y * 0.5
	end

	if type(boundaries.Runs) == "table" then
		for _, run in ipairs(boundaries.Runs) do
			local runFloorY = run.FloorY or floorY
			if run.Axis == "Z" then
				createStyledRunZ(parent, run.Name or "WorldBoundary", run.Coordinate, run.Start, run.End, run.Thickness, run.Height, runFloorY, run.InteriorSide)
			elseif run.Axis == "X" then
				createStyledRunX(parent, run.Name or "WorldBoundary", run.Start, run.End, run.Coordinate, run.Thickness, run.Height, runFloorY, run.InteriorSide)
			end
		end
	else
		local wallHeight = boundaries.WallHeight or 20
		local wallThickness = boundaries.WallThickness or 12
		if boundaries.WestX then
			createStyledRunZ(parent, "WestCliff", boundaries.WestX, boundaries.SideStartZ, boundaries.SideEndZ, wallThickness, wallHeight, floorY, 1)
		end
		if boundaries.EastX then
			createStyledRunZ(parent, "EastCliff", boundaries.EastX, boundaries.SideStartZ, boundaries.SideEndZ, wallThickness, wallHeight, floorY, -1)
		end
		if boundaries.SpineX then
			createStyledRunZ(parent, "CentralRidge", boundaries.SpineX, boundaries.SpineStartZ, boundaries.SpineEndZ, wallThickness, wallHeight, floorY, 0)
		end
		if boundaries.NorthZ and boundaries.WestX and boundaries.EastX then
			createStyledRunX(parent, "NorthernCliff", boundaries.WestX, boundaries.EastX, boundaries.NorthZ, wallThickness, wallHeight, floorY, -1)
		end
		if boundaries.ReturnClosureZ and boundaries.SpineX and boundaries.EastX then
			createStyledRunX(parent, "ReturnEndCliff", boundaries.SpineX, boundaries.EastX, boundaries.ReturnClosureZ, wallThickness, wallHeight, floorY, 1)
		end
	end

	local flanks = configuration.BARRIER_FLANKS
	local barrier = configuration.BARRIER
	if type(flanks) == "table" and type(barrier) == "table" and barrier.Position then
		local flankDepth = flanks.Depth or 8
		local flankHeight = flanks.Height or 20
		createStyledRunX(parent, "Forest2BarrierWestFlank", flanks.LeftStartX, flanks.LeftEndX, barrier.Position.Z, flankDepth, flankHeight, floorY, 1, true)
		createStyledRunX(parent, "Forest2BarrierEastFlank", flanks.RightStartX, flanks.RightEndX, barrier.Position.Z, flankDepth, flankHeight, floorY, 1, true)
	end
end

local function createSampleLabel(parent, title, center, groundTop, style)
	local board = createPart(
		parent,
		"SampleLabelBoard",
		Vector3.new(13, 2.8, 0.5),
		CFrame.new(center.X, groundTop + 3.2, center.Z),
		style.SignColor,
		Enum.Material.SmoothPlastic
	)
	board.CanCollide = false
	board.CanTouch = false
	board.CanQuery = false
	markWorldPart(board, "WorldStyleSampleLabel")

	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Name = "SampleLabel" .. face.Name
		surfaceGui.Face = face
		surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		surfaceGui.CanvasSize = Vector2.new(1000, 220)
		surfaceGui.LightInfluence = 0
		surfaceGui.AlwaysOnTop = false
		surfaceGui.Parent = board

		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBlack
		label.Text = title
		label.TextColor3 = style.SignTextColor
		label.TextScaled = true
		label.TextStrokeTransparency = 0.65
		label.Parent = surfaceGui
	end

	for _, offset in ipairs({ -4.8, 4.8 }) do
		local post = createPart(
			parent,
			"SampleLabelPost",
			Vector3.new(0.45, 2.4, 0.45),
			CFrame.new(center.X + offset, groundTop + 1.2, center.Z),
			style.SignColor,
			Enum.Material.SmoothPlastic
		)
		markWorldPart(post, "WorldStyleSampleLabel")
	end
end

local function createSampleBoundary(parent, center, size, groundTop, style)
	local backZ = center.Z + size.Z * 0.5 - 1.7
	local baseLength = size.X * 0.68
	if style.BoundaryForm == "SteppedBlocks" then
		local base = createPart(
			parent,
			"BrickBoundaryBase",
			Vector3.new(baseLength, 2.6, 3.6),
			CFrame.new(center.X, groundTop + 1.3, backZ),
			style.BoundaryColors[1],
			style.BoundaryMaterial
		)
		markWorldPart(base, "WorldStyleSampleBoundary")

		for index, side in ipairs({ -1, 1 }) do
			local block = createPart(
				parent,
				"BrickBoundaryStep" .. index,
				Vector3.new(baseLength * 0.42, 2.5 + index * 0.25, 4.0),
				CFrame.new(center.X + side * baseLength * 0.22, groundTop + 3.8, backZ),
				style.BoundaryColors[index + 1],
				style.BoundaryMaterial
			)
			markWorldPart(block, "WorldStyleSampleBoundary")
		end

		local cap = createPart(
			parent,
			"BrickBoundaryCap",
			Vector3.new(baseLength * 0.27, 1.7, 4.4),
			CFrame.new(center.X - baseLength * 0.1, groundTop + 5.95, backZ),
			style.BoundaryColors[3],
			style.BoundaryMaterial
		)
		markWorldPart(cap, "WorldStyleSampleBoundary")
	elseif style.BoundaryForm == "MushroomRidge" then
		local ridge = createPart(
			parent,
			"WhimsyBoundaryRidge",
			Vector3.new(baseLength * 0.72, 1.8, 2.8),
			CFrame.new(center.X, groundTop + 0.9, backZ),
			style.BoundaryColors[1],
			style.BoundaryMaterial
		)
		markWorldPart(ridge, "WorldStyleSampleBoundary")

		for index, side in ipairs({ -1, 1 }) do
			local mushroomCenter = Vector3.new(center.X + side * baseLength * 0.25, groundTop + 1.9, backZ - 0.4)
			local stem = createPart(
				parent,
				"WhimsyBoundaryMushroomStem" .. index,
				Vector3.new(2.4, 3.2, 2.4),
				CFrame.new(mushroomCenter),
				style.BoundaryColors[2],
				style.BoundaryMaterial,
				Enum.PartType.Ball
			)
			markWorldPart(stem, "WorldStyleSampleBoundary")

			local cap = createPart(
				parent,
				"WhimsyBoundaryMushroomCap" .. index,
				Vector3.new(4.6, 1.6, 3.8),
				CFrame.new(mushroomCenter + Vector3.new(0, 1.65, 0)),
				style.AccentColor,
				style.BoundaryMaterial,
				Enum.PartType.Ball
			)
			markWorldPart(cap, "WorldStyleSampleBoundary")
		end
	else
		local base = createPart(
			parent,
			"SoftCliffToe",
			Vector3.new(baseLength, 2.1, 3.1),
			CFrame.new(center.X, groundTop + 1.05, backZ),
			style.BoundaryColors[1],
			style.BoundaryMaterial
		)
		markWorldPart(base, "WorldStyleSampleBoundary")

		for index, offset in ipairs({ -0.25, 0, 0.25 }) do
			local mound = createPart(
				parent,
				"SoftCliffMound" .. index,
				Vector3.new(6.4, 4.4 + (index % 2) * 0.5, 4.2),
				CFrame.new(center.X + offset * baseLength, groundTop + 2.0, backZ - 0.2),
				style.BoundaryColors[index],
				style.BoundaryMaterial,
				Enum.PartType.Ball
			)
			markWorldPart(mound, "WorldStyleSampleBoundary")
		end
	end

	for _, side in ipairs({ -1, 1 }) do
		local foliageShape = nil
		if style.BoundaryForm ~= "SteppedBlocks" then
			foliageShape = Enum.PartType.Ball
		end
		local foliageMaterial = style.BoundaryForm == "SteppedBlocks" and Enum.Material.SmoothPlastic or style.BoundaryMaterial
		local bush = createPart(
			parent,
			"SampleFoliage",
			style.BoundaryForm == "MushroomRidge" and Vector3.new(4.2, 3.2, 3.6) or Vector3.new(3.8, 2.8, 3.3),
			CFrame.new(center.X + side * size.X * 0.34, groundTop + 1.35, center.Z + size.Z * 0.15),
			style.FoliageColor,
			foliageMaterial,
			foliageShape
		)
		bush.CanCollide = false
		bush.CanTouch = false
		bush.CanQuery = false
		markWorldPart(bush, "WorldStyleSampleFoliage")

		local accent = createPart(
			parent,
			"SampleAccent",
			Vector3.new(1.3, 1.3, 1.3),
			CFrame.new(center.X + side * size.X * 0.34, groundTop + 2.55, center.Z + size.Z * 0.15),
			style.AccentColor,
			style.BoundaryMaterial,
			Enum.PartType.Ball
		)
		accent.CanCollide = false
		accent.CanTouch = false
		accent.CanQuery = false
		markWorldPart(accent, "WorldStyleSampleFoliage")
	end
end

local DEFAULT_PADS = {
	{ Name = "BrightSimulator", Style = "BrightSimulator", Center = Vector3.new(68, -0.75, 92) },
	{ Name = "ChunkyBrick", Style = "ChunkyBrick", Center = Vector3.new(94, -0.75, 92) },
	{ Name = "LightWhimsy", Style = "LightWhimsy", Center = Vector3.new(120, -0.75, 92) },
}

function WorldStyleBaseline.CreateSamples(parent, sampleConfiguration)
	if not parent then
		return nil
	end

	local samplesFolder = Instance.new("Folder")
	samplesFolder.Name = "WorldStyleSamples"
	samplesFolder:SetAttribute("WorldLayoutOwned", true)
	samplesFolder:SetAttribute("BuildStatus", "StylePrototype")
	samplesFolder.Parent = parent

	local pads = type(sampleConfiguration) == "table" and sampleConfiguration.Pads or nil
	if type(pads) ~= "table" then
		pads = DEFAULT_PADS
	end
	local defaultSize = type(sampleConfiguration) == "table" and sampleConfiguration.Size or nil
	if typeof(defaultSize) ~= "Vector3" then
		defaultSize = Vector3.new(22, 0.5, 18)
	end

	for index, padConfiguration in ipairs(pads) do
		if typeof(padConfiguration.Center) == "Vector3" then
			local style = SAMPLE_STYLES[padConfiguration.Style] or SAMPLE_STYLES.BrightSimulator
			local padSize = typeof(padConfiguration.Size) == "Vector3" and padConfiguration.Size or defaultSize
			local groundOffset = 0.08
			if type(sampleConfiguration) == "table" and type(sampleConfiguration.GroundOffset) == "number" then
				groundOffset = sampleConfiguration.GroundOffset
			end
			local center = padConfiguration.Center + Vector3.new(0, groundOffset, 0)
			local sample = Instance.new("Folder")
			sample.Name = padConfiguration.Name or string.format("Sample%02d", index)
			sample:SetAttribute("WorldLayoutOwned", true)
			sample:SetAttribute("BuildStatus", "StylePrototype")
			sample:SetAttribute("SampleStyle", padConfiguration.Style or "BrightSimulator")
			sample.Parent = samplesFolder

			local ground = createPart(
				sample,
				"SampleGround",
				padSize,
				CFrame.new(center),
				style.GroundColor,
				style.GroundMaterial
			)
			ground:SetAttribute("HarvestLandingSurface", true)
			ground:SetAttribute("BuildStatus", "StylePrototype")

			local groundTop = center.Y + padSize.Y * 0.5
			local pathThickness = 0.14
			local path = createPart(
				sample,
				"SamplePath",
				Vector3.new(padSize.X * 0.72, pathThickness, 4.2),
				CFrame.new(center.X, groundTop + pathThickness * 0.5, center.Z - padSize.Z * 0.19),
				style.PathColor,
				style.PathMaterial
			)
			path:SetAttribute("HarvestLandingSurface", true)
			path:SetAttribute("BuildStatus", "StylePrototype")

			createSampleBoundary(sample, center, padSize, groundTop, style)
			local labelCenter = Vector3.new(center.X, 0, center.Z - padSize.Z * 0.5 + 1.4)
			createSampleLabel(sample, style.Title, labelCenter, groundTop, style)
		end
	end

	return samplesFolder
end

return WorldStyleBaseline
