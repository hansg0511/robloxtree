local Tree = {}
Tree.__index = Tree

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local SpeciesVisuals = require(ServerStorage:WaitForChild("SpeciesVisuals"))
local TreeVisualModifiers = require(ServerStorage:WaitForChild("TreeVisualModifiers"))
local ChopFX = game.ReplicatedStorage.Chop.ChopFX
local DamageEvent = game.ReplicatedStorage.DamageEvent
local FXService = require(game.ReplicatedStorage.FXService)
local HarvestVisualConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("HarvestVisualConfig"))
local Definitions = require(script.Parent.TreeDefinitions)
local MutationDefinitions = require(game.ServerScriptService.Grove.MutationDefinitions)
local WorldProgressService = require(game.ServerScriptService.WorldProgressService)
local LogService = require(game.ServerScriptService.Inventory.LogService)
local MaterialDefinitions = require(game.ServerScriptService.Economy.MaterialDefinitions)
local SaplingDiscoveryService = require(game.ServerScriptService.Grove.SaplingDiscoveryService)

local treeRandom = Random.new()

local function rollTreeScale()
	local roll = treeRandom:NextNumber()
	if roll < 0.82 then
		return treeRandom:NextNumber(0.7, 1.3)
	elseif roll < 0.91 then
		return treeRandom:NextNumber(0.45, 0.7)
	end
	return treeRandom:NextNumber(1.3, 1.7)
end

local function makeBrickPart(name, size, position, color, parent, root, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Color = color
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Inlet
	part.FrontSurface = Enum.SurfaceType.Studs
	part.BackSurface = Enum.SurfaceType.Studs
	part.LeftSurface = Enum.SurfaceType.Studs
	part.RightSurface = Enum.SurfaceType.Studs
	part.Anchored = root == nil
	if canCollide == nil then
		part.CanCollide = root == nil
	else
		part.CanCollide = canCollide
	end
	part.Parent = parent
	if root then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end
	return part
end

local function addBarkStuds(brick, root, palette)
	local studDiameter = math.clamp(math.min(brick.Size.X, brick.Size.Z) * 0.11, 0.38, 0.72)
	local studDepth = math.clamp(studDiameter * 0.48, 0.16, 0.3)
	local function attachStud(position, rotation, color)
		local stud = Instance.new("Part")
		stud.Name = "BarkStud"
		stud.Shape = Enum.PartType.Cylinder
		stud.Size = Vector3.new(studDepth, studDiameter, studDiameter)
		stud.CFrame = brick.CFrame * CFrame.new(position) * rotation
		stud.Color = color
		stud.Material = Enum.Material.Plastic
		stud.Anchored = false
		stud.CanCollide = false
		stud.Parent = brick.Parent
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = stud
		weld.Parent = stud
	end

	local halfX, halfZ = brick.Size.X * 0.24, brick.Size.Z * 0.24
	local topRotation = CFrame.Angles(0, 0, math.rad(90))
	for _, x in ipairs({ -halfX, halfX }) do
		for _, z in ipairs({ -halfZ, halfZ }) do
			attachStud(Vector3.new(x, brick.Size.Y * 0.5 + studDepth * 0.42, z), topRotation, palette.BarkHighlight)
		end
	end

	-- Side studs make the trunk read as stacked toy bricks from every approach.
	local faceStuds = {
		{ NormalOffset = Vector3.new(0, 0, 1), Rotation = CFrame.Angles(0, math.rad(-90), 0), Axis = "X" },
		{ NormalOffset = Vector3.new(0, 0, -1), Rotation = CFrame.Angles(0, math.rad(90), 0), Axis = "X" },
		{ NormalOffset = Vector3.new(1, 0, 0), Rotation = CFrame.new(), Axis = "Z" },
		{ NormalOffset = Vector3.new(-1, 0, 0), Rotation = CFrame.Angles(0, math.rad(180), 0), Axis = "Z" },
	}
	for _, face in ipairs(faceStuds) do
		for _, y in ipairs({ -brick.Size.Y * 0.24, brick.Size.Y * 0.24 }) do
			local normalDistance = face.Axis == "X" and brick.Size.Z * 0.5 or brick.Size.X * 0.5
			local position
			if face.Axis == "X" then
				position = Vector3.new(0, y, face.NormalOffset.Z * (normalDistance + studDepth * 0.42))
			else
				position = Vector3.new(face.NormalOffset.X * (normalDistance + studDepth * 0.42), y, 0)
			end
			local accent = y < 0 and palette.BarkShadow or palette.BarkHighlight
			attachStud(position, face.Rotation, accent)
		end
	end
end

local function makeBrickPlaceholder()
	local model = Instance.new("Model")
	model.Name = "BrickPlaceholder"

	local oakPalette = SpeciesVisuals.GetPalette("Oak")
	local barkColor = oakPalette.Bark
	local bark = makeBrickPart("Bark", Vector3.new(8, 4, 8), Vector3.new(0, 2, 0), barkColor, model)
	bark.PivotOffset = CFrame.new(0, -2, 0)
	model.PrimaryPart = bark
	addBarkStuds(bark, bark, oakPalette)

	-- Server-owned trunk interaction geometry. It is invisible and non-queryable
	-- so it never becomes a client aiming aid; the server uses its bounds only.
	local chopHitbox = makeBrickPart("ChopHitbox", Vector3.new(10, 18, 10), Vector3.new(0, 9, 0), Color3.new(), model, bark)
	chopHitbox.Transparency = 1
	chopHitbox.CanCollide = false
	chopHitbox.CanTouch = false
	chopHitbox.CanQuery = false
	chopHitbox.Massless = true
	chopHitbox:SetAttribute("AlwaysInvisible", true)

	for index, definition in ipairs({
		{ Vector3.new(7, 4, 7), Vector3.new(1, 6, -1), oakPalette.BarkHighlight },
		{ Vector3.new(8, 4, 8), Vector3.new(-1, 10, 1), barkColor },
		{ Vector3.new(7, 4, 7), Vector3.new(0, 14, 0), oakPalette.BarkHighlight },
	}) do
		local brick = makeBrickPart("BarkBrick" .. index, definition[1], definition[2], definition[3], model, bark)
		addBarkStuds(brick, bark, oakPalette)
	end

	local leaves = Instance.new("Folder")
	leaves.Name = "Leaves"
	leaves.Parent = model
	for index, definition in ipairs({
		{ Vector3.new(18, 8, 18), Vector3.new(0, 18, 0), oakPalette.Leaf },
		{ Vector3.new(14, 8, 14), Vector3.new(-6, 22, -2), oakPalette.LeafHighlight },
		{ Vector3.new(14, 8, 14), Vector3.new(6, 22, 2), oakPalette.LeafShadow },
		{ Vector3.new(16, 7, 16), Vector3.new(0, 27, 0), oakPalette.LeafHighlight },
	}) do
		local leaf = makeBrickPart("Leaf" .. index, definition[1], definition[2], definition[3], leaves, bark)
		leaf.CanCollide = false
	end

	return model
end

local function makeTreeFrame(modelName, trunkSize, trunkPosition, palette)
	local model = Instance.new("Model")
	model.Name = modelName

	local trunk = makeBrickPart("Bark", trunkSize, trunkPosition, palette.Bark, model)
	trunk.PivotOffset = CFrame.new(0, -trunkSize.Y * 0.5, 0)
	model.PrimaryPart = trunk
	addBarkStuds(trunk, trunk, palette)

	local leaves = Instance.new("Folder")
	leaves.Name = "Leaves"
	leaves.Parent = model
	return model, trunk, leaves
end

local function addBarkBrick(model, root, name, size, position, color, palette, canCollide)
	local brick = makeBrickPart(name, size, position, color, model, root, canCollide)
	addBarkStuds(brick, root, palette)
	return brick
end

local function addLeafBricks(leaves, root, definitions, canCollide)
	for index, definition in ipairs(definitions) do
		local leaf = makeBrickPart(
			"Leaf" .. index,
			definition.Size,
			definition.Position,
			definition.Color,
			leaves,
			root,
			canCollide
		)
		leaf.CanCollide = canCollide == true
	end
end

local function addChopHitbox(model, root, size, position)
	local hitbox = makeBrickPart("ChopHitbox", size, position, Color3.new(), model, root, false)
	hitbox.Transparency = 1
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CanQuery = false
	hitbox.Massless = true
	hitbox:SetAttribute("AlwaysInvisible", true)
	return hitbox
end

local function makeStarterForestTree()
	local oakPalette = SpeciesVisuals.GetPalette("Oak")
	local model, trunk, leaves = makeTreeFrame(
		"StarterForestTree",
		Vector3.new(6, 10, 6),
		Vector3.new(0, 5, 0),
		oakPalette
	)
	addBarkBrick(model, trunk, "BarkBrick1", Vector3.new(5, 5, 5), Vector3.new(0, 11, 0), oakPalette.BarkHighlight, oakPalette)
	addBarkBrick(model, trunk, "BarkBrick2", Vector3.new(4, 5, 4), Vector3.new(0, 15, 0), oakPalette.Bark, oakPalette)
	addLeafBricks(leaves, trunk, {
		{ Size = Vector3.new(18, 8, 16), Position = Vector3.new(0, 20, 0), Color = oakPalette.Leaf },
		{ Size = Vector3.new(12, 7, 12), Position = Vector3.new(-7, 23, -2), Color = oakPalette.LeafHighlight },
		{ Size = Vector3.new(12, 7, 12), Position = Vector3.new(7, 23, 2), Color = oakPalette.LeafShadow },
		{ Size = Vector3.new(15, 7, 14), Position = Vector3.new(0, 27, 0), Color = oakPalette.Leaf },
		{ Size = Vector3.new(10, 7, 10), Position = Vector3.new(0, 33, 0), Color = oakPalette.LeafHighlight },
	}, false)
	addChopHitbox(model, trunk, Vector3.new(10, 22, 10), Vector3.new(0, 11, 0))
	return model
end

local function makeStarterForestHarvestOak(sectionCount)
	local sectionNamesByCount = {
		[1] = { "Base" },
		[2] = { "Base", "Top" },
		[3] = { "Base", "Middle", "Top" },
	}
	local sectionNames = sectionNamesByCount[sectionCount]
	if not sectionNames then return nil end

	local oakPalette = SpeciesVisuals.GetPalette("Oak")
	local model = Instance.new("Model")
	model.Name = "StarterForestTree"

	-- This hidden carrier keeps the authored groups, leaves, and hitbox moving as
	-- one rigid tree until impact. Each harvest section has its own explicit weld.
	local carrier = makeBrickPart(
		"OakRootCarrier",
		Vector3.new(1, 18, 1),
		Vector3.new(0, 9, 0),
		oakPalette.Bark,
		model
	)
	carrier.PivotOffset = CFrame.new(0, -9, 0)
	carrier.Transparency = 1
	carrier.CanCollide = false
	carrier.CanTouch = false
	carrier.CanQuery = false
	carrier:SetAttribute("AlwaysInvisible", true)
	model.PrimaryPart = carrier

	local sectionsFolder = Instance.new("Folder")
	sectionsFolder.Name = "OakHarvestSections"
	sectionsFolder.Parent = model

	local sections = table.create(sectionCount)
	local sectionHeight = 18 / sectionCount
	local coreWidth = 2.4
	for index, sectionName in ipairs(sectionNames) do
		local section = Instance.new("Model")
		section.Name = sectionName
		section:SetAttribute("OakHarvestSection", true)
		section:SetAttribute("OakHarvestIndex", index)
		section:SetAttribute("AuthoredHarvestSection", true)
		section:SetAttribute("HarvestSectionIndex", index)
		section:SetAttribute("SpeciesId", "Oak")
		section.Parent = sectionsFolder

		local core = makeBrickPart(
			"OakHarvestCore",
			Vector3.new(coreWidth, sectionHeight, coreWidth),
			Vector3.new(0, (index - 0.5) * sectionHeight, 0),
			oakPalette.Bark,
			section,
			carrier,
			index == 1
		)
		core.CanTouch = true
		section.PrimaryPart = core
		addBarkStuds(core, core, oakPalette)
		sections[index] = section
	end

	local leaves = Instance.new("Folder")
	leaves.Name = "Leaves"
	leaves.Parent = model
	addLeafBricks(leaves, carrier, {
		{ Size = Vector3.new(18, 8, 16), Position = Vector3.new(0, 20, 0), Color = oakPalette.Leaf },
		{ Size = Vector3.new(12, 7, 12), Position = Vector3.new(-7, 23, -2), Color = oakPalette.LeafHighlight },
		{ Size = Vector3.new(12, 7, 12), Position = Vector3.new(7, 23, 2), Color = oakPalette.LeafShadow },
		{ Size = Vector3.new(15, 7, 14), Position = Vector3.new(0, 27, 0), Color = oakPalette.Leaf },
		{ Size = Vector3.new(10, 7, 10), Position = Vector3.new(0, 33, 0), Color = oakPalette.LeafHighlight },
	}, false)
	addChopHitbox(model, carrier, Vector3.new(10, 22, 10), Vector3.new(0, 11, 0))
	return model, sections
end

local function makeForest2Tree(sectionCount)
	local sectionGroupsByCount = {
		[1] = { { 1, 3 } },
		[2] = { { 1, 1 }, { 2, 3 } },
		[3] = { { 1, 1 }, { 2, 2 }, { 3, 3 } },
	}
	local sectionGroups = sectionGroupsByCount[sectionCount] or sectionGroupsByCount[2]
	local ironwoodPalette = SpeciesVisuals.GetPalette("Ironwood")
	local model = Instance.new("Model")
	model.Name = "Forest2Tree"
	-- Match the former trunk primary's size and pivot so existing fall placement
	-- and reward fallback calculations retain their original reference height.
	local carrier = makeBrickPart("IronwoodRootCarrier", Vector3.new(1, 16, 1), Vector3.new(0, 8, 0), ironwoodPalette.Bark, model)
	carrier.PivotOffset = CFrame.new(0, -8, 0)
	carrier.Transparency = 1
	carrier.CanCollide = false
	carrier.CanTouch = false
	carrier.CanQuery = false
	carrier:SetAttribute("AlwaysInvisible", true)
	model.PrimaryPart = carrier

	local sectionsFolder = Instance.new("Folder")
	sectionsFolder.Name = "IronwoodHarvestSections"
	sectionsFolder.Parent = model
	local trunkPieces = {
		{ Name = "Bark", Size = Vector3.new(3.5, 16, 3.5), Position = Vector3.new(0, 8, 0), Color = ironwoodPalette.Bark },
		{ Name = "BarkBrick1", Size = Vector3.new(3, 9, 3), Position = Vector3.new(0, 18, 0), Color = ironwoodPalette.BarkHighlight },
		{ Name = "BarkBrick2", Size = Vector3.new(2.5, 8, 2.5), Position = Vector3.new(0, 25, 0), Color = ironwoodPalette.Bark },
	}
	local sections = table.create(#sectionGroups)
	for index, pieceRange in ipairs(sectionGroups) do
		local section = Instance.new("Model")
		section.Name = "IronwoodHarvestSection" .. index
		section:SetAttribute("AuthoredHarvestSection", true)
		section:SetAttribute("HarvestSectionIndex", index)
		section:SetAttribute("SpeciesId", "Ironwood")
		section.Parent = sectionsFolder
		for pieceIndex = pieceRange[1], pieceRange[2] do
			local definition = trunkPieces[pieceIndex]
			local piece = makeBrickPart(definition.Name, definition.Size, definition.Position, definition.Color, section, carrier, false)
			piece.CanTouch = false
			addBarkStuds(piece, piece, ironwoodPalette)
			if not section.PrimaryPart then section.PrimaryPart = piece end
		end
		sections[index] = section
	end

	local leaves = Instance.new("Folder")
	leaves.Name = "Leaves"
	leaves.Parent = model
	addBarkBrick(model, carrier, "BoughLeft", Vector3.new(11, 4, 5), Vector3.new(-5, 23, 0), ironwoodPalette.BarkHighlight, ironwoodPalette)
	addBarkBrick(model, carrier, "BoughRight", Vector3.new(11, 4, 5), Vector3.new(5, 28, 0), ironwoodPalette.BarkHighlight, ironwoodPalette)
	addLeafBricks(leaves, carrier, {
		{ Size = Vector3.new(20, 7, 18), Position = Vector3.new(0, 31, 0), Color = ironwoodPalette.LeafShadow },
		{ Size = Vector3.new(15, 7, 15), Position = Vector3.new(0, 37, 0), Color = ironwoodPalette.Leaf },
		{ Size = Vector3.new(11, 7, 11), Position = Vector3.new(0, 43, 0), Color = ironwoodPalette.LeafHighlight },
		{ Size = Vector3.new(7, 7, 7), Position = Vector3.new(0, 49, 0), Color = ironwoodPalette.LeafHighlight },
		{ Size = Vector3.new(10, 6, 10), Position = Vector3.new(-7, 34, 0), Color = ironwoodPalette.Leaf },
		{ Size = Vector3.new(10, 6, 10), Position = Vector3.new(7, 39, 0), Color = ironwoodPalette.LeafShadow },
	}, false)
	addChopHitbox(model, carrier, Vector3.new(11, 32, 11), Vector3.new(0, 16, 0))
	return model, sections
end

local function makeBambooClump()
	local palette = SpeciesVisuals.GetPalette("Bamboo")
	local model = Instance.new("Model")
	model.Name = "BambooClump"
	local root = makeBrickPart(
		"BambooRootCarrier",
		Vector3.new(1.1, 8.4, 1.1),
		Vector3.new(0, 4.2, 0),
		palette.Bark,
		model
	)
	root.PivotOffset = CFrame.new(0, -4.2, 0)
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root:SetAttribute("AlwaysInvisible", true)
	model.PrimaryPart = root
	local sectionsFolder = Instance.new("Folder")
	sectionsFolder.Name = "BambooHarvestSections"
	sectionsFolder.Parent = model
	local leaves = Instance.new("Folder")
	leaves.Name = "Leaves"
	leaves.Parent = model

	local stalks = {
		{ Height = 8.4, Diameter = 1.1, Position = Vector3.new(0, 4.2, 0), IsRoot = true },
		{ Height = 7.6, Diameter = 0.86, Position = Vector3.new(-1.45, 3.8, -1.1) },
		{ Height = 7.0, Diameter = 0.84, Position = Vector3.new(1.35, 3.5, -1.05) },
		{ Height = 8.0, Diameter = 0.9, Position = Vector3.new(-1.35, 4.0, 1.15) },
		{ Height = 7.3, Diameter = 0.86, Position = Vector3.new(1.4, 3.65, 1.05) },
	}

	local sections = table.create(#stalks)
	for index, stalk in ipairs(stalks) do
		local section = Instance.new("Model")
		section.Name = "BambooHarvestSection" .. index
		section:SetAttribute("AuthoredHarvestSection", true)
		section:SetAttribute("HarvestSectionIndex", index)
		section:SetAttribute("SpeciesId", "Bamboo")
		section.Parent = sectionsFolder
		local stalkPart = makeBrickPart(
			if stalk.IsRoot then "BambooCore" else "BambooStalk" .. index,
			Vector3.new(stalk.Diameter, stalk.Height, stalk.Diameter),
			stalk.Position,
			palette.Bark,
			section,
			root,
			false
		)
		stalkPart.CanTouch = false
		section.PrimaryPart = stalkPart

		for nodeIndex = 1, 3 do
			local nodeY = stalk.Position.Y - stalk.Height * 0.5 + stalk.Height * nodeIndex * 0.25
			makeBrickPart(
				"BambooNode" .. index .. "_" .. nodeIndex,
				Vector3.new(stalk.Diameter * 1.14, 0.16, stalk.Diameter * 1.14),
				Vector3.new(stalk.Position.X, nodeY, stalk.Position.Z),
				palette.BarkShadow,
				section,
				stalkPart,
				false
			)
		end

		local leafY = stalk.Position.Y + stalk.Height * 0.5 + 0.3
		for leafIndex, leafDefinition in ipairs({
			{ Size = Vector3.new(2.8, 0.2, 0.42), Position = Vector3.new(stalk.Position.X - 0.7, leafY, stalk.Position.Z), Color = palette.Leaf },
			{ Size = Vector3.new(2.5, 0.2, 0.4), Position = Vector3.new(stalk.Position.X + 0.8, leafY + 0.25, stalk.Position.Z + 0.1), Color = palette.LeafHighlight },
			{ Size = Vector3.new(2.2, 0.2, 0.4), Position = Vector3.new(stalk.Position.X, leafY + 0.45, stalk.Position.Z - 0.5), Color = palette.LeafShadow },
		}) do
			local leaf = makeBrickPart(
				"BambooLeaf" .. index .. "_" .. leafIndex,
				leafDefinition.Size,
				leafDefinition.Position,
				leafDefinition.Color,
				leaves,
				root,
				false
			)
			leaf.CanCollide = false
		end
		sections[index] = section
	end

	addChopHitbox(model, root, Vector3.new(7, 11, 7), Vector3.new(0, 5.1, 0))
	return model, sections
end

local function makeBarrierTree()
	local barkColor = Color3.fromRGB(105, 61, 39)
	local barrierPalette = {
		Bark = barkColor,
		BarkHighlight = Color3.fromRGB(138, 82, 48),
		BarkShadow = Color3.fromRGB(82, 45, 32),
	}
	local model, trunk, leaves = makeTreeFrame(
		"BarrierTree",
		Vector3.new(38, 28, 18),
		Vector3.new(0, 14, 0),
		barrierPalette
	)
	-- A broad, continuous wooden core and overlapping side posts make this a
	-- physical gate as well as a server-registered chop target.
	addBarkBrick(model, trunk, "BarrierBeam", Vector3.new(62, 12, 20), Vector3.new(0, 32, 0), Color3.fromRGB(123, 72, 43), barrierPalette, true)
	addBarkBrick(model, trunk, "BarrierPostLeft", Vector3.new(16, 30, 20), Vector3.new(-24, 15, 0), Color3.fromRGB(116, 66, 41), barrierPalette, true)
	addBarkBrick(model, trunk, "BarrierPostRight", Vector3.new(16, 30, 20), Vector3.new(24, 15, 0), Color3.fromRGB(116, 66, 41), barrierPalette, true)
	addLeafBricks(leaves, trunk, {
		{ Size = Vector3.new(42, 10, 22), Position = Vector3.new(0, 43, 0), Color = Color3.fromRGB(47, 105, 58) },
		{ Size = Vector3.new(29, 10, 20), Position = Vector3.new(0, 51, 0), Color = Color3.fromRGB(59, 126, 62) },
		{ Size = Vector3.new(20, 9, 18), Position = Vector3.new(0, 59, 0), Color = Color3.fromRGB(75, 143, 66) },
		{ Size = Vector3.new(20, 10, 22), Position = Vector3.new(-21, 45, 0), Color = Color3.fromRGB(40, 93, 53) },
		{ Size = Vector3.new(20, 10, 22), Position = Vector3.new(21, 45, 0), Color = Color3.fromRGB(40, 93, 53) },
		{ Size = Vector3.new(14, 9, 18), Position = Vector3.new(-31, 53, 0), Color = Color3.fromRGB(58, 119, 60) },
		{ Size = Vector3.new(14, 9, 18), Position = Vector3.new(31, 53, 0), Color = Color3.fromRGB(58, 119, 60) },
	}, true)
	addChopHitbox(model, trunk, Vector3.new(76, 68, 30), Vector3.new(0, 34, 0))
	return model
end

local SOURCE_BUILT_MODELS = {
	BrickPlaceholder = makeBrickPlaceholder,
	StarterForestTree = makeStarterForestTree,
	Forest2Tree = makeForest2Tree,
	BambooClump = makeBambooClump,
	BarrierTree = makeBarrierTree,
}

local GROVE_STAGE_SCALE = {
	sapling = 0.18,
	young = 0.52,
	mature = 1,
}

Tree.ActiveTrees = {}
Tree._nextCreationId = 0

local function applyVisualModifiers(tree, model, currentScale)
	TreeVisualModifiers.Apply(model, {
		SpeciesId = tree.SpeciesId,
		Mutations = tree.Mutations,
		GroveStage = if tree.IsPersistentGrove then tree.GroveStage else nil,
		SizePotential = if tree.IsPersistentGrove then tree.GroveSizePotential else nil,
		CurrentScale = currentScale,
	})
end

-- Builds an unregistered, non-interactive copy of one of the authored tree
-- visuals for Studio-only tools. The returned Model is intentionally unparented
-- and is never added to Tree.ActiveTrees.
--
-- kind: "GroveOak", "WildOak", "Bamboo", or "Ironwood"
-- context: { GroveStage = "sapling" | "young" | "mature", SizePotential = number, Mutations = { [id] = true } }
function Tree.BuildPreviewModel(kind, context)
	if not RunService:IsStudio() then return nil end
	if type(kind) ~= "string" then return nil end
	context = if type(context) == "table" then context else {}

	local groveStage = context.GroveStage or "mature"
	local stageScale = GROVE_STAGE_SCALE[groveStage]
	if not stageScale then return nil end

	local sizePotential = context.SizePotential
	if sizePotential == nil then sizePotential = 1 end
	if type(sizePotential) ~= "number"
		or sizePotential ~= sizePotential
		or sizePotential < 0.1
		or sizePotential > 2
		or sizePotential == math.huge then
		return nil
	end

	local model
	local speciesId
	if kind == "GroveOak" then
		model = makeStarterForestTree()
		speciesId = "Oak"
	elseif kind == "WildOak" then
		-- Three authored sections provide a representative mature wild Oak while
		-- using the same harvest-core construction path as live forest trees.
		model = makeStarterForestHarvestOak(3)
		speciesId = "Oak"
	elseif kind == "Bamboo" then
		model = makeBambooClump()
		speciesId = "Bamboo"
	elseif kind == "Ironwood" then
		-- nil intentionally selects the builder's same default section grouping
		-- used by PersistentGroveTree spawning.
		model = makeForest2Tree(nil)
		speciesId = "Ironwood"
	else
		return nil
	end

	if not model then return nil end
	local currentScale = sizePotential * stageScale
	model:ScaleTo(currentScale)
	model.Name = "DevTreePreview_" .. kind
	model:SetAttribute("DevTreePreviewKind", kind)

	-- Previews only display the builder output: remove the invisible chop target
	-- and make every remaining part static and non-interactive before parenting.
	local chopHitbox = model:FindFirstChild("ChopHitbox", true)
	if chopHitbox then chopHitbox:Destroy() end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end

	TreeVisualModifiers.Apply(model, {
		SpeciesId = speciesId,
		Mutations = context.Mutations,
		GroveStage = groveStage,
		SizePotential = sizePotential,
		CurrentScale = currentScale,
	})
	return model
end

function Tree.new(options)
	assert(type(options) == "table", "Tree options required")
	local definition = Definitions[options.DefinitionId]
	assert(definition, "Unknown tree definition: " .. tostring(options.DefinitionId))
	assert(Definitions.Categories[definition.Category], "Unknown tree category")
	assert(type(definition.InteractionPartName) == "string", "Tree definition requires InteractionPartName")
	assert(type(definition.ChopRadius) == "number" and definition.ChopRadius >= 0, "Tree definition requires a non-negative ChopRadius")
	assert(options.Parent and options.CFrame, "Tree parent and CFrame required")

	local self = setmetatable({}, Tree)
	self.DefinitionId = options.DefinitionId
	self.Category = definition.Category
	self.ModelName = definition.ModelName
	self.BaseHP = definition.MaxHP
	self.MaxHP = definition.MaxHP
	self.HP = definition.MaxHP
	self.SpeciesId = definition.SpeciesId
	self.LogYield = definition.LogYield
	self.FixedSizeScale = definition.FixedSizeScale
	self.YieldsLog = definition.YieldsLog == true
	self.SizeScale = 1
	self.DamageContributions = {}
	self.RespawnSeconds = definition.RespawnSeconds
	self.OwnerOnly = definition.OwnerOnly
	self.OwnerUserId = options.OwnerUserId
	self.Choppable = definition.Choppable
	self.ForestId = options.ForestId or definition.ForestId or "Base"
	self.RequiredStandardAxeTier = definition.RequiredStandardAxeTier
	self.UnlockForestId = definition.UnlockForestId
	self.InteractionPartName = definition.InteractionPartName
	self.ChopRadius = definition.ChopRadius
	self.IsPersistentGrove = options.DefinitionId == "PersistentGroveTree"
	self.Mutations = {}
	self.CanChopCallback = options.CanChopCallback
	self.OnPersistentHarvest = options.OnPersistentHarvest
	if self.IsPersistentGrove then
		local speciesConfig = Definitions.PersistentGroveSpecies[options.SpeciesId]
		local sizePotential = options.SizePotential
		local plantedAt = options.PlantedAt
		local maturesAt = options.MaturesAt
		assert(type(options.GroveTreeUID) == "string" and #options.GroveTreeUID > 0, "Persistent Grove tree UID required")
		assert(type(options.SourceSaplingUID) == "string" and #options.SourceSaplingUID > 0, "Persistent Grove source UID required")
		assert(speciesConfig ~= nil and MaterialDefinitions.Get(options.SpeciesId) ~= nil, "Unknown Persistent Grove species")
		assert(type(speciesConfig.MaxHP) == "number" and speciesConfig.MaxHP > 1, "Invalid Persistent Grove prototype HP")
		assert(type(speciesConfig.ChopRadius) == "number" and speciesConfig.ChopRadius > 0, "Invalid Persistent Grove chop radius")
		assert(type(sizePotential) == "number" and sizePotential == sizePotential and sizePotential >= 0.1 and sizePotential <= 2, "Invalid Persistent Grove size potential")
		assert(type(plantedAt) == "number" and plantedAt == plantedAt and plantedAt >= 0 and plantedAt < math.huge, "Invalid Persistent Grove planting time")
		assert(type(maturesAt) == "number" and maturesAt > plantedAt and maturesAt < math.huge, "Invalid Persistent Grove maturity time")
		self.ModelName = speciesConfig.ModelName
		self.BaseHP = speciesConfig.MaxHP
		self.MaxHP = speciesConfig.MaxHP
		self.HP = speciesConfig.MaxHP
		self.ChopRadius = speciesConfig.ChopRadius
		self.SpeciesId = options.SpeciesId
		self.GroveTreeUID = options.GroveTreeUID
		self.SourceSaplingUID = options.SourceSaplingUID
		self.Mutations = MutationDefinitions.CopyKnown(options.Mutations)
		self.GroveSizePotential = sizePotential
		self.GrovePlantedAt = plantedAt
		self.GroveMaturesAt = maturesAt
		self.GroveStage = if GROVE_STAGE_SCALE[options.GroveStage] then options.GroveStage else "sapling"
		self.YieldsLog = false
		self.RespawnSeconds = nil
		self.OwnerOnly = true
		self.Choppable = true
	end
	self.Parent = options.Parent
	self.CFrame = options.CFrame
	self.isDead = false
	self.destroyed = false
	Tree._nextCreationId += 1
	self.CreationId = Tree._nextCreationId
	Tree.ActiveTrees[self] = true
	return self
end

function Tree:Spawn()
	if self.destroyed then return nil end
	-- A respawn reuses this TreeObject, so discovery idempotency must distinguish
	-- each life from stale callbacks associated with an earlier death.
	self.DeathGeneration = (self.DeathGeneration or 0) + 1
	local hasKnownMaterial = type(self.SpeciesId) == "string"
		and MaterialDefinitions.Get(self.SpeciesId) ~= nil
	local hasLogDrop = self.YieldsLog
		and self.Category ~= "Barrier"
		and hasKnownMaterial
	self.SizeScale = if self.IsPersistentGrove
		then self.GroveSizePotential
		elseif type(self.FixedSizeScale) == "number" and self.FixedSizeScale > 0
		then self.FixedSizeScale
		elseif hasLogDrop
		then rollTreeScale()
		else 1
	-- Combat state stays integral even though the presentation size is fractional.
	self.MaxHP = math.max(1, math.floor(self.BaseHP * (self.SizeScale ^ 1.4) + 0.5))
	self.HP = self.MaxHP
	self.DamageContributions = {}
	self.OakHarvestSections = nil
	self.HarvestSections = nil
	local oakHarvestCount
	if self.DefinitionId == "StarterForestTree" and hasLogDrop then
		oakHarvestCount = LogService.GetTreeLogYieldCount(self)
	end

	local builder = SOURCE_BUILT_MODELS[self.ModelName]
	local model
	local oakHarvestSections
	local authoredHarvestSections
	if self.DefinitionId == "StarterForestTree" and oakHarvestCount then
		model, oakHarvestSections = makeStarterForestHarvestOak(oakHarvestCount)
	elseif self.DefinitionId == "Forest2Tree" and hasLogDrop then
		local harvestCount = LogService.GetTreeLogYieldCount(self)
		if harvestCount then
			model, authoredHarvestSections = makeForest2Tree(harvestCount)
		end
	elseif self.DefinitionId == "BambooClump" and hasLogDrop then
		model, authoredHarvestSections = makeBambooClump()
	end
	if not model and builder then
		model = builder()
	end
	if not model then
		local templates = ServerStorage:FindFirstChild("TreeTypes")
		local template = templates and templates:FindFirstChild(self.ModelName)
		if not template or not template:IsA("Model") then
			warn("Missing tree model", self.ModelName)
			return nil
		end
		model = template:Clone()
	end
	model.Name = "Tree"
	local modelScale = self.SizeScale
	if self.IsPersistentGrove then
		modelScale *= GROVE_STAGE_SCALE[self.GroveStage]
	end
	model:ScaleTo(modelScale)
	model:PivotTo(self.CFrame)
	model.Parent = self.Parent
	-- Keep useful read-only identity metadata on every lifecycle incarnation,
	-- including respawns. Gameplay authority remains the server TreeObject.
	model:SetAttribute("DefinitionId", self.DefinitionId)
	model:SetAttribute("ForestId", self.ForestId)
	model:SetAttribute("TreeCategory", self.Category)
	model:SetAttribute("SizeScale", self.SizeScale)
	model:SetAttribute("MaxHP", self.MaxHP)
	if self.SpeciesId then model:SetAttribute("SpeciesId", self.SpeciesId) end
	if self.IsPersistentGrove then
		model:SetAttribute("PersistentGrove", true)
		model:SetAttribute("OwnerUserId", self.OwnerUserId)
		model:SetAttribute("GroveTreeUID", self.GroveTreeUID)
		model:SetAttribute("SourceSaplingUID", self.SourceSaplingUID)
		model:SetAttribute("GroveStage", self.GroveStage)
		model:SetAttribute("GroveSizeScale", modelScale)
		model:SetAttribute("GrovePlantedAt", self.GrovePlantedAt)
		model:SetAttribute("GroveMaturesAt", self.GroveMaturesAt)
	end
	applyVisualModifiers(self, model, modelScale)
	self.model = model
	if self.DefinitionId == "StarterForestTree" then
		self.OakHarvestSections = oakHarvestSections
	end
	self.HarvestSections = oakHarvestSections or authoredHarvestSections
	self.isDead = false
	local interactionPart = model:FindFirstChild(self.InteractionPartName, true)
	if not interactionPart or not interactionPart:IsA("BasePart") then
		warn("Tree is missing its required interaction part", self.DefinitionId, self.InteractionPartName)
		model:Destroy()
		self.model = nil
		return nil
	end
	self.InteractionPart = interactionPart
	self:BuildLeafPool()
	return model
end

function Tree:SetGroveStage(stage)
	local stageScale = GROVE_STAGE_SCALE[stage]
	if not self.IsPersistentGrove or not stageScale then return false end
	self.GroveStage = stage
	local model = self.model
	if model and model.Parent then
		local modelScale = self.GroveSizePotential * stageScale
		model:ScaleTo(modelScale)
		model:SetAttribute("GroveStage", stage)
		model:SetAttribute("GroveSizeScale", modelScale)
		applyVisualModifiers(self, model, modelScale)
	end
	return true
end

function Tree:BuildLeafPool()
	self.pool = {}
	local leavesFolder = self.model and self.model:FindFirstChild("Leaves")
	if leavesFolder then
		for _, leaf in ipairs(leavesFolder:GetDescendants()) do
			if leaf:IsA("BasePart") then
				table.insert(self.pool, leaf)
			end
		end
	end
	self.totalLeaves = #self.pool
	self.leavesRemaining = self.totalLeaves
end

function Tree:CanChop(player)
	if self.destroyed or self.isDead or not self.model or not self.model.Parent then return false end
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return false end
	if self.IsPersistentGrove then
		if self.OwnerUserId ~= player.UserId or type(self.CanChopCallback) ~= "function" then return false end
		local ok, canChop = pcall(self.CanChopCallback, player, self)
		return ok and canChop == true
	end
	if not self.Choppable then return false end
	if self.OwnerOnly and self.OwnerUserId ~= player.UserId then return false end
	return true
end

function Tree:GetInteractionDistance(worldPosition)
	local part = self.InteractionPart
	if typeof(worldPosition) ~= "Vector3"
		or not part
		or not part:IsA("BasePart")
		or not self.model
		or not part:IsDescendantOf(self.model) then
		return math.huge
	end

	local localPosition = part.CFrame:PointToObjectSpace(worldPosition)
	local halfSize = part.Size * 0.5
	local closestLocalPoint = Vector3.new(
		math.clamp(localPosition.X, -halfSize.X, halfSize.X),
		math.clamp(localPosition.Y, -halfSize.Y, halfSize.Y),
		math.clamp(localPosition.Z, -halfSize.Z, halfSize.Z)
	)
	local closestWorldPoint = part.CFrame:PointToWorldSpace(closestLocalPoint)
	return (worldPosition - closestWorldPoint).Magnitude
end

function Tree.GetBestChopTarget(player, eligibilityFilter)
	assert(type(eligibilityFilter) == "function", "Tree eligibility filter required")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then return nil end

	local bestTree = nil
	local bestDistance = math.huge
	for tree in pairs(Tree.ActiveTrees) do
		if eligibilityFilter(tree) then
			local distance = tree:GetInteractionDistance(root.Position)
			if distance <= tree.ChopRadius then
				if distance < bestDistance - 0.001
					or (math.abs(distance - bestDistance) <= 0.001 and bestTree and tree.CreationId < bestTree.CreationId)
					or not bestTree then
					bestTree = tree
					bestDistance = distance
				end
			end
		end
	end
	return bestTree
end

local function leavesForHP(hp, maxHP, totalLeaves)
	if totalLeaves == 0 then return 0 end
	return math.ceil(math.clamp(hp / maxHP, 0, 1) * totalLeaves)
end

local OAK_HARVEST_WAVE_INTERVAL = HarvestVisualConfig.SectionStagger
local OAK_HARVEST_ARC_HEIGHT = HarvestVisualConfig.SectionArcHeight
local OAK_HARVEST_ANIMATION_DURATION = HarvestVisualConfig.SectionDuration
local HARVEST_AXIAL_ROTATION_TURNS = HarvestVisualConfig.RotationTurns
local HARVEST_AXIAL_ROTATION_DIRECTION = 1
local HARVEST_AXIAL_ROTATION_SPEED_RADIANS_PER_SECOND = HarvestVisualConfig.RotationSpeedRadiansPerSecond
local HARVEST_GROUND_RAY_START_HEIGHT = 128
local HARVEST_GROUND_RAY_LENGTH = 4096
local HARVEST_GROUND_MAX_HEIGHT_VARIATION = 1.25
local HARVEST_GROUND_CLEARANCE = 0.06

local function getHarvestSectionProjectionBounds(model, sourcePivot, targetRotation, axis)
	local minimumProjection = math.huge
	local maximumProjection = -math.huge
	local lowestY = math.huge
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local relativeCFrame = sourcePivot:ToObjectSpace(descendant.CFrame)
			local targetRelativeCFrame = targetRotation * relativeCFrame
			local part = descendant
			local projectedHalfExtent = math.abs(targetRelativeCFrame.RightVector:Dot(axis)) * part.Size.X * 0.5
				+ math.abs(targetRelativeCFrame.UpVector:Dot(axis)) * part.Size.Y * 0.5
				+ math.abs(targetRelativeCFrame.LookVector:Dot(axis)) * part.Size.Z * 0.5
			local projection = targetRelativeCFrame.Position:Dot(axis)
			minimumProjection = math.min(minimumProjection, projection - projectedHalfExtent)
			maximumProjection = math.max(maximumProjection, projection + projectedHalfExtent)
			local verticalHalfExtent = math.abs(targetRelativeCFrame.RightVector.Y) * part.Size.X * 0.5
				+ math.abs(targetRelativeCFrame.UpVector.Y) * part.Size.Y * 0.5
				+ math.abs(targetRelativeCFrame.LookVector.Y) * part.Size.Z * 0.5
			lowestY = math.min(lowestY, targetRelativeCFrame.Position.Y - verticalHalfExtent)
		end
	end
	if minimumProjection == math.huge or lowestY == math.huge then return nil end
	return minimumProjection, maximumProjection, lowestY
end

local function getPlannedSectionCenter(section, sourcePivot, targetRotation, axis)
	local minimumProjection, maximumProjection = getHarvestSectionProjectionBounds(
		section,
		sourcePivot,
		targetRotation,
		axis
	)
	if not minimumProjection then return nil end
	return sourcePivot.Position:Dot(axis) + (minimumProjection + maximumProjection) * 0.5,
		(maximumProjection - minimumProjection) * 0.5
end

local function planSeparatedSectionCenters(sections, sourcePivots, targetRotation, axis, gapMode)
	local measurements = table.create(#sections)
	for index, section in ipairs(sections) do
		local center, halfExtent = getPlannedSectionCenter(section, sourcePivots[index], targetRotation, axis)
		if not center then return nil end
		table.insert(measurements, {
			Index = index,
			Center = center,
			HalfExtent = halfExtent,
		})
	end
	table.sort(measurements, function(a, b)
		if math.abs(a.Center - b.Center) <= 1e-4 then
			return a.Index < b.Index
		end
		return a.Center < b.Center
	end)

	local centersByIndex = {}
	local plannedCenters = table.create(#measurements)
	for order, measurement in ipairs(measurements) do
		local plannedCenter = measurement.Center
		if order > 1 then
			local previous = measurements[order - 1]
			local minimumGap = 0
			if gapMode == "Longitudinal" then
				local smallerLength = math.min(previous.HalfExtent, measurement.HalfExtent) * 2
				minimumGap = math.clamp(smallerLength * 0.12, 0.6, 1)
			elseif gapMode == "BambooLateral" then
				minimumGap = 0.15
			end
			plannedCenter = math.max(
				plannedCenter,
				plannedCenters[order - 1] + previous.HalfExtent + measurement.HalfExtent + minimumGap
			)
		end
		plannedCenters[order] = plannedCenter
		centersByIndex[measurement.Index] = plannedCenter
	end

	if #measurements > 1 then
		local originalMidpoint = (measurements[1].Center + measurements[#measurements].Center) * 0.5
		local plannedMidpoint = (plannedCenters[1] + plannedCenters[#plannedCenters]) * 0.5
		local recenterOffset = originalMidpoint - plannedMidpoint
		for index, center in pairs(centersByIndex) do
			centersByIndex[index] = center + recenterOffset
		end
	end
	return centersByIndex
end

local function createHarvestLandingRaycastParams()
	local includeInstances = { workspace.Terrain }
	local included = { [workspace.Terrain] = true }
	local baseGround = workspace:FindFirstChild("BaseGround")
	if baseGround and baseGround:IsA("BasePart") then
		table.insert(includeInstances, baseGround)
		included[baseGround] = true
	end

	-- The source world marks only its actual support surfaces. This keeps trees,
	-- foliage, props, players, and station geometry out of the candidate set.
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart")
			and descendant:GetAttribute("HarvestLandingSurface") == true
			and not included[descendant] then
			table.insert(includeInstances, descendant)
			included[descendant] = true
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = includeInstances
	params.IgnoreWater = true
	return params
end

local function isSuitableHarvestLandingHit(hit)
	if not hit or hit.Normal.Y < 0.65 then return false end
	if hit.Instance == workspace.Terrain then
		return hit.Material ~= Enum.Material.Water
	end
	local part = hit.Instance
	return part:IsA("BasePart")
		and part.Anchored
		and part.CanCollide
		and (part.Name == "BaseGround" or part:GetAttribute("HarvestLandingSurface") == true)
end

local function getHarvestGroundHeight(position, raycastParams)
	local rayOrigin = Vector3.new(position.X, position.Y + HARVEST_GROUND_RAY_START_HEIGHT, position.Z)
	local hit = workspace:Raycast(rayOrigin, Vector3.new(0, -HARVEST_GROUND_RAY_LENGTH, 0), raycastParams)
	if not isSuitableHarvestLandingHit(hit) then return nil end
	return hit.Position.Y
end

local function getAuthoredHarvestGroundCFrame(
	section,
	sourcePivot,
	horizontalDirection,
	perpendicularDirection,
	targetAlongCenter,
	targetAcrossCenter,
	raycastParams
)
	local flatRotation = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, horizontalDirection, Vector3.yAxis:Cross(horizontalDirection))
	local alongCenter, alongHalfExtent = getPlannedSectionCenter(section, sourcePivot, flatRotation, horizontalDirection)
	local acrossCenter, acrossHalfExtent = getPlannedSectionCenter(section, sourcePivot, flatRotation, perpendicularDirection)
	local _, _, bottomOffset = getHarvestSectionProjectionBounds(section, sourcePivot, flatRotation, Vector3.yAxis)
	if not alongCenter or not acrossCenter or not alongHalfExtent or not acrossHalfExtent or not bottomOffset then return nil end
	local horizontalPosition = sourcePivot.Position
		+ horizontalDirection * (targetAlongCenter - alongCenter)
		+ perpendicularDirection * (targetAcrossCenter - acrossCenter)

	-- Check the center, both ends, both sides, and the footprint corners. All
	-- samples must land on designated ground and remain close in height so a
	-- log cannot bridge a ledge or settle on an unrelated elevated object.
	local inset = math.min(0.12, alongHalfExtent * 0.2, acrossHalfExtent * 0.2)
	local alongReach = math.max(0, alongHalfExtent - inset)
	local acrossReach = math.max(0, acrossHalfExtent - inset)
	local sampleOffsets = {
		Vector3.zero,
		horizontalDirection * alongReach,
		-horizontalDirection * alongReach,
		perpendicularDirection * acrossReach,
		-perpendicularDirection * acrossReach,
		horizontalDirection * alongReach + perpendicularDirection * acrossReach,
		horizontalDirection * alongReach - perpendicularDirection * acrossReach,
		-horizontalDirection * alongReach + perpendicularDirection * acrossReach,
		-horizontalDirection * alongReach - perpendicularDirection * acrossReach,
	}
	local lowestGroundY = math.huge
	local highestGroundY = -math.huge
	for _, offset in ipairs(sampleOffsets) do
		local samplePosition = horizontalPosition + offset
		local groundY = getHarvestGroundHeight(samplePosition, raycastParams)
		if groundY == nil then return nil end
		lowestGroundY = math.min(lowestGroundY, groundY)
		highestGroundY = math.max(highestGroundY, groundY)
	end
	local allowedHeightVariation = math.clamp(alongHalfExtent * 0.2, 0.65, HARVEST_GROUND_MAX_HEIGHT_VARIATION)
	if highestGroundY - lowestGroundY > allowedHeightVariation then return nil end

	local targetPosition = Vector3.new(
		horizontalPosition.X,
		highestGroundY - bottomOffset + HARVEST_GROUND_CLEARANCE,
		horizontalPosition.Z
	)
	local targetCFrame = CFrame.new(targetPosition) * flatRotation
	local inFlightPosition = sourcePivot.Position:Lerp(targetPosition, 0.55)
		+ Vector3.new(0, OAK_HARVEST_ARC_HEIGHT, 0)
	local inFlightCFrame = CFrame.new(inFlightPosition) * flatRotation
	return targetCFrame, inFlightCFrame
end

local function createPreparedAuthoredHarvestLogs(fallenModel, sections, count, fallRotation, speciesId)
	if not fallenModel or not fallenModel.Parent
		or type(sections) ~= "table" or #sections ~= count then
		return nil
	end

	local horizontalDirection = fallRotation:VectorToWorldSpace(Vector3.yAxis)
	horizontalDirection = Vector3.new(horizontalDirection.X, 0, horizontalDirection.Z)
	if horizontalDirection.Magnitude <= 1e-4 then return nil end
	horizontalDirection = horizontalDirection.Unit

	local sourcePivots = table.create(count)
	for index = 1, count do
		local section = sections[index]
		if not section or not section:IsA("Model")
			or section:GetAttribute("AuthoredHarvestSection") ~= true
			or section:GetAttribute("HarvestSectionIndex") ~= index
			or section:GetAttribute("SpeciesId") ~= speciesId
			or not section:IsDescendantOf(fallenModel)
			or not section:FindFirstChildWhichIsA("BasePart", true) then
			return nil
		end
		sourcePivots[index] = section:GetPivot()
	end

	local raycastParams = createHarvestLandingRaycastParams()

	local flatRotation = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, horizontalDirection, Vector3.yAxis:Cross(horizontalDirection))
	local perpendicularDirection = Vector3.new(-horizontalDirection.Z, 0, horizontalDirection.X)
	local alongCenters
	local acrossCenters
	if speciesId == "Bamboo" then
		alongCenters = table.create(count)
		for index, section in ipairs(sections) do
			local center = getPlannedSectionCenter(section, sourcePivots[index], flatRotation, horizontalDirection)
			if not center then return nil end
			alongCenters[index] = center
		end
		acrossCenters = planSeparatedSectionCenters(
			sections,
			sourcePivots,
			flatRotation,
			perpendicularDirection,
			"BambooLateral"
		)
	else
		alongCenters = planSeparatedSectionCenters(
			sections,
			sourcePivots,
			flatRotation,
			horizontalDirection,
			"Longitudinal"
		)
		acrossCenters = table.create(count)
		for index, section in ipairs(sections) do
			acrossCenters[index] = getPlannedSectionCenter(section, sourcePivots[index], flatRotation, perpendicularDirection)
		end
	end
	if not alongCenters or not acrossCenters then return nil end

	local targetCFrames = table.create(count)
	local inFlightCFrames = table.create(count)
	for index, section in ipairs(sections) do
		targetCFrames[index], inFlightCFrames[index] = getAuthoredHarvestGroundCFrame(
			section,
			sourcePivots[index],
			horizontalDirection,
			perpendicularDirection,
			alongCenters[index],
			acrossCenters[index],
			raycastParams
		)
		if not targetCFrames[index] or not inFlightCFrames[index] then
			-- Reject authored visuals before detaching them. The caller can then
			-- register standard logs and destroy the still-parented source sections.
			return nil, nil, nil, nil, "no-safe-landing"
		end
	end

	local partSectionByPart = {}
	for _, section in ipairs(sections) do
		for _, descendant in ipairs(section:GetDescendants()) do
			if descendant:IsA("BasePart") then
				partSectionByPart[descendant] = section
			end
		end
	end
	local externalJoints = {}
	for _, descendant in ipairs(fallenModel:GetDescendants()) do
		if descendant:IsA("WeldConstraint") or descendant:IsA("JointInstance") then
			local section0 = partSectionByPart[descendant.Part0]
			local section1 = partSectionByPart[descendant.Part1]
			if section0 ~= section1 and (section0 or section1) then
				table.insert(externalJoints, descendant)
			end
		end
	end

	for _, section in ipairs(sections) do
		for _, descendant in ipairs(section:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
			end
		end
	end
	for _, joint in ipairs(externalJoints) do
		joint:Destroy()
	end

	local sectionParent = fallenModel.Parent
	for index, section in ipairs(sections) do
		section.Parent = sectionParent
		section.Name = "Prepared" .. speciesId .. "HarvestLog" .. index
	end
	return sections, sourcePivots, inFlightCFrames, targetCFrames
end

local function animateAuthoredHarvestSection(visual, sourceCFrame, inFlightCFrame, targetCFrame)
	local movementProgress = Instance.new("NumberValue")
	local rotationProgress = Instance.new("NumberValue")
	local turns = math.max(0, HARVEST_AXIAL_ROTATION_TURNS)
	local direction = if HARVEST_AXIAL_ROTATION_DIRECTION < 0 then -1 else 1
	local targetAngle = direction * turns * 2 * math.pi
	local rotationSpeed = math.max(math.abs(HARVEST_AXIAL_ROTATION_SPEED_RADIANS_PER_SECOND), math.rad(1))
	local animationDuration = if turns > 0
		then math.abs(targetAngle) / rotationSpeed
		else OAK_HARVEST_ANIMATION_DURATION
	local tweens = {}
	local connections = {}
	local rotationCompleted = false

	local function updatePose()
		if not visual.Parent then return end
		local progress = movementProgress.Value
		local position
		if progress <= 0.4 then
			position = sourceCFrame.Position:Lerp(inFlightCFrame.Position, progress / 0.4)
		else
			position = inFlightCFrame.Position:Lerp(targetCFrame.Position, (progress - 0.4) / 0.6)
		end

		local baseRotation = sourceCFrame.Rotation:Lerp(targetCFrame.Rotation, progress)
		local axialRotation = CFrame.fromAxisAngle(Vector3.yAxis, targetAngle * rotationProgress.Value)
		visual:PivotTo(CFrame.new(position) * baseRotation * axialRotation)
	end

	table.insert(connections, movementProgress:GetPropertyChangedSignal("Value"):Connect(updatePose))
	table.insert(connections, rotationProgress:GetPropertyChangedSignal("Value"):Connect(updatePose))
	local function tweenProgress(value, target, duration, easingStyle, easingDirection)
		local tween = TweenService:Create(
			value,
			TweenInfo.new(duration, easingStyle, easingDirection),
			{ Value = target }
		)
		table.insert(tweens, tween)
		local completed = false
		local completionConnection = tween.Completed:Connect(function(playbackState)
			completed = playbackState == Enum.PlaybackState.Completed
		end)
		table.insert(connections, completionConnection)
		tween:Play()

		-- A destroyed/replaced tween target or a scheduler edge case must not hold
		-- the whole harvest batch forever. Preserve the normal tween when it
		-- completes, but cap each phase and settle its progress value on timeout.
		local deadline = os.clock() + duration + 0.35
		while not completed and os.clock() < deadline do
			task.wait()
		end
		if not completed then
			tween:Cancel()
		end
		value.Value = target
	end

	local ok, err = pcall(function()
		local rotationTween = TweenService:Create(
			rotationProgress,
			TweenInfo.new(animationDuration, Enum.EasingStyle.Linear),
			{ Value = 1 }
		)
		table.insert(tweens, rotationTween)
		table.insert(connections, rotationTween.Completed:Connect(function(playbackState)
			rotationCompleted = playbackState == Enum.PlaybackState.Completed
		end))
		rotationTween:Play()
		local rotationDeadline = os.clock() + animationDuration + 0.35

		local firstPhaseDuration = animationDuration * 0.4
		tweenProgress(movementProgress, 0.4, firstPhaseDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		tweenProgress(
			movementProgress,
			1,
			animationDuration - firstPhaseDuration,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		while not rotationCompleted and os.clock() < rotationDeadline do
			task.wait()
		end
		if not rotationCompleted then
			rotationTween:Cancel()
		end
		rotationProgress.Value = 1
	end)
	if not ok then
		warn("Could not animate authored harvest section", err)
	end
	if visual.Parent then visual:PivotTo(targetCFrame) end
	for _, tween in ipairs(tweens) do
		tween:Cancel()
		tween:Destroy()
	end
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	movementProgress:Destroy()
	rotationProgress:Destroy()
end

local function animateAuthoredHarvestSections(preparedVisuals, sourcePivots, inFlightCFrames, targetCFrames, harvestBatchId, speciesId)
	LogService.DebugHarvestPickupLifecycle(
		"AUTHORED_ANIMATION_START",
		speciesId,
		string.format("batch=%s sections=%d waveInterval=%.2f animationDuration=%.2f", tostring(harvestBatchId), #preparedVisuals, OAK_HARVEST_WAVE_INTERVAL, OAK_HARVEST_ANIMATION_DURATION)
	)
	task.spawn(function()
		local completedCount = 0
		for index, visual in ipairs(preparedVisuals) do
			task.spawn(function()
				local animationOk, animationError = pcall(function()
					task.wait((index - 1) * OAK_HARVEST_WAVE_INTERVAL)
					if visual.Parent then
						animateAuthoredHarvestSection(
							visual,
							sourcePivots[index],
							inFlightCFrames[index],
							targetCFrames[index]
						)
					end
				end)
				if not animationOk then
					warn("Could not finish authored harvest section movement", animationError)
					if visual.Parent then pcall(function() visual:PivotTo(targetCFrames[index]) end) end
				end
				completedCount += 1
				LogService.DebugHarvestPickupLifecycle(
					"AUTHORED_SECTION_COMPLETE",
					speciesId,
					string.format("batch=%s section=%d/%d completed=%d animationOk=%s", tostring(harvestBatchId), index, #preparedVisuals, completedCount, tostring(animationOk))
				)
			end)
		end
		while completedCount < #preparedVisuals do
			task.wait(0.03)
		end
		LogService.DebugHarvestPickupLifecycle(
			"AUTHORED_RELEASE_BARRIER",
			speciesId,
			string.format("batch=%s completed=%d/%d", tostring(harvestBatchId), completedCount, #preparedVisuals)
		)
		LogService.EnableGroundLogBatch(harvestBatchId)
	end)
end

local function destroyPreparedAuthoredHarvestLogs(preparedVisuals)
	for _, visual in ipairs(preparedVisuals or {}) do
		if visual and visual.Parent then visual:Destroy() end
	end
end

function Tree:TakeDamage(ctx, player)
	if not self:CanChop(player) or not WorldProgressService.CanInteractWithTree(player, self) then return false end
	local damage = ctx.Damage
	if type(damage) ~= "number" or damage ~= damage or damage <= 0 or damage == math.huge then return false end

	local appliedDamage = math.min(math.floor(damage), self.HP)
	if appliedDamage <= 0 then return false end
	self.HP = math.max(0, self.HP - appliedDamage)
	local isLethalHit = self.HP == 0
	local contribution = self.DamageContributions[player.UserId]
	if not contribution then
		contribution = { Player = player, Damage = 0 }
		self.DamageContributions[player.UserId] = contribution
	end
	contribution.Damage += appliedDamage
	ChopFX:FireAllClients("playHit", { model = self.model })
	if self.IsPersistentGrove and self.HP == 0 then
		self:Die(player)
	end
	DamageEvent:FireAllClients({
		Target = self.model,
		Damage = appliedDamage,
		IsCrit = ctx.IsCrit,
		HP = self.HP,
		MaxHP = self.MaxHP,
	})

	if not isLethalHit and not (self.IsPersistentGrove and self.isDead) then
		local targetLeaves = leavesForHP(self.HP, self.MaxHP, self.totalLeaves)
		local leavesToDrop = self.leavesRemaining - targetLeaves
		if leavesToDrop > 0 then
			self.leavesRemaining = targetLeaves
			local model = self.model
			local pool = self.pool
			task.spawn(function()
				if model and model.Parent then FXService:DropLeaves(model, pool, leavesToDrop) end
			end)
		end
	end
	if self.HP == 0 and not self.IsPersistentGrove then
		self:Die(player)
	end
	return true
end

function Tree:Die(player)
	if self.isDead or self.destroyed then return end
	if self.IsPersistentGrove then
		if self.HarvestInProgress then return false end
		self.HarvestInProgress = true
		local fallenModel = self.model
		local fallRotation = FXService.GetTreeFallRotation(fallenModel, player)
		local harvested = false
		if type(self.OnPersistentHarvest) == "function" then
			local ok, result = pcall(self.OnPersistentHarvest, player, self)
			harvested = ok and result == true
		end
		if not harvested then
			self.HP = 1
			self.HarvestInProgress = false
			return false
		end
		self.isDead = true
		self.Choppable = false
		self.DamageContributions = {}
		Tree.ActiveTrees[self] = nil
		task.spawn(function()
			FXService:TreeFall(fallenModel, player, fallRotation, nil)
			self.destroyed = true
			self.model = nil
			self.InteractionPart = nil
		end)
		return true
	end
	self.isDead = true
	-- The discovery service is server-only, uses the shared log-winner rule, and
	-- marks this exact TreeObject death before rolling. It does not depend on
	-- physical log creation, pickup, carry capacity, or tree-fall callbacks.
	SaplingDiscoveryService.AwardForTreeDeath(self, self.DamageContributions, self.DeathGeneration)
	local fallenModel = self.model
	local fallRotation = FXService.GetTreeFallRotation(fallenModel, player)
	local awardSnapshot = LogService.CaptureTreeLogAward(
		self,
		self.DamageContributions,
		fallRotation
	)
	if not awardSnapshot then
		LogService.DebugHarvestPickupLifecycle("NO_REWARD_CREATED", self.SpeciesId, "reason=award-snapshot-unavailable")
	end
	if self.UnlockForestId then
		WorldProgressService.UnlockForest(player, self.UnlockForestId)
	end
	local usesAuthoredHarvestSections = self.YieldsLog
		and not self.IsPersistentGrove
		and type(self.HarvestSections) == "table"
	local legacyAwardAttempted = false
	local function revealLegacyLogAward()
		if legacyAwardAttempted then return nil end
		legacyAwardAttempted = true
		if awardSnapshot then
			local harvestBatchId = LogService.AwardTreeLog(awardSnapshot, { Reveal = true })
			if harvestBatchId then
				LogService.DebugHarvestPickupLifecycle(
					"STANDARD_FALLBACK_REGISTERED",
					self.SpeciesId,
					"batch=" .. tostring(harvestBatchId)
				)
				LogService.EnableGroundLogBatchAfterStandardReveal(harvestBatchId)
			else
				LogService.DebugHarvestPickupLifecycle(
					"NO_REWARD_CREATED",
					self.SpeciesId,
					"reason=standard-fallback-registration-failed"
				)
			end
			return harvestBatchId
		end
		return nil
	end
	task.spawn(function()
		if usesAuthoredHarvestSections then
			local impactCompleted = FXService:TreeFallToImpact(fallenModel, player, fallRotation, {
				ConcurrentLeafShrink = true,
				OnImpact = function(impactModel)
					local preparedVisuals, sourcePivots, inFlightCFrames, targetCFrames, preparationFailure
					local harvestBatchId
					local movementScheduled = false
					local cleanupScheduled = false
					local function scheduleImpactCleanup()
						if cleanupScheduled then return end
						local delayedCleanupOk = pcall(task.delay, 0.3, function()
							if impactModel.Parent then impactModel:Destroy() end
						end)
						cleanupScheduled = true
						if not delayedCleanupOk and impactModel.Parent then
							impactModel:Destroy()
						end
					end

					local callbackOk, callbackError = pcall(function()
						local rewardCount = LogService.GetTreeLogYieldCount(self)
						if awardSnapshot and rewardCount then
							preparedVisuals, sourcePivots, inFlightCFrames, targetCFrames, preparationFailure = createPreparedAuthoredHarvestLogs(
								impactModel,
								self.HarvestSections,
								rewardCount,
								fallRotation,
								self.SpeciesId
							)
						end
						if preparedVisuals then
							harvestBatchId = LogService.AwardTreeLog(awardSnapshot, {
								Reveal = true,
								PreparedVisuals = preparedVisuals,
							})
							if harvestBatchId then
								animateAuthoredHarvestSections(
									preparedVisuals,
									sourcePivots,
									inFlightCFrames,
									targetCFrames,
									harvestBatchId,
									self.SpeciesId
								)
								movementScheduled = true
								scheduleImpactCleanup()
								return
							end
							destroyPreparedAuthoredHarvestLogs(preparedVisuals)
							preparedVisuals = nil
						end
						if preparationFailure == "no-safe-landing" then
							-- The authored footprint was rejected before its Models were detached.
							-- Register standard server-owned logs instead so cleanup cannot leave
							-- visible, unregistered sections or silently discard this reward.
							local fallbackBatchId = revealLegacyLogAward()
							if fallbackBatchId then
								warn("Authored harvest landing rejected; registered standard log fallback", self.DefinitionId, self.SpeciesId)
							else
								warn("Authored harvest landing rejected and standard log fallback could not be registered", self.DefinitionId, self.SpeciesId)
							end
						elseif awardSnapshot and not harvestBatchId then
							revealLegacyLogAward()
						end
						scheduleImpactCleanup()
					end)
					if not callbackOk then
						warn("Authored harvest impact callback failed", callbackError)
						-- Schedule residual tree cleanup before attempting any recovery work.
						pcall(scheduleImpactCleanup)
						if harvestBatchId then
							-- The batch owns these section Models now. If movement setup failed,
							-- settle them and release pickup without awarding a second batch.
							if not movementScheduled then
								for index, visual in ipairs(preparedVisuals or {}) do
									local targetCFrame = targetCFrames and targetCFrames[index]
									if visual and visual.Parent and targetCFrame then
										pcall(function() visual:PivotTo(targetCFrame) end)
									end
								end
								pcall(LogService.EnableGroundLogBatch, harvestBatchId)
							end
						else
							if preparedVisuals then
								pcall(destroyPreparedAuthoredHarvestLogs, preparedVisuals)
							elseif type(self.HarvestSections) == "table" then
								-- Preparation can fail partway through detaching. Remove only
								-- sections already moved out of the impact tree.
								for _, section in ipairs(self.HarvestSections) do
									if section and section.Parent and not section:IsDescendantOf(impactModel) then
										pcall(function() section:Destroy() end)
									end
								end
							end
							if awardSnapshot then pcall(revealLegacyLogAward) end
						end
					end
				end,
			})
			if not impactCompleted and fallenModel and fallenModel.Parent then
				FXService:TreeFall(fallenModel, player, fallRotation, revealLegacyLogAward)
			end
		else
			FXService:TreeFall(fallenModel, player, fallRotation, revealLegacyLogAward)
		end
		self.model = nil
		self.InteractionPart = nil
	end)
	if self.RespawnSeconds then
		task.delay(self.RespawnSeconds, function()
			if not self.destroyed then self:Respawn() end
		end)
	end
end

function Tree:Respawn()
	if self.destroyed or self.IsPersistentGrove then return end
	self.HP = self.MaxHP
	local model = self:Spawn()
	if model then FXService:FadeIn(model) end
end

function Tree:Destroy()
	self.destroyed = true
	Tree.ActiveTrees[self] = nil
	if self.model then
		self.model:Destroy()
	end
	self.model = nil
	self.InteractionPart = nil
end

return Tree
