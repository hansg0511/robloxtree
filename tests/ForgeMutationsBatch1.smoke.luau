-- Phase 2 Batch 1 pure/server-effects smoke tests.
-- Execute in Roblox Studio PLAY -> SERVER Command Bar with synced Rojo code.
-- Synthetic weapons/trees only: no player currency or inventory changed.
local Forge = require(game.ReplicatedStorage.Shared.ForgeMutationRules)
local Experimental = require(game.ReplicatedStorage.Shared.ExperimentalForgeRules)
local Mutations = require(game.ServerScriptService.Grove.MutationDefinitions)
local Effects = require(game.ServerScriptService.WeaponEffects.Dispatcher)
local Fervor = require(game.ServerScriptService.WeaponEffects.Fervor)
local Thunderstrike = require(game.ServerScriptService.WeaponEffects.Thunderstrike)

local function check(label, condition)
	assert(condition, "[ForgeMutations] " .. label)
end
local function near(a, b)
	return math.abs(a - b) < 0.000001
end
local function log(size, mutations)
	return { SpeciesId = "Oak", SizeScale = size, Mutations = mutations or {} }
end

check("both initial forge tiers exist", Forge.Tier(1) and Forge.Tier(2))
check("tier 3 unavailable", Forge.Tier(3) == nil)
check("tier shift is independent from mutation class", Forge.ClassCount(5,1) == 5
	and Forge.ClassCount(5,2) == 3)
check("tier 1 class odds unchanged", near(Experimental.Odds(5).Axe, 0.65))
check("tier 2 has more dagger chance at the same count",
	Experimental.Odds(5,2).Dagger > Experimental.Odds(5,1).Dagger)
check("tier 2 odds still sum to 1", near(
	Experimental.Odds(20,2).Dagger + Experimental.Odds(20,2).Axe
		+ Experimental.Odds(20,2).Battlehammer, 1))

local unmutated = Forge.Preview({log(5),log(5)},1)
check("ordinary wood never grants a mutation", unmutated
	and unmutated.Family == nil and unmutated.Potency == 0
	and Forge.Roll(unmutated,1,Random.new()) == nil)
local golden = Forge.Preview({log(5,{Golden=true})},1)
check("one perfect Golden log cannot max potency",
	golden and golden.Family == "Golden" and near(golden.Potency, 0.22)
		and golden.Potency < golden.PotencyCap)
local withOrdinary = Forge.Preview({log(5,{Golden=true}),log(5),log(5)},1)
check("ordinary logs do not dilute mutation potency",
	near(withOrdinary.Potency,golden.Potency))
local capped = Forge.Preview({
	log(5,{Golden=true}),log(5,{Golden=true}),log(5,{Golden=true}),
	log(5,{Golden=true}),
},1)
check("cap and explicit wasted potency", capped.Potency == Forge.Tier(1).PotencyCap
	and capped.WastedPotency > 0)
local higher = Forge.Preview({
	log(5,{Golden=true}),log(5,{Golden=true}),
	log(5,{Golden=true}),log(5,{Golden=true}),
},2)
check("higher tier unlocks more cumulative potency",
	higher.Potency > capped.Potency and higher.Potency == Forge.Tier(2).PotencyCap)
local mixed = Forge.Preview({log(2,{Golden=true}),log(4,{Frenzied=true})},1)
check("mixed ability mutation families rejected before consumption",
	mixed.InvalidReason == "MIXED_MUTATION_FAMILIES")
local giantGolden = Forge.Preview({log(5,{Golden=true,Giant=true})},1)
check("Giant is size genetics, not a separate weapon ability",
	giantGolden.Family == "Golden")
local oldCrystal = Forge.Preview({log(5,{Crystal=true})},1)
check("legacy Crystal grants no new ability", oldCrystal.Family == nil)
check("old Crystal stays in save copy while not naturally rolled",
	Mutations.CopyKnown({Crystal=true}).Crystal == true
	and not table.find(Mutations.OrderedIds,"Crystal")
	and table.find(Mutations.OrderedIds,"Frenzied")
	and table.find(Mutations.OrderedIds,"Shocked"))

local function rolled(family)
	local preview = Forge.Preview({log(5,{[family]=true})},1)
	local ability = Forge.Roll(preview,1,Random.new(517))
	check(family .. " gives one validated effect", ability ~= nil
		and ability.Family == family and ability.Effect.Source == "WoodMutation")
	local effects = Effects.List({ Effects = {ability.Effect} })
	check(family .. " accepted by registered server dispatcher",
		#effects == 1 and effects[1].Id == ability.Id)
	return ability, effects[1].Params
end
local gold, goldParams = rolled("Golden")
check("Golden Touch selected", gold.Id == "GoldenTouch")
local frenzy, frenzyParams = rolled("Frenzied")
check("Fervor selected", frenzy.Id == "Fervor")
local shock, shockParams = rolled("Shocked")
check("Thunderstrike selected", shock.Id == "Thunderstrike")

-- Confirm Golden Touch only pays out when the authoritative kill flag is true.
local paid = 0
local payout = function(amount) paid += amount end
local gilded = { Effects = {gold.Effect} }
Effects.ApplyTrigger("OnKill", gilded,
	{ Killed = false, TreeCoinBase = 100, AwardCoins = payout })
check("hit without kill never pays", paid == 0)
Effects.ApplyTrigger("OnKill", gilded,
	{ Killed = true, TreeCoinBase = 100, AwardCoins = payout })
check("confirmed kill pays expected capped coins",
	paid == math.floor(100 * goldParams.CoinFraction + 0.5))

-- Server Fervor timing: first hit no speed boost; repeated same-tree
-- hits progress, different targets or expiry reset the effect.
local player = {}
local a, b = {}, {}
local uid = "synthetic-dagger"
local baseline = 0.5
check("no prior hits: baseline", Fervor.Interval(player,uid,a,1,baseline,frenzyParams) == baseline)
Fervor.RecordHit(player,uid,a,1,frenzyParams)
check("first hit does not grant a free instant stack",
	Fervor.Interval(player,uid,a,1.1,baseline,frenzyParams) == baseline)
Fervor.RecordHit(player,uid,a,1.5,frenzyParams)
check("second hit accelerates next server cooldown",
	Fervor.Interval(player,uid,a,1.6,baseline,frenzyParams) < baseline)
check("different tree resets populated combo",
	Fervor.Interval(player,uid,b,1.6,baseline,frenzyParams) == baseline)
check("different weapon resets populated combo",
	Fervor.Interval(player,"other",a,1.6,baseline,frenzyParams) == baseline)
check("hit combo expires while populated",
	Fervor.Interval(player,uid,a,20,baseline,frenzyParams) == baseline)
Fervor.OnWeaponEquipped(player, uid, uid)
check("same-UID re-equip preserves active combo",
	Fervor.Interval(player,uid,a,1.61,baseline,frenzyParams) < baseline)
Fervor.OnWeaponEquipped(player, uid, "other")
Fervor.OnWeaponEquipped(player, "other", uid)
check("switch away and back clears active combo",
	Fervor.Interval(player,uid,a,1.62,baseline,frenzyParams) == baseline)
Fervor.Clear(player)

-- Thunderstrike must proc repeatedly, every N real primary hits. It damages one eligible
-- secondary tree by HP-clamped amount, reports XP attribution, no recursion.
local primary = { CFrame=CFrame.new(0,0,0), CreationId=1, HP=100, MaxHP=100 }
local neighbor = { CFrame=CFrame.new(5,0,0), CreationId=2, HP=30, MaxHP=30 }
function neighbor:TakeDamage(ctx,_player)
	local applied = math.min(self.HP,math.floor(ctx.Damage or 0))
	if applied <= 0 then return false end
	self.HP -= applied
	return true,applied,self.HP == 0
end
local appliedHits={}
local context={
	Player=player, WeaponUID=uid, PrimarySucceeded=true,
	PrimaryTree=primary, PrimaryDamage=20,
	ActiveTrees={[primary]=true,[neighbor]=true},
	EligibleSecondary=function(_) return true end,
	OnAppliedHit=function(tree,applied,killed,maxHP)
		table.insert(appliedHits,{tree,applied,killed,maxHP})
	end,
}
-- Explicitly cover three FULL proc cycles, not merely the first strike.
-- Rebuild prepared state for every hit just like ChopHandler does.
local telemetry = {}
context.OnMutationTelemetry = function(id, state)
	if id == "Thunderstrike" then
		telemetry[#telemetry+1] = { Count=state.Count, Proc=state.Proc }
	end
end
local expected = math.floor(20*shockParams.DamageFraction)
for cycle=1,3 do
	for swing=1,shockParams.EveryHits do
		local prepared = Thunderstrike.Prepare(shockParams,context)
		check("fresh secondary target " .. cycle .. "/" .. swing,
			prepared and #prepared.Targets == 1 and prepared.Targets[1] == neighbor)
		local hits = Thunderstrike.Apply(prepared,context)
		check("proc only on the Nth hit for cycle " .. cycle .. "/" .. swing,
			hits == (if swing == shockParams.EveryHits then 1 else 0))
		local state = telemetry[#telemetry]
		check("counter advances and resets each cycle " .. cycle .. "/" .. swing,
			state.Count == swing and state.Proc == (swing == shockParams.EveryHits))
	end
	check("repeated secondary damage hits exactly once per proc",
		neighbor.HP == 30-expected*cycle and #appliedHits == cycle
		and appliedHits[cycle][1] == neighbor
		and appliedHits[cycle][2] == expected)
end
check("all N*3 primary strikes reported", #telemetry == shockParams.EveryHits * 3)
Thunderstrike.Clear(player)

print("ForgeMutations Batch 1: tier odds, potency, Golden Touch, Fervor and Thunderstrike 3-cycle repeated proc regression passed")
return true
