-- Studio SERVER Command Bar; read-only previews only.
-- Verify the generic six-milestone allocation on Ironwood and Bamboo.
local Tree = require(game.ServerScriptService.Trees.TreeObject)
local Rules = require(game.ServerScriptService.Grove.GroveGrowthRules)
local function check(name, ok)
	assert(ok, name .. " failed")
end

local function preview(species, progress)
	local model = Tree.BuildPreviewModel(species, {
		GroveStage = if progress >= 1 then "mature" else "young",
		SizePotential = 1, GrowthDurationSeconds = Rules.DurationForSize(1),
		GrowthProgress = progress,
	})
	check(species .. " preview", model ~= nil)
	check("six steps for size one independent of cadence",
		model:GetAttribute("GroveGrowthVisualTotalSteps") == Rules.StepsForSize(1))
	return model
end

local function visible(part)
	return part ~= nil and part.Transparency < 0.99
end

local function proxyFor(model, source)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Name == "GroveGrowthProxy"
			and part:GetAttribute("GroveGrowthSource") == source then
			return part
		end
	end
	return nil
end

-- Ironwood lower section, then middle, then upper. The entire vertical
-- wood structure is allocated across three of the six visible updates.
for _, case in ipairs({
	{ Progress = 0, Lower = "hidden", Middle = "hidden", Upper = "hidden" },
	{ Progress = 1 / 6, Lower = "proxy", Middle = "hidden", Upper = "hidden" },
	{ Progress = 2 / 6, Lower = "native", Middle = "proxy", Upper = "hidden" },
	{ Progress = 3 / 6, Lower = "native", Middle = "native", Upper = "native" },
	{ Progress = 1, Lower = "native", Middle = "native", Upper = "native" },
}) do
	local tree = preview("Ironwood", case.Progress)
	for _, item in ipairs({
		{ Name = "Bark", State = case.Lower },
		{ Name = "BarkBrick1", State = case.Middle },
		{ Name = "BarkBrick2", State = case.Upper },
	}) do
		local native = tree:FindFirstChild(item.Name, true)
		local proxy = proxyFor(tree, item.Name)
		check("Ironwood original " .. item.Name, native ~= nil)
		local state = if visible(native) then "native"
			else if visible(proxy) then "proxy" else "hidden"
		check(item.Name .. " phase at " .. case.Progress, state == item.State)
		if item.State == "native" then
			check("Finished Ironwood proxy freed", proxy == nil)
		end
	end
	for _, part in ipairs(tree:GetDescendants()) do
		if part:IsA("BasePart") and part.Name == "BarkStud" then
			check("No floating Grove Ironwood dots", not visible(part))
		end
	end
	tree:Destroy()
end

-- Bamboo is one existing synchronized visual bundle, not five independent
-- sequential parts. It retains the slim five-culm stumps and native canopy.
local canes = { "BambooCore", "BambooStalk2", "BambooStalk3",
	"BambooStalk4", "BambooStalk5" }
for _, sample in ipairs({
	{ Progress = 0, Proxy = false, Native = false, Stumps = true },
	{ Progress = 1 / 6, Proxy = true, Native = false, Stumps = false },
	{ Progress = 2 / 6, Proxy = true, Native = false, Stumps = false },
	{ Progress = 3 / 6, Proxy = false, Native = true, Stumps = false },
	{ Progress = 1, Proxy = false, Native = true, Stumps = false },
}) do
	local tree = preview("Bamboo", sample.Progress)
	local stumps = 0
	for _, part in ipairs(tree:GetDescendants()) do
		if part:IsA("BasePart") then
			if string.match(part.Name, "^GroveBambooCulm%d+Stump$") and visible(part) then
				stumps += 1
			end
			check("No old sliced Bamboo segments", part.Name ~= "GroveBambooGrowthSegment")
		end
	end
	check("Bamboo five stumps", (stumps == 5) == sample.Stumps)
	local commonFraction
	for _, cane in ipairs(canes) do
		local native = tree:FindFirstChild(cane, true)
		local proxy = proxyFor(tree, cane)
		check("Bamboo native exists", native ~= nil)
		check("Bamboo native visible at correct step",
			visible(native) == sample.Native)
		check("Bamboo proxy visible at correct step",
			visible(proxy) == sample.Proxy)
		if sample.Native then check("Finished Bamboo proxy freed", proxy == nil) end
		if sample.Proxy then
			local fraction = proxy.Size.Y / native.Size.Y
			check("All five canes grow by same fraction", commonFraction == nil
				or math.abs(commonFraction - fraction) < 0.005)
			commonFraction = fraction
			local nativeFoot = native.CFrame * CFrame.new(0, -native.Size.Y * 0.5, 0)
			local proxyFoot = proxy.CFrame * CFrame.new(0, -proxy.Size.Y * 0.5, 0)
			check("Bamboo foot anchored",
				(nativeFoot.Position - proxyFoot.Position).Magnitude < 0.02)
		end
	end
	tree:Destroy()
end

local oak = preview("GroveOak", 2 / 6)
check("Oak uses native Forest 1 procedural model",
	oak:GetAttribute("ProceduralStarterOak") == true)
oak:Destroy()

print("Six-step Ironwood/Bamboo growth checks passed")
return true
