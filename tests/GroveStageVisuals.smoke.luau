-- Paste in Roblox Studio's SERVER Command Bar after connecting Rojo.
-- This is a read-only visual-model smoke test; it does not plant or harvest.
local Tree = require(game.ServerScriptService.Trees.TreeObject)

local function check(name, value)
	assert(value, name .. " failed")
end

local species = { "GroveOak", "Bamboo", "Ironwood" }
local stages = { "stump", "sapling", "young", "mature" }
for _, kind in ipairs(species) do
	local heights, silhouettes = {}, {}
	for _, stage in ipairs(stages) do
		local model = Tree.BuildPreviewModel(kind, {
			GroveStage = stage,
			SizePotential = 1,
			Mutations = { Golden = true },
		})
		check(kind .. " " .. stage .. " model built", model ~= nil)
		check(kind .. " " .. stage .. " stage metadata",
			model:GetAttribute("VisualGrowthStage") == stage)
		local leaves = model:FindFirstChild("Leaves")
		check(kind .. " " .. stage .. " leaves folder", leaves ~= nil)

		local visibleLeaves = 0
		for _, object in ipairs(leaves:GetDescendants()) do
			if object:IsA("BasePart") and object.Transparency < 1 then
				visibleLeaves += 1
				check("world foliage is cubes/cuboids: " .. kind .. " " .. stage,
					object.Shape == Enum.PartType.Block)
			end
		end
		if stage == "stump" then
			check(kind .. " stump is leafless", visibleLeaves == 0)
		else
			check(kind .. " " .. stage .. " has leaves", visibleLeaves > 0)
		end
		local height = model:GetExtentsSize().Y
		heights[stage] = height
		silhouettes[stage] = #model:GetDescendants()
		check(kind .. " " .. stage .. " visible height", height > 0)
		model:Destroy()
	end
	check(kind .. " stump shorter than sapling", heights.stump < heights.sapling)
	check(kind .. " sapling shorter than young", heights.sapling < heights.young)
	check(kind .. " young shorter than mature", heights.young < heights.mature)
	check(kind .. " different stage meshes",
		silhouettes.sapling ~= silhouettes.young
		and silhouettes.young ~= silhouettes.mature)
	print(kind, string.format("stage heights: stump %.1f, sapling %.1f, young %.1f, mature %.1f",
		heights.stump, heights.sapling, heights.young, heights.mature))
end
print("Grove distinct-stage visual smoke checks passed")
return true
