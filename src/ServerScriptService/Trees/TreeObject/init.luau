local Tree = {}
Tree.__index = Tree

local ServerStorage = game:GetService("ServerStorage")
local ChopFX = game.ReplicatedStorage.Chop.ChopFX
local DamageEvent = game.ReplicatedStorage.DamageEvent
local FXService = require(game.ReplicatedStorage.FXService)
local Definitions = require(script.Parent.TreeDefinitions)

local function makeBrickPart(name, size, position, color, parent, root)
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
	part.CanCollide = root == nil
	part.Parent = parent
	if root then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end
	return part
end

local function addBarkStuds(brick, root, color)
	local halfX, halfZ = brick.Size.X * 0.25, brick.Size.Z * 0.25
	for _, offset in ipairs({
		Vector3.new(-halfX, 0, -halfZ), Vector3.new(halfX, 0, -halfZ),
		Vector3.new(-halfX, 0, halfZ), Vector3.new(halfX, 0, halfZ),
	}) do
		local stud = Instance.new("Part")
		stud.Name = "BarkStud"
		stud.Shape = Enum.PartType.Cylinder
		stud.Size = Vector3.new(0.35, 0.9, 0.9)
		stud.CFrame = brick.CFrame * CFrame.new(offset.X, brick.Size.Y * 0.5 + 0.16, offset.Z) * CFrame.Angles(0, 0, math.rad(90))
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

	-- Top studs alone disappear when bricks are stacked. These small side studs
	-- keep the trunk visibly brick-built from the player's eye level.
	for _, verticalOffset in ipairs({ -brick.Size.Y * 0.2, brick.Size.Y * 0.2 }) do
		for _, horizontalOffset in ipairs({ -halfX, halfX }) do
			local frontStud = Instance.new("Part")
			frontStud.Name = "BarkStud"
			frontStud.Shape = Enum.PartType.Cylinder
			frontStud.Size = Vector3.new(0.45, 0.8, 0.8)
			frontStud.CFrame = brick.CFrame
				* CFrame.new(horizontalOffset, verticalOffset, brick.Size.Z * 0.5 + 0.2)
				* CFrame.Angles(0, math.rad(90), 0)
			frontStud.Color = color
			frontStud.Material = Enum.Material.Plastic
			frontStud.Anchored = false
			frontStud.CanCollide = false
			frontStud.Parent = brick.Parent
			local frontWeld = Instance.new("WeldConstraint")
			frontWeld.Part0 = root
			frontWeld.Part1 = frontStud
			frontWeld.Parent = frontStud

			local sideStud = frontStud:Clone()
			sideStud.CFrame = brick.CFrame * CFrame.new(brick.Size.X * 0.5 + 0.2, verticalOffset, horizontalOffset)
			sideStud.Parent = brick.Parent
			local sideWeld = sideStud:FindFirstChildOfClass("WeldConstraint")
			if sideWeld then
				sideWeld.Part0 = root
				sideWeld.Part1 = sideStud
			end
		end
	end
end

local function makeBrickPlaceholder()
	local model = Instance.new("Model")
	model.Name = "BrickPlaceholder"

	local barkColor = Color3.fromRGB(144, 85, 48)
	local bark = makeBrickPart("Bark", Vector3.new(8, 4, 8), Vector3.new(0, 2, 0), barkColor, model)
	bark.PivotOffset = CFrame.new(0, -2, 0)
	model.PrimaryPart = bark
	addBarkStuds(bark, bark, barkColor)

	for index, definition in ipairs({
		{ Vector3.new(7, 4, 7), Vector3.new(1, 6, -1), Color3.fromRGB(159, 95, 54) },
		{ Vector3.new(8, 4, 8), Vector3.new(-1, 10, 1), barkColor },
		{ Vector3.new(7, 4, 7), Vector3.new(0, 14, 0), Color3.fromRGB(159, 95, 54) },
	}) do
		local brick = makeBrickPart("BarkBrick" .. index, definition[1], definition[2], definition[3], model, bark)
		addBarkStuds(brick, bark, definition[3])
	end

	local leaves = Instance.new("Folder")
	leaves.Name = "Leaves"
	leaves.Parent = model
	for index, definition in ipairs({
		{ Vector3.new(18, 8, 18), Vector3.new(0, 18, 0), Color3.fromRGB(77, 181, 87) },
		{ Vector3.new(14, 8, 14), Vector3.new(-6, 22, -2), Color3.fromRGB(87, 201, 93) },
		{ Vector3.new(14, 8, 14), Vector3.new(6, 22, 2), Color3.fromRGB(66, 162, 78) },
		{ Vector3.new(16, 7, 16), Vector3.new(0, 27, 0), Color3.fromRGB(89, 205, 99) },
	}) do
		local leaf = makeBrickPart("Leaf" .. index, definition[1], definition[2], definition[3], leaves, bark)
		leaf.CanCollide = false
	end

	return model
end

Tree.ActiveTrees = {}
Tree.ByModel = {}

function Tree.new(options)
	assert(type(options) == "table", "Tree options required")
	local definition = Definitions[options.DefinitionId]
	assert(definition, "Unknown tree definition: " .. tostring(options.DefinitionId))
	assert(Definitions.Categories[definition.Category], "Unknown tree category")
	assert(options.Parent and options.CFrame, "Tree parent and CFrame required")

	local self = setmetatable({}, Tree)
	self.DefinitionId = options.DefinitionId
	self.Category = definition.Category
	self.ModelName = definition.ModelName
	self.MaxHP = definition.MaxHP
	self.HP = definition.MaxHP
	self.RespawnSeconds = definition.RespawnSeconds
	self.OwnerOnly = definition.OwnerOnly
	self.OwnerUserId = options.OwnerUserId
	self.Choppable = definition.Choppable
	self.ForestId = options.ForestId or definition.ForestId or "Base"
	self.Parent = options.Parent
	self.CFrame = options.CFrame
	self.isDead = false
	self.destroyed = false
	Tree.ActiveTrees[self] = true
	return self
end

function Tree:Spawn()
	if self.destroyed then return nil end
	if self.model then Tree.ByModel[self.model] = nil end
	local model
	if self.ModelName == "BrickPlaceholder" then
		model = makeBrickPlaceholder()
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
	model:PivotTo(self.CFrame)
	model.Parent = self.Parent
	self.model = model
	self.isDead = false
	Tree.ByModel[model] = self
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

function Tree.GetTreeFromTarget(target)
	if typeof(target) ~= "Instance" then return nil end
	local cursor = target
	while cursor do
		local tree = Tree.ByModel[cursor]
		if tree then
			if tree.model == cursor and not tree.destroyed and cursor.Parent then
				return tree
			end
			return nil
		end
		cursor = cursor.Parent
	end
	return nil
end

function Tree:IsPlayerWithinChopDistance(player, maxDistance)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not self.model then return false end
	return (self.model:GetPivot().Position - root.Position).Magnitude <= maxDistance
end

local function leavesForHP(hp, maxHP, totalLeaves)
	if totalLeaves == 0 then return 0 end
	return math.ceil(math.clamp(hp / maxHP, 0, 1) * totalLeaves)
end

function Tree:TakeDamage(ctx, player)
	if not self:CanChop(player) then return false end
	local damage = ctx.Damage
	if type(damage) ~= "number" or damage ~= damage or damage <= 0 then return false end

	self.HP = math.max(0, self.HP - damage)
	ChopFX:FireAllClients("playHit", { model = self.model })
	DamageEvent:FireAllClients({
		Target = self.model,
		Damage = damage,
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
	Tree.ByModel[fallenModel] = nil
	task.spawn(function()
		FXService:TreeFall(fallenModel, player)
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
		Tree.ByModel[self.model] = nil
		self.model:Destroy()
	end
	self.model = nil
end

return Tree
