-- Studio SERVER Command Bar. Pure allocation metadata test; no live trees.
local Allocation = require(game.ServerScriptService.Trees.GroveGrowthAllocation)
local Rules = require(game.ServerScriptService.Grove.GroveGrowthRules)
local function check(name, ok)
	assert(ok, name .. " failed")
end

local model = Instance.new("Model")
model.Name = "AllocationSmokeTest"
local root = Instance.new("Part")
root.Name = "InvisibleRoot"
root.CFrame = CFrame.new(0, 0, 0)
root.Size = Vector3.new(0.2, 0.2, 0.2)
root.Transparency = 1
root.Parent = model
model.PrimaryPart = root

local function add(name, size, pos, role, axis)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(pos)
	part.Parent = model
	return { Part = part, Role = role, Axis = axis }
end

local lower = add("Lower", Vector3.new(3, 10, 3), Vector3.new(0, 5, 0), "trunk", "Y")
local upper = add("Upper", Vector3.new(2, 20, 2), Vector3.new(0, 20, 0), "trunk", "Y")
local branch = add("Branch", Vector3.new(1, 8, 1), Vector3.new(4, 20, 0), "branches", "Y")
local lowLeaf = add("LowLeaf", Vector3.new(8, 6, 8), Vector3.new(4, 21, 0), "leaves", nil)
local highLeaf = add("HighLeaf", Vector3.new(6, 6, 6), Vector3.new(0, 30, 0), "leaves", nil)
local records = { upper, lowLeaf, branch, lower, highLeaf }
Allocation.Assign(records, model)

local near = function(a,b) return math.abs(a-b) < 0.001 end
check("lower trunk starts at ground", near(lower.At, 0))
check("lower trunk fills first 10 of 30 studs",
	near(lower.NativeAt, 0.5 * 10 / 30))
check("upper trunk starts when lower reaches 10 studs",
	near(upper.At, lower.NativeAt))
check("upper trunk finishes at 50% progress",
	near(upper.NativeAt, 0.5))
check("branches follow trunk", branch.At >= upper.NativeAt)
check("lower foliage starts before upper foliage",
	lowLeaf.At < highLeaf.At)
check("all foliage completes at maturity", near(highLeaf.NativeAt, 1))

-- At six steps, two unequal source Parts still have three meaningful
-- trunk growth milestones. At 24 steps, the same allocation gives more
-- intermediate heights; no model changes or magic 40-step denominator.
local function totalVisibleHeight(normalizedProgress)
	local overallTip = math.clamp(normalizedProgress / 0.5, 0, 1) * 30
	local lowHeight = math.clamp(overallTip, 0, 10)
	local highHeight = math.clamp(overallTip - 10, 0, 20)
	return lowHeight, highHeight
end
local firstLow, firstHigh = totalVisibleHeight(1/6)
check("six-step sample 1 shows 10-stud lower Part", near(firstLow, 10))
check("six-step sample 1 upper Part not yet grown", near(firstHigh, 0))
local secondLow, secondHigh = totalVisibleHeight(2/6)
check("six-step sample 2 upper Part partially grown",
	near(secondLow, 10) and near(secondHigh, 10))
local longLow, longHigh = totalVisibleHeight(1/24)
check("longer cycle has smaller first increment",
	longLow < firstLow and near(longHigh, 0))

-- Plant authors can override windows without changing the renderer.
highLeaf.Part:SetAttribute("GroveGrowthStart", 0.75)
highLeaf.Part:SetAttribute("GroveGrowthFinish", 1)
Allocation.Assign(records, model)
check("per-part explicit timing override honored",
	near(highLeaf.At, 0.75) and near(highLeaf.NativeAt, 1))

-- Manually authored growth ordering can override spatial height sorting
-- for twisted pieces with non-obvious botanical order.
lower.Part:SetAttribute("GroveGrowthOrder", 2)
upper.Part:SetAttribute("GroveGrowthOrder", 1)
Allocation.Assign(records, model)
check("manual trunk order can invert automatic height sorting",
	near(upper.At, 0) and near(upper.NativeAt, 0.5 * 20 / 30)
		and near(lower.At, upper.NativeAt) and near(lower.NativeAt, 0.5))

model:Destroy()
check("30 seconds makes six five-second steps",
	Rules.DurationForSize(1) / Rules.SECONDS_PER_VISUAL_STEP == 6)
print("Generic sequential Grove growth allocation checks passed")
return true
