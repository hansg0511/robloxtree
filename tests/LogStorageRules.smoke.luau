-- Paste into Roblox Studio's SERVER Command Bar after Rojo sync.
-- This file is outside the Rojo project and does not run automatically.
local rules = require(game.ServerScriptService.Inventory.LogStorageRules)

local function check(name, ok)
	assert(ok, name .. " failed")
end

local empty = {}
local settings = rules.NormalizeSettings(empty)
check("default mutated protection", settings.Mutations == true)
check("default large protection", settings.Oversized == true)
check("default threshold", settings.SizeThreshold == 1.5)
check("ordinary log stays in bag", not rules.ShouldStore({ SizeScale = 1, Mutations = {} }, settings))
check("large log auto-saved", rules.ShouldStore({ SizeScale = 1.6, Mutations = {} }, settings))
check("mutation auto-saved", rules.ShouldStore({ SizeScale = 0.8, Mutations = { Golden = true } }, settings))
check("false mutation not saved", not rules.ShouldStore({ SizeScale = 1, Mutations = { Golden = false } }, settings))
check("size exactly at threshold", rules.ShouldStore({ SizeScale = 1.5 }, settings))
check("inherited size fallback", rules.SizeScale({}) == 1)
check("invalid size fallback", rules.SizeScale({ SizeScale = math.huge }) == 1)
local noFilter = rules.NormalizeSettings({
	AutoKeep = { Mutations = false, Oversized = false, SizeThreshold = 2.0 },
})
check("both disabled", not rules.ShouldStore({ Mutations = { Golden = true }, SizeScale = 2.6 }, noFilter))
check("no setting erased", noFilter.Mutations == false and noFilter.SizeThreshold == 2.0)
local bad = rules.NormalizeSettings({ AutoKeep = { Mutations = "yes", Oversized = 1, SizeThreshold = 99 } })
check("malformed settings normalize", bad.Mutations == true and bad.Oversized == true and bad.SizeThreshold == 1.5)
print("LogStorageRules smoke checks passed")
return true
