local HugeOak = {}

-- General settings
HugeOak.Name = script.Name

-- Appearance
HugeOak.Appearance = {
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
HugeOak.LeafGeneration = {
	Amount = function(treeData)
		if treeData.SegmentIndex >= treeData.TotalSegments then
			return 2
		end

		return 0
	end,

	Size = function(treeData)
		local diameter = math.random(18, 22) * Vector3.new(1, 0.75, 1)

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

HugeOak.BranchGeneration = {
	Segments = function(treeData)
		return math.random(22, 26)
	end,

	Splits = function(treeData)
		if treeData.SegmentIndex == 5 then
			return math.random(4, 6)
		elseif treeData.SegmentIndex == 9 then
			return 3
		elseif treeData.SegmentIndex == 13 then
			return math.random(3, 4)
		end

		return 1
	end,

	Size = function(treeData)
		if treeData.SegmentIndex == 1 then
			local width = math.random(32, 36) / 10
			local size = Vector3.new(width, (math.random(60, 70) / 10), width)
			treeData.TrunkSize = size

			return size
		else
			return treeData.TrunkSize - (Vector3.new(0.12, 0.25, 0.12) * (treeData.SegmentIndex - 1))
		end
	end,

	CFrame = function(treeData)
		if treeData.SegmentIndex == 1 then
			CFrame.Angles(0, math.random(-180, 180), 0)
		end

		local finalCFrame = (treeData.LastBranch.CFrame - treeData.LastBranch.Position) 
			* CFrame.Angles(
				math.rad(math.random(-5, 5)),
				math.rad(math.random(-5, 5)),
				math.rad(math.random(-5, 5))
			)

		if treeData.SegmentIndex < 4 then
			finalCFrame = (treeData.LastBranch.CFrame - treeData.LastBranch.Position) 
				* CFrame.Angles(
					math.rad(0),
					math.rad(0),
					math.rad(0)
				)
		end

		if treeData.SegmentIndex == 5 then
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

		if treeData.SegmentIndex > 8 and treeData.SegmentIndex < 10 and treeData.TotalSplits > 1 then
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

		if treeData.SegmentIndex > 12 and treeData.SegmentIndex < 14 and treeData.TotalSplits > 1 then
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

return HugeOak
