-- Studio-only owner for the shared development gallery shell and navigation metadata.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Config = require(script.Parent:WaitForChild("Config"))

local OWNER_ATTRIBUTE = "DevGalleryOwner"
local COORDINATOR_OWNER = "Coordinator"
local FOREST_OWNER = "Forest"
local ROOT_NAME = "DevTreeGallery"
local NAV_REGISTRY_NAME = "DevGalleryNavRegistry"
local NAV_ENTRIES_NAME = "Entries"
local COORDINATOR_VERSION = 2
local FOREST_SHOWCASE_SCHEMA_VERSION = 2

local LABS = Config.Labs or {}
local ARCHIVE_CONFIG = Config.Archive or {}
local gallery
local navRegistry
local navEntries
local activeReferenceNav
local refreshScheduled = false
local galleryConnections = {}
local referenceConnections = {}

local function disconnectAll(connections)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function isOwned(instance, owner)
	return instance ~= nil and instance:GetAttribute(OWNER_ATTRIBUTE) == owner
end

local function removeOwnedWorkspaceModel(name, owner)
	local existing = Workspace:FindFirstChild(name)
	if not existing then
		return true
	end
	if not isOwned(existing, owner) then
		warn(("[DevGalleryCoordinator] %s is owned by another system; leaving it untouched."):format(name))
		return false
	end
	existing:Destroy()
	return true
end

local function createPart(parent, name, size, cframe, color, material, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color or Color3.fromRGB(64, 84, 69)
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = canCollide == true
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part:SetAttribute("DevOnly", true)
	part:SetAttribute("VisualOnly", true)
	part.Parent = parent
	return part
end

local function addPlaceholderLabel(parent, title, subtitle, position)
	local anchor = createPart(
		parent,
		"NavigationLabelAnchor",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(position),
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		false
	)
	anchor.Transparency = 1

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NavigationLabel"
	billboard.Size = UDim2.fromOffset(240, 66)
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.MaxDistance = 220
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(31, 48, 39)
	label.BackgroundTransparency = 0.12
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Text = title .. "\n" .. subtitle
	label.TextColor3 = Color3.fromRGB(245, 242, 220)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

local function addPlaceholderLab(root, origin, floorTopY, labId, configKey, xOffset)
	local modelName = labId .. "Lab"
	local model = Instance.new("Model")
	model.Name = modelName
	model:SetAttribute(OWNER_ATTRIBUTE, labId)
	model:SetAttribute("LabId", labId)
	model:SetAttribute("DevOnly", true)
	model:SetAttribute("VisualOnly", true)
	model:SetAttribute("BuildStatus", "Building")

	local zOffset = -62
	local center = Vector3.new(origin.X + xOffset, floorTopY, origin.Z + zOffset)
	local pad = createPart(
		model,
		"LandingPad",
		Vector3.new(34, 0.5, 22),
		CFrame.new(center.X, floorTopY + 0.25, center.Z),
		if labId == "Forest" then Color3.fromRGB(76, 114, 78) else Color3.fromRGB(93, 91, 72),
		Enum.Material.SmoothPlastic,
		true
	)
	pad:SetAttribute("NavigationTarget", true)

	local archiveStudiesEnabled = labId == "Archive" and ARCHIVE_CONFIG.TreeStudies == true
	local title = if labId == "Forest" then "FOREST LAB" else "ARCHIVE"
	local subtitle = if labId == "Forest"
		then "Studio-only prototype area"
		elseif archiveStudiesEnabled
		then "Tree studies are enabled; waiting for the archive builder."
		else "No archive studies enabled · see DevGallery.Config.Archive"
	addPlaceholderLabel(model, title, subtitle, center + Vector3.new(0, 8, 0))

	local arrival = Vector3.new(center.X, floorTopY + 4, center.Z + 8)
	local destination = CFrame.new(arrival)
	model:SetAttribute("NavigationDestinationCFrame", destination)
	model:SetAttribute("NavigationFocusPosition", nil)
	model:SetAttribute("NavigationSummary", subtitle)
	model:SetAttribute("BuildStatus", "Ready")
	model.Parent = root

	root:SetAttribute(configKey .. "LabReady", true)
	root:SetAttribute(configKey .. "LabDestinationCFrame", destination)
	root:SetAttribute(configKey .. "LabFocusPosition", center + Vector3.new(0, 4, -8))
	return model
end

local function addForestLabContainer(root)
	local model = Instance.new("Model")
	model.Name = "ForestLab"
	model:SetAttribute(OWNER_ATTRIBUTE, FOREST_OWNER)
	model:SetAttribute("LabId", "Forest")
	model:SetAttribute("DevOnly", true)
	model:SetAttribute("VisualOnly", true)
	model:SetAttribute("BuildStatus", "Building")
	model.Parent = root
	return model
end

local function buildGalleryShell()
	if typeof(Config.Origin) ~= "Vector3" then
		warn("[DevGalleryCoordinator] Config.Origin must be a Vector3; skipping the dev gallery.")
		return nil
	end

	local existing = Workspace:FindFirstChild(ROOT_NAME)
	if existing then
		if not isOwned(existing, COORDINATOR_OWNER) then
			warn(("[DevGalleryCoordinator] %s already exists and is not coordinator-owned; leaving it untouched."):format(ROOT_NAME))
			return nil
		end
		if existing:GetAttribute("CoordinatorVersion") == COORDINATOR_VERSION
			and existing:GetAttribute("BuildStatus") == "Ready"
			and typeof(existing:GetAttribute("GalleryOrigin")) == "Vector3"
			and (existing:GetAttribute("GalleryOrigin") - Config.Origin).Magnitude <= 0.01
			and existing:FindFirstChild("GalleryFloor")
			and existing:FindFirstChild("GalleryFloor"):IsA("BasePart")
			and existing:FindFirstChild("GallerySpawn")
			and existing:FindFirstChild("GallerySpawn"):IsA("BasePart")
		then
			return existing
		end
		existing:Destroy()
	end

	local origin = Config.Origin
	local root = Instance.new("Model")
	root.Name = ROOT_NAME
	root:SetAttribute(OWNER_ATTRIBUTE, COORDINATOR_OWNER)
	root:SetAttribute("DevOnly", true)
	root:SetAttribute("VisualOnly", true)
	root:SetAttribute("GalleryOrigin", origin)
	root:SetAttribute("CoordinatorVersion", COORDINATOR_VERSION)
	root:SetAttribute("BuildStatus", "Building")

	-- Preserve the prior gallery's world bounds and floor height. The tree and
	-- mesa builders rely on this direct child and on its top being Origin.Y-0.5.
	local floorSize = Vector3.new(360, 1, 1000)
	local floorCenter = origin + Vector3.new(180, -1, 400)
	local floor = createPart(
		root,
		"GalleryFloor",
		floorSize,
		CFrame.new(floorCenter),
		Color3.fromRGB(54, 78, 62),
		Enum.Material.SmoothPlastic,
		true
	)
	floor.Transparency = 0.12
	floor:SetAttribute("WalkableUtilitySurface", true)
	local floorTopY = floor.Position.Y + floor.Size.Y * 0.5

	local spawnPosition = origin + Vector3.new(20, 0.5, -78)
	local spawnMarker = createPart(
		root,
		"GallerySpawn",
		Vector3.new(1, 1, 1),
		CFrame.lookAt(spawnPosition, spawnPosition + Vector3.new(0, 0, 1)),
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		false
	)
	spawnMarker.Transparency = 1
	spawnMarker:SetAttribute("CommandBarHint", "PivotTo(GallerySpawn.CFrame + Vector3.new(0, 4, 0))")
	root.PrimaryPart = spawnMarker
	root:SetAttribute("GalleryEntryCFrame", spawnMarker.CFrame + Vector3.new(0, 4, 0))

	if LABS.Forest == true then
		addForestLabContainer(root)
	end
	if LABS.Archive == true then
		addPlaceholderLab(root, origin, floorTopY, "Archive", "Archive", 242)
	end

	root:SetAttribute("BuildStatus", "Ready")
	root.Parent = Workspace
	return root
end

local FOREST_NAV_ATTRIBUTES = {
	"ForestLabReady",
	"ForestLabDestinationCFrame",
	"ForestLabFocusPosition",
	"ForestSofterTeleportCFrame",
	"ForestSofterFocusPosition",
	"ForestSofterEstimatedInstances",
	"ForestChunkierTeleportCFrame",
	"ForestChunkierFocusPosition",
	"ForestChunkierEstimatedInstances",
	"ForestAssetSelectionReady",
	"ForestAssetSelectionTeleportCFrame",
	"ForestAssetSelectionFocusPosition",
	"ForestAssetSelectionEstimatedInstances",
}

local function clearForestMetadata(targetGallery)
	for _, attributeName in ipairs(FOREST_NAV_ATTRIBUTES) do
		targetGallery:SetAttribute(attributeName, nil)
	end
end

local function isFiniteNumber(value)
	return type(value) == "number" and value == value and math.abs(value) < 1000000
end

local function isValidVector3(value)
	return typeof(value) == "Vector3"
		and isFiniteNumber(value.X)
		and isFiniteNumber(value.Y)
		and isFiniteNumber(value.Z)
end

local function isValidCFrame(value)
	if typeof(value) ~= "CFrame" then
		return false
	end
	for _, component in ipairs({ value:GetComponents() }) do
		if not isFiniteNumber(component) then
			return false
		end
	end
	return true
end

local function isInsideGalleryBounds(position)
	if not isValidVector3(position) then
		return false
	end
	local origin = Config.Origin
	local horizontalOffset = Vector3.new(position.X - origin.X, 0, position.Z - origin.Z)
	return horizontalOffset.Magnitude <= 2000 and math.abs(position.Y - origin.Y) <= 800
end

local function resolveForestFocus(candidate, fallback, destination)
	if isValidVector3(candidate) then
		return candidate
	end
	if isValidVector3(fallback) then
		return fallback
	end
	return destination.Position + destination.LookVector * 16
end

local function hasWalkableCatalogFloor(target)
	local floor = target:FindFirstChild("AssetCatalogWalkway", true)
	return floor ~= nil
		and floor:IsA("BasePart")
		and floor:GetAttribute("WalkableUtilitySurface") == true
		and floor.CanCollide
end

local function hasReadyAssetSelectionModel(showcase)
	local target = showcase:FindFirstChild("ForestAssetSelectionShowcase")
	return target ~= nil
		and target:IsA("Model")
		and target:GetAttribute("BuildStatus") == "Ready"
		and target.ModelStreamingMode == Enum.ModelStreamingMode.Atomic
		and hasWalkableCatalogFloor(target)
end

local function buildForestDesignLab(targetGallery)
	if not isOwned(targetGallery, COORDINATOR_OWNER)
		or targetGallery.Parent ~= Workspace
		or targetGallery:GetAttribute("BuildStatus") ~= "Ready"
	then
		return false
	end

	local forestLab = targetGallery:FindFirstChild("ForestLab")
	if not forestLab or not forestLab:IsA("Model") or not isOwned(forestLab, FOREST_OWNER) then
		clearForestMetadata(targetGallery)
		if forestLab then
			warn("[DevGalleryCoordinator] ForestLab is owned by another system; leaving it untouched.")
		else
			warn("[DevGalleryCoordinator] ForestLab container is missing; forest navigation will stay unavailable.")
		end
		return false
	end

	local existingShowcase = forestLab:FindFirstChild("ForestDesignLab")
	if existingShowcase then
		local existingSofter = targetGallery:GetAttribute("ForestSofterTeleportCFrame")
		local existingChunkier = targetGallery:GetAttribute("ForestChunkierTeleportCFrame")
		local assetSelectionModule = script.Parent:FindFirstChild("ForestAssetSelectionShowcase")
		local assetSelectionExpected = assetSelectionModule and assetSelectionModule:IsA("ModuleScript")
		local assetSelectionDestination = targetGallery:GetAttribute("ForestAssetSelectionTeleportCFrame")
		local assetSelectionFocus = targetGallery:GetAttribute("ForestAssetSelectionFocusPosition")
		local existingAssetSelectionReady = not assetSelectionExpected
			or (
				targetGallery:GetAttribute("ForestAssetSelectionReady") == true
				and hasReadyAssetSelectionModel(existingShowcase)
				and isValidCFrame(assetSelectionDestination)
				and isValidVector3(assetSelectionFocus)
				and isInsideGalleryBounds(assetSelectionDestination.Position)
				and isInsideGalleryBounds(assetSelectionFocus)
			)
		if isOwned(existingShowcase, FOREST_OWNER)
			and existingShowcase:IsA("Model")
			and existingShowcase:GetAttribute("BuildStatus") == "Ready"
			and existingShowcase:GetAttribute("ForestDesignLabSchemaVersion") == FOREST_SHOWCASE_SCHEMA_VERSION
			and existingAssetSelectionReady
			and forestLab:GetAttribute("BuildStatus") == "Ready"
			and targetGallery:GetAttribute("ForestLabReady") == true
			and isValidCFrame(existingSofter)
			and isValidCFrame(existingChunkier)
			and isInsideGalleryBounds(existingSofter.Position)
			and isInsideGalleryBounds(existingChunkier.Position)
		then
			return true
		end
		if not isOwned(existingShowcase, FOREST_OWNER) then
			clearForestMetadata(targetGallery)
			warn("[DevGalleryCoordinator] ForestDesignLab is owned by another system; leaving it untouched.")
			return false
		end
		existingShowcase:Destroy()
	end

	clearForestMetadata(targetGallery)
	forestLab:SetAttribute("BuildStatus", "Building")
	local moduleScript = script.Parent:FindFirstChild("ForestDesignLab")
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		forestLab:SetAttribute("BuildStatus", "Unavailable")
		warn("[DevGalleryCoordinator] ForestDesignLab module is missing; Forest Lab is unavailable.")
		return false
	end

	local galleryFloor = targetGallery:FindFirstChild("GalleryFloor")
	if not galleryFloor or not galleryFloor:IsA("BasePart") then
		forestLab:SetAttribute("BuildStatus", "Unavailable")
		warn("[DevGalleryCoordinator] GalleryFloor is missing; Forest Lab is unavailable.")
		return false
	end
	local floorTopY = galleryFloor.Position.Y + galleryFloor.Size.Y * 0.5
	local center = Vector3.new(Config.Origin.X + 900, floorTopY, Config.Origin.Z)
	if not isInsideGalleryBounds(center) then
		forestLab:SetAttribute("BuildStatus", "Unavailable")
		warn("[DevGalleryCoordinator] Forest showcase center is outside the dev gallery bounds.")
		return false
	end

	local staging = Instance.new("Model")
	staging.Name = "ForestDesignLabStaging"
	local buildOk, showcase, metadata = pcall(function()
		local builder = require(moduleScript)
		assert(type(builder) == "table" and type(builder.Build) == "function", "ForestDesignLab must export Build")
		local builtShowcase, builtMetadata = builder.Build(staging, center)
		assert(builtShowcase and builtShowcase:IsA("Model"), "ForestDesignLab Build returned no Model")
		assert(builtShowcase.Parent == staging, "ForestDesignLab Build must parent its result to the supplied parent")
		assert(type(builtMetadata) == "table", "ForestDesignLab Build returned no metadata")
		return builtShowcase, builtMetadata
	end)
	if not buildOk then
		staging:Destroy()
		forestLab:SetAttribute("BuildStatus", "Failed")
		warn("[DevGalleryCoordinator] Forest Design Lab build failed: " .. tostring(showcase))
		return false
	end
	if targetGallery.Parent ~= Workspace
		or Workspace:FindFirstChild(ROOT_NAME) ~= targetGallery
		or not isOwned(targetGallery, COORDINATOR_OWNER)
		or forestLab.Parent ~= targetGallery
	then
		staging:Destroy()
		return false
	end

	local variations = metadata.Variations
	local softerDestination = if type(variations) == "table" then variations.Softer else nil
	local chunkierDestination = if type(variations) == "table" then variations.Chunkier else nil
	local focusByVariation = metadata.FocusByVariation
	local softerFocus = resolveForestFocus(
		if type(focusByVariation) == "table" then focusByVariation.Softer else nil,
		metadata.Focus,
		if isValidCFrame(softerDestination) then softerDestination else CFrame.new()
	)
	local chunkierFocus = resolveForestFocus(
		if type(focusByVariation) == "table" then focusByVariation.Chunkier else nil,
		metadata.Focus,
		if isValidCFrame(chunkierDestination) then chunkierDestination else CFrame.new()
	)
	local metadataValid = isValidCFrame(softerDestination)
		and isValidCFrame(chunkierDestination)
		and (softerDestination.Position - chunkierDestination.Position).Magnitude >= 20
		and isInsideGalleryBounds(softerDestination.Position)
		and isInsideGalleryBounds(chunkierDestination.Position)
		and isInsideGalleryBounds(softerFocus)
		and isInsideGalleryBounds(chunkierFocus)
	if not metadataValid then
		staging:Destroy()
		forestLab:SetAttribute("BuildStatus", "Failed")
		warn("[DevGalleryCoordinator] Forest Design Lab returned invalid variation destinations or focus positions.")
		return false
	end

	local assetSelectionMetadata = metadata.AssetSelection
	local assetSelectionTarget = showcase:FindFirstChild("ForestAssetSelectionShowcase")
	local assetSelectionDestination = if type(assetSelectionMetadata) == "table"
		then assetSelectionMetadata.LandingCFrame else nil
	local assetSelectionFocus = if type(assetSelectionMetadata) == "table"
		then assetSelectionMetadata.FocusPosition else nil
	local assetSelectionValid = hasReadyAssetSelectionModel(showcase)
		and isValidCFrame(assetSelectionDestination)
		and isValidVector3(assetSelectionFocus)
		and isInsideGalleryBounds(assetSelectionDestination.Position)
		and isInsideGalleryBounds(assetSelectionFocus)
	if not assetSelectionValid and assetSelectionTarget then
		assetSelectionTarget:Destroy()
		warn("[DevGalleryCoordinator] Forest asset selection metadata or walkable target was invalid; A/B remain available.")
	end

	showcase.Name = "ForestDesignLab"
	showcase:SetAttribute("ForestDesignLabSchemaVersion", FOREST_SHOWCASE_SCHEMA_VERSION)
	showcase:SetAttribute(OWNER_ATTRIBUTE, FOREST_OWNER)
	showcase:SetAttribute("LabId", "Forest")
	showcase:SetAttribute("DevOnly", true)
	showcase:SetAttribute("VisualOnly", true)
	showcase:SetAttribute("BuildStatus", "Ready")
	showcase.Parent = forestLab
	staging:Destroy()
	forestLab:SetAttribute("BuildStatus", "Ready")

	targetGallery:SetAttribute("ForestSofterTeleportCFrame", softerDestination)
	targetGallery:SetAttribute("ForestSofterFocusPosition", softerFocus)
	targetGallery:SetAttribute("ForestChunkierTeleportCFrame", chunkierDestination)
	targetGallery:SetAttribute("ForestChunkierFocusPosition", chunkierFocus)
	local instanceCounts = metadata.InstanceCounts
	if type(instanceCounts) == "table" then
		local softerEstimate = instanceCounts.Softer
		local chunkierEstimate = instanceCounts.Chunkier
		targetGallery:SetAttribute("ForestSofterEstimatedInstances", if isFiniteNumber(softerEstimate) then softerEstimate else nil)
		targetGallery:SetAttribute("ForestChunkierEstimatedInstances", if isFiniteNumber(chunkierEstimate) then chunkierEstimate else nil)
	end
	if assetSelectionValid then
		targetGallery:SetAttribute("ForestAssetSelectionTeleportCFrame", assetSelectionDestination)
		targetGallery:SetAttribute("ForestAssetSelectionFocusPosition", assetSelectionFocus)
		targetGallery:SetAttribute("ForestAssetSelectionEstimatedInstances",
			if type(assetSelectionMetadata) == "table" and isFiniteNumber(assetSelectionMetadata.InstanceCount)
				then assetSelectionMetadata.InstanceCount else nil)
		targetGallery:SetAttribute("ForestAssetSelectionReady", true)
	end
	targetGallery:SetAttribute("ForestLabReady", true)
	return true
end

local function disableForestLab(targetGallery)
	clearForestMetadata(targetGallery)
	local forestLab = targetGallery:FindFirstChild("ForestLab")
	if forestLab and isOwned(forestLab, FOREST_OWNER) then
		forestLab:Destroy()
	elseif forestLab then
		warn("[DevGalleryCoordinator] ForestLab is owned by another system; leaving it untouched.")
	end
end

local function getOrCreateNavigationRegistry()
	local existing = Workspace:FindFirstChild(NAV_REGISTRY_NAME)
	if existing then
		if not isOwned(existing, COORDINATOR_OWNER) then
			warn(("[DevGalleryCoordinator] %s is owned by another system; navigation will stay unavailable."):format(NAV_REGISTRY_NAME))
			return nil
		end
		local entries = existing:FindFirstChild(NAV_ENTRIES_NAME)
		if not entries or not entries:IsA("Folder") then
			entries = Instance.new("Folder")
			entries.Name = NAV_ENTRIES_NAME
			entries.Parent = existing
		end
		local marker = existing:FindFirstChild("RegistryMarker")
		if not marker or not marker:IsA("BasePart") then
			marker = createPart(
				existing,
				"RegistryMarker",
				Vector3.new(0.2, 0.2, 0.2),
				CFrame.new(Config.Origin + Vector3.new(0, 8, 0)),
				Color3.new(1, 1, 1),
				Enum.Material.SmoothPlastic,
				false
			)
			marker.Transparency = 1
		end
		existing.PrimaryPart = marker
		existing.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		existing:SetAttribute("BuildStatus", "Building")
		return existing, entries
	end

	local registry = Instance.new("Model")
	registry.Name = NAV_REGISTRY_NAME
	registry:SetAttribute(OWNER_ATTRIBUTE, COORDINATOR_OWNER)
	registry:SetAttribute("DevOnly", true)
	registry:SetAttribute("VisualOnly", true)
	registry:SetAttribute("BuildStatus", "Building")
	registry.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	-- The registry contains only metadata and one invisible part, never lab geometry.
	local marker = createPart(
		registry,
		"RegistryMarker",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(Config.Origin + Vector3.new(0, 8, 0)),
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		false
	)
	marker.Transparency = 1
	registry.PrimaryPart = marker

	local entries = Instance.new("Folder")
	entries.Name = NAV_ENTRIES_NAME
	entries.Parent = registry
	registry.Parent = Workspace
	return registry, entries
end

local function getNavigationEntry(entryId)
	local entry = navEntries and navEntries:FindFirstChild(entryId)
	if entry and entry:IsA("Folder") and isOwned(entry, COORDINATOR_OWNER) then
		return entry
	end
	if entry then
		warn(("[DevGalleryCoordinator] Navigation entry %s is owned by another system; leaving it untouched."):format(entryId))
		return nil
	end
	entry = Instance.new("Folder")
	entry.Name = entryId
	entry:SetAttribute(OWNER_ATTRIBUTE, COORDINATOR_OWNER)
	entry.Parent = navEntries
	return entry
end

local function upsertEntry(entryId, properties)
	if not navEntries then
		return
	end
	local entry = getNavigationEntry(entryId)
	if not entry then
		return
	end
	for key, value in pairs(properties) do
		entry:SetAttribute(key, value)
	end
	-- Nil values are omitted from a Lua table literal, so clear optional camera
	-- metadata explicitly when an entry no longer supplies it.
	entry:SetAttribute("FocusPosition", properties.FocusPosition)
	entry:SetAttribute("Summary", properties.Summary or "")
	entry:SetAttribute("CameraDistance", properties.CameraDistance or 20)
	entry:SetAttribute("CameraHeight", properties.CameraHeight or 8)
	entry:SetAttribute("Ready", true)
	entry:SetAttribute("Enabled", true)
end

local function removeStaleEntries(wanted)
	if not navEntries then
		return
	end
	for _, entry in ipairs(navEntries:GetChildren()) do
		if entry:IsA("Folder")
			and isOwned(entry, COORDINATOR_OWNER)
			and not wanted[entry.Name]
		then
			entry:Destroy()
		end
	end
end

local function addRootEntry(wanted, entryId, label, labId, destination, focus, targetName, summary)
	if typeof(destination) ~= "CFrame" then
		return
	end
	wanted[entryId] = true
	upsertEntry(entryId, {
		LabId = labId,
		Label = label,
		DestinationCFrame = destination,
		FocusPosition = if typeof(focus) == "Vector3" then focus else nil,
		TargetRootName = ROOT_NAME,
		TargetName = targetName,
		Summary = summary or "",
		CameraDistance = if labId == "Terrain" then 12 else 20,
		CameraHeight = if labId == "Terrain" then 34 else 8,
	})
end

local function refreshNavigation()
	if not navRegistry or not navEntries then
		return
	end
	navRegistry:SetAttribute("BuildStatus", "Building")
	local wanted = {}
	if gallery and gallery.Parent == Workspace and gallery:GetAttribute("BuildStatus") == "Ready" then
		addRootEntry(
			wanted,
			"Entry",
			"GALLERY ENTRY",
			"Gallery",
			gallery:GetAttribute("GalleryEntryCFrame"),
			nil,
			"GalleryFloor"
		)

		if LABS.Tree == true and gallery:GetAttribute("TreeLabReady") == true then
			local treeDestination = gallery:GetAttribute("ProceduralHarvestShowcaseTeleportCFrame")
			local legacyTreeDestination = gallery:GetAttribute("ShowcaseTeleportCFrame")
			if typeof(treeDestination) ~= "CFrame" then
				treeDestination = legacyTreeDestination
			end
			addRootEntry(
				wanted,
				"Tree",
				"TREE LAB",
				"Tree",
				treeDestination,
				nil,
				"TreeLab"
			)
			if typeof(legacyTreeDestination) == "CFrame"
				and legacyTreeDestination ~= treeDestination
			then
				addRootEntry(
					wanted,
					"TreeOverview",
					"TREE SHOWCASE",
					"Tree",
					legacyTreeDestination,
					nil,
					"TreeLab"
				)
			end
		end
		if LABS.Terrain == true and gallery:GetAttribute("MesaShapeShowcaseVersion") ~= nil then
			local mesaCenter = gallery:GetAttribute("MesaComparisonSampleCenter")
			addRootEntry(
				wanted,
				"Mesa",
				"MESA OVERVIEW",
				"Terrain",
				gallery:GetAttribute("MesaComparisonTeleportCFrame"),
				mesaCenter,
				"MesaShowcaseSupport"
			)
			addRootEntry(
				wanted,
				"Terrain",
				"TERRAIN BOUNDARY",
				"Terrain",
				gallery:GetAttribute("MesaTerrainBoundaryTeleportCFrame"),
				gallery:GetAttribute("MesaTerrainBoundarySampleCenter"),
				"TerrainBoundarySample"
			)
			addRootEntry(
				wanted,
				"MesaFaceted",
				"FACETED BOUNDARY",
				"Terrain",
				gallery:GetAttribute("MesaFacetedBoundaryTeleportCFrame"),
				gallery:GetAttribute("MesaFacetedBoundarySampleCenter"),
				"FacetedBoundarySample"
			)
			addRootEntry(
				wanted,
				"MesaMixed",
				"MIXED BOUNDARY",
				"Terrain",
				gallery:GetAttribute("MesaMixedBoundaryTeleportCFrame"),
				gallery:GetAttribute("MesaMixedBoundarySampleCenter"),
				"MixedBoundarySample"
			)
		end

		local forestLab = gallery:FindFirstChild("ForestLab")
		if LABS.Forest == true
			and gallery:GetAttribute("ForestLabReady") == true
			and forestLab and isOwned(forestLab, FOREST_OWNER)
			and forestLab:GetAttribute("BuildStatus") == "Ready"
		then
			addRootEntry(
				wanted,
				"ForestSofter",
				"FOREST A · SOFTER STORYBOOK",
				"Forest",
				gallery:GetAttribute("ForestSofterTeleportCFrame"),
				gallery:GetAttribute("ForestSofterFocusPosition"),
				"SofterStorybookClearing",
				"Warm, gentler World 1 clearing"
			)
			addRootEntry(
				wanted,
				"ForestChunkier",
				"FOREST B · CHUNKIER STORYBOOK",
				"Forest",
				gallery:GetAttribute("ForestChunkierTeleportCFrame"),
				gallery:GetAttribute("ForestChunkierFocusPosition"),
				"ChunkierStorybookClearing",
				"Chunkier toy forms · same World 1 theme"
			)

			local designLab = forestLab:FindFirstChild("ForestDesignLab")
			local assetSelectionTarget = designLab and designLab:FindFirstChild("ForestAssetSelectionShowcase")
			local assetSelectionDestination = gallery:GetAttribute("ForestAssetSelectionTeleportCFrame")
			local assetSelectionFocus = gallery:GetAttribute("ForestAssetSelectionFocusPosition")
			if gallery:GetAttribute("ForestAssetSelectionReady") == true
				and designLab and designLab:IsA("Model")
				and designLab:GetAttribute("BuildStatus") == "Ready"
				and hasReadyAssetSelectionModel(designLab)
				and isValidCFrame(assetSelectionDestination)
				and isValidVector3(assetSelectionFocus)
				and isInsideGalleryBounds(assetSelectionDestination.Position)
				and isInsideGalleryBounds(assetSelectionFocus)
				and assetSelectionTarget
			then
				addRootEntry(
					wanted,
					"ForestAssetSelection",
					"FOREST ASSET CATALOG",
					"Forest",
					assetSelectionDestination,
					assetSelectionFocus,
					"ForestAssetSelectionShowcase",
					"Curated Creator Store model previews"
				)
			end
		end
		if LABS.Archive == true and gallery:GetAttribute("ArchiveLabReady") == true then
			local studiesEnabled = ARCHIVE_CONFIG.TreeStudies == true
			local studiesReady = studiesEnabled and gallery:GetAttribute("TreeStudiesArchiveReady") == true
			local archiveSummary = if studiesReady
				then "Archived tree studies"
				elseif studiesEnabled
				then "Tree studies are enabled; waiting for the archive builder."
				else "No archive studies enabled · see DevGallery.Config.Archive"
			addRootEntry(
				wanted,
				"Archive",
				if studiesReady then "ARCHIVE · TREE STUDIES" elseif studiesEnabled then "ARCHIVE · LOADING" else "ARCHIVE · EMPTY",
				"Archive",
				if studiesReady
					then gallery:GetAttribute("TreeStudiesArchiveTeleportCFrame")
					else gallery:GetAttribute("ArchiveLabDestinationCFrame"),
				if studiesReady
					then gallery:GetAttribute("TreeStudiesArchiveFocusPosition")
					else gallery:GetAttribute("ArchiveLabFocusPosition"),
				if studiesReady then "TreeStudiesArchive" else "ArchiveLab",
				archiveSummary
			)
		end
	end

	local referenceNav = Workspace:FindFirstChild("DevStudioReferenceTeleport")
	local referenceScene = Workspace:FindFirstChild("DevStudioReferenceGallery")
	if LABS.Terrain == true
		and gallery and gallery.Parent == Workspace
		and gallery:GetAttribute(OWNER_ATTRIBUTE) == COORDINATOR_OWNER
		and gallery:GetAttribute("BuildStatus") == "Ready"
		and referenceNav and referenceScene
		and referenceNav:GetAttribute("DevStudioReferenceGalleryOwner") == "DevStudioReferenceGallery.server"
		and referenceScene:GetAttribute("DevStudioReferenceGalleryOwner") == "DevStudioReferenceGallery.server"
	then
		local referenceDestination = referenceNav:GetAttribute("ReferenceTeleportCFrame")
		if typeof(referenceDestination) == "CFrame" then
			wanted.References = true
			upsertEntry("References", {
				LabId = "References",
				Label = "REFERENCE ASSETS",
				DestinationCFrame = referenceDestination,
				FocusPosition = referenceNav:GetAttribute("ReferenceFocusPosition"),
				TargetRootName = "DevStudioReferenceGallery",
				TargetName = "DevStudioReferenceGallery",
				Summary = "Studio-only source asset displays",
				CameraDistance = 20,
				CameraHeight = 8,
			})
		end
	end

	removeStaleEntries(wanted)
	navRegistry:SetAttribute("GalleryOrigin", if gallery then gallery:GetAttribute("GalleryOrigin") else nil)
	navRegistry:SetAttribute("EntryCount", #navEntries:GetChildren())
	navRegistry:SetAttribute("BuildStatus", "Ready")
end

local function scheduleNavigationRefresh()
	if refreshScheduled then
		return
	end
	refreshScheduled = true
	task.defer(function()
		refreshScheduled = false
		refreshNavigation()
	end)
end

local function watchGallery(candidate)
	disconnectAll(galleryConnections)
	gallery = candidate
	if gallery and isOwned(gallery, COORDINATOR_OWNER) then
		table.insert(galleryConnections, gallery.AttributeChanged:Connect(scheduleNavigationRefresh))
		table.insert(galleryConnections, gallery.ChildAdded:Connect(scheduleNavigationRefresh))
		table.insert(galleryConnections, gallery.ChildRemoved:Connect(scheduleNavigationRefresh))
	else
		gallery = nil
	end
	scheduleNavigationRefresh()
end

local function watchReferenceNav(candidate)
	disconnectAll(referenceConnections)
	activeReferenceNav = candidate
	if activeReferenceNav then
		table.insert(referenceConnections, activeReferenceNav.AttributeChanged:Connect(scheduleNavigationRefresh))
	end
	scheduleNavigationRefresh()
end

local function clearOwnedRuntime()
	local existingRoot = Workspace:FindFirstChild(ROOT_NAME)
	if existingRoot and isOwned(existingRoot, COORDINATOR_OWNER) then
		existingRoot:Destroy()
	end
	local existingRegistry = Workspace:FindFirstChild(NAV_REGISTRY_NAME)
	if existingRegistry and isOwned(existingRegistry, COORDINATOR_OWNER) then
		existingRegistry:Destroy()
	end
end

if Config.Enabled ~= true then
	clearOwnedRuntime()
	return
end

if typeof(Config.Origin) ~= "Vector3" then
	warn("[DevGalleryCoordinator] Config.Origin must be a Vector3; skipping the dev gallery.")
	return
end

-- Establish the lightweight persistent registry first so the single client UI
-- can appear as soon as any independently enabled lab reports ready.
navRegistry, navEntries = getOrCreateNavigationRegistry()
if not navRegistry then
	return
end

local builtGallery = buildGalleryShell()
if not builtGallery then
	navRegistry:SetAttribute("BuildStatus", "Unavailable")
	return
end
watchGallery(builtGallery)
watchReferenceNav(Workspace:FindFirstChild("DevStudioReferenceTeleport"))

Workspace.ChildAdded:Connect(function(child)
	if child.Name == ROOT_NAME then
		watchGallery(child)
	elseif child.Name == "DevStudioReferenceTeleport" then
		watchReferenceNav(child)
	elseif child.Name == "DevStudioReferenceGallery" then
		scheduleNavigationRefresh()
	end
end)

Workspace.ChildRemoved:Connect(function(child)
	if child == gallery then
		watchGallery(nil)
	elseif child == activeReferenceNav then
		watchReferenceNav(nil)
	elseif child.Name == "DevStudioReferenceGallery" then
		scheduleNavigationRefresh()
	end
end)

if LABS.Forest == true then
	task.spawn(function()
		local buildOk, buildError = pcall(buildForestDesignLab, builtGallery)
		if not buildOk then
			if builtGallery.Parent == Workspace and Workspace:FindFirstChild(ROOT_NAME) == builtGallery then
				clearForestMetadata(builtGallery)
				local forestLab = builtGallery:FindFirstChild("ForestLab")
				if forestLab and isOwned(forestLab, FOREST_OWNER) then
					forestLab:SetAttribute("BuildStatus", "Failed")
				end
			end
			warn("[DevGalleryCoordinator] Forest Design Lab setup failed: " .. tostring(buildError))
		end
		scheduleNavigationRefresh()
	end)
else
	disableForestLab(builtGallery)
end

scheduleNavigationRefresh()

