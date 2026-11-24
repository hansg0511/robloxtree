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
check("forge levels 3–20 available", Forge.Tier(3) and Forge.Tier(20) and Forge.Tier(21) == nil)
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
	golden and golden.Family == "Golden" and near(golden.Potency, 0.15)
		and golden.Potency < golden.PotencyCap)
local withOrdinary = Forge.Preview({log(5,{Golden=true}),log(5),log(5)},1)
check("ordinary logs do not dilute mutation potency",
	near(withOrdinary.Potency,golden.Potency))
local three = {log(5,{Golden=true}),log(5,{Golden=true}),log(5,{Golden=true})}
local capped = Forge.Preview(three,1)
check("cap and explicit wasted potency", capped.Potency == Forge.Tier(1).PotencyCap
	and capped.WastedPotency > 0)
local higher = Forge.Preview(three,2)
check("higher tier extracts more potency", higher.Potency > capped.Potency and near(higher.Potency, 0.45))
local four = table.clone(three)
table.insert(four, log(5,{Golden=true}))
check("three mutated log limit enforced", Forge.Preview(four,2).InvalidReason == "TOO_MANY_MUTATED_LOGS")
check("level 5 permits fourth mutated log", near(Forge.Preview(four,5).Potency,0.60))
local iron = Forge.Preview({{SpeciesId="Ironwood",SizeScale=5,Mutations={Golden=true}}},1)
check("species affects same-size potency", near(iron.Potency,0.22) and iron.Potency > golden.Potency)
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

-- Thunderstrike is a same-target bonus on EVERY Nth confirmed hit.
-- Three complete cycles must damage only the primary, never its neighbor.
-- Bonus is combined into ONE HP-clamped primary hit; no duplicate XP.
local primary = { CFrame=CFrame.new(0,0,0), CreationId=1, HP=1500, MaxHP=1500 }
local neighbor = { CFrame=CFrame.new(5,0,0), CreationId=2, HP=30, MaxHP=30 }
local neighborHitCount = 0
function neighbor:TakeDamage(_ctx, _player)
	neighborHitCount += 1
	return true, 1, false
end
local context = {
	Player=player, WeaponUID=uid, PrimaryTree=primary,
	PrimaryDamage=20, PrimarySucceeded=false, PrimaryAppliedDamage=0,
	-- These are deliberately present; Thunderstrike should NEVER use them.
	ActiveTrees={[primary]=true, [neighbor]=true},
	EligibleSecondary=function(_) return true end,
}
local telemetry = {}
context.OnMutationTelemetry = function(id, state)
	telemetry[#telemetry+1] = {
		Id=id, Count=state.Count, Proc=state.Proc,
		Outcome=state.Outcome, Damage=state.Damage,
	}
end
local expectedBonus = Thunderstrike.BonusDamage(20,shockParams)
check("positive, bounded same-target bonus",expectedBonus>=1)
local startingHP = primary.HP
local attributedHP = 0
for cycle=1,3 do
	for swing=1,shockParams.EveryHits do
		local prepared = Thunderstrike.Prepare(shockParams,context)
		local shouldProc = swing == shockParams.EveryHits
		check("proc prepared only on Nth hit for cycle "..cycle.."/"..swing,
			prepared ~= nil and prepared.WillProc == shouldProc)
		check("only primary damage increases on proc "..cycle.."/"..swing,
			prepared.BonusDamage == (if shouldProc then expectedBonus else 0))
		-- Simulate ONE server TakeDamage, exactly as ChopHandler composes.
		local attempted = context.PrimaryDamage + prepared.BonusDamage
		local applied = math.min(primary.HP, attempted)
		primary.HP -= applied
		context.PrimarySucceeded = true
		context.PrimaryAppliedDamage = applied
		context.PrimaryKilled = primary.HP == 0
		attributedHP += applied
		check("Thunderstrike adds zero secondary hits",Thunderstrike.Apply(prepared,context)==0)
		-- Proc hits generate TWO telemetry records (counter then result).
		local state = telemetry[#telemetry - (if shouldProc then 1 else 0)]
		check("counter repeats each cycle "..cycle.."/"..swing,
			state.Id=="Thunderstrike" and state.Count==swing
			and state.Proc==shouldProc)
		if shouldProc then
			local procResult = telemetry[#telemetry]
			check("same-target bonus results in one verified proc",
				procResult.Id=="ThunderstrikeResult"
				and procResult.Outcome=="HIT"
				and procResult.Damage==expectedBonus)
		end
	end
end
check("three full Thunderstrike cycles completed",primary.HP ==
	startingHP - 20*shockParams.EveryHits*3 - expectedBonus*3)
check("no adjacent tree damage ever",neighbor.HP==30 and neighborHitCount==0)
check("primary HP removed attributed once",attributedHP == startingHP-primary.HP)
Thunderstrike.Clear(player)

-- Unsuccessful primary strikes cannot advance the N-hit counter.
local attempted = Thunderstrike.Prepare(shockParams,context)
context.PrimarySucceeded = false
context.PrimaryAppliedDamage = 0
check("miss never applies proc", Thunderstrike.Apply(attempted,context)==0)
local retry = Thunderstrike.Prepare(shockParams,context)
check("miss does not consume counter", retry.NextCount==attempted.NextCount)
Thunderstrike.Clear(player)

-- Lethal regression: even when this SAME PRIMARY model is destroyed by the
-- combined proc hit, lightning must flash at its last known position.
local lethalModel = Instance.new("Model")
lethalModel.Name = "TransientThunderTestTree"
lethalModel.Parent = workspace
local lethal = {
	CFrame=CFrame.new(400,0,0), CreationId=100,
	MaxHP=2000, HP=2000, model=lethalModel,
}
local lethalContext = {
	Player=player, WeaponUID="lethal-primary-visual-regression",
	PrimaryTree=lethal, PrimaryDamage=100,
	PrimarySucceeded=false, PrimaryAppliedDamage=0,
}
local hitCount = 0
local bonus = Thunderstrike.BonusDamage(100,shockParams)
for swing=1,shockParams.EveryHits do
	-- Force the LAST swing into a scenario where regular 100 damage would
	-- survive, but its Thunderstrike bonus kills the primary.
	if swing == shockParams.EveryHits then lethal.HP = 100 + math.max(1,bonus-1) end
	local state = Thunderstrike.Prepare(shockParams,lethalContext)
	local attemptedDamage = lethalContext.PrimaryDamage + state.BonusDamage
	local applied = math.min(lethal.HP, attemptedDamage)
	lethal.HP -= applied
	hitCount += 1
	lethalContext.PrimaryAppliedDamage = applied
	lethalContext.PrimarySucceeded = true
	lethalContext.PrimaryKilled = lethal.HP==0
	if lethal.HP==0 then lethalModel:Destroy() end
	check("lethal primary proc emits no second hit",
		Thunderstrike.Apply(state,lethalContext)==0)
	if swing==shockParams.EveryHits then
		check("same-target bonus killed primary where normal swing would not",
			applied > 100 and lethal.HP==0 and lethalContext.PrimaryKilled)
	end
end
check("all lethal simulation primary strikes processed",hitCount==shockParams.EveryHits)
local flash = workspace:FindFirstChild("ThunderstrikeFlash")
check("lethal same-target Thunderstrike shows lightning after tree removal",
	flash and flash:IsA("Part")
	and (flash.Position - Vector3.new(400,10,0)).Magnitude < 0.1)
if flash then flash:Destroy() end
Thunderstrike.Clear(player)

print("ForgeMutations Batch 1: tier odds, potency, Golden Touch, Fervor, repeated same-target Thunderstrike and lethal FX passed")
return true
