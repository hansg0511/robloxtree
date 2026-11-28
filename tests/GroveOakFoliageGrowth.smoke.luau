-- Run from Roblox Studio SERVER Command Bar with Rojo connected.
-- Read-only Grove previews: verifies bark accents never float ahead of their
-- supporting procedural Oak core, and leaf blocks expand rather than pop in.
local Tree = require(game.ServerScriptService.Trees.TreeObject)

local function check(name, result)
	assert(result, name .. " failed")
end

local function preview(progress)
	local model = Tree.BuildPreviewModel("GroveOak", {
		SizePotential = 1.1,
		GroveStage = if progress >= 1 then "mature" else "young",
		GrowthProgress = progress,
	})
	check("procedural Grove Oak preview built", model and model:IsA("Model"))
	return model
end

local function visible(part)
	return part and part.Transparency < 0.99
end

local sampled = { 0, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.42, 0.60, 0.75, 0.85, 0.95, 1 }
local foundBarkAccents = false
local partialLeafCount = 0
local mature = preview(1)
local matureLeaves = {}
for _, part in ipairs(mature:GetDescendants()) do
	if part:IsA("BasePart") and
		(part.Name:find("Leaf") or part.Name:find("Canopy")) then
		matureLeaves[part.Name] = part
	end
end

for _, progress in ipairs(sampled) do
	local tree = preview(progress)
	local visibleCoreBySection = {}
	local hasCoreBySection = {}
	for _, part in ipairs(tree:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute("HarvestableCore") == true then
			local section = part:GetAttribute("HarvestSectionIndex")
			if type(section) == "number" then
				hasCoreBySection[section] = true
				visibleCoreBySection[section] =
					visibleCoreBySection[section] ~= false and visible(part)
			end
		end
	end
	for _, part in ipairs(tree:GetDescendants()) do
		if part:IsA("BasePart") then
			if part:GetAttribute("HarvestableBarkAccent") == true then
				foundBarkAccents = true
				local section = part:GetAttribute("HarvestSectionIndex")
				if visible(part) then
					check("accent has support section at " .. progress,
						hasCoreBySection[section] == true)
					check("accent never precedes supporting core at " .. progress,
						visibleCoreBySection[section] == true)
				end
			end
			if part.Name:find("Leaf") or part.Name:find("Canopy") then
				local full = matureLeaves[part.Name]
				if full and visible(part) then
					check("foliage never grows larger than authored tree",
						part.Size.X <= full.Size.X + 0.005
							and part.Size.Y <= full.Size.Y + 0.005
							and part.Size.Z <= full.Size.Z + 0.005)
					if progress >= 0.60 and progress < 1
						and part.Size.X < full.Size.X * 0.90 then
						partialLeafCount += 1
					end
				end
			end
		end
	end
	tree:Destroy()
end
check("Oak bark accent models were tested", foundBarkAccents)
check("some Oak foliage is visibly partially grown", partialLeafCount > 0)
mature:Destroy()
print("Grove Oak bark and progressive leaf-size checks passed")
return true
