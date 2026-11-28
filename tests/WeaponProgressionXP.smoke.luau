-- Phase 1B pure XP + secondary-hit smoke tests. Paste into Roblox
-- Studio SERVER Command Bar during Play after Rojo synchronization.
-- Synthetic records only: no player inventory, actual trees, or economy
-- resources are modified.
local Rules = require(game.ServerScriptService.WeaponProgressionRules)
local Dispatcher = require(game.ServerScriptService.WeaponEffects.Dispatcher)

local function expect(message, condition)
	assert(condition, message)
end
local function close(x, y)
	return math.abs(x - y) < 0.00001
end

expect("No XP from zero damage", Rules.XPForAppliedHit(0, 60, true) == 0)
expect("No XP from overkill (raw damage not accepted)",
	Rules.XPForAppliedHit(200, 60, true) == 0)
expect("No XP from invalid HP", Rules.XPForAppliedHit(10, 0, true) == 0)
expect("No XP from NaN", Rules.XPForAppliedHit(0/0, 60, false) == 0)
expect("No XP from infinite damage", Rules.XPForAppliedHit(1/0, 60, false) == 0)
expect("No XP from an ineligible extreme-HP tree",
	Rules.XPForAppliedHit(10, Rules.MAX_TREE_HP_FOR_XP + 1, false) == 0)
expect("Applied damage yields XP", Rules.XPForAppliedHit(30, 60, false) == 30)
expect("Kill grants a difficulty-scaled bonus",
	Rules.XPForAppliedHit(30, 60, true) == 45)
expect("Weak bamboo awards less than a harder Oak for equivalent chop",
	Rules.XPForAppliedHit(18, 18, true) <
	Rules.XPForAppliedHit(60, 60, true))

local common = Rules.NewProgression()
local threshold = Rules.XPToNextLevel("Common", 1)
expect("First threshold exists", threshold == 125)
local before, noLevels = Rules.ApplyXP(common, "Common", threshold - 1)
expect("Under threshold does not level",
	noLevels == 0 and before.Level == 1 and before.XP == threshold - 1)
expect("ApplyXP leaves source untouched",
	common.Level == 1 and common.XP == 0)

local after, oneLevel = Rules.ApplyXP(before, "Common", 1)
expect("Exactly at threshold advances one level",
	oneLevel == 1 and after.Level == 2 and after.XP == 0)
local larger, multiLevels = Rules.ApplyXP(common, "Common", 1000)
expect("Large legitimate hit crosses multiple thresholds",
	multiLevels >= 2 and larger.Level > 2 and larger.Level <= Rules.GetLevelCap("Common"))
local cap = Rules.GetLevelCap("Common")
local maxed, gained = Rules.ApplyXP(common, "Common", 100000)
expect("Max level clamps and clears surplus XP",
	maxed.Level == cap and maxed.XP == 0 and gained == cap - 1)
local unchanged, none = Rules.ApplyXP(maxed, "Common", 1000)
expect("At cap there is no phantom XP banking",
	unchanged.Level == cap and unchanged.XP == 0 and none == 0)
expect("Max level has no next-level requirement",
	Rules.XPToNextLevel("Common", cap) == nil)

-- Test the real dispatcher/Cleave with a three-result TakeDamage:
-- success, actual applied damage, killed.
local function tree(id, x, hp)
	local obj = { CreationId = id, CFrame = CFrame.new(x,0,0), HP = hp, MaxHP = hp }
	function obj:TakeDamage(ctx, _player)
		local amount = math.min(self.HP, math.floor(ctx.Damage or 0))
		if amount <= 0 then return false end
		self.HP -= amount
		return true, amount, self.HP == 0
	end
	return obj
end
local primary = tree(1, 0, 60)
local second = tree(2, 4, 12) -- should cap 40 simulated Cleave damage to 12
local third = tree(3, 6, 50)
local registry = { [primary]=true, [second]=true, [third]=true }
local recorded = {}
local ctx = {
	Player = "synthetic-player", PrimaryTree = primary,
	ActiveTrees = registry, PrimaryDamage = 100,
	EligibleSecondary = function(_) return true end,
	OnAppliedHit = function(target, actual, killed)
		table.insert(recorded, { Target = target, Actual = actual, Killed = killed })
	end,
}
local weaponData = { Effects = { { Id = "Cleave",
	Trigger = "OnHit", Source = "WeaponClass",
	Params = { Radius = 10, DamageFraction = 0.4 } } } }
local prepared = Dispatcher.Prepare("OnHit", weaponData, ctx)
expect("Secondary target preparation succeeds", #prepared == 1)
registry[primary] = nil -- primary may die/unregister before secondary
expect("Secondary targets take confirmed hits",
	Dispatcher.ApplyPrepared(prepared, ctx) == 2)
expect("Each actual Cleave hit reported once",
	#recorded == 2 and recorded[1].Target == second
	and recorded[1].Actual == 12 and recorded[1].Killed
	and recorded[2].Target == third and recorded[2].Actual == 40
	and not recorded[2].Killed)
local total = 0
for _, r in ipairs(recorded) do
	total += Rules.XPForAppliedHit(r.Actual, r.Target.MaxHP, r.Killed)
end
expect("Cleave XP uses HP-clamped secondary damage",
	total == Rules.XPForAppliedHit(12,12,true)
		+ Rules.XPForAppliedHit(40,50,false))
expect("Secondary effects do not hit again",
	second.HP == 0 and third.HP == 10)
expect("Cleave does not change primary HP", close(primary.HP, 60))

print("Weapon XP: thresholds, level caps, overkill, kill bonuses, and Cleave attribution passed")
return true
