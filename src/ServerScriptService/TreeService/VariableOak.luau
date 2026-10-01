local VariableOak = {}

-- General settings
VariableOak.Name = script.Name

-- Tree Settings
VariableOak.Height = 1
VariableOak.BranchDensity = 1
VariableOak.BranchThickness = 1

-- Appearance
VariableOak.Appearance = {
	Bark = {
		Material = Enum.Material.Plastic,
		Color = Color3.fromRGB(108, 88, 75),
	},

	Leaves = {
		Color = function(treeData)
			return Color3.fromRGB(
				91 + math.random(-10, 10),
				154 + math.random(-10, 10),
				76 + math.random(-10, 10)
			)
		end,
		Material = Enum.Material.Plastic,
	},
}

-- Generation
VariableOak.LeafGeneration = {
	Amount = function(treeData)
		if treeData.SegmentIndex >= treeData.TotalSegments then
			return 2
		end

		return 0
	end,

	Size = function(treeData)
		local diameter = math.random(14, 16) * VariableOak.Height * Vector3.new(1, 0.75, 1)

		return diameter * Vector3.new(
			math.random(9, 12) / 10,
			math.random(9, 12) / 10,
			math.random(9, 12) / 10
		)
	end,

	CFrame = function(treeData)
		return 
			CFrame.Angles(
				0,
				0,
				math.rad(math.random(10, 15))
			)
			* CFrame.Angles(
				0,
				math.rad(math.random(-25, 25)),
				0
			)
			* CFrame.Angles(
				0,
				0,
				math.rad(math.random(-5, 5))
			)
	end,
}

VariableOak.BranchGeneration = {
	Segments = function(treeData)
		return math.floor(VariableOak.Height * math.random(17, 21))
	end,

	Splits = function(treeData)
		local heightScale = VariableOak.Height
		local firstSplit = math.floor(5 * heightScale)
		local secondSplit = math.floor(9 * heightScale)
		local thirdSplit = math.floor(13 * heightScale)

		if treeData.SegmentIndex == firstSplit then
			return math.max(1, math.floor(math.random(3, 5) * VariableOak.BranchDensity))
		elseif treeData.SegmentIndex == secondSplit then
			return math.max(1, math.floor(2 * VariableOak.BranchDensity))
		elseif treeData.SegmentIndex == thirdSplit then
			return math.max(1, math.floor(math.random(2, 3) * VariableOak.BranchDensity))
		end

		return 1
	end,

	Size = function(treeData)
		if treeData.SegmentIndex == 1 then
			local width = (math.random(26, 28) / 10) * VariableOak.Height * VariableOak.BranchThickness
			local height = (math.random(45, 50) / 10) * VariableOak.Height
			local size = Vector3.new(width, height, width)
			treeData.TrunkSize = size

			return size
		else
			local taper = Vector3.new(0.1, 0.2, 0.1)
			return treeData.TrunkSize - (taper * (treeData.SegmentIndex - 1))
		end
	end,

	CFrame = function(treeData)
		if treeData.SegmentIndex == 1 then
			CFrame.Angles(0, math.random(-180, 180), 0)
		end

		-- Keep main trunk straight (no random angles)
		local finalCFrame = (treeData.LastBranch.CFrame - treeData.LastBranch.Position) 
			* CFrame.Angles(
				math.rad(0),
				math.rad(0),
				math.rad(0)
			)

		-- Apply random angles only after the first split
		local heightScale = VariableOak.Height
		local firstSplit = math.floor(5 * heightScale)

		if treeData.SegmentIndex > firstSplit then
			finalCFrame = (treeData.LastBranch.CFrame - treeData.LastBranch.Position) 
				* CFrame.Angles(
					math.rad(math.random(-5, 5)),
					math.rad(math.random(-5, 5)),
					math.rad(math.random(-5, 5))
				)
		end

		-- Angles of first split
		local heightScale = VariableOak.Height
		local firstSplit = math.floor(5 * heightScale)
		local secondSplit = math.floor(9 * heightScale)
		local thirdSplit = math.floor(13 * heightScale)

		if treeData.SegmentIndex == firstSplit then
			finalCFrame = finalCFrame
				* CFrame.Angles(
					0,
					math.rad((360 / treeData.TotalSplits) * treeData.SplitIndex),
					0
				) 
				* CFrame.Angles(
					math.rad(math.random(30, 35)),
					0,
					0
				)
		end

		-- Angles of second splits
		if treeData.SegmentIndex > (secondSplit - 1) and treeData.SegmentIndex < (secondSplit + 1) and treeData.TotalSplits > 1 then
			finalCFrame = finalCFrame * CFrame.Angles(
				0,
				math.rad((360 / treeData.TotalSplits) * treeData.SplitIndex),
				0
			) 
				* CFrame.Angles(
					math.rad(math.random(35, 40)),
					0,
					0
				)
		end

		-- Angles of third splits
		if treeData.SegmentIndex > (thirdSplit - 1) and treeData.SegmentIndex < (thirdSplit + 1) and treeData.TotalSplits > 1 then
			finalCFrame = finalCFrame * CFrame.Angles(
				0,
				math.rad((360 / treeData.TotalSplits) * treeData.SplitIndex),
				0
			) 
				* CFrame.Angles(
					math.rad(math.random(40, 45)),
					0,
					0
				)
		end

		return finalCFrame
	end,
}

return VariableOak
