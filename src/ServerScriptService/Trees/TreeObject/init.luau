local Tree = {}
Tree.__index = Tree

local ServerStorage = game:GetService("ServerStorage")
local ChopFX = game.ReplicatedStorage.Chop.ChopFX
local DamageEvent = game.ReplicatedStorage.DamageEvent
local FXService = require(game.ReplicatedStorage.FXService)
local Definitions = require(script.Parent.TreeDefinitions)

local function makeBrickPlaceholder()
	local model = Instance.new("Model")
	model.Name = "BrickPlaceholder"

	local bark = Instance.new("Part")
	bark.Name = "Bark"
	bark.Size = Vector3.new(4, 12, 4)
	bark.CFrame = CFrame.new(0, 6, 0)
	bark.PivotOffset = CFrame.new(0, -6, 0)
	bark.Color = Color3.fromRGB(151, 90, 51)
	bark.Material = Enum.Material.Plastic
	bark.TopSurface = Enum.SurfaceType.Studs
	bark.Anchored = true
	bark.Parent = model
	model.PrimaryPart = bark

	local leaves = Instance.new("Folder")
	leaves.Name = "Leaves"
	leaves.Parent = model
	for index, offset in ipairs({
		Vector3.new(0, 12, 0),
		Vector3.new(-3, 15, 0),
		Vector3.new(3, 15, 0),
		Vector3.new(0, 18, 0),
	}) do
		local leaf = Instance.new("Part")
		leaf.Name = "Leaf" .. index
		leaf.Size = Vector3.new(8, 5, 8)
		leaf.CFrame = CFrame.new(offset)
		leaf.Color = Color3.fromRGB(65, 194, 83)
		leaf.Material = Enum.Material.Plastic
		leaf.TopSurface = Enum.SurfaceType.Studs
		leaf.Anchored = true
		leaf.CanCollide = false
		leaf.Parent = leaves
	end

	return model
end

Tree.ActiveTrees = {}

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
	self.Parent = options.Parent
	self.CFrame = options.CFrame
	self.isDead = false
	self.destroyed = false
	Tree.ActiveTrees[self] = true
	return self
end

function Tree:Spawn()
	if self.destroyed then return nil end
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
	if self.destroyed or self.isDead or not self.Choppable or not self.model then return false end
	if self.OwnerOnly and self.OwnerUserId ~= player.UserId then return false end
	return true
end

function Tree.GetClosestChoppableTree(player, maxDistance)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then return nil end
	local closest = nil
	local closestDistance = maxDistance
	for tree in pairs(Tree.ActiveTrees) do
		if tree:CanChop(player) then
			local distance = (tree.CFrame.Position - root.Position).Magnitude
			if distance <= closestDistance then
				closest = tree
				closestDistance = distance
			end
		end
	end
	return closest
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
	if self.model then self.model:Destroy() end
	self.model = nil
end

return Tree
