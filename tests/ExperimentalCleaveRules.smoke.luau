-- Run in Roblox Studio SERVER Command Bar during Play.
-- No profiles, live trees or player inventories are modified by this test.
local Rules = require(game.ServerScriptService.Economy.Wood.CleaveRules)
local Forge = require(game.ReplicatedStorage.Shared.ExperimentalForgeRules)

local function near(a, b)
	return math.abs(a - b) < 0.00001
end

assert(Rules.Resolve(nil) == nil, "Absent metadata cannot grant Cleave")
assert(Rules.Resolve({ Radius = 16,
	DamageFraction = 0.4 }) ~= nil,
	"Cleave behavior must not depend on a weapon class")
assert(Rules.Resolve({}) == nil,
	"Missing effect parameters cannot activate")
assert(Rules.Resolve({ Radius = 0 / 0,
	DamageFraction = 0.4 }) == nil,
	"Nonfinite radius must fail closed")
local profile = Rules.Resolve({
	Radius = 10,
	DamageFraction = 0.4,
})
assert(profile and profile.MaxTargets == 2 and near(profile.Radius, 10),
	"Server-owned effect parameters resolve")
assert(Rules.SecondaryDamage(100, profile) == 40, "40% of damage")
assert(Rules.SecondaryDamage(1, profile) == 0, "Small hits don't create free damage")
assert(Rules.SecondaryDamage(0, profile) == 0, "No free damage on zero-hit")
local maxed = Rules.Resolve({
	Radius = 100000,
	DamageFraction = 100,
})
assert(maxed.Radius == Rules.MAX_RADIUS_STUDS
	and near(maxed.DamageFraction, Rules.MAX_DAMAGE_FRACTION),
	"Saved metadata cannot exceed server safety caps")

local function tree(id, x, y, z, canHit)
	return {
		CreationId = id,
		CFrame = CFrame.new(x, y, z),
		CanBeHit = canHit ~= false,
	}
end
local primary = tree(1, 0, 0, 0)
local near1 = tree(2, 3, 0, 0)
local near2 = tree(3, 5, 0, 0)
local near3 = tree(4, 7, 0, 0)
local far = tree(5, 15, 0, 0)
local vertical = tree(6, 1, 30, 0)
local protected = tree(7, 1, 0, 0, false)
local registry = {
	[primary] = true, [near1] = true, [near2] = true,
	[near3] = true, [far] = true, [vertical] = true,
	[protected] = true,
}
local result = Rules.FindSecondaryTargets(primary, registry, profile,
	function(candidate)
		return candidate.CanBeHit
	end)
assert(#result == 2 and result[1] == near1 and result[2] == near2,
	"Select only the two closest allowed trees; exclude primary, far, high and protected")
local sameDistA = tree(8, 3, 0, 0)
local sameDistB = tree(9, 3, 0, 0)
local ties = Rules.FindSecondaryTargets(primary,
	{ [primary] = true, [sameDistB] = true, [sameDistA] = true },
	profile, function() return true end)
assert(ties[1] == sameDistA and ties[2] == sameDistB,
	"CreationId must break distance ties deterministically")
assert(#Rules.FindSecondaryTargets(primary, registry,
	profile, function() return false end) == 0,
	"Denied targets must be excluded")
assert(#Rules.FindSecondaryTargets(primary, registry,
	{ Radius = 0, MaxTargets = 2 },
	function() return true end) == 0, "Invalid radius fails closed")

-- Twenty normal high-quality logs guarantee the heavy class and independently
-- rolled Cleave stats that are included in the saved weapon payload.
local logs = {}
for i = 1, 20 do
	logs[i] = { SpeciesId = "Ironwood", SizeScale = 5, Mutations = {} }
end
local preview = Forge.Preview(25, logs)
assert(preview.Odds.Battlehammer == 1, "20-log class guarantee")
assert(preview.Ranges.Battlehammer.CleaveDamageFraction
	and preview.Ranges.Battlehammer.CleaveRadius,
	"Preview includes secondary effect potential")
assert(preview.Ranges.Dagger.CleaveRadius == nil
	and preview.Ranges.Axe.CleaveDamageFraction == nil,
	"No secondary effect is assigned to other classes")

local draw = 0
local rng = {
	NextNumber = function()
		draw += 1
		return 0.5
	end,
}
local rolled = Forge.Roll(25, logs, rng)
assert(rolled.Class == "Battlehammer", "Forged class is heavy")
assert(near(rolled.CleaveDamageFraction, Forge.CLEAVE_DAMAGE_FRACTION)
	and near(rolled.CleaveRadius, Forge.CLEAVE_RADIUS_STUDS),
	"Cleave stats get material-quality and independent roll calculations")
assert(draw == 6, "One class, three core stats and two ability stats; no Golden roll")

-- Forest 1 Sapwood is a genuine material, not a thin Oak visual.
-- Keep this in the existing forge/effects smoke; no new test runner.
local materials = require(game.ServerScriptService.Economy.MaterialDefinitions)
local treeDefs = require(game.ServerScriptService.Trees.TreeDefinitions)
local sapwood = materials.Get("Sapwood")
local sapwoodTree = treeDefs.SapwoodTree
assert(sapwood and sapwood.CapacityKg == 0.5
	and sapwood.CarryVisualScale > 0 and sapwood.SellValue > 0,
	"Sapwood must support light carry weight, log visuals and sale")
assert(sapwoodTree and sapwoodTree.SpeciesId == "Sapwood"
	and sapwoodTree.YieldsLog == true and sapwoodTree.LogYield == 2
	and sapwoodTree.ForestId == "Forest1",
	"Sapwood trees must use the normal wild harvest contract")
local lightPreview = Forge.Preview(25, {
	{SpeciesId = "Sapwood", SizeScale = 1, Mutations = {}},
}, 1)
assert(lightPreview and lightPreview.LogCount == 1
	and lightPreview.Odds.Dagger == 1,
	"Sapwood must be usable in existing experimental forge previews")

-- Low-quality and maximum-quality wood retain the same speed ranges.
for class, interval in pairs({ Dagger = 0.35, Axe = 0.60, Battlehammer = 1.10 }) do
	local low = lightPreview.Ranges[class].AttacksPerSecond
	local high = preview.Ranges[class].AttacksPerSecond
	assert(near(low.Min, high.Min) and near(low.Max, high.Max),
		"Wood quality must not slow attack cadence: " .. class)
	assert(near((low.Min + low.Max) / 2, 1 / interval),
		"Class speed midpoint matches combat-feel baseline: " .. class)
end

print("Battlehammer Cleave: class gate, caps, target filtering, deterministic tie-break and rolls passed")
return true
