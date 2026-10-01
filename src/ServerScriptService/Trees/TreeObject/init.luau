local Tree = {}
local treeDatabase = require(script.TreeDatabase)

local ChopFX = game.ReplicatedStorage.Chop.ChopFX
local DamageEvent = game.ReplicatedStorage.DamageEvent

local playerProfileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local ServerStorage = game.ServerStorage
local Zone = require(game.ReplicatedStorage.Zone)
local ZoneController = require(game.ReplicatedStorage.Zone.ZoneController)

Tree.__index = Tree

Tree.ActiveTreeByPlayer = {}

function Tree.new(player, plotFolder, treeType, passivePlotNumber)
	local self = setmetatable({}, Tree)
	local stats = treeDatabase
	self.player = player
	self.plotFolder = plotFolder
	if not passivePlotNumber then
		self.Position = self.plotFolder.PlotModel:GetPivot().Position
		self.MaxHP = stats.MaxHP or 100
		self.HP = stats.MaxHP or 100
		self.Def = stats.Defense
		self.parent = self.plotFolder.PlotModel
		self.Zone = Zone.new(self.parent.Zone)
		self:_bindZone()
		self.RespawnTime = 3
	else
		self.parent = self.plotFolder.PlotModel[passivePlotNumber]
		self.Position = self.parent:GetPivot().Position
	end
	self.type = treeType
	return self
end

function Tree:Spawn()
	self.isDead = false
	self.model = ServerStorage.TreeTypes:FindFirstChild(self.type):Clone()
	local primary = self.model.PrimaryPart
	if not primary then return end
	self.model:PivotTo(CFrame.new(self.Position))
	self.model.Parent = self.parent
	self.model.Name = "Tree"
	if self.HP then
		self:BuildLeafPool()
	end
end

function Tree:_bindZone()
	self.Zone.playerEntered:Connect(function(player)
		--self.PlayersInZone[player] = true
		Tree.ActiveTreeByPlayer[player] = self
		player:SetAttribute("InZone", true)
	end)

	self.Zone.playerExited:Connect(function(player)
		--self.PlayersInZone[player] = nil
		player:SetAttribute("InZone", false)
		if Tree.ActiveTreeByPlayer[player] == self then
			Tree.ActiveTreeByPlayer[player] = nil
		end
	end)
end

function Tree:BuildLeafPool()
	local leavesFolder = self.plotFolder.PlotModel.Tree:FindFirstChild("Leaves")
	if not leavesFolder then return {} end

	self.pool = {}

	for _, leaf in ipairs(leavesFolder:GetChildren()) do
		if leaf:IsA("BasePart") then
			table.insert(self.pool, leaf)
		end
	end
	self.totalLeaves = #self.pool
	self.leavesRemaining = self.totalLeaves
	return
end

function Tree:ChangeModel(model)
	self.model = model
end

local function ComputeLeavesFromHP(hp, maxHp, totalLeaves)
	local ratio = math.clamp(hp / maxHp, 0, 1)
	return math.ceil(ratio * totalLeaves)
end

local FXService = require(game.ReplicatedStorage.FXService)

function Tree:TakeDamage(ctx, player)
	if self.isDead then
		print("Dead, Exit!")
		return
	end

	local dmg = ctx.Damage

	ChopFX:FireAllClients("playHit", {model = self.model})
	self.HP = math.max(0, self.HP - dmg)

	DamageEvent:FireAllClients({
		Target = ctx.Target.model,
		Damage = dmg,
		IsCrit = ctx.IsCrit,
		HP = self.HP,
		MaxHP = self.MaxHP
	})

	if self.HP == 0 then
		print("HP = 0")
		self.isDead = true
	end

	local targetLeaves = ComputeLeavesFromHP(self.HP, self.MaxHP, self.totalLeaves)
	local leavesToDrop = self.leavesRemaining - targetLeaves

	if leavesToDrop > 0 then
		FXService:DropLeaves(self.model, self.pool, leavesToDrop)
		self.leavesRemaining = targetLeaves
	end

	if self.isDead then
		self:Die(player)
		return
	end
end

function Tree:Die(player)
	--ChopFX:FireAllClients("TreeDies", {model = self.model, playerID = player.UserId})
	--print(player, "Server player")
	FXService:TreeFall(self.model, player)

	task.delay(self.RespawnTime or 10, function()
		print("Respawned")
		self:Respawn()
	end)
end

function Tree:Respawn()
	self.HP = self.MaxHP

	self:Spawn()
	for _, part in ipairs(self.model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = 1
		end
	end

	FXService:FadeIn(self.model)
	--ChopFX:FireAllClients("TreeRespawn", {model = self.model})
end

return Tree
