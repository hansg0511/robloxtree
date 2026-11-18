-- Roblox Studio SERVER Command Bar, with the new Rojo branch connected.
-- Read-only model-building test. No player profiles or Grove entries mutated.
local Tree = require(game.ServerScriptService.Trees.TreeObject)
local GrowthRules = require(game.ServerScriptService.Grove.GroveGrowthRules)
local Configuration = require(game.ServerScriptService.WorldLayout.WorldLayoutConfiguration)

local function check(name, condition)
	assert(condition, name .. " failed")
end

local function describe(model)
	local leaves, branches, trunk = 0, 0, 0
	local visibleParts = 0
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute("AlwaysInvisible") ~= true
			and part.Transparency < 0.99 then
			visibleParts += 1
			local node = part
			local leaf = false
			local branch = false
			while node and node ~= model do
				if node.Name == "Leaves" or node.Name == "FoliageDecorations" then leaf = true end
				if node.Name == "DecorativeBranches" then branch = true end
				node = node.Parent
			end
			if leaf then leaves += 1
			elseif branch then branches += 1
			else trunk += 1 end
		end
	end
	return { Visible = visibleParts, Trunk = trunk, Branches = branches, Leaves = leaves }
end

-- These represent preview sample fractions; the renderer snaps each one to
-- the available five-second milestones for that specific size.
local phases = { 0, 1 / 6, 0.50, 5 / 6, 1 }
for _, kind in ipairs({ "GroveOak", "Bamboo", "Ironwood" }) do
	local series = {}
	local totalParts
	for _, progress in ipairs(phases) do
		local model = Tree.BuildPreviewModel(kind, {
			GroveStage = if progress >= 1 then "mature" else "young",
			GrowthProgress = progress,
			SizePotential = 1.2,
			Mutations = { Golden = true },
		})
		check(kind .. " preview built", model ~= nil)
		local steps = model:GetAttribute("GroveGrowthVisualTotalSteps")
		check(kind .. " total steps assigned", type(steps) == "number" and steps >= 1)
		local expectedStep = math.floor(progress * steps + 1e-6)
		check(kind .. " five-second milestone",
			model:GetAttribute("GroveGrowthVisualStep") == expectedStep)
		check(kind .. " progress metadata",
			math.abs((model:GetAttribute("GroveGrowthProgress") or -1)
				- expectedStep / steps) <= 0.0001)
		local stumpName = if kind == "Bamboo" then "GroveBambooCulm1Stump"
			else "GroveGrowthStump"
		local stump = model:FindFirstChild(stumpName)
		check(kind .. " predictive stump exists", stump ~= nil)
		local shouldBeStump = expectedStep == 0
		check(kind .. " stump visibility",
			(stump.Transparency == 0) == shouldBeStump)
		if kind == "GroveOak" and Configuration.PROCEDURAL_STARTER_OAKS_ENABLED == true then
			check("Grove Oak uses Forest 1 procedural generator",
				model:GetAttribute("ProceduralStarterOak") == true)
		end
		-- Cosmetic wood proxies disappear once their native source is
		-- visible; compare the permanent source geometry instead of raw
		-- temporary descendant counts.
		local permanentParts = 0
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "GroveGrowthProxy"
				and part.Name ~= "GroveGrowthStump"
				and part.Name ~= "GroveGrowthCutEnd"
				and not string.match(part.Name, "^GroveBambooCulm%d+Stump$")
				and not string.match(part.Name, "^GroveBambooCulm%d+CutEnd$") then
				permanentParts += 1
			end
		end
		totalParts = totalParts or permanentParts
		check(kind .. " permanent source geometry never changes", permanentParts == totalParts)
		table.insert(series, describe(model))
		model:Destroy()
	end
	check(kind .. " has visible base", series[1].Trunk > 0)
	check(kind .. " no foliage at stump", series[1].Leaves == 0)
	check(kind .. " trunk develops", series[3].Trunk > series[1].Trunk)
	check(kind .. " foliage arrives late", series[5].Leaves > series[3].Leaves)
	check(kind .. " mature tree has visible canopy", series[5].Leaves > 0)
	check(kind .. " mature model has more parts", series[5].Visible > series[1].Visible)
	print(kind, "visible counts:",
		series[1].Visible, series[2].Visible, series[3].Visible,
		series[4].Visible, series[5].Visible)
end

for _, kind in ipairs({ "GroveOak", "Bamboo", "Ironwood" }) do
	local small = Tree.BuildPreviewModel(kind, {
		GroveStage = "stump", GrowthProgress = 0, SizePotential = 0.75,
	})
	local huge = Tree.BuildPreviewModel(kind, {
		GroveStage = "stump", GrowthProgress = 0, SizePotential = 1.75,
	})
	check(kind .. " small and large stumps built", small ~= nil and huge ~= nil)
	local stumpName = if kind == "Bamboo" then "GroveBambooCulm1Stump"
		else "GroveGrowthStump"
	local smallWidth = small:FindFirstChild(stumpName).Size.X
	local hugeWidth = huge:FindFirstChild(stumpName).Size.X
	check(kind .. " huge stump predicts bigger growth", hugeWidth > smallWidth)
	small:Destroy()
	huge:Destroy()
end

check("growth progress begins at zero",
	GrowthRules.Progress({ PlantedAt = 1000, MaturesAt = 1045, HarvestCount = 0 }, 1000) == 0)
check("regrowth holds stump 5 sec",
	GrowthRules.Progress({ PlantedAt = 1000, MaturesAt = 1045, HarvestCount = 1 }, 1004) == 0)
check("regrowth finishes at 45 sec",
	GrowthRules.Progress({ PlantedAt = 1000, MaturesAt = 1045, HarvestCount = 1 }, 1045) == 1)
print("Grove progressive growth smoke checks passed")
return true
