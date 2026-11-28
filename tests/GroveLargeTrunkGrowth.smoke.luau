-- Studio SERVER Command Bar, no player profile mutation.
-- Verify a deliberately huge, TWO-PIECE trunk grows with a fixed base
-- instead of popping complete pieces into the Grove.
local Visuals = require(game.ServerScriptService.Trees.GroveGrowthVisuals)

local function check(name, value)
	assert(value, name .. " failed")
end

local fakeTree = Instance.new("Model")
fakeTree.Name = "HugeTwoPartTrunkTest"
local carrier = Instance.new("Part")
carrier.Name = "OakRootCarrier"
carrier.Size = Vector3.new(0.2, 0.2, 0.2)
carrier.Transparency = 1
carrier.CanCollide = false
carrier.Anchored = true
carrier:SetAttribute("AlwaysInvisible", true)
carrier.CFrame = CFrame.new(0, 0, 0)
carrier.Parent = fakeTree
fakeTree.PrimaryPart = carrier

for i = 1, 2 do
	local block = Instance.new("Part")
	block.Name = "BarkBrick" .. i
	block.Size = Vector3.new(8, 60, 8)
	block.CFrame = CFrame.new(0, (i - 0.5) * 60, 0)
	block.Anchored = true
	block.Parent = fakeTree
end

local state = Visuals.Prepare(fakeTree, "Oak")
check("Grove visual state prepared", state ~= nil)
local proxyRecords = {}
for _, record in ipairs(state.Records) do
	if record.Proxy then
		proxyRecords[record.Part.Name] = record
	end
end
check("Both huge pieces get one proxy each",
	proxyRecords.BarkBrick1 ~= nil and proxyRecords.BarkBrick2 ~= nil)
local first = proxyRecords.BarkBrick1
local second = proxyRecords.BarkBrick2
check("Lower trunk begins before upper trunk", first.At < second.At)
check("Only two temporary growing wood pieces", (function()
	local n = 0
	for _, record in ipairs(state.Records) do
		if record.Proxy then n += 1 end
	end
	return n == 2
end)())

for _, fraction in ipairs({ 0, 0.10, 0.15, 0.20, 0.25, 0.30, 0.40, 1 }) do
	check("Progress update " .. fraction, Visuals.Apply(state, fraction, true))
	for _, record in ipairs({ first, second }) do
		local native = record.Part
		local proxy = record.Proxy
		check("Real trunk Size remains unchanged", math.abs(native.Size.Y - 60) < 0.01)
		check("Real trunk CFrame remains unchanged",
			(native.Position - Vector3.new(0,
				if native.Name == "BarkBrick1" then 30 else 90, 0)).Magnitude < 0.01)
		local growing = proxy.Transparency < 0.99
		local finished = native.Transparency < 0.99
		check("Full trunk never overlaps proxy", not (growing and finished))
		if growing then
			local localBottom = proxy.CFrame:PointToWorldSpace(
				Vector3.new(0, -proxy.Size.Y * 0.5, 0))
			local nativeBottom = native.CFrame:PointToWorldSpace(
				Vector3.new(0, -native.Size.Y * 0.5, 0))
			check("Growing trunk stays anchored at its foot",
				(localBottom - nativeBottom).Magnitude < 0.015)
			check("Growing proxy height not larger than source",
				proxy.Size.Y <= native.Size.Y + 0.01)
		end
	end
end
check("Original complete native trunk is visible at maturity",
	first.Part.Transparency < 0.99 and second.Part.Transparency < 0.99)
check("Temporary visual copies are destroyed after maturity",
	first.Proxy.Parent == nil and second.Proxy.Parent == nil)

fakeTree:Destroy()

-- A single 30-stud ROTATED branch also extends along its LOCAL Y axis.
-- Its base stays attached to its own original starting point, not to the
-- model's world Y coordinate (important for angled branches in later worlds).
local branchTree = Instance.new("Model")
branchTree.Name = "OneHugeRotatedBranch"
local pivot = Instance.new("Part")
pivot.Name = "RootCarrier"
pivot.Size = Vector3.new(0.2, 0.2, 0.2)
pivot.CFrame = CFrame.new()
pivot.Transparency = 1
pivot.Anchored = true
pivot:SetAttribute("AlwaysInvisible", true)
pivot.Parent = branchTree
branchTree.PrimaryPart = pivot
local bigBranch = Instance.new("Part")
bigBranch.Name = "Branch1"
bigBranch.Size = Vector3.new(2, 30, 2)
bigBranch.CFrame = CFrame.new(0, 13, 0) * CFrame.Angles(0, 0, math.rad(65))
bigBranch.Anchored = true
bigBranch.Parent = branchTree
local branchState = Visuals.Prepare(branchTree, "Oak")
local branchRecord
for _, record in ipairs(branchState.Records) do
	if record.Part == bigBranch then branchRecord = record end
end
check("Angled branch gets a single height-growth proxy",
	branchRecord and branchRecord.Proxy and branchRecord.Axis == "Y")
local mid = math.min(0.95, branchRecord.At + branchRecord.GrowDuration * 0.5)
check("Angled branch can progress", Visuals.Apply(branchState, mid, true))
local proxy = branchRecord.Proxy
check("Angled branch is growing", proxy.Parent and proxy.Transparency < 0.99)
local sourceFoot = bigBranch.CFrame * CFrame.new(0, -bigBranch.Size.Y * 0.5, 0)
local proxyFoot = proxy.CFrame * CFrame.new(0, -proxy.Size.Y * 0.5, 0)
check("Rotated branch begins at its own fixed foot",
	(sourceFoot.Position - proxyFoot.Position).Magnitude < 0.015)
check("Angled source remains full-size and unmoved",
	bigBranch.Size.Y == 30 and (bigBranch.CFrame.Position
		- Vector3.new(0, 13, 0)).Magnitude < 0.01)
check("Angled branch fully matures", Visuals.Apply(branchState, 1, true))
check("Angled temporary proxy is freed", proxy.Parent == nil)
check("Angled native source is visible", bigBranch.Transparency < 0.99)
branchTree:Destroy()

print("Huge two-part trunk and rotated-branch Grove growth checks passed")
return true
