-- Manual Studio smoke test. Paste into the SERVER Command Bar after Rojo
-- sync, or run this file using a Luau test runner configured for the place.
-- This file lives outside the Rojo source tree and does not execute on join.
local ServerScriptService = game:GetService("ServerScriptService")
local rules = require(ServerScriptService.Economy.WeaponRecipeRules)

local function check(testName, condition)
	assert(condition, testName .. " failed")
end

local valid = { "log-a", "log-b", "log-c" }
check("valid exact selection", rules.IsExactUidSelection(valid, 3))
check("reject undersized", not rules.IsExactUidSelection({ "log-a", "log-b" }, 3))
check("reject oversized", not rules.IsExactUidSelection({ "log-a", "log-b", "log-c", "log-d" }, 3))
check("reject duplicate", not rules.IsExactUidSelection({ "log-a", "log-b", "log-a" }, 3))
check("reject holes", not rules.IsExactUidSelection({ [1] = "log-a", [3] = "log-c" }, 3))
check("reject extra keys", not rules.IsExactUidSelection({ [1] = "log-a", [2] = "log-b", [3] = "log-c", bonus = "log-d" }, 3))
check("reject bad UID", not rules.IsExactUidSelection({ "log-a", "", "log-c" }, 3))
check("reject non-array", not rules.IsExactUidSelection("log-a", 3))
check("reject invalid required count", not rules.IsExactUidSelection(valid, 0))

local copper = { Id = "copper_axe", OutputItemID = 102, WeaponKind = "Axe" }
local fixed = rules.ResolveFixedOutput(copper)
check("fixed output exists", fixed ~= nil)
check("fixed identity", fixed.RecipeId == "copper_axe" and fixed.ItemID == 102 and fixed.WeaponKind == "Axe")
check("reject output with no weapon kind", rules.ResolveFixedOutput({ Id = "bad", OutputItemID = 102 }) == nil)
check("reject missing output", rules.ResolveFixedOutput({ Id = "bad", WeaponKind = "Axe" }) == nil)
check("reject fractional output ID", rules.ResolveFixedOutput({ Id = "bad", OutputItemID = 102.5, WeaponKind = "Axe" }) == nil)
check("reject invalid recipe ID", rules.ResolveFixedOutput({ Id = "", OutputItemID = 102, WeaponKind = "Axe" }) == nil)

print("WeaponRecipeRules manual smoke checks passed")
return true
