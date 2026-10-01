-- https://devforum.roblox.com/t/open-source-procedural-tree-generation/2956400
local TreeService = {}

local function NewBranch(appearance)
	local branch = TreeService:NewPart(appearance.Bark)
	branch.Name = "Branch"
	TreeService:SetAppearance(branch, appearance.Bark)
	
	return branch
end

-- Generate branches
local function CreateBranches(treeData)
	local treeSettings = treeData.TreeSettings
	local appearance = treeSettings.Appearance
	local branchGeneration = treeSettings.BranchGeneration
	local leafGeneration = treeSettings.LeafGeneration

	treeData.TotalSplits = branchGeneration.Splits(treeData)

	local originalSegmentIndex = treeData.SegmentIndex
	local originalBranchFrom = treeData.LastBranch

	local totalSplits = branchGeneration.Splits(treeData)
	treeData.TotalSplits = totalSplits

	for i = 1, treeData.TotalSplits do	
		treeData.SplitIndex = i

		local branch = NewBranch(appearance)
		TreeService:HandleTag(originalBranchFrom, branch)

		local cutsFolder = Instance.new("Folder")
		cutsFolder.Name = "Cuts"
		cutsFolder.Parent = branch

		local branchSize = branchGeneration.Size(treeData)
		branch.Size = branchSize

		local branchCFrame =
			CFrame.new(
				(
					branch.Settings.BranchFrom.Value.CFrame *
					CFrame.new(0, branch.Settings.BranchFrom.Value.Size.Y / 2, 0)
				).Position
			) *
			branchGeneration.CFrame(treeData) *
			CFrame.new(0, branchSize.Y / 2, 0)

		branch.CFrame = branchCFrame

		branch.Parent = treeData.Model.Branches

		-- Immediately generate next segments (no delay/tweening for instant trees)
		if treeData.SegmentIndex < treeData.TotalSegments then
			treeData.SegmentIndex = originalSegmentIndex + 1
			treeData.LastBranch = branch

			CreateBranches(treeData)

			treeData.SegmentIndex = originalSegmentIndex
			treeData.LastBranch = originalBranchFrom
			treeData.TotalSplits = totalSplits
		end

		local leavesAmount = leafGeneration.Amount and leafGeneration.Amount(treeData) or 0 -- Some trees will have no leaves

		treeData.SegmentIndex = originalSegmentIndex + 1
		treeData.LastBranch = branch
		treeData.TotalSplits = leavesAmount

		for a = 1, leavesAmount do
			treeData.SplitIndex = a

			local leaf = TreeService:NewPart(appearance.Leaves)
			local leafSize = leafGeneration.Size(treeData)

			treeData.CurrentLeaf = leaf

			local leafCFrame = branch.CFrame * 
				CFrame.new(0, branch.Size.Y / 2, 0)
				* CFrame.new(0, leafSize.Y / 4, 0)
				* leafGeneration.CFrame(treeData)

			game:GetService("CollectionService"):AddTag(leaf, "WindShake")

			leaf.Name = "Leaf"
			leaf.PivotOffset = leafCFrame:ToObjectSpace(branch.CFrame * CFrame.new(0, branch.Size.Y / 2, 0))

			TreeService:SetAppearance(leaf, appearance.Leaves)

			leaf.Massless = true
			leaf.CanCollide = false
			leaf.Size = leafSize
			leaf.CFrame = leafCFrame
			leaf.Parent = treeData.Model.Leaves

			TreeService:HandleTag(branch, leaf)

			treeData.CurrentLeaf = nil
		end

		treeData.SplitIndex = i
		treeData.SegmentIndex = originalSegmentIndex
		treeData.LastBranch = originalBranchFrom
		treeData.TotalSplits = totalSplits
	end
end

-- Create the tree
function TreeService:GenerateTree(treeType, spawnCFrame, parameters)
	local treeSettings = require(script:FindFirstChild(treeType))

	-- Apply custom parameters if provided
	if parameters then
		if parameters.Height then
			treeSettings.Height = parameters.Height
		end
		if parameters.BranchDensity then
			treeSettings.BranchDensity = parameters.BranchDensity
		end
		if parameters.BranchThickness then
			treeSettings.BranchThickness = parameters.BranchThickness
		end
	end

	local treeData = {
		Model = nil,
		LastBranch = nil,

		TreeSettings = treeSettings,

		TotalSegments = treeSettings.BranchGeneration.Segments(),
		SegmentIndex = 0,

		TotalSplits = 0,
		SplitIndex = 0,
	}

	local model = Instance.new("Model")
	model.Name = treeSettings.Name
	treeData.Model = model

	local branchesFolder = Instance.new("Folder")
	branchesFolder.Name = "Branches"
	branchesFolder.Parent = model

	local leavesFolder = Instance.new("Folder")
	leavesFolder.Name = "Leaves"
	leavesFolder.Parent = model

	local originPart = TreeService:NewPart(
		{
			CanCollide = false,
			BrickColor = BrickColor.new("Hot pink"),
			Size = Vector3.new(),
			CFrame = spawnCFrame,
			Parent = model,
		}
	)

	model.PrimaryPart = originPart

	treeData.SegmentIndex = 1
	treeData.LastBranch = originPart

	model.Parent = workspace

	CreateBranches(treeData)

	return model
end

-- Utility functions
function TreeService:FindOrCreate(object, name, className)
	local existing = object:FindFirstChild(name)

	if existing then
		return existing
	end

	local new = Instance.new(className)
	new.Name = name
	new.Parent = object

	return new
end

function TreeService:HandleTag(from, part)
	local branchToFolder = TreeService:FindOrCreate(TreeService:FindOrCreate(from, "Settings", "Folder"), "BranchTo", "Folder")

	local selfTag = Instance.new("ObjectValue")
	selfTag.Name = part.Name
	selfTag.Value = part
	selfTag.Parent = branchToFolder

	-- Handle branch from
	TreeService:FindOrCreate(TreeService:FindOrCreate(part, "Settings", "Folder"), "BranchFrom", "ObjectValue").Value = from
end

function TreeService:SetAppearance(part, appearance)
	for i, v in pairs(appearance or {}) do
		part[i] = (type(v) == type(pairs)) and v() or v
	end
end

function TreeService:NewPart(appearance)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	TreeService:SetAppearance(part, appearance)

	return part
end

return TreeService
