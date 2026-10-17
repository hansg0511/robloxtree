-- Studio-only visual gallery for comparing tree builders and Grove metadata.
-- Enable manually for an inspection session, then sync/restart the server.
local ENABLED = false

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local TreeObject = require(ServerScriptService:WaitForChild("Trees"):WaitForChild("TreeObject"))
local TreeVisualModifiers = require(ServerStorage:WaitForChild("TreeVisualModifiers"))

local GALLERY_NAME = "DevTreeGallery"
local GALLERY_ORIGIN = Vector3.new(6000, 120, 6000)
local GALLERY_FLOOR_SIZE = Vector3.new(360, 1, 620)
local GALLERY_FLOOR_OFFSET = Vector3.new(180, -1, 210)
local MIN_PLATFORM_SIZE = 24
local PLATFORM_PADDING = 12
local COLUMN_GAP = 20
local ROW_GAP = 46

if not ENABLED then
	-- Turning the Studio tool off removes a gallery created during an earlier
	-- inspection session, while published servers never reach this code path.
	local existingGallery = Workspace:FindFirstChild(GALLERY_NAME)
	if existingGallery then existingGallery:Destroy() end
	return
end

local MUTATION_VARIANTS = {
	{ Label = "No Mutation", Mutations = {} },
	{ Label = "Golden", Mutations = { Golden = true } },
	{ Label = "Giant", Mutations = { Giant = true } },
	{ Label = "Crystal", Mutations = { Crystal = true } },
	{ Label = "Golden + Crystal", Mutations = { Golden = true, Crystal = true } },
}

local function createPart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function addSign(parent, label, position, width, name)
	local post = createPart(
		parent,
		name .. "Post",
		Vector3.new(0.8, 2.5, 0.8),
		CFrame.new(position.X, GALLERY_ORIGIN.Y + 1.25, position.Z),
		Color3.fromRGB(70, 91, 77)
	)
	post.TopSurface = Enum.SurfaceType.Smooth
	post.BottomSurface = Enum.SurfaceType.Smooth

	local board = createPart(
		parent,
		name,
		Vector3.new(width, 4, 0.7),
		CFrame.new(position.X, GALLERY_ORIGIN.Y + 4.2, position.Z),
		Color3.fromRGB(31, 53, 43)
	)
	board.TopSurface = Enum.SurfaceType.Smooth
	board.BottomSurface = Enum.SurfaceType.Smooth

	local surface = Instance.new("SurfaceGui")
	surface.Name = "LabelSurface"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 36
	surface.LightInfluence = 0
	surface.Parent = board

	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = label
	text.TextColor3 = Color3.fromRGB(239, 246, 235)
	text.TextStrokeColor3 = Color3.fromRGB(16, 27, 20)
	text.TextStrokeTransparency = 0.35
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.Parent = surface
	return board
end

local function makeContext(stage, mutations)
	return {
		GroveStage = stage,
		SizePotential = 1,
		Mutations = table.clone(mutations),
	}
end

local function buildPreview(kind, speciesId, stage, mutations, displayLabel)
	local context = makeContext(stage, mutations)
	local model = TreeObject.BuildPreviewModel(kind, context)
	assert(model and model:IsA("Model"), "Tree preview builder returned no Model for " .. kind)

	-- Reapplying is intentional and idempotent: the gallery owns the displayed
	-- metadata context even if the builder later gains a separate caller.
	TreeVisualModifiers.Apply(model, {
		SpeciesId = speciesId,
		GroveStage = stage,
		SizePotential = context.SizePotential,
		Mutations = context.Mutations,
		CurrentScale = model:GetAttribute("VisualScale"),
	})

	model.Name = "Preview_" .. kind .. "_" .. string.gsub(displayLabel, "%W+", "_")
	model:SetAttribute("DevTreeGalleryPreview", true)
	model:SetAttribute("DevTreeGalleryLabel", displayLabel)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
	return model
end

local function makeEntry(kind, speciesId, stage, mutations, label)
	local model = buildPreview(kind, speciesId, stage, mutations, label)
	local _, bounds = model:GetBoundingBox()
	local platformSize = Vector3.new(
		math.max(MIN_PLATFORM_SIZE, bounds.X + PLATFORM_PADDING),
		1,
		math.max(MIN_PLATFORM_SIZE, bounds.Z + PLATFORM_PADDING)
	)
	return {
		Kind = kind,
		Label = label,
		Model = model,
		PlatformSize = platformSize,
	}
end

local function addPlatform(parent, name, position, size)
	local platform = createPart(
		parent,
		name,
		size,
		CFrame.new(position.X, GALLERY_ORIGIN.Y - 0.5, position.Z),
		Color3.fromRGB(73, 112, 82),
		Enum.Material.SmoothPlastic
	)
	platform.TopSurface = Enum.SurfaceType.Smooth
	platform.BottomSurface = Enum.SurfaceType.Smooth
	return platform
end

local function arrangeRow(gallery, title, entries, rowZ)
	local rowDepth = MIN_PLATFORM_SIZE
	local rowWidth = 0
	for index, entry in ipairs(entries) do
		rowDepth = math.max(rowDepth, entry.PlatformSize.Z)
		rowWidth += entry.PlatformSize.X
		if index > 1 then
			rowWidth += COLUMN_GAP
		end
	end

	local cursorX = GALLERY_ORIGIN.X
	for index, entry in ipairs(entries) do
		local width = entry.PlatformSize.X
		local depth = entry.PlatformSize.Z
		local centerX = cursorX + width * 0.5
		local centerZ = GALLERY_ORIGIN.Z + rowZ
		local platformCenter = Vector3.new(centerX, GALLERY_ORIGIN.Y - 0.5, centerZ)
		addPlatform(gallery, "Platform_" .. title .. "_" .. index, platformCenter, entry.PlatformSize)

		local model = entry.Model
		model:PivotTo(CFrame.new(centerX, GALLERY_ORIGIN.Y, centerZ))
		local boxCFrame, boxSize = model:GetBoundingBox()
		local modelBottomY = boxCFrame.Position.Y - boxSize.Y * 0.5
		model:PivotTo(model:GetPivot() + Vector3.new(0, GALLERY_ORIGIN.Y - modelBottomY + 0.04, 0))
		model.Parent = gallery

		local frontZ = centerZ - depth * 0.5 - 2
		addSign(gallery, entry.Label, Vector3.new(centerX, 0, frontZ), math.clamp(width - 2, 18, 42), "Sign_" .. title .. "_" .. index)
		cursorX += width + COLUMN_GAP
	end

	local rowCenterX = GALLERY_ORIGIN.X + rowWidth * 0.5
	local headerZ = GALLERY_ORIGIN.Z + rowZ - rowDepth * 0.5 - 21
	addSign(gallery, title, Vector3.new(rowCenterX, 0, headerZ), math.clamp(rowWidth * 0.42, 28, 46), "Header_" .. title)

	return rowDepth, rowWidth, rowCenterX
end

local function createGallery()
	local gallery = Instance.new("Model")
	gallery.Name = GALLERY_NAME
	gallery:SetAttribute("DevOnly", true)
	gallery:SetAttribute("VisualOnly", true)
	gallery:SetAttribute("GalleryOrigin", GALLERY_ORIGIN)

	-- Preview trees remain completely non-colliding. This Studio-only floor is
	-- the sole walkable utility surface so a manually teleported tester can
	-- inspect the rows without falling from the isolated gallery area.
	local floorCenter = GALLERY_ORIGIN + GALLERY_FLOOR_OFFSET
	local floor = createPart(
		gallery,
		"GalleryFloor",
		GALLERY_FLOOR_SIZE,
		CFrame.new(floorCenter),
		Color3.fromRGB(54, 78, 62),
		Enum.Material.SmoothPlastic
	)
	floor.CanCollide = true
	floor.Transparency = 0.12

	local spawnPosition = GALLERY_ORIGIN + Vector3.new(20, 0.5, -78)
	local spawnMarker = createPart(
		gallery,
		"GallerySpawn",
		Vector3.new(1, 1, 1),
		CFrame.lookAt(spawnPosition, spawnPosition + Vector3.new(0, 0, 1)),
		Color3.new(1, 1, 1)
	)
	spawnMarker.Transparency = 1
	spawnMarker:SetAttribute("CommandBarHint", "PivotTo(GallerySpawn.CFrame + Vector3.new(0, 4, 0))")
	gallery.PrimaryPart = spawnMarker

	local firstHeaderPosition = GALLERY_ORIGIN + Vector3.new(20, 0, -57)
	addSign(gallery, "DEV TREE GALLERY - START HERE", firstHeaderPosition, 40, "GalleryWelcome")

	local nextZ = 0
	local function addRow(title, entries)
		local rowDepth = arrangeRow(gallery, title, entries, nextZ)
		nextZ += rowDepth + ROW_GAP
	end

	for _, species in ipairs({
		{ Label = "OAK", Kind = "GroveOak", SpeciesId = "Oak" },
		{ Label = "BAMBOO", Kind = "Bamboo", SpeciesId = "Bamboo" },
		{ Label = "IRONWOOD", Kind = "Ironwood", SpeciesId = "Ironwood" },
	}) do
		local entries = {}
		for _, variant in ipairs(MUTATION_VARIANTS) do
			table.insert(entries, makeEntry(
				species.Kind,
				species.SpeciesId,
				"mature",
				variant.Mutations,
				species.Label .. " - " .. variant.Label
			))
		end
		addRow("MATURE GROVE MUTATIONS / " .. species.Label, entries)
	end

	for _, species in ipairs({
		{ Label = "OAK", Kind = "GroveOak", SpeciesId = "Oak" },
		{ Label = "BAMBOO", Kind = "Bamboo", SpeciesId = "Bamboo" },
		{ Label = "IRONWOOD", Kind = "Ironwood", SpeciesId = "Ironwood" },
	}) do
		local entries = {}
		for _, stage in ipairs({
			{ Label = "Sapling", Id = "sapling" },
			{ Label = "Young", Id = "young" },
			{ Label = "Mature", Id = "mature" },
		}) do
			table.insert(entries, makeEntry(
				species.Kind,
				species.SpeciesId,
				stage.Id,
				{},
				species.Label .. " - " .. stage.Label
			))
		end
		addRow("GROWTH STAGES / " .. species.Label, entries)
	end

	addRow("MATURE OAK BUILDER COMPARISON", {
		makeEntry("WildOak", "Oak", "mature", {}, "Wild Oak"),
		makeEntry("GroveOak", "Oak", "mature", {}, "Grove Oak"),
	})

	return gallery
end

local ok, galleryOrError = pcall(createGallery)
if not ok then
	warn("[DevTreeGallery] Build failed: " .. tostring(galleryOrError))
	return
end

local previousGallery = Workspace:FindFirstChild(GALLERY_NAME)
if previousGallery then
	previousGallery:Destroy()
end

galleryOrError.Parent = Workspace
print(
	"[DevTreeGallery] Built at " .. tostring(GALLERY_ORIGIN)
		.. ". Server Command Bar: local p=game:GetService(\"Players\"):GetPlayers()[1]; local g=workspace:FindFirstChild(\"DevTreeGallery\"); local s=g and g:FindFirstChild(\"GallerySpawn\"); if p and p.Character and s then p.Character:PivotTo(s.CFrame + Vector3.new(0, 4, 0)) end"
)
