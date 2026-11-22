-- LOCAL-INSTALL ONLY Studio practice-tree fixture for Phase 2 mutations.
-- This file is tracked in tests/, but intentionally is not mounted in src/.
-- Ask the coding agent to copy it to src/ServerScriptService/ locally,
-- excluding that copy from Git. No live-server execution is possible.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

local Players = game:GetService("Players")
local Tree = require(game.ServerScriptService.Trees.TreeObject)
local MAX_HP = 50000000
local START_DISTANCE = 18
local SIDE = 7
local spawned = {}
local started = false

local function addMarker(model, text, color)
	local adornee = model:FindFirstChild("ChopHitbox", true)
		or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not adornee then return end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "MutationPracticeSign"
	billboard.Size = UDim2.fromOffset(300, 75)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 11, 0)
	billboard.Adornee = adornee
	billboard.Parent = model
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(14, 26, 32)
	label.BackgroundTransparency = 0.18
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = text
	label.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
end

local function spawnPracticeTree(parent, position, label, color)
	local tree = Tree.new({
		DefinitionId = "BambooClump",
		ForestId = "Forest1",
		Parent = parent,
		CFrame = CFrame.new(position),
	})
	local model = tree:Spawn()
	if not model then
		tree:Destroy()
		error("Could not spawn practice tree " .. label)
	end
	-- This is a real registered TreeObject, not a fake hit box. The only
	-- altered value is HP so weapon strikes exercise the normal live path.
	tree.BaseHP = MAX_HP
	tree.MaxHP = MAX_HP
	tree.HP = MAX_HP
	model:SetAttribute("MaxHP", MAX_HP)
	model:SetAttribute("MutationCombatDummy", true)
	addMarker(model, label .. "\n50M HP — STUDIO TEST", color)
	table.insert(spawned, tree)
	return tree
end

local function cleanup()
	for _, tree in ipairs(spawned) do
		tree:Destroy()
	end
	table.clear(spawned)
end

local function start(player)
	if started then return end
	started = true
	local deadline = os.clock() + 30
	local root
	while os.clock() < deadline and player.Parent do
		local character = player.Character
		if character then
			root = character:FindFirstChild("HumanoidRootPart")
			if root then
				break
			end
		end
		task.wait(0.25)
	end
	if not root or not player.Parent then
		warn("[MutationPractice] Player root did not initialize within 30 seconds, fixture skipped")
		return
	end
	task.wait(1.5)
	if not player.Parent then return end

	local folder = Instance.new("Folder")
	folder.Name = "MutationCombatPracticeTrees"
	folder.Parent = workspace
	local origin = root.CFrame
	-- Two practice Bamboo trees ~14 studs apart. Both have 50M HP.
	-- The second tree helps prove Thunderstrike DOES NOT hit neighbors.
	local left = (origin * CFrame.new(-SIDE, -3, -START_DISTANCE)).Position
	local right = (origin * CFrame.new(SIDE, -3, -START_DISTANCE)).Position
	local ok, err = pcall(function()
		spawnPracticeTree(folder, left, "FERVOR / NEIGHBOR", Color3.fromRGB(255, 170, 90))
		spawnPracticeTree(folder, right, "THUNDERSTRIKE TARGET", Color3.fromRGB(80, 195, 255))
	end)
	if not ok then
		warn("[MutationPractice] Failed to prepare trees:", err)
		cleanup()
		folder:Destroy()
		return
	end

	print("[MutationPractice] READY: Two 50M HP registered training trees placed ahead of spawn.")
	print("[MutationPractice] Move near either trunk and equip Fervor or Thunderstrike.")
	print("[MutationPractice] Fervor prints stacks, allowed attack interval and measured hit gap.")
	print("[MutationPractice] Thunderstrike: chop the SAME TARGET, lightning strikes only that tree, never the neighbor.")
	print("[MutationPractice] Hit counter prints 1/N ... N/N PROC! and HIT extra damage, repeating.")
	print("[MutationPractice] Studio-only. No regular-tree rewards or persistent profile mutations are needed.")
	player.AncestryChanged:Connect(function(_, parentNow)
		if not parentNow then
			cleanup()
			if folder.Parent then folder:Destroy() end
		end
	end)
end

task.spawn(function()
	local limit = os.clock() + 60
	while os.clock() < limit and not started do
		local players = Players:GetPlayers()
		if #players == 1 then
			start(players[1])
			return
		end
		task.wait(0.5)
	end
end)
