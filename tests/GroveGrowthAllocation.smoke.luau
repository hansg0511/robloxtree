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

-- At 15 steps, two unequal source Parts grow by height, not count.
-- A 24-step animation would simply sample the same allocation more often.
local function totalVisibleHeight(normalizedProgress)
	local overallTip = math.clamp(normalizedProgress / 0.5, 0, 1) * 30
	local lowHeight = math.clamp(overallTip, 0, 10)
	local highHeight = math.clamp(overallTip - 10, 0, 20)
	return lowHeight, highHeight
end
local firstLow, firstHigh = totalVisibleHeight(1/15)
check("first 15-step update begins extending lower trunk", near(firstLow, 4))
check("first 15-step update upper Part still hidden", near(firstHigh, 0))
local secondLow, secondHigh = totalVisibleHeight(5/15)
check("later update extends upper Part", near(secondLow, 10) and near(secondHigh, 10))
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
check("all plant sizes use 15 steps, each two seconds",
	Rules.StepsForSize(0.7) == 15
		and Rules.StepsForSize(1.7) == 15
		and Rules.DurationForSize(1) == 30
		and Rules.DurationForSize(1) / Rules.SECONDS_PER_VISUAL_STEP == 15)
print("Generic sequential Grove growth allocation checks passed")
return true
