-- Roblox Studio SERVER Command Bar after Rojo sync.
-- Read-only model previews. Tests progressive server-rendered growth proxies
-- rather than old six-layer Bamboo segment stand-ins.
local Tree = require(game.ServerScriptService.Trees.TreeObject)
local function check(name, ok)
	assert(ok, name .. " failed")
end

local function preview(species, progress)
	local model = Tree.BuildPreviewModel(species, {
		GroveStage = if progress >= 1 then "mature" else "young",
		SizePotential = 1, GrowthProgress = progress,
	})
	check(species .. " visual preview", model ~= nil)
	return model
end

local function visible(part)
	return part ~= nil and part.Transparency < 0.99
end

local function proxyFor(model, name)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Name == "GroveGrowthProxy"
			and part:GetAttribute("GroveGrowthSource") == name then
			return part
		end
	end
	return nil
end

-- Each Ironwood trunk body extends upward before the next. Its original
-- full-length source body replaces the proxy only AFTER growth completes.
for _, case in ipairs({
	{ Progress = 0.10, Bottom = "proxy", Middle = "hidden", Top = "hidden" },
	{ Progress = 0.25, Bottom = "native", Middle = "proxy", Top = "hidden" },
	{ Progress = 0.35, Bottom = "native", Middle = "native", Top = "proxy" },
	{ Progress = 0.45, Bottom = "native", Middle = "native", Top = "native" },
	{ Progress = 1.00, Bottom = "native", Middle = "native", Top = "native" },
}) do
	local tree = preview("Ironwood", case.Progress)
	for _, item in ipairs({
		{ Name = "Bark", Expected = case.Bottom },
		{ Name = "BarkBrick1", Expected = case.Middle },
		{ Name = "BarkBrick2", Expected = case.Top },
	}) do
		local native = tree:FindFirstChild(item.Name, true)
		local proxy = proxyFor(tree, item.Name)
		check("Ironwood source and proxy exist " .. item.Name, native and proxy)
		local actual = if visible(native) then "native"
			else if visible(proxy) then "proxy" else "hidden"
		check(item.Name .. " at progress " .. case.Progress, actual == item.Expected)
	end
	for _, part in ipairs(tree:GetDescendants()) do
		if part:IsA("BasePart") and part.Name == "BarkStud" then
			check("No detached Ironwood bark dots", not visible(part))
		end
	end
	tree:Destroy()
end

-- Bamboo: exactly five synchronized bottom-anchored proxies, no 30
-- segmented growth pieces. At the same progress their height fractions
-- should match despite different final heights.
local caneNames = {
	BambooCore = true, BambooStalk2 = true, BambooStalk3 = true,
	BambooStalk4 = true, BambooStalk5 = true,
}
for _, sample in ipairs({
	{ Progress = 0, Proxy = false, Native = false, Stumps = true },
	{ Progress = 0.15, Proxy = true, Native = false, Stumps = true },
	{ Progress = 0.35, Proxy = true, Native = false, Stumps = false },
	{ Progress = 0.60, Proxy = true, Native = false, Stumps = false },
	{ Progress = 0.65, Proxy = false, Native = true, Stumps = false },
	{ Progress = 1, Proxy = false, Native = true, Stumps = false },
}) do
	local tree = preview("Bamboo", sample.Progress)
	local stumps = 0
	for _, item in ipairs(tree:GetDescendants()) do
		if item:IsA("BasePart") and
			string.match(item.Name, "^GroveBambooCulm%d+Stump$") and visible(item) then
			stumps += 1
		end
		check("No old segmented Bamboo proxies", item.Name ~= "GroveBambooGrowthSegment")
	end
	check("Five thin Bamboo stumps at " .. sample.Progress,
		(stumps == 5) == sample.Stumps)
	local commonFraction
	for cane in pairs(caneNames) do
		local native = tree:FindFirstChild(cane, true)
		local proxy = proxyFor(tree, cane)
		check("Bamboo native and proxy exist " .. cane, native and proxy)
		check("Bamboo native state " .. cane .. " at " .. sample.Progress,
			visible(native) == sample.Native)
		check("Bamboo proxy state " .. cane .. " at " .. sample.Progress,
			visible(proxy) == sample.Proxy)
		if sample.Proxy then
			local fraction = proxy.Size.Y / native.Size.Y
			if commonFraction then
				check("All five Bamboo canes rise together", math.abs(commonFraction - fraction) < 0.005)
			else
				commonFraction = fraction
			end
			local nativeBase = native.CFrame * CFrame.new(0, -native.Size.Y * 0.5, 0)
			local proxyBase = proxy.CFrame * CFrame.new(0, -proxy.Size.Y * 0.5, 0)
			check("Bamboo growing cane bottom stays rooted",
				(nativeBase.Position - proxyBase.Position).Magnitude < 0.02)
		end
	end
	tree:Destroy()
end

-- Approved Oak remains procedural and does not receive old segmented cane
-- parts. It may now use full-length wood proxies instead.
local oak = preview("GroveOak", 0.35)
check("Oak uses existing procedural final model",
	oak:GetAttribute("ProceduralStarterOak") == true)
check("Oak has no Bamboo segmented proxies",
	oak:FindFirstChild("GroveBambooGrowthSegment", true) == nil)
oak:Destroy()

print("Grove Ironwood/Bamboo bottom-anchored growth checks passed")
return true
