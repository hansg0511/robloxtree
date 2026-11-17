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
print("Huge two-part Grove trunk growth smoke checks passed")
return true
