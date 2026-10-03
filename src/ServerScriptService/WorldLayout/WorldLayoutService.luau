-- Builds the source-controlled corridor and registers its public TreeObject records.
local Workspace = game:GetService("Workspace")
local TreeObject = require(game.ServerScriptService.Trees.TreeObject)
local TreeDefinitions = require(game.ServerScriptService.Trees.TreeDefinitions)
local Configuration = require(script.Parent.WorldLayoutConfiguration)

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

local function createGround(parent, name, center, size)
	local ground = createPart(
		name,
		size,
		CFrame.new(center),
		Configuration.GROUND_COLOR,
		Configuration.GROUND_MATERIAL,
		parent
	)
	ground:SetAttribute("WorldLayoutOwned", true)
	return ground
end

local function createPath(parent, segment)
	local length = math.abs(segment.EndZ - segment.StartZ)
	local centerZ = (segment.StartZ + segment.EndZ) * 0.5
	local path = createPart(
		segment.Name,
		Vector3.new(segment.Width, Configuration.PATH_THICKNESS, length),
		CFrame.new(0, Configuration.PATH_SURFACE_Y - Configuration.PATH_THICKNESS * 0.5, centerZ),
		Configuration.PATH_COLOR,
		Configuration.PATH_MATERIAL,
		parent
	)
	path:SetAttribute("WorldLayoutOwned", true)
	path:SetAttribute("Route", "BaseToForest2")
	return path
end

local function createSign(parent, signConfiguration)
	local x = signConfiguration.Position.X
	local z = signConfiguration.Position.Z
	local facesLeft = x > 0
	local yaw = facesLeft and math.rad(90) or math.rad(-90)
	local boardCFrame = CFrame.new(x, 3.6, z) * CFrame.Angles(0, yaw, 0)
	local board = createPart(
		"TrailSignBoard",
		Vector3.new(14, 4, 0.6),
		boardCFrame,
		Color3.fromRGB(104, 67, 39),
		Enum.Material.WoodPlanks,
		parent
	)
	board:SetAttribute("WorldLayoutOwned", true)

	local signFace = Instance.new("SurfaceGui")
	signFace.Name = "SignFace"
	signFace.Face = Enum.NormalId.Front
	signFace.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	signFace.CanvasSize = Vector2.new(900, 260)
	signFace.LightInfluence = 0
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

	local postZOffset = 5
	for _, offset in ipairs({ -postZOffset, postZOffset }) do
		local post = createPart(
			"TrailSignPost",
			Vector3.new(0.65, 3.4, 0.65),
			CFrame.new(x, 1.15, z + offset),
			Color3.fromRGB(95, 62, 38),
			Enum.Material.Wood,
			parent
		)
		post:SetAttribute("WorldLayoutOwned", true)
	end
end

local function createHomeEconomyStation(parent)
	local station = Instance.new("Model")
	station.Name = "HomeEconomyStation"
	station:SetAttribute("WorldLayoutOwned", true)
	station:SetAttribute("SellDistance", Configuration.HOME_ECONOMY_STATION.SellDistance)
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

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EconomyPrompt"
	prompt.ActionText = "Open Economy"
	prompt.ObjectText = "Lumber Depot"
	prompt.MaxActivationDistance = Configuration.HOME_ECONOMY_STATION.SellDistance
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = interaction

	local sign = Instance.new("BillboardGui")
	sign.Name = "StationSign"
	sign.Size = UDim2.fromOffset(260, 70)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0)
	sign.AlwaysOnTop = true
	sign.Parent = counter
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.Text = "LUMBER DEPOT"
	text.TextColor3 = Color3.fromRGB(255, 234, 181)
	text.TextStrokeTransparency = 0.35
	text.TextScaled = true
	text.Parent = sign

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

local function buildWorld()
	local existing = Workspace:FindFirstChild(Configuration.ROOT_NAME)
	if existing and existing:GetAttribute("WorldLayoutVersion") == Configuration.VERSION then
		return existing
	end
	if existing then
		for _, tree in ipairs(spawnedTreesByRoot[existing] or {}) do
			tree:Destroy()
		end
		spawnedTreesByRoot[existing] = nil
		existing:Destroy()
	end

	local root = createFolder(Configuration.ROOT_NAME, Workspace)
	local terrain = createFolder("Terrain", root)
	local pathFolder = createFolder("Path", root)
	local forestRoot = createFolder("Forests", root)
	root:SetAttribute("WorldLayoutOwned", true)
	createHomeEconomyStation(root)

	createGround(
		terrain,
		Configuration.CONNECTOR_GROUND.Name,
		Configuration.CONNECTOR_GROUND.Center,
		Configuration.CONNECTOR_GROUND.Size
	)
	for _, segment in ipairs(Configuration.PATH_SEGMENTS) do
		createPath(pathFolder, segment)
	end

	local spawnedTrees = {}
	for _, forestConfiguration in ipairs(Configuration.FORESTS) do
		local forestFolder = createFolder(forestConfiguration.Name, forestRoot)
		forestFolder:SetAttribute("ForestId", forestConfiguration.ForestId)
		createGround(
			forestFolder,
			"ForestGround",
			forestConfiguration.GroundCenter,
			forestConfiguration.GroundSize
		)
		createSign(forestFolder, forestConfiguration.Sign)

		for _, record in ipairs(forestConfiguration.Trees) do
			local tree = spawnTreeRecord(forestFolder, forestConfiguration.ForestId, record)
			if tree then table.insert(spawnedTrees, tree) end
		end
	end

	local starterForest = forestRoot:FindFirstChild("StarterForest")
	local barrier = spawnTreeRecord(starterForest, Configuration.BARRIER.ForestId, Configuration.BARRIER)
	if barrier then table.insert(spawnedTrees, barrier) end
	root:SetAttribute("WorldLayoutVersion", Configuration.VERSION)
	spawnedTreesByRoot[root] = spawnedTrees
	return root, spawnedTrees
end

function WorldLayoutService.Build()
	return buildWorld()
end

return WorldLayoutService
