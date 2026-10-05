local Tree = {}
Tree.__index = Tree

local ServerStorage = game:GetService("ServerStorage")
local SpeciesVisuals = require(ServerStorage:WaitForChild("SpeciesVisuals"))
local ChopFX = game.ReplicatedStorage.Chop.ChopFX
local DamageEvent = game.ReplicatedStorage.DamageEvent
local FXService = require(game.ReplicatedStorage.FXService)
local Definitions = require(script.Parent.TreeDefinitions)
local WorldProgressService = require(game.ServerScriptService.WorldProgressService)
local LogService = require(game.ServerScriptService.Inventory.LogService)

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

local function makeForest2Tree()
	local ironwoodPalette = SpeciesVisuals.GetPalette("Ironwood")
	local model, trunk, leaves = makeTreeFrame(
		"Forest2Tree",
		Vector3.new(7, 16, 7),
		Vector3.new(0, 8, 0),
		ironwoodPalette
	)
	addBarkBrick(model, trunk, "BarkBrick1", Vector3.new(6, 9, 6), Vector3.new(0, 18, 0), ironwoodPalette.BarkHighlight, ironwoodPalette)
	addBarkBrick(model, trunk, "BarkBrick2", Vector3.new(5, 8, 5), Vector3.new(0, 25, 0), ironwoodPalette.Bark, ironwoodPalette)
	addBarkBrick(model, trunk, "BoughLeft", Vector3.new(11, 4, 5), Vector3.new(-5, 23, 0), ironwoodPalette.BarkHighlight, ironwoodPalette)
	addBarkBrick(model, trunk, "BoughRight", Vector3.new(11, 4, 5), Vector3.new(5, 28, 0), ironwoodPalette.BarkHighlight, ironwoodPalette)
	addLeafBricks(leaves, trunk, {
		{ Size = Vector3.new(20, 7, 18), Position = Vector3.new(0, 31, 0), Color = ironwoodPalette.LeafShadow },
		{ Size = Vector3.new(15, 7, 15), Position = Vector3.new(0, 37, 0), Color = ironwoodPalette.Leaf },
		{ Size = Vector3.new(11, 7, 11), Position = Vector3.new(0, 43, 0), Color = ironwoodPalette.LeafHighlight },
		{ Size = Vector3.new(7, 7, 7), Position = Vector3.new(0, 49, 0), Color = ironwoodPalette.LeafHighlight },
		{ Size = Vector3.new(10, 6, 10), Position = Vector3.new(-7, 34, 0), Color = ironwoodPalette.Leaf },
		{ Size = Vector3.new(10, 6, 10), Position = Vector3.new(7, 39, 0), Color = ironwoodPalette.LeafShadow },
	}, false)
	addChopHitbox(model, trunk, Vector3.new(11, 32, 11), Vector3.new(0, 16, 0))
	return model
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
	BarrierTree = makeBarrierTree,
}

Tree.ActiveTrees = {}
Tree._nextCreationId = 0

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
	self.LogValue = definition.LogValue
	self.YieldsLog = definition.YieldsLog == true
	self.SizeScale = 1
	self.DamageContributions = {}
	self.RespawnSeconds = definition.RespawnSeconds
	self.OwnerOnly = definition.OwnerOnly
	self.OwnerUserId = options.OwnerUserId
	self.Choppable = definition.Choppable
	self.ForestId = options.ForestId or definition.ForestId or "Base"
	self.UnlockForestId = definition.UnlockForestId
	self.InteractionPartName = definition.InteractionPartName
	self.ChopRadius = definition.ChopRadius
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
	local hasLogDrop = self.YieldsLog
		and self.Category ~= "Barrier"
		and type(self.SpeciesId) == "string"
		and type(self.LogValue) == "number"
	self.SizeScale = if hasLogDrop then rollTreeScale() else 1
	-- Combat state stays integral even though the presentation size is fractional.
	self.MaxHP = math.max(1, math.floor(self.BaseHP * (self.SizeScale ^ 1.4) + 0.5))
	self.HP = self.MaxHP
	self.DamageContributions = {}

	local builder = SOURCE_BUILT_MODELS[self.ModelName]
	local model
	if builder then
		model = builder()
	else
		local templates = ServerStorage:FindFirstChild("TreeTypes")
		local template = templates and templates:FindFirstChild(self.ModelName)
		if not template or not template:IsA("Model") then
			warn("Missing tree model", self.ModelName)
			return nil
		end
		model = template:Clone()
	end
	model.Name = "Tree"
	model:ScaleTo(self.SizeScale)
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
	self.model = model
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
	if self.destroyed or self.isDead or not self.Choppable or not self.model or not self.model.Parent then return false end
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

function Tree:TakeDamage(ctx, player)
	if not self:CanChop(player) or not WorldProgressService.CanInteractWithTree(player, self) then return false end
	local damage = ctx.Damage
	if type(damage) ~= "number" or damage ~= damage or damage <= 0 or damage == math.huge then return false end

	local appliedDamage = math.min(math.floor(damage), self.HP)
	if appliedDamage <= 0 then return false end
	self.HP = math.max(0, self.HP - appliedDamage)
	local contribution = self.DamageContributions[player.UserId]
	if not contribution then
		contribution = { Player = player, Damage = 0 }
		self.DamageContributions[player.UserId] = contribution
	end
	contribution.Damage += appliedDamage
	ChopFX:FireAllClients("playHit", { model = self.model })
	DamageEvent:FireAllClients({
		Target = self.model,
		Damage = appliedDamage,
		IsCrit = ctx.IsCrit,
		HP = self.HP,
		MaxHP = self.MaxHP,
	})

	local targetLeaves = leavesForHP(self.HP, self.MaxHP, self.totalLeaves)
	local leavesToDrop = self.leavesRemaining - targetLeaves
	if leavesToDrop > 0 then
		self.leavesRemaining = targetLeaves
		local model = self.model
		local pool = self.pool
		task.spawn(function()
			if model.Parent then FXService:DropLeaves(model, pool, leavesToDrop) end
		end)
	end
	if self.HP == 0 then
		self:Die(player)
	end
	return true
end

function Tree:Die(player)
	if self.isDead or self.destroyed then return end
	self.isDead = true
	local fallenModel = self.model
	local fallRotation = FXService.GetTreeFallRotation(fallenModel, player)
	local awardSnapshot = LogService.CaptureTreeLogAward(
		self,
		self.DamageContributions,
		fallRotation
	)
	if self.UnlockForestId then
		WorldProgressService.UnlockForest(player, self.UnlockForestId)
	end
	task.spawn(function()
		FXService:TreeFall(fallenModel, player, fallRotation)
		-- Spawn the physical reward only after the fallen tree is fully faded,
		-- keeping the drops hidden until they are no longer covered by the tree.
		if awardSnapshot then
			LogService.AwardTreeLog(awardSnapshot)
		end
	end)
	if self.RespawnSeconds then
		task.delay(self.RespawnSeconds, function()
			if not self.destroyed then self:Respawn() end
		end)
	end
end

function Tree:Respawn()
	if self.destroyed then return end
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
