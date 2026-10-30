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

-- Ordinary World 1 cliffs are made from overlapping, visible cylinder pillars.
-- Each pillar owns its own rock body and grass cap; no continuous wall or hidden
-- collision plane sits behind them.
local STONE_MASS_COLORS = {
	Color3.fromRGB(112, 120, 124),
	Color3.fromRGB(101, 109, 113),
	Color3.fromRGB(124, 131, 135),
	Color3.fromRGB(91, 99, 103),
}
local GRASS_CAP_COLOR = Color3.fromRGB(100, 151, 79)
local PILLAR_SPACING_ESTIMATE = 16
local PILLAR_MIN_RADIUS = 6.5
local PILLAR_MAX_RADIUS = 11.5
local PILLAR_CAP_HEIGHT = 1.25
local PILLAR_CAP_OVERHANG = 0.5
local PILLAR_MAX_CAP_RADIUS = PILLAR_MAX_RADIUS + PILLAR_CAP_OVERHANG
local PILLAR_ALONG_JITTER = { -0.3, 0.25, 0.15, -0.2, 0.05 }
local PILLAR_HEIGHT_JITTER = { -1, 0, 1 }
local PILLAR_SIDE_DEPTH_OFFSETS = { 2.0, 4.5, 2.5, 4.0, 3.0 }
local PILLAR_RIDGE_DEPTH_OFFSETS = { 0, 4.5, 1.5, 4.25, 0.5 }
local PILLAR_SUPPORT_CLUSTER_PATTERN = { true, true, false, true, true, true, false }
local PILLAR_OUTBOARD_SUPPORT_HEIGHTS = { 26, 34, 29, 37, 31, 35, 28, 33, 30, 36, 27, 32 }
local PILLAR_TARGET_OVERLAP = 1.5
local PILLAR_MIN_OVERLAP = 1.0
local PILLAR_MAX_OVERLAP = 2.75
local PILLAR_TARGET_PLANE_OVERLAP = 1.0
local PILLAR_MIN_PLANE_OVERLAP = 0.4

local PILLAR_RADIUS_BY_ROLE = {
	Support = { 8.5, 9.0 },
	Medium = { 9.5, 10.0, 10.5 },
	Anchor = { 10.5, 11.0, 11.5 },
	OutboardSupport = { 6.5, 7.0, 7.5, 8.0 },
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

local function getMassPhase(name)
	local phase = 0
	for index = 1, #name do
		phase = (phase + string.byte(name, index)) % #PILLAR_ALONG_JITTER
	end
	return phase
end

local function getPillarRole(index, phase)
	local clusterSlot = (index + phase - 1) % 8
	if clusterSlot == 4 then
		return "Anchor"
	elseif clusterSlot == 0 or clusterSlot == 2 or clusterSlot == 6 then
		return "Support"
	end
	return "Medium"
end

local function getPillarRadius(role, index, phase)
	local radii = PILLAR_RADIUS_BY_ROLE[role]
	local radiusPatternIndex = role == "Support" and (math.floor((index - 1) / 8) + phase) or (index * 3 + phase)
	local radiusIndex = (radiusPatternIndex % #radii) + 1
	return math.max(PILLAR_MIN_RADIUS, math.min(PILLAR_MAX_RADIUS, radii[radiusIndex]))
end

local function getPillarHeight(role, index, phase, requestedHeight)
	local targetHeight = math.max(28, math.min(31, requestedHeight or 30))
	local roleOffset = role == "Anchor" and 9 or role == "Medium" and 0 or -5
	local jitterIndex = ((index + phase * 2) % #PILLAR_HEIGHT_JITTER) + 1
	return math.max(24, math.min(40, targetHeight + roleOffset + PILLAR_HEIGHT_JITTER[jitterIndex]))
end

local function getOutboardSupportHeight(index, phase, requestedHeight)
	local targetHeight = math.max(28, math.min(31, requestedHeight or 30))
	local heightIndex = ((index + phase * 3 - 1) % #PILLAR_OUTBOARD_SUPPORT_HEIGHTS) + 1
	local requestedHeightAdjustment = targetHeight - 30
	return math.max(24, math.min(37, PILLAR_OUTBOARD_SUPPORT_HEIGHTS[heightIndex] + requestedHeightAdjustment))
end

local function getPillarNormalOffset(interiorSide, index, phase)
	local offsetIndex = ((index + phase - 1) % #PILLAR_SIDE_DEPTH_OFFSETS) + 1
	if interiorSide == 0 then
		return PILLAR_RIDGE_DEPTH_OFFSETS[offsetIndex]
	end

	local side = interiorSide or 1
	-- Main bodies straddle the boundary line but stay slightly outboard to keep
	-- the existing play spaces and tree clearances unchanged.
	return -side * PILLAR_SIDE_DEPTH_OFFSETS[offsetIndex]
end

local function buildPillarPlan(name, runLength, interiorSide, requestedHeight)
	local phase = getMassPhase(name)
	local minimumIntervals = math.max(1, math.floor(runLength / (PILLAR_SPACING_ESTIMATE + 4)) - 1)
	local maximumIntervals = math.max(minimumIntervals, math.ceil(runLength / (PILLAR_SPACING_ESTIMATE - 5)) + 1)
	local bestPlan = nil
	local bestScore = math.huge

	for intervalCount = minimumIntervals, maximumIntervals do
		local pillars = {}
		for index = 1, intervalCount + 1 do
			local role = getPillarRole(index, phase)
			local radius = getPillarRadius(role, index, phase)
			local normalOffset = getPillarNormalOffset(interiorSide, index, phase)
			if index == 1 or index == intervalCount + 1 then
				if interiorSide == 0 then
					normalOffset = 3.25
				else
					normalOffset = -(interiorSide or 1) * 2.5
				end
			end
			if name == "CentralRidge" then
				-- Keep each west-facing ridge body clear of Forest 1 crowns while
				-- allowing smaller supports to straddle x=0.
				normalOffset = math.max(normalOffset, radius - 8.5, 0)
				if index == 1 then
					normalOffset = math.max(normalOffset, 4.5)
				end
			end
			pillars[index] = {
				Index = index,
				Role = role,
				Radius = radius,
				BodyHeight = getPillarHeight(role, index, phase, requestedHeight),
				NormalOffset = normalOffset,
				ColorIndex = ((index * 3 + phase) % #STONE_MASS_COLORS) + 1,
			}
		end

		local steps = {}
		local totalStep = 0
		for index = 1, intervalCount do
			local first = pillars[index]
			local second = pillars[index + 1]
			local targetCenterDistance = first.Radius + second.Radius - PILLAR_TARGET_OVERLAP
			local crossDistance = math.abs(second.NormalOffset - first.NormalOffset)
			local alongDistanceByBody = math.sqrt(math.max(0.01, targetCenterDistance ^ 2 - crossDistance ^ 2))
			-- The body disks must also overlap where they cross the actual boundary
			-- plane. This is the half-width of each disk's vertical-plane slice.
			local firstPlaneReach = math.sqrt(math.max(0.01, first.Radius ^ 2 - first.NormalOffset ^ 2))
			local secondPlaneReach = math.sqrt(math.max(0.01, second.Radius ^ 2 - second.NormalOffset ^ 2))
			local alongDistanceByPlane = firstPlaneReach + secondPlaneReach - PILLAR_TARGET_PLANE_OVERLAP
			local alongDistance = math.min(alongDistanceByBody, alongDistanceByPlane)
			local jitterIndex = ((index + phase - 1) % #PILLAR_ALONG_JITTER) + 1
			local step = math.max(0.1, alongDistance + PILLAR_ALONG_JITTER[jitterIndex])
			steps[index] = step
			totalStep = totalStep + step
		end

		local scale = runLength / totalStep
		local overlapPenalty = 0
		local averageOverlap = 0
		for index = 1, intervalCount do
			local first = pillars[index]
			local second = pillars[index + 1]
			local crossDistance = math.abs(second.NormalOffset - first.NormalOffset)
			local centerDistance = math.sqrt((steps[index] * scale) ^ 2 + crossDistance ^ 2)
			local overlap = first.Radius + second.Radius - centerDistance
			averageOverlap = averageOverlap + overlap
			local firstPlaneReach = math.sqrt(math.max(0.01, first.Radius ^ 2 - first.NormalOffset ^ 2))
			local secondPlaneReach = math.sqrt(math.max(0.01, second.Radius ^ 2 - second.NormalOffset ^ 2))
			local planeOverlap = firstPlaneReach + secondPlaneReach - steps[index] * scale
			if planeOverlap < PILLAR_MIN_PLANE_OVERLAP then
				overlapPenalty = overlapPenalty + PILLAR_MIN_PLANE_OVERLAP - planeOverlap
			end
			if overlap < PILLAR_MIN_OVERLAP then
				overlapPenalty = overlapPenalty + PILLAR_MIN_OVERLAP - overlap
			elseif overlap > PILLAR_MAX_OVERLAP then
				overlapPenalty = overlapPenalty + overlap - PILLAR_MAX_OVERLAP
			end
		end
		averageOverlap = averageOverlap / intervalCount

		local score = overlapPenalty * 100 + math.abs(scale - 1) + math.abs(averageOverlap - PILLAR_TARGET_OVERLAP) * 0.05
		if score < bestScore then
			bestScore = score
			bestPlan = {
				Phase = phase,
				Pillars = pillars,
				Steps = steps,
				Scale = scale,
			}
		end
	end

	return bestPlan
end

local function createBoundaryPillar(parent, runName, columnName, role, position, radius, bodyHeight, capColor, stoneColor)
	local model = Instance.new("Model")
	model.Name = columnName
	model:SetAttribute("WorldLayoutOwned", true)
	model:SetAttribute("WorldBoundary", true)
	model:SetAttribute("BoundaryStyle", "World1Baseline")
	model:SetAttribute("BoundaryColumn", true)
	model:SetAttribute("BoundaryRun", runName)
	model:SetAttribute("BoundaryColumnRole", role)
	model:SetAttribute("PillarRadius", radius)
	model:SetAttribute("PillarBodyHeight", bodyHeight)

	-- Roblox cylinders use local X as their long axis. Rotating local X onto world
	-- Y keeps both the rock body and its grass cap upright.
	local verticalRotation = CFrame.Angles(0, 0, math.rad(90))
	local body = createPart(
		model,
		"Body",
		Vector3.new(bodyHeight, radius * 2, radius * 2),
		CFrame.new(position.X, position.Y + bodyHeight * 0.5, position.Z) * verticalRotation,
		stoneColor or STONE_MASS_COLORS[((math.floor(position.X + position.Z + bodyHeight)) % #STONE_MASS_COLORS) + 1],
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	body.CanCollide = true
	body.CanTouch = false
	body.CanQuery = true
	body:SetAttribute("BoundaryColumn", true)
	body:SetAttribute("PillarRole", role)
	body:SetAttribute("PillarRadius", radius)
	body:SetAttribute("PillarBodyHeight", bodyHeight)
	markBoundary(body)

	local capRadius = radius + PILLAR_CAP_OVERHANG
	local cap = createPart(
		model,
		"GrassCap",
		Vector3.new(PILLAR_CAP_HEIGHT, capRadius * 2, capRadius * 2),
		CFrame.new(position.X, position.Y + bodyHeight + PILLAR_CAP_HEIGHT * 0.5, position.Z) * verticalRotation,
		capColor or GRASS_CAP_COLOR,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	cap.CanCollide = true
	cap.CanTouch = false
	cap.CanQuery = true
	cap:SetAttribute("BoundaryColumn", true)
	cap:SetAttribute("PillarRole", role)
	cap:SetAttribute("PillarRadius", capRadius)
	markBoundary(cap)

	model.PrimaryPart = body
	model.Parent = parent
	return model
end

local function getPillarPosition(axis, normalCoordinate, floorY, runCoordinate)
	if axis == "Z" then
		return Vector3.new(normalCoordinate, floorY, runCoordinate)
	end
	return Vector3.new(runCoordinate, floorY, normalCoordinate)
end

local function createPillarRun(parent, name, axis, coordinate, startCoordinate, endCoordinate, requestedHeight, floorY, interiorSide, forcedSolidInterval, forcedSolidSide)
	local runLength = math.abs(endCoordinate - startCoordinate)
	if runLength <= 0 then
		return
	end

	local direction = endCoordinate >= startCoordinate and 1 or -1
	local plan = buildPillarPlan(name, runLength, interiorSide, requestedHeight)
	if not plan then
		return
	end
	local phase = plan.Phase
	local alongDistance = 0
	local pillarCount = #plan.Pillars

	for index, pillar in ipairs(plan.Pillars) do
		local alongCoordinate = index == pillarCount and endCoordinate or startCoordinate + direction * alongDistance
		local normalOffset = pillar.NormalOffset
		local position = getPillarPosition(axis, coordinate + normalOffset, floorY, alongCoordinate)
		local columnName = string.format("%sPillar%03d", name, index)
		local colorIndex = pillar.ColorIndex
		createBoundaryPillar(parent, name, columnName, pillar.Role, position, pillar.Radius, pillar.BodyHeight, nil, STONE_MASS_COLORS[colorIndex])

		-- Cluster smaller supports in irregular paired and triple groups beyond
		-- the main containment chain. Their varied tops make the second layer read
		-- as a visible mesa cluster instead of a low repeated trim. Outer-run
		-- supports face away from gameplay; ridge supports face Corridor B, clear
		-- of Forest 1 trees and route space.
		local supportPatternIndex = ((index - 1) % #PILLAR_SUPPORT_CLUSTER_PATTERN) + 1
		if PILLAR_SUPPORT_CLUSTER_PATTERN[supportPatternIndex] then
			local side = interiorSide or 1
			local outwardSide = interiorSide == 0 and 1 or -side
			local supportRunOffset = direction * (index % 2 == 0 and -3.5 or 3.5)
			local supportIndex = index + phase + 2
			local supportRadius = getPillarRadius("OutboardSupport", supportIndex, phase + 1)
			local supportHeight = getOutboardSupportHeight(supportIndex, phase + 1, requestedHeight)
			local supportCenterDistance = pillar.Radius + supportRadius - PILLAR_TARGET_OVERLAP
			local supportCrossOffset = math.sqrt(math.max(0.01, supportCenterDistance ^ 2 - 3.5 ^ 2))
			local supportPosition = getPillarPosition(
				axis,
				coordinate + normalOffset + outwardSide * supportCrossOffset,
				floorY,
				alongCoordinate + supportRunOffset
			)
			local supportColorIndex = (colorIndex % #STONE_MASS_COLORS) + 1
			createBoundaryPillar(
				parent,
				name,
				string.format("%sSupportPillar%03d", name, index),
				"Support",
				supportPosition,
				supportRadius,
				supportHeight,
				nil,
				STONE_MASS_COLORS[supportColorIndex]
			)
		end

		if index < pillarCount then
			alongDistance = alongDistance + plan.Steps[index] * plan.Scale
		end
	end

	-- These visible tall columns bridge the unchanged Forest 2 flank ends to the
	-- ordinary boundary pillars. Their body height exceeds the preserved flanks.
	if axis == "Z"
		and type(forcedSolidInterval) == "table"
		and (name == "WestCliff" or name == "CentralRidge")
	then
		local junctionOffset
		if interiorSide == 0 then
			junctionOffset = (forcedSolidSide or -1) * 1.5
		else
			junctionOffset = -(interiorSide or 1) * 2.5
		end
		local gatePosition = getPillarPosition(
			axis,
			coordinate + junctionOffset,
			floorY,
			(forcedSolidInterval.Start + forcedSolidInterval.End) * 0.5
		)
		local gateHeight = math.max(30, math.min(34, requestedHeight or 30))
		createBoundaryPillar(
			parent,
			name,
			name .. "GateJunctionPillar",
			"GateJunction",
			gatePosition,
			PILLAR_MAX_RADIUS,
			gateHeight,
			nil,
			STONE_MASS_COLORS[(phase % #STONE_MASS_COLORS) + 1]
		)
	end
end

local function createLayeredRunZ(parent, name, x, startZ, endZ, thickness, requestedHeight, floorY, interiorSide, forcedSolidInterval, forcedSolidSide)
	if type(x) ~= "number" or type(startZ) ~= "number" or type(endZ) ~= "number" then
		return
	end
	createPillarRun(parent, name, "Z", x, startZ, endZ, requestedHeight, floorY, interiorSide, forcedSolidInterval, forcedSolidSide)
end

local function createLayeredRunX(parent, name, startX, endX, z, thickness, requestedHeight, floorY, interiorSide)
	if type(startX) ~= "number" or type(endX) ~= "number" or type(z) ~= "number" then
		return
	end
	createPillarRun(parent, name, "X", z, startX, endX, requestedHeight, floorY, interiorSide)
end
local function createStyledRunZ(parent, name, x, startZ, endZ, thickness, requestedHeight, floorY, interiorSide, preserveBarrierStyle, forcedSolidInterval, forcedSolidSide)
	if not preserveBarrierStyle then
		createLayeredRunZ(parent, name, x, startZ, endZ, thickness, requestedHeight, floorY, interiorSide, forcedSolidInterval, forcedSolidSide)
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

	local barrierFlanksForJoin = configuration.BARRIER_FLANKS
	local barrierForJoin = configuration.BARRIER
	local barrierZInterval
	if type(barrierFlanksForJoin) == "table"
		and type(barrierForJoin) == "table"
		and barrierForJoin.Position
	then
		local barrierDepth = barrierForJoin.Depth
		if type(barrierDepth) ~= "number" then
			barrierDepth = barrierFlanksForJoin.Depth
		end
		if type(barrierDepth) == "number" and barrierDepth > 0 then
			barrierZInterval = {
				Start = barrierForJoin.Position.Z - barrierDepth * 0.5,
				End = barrierForJoin.Position.Z + barrierDepth * 0.5,
			}
		end
	end

	local function getBarrierJoinSettings(runName)
		if not barrierZInterval then
			return nil, nil
		end
		if runName == "WestCliff" then
			return barrierZInterval, nil
		elseif runName == "CentralRidge" then
			return barrierZInterval, -1
		end
		return nil, nil
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

	local function getNorthPathEdgeAtX(x)
		local pathSegments = configuration.PATH_SEGMENTS
		if type(pathSegments) ~= "table" then
			return nil
		end

		local northEdge = nil
		for _, pathSegment in ipairs(pathSegments) do
			if typeof(pathSegment.Start) == "Vector3" and typeof(pathSegment.End) == "Vector3" then
				local width = type(pathSegment.Width) == "number" and pathSegment.Width or 0
				local minX = math.min(pathSegment.Start.X, pathSegment.End.X)
				local maxX = math.max(pathSegment.Start.X, pathSegment.End.X)
				local minZ = math.min(pathSegment.Start.Z, pathSegment.End.Z)
				local maxZ = math.max(pathSegment.Start.Z, pathSegment.End.Z)
				local isAxisAligned = math.abs(pathSegment.Start.X - pathSegment.End.X) < 0.001
					or math.abs(pathSegment.Start.Z - pathSegment.End.Z) < 0.001
				if isAxisAligned and x >= minX - width * 0.5 and x <= maxX + width * 0.5 then
					local edge = maxZ + width * 0.5
					northEdge = northEdge and math.max(northEdge, edge) or edge
				end
			end
		end
		return northEdge
	end

	local function adjustPillarStartZ(runName, x, startZ, endZ, interiorSide)
		if type(startZ) ~= "number" or type(endZ) ~= "number" or endZ < startZ then
			return startZ
		end

		if runName == "CentralRidge" then
			local pathEdge = getNorthPathEdgeAtX(x)
			if pathEdge then
				-- Account for the full circular grass-cap footprint so the ridge's
				-- first pillar clears the hub fork and its approach path.
				startZ = math.max(startZ, pathEdge + PILLAR_MAX_CAP_RADIUS + 0.5)
			end
		elseif runName == "WestCliff" or runName == "EastCliff" then
			local sampleConfiguration = configuration.STYLE_SAMPLES
			local pads = type(sampleConfiguration) == "table" and sampleConfiguration.Pads or nil
			local defaultSize = type(sampleConfiguration) == "table" and sampleConfiguration.Size or nil
			if typeof(defaultSize) ~= "Vector3" then
				defaultSize = Vector3.new(22, 0.5, 18)
			end
			local side = interiorSide or (runName == "WestCliff" and 1 or -1)
			local closestColumnX = x - side * 1.5
			if type(pads) == "table" then
				for _, pad in ipairs(pads) do
					if typeof(pad.Center) == "Vector3" then
						local padSize = typeof(pad.Size) == "Vector3" and pad.Size or defaultSize
						local xGap = math.max(0, math.abs(closestColumnX - pad.Center.X) - padSize.X * 0.5)
						if xGap < PILLAR_MAX_CAP_RADIUS then
							local zReach = math.sqrt(PILLAR_MAX_CAP_RADIUS ^ 2 - xGap ^ 2)
							local padNorthEdge = pad.Center.Z + padSize.Z * 0.5
							startZ = math.max(startZ, padNorthEdge + zReach + 1.5)
						end
					end
				end
			end
		end
		return startZ
	end

	if type(boundaries.Runs) == "table" then
		for _, run in ipairs(boundaries.Runs) do
			local runFloorY = run.FloorY or floorY
			if run.Axis == "Z" then
				local runName = run.Name or "WorldBoundary"
				local forcedSolidInterval, forcedSolidSide = getBarrierJoinSettings(runName)
				local startZ = adjustPillarStartZ(runName, run.Coordinate, run.Start, run.End, run.InteriorSide)
				createStyledRunZ(parent, runName, run.Coordinate, startZ, run.End, run.Thickness, run.Height, runFloorY, run.InteriorSide, false, forcedSolidInterval, forcedSolidSide)
			elseif run.Axis == "X" then
				createStyledRunX(parent, run.Name or "WorldBoundary", run.Start, run.End, run.Coordinate, run.Thickness, run.Height, runFloorY, run.InteriorSide)
			end
		end
	else
		local wallHeight = boundaries.WallHeight or 20
		local wallThickness = boundaries.WallThickness or 12
		if boundaries.WestX then
			local forcedSolidInterval, forcedSolidSide = getBarrierJoinSettings("WestCliff")
			local startZ = adjustPillarStartZ("WestCliff", boundaries.WestX, boundaries.SideStartZ, boundaries.SideEndZ, 1)
			createStyledRunZ(parent, "WestCliff", boundaries.WestX, startZ, boundaries.SideEndZ, wallThickness, wallHeight, floorY, 1, false, forcedSolidInterval, forcedSolidSide)
		end
		if boundaries.EastX then
			local startZ = adjustPillarStartZ("EastCliff", boundaries.EastX, boundaries.SideStartZ, boundaries.SideEndZ, -1)
			createStyledRunZ(parent, "EastCliff", boundaries.EastX, startZ, boundaries.SideEndZ, wallThickness, wallHeight, floorY, -1)
		end
		if boundaries.SpineX then
			local forcedSolidInterval, forcedSolidSide = getBarrierJoinSettings("CentralRidge")
			local startZ = adjustPillarStartZ("CentralRidge", boundaries.SpineX, boundaries.SpineStartZ, boundaries.SpineEndZ, 0)
			createStyledRunZ(parent, "CentralRidge", boundaries.SpineX, startZ, boundaries.SpineEndZ, wallThickness, wallHeight, floorY, 0, false, forcedSolidInterval, forcedSolidSide)
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
