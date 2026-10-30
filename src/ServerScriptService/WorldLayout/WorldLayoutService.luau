-- Builds the source-controlled corridor and registers its public TreeObject records.
local Workspace = game:GetService("Workspace")
local TreeObject = require(game.ServerScriptService.Trees.TreeObject)
local TreeDefinitions = require(game.ServerScriptService.Trees.TreeDefinitions)
local Configuration = require(script.Parent.WorldLayoutConfiguration)
local WorldStyleBaseline = require(script.Parent.WorldStyleBaseline)
local World1Dressing = require(script.Parent.World1Dressing)

local WorldLayoutService = {}
local spawnedTreesByRoot = {}

local function createFolder(name, parent)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function createPart(name, size, cframe, color, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createGround(parent, name, center, size, color, material, styleRole)
	local ground = createPart(
		name,
		size,
		CFrame.new(center),
		color or Configuration.GROUND_COLOR,
		material or Configuration.GROUND_MATERIAL,
		parent
	)
	ground:SetAttribute("WorldLayoutOwned", true)
	ground:SetAttribute("HarvestLandingSurface", true)
	WorldStyleBaseline.ApplyGround(ground, styleRole or "WorldGround")
	return ground
end

local function createPath(parent, segment)
	local startPosition = segment.Start
	local endPosition = segment.End
	local deltaX = endPosition.X - startPosition.X
	local deltaZ = endPosition.Z - startPosition.Z
	local length = math.sqrt(deltaX * deltaX + deltaZ * deltaZ)
	if length <= 0 then
		warn("World layout path segment has no length:", segment.Name)
		return nil
	end

	local centerX = (startPosition.X + endPosition.X) * 0.5
	local centerZ = (startPosition.Z + endPosition.Z) * 0.5
	local centerY = Configuration.PATH_SURFACE_Y - Configuration.PATH_THICKNESS * 0.5
	local center = Vector3.new(centerX, centerY, centerZ)
	local target = Vector3.new(endPosition.X, centerY, endPosition.Z)
	local path = createPart(
		segment.Name,
		Vector3.new(segment.Width, Configuration.PATH_THICKNESS, length),
		CFrame.lookAt(center, target),
		Configuration.PATH_COLOR,
		Configuration.PATH_MATERIAL,
		parent
	)
	path:SetAttribute("WorldLayoutOwned", true)
	path:SetAttribute("HarvestLandingSurface", true)
	path:SetAttribute("Route", segment.Route or "World1")
	WorldStyleBaseline.ApplyGround(path, "Path")
	return path
end

local function markWorldLayoutPart(part, attributeName)
	part:SetAttribute("WorldLayoutOwned", true)
	if attributeName then
		part:SetAttribute(attributeName, true)
	end
	return part
end

local function createGroveFenceRun(parent, name, startPosition, endPosition)
	local deltaX = endPosition.X - startPosition.X
	local deltaZ = endPosition.Z - startPosition.Z
	local length = math.sqrt(deltaX * deltaX + deltaZ * deltaZ)
	if length <= 0 then return end

	local segmentCount = math.max(1, math.ceil(length / 18))
	local segmentLength = length / segmentCount
	local unitX = deltaX / length
	local unitZ = deltaZ / length
	local woodColor = Color3.fromRGB(110, 76, 48)

	for index = 0, segmentCount do
		local distance = math.min(index * segmentLength, length)
		local x = startPosition.X + unitX * distance
		local z = startPosition.Z + unitZ * distance
		local post = createPart(
			name .. "Post",
			Vector3.new(0.9, 5, 0.9),
			CFrame.new(x, 2, z),
			Color3.fromRGB(89, 60, 39),
			Enum.Material.Wood,
			parent
		)
		markWorldLayoutPart(post, "GroveDistrictBoundary")

		if index < segmentCount then
			local nextDistance = math.min((index + 1) * segmentLength, length)
			local midpoint = startPosition + Vector3.new(unitX, 0, unitZ) * ((distance + nextDistance) * 0.5)
			local railLength = nextDistance - distance + 0.2
			for _, railY in ipairs({ 1.15, 3.5 }) do
				local railCenter = Vector3.new(midpoint.X, railY, midpoint.Z)
				local railTarget = railCenter + Vector3.new(unitX, 0, unitZ)
				local rail = createPart(
					name .. "Rail",
					Vector3.new(0.55, 0.65, railLength),
					CFrame.lookAt(railCenter, railTarget),
					woodColor,
					Enum.Material.WoodPlanks,
					parent
				)
				markWorldLayoutPart(rail, "GroveDistrictBoundary")
			end
		end
	end
end

local function createGroveDistrictFrame(parent)
	local fences = Configuration.GROVE_FENCES
	createGroveFenceRun(
		parent,
		"GroveWestFence",
		Vector3.new(-fences.SideX, 0, fences.StartZ),
		Vector3.new(-fences.SideX, 0, fences.EndZ)
	)
	createGroveFenceRun(
		parent,
		"GroveEastFence",
		Vector3.new(fences.SideX, 0, fences.StartZ),
		Vector3.new(fences.SideX, 0, fences.EndZ)
	)
	createGroveFenceRun(
		parent,
		"GroveRearFence",
		Vector3.new(-fences.SideX, 0, fences.BackZ),
		Vector3.new(fences.SideX, 0, fences.BackZ)
	)
	for _, run in ipairs(fences.FrontRuns) do
		createGroveFenceRun(
			parent,
			"GroveFrontFence",
			Vector3.new(run.StartX, 0, fences.FrontZ),
			Vector3.new(run.EndX, 0, fences.FrontZ)
		)
	end
end

local function createForestEntrance(parent, forestConfiguration)
	local center = forestConfiguration.GroundCenter
	local size = forestConfiguration.GroundSize
	local entryZ
	if forestConfiguration.ApproachFrom == "North" then
		entryZ = center.Z + size.Z * 0.5 - 8
	else
		entryZ = center.Z - size.Z * 0.5 + 8
	end

	for _, offsetX in ipairs({ -19, 19 }) do
		local post = createPart(
			forestConfiguration.ForestId .. "EntrancePost",
			Vector3.new(4, 12, 4),
			CFrame.new(center.X + offsetX, 5.5, entryZ),
			WorldStyleBaseline.WoodColors.Main,
			Enum.Material.WoodPlanks,
			parent
		)
		post.CanCollide = false
		post.CanTouch = false
		post.CanQuery = false
		markWorldLayoutPart(post, "ForestEntranceFrame")
		if forestConfiguration.Status == "Blockout" then
			post:SetAttribute("FutureBarrierThreshold", true)
			post:SetAttribute("BuildStatus", "Blockout")
		end
	end

	local blockoutThreshold = forestConfiguration.Status == "Blockout"
	local lintel = createPart(
		forestConfiguration.ForestId .. "EntranceLintel",
		Vector3.new(42, 2, 3),
		CFrame.new(center.X, 12.5, entryZ),
		if blockoutThreshold then WorldStyleBaseline.WoodColors.Highlight else WorldStyleBaseline.WoodColors.Main,
		Enum.Material.WoodPlanks,
		parent
	)
	lintel.CanCollide = false
	lintel.CanTouch = false
	lintel.CanQuery = false
	markWorldLayoutPart(lintel, "ForestEntranceFrame")
	if blockoutThreshold then
		lintel:SetAttribute("FutureBarrierThreshold", true)
		lintel:SetAttribute("BuildStatus", "Blockout")
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local surfaceGui = Instance.new("SurfaceGui")
			surfaceGui.Name = "BlockoutLabel" .. face.Name
			surfaceGui.Face = face
			surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
			surfaceGui.CanvasSize = Vector2.new(1200, 120)
			surfaceGui.LightInfluence = 0
			surfaceGui.AlwaysOnTop = false
			surfaceGui.Parent = lintel

			local label = Instance.new("TextLabel")
			label.Name = "BlockoutText"
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.GothamBlack
			label.Text = "BLOCKOUT"
			label.TextColor3 = Color3.fromRGB(255, 226, 135)
			label.TextScaled = true
			label.TextStrokeTransparency = 0.5
			label.Parent = surfaceGui
		end
	end
end

local function createForestEdgeBoulders(parent, forestConfiguration)
	local center = forestConfiguration.GroundCenter
	local size = forestConfiguration.GroundSize
	local positions = {
		Vector3.new(center.X - size.X * 0.5 + 10, 0, center.Z - size.Z * 0.5 + 10),
		Vector3.new(center.X - size.X * 0.5 + 10, 0, center.Z + size.Z * 0.5 - 10),
		Vector3.new(center.X + size.X * 0.5 - 10, 0, center.Z - size.Z * 0.5 + 10),
		Vector3.new(center.X + size.X * 0.5 - 10, 0, center.Z + size.Z * 0.5 - 10),
	}
	for _, position in ipairs(positions) do
		local boulder = createPart(
			forestConfiguration.ForestId .. "EdgeBoulder",
			Vector3.new(9, 6, 8),
			CFrame.new(position.X, 2.5, position.Z),
			Color3.fromRGB(91, 103, 91),
			Enum.Material.Slate,
			parent
		)
		boulder.CanCollide = false
		boulder.CanTouch = false
		boulder.CanQuery = false
		markWorldLayoutPart(boulder, "ForestBoundaryProp")
	end
end

local function createSign(parent, signConfiguration, approachFrom)
	local x = signConfiguration.Position.X
	local z = signConfiguration.Position.Z
	-- Face the incoming player along the trail and label both board faces.
	local yaw = approachFrom == "North" and math.rad(180) or 0
	local boardCFrame = CFrame.new(x, 3.6, z) * CFrame.Angles(0, yaw, 0)
	local board = createPart(
		"TrailSignBoard",
		Vector3.new(14, 4, 0.6),
		boardCFrame,
		WorldStyleBaseline.WoodColors.Shadow,
		Enum.Material.WoodPlanks,
		parent
	)
	board:SetAttribute("WorldLayoutOwned", true)

	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local signFace = Instance.new("SurfaceGui")
		signFace.Name = "SignFace" .. face.Name
		signFace.Face = face
		signFace.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		signFace.CanvasSize = Vector2.new(900, 260)
		signFace.LightInfluence = 0
		signFace.AlwaysOnTop = false
		signFace.Parent = board

		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.Text = signConfiguration.Text
		label.TextColor3 = Color3.fromRGB(255, 236, 190)
		label.TextScaled = true
		label.Parent = signFace
	end

	local postXOffset = 5
	for _, offset in ipairs({ -postXOffset, postXOffset }) do
		local post = createPart(
			"TrailSignPost",
			Vector3.new(0.65, 3.4, 0.65),
			CFrame.new(x + offset, 1.15, z),
			WorldStyleBaseline.WoodColors.Shadow,
			Enum.Material.Wood,
			parent
		)
		post:SetAttribute("WorldLayoutOwned", true)
	end
end

local function createStationSign(parent, name, title, subtitle, position, boardColor, textColor)
	local board = createPart(
		name .. "SignBoard",
		Vector3.new(7, 1.8, 0.5),
		CFrame.new(position),
		boardColor,
		Enum.Material.WoodPlanks,
		parent
	)
	board:SetAttribute("WorldLayoutOwned", true)

	-- Physical, two-sided boards stay world-scaled: they read at the station
	-- from either travel direction and naturally shrink out of view at range.
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local signFace = Instance.new("SurfaceGui")
		signFace.Name = "SignFace" .. face.Name
		signFace.Face = face
		signFace.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		signFace.CanvasSize = Vector2.new(560, 144)
		signFace.LightInfluence = 0
		signFace.AlwaysOnTop = false
		signFace.Parent = board

		local panel = Instance.new("Frame")
		panel.Name = "Panel"
		panel.Position = UDim2.fromScale(0.035, 0.08)
		panel.Size = UDim2.fromScale(0.93, 0.84)
		panel.BackgroundColor3 = Color3.fromRGB(37, 79, 72)
		panel.BorderSizePixel = 0
		panel.Parent = signFace

		local panelCorner = Instance.new("UICorner")
		panelCorner.CornerRadius = UDim.new(0, 12)
		panelCorner.Parent = panel

		local panelStroke = Instance.new("UIStroke")
		panelStroke.Color = Color3.fromRGB(255, 205, 78)
		panelStroke.Thickness = 5
		panelStroke.Parent = panel

		local topAccent = Instance.new("Frame")
		topAccent.Name = "TopAccent"
		topAccent.AnchorPoint = Vector2.new(0.5, 0)
		topAccent.Position = UDim2.new(0.5, 0, 0.08, 0)
		topAccent.Size = UDim2.new(0.24, 0, 0, 6)
		topAccent.BackgroundColor3 = boardColor
		topAccent.BorderSizePixel = 0
		topAccent.Parent = panel

		local label = Instance.new("TextLabel")
		label.Name = "Title"
		label.BackgroundTransparency = 1
		label.Position = UDim2.new(0.06, 0, subtitle and 0.18 or 0.24, 0)
		label.Size = UDim2.new(0.88, 0, subtitle and 0.48 or 0.58, 0)
		label.Font = Enum.Font.GothamBlack
		label.Text = title
		label.TextColor3 = textColor
		label.TextScaled = true
		label.TextStrokeTransparency = 0.6
		label.Parent = panel

		if subtitle then
			local subtitleLabel = Instance.new("TextLabel")
			subtitleLabel.Name = "Subtitle"
			subtitleLabel.BackgroundTransparency = 1
			subtitleLabel.Position = UDim2.new(0.06, 0, 0.64, 0)
			subtitleLabel.Size = UDim2.new(0.88, 0, 0.23, 0)
			subtitleLabel.Font = Enum.Font.GothamBold
			subtitleLabel.Text = subtitle
			subtitleLabel.TextColor3 = Color3.fromRGB(255, 218, 101)
			subtitleLabel.TextScaled = true
			subtitleLabel.TextStrokeTransparency = 0.7
			subtitleLabel.Parent = panel
		end
	end

	return board
end

local function createHomeEconomyStation(parent)
	local station = Instance.new("Model")
	station.Name = "HomeEconomyStation"
	station:SetAttribute("WorldLayoutOwned", true)
	station:SetAttribute("UseDistance", Configuration.STATION_USE_DISTANCES.HomeEconomyStation)
	station.Parent = parent

	local position = Configuration.HOME_ECONOMY_STATION.Position
	local counter = createPart(
		"Counter",
		Vector3.new(8, 4, 3),
		CFrame.new(position + Vector3.new(0, 2, 0)),
		Color3.fromRGB(113, 72, 44),
		Enum.Material.WoodPlanks,
		station
	)
	counter:SetAttribute("WorldLayoutOwned", true)

	local interaction = createPart(
		"Interaction",
		Vector3.new(8, 6, 5),
		CFrame.new(position + Vector3.new(0, 3, -3)),
		Color3.fromRGB(88, 164, 92),
		Enum.Material.Plastic,
		station
	)
	interaction.Transparency = 1
	interaction.CanCollide = false
	interaction.CanTouch = false
	interaction.CanQuery = false
	interaction:SetAttribute("WorldLayoutOwned", true)
	interaction:SetAttribute("UseDistance", Configuration.STATION_USE_DISTANCES.HomeEconomyStation)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EconomyPrompt"
	prompt.ActionText = "Sell logs"
	prompt.ObjectText = "Lumber Depot"
	prompt.MaxActivationDistance = Configuration.STATION_USE_DISTANCES.HomeEconomyStation
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = interaction

	local signPost = createPart(
		"SignPost",
		Vector3.new(0.45, 2.8, 0.45),
		CFrame.new(position + Vector3.new(0, 5.0, 0)),
		Color3.fromRGB(95, 62, 38),
		Enum.Material.Wood,
		station
	)
	signPost:SetAttribute("WorldLayoutOwned", true)
	createStationSign(
		station,
		"LumberDepot",
		"Lumber Depot",
		"Sell Logs",
		position + Vector3.new(0, 6.1, 0),
		Color3.fromRGB(235, 159, 57),
		Color3.fromRGB(255, 234, 181)
	)

	return station
end

local function createAxeShopStation(parent)
	local station = Instance.new("Model")
	station.Name = "AxeShopStation"
	station:SetAttribute("WorldLayoutOwned", true)
	station:SetAttribute("UseDistance", Configuration.STATION_USE_DISTANCES.AxeShopStation)
	station.Parent = parent

	local position = Configuration.AXE_SHOP_STATION.Position
	local counter = createPart(
		"Counter",
		Vector3.new(10, 3.5, 3.5),
		CFrame.new(position + Vector3.new(0, 1.75, 0)),
		Color3.fromRGB(235, 162, 61),
		Enum.Material.WoodPlanks,
		station
	)
	counter:SetAttribute("WorldLayoutOwned", true)

	local counterTop = createPart(
		"CounterTop",
		Vector3.new(11, 0.6, 4.2),
		CFrame.new(position + Vector3.new(0, 3.8, 0)),
		Color3.fromRGB(255, 214, 77),
		Enum.Material.Plastic,
		station
	)
	counterTop:SetAttribute("WorldLayoutOwned", true)
	counterTop.TopSurface = Enum.SurfaceType.Studs

	local signPost = createPart(
		"SignPost",
		Vector3.new(0.6, 3.4, 0.6),
		CFrame.new(position + Vector3.new(0, 5.5, 0)),
		Color3.fromRGB(92, 137, 80),
		Enum.Material.Plastic,
		station
	)
	signPost:SetAttribute("WorldLayoutOwned", true)

	createStationSign(
		station,
		"AxeShop",
		"Axe Shop",
		nil,
		position + Vector3.new(0, 6.2, 0),
		Color3.fromRGB(68, 191, 104),
		Color3.fromRGB(255, 249, 219)
	)

	local interaction = createPart(
		"Interaction",
		Vector3.new(10, 6, 5),
		CFrame.new(position + Vector3.new(0, 3, -3.5)),
		Color3.fromRGB(88, 164, 92),
		Enum.Material.Plastic,
		station
	)
	interaction.Transparency = 1
	interaction.CanCollide = false
	interaction.CanTouch = false
	interaction.CanQuery = false
	interaction:SetAttribute("WorldLayoutOwned", true)
	interaction:SetAttribute("UseDistance", Configuration.STATION_USE_DISTANCES.AxeShopStation)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "AxeShopPrompt"
	prompt.ActionText = "Browse axes"
	prompt.ObjectText = "Axe Shop"
	prompt.MaxActivationDistance = Configuration.STATION_USE_DISTANCES.AxeShopStation
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = interaction

	return station
end

local function createForgeStation(parent)
	local station = Instance.new("Model")
	station.Name = "ForgeStation"
	station:SetAttribute("WorldLayoutOwned", true)
	station:SetAttribute("UseDistance", Configuration.STATION_USE_DISTANCES.ForgeStation)
	station.Parent = parent

	local position = Configuration.FORGE_STATION.Position
	local base = createPart(
		"ForgeBase",
		Vector3.new(9, 1, 7),
		CFrame.new(position + Vector3.new(0, 0.5, 0)),
		Color3.fromRGB(67, 67, 64),
		Enum.Material.Slate,
		station
	)
	base:SetAttribute("WorldLayoutOwned", true)

	local furnace = createPart(
		"Furnace",
		Vector3.new(4, 3, 3),
		CFrame.new(position + Vector3.new(0, 2.5, 1.5)),
		Color3.fromRGB(92, 65, 53),
		Enum.Material.Brick,
		station
	)
	furnace:SetAttribute("WorldLayoutOwned", true)

	local hearth = createPart(
		"Hearth",
		Vector3.new(2, 1.4, 0.25),
		CFrame.new(position + Vector3.new(0, 2.5, -0.14)),
		Color3.fromRGB(255, 112, 36),
		Enum.Material.Neon,
		station
	)
	hearth:SetAttribute("WorldLayoutOwned", true)

	local anvilBody = createPart(
		"AnvilBody",
		Vector3.new(2.2, 1, 1.5),
		CFrame.new(position + Vector3.new(0, 1.5, -1.9)),
		Color3.fromRGB(87, 99, 103),
		Enum.Material.Metal,
		station
	)
	anvilBody:SetAttribute("WorldLayoutOwned", true)

	local anvilTop = createPart(
		"AnvilTop",
		Vector3.new(2.8, 0.4, 1.8),
		CFrame.new(position + Vector3.new(0, 1.9, -1.9)),
		Color3.fromRGB(139, 151, 154),
		Enum.Material.Metal,
		station
	)
	anvilTop:SetAttribute("WorldLayoutOwned", true)

	local interaction = createPart(
		"Interaction",
		Vector3.new(10, 6, 5),
		CFrame.new(position + Vector3.new(0, 3, -3.5)),
		Color3.fromRGB(88, 164, 92),
		Enum.Material.Plastic,
		station
	)
	interaction.Transparency = 1
	interaction.CanCollide = false
	interaction.CanTouch = false
	interaction.CanQuery = false
	interaction:SetAttribute("WorldLayoutOwned", true)
	interaction:SetAttribute("UseDistance", Configuration.STATION_USE_DISTANCES.ForgeStation)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ForgePrompt"
	prompt.ActionText = "Forge axe"
	prompt.ObjectText = "Forge"
	prompt.MaxActivationDistance = Configuration.STATION_USE_DISTANCES.ForgeStation
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = interaction

	createStationSign(
		station,
		"Forge",
		"Forge",
		"Craft Axes",
		position + Vector3.new(0, 6.1, 1.5),
		Color3.fromRGB(125, 73, 50),
		Color3.fromRGB(255, 232, 201)
	)

	return station
end

local function spawnTreeRecord(forestFolder, forestId, record)
	local definition = TreeDefinitions[record.DefinitionId]
	if not definition then
		warn("World layout tree definition is missing:", record.DefinitionId)
		return nil
	end

	local tree = TreeObject.new({
		DefinitionId = record.DefinitionId,
		Parent = forestFolder,
		CFrame = CFrame.new(record.Position),
		ForestId = forestId,
	})
	local model = tree:Spawn()
	if not model then
		tree:Destroy()
		return nil
	end
	model:SetAttribute("ForestId", forestId)
	model:SetAttribute("DefinitionId", record.DefinitionId)
	model:SetAttribute("PublicWorldTree", true)
	return tree
end

local function destroyTreesForExistingRoot(existing)
	local treesToDestroy = {}
	local seenTrees = {}
	local function rememberTree(tree)
		if tree and not seenTrees[tree] then
			seenTrees[tree] = true
			table.insert(treesToDestroy, tree)
		end
	end

	for _, tree in ipairs(spawnedTreesByRoot[existing] or {}) do
		rememberTree(tree)
	end
	-- A service reload can clear its ownership map while TreeObject still holds
	-- active records. Snapshot matching records before Destroy mutates ActiveTrees.
	for tree in pairs(TreeObject.ActiveTrees or {}) do
		local treeParent = tree.Parent
		if treeParent and (treeParent == existing or treeParent:IsDescendantOf(existing)) then
			rememberTree(tree)
		end
	end
	for _, tree in ipairs(treesToDestroy) do
		tree:Destroy()
	end
end

local function buildWorld()
	local baseGround = Workspace:FindFirstChild("BaseGround")
	if baseGround and baseGround:IsA("BasePart") then
		WorldStyleBaseline.ApplyGround(baseGround, "BaseGround")
	end

	local existing = Workspace:FindFirstChild(Configuration.ROOT_NAME)
	local proceduralStarterOaksEnabled = Configuration.PROCEDURAL_STARTER_OAKS_ENABLED == true
	if existing
		and existing:GetAttribute("WorldLayoutVersion") == Configuration.VERSION
		and (existing:GetAttribute("ProceduralStarterOaksEnabled") == true) == proceduralStarterOaksEnabled then
		return existing
	end
	if existing then
		destroyTreesForExistingRoot(existing)
		spawnedTreesByRoot[existing] = nil
		existing:Destroy()
	end

	local root = createFolder(Configuration.ROOT_NAME, Workspace)
	local terrain = createFolder("Terrain", root)
	local pathFolder = createFolder("Path", root)
	local forestRoot = createFolder("Forests", root)
	local environment = createFolder("Environment", root)
	root:SetAttribute("WorldLayoutOwned", true)
	createHomeEconomyStation(root)
	createAxeShopStation(root)
	createForgeStation(root)

	createGround(
		terrain,
		"WorldGround",
		Configuration.WORLD_GROUND.Center,
		Configuration.WORLD_GROUND.Size,
		Configuration.GROUND_COLOR,
		Configuration.GROUND_MATERIAL,
		"WorldGround"
	)
	createGround(
		terrain,
		"HubPlaza",
		Configuration.HUB_GROUND.Center,
		Configuration.HUB_GROUND.Size,
		Configuration.HUB_GROUND.Color,
		Configuration.HUB_GROUND.Material,
		"HubGround"
	)
	createGroveDistrictFrame(environment)
	WorldStyleBaseline.CreateBoundaries(environment, Configuration)
	WorldStyleBaseline.CreateSamples(environment, Configuration.STYLE_SAMPLES)
	createSign(
		environment,
		{ Text = "<- FORESTS 1-5", Position = Vector3.new(-20, 0, 132) },
		"South"
	)
	createSign(
		environment,
		{ Text = "-> FORESTS 6-10", Position = Vector3.new(20, 0, 132) },
		"South"
	)

	for _, segment in ipairs(Configuration.PATH_SEGMENTS) do
		createPath(pathFolder, segment)
	end

	local spawnedTrees = {}
	for _, forestConfiguration in ipairs(Configuration.FORESTS) do
		local forestFolder = createFolder(forestConfiguration.Name, forestRoot)
		forestFolder:SetAttribute("ForestId", forestConfiguration.ForestId)
		if forestConfiguration.Status then
			forestFolder:SetAttribute("BuildStatus", forestConfiguration.Status)
		end
		createGround(
			forestFolder,
			"ForestGround",
			forestConfiguration.GroundCenter,
			forestConfiguration.GroundSize,
			forestConfiguration.GroundColor,
			nil,
			"ForestGround"
		)
		createForestEntrance(forestFolder, forestConfiguration)
		-- Keep Forest1's approved Oaks and Forest2's trees clear of the perimeter;
		-- reserved later footprints use noncolliding corner rocks for scale.
		if #forestConfiguration.Trees == 0 then
			createForestEdgeBoulders(forestFolder, forestConfiguration)
		end
		createSign(forestFolder, forestConfiguration.Sign, forestConfiguration.ApproachFrom)

		for _, record in ipairs(forestConfiguration.Trees) do
			local tree = spawnTreeRecord(forestFolder, forestConfiguration.ForestId, record)
			if tree then table.insert(spawnedTrees, tree) end
		end
	end

	local starterForest = forestRoot:FindFirstChild("StarterForest")
	local barrier = spawnTreeRecord(starterForest, Configuration.BARRIER.ForestId, Configuration.BARRIER)
	if barrier then table.insert(spawnedTrees, barrier) end
	World1Dressing.Create(environment)
	root:SetAttribute("WorldLayoutVersion", Configuration.VERSION)
	root:SetAttribute("ProceduralStarterOaksEnabled", proceduralStarterOaksEnabled)
	spawnedTreesByRoot[root] = spawnedTrees
	return root, spawnedTrees
end

function WorldLayoutService.Build()
	return buildWorld()
end

return WorldLayoutService
