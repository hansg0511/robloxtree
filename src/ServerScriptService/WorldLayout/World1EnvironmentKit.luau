-- Shared, deterministic environmental dressing for World 1 forests.
-- Every decorative clone comes from the reviewed toolbox library; this module
-- does not load Creator Store content or synthesize replacement geometry.
local ServerStorage = game:GetService("ServerStorage")

local World1EnvironmentKit = {}

local WORLD_ROOT_NAME = "World1EnvironmentKit"
local PATH_FOLDER_NAME = "DirtPaths"
local PATH_TEMPLATE_NAME = "Individual_DirtPath"
local LIVE_TREE_CLEARANCE = 20
local MAX_PLACEMENT_ATTEMPTS = 144
local RANDOM_MODULUS = 2147483647

-- Pack IDs are not unique model identities. Validate each approved ID together
-- with its exact source-backed model name and Variant attribute.
local APPROVED_TEMPLATES = {
	Synty_Log = { AssetId = "6933438443", AssetName = "Synty Nature Pack", Variant = "Fallen log" },
	Synty_Sign = { AssetId = "6933438443", AssetName = "Synty Nature Pack", Variant = "Sign" },
	Synty_Pebbles = { AssetId = "6933438443", AssetName = "Synty Nature Pack", Variant = "Pebble group" },
	Stylised_Rock01 = { AssetId = "6503281311", AssetName = "Stylised Low-Poly Nature Pack", Variant = "Rock 1" },
	Stylised_Rock02 = { AssetId = "6503281311", AssetName = "Stylised Low-Poly Nature Pack", Variant = "Rock 2" },
	Stylised_Rock03 = { AssetId = "6503281311", AssetName = "Stylised Low-Poly Nature Pack", Variant = "Rock 3" },
	Individual_WoodFence = { AssetId = "8399365124", AssetName = "Wooden Fence", Variant = "Original" },
	Individual_DirtPath = { AssetId = "5216151629", AssetName = "Dirt Path", Variant = "Original" },
	Colored_Flower01 = { AssetId = "17638037773", AssetName = "Colored Flowers Pack", Variant = "Flower 1" },
	Colored_Flower02 = { AssetId = "17638037773", AssetName = "Colored Flowers Pack", Variant = "Flower 2" },
	Colored_Flower03 = { AssetId = "17638037773", AssetName = "Colored Flowers Pack", Variant = "Flower 3" },
	Individual_LowPolyLog = { AssetId = "11312714034", AssetName = "Low Poly Log", Variant = "Original" },
}

local FLOWERS = { "Colored_Flower01", "Colored_Flower02", "Colored_Flower03" }
local ROCKS = { "Stylised_Rock01", "Stylised_Rock02", "Stylised_Rock03" }

local function makeReport()
	return {
		Success = false,
		ByForest = {},
		Path = {
			Success = false,
			SegmentCount = 0,
			TileCount = 0,
			InstanceCount = 0,
			BasePartCount = 0,
			Errors = {},
		},
		MissingTemplates = {},
		Errors = {},
		TotalInstanceCount = 0,
		TotalBasePartCount = 0,
		RemovedScriptCount = 0,
		RemovedJointCount = 0,
	}
end

local function normalizeSeed(seed)
	local value = math.floor(tonumber(seed) or 1) % (RANDOM_MODULUS - 1)
	if value < 0 then
		value += RANDOM_MODULUS - 1
	end
	return value + 1
end

local function hashText(text)
	local value = 17
	for index = 1, #text do
		value = (value * 31 + string.byte(text, index)) % (RANDOM_MODULUS - 1)
	end
	return value + 1
end

local function newRandom(seed)
	local state = normalizeSeed(seed)
	local random = {}
	function random:NextNumber(minimum, maximum)
		state = (state * 48271) % RANDOM_MODULUS
		local unit = (state - 1) / (RANDOM_MODULUS - 1)
		return minimum + (maximum - minimum) * unit
	end
	function random:NextInteger(minimum, maximum)
		return math.floor(self:NextNumber(minimum, maximum + 1))
	end
	function random:NextSign()
		return self:NextInteger(0, 1) == 0 and -1 or 1
	end
	return random
end

local function getForestSeed(forestConfiguration, index)
	local dressing = forestConfiguration.Dressing
	if dressing and dressing.Seed ~= nil then
		return normalizeSeed(dressing.Seed)
	end
	return hashText(tostring(forestConfiguration.ForestId or forestConfiguration.Name or index))
end

local function getDensity(forestConfiguration)
	local dressing = forestConfiguration.Dressing
	local density = dressing and dressing.Density
	if type(density) ~= "number" then
		density = 1
	end
	return math.clamp(density, 0, 1.5)
end

local function validateTemplates()
	local storage = ServerStorage:FindFirstChild("DevToolboxAssets")
	local library = storage and storage:FindFirstChild("ForestToolboxAssets")
	local templates = {}
	local missing = {}
	for name, specification in pairs(APPROVED_TEMPLATES) do
		local template = library and library:FindFirstChild(name)
		local valid = template ~= nil and template:IsA("Model")
		if valid then
			valid = template.Name == name
				and tostring(template:GetAttribute("AssetId")) == specification.AssetId
				and template:GetAttribute("AssetName") == specification.AssetName
				and template:GetAttribute("Variant") == specification.Variant
		end
		if valid then
			templates[name] = template
		else
			table.insert(missing, name)
		end
	end
	table.sort(missing)
	if #missing > 0 then
		return nil, missing
	end
	return templates, missing
end

local function setNonInteractive(instance, kind, forestId, report)
	local toRemove = {}
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
			table.insert(toRemove, descendant)
		elseif descendant:IsA("JointInstance") or descendant:IsA("Constraint") then
			table.insert(toRemove, descendant)
		end
	end
	for _, scriptInstance in ipairs(toRemove) do
		if scriptInstance:IsA("Script") or scriptInstance:IsA("LocalScript") or scriptInstance:IsA("ModuleScript") then
			report.RemovedScriptCount += 1
		else
			report.RemovedJointCount += 1
		end
		scriptInstance:Destroy()
	end

	instance:SetAttribute("WorldLayoutOwned", true)
	instance:SetAttribute("WorldDecoration", kind)
	if forestId then
		instance:SetAttribute("ForestId", forestId)
	end
	local parts = {}
	if instance:IsA("BasePart") then
		table.insert(parts, instance)
	end
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	for _, part in ipairs(parts) do
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part:SetAttribute("WorldLayoutOwned", true)
		part:SetAttribute("WorldDecoration", kind)
		if forestId then
			part:SetAttribute("ForestId", forestId)
		end
	end
end

local function countInstances(instance)
	local instances = 1
	local baseParts = if instance:IsA("BasePart") then 1 else 0
	for _, descendant in ipairs(instance:GetDescendants()) do
		instances += 1
		if descendant:IsA("BasePart") then
			baseParts += 1
		end
	end
	return instances, baseParts
end

local function accountModel(forestReport, model, kind)
	local instances, baseParts = countInstances(model)
	forestReport.ModelCount += 1
	forestReport.InstanceCount += instances
	forestReport.BasePartCount += baseParts
	forestReport.Kinds[kind] = (forestReport.Kinds[kind] or 0) + 1
end

local function placeModel(template, parent, forestConfiguration, forestReport, report, position, yaw, scale, kind)
	local clone = template:Clone()
	clone.Name = kind
	clone:SetAttribute("AssetId", tostring(template:GetAttribute("AssetId")))
	clone:SetAttribute("AssetVariant", template:GetAttribute("Variant"))
	clone:SetAttribute("AssetTemplateName", template.Name)
	setNonInteractive(clone, kind, forestConfiguration.ForestId, report)
	clone:ScaleTo(scale)
	clone:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(yaw), 0))
	local boundsFrame, boundsSize = clone:GetBoundingBox()
	local bottomY = boundsFrame.Position.Y - boundsSize.Y * 0.5
	local pivotY = position.Y - bottomY
	clone:PivotTo(CFrame.new(position.X, pivotY, position.Z) * CFrame.Angles(0, math.rad(yaw), 0))
	clone.Parent = parent
	accountModel(forestReport, clone, kind)
	return clone
end

local function distanceXZ(first, second)
	local dx = first.X - second.X
	local dz = first.Z - second.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function distanceToSegmentXZ(point, startPosition, endPosition)
	local dx = endPosition.X - startPosition.X
	local dz = endPosition.Z - startPosition.Z
	local lengthSquared = dx * dx + dz * dz
	if lengthSquared == 0 then
		return distanceXZ(point, startPosition)
	end
	local alpha = ((point.X - startPosition.X) * dx + (point.Z - startPosition.Z) * dz) / lengthSquared
	alpha = math.clamp(alpha, 0, 1)
	return distanceXZ(point, Vector3.new(startPosition.X + dx * alpha, point.Y, startPosition.Z + dz * alpha))
end

local function pathIsClear(position, pathSegments, margin)
	for _, segment in ipairs(pathSegments) do
		if segment.Start and segment.End and type(segment.Width) == "number" then
			if distanceToSegmentXZ(position, segment.Start, segment.End) < segment.Width * 0.5 + margin then
				return false
			end
		end
	end
	return true
end

local function nearEntrance(localX, localZ, forest, halfDepth)
	local entranceZ = if forest.ApproachFrom == "North" then halfDepth - 8 else -halfDepth + 8
	return math.abs(localX) < 28 and math.abs(localZ - entranceZ) < 8
end

local function nearExistingSign(position, forest)
	local sign = forest.Sign
	return sign and sign.Position
		and math.abs(position.X - sign.Position.X) < 11
		and math.abs(position.Z - sign.Position.Z) < 6
end

local function nearTree(position, forest, clearance)
	for _, tree in ipairs(forest.Trees or {}) do
		if tree.Position and distanceXZ(position, tree.Position) < clearance then
			return true
		end
	end
	return false
end

local function positionIsAllowed(position, forest, pathSegments, options)
	local center = forest.GroundCenter
	local size = forest.GroundSize
	if not center or not size then
		return false
	end
	local localX = position.X - center.X
	local localZ = position.Z - center.Z
	if math.abs(localX) > size.X * 0.5 - options.EdgeMargin or math.abs(localZ) > size.Z * 0.5 - options.EdgeMargin then
		return false
	end
	if not options.AllowEntrance and nearEntrance(localX, localZ, forest, size.Z * 0.5) then
		return false
	end
	if nearExistingSign(position, forest) then
		return false
	end
	if not pathIsClear(position, pathSegments, options.PathMargin) then
		return false
	end
	if nearTree(position, forest, options.TreeClearance) then
		return false
	end
	for _, anchor in ipairs(options.ExistingAnchors) do
		if distanceXZ(position, anchor) < options.MinimumAnchorGap then
			return false
		end
	end
	return true
end

local function findAnchor(forest, pathSegments, random, options)
	local center = forest.GroundCenter
	local halfWidth = forest.GroundSize.X * 0.5
	local halfDepth = forest.GroundSize.Z * 0.5
	local groundY = center.Y + forest.GroundSize.Y * 0.5
	for _ = 1, MAX_PLACEMENT_ATTEMPTS do
		local localX
		local localZ
		if forest.Status == "Blockout" then
			local sideX = random:NextSign()
			local sideZ = random:NextSign()
			if random:NextInteger(0, 1) == 0 then
				localX = sideX * random:NextNumber(halfWidth * 0.56, halfWidth - 9)
				localZ = random:NextNumber(-halfDepth + 12, halfDepth - 12)
			else
				localX = sideX * random:NextNumber(20, halfWidth - 9)
				localZ = sideZ * random:NextNumber(halfDepth * 0.5, halfDepth - 12)
			end
		else
			localX = random:NextSign() * random:NextNumber(14, math.min(28, halfWidth - 8))
			localZ = random:NextNumber(-halfDepth + 12, halfDepth - 10)
		end
		local candidate = Vector3.new(center.X + localX, groundY, center.Z + localZ)
		if positionIsAllowed(candidate, forest, pathSegments, options) then
			return candidate
		end
	end
	return nil
end

local function putAt(forestFolder, forest, pathSegments, random, templates, forestReport, report, anchor, name, offsetX, offsetZ, scaleMin, scaleMax, kind, options)
	if not anchor then
		return false
	end
	local point = Vector3.new(anchor.X + (offsetX or 0), anchor.Y, anchor.Z + (offsetZ or 0))
	if not positionIsAllowed(point, forest, pathSegments, options) then
		return false
	end
	placeModel(
		templates[name], forestFolder, forest, forestReport, report, point,
		random:NextNumber(-180, 180), random:NextNumber(scaleMin, scaleMax), kind
	)
	return true
end

local function newForestReport(forest)
	return {
		Success = false,
		ForestId = forest.ForestId,
		FolderName = tostring(forest.ForestId) .. "Dressing",
		ModelCount = 0,
		InstanceCount = 0,
		BasePartCount = 0,
		Kinds = {},
		Errors = {},
	}
end

local function addLiveDressing(folder, forest, pathSegments, random, templates, forestReport, report, density)
	local options = {
		TreeClearance = LIVE_TREE_CLEARANCE,
		PathMargin = 2,
		EdgeMargin = 6,
		MinimumAnchorGap = 8,
		ExistingAnchors = {},
	}
	local groupCount = math.clamp(math.floor(3 * density + 0.5), 0, 4)
	for _ = 1, groupCount do
		local anchor = findAnchor(forest, pathSegments, random, options)
		if not anchor then
			break
		end
		local flower = FLOWERS[random:NextInteger(1, #FLOWERS)]
		putAt(folder, forest, pathSegments, random, templates, forestReport, report, anchor, "Synty_Pebbles", 0, 0, 0.3, 0.4, "Pebbles", options)
		putAt(folder, forest, pathSegments, random, templates, forestReport, report, anchor, flower, random:NextSign() * 2, random:NextNumber(-1, 1), 0.28, 0.36, "Flowers", options)
		table.insert(options.ExistingAnchors, anchor)
	end
end

local function blockoutPosition(forest, pathSegments, localX, localZ, allowEntrance)
	local center = forest.GroundCenter
	local groundY = center.Y + forest.GroundSize.Y * 0.5
	local point = Vector3.new(center.X + localX, groundY, center.Z + localZ)
	local options = {
		TreeClearance = 0,
		PathMargin = 3,
		EdgeMargin = 6,
		MinimumAnchorGap = 0,
		ExistingAnchors = {},
		AllowEntrance = allowEntrance == true,
	}
	if positionIsAllowed(point, forest, pathSegments, options) then
		return point
	end
	return nil
end

local function addBlockoutDressing(folder, forest, pathSegments, random, templates, forestReport, report, density, forestIndex)
	local halfWidth = forest.GroundSize.X * 0.5
	local halfDepth = forest.GroundSize.Z * 0.5
	local corners = {
		Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1),
		Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1),
	}
	local anchors = {}
	for _, corner in ipairs(corners) do
		local x = corner.X * (halfWidth - 17) + random:NextNumber(-3, 3)
		local z = corner.Z * (halfDepth - 18) + random:NextNumber(-3, 3)
		table.insert(anchors, blockoutPosition(forest, pathSegments, x, z, false))
	end

	local options = {
		TreeClearance = 0,
		PathMargin = 3,
		EdgeMargin = 5,
		MinimumAnchorGap = 0,
		ExistingAnchors = {},
	}
	local groups = math.clamp(math.floor(4 * density + 0.5), 0, 6)
	local rock = random:NextInteger(1, #ROCKS)
	local rockA = ROCKS[rock]
	local rockB = ROCKS[rock % #ROCKS + 1]
	local rockC = ROCKS[(rock + 1) % #ROCKS + 1]

	if groups >= 1 then
		putAt(folder, forest, pathSegments, random, templates, forestReport, report, anchors[1] or anchors[2], rockA, -2.3, 0.5, 0.42, 0.54, "Rock", options)
		putAt(folder, forest, pathSegments, random, templates, forestReport, report, anchors[1] or anchors[2], rockB, 2.4, -1.5, 0.34, 0.45, "Rock", options)
		putAt(folder, forest, pathSegments, random, templates, forestReport, report, anchors[1] or anchors[2], "Synty_Pebbles", 0.5, 2.4, 0.3, 0.38, "Pebbles", options)
	end
	if groups >= 2 then
		putAt(folder, forest, pathSegments, random, templates, forestReport, report, anchors[2] or anchors[3], FLOWERS[random:NextInteger(1, #FLOWERS)], -2, 0, 0.3, 0.38, "Flowers", options)
		putAt(folder, forest, pathSegments, random, templates, forestReport, report, anchors[2] or anchors[3], FLOWERS[random:NextInteger(1, #FLOWERS)], 2.2, -1.4, 0.3, 0.38, "Flowers", options)
	end
	if groups >= 3 then
		local logTemplate = if random:NextInteger(0, 1) == 0 then "Synty_Log" else "Individual_LowPolyLog"
		putAt(folder, forest, pathSegments, random, templates, forestReport, report, anchors[3] or anchors[4], logTemplate, 0, 0, 0.35, 0.48, "DecorativeLog", options)
	end
	if groups >= 4 then
		putAt(folder, forest, pathSegments, random, templates, forestReport, report, anchors[4] or anchors[1], rockC, -2.3, 1, 0.36, 0.48, "Rock", options)
		putAt(folder, forest, pathSegments, random, templates, forestReport, report, anchors[4] or anchors[1], FLOWERS[random:NextInteger(1, #FLOWERS)], 2, -1.4, 0.28, 0.36, "Flowers", options)
	end

	-- The existing text label remains readable; this approved sign frames the
	-- entrance on the opposite side and stays outside its player passage.
	local signPoint = blockoutPosition(forest, pathSegments, 32, -halfDepth + 10, true)
	if signPoint and density > 0 then
		placeModel(templates.Synty_Sign, folder, forest, forestReport, report, signPoint, random:NextNumber(-8, 8), 0.44, "EntranceSign")
	end

	-- One short fence segment on alternating footprints leaves the forest open.
	if density > 0 and forestIndex % 2 == 0 then
		local fencePoint = blockoutPosition(forest, pathSegments, -halfWidth + 9, random:NextNumber(-4, 10), false)
		if fencePoint then
			placeModel(templates.Individual_WoodFence, folder, forest, forestReport, report, fencePoint, 90 + random:NextNumber(-7, 7), 0.46, "TrailFence")
		end
	end
end

local function createForestFolder(parent, forest, index, configuration, pathSegments, templates, report)
	local forestReport = newForestReport(forest)
	report.ByForest[forest.ForestId] = forestReport
	local density = getDensity(forest)
	local folder = Instance.new("Folder")
	folder.Name = forestReport.FolderName
	folder:SetAttribute("WorldLayoutOwned", true)
	folder:SetAttribute("WorldDecoration", "ForestDressing")
	folder:SetAttribute("ForestId", forest.ForestId)
	folder.Parent = parent

	local success, message = pcall(function()
		local random = newRandom(getForestSeed(forest, index))
		if forest.Status == "Blockout" then
			addBlockoutDressing(folder, forest, pathSegments, random, templates, forestReport, report, density, index)
		else
			addLiveDressing(folder, forest, pathSegments, random, templates, forestReport, report, density)
		end
	end)
	if not success then
		folder:Destroy()
		forestReport.ModelCount = 0
		forestReport.InstanceCount = 0
		forestReport.BasePartCount = 0
		forestReport.Kinds = {}
		table.insert(forestReport.Errors, tostring(message))
		return forestReport
	end
	if density > 0 and forestReport.ModelCount == 0 then
		folder:Destroy()
		forestReport.InstanceCount = 0
		forestReport.BasePartCount = 0
		forestReport.Kinds = {}
		table.insert(forestReport.Errors, "No approved decorations passed the forest clearance checks")
		return forestReport
	end
	forestReport.Success = true
	forestReport.InstanceCount += 1 -- Forest dressing folder.
	folder:SetAttribute("BuildSuccess", true)
	folder:SetAttribute("DecorationModelCount", forestReport.ModelCount)
	folder:SetAttribute("DecorationInstanceCount", forestReport.InstanceCount)
	folder:SetAttribute("DecorationBasePartCount", forestReport.BasePartCount)
	folder:SetAttribute("DecorationKindSummary", table.concat({
		"DecorativeLog=" .. tostring(forestReport.Kinds.DecorativeLog or 0),
		"EntranceSign=" .. tostring(forestReport.Kinds.EntranceSign or 0),
		"Flowers=" .. tostring(forestReport.Kinds.Flowers or 0),
		"Pebbles=" .. tostring(forestReport.Kinds.Pebbles or 0),
		"Rock=" .. tostring(forestReport.Kinds.Rock or 0),
		"TrailFence=" .. tostring(forestReport.Kinds.TrailFence or 0),
	}, ","))
	return forestReport
end

local function findPathTile(template)
	for _, descendant in ipairs(template:GetDescendants()) do
		if descendant:IsA("BasePart") then
			for _, child in ipairs(descendant:GetChildren()) do
				if child:IsA("Decal") then
					return descendant, child
				end
			end
		end
	end
	return nil
end

local function createPaths(parent, configuration, templates, report)
	local pathReport = report.Path
	local pathSegments = configuration.PATH_SEGMENTS or {}
	local sourceModel = templates[PATH_TEMPLATE_NAME]
	local sourcePart, sourceDecal = findPathTile(sourceModel)
	if not sourcePart or not sourceDecal then
		table.insert(pathReport.Errors, "Approved Individual_DirtPath contains no decal-bearing BasePart")
		return pathReport
	end
	if sourceDecal.Face ~= Enum.NormalId.Bottom and sourceDecal.Face ~= Enum.NormalId.Top then
		table.insert(pathReport.Errors, "Approved Individual_DirtPath decal face is not horizontal")
		return pathReport
	end
	local folder = Instance.new("Folder")
	folder.Name = PATH_FOLDER_NAME
	folder:SetAttribute("WorldLayoutOwned", true)
	folder:SetAttribute("WorldDecoration", "DirtPath")
	folder.Parent = parent

	local success, message = pcall(function()
		local sourceSize = sourcePart.Size
		-- The approved source decal is on its Bottom face, and its support is
		-- authored upside down. Keep the original Face and flip that face upward;
		-- route yaw comes from the existing path centerline, not the pack's staging yaw.
		local sourceRotation = if sourceDecal.Face == Enum.NormalId.Bottom
			then CFrame.Angles(math.pi, 0, 0)
			else CFrame.new()
		for _, segment in ipairs(pathSegments) do
			-- Keep the grove's plot lane unchanged; all hub branches and forest
			-- corridors remain connected by the approved dirt surface.
			if segment.Name ~= "PlotLane" then
				local delta = Vector3.new(segment.End.X - segment.Start.X, 0, segment.End.Z - segment.Start.Z)
				local length = delta.Magnitude
				if length > 0 and type(segment.Width) == "number" then
					local scale = math.min(sourceSize.X, segment.Width * 0.98) / sourceSize.X
					local tileSize = sourceSize * scale
					local spacing = math.max(tileSize.Z * 0.74, 3)
					local tileCount = math.max(2, math.ceil(length / spacing) + 1)
					local routeRotation = CFrame.lookAt(Vector3.zero, delta.Unit)
					local tileRotation = routeRotation * sourceRotation
					local faceSign = if sourceDecal.Face == Enum.NormalId.Bottom then -1 else 1
					local faceOffset = tileRotation:VectorToWorldSpace(Vector3.new(0, faceSign * tileSize.Y * 0.5, 0))
					local surfaceY = configuration.PATH_SURFACE_Y or -0.4

					for index = 0, tileCount - 1 do
						local alpha = index / (tileCount - 1)
						local x = segment.Start.X + delta.X * alpha
						local z = segment.Start.Z + delta.Z * alpha
						local centerY = surfaceY - faceOffset.Y + 0.01
						local tile = sourcePart:Clone()
						tile.Name = "DirtPathTile"
						tile.Size = tileSize
						tile.CFrame = CFrame.new(x, centerY, z) * tileRotation
						setNonInteractive(tile, "DirtPath", nil, report)
						tile:SetAttribute("AssetId", tostring(sourceModel:GetAttribute("AssetId")))
						tile:SetAttribute("AssetVariant", sourceModel:GetAttribute("Variant"))
						tile:SetAttribute("AssetTemplateName", sourceModel.Name)
						tile:SetAttribute("PathSegment", segment.Name)
						tile.Parent = folder
						local instances, baseParts = countInstances(tile)
						pathReport.TileCount += 1
						pathReport.InstanceCount += instances
						pathReport.BasePartCount += baseParts
					end
					pathReport.SegmentCount += 1
				end
			end
		end
	end)
	if not success then
		folder:Destroy()
		pathReport.SegmentCount = 0
		pathReport.TileCount = 0
		pathReport.InstanceCount = 0
		pathReport.BasePartCount = 0
		table.insert(pathReport.Errors, tostring(message))
		return pathReport
	end
	pathReport.Success = pathReport.SegmentCount > 0
	if pathReport.Success then
		pathReport.InstanceCount += 1 -- DirtPaths folder.
		folder:SetAttribute("BuildSuccess", true)
		folder:SetAttribute("PathSegmentCount", pathReport.SegmentCount)
		folder:SetAttribute("DirtPathTileCount", pathReport.TileCount)
		folder:SetAttribute("DecorationInstanceCount", pathReport.InstanceCount)
		folder:SetAttribute("DecorationBasePartCount", pathReport.BasePartCount)
	else
		folder:Destroy()
		pathReport.SegmentCount = 0
		pathReport.TileCount = 0
		pathReport.InstanceCount = 0
		pathReport.BasePartCount = 0
		table.insert(pathReport.Errors, "No configured forest or hub path segments were dressed")
	end
	return pathReport
end

local function sumCounts(report)
	local instances = report.Path.InstanceCount + 1 -- World1EnvironmentKit root folder.
	local baseParts = report.Path.BasePartCount
	for _, forestReport in pairs(report.ByForest) do
		instances += forestReport.InstanceCount
		baseParts += forestReport.BasePartCount
	end
	report.TotalInstanceCount = instances
	report.TotalBasePartCount = baseParts
end

function World1EnvironmentKit.Create(parent, configuration)
	local report = makeReport()
	if not parent or not configuration or type(configuration.FORESTS) ~= "table" then
		table.insert(report.Errors, "Create requires a parent and WorldLayoutConfiguration")
		return nil, report
	end

	local templates, missing = validateTemplates()
	report.MissingTemplates = missing
	if not templates then
		for _, forest in ipairs(configuration.FORESTS) do
			report.ByForest[forest.ForestId] = newForestReport(forest)
		end
		table.insert(report.Errors, "Approved source-backed templates are missing or failed identity validation: " .. table.concat(missing, ", "))
		return nil, report
	end

	local root = Instance.new("Folder")
	root.Name = WORLD_ROOT_NAME
	root:SetAttribute("WorldLayoutOwned", true)
	root:SetAttribute("WorldDecoration", WORLD_ROOT_NAME)
	root.Parent = parent

	local success, message = pcall(function()
		createPaths(root, configuration, templates, report)
		local pathSegments = configuration.PATH_SEGMENTS or {}
		for index, forest in ipairs(configuration.FORESTS) do
			createForestFolder(root, forest, index, configuration, pathSegments, templates, report)
		end
		for _, pathError in ipairs(report.Path.Errors) do
			table.insert(report.Errors, "DirtPaths: " .. pathError)
		end
		for _, forest in ipairs(configuration.FORESTS) do
			local forestReport = report.ByForest[forest.ForestId]
			for _, forestError in ipairs(forestReport.Errors) do
				table.insert(report.Errors, tostring(forest.ForestId) .. ": " .. forestError)
			end
		end
	end)
	if not success then
		root:Destroy()
		table.insert(report.Errors, tostring(message))
		for _, forestReport in pairs(report.ByForest) do
			forestReport.Success = false
			forestReport.ModelCount = 0
			forestReport.InstanceCount = 0
			forestReport.BasePartCount = 0
			forestReport.Kinds = {}
		end
		report.Path.Success = false
		report.Path.TileCount = 0
		report.Path.InstanceCount = 0
		report.Path.BasePartCount = 0
		return nil, report
	end

	local forestsSucceeded = true
	for _, forest in ipairs(configuration.FORESTS) do
		local forestReport = report.ByForest[forest.ForestId]
		if not forestReport or not forestReport.Success then
			forestsSucceeded = false
		end
	end
	report.Success = report.Path.Success and forestsSucceeded and #report.MissingTemplates == 0
	sumCounts(report)
	root:SetAttribute("BuildSuccess", report.Success)
	root:SetAttribute("ForestCount", #configuration.FORESTS)
	root:SetAttribute("DirtPathSegmentCount", report.Path.SegmentCount)
	root:SetAttribute("DirtPathTileCount", report.Path.TileCount)
	root:SetAttribute("DecorationModelCount", (function()
		local total = 0
		for _, forestReport in pairs(report.ByForest) do
			total += forestReport.ModelCount
		end
		return total
	end)())
	root:SetAttribute("DecorationInstanceCount", report.TotalInstanceCount)
	root:SetAttribute("DecorationBasePartCount", report.TotalBasePartCount)
	root:SetAttribute("RemovedScriptCount", report.RemovedScriptCount)
	root:SetAttribute("RemovedJointCount", report.RemovedJointCount)
	root:SetAttribute("MissingTemplates", table.concat(report.MissingTemplates, ","))
	root:SetAttribute("BuildErrors", table.concat(report.Errors, " | "))
	return root, report
end

return World1EnvironmentKit
