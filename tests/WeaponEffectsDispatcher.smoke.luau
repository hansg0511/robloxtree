-- Studio SERVER Command Bar during Play, or a Luau test harness with
-- ServerScriptService mounted. Uses synthetic records; no real trees touched.
local Dispatcher = require(game.ServerScriptService.WeaponEffects.Dispatcher)
local Cleave = require(game.ServerScriptService.WeaponEffects.Cleave)

local function close(a, b)
	return math.abs(a - b) < 0.00001
end
local function tree(id, x, z, allowed)
	local result = {
		CreationId = id,
		CFrame = CFrame.new(x, 0, z),
		Allowed = allowed ~= false,
		HP = 200,
	}
	function result:TakeDamage(ctx, _player)
		if ctx.Damage < 1 or self.HP <= 0 then return false end
		self.HP = math.max(0, self.HP - ctx.Damage)
		return true
	end
	return result
end
local primary = tree(1, 0, 0)
local targetA = tree(2, 2, 0)
local targetB = tree(3, 4, 0)
local targetC = tree(4, 6, 0)
local protected = tree(5, 1, 0, false)
local registry = {
	[primary] = true,
	[targetA] = true,
	[targetB] = true,
	[targetC] = true,
	[protected] = true,
}
local context = {
	Player = "TestPlayer",
	PrimaryTree = primary,
	ActiveTrees = registry,
	PrimaryDamage = 100,
	EligibleSecondary = function(candidate)
		return candidate.Allowed == true
	end,
}
local sourceMutationWeapon = {
	ExperimentalClass = "Dagger",
	Effects = {
		{
			Id = "Cleave",
			Trigger = "OnHit",
			Source = "Mutation",
			Params = { Radius = 10, DamageFraction = 0.4 },
		},
	},
}

local list = Dispatcher.List(sourceMutationWeapon)
assert(#list == 1 and list[1].Id == "Cleave"
	and list[1].Source == "Mutation" and list[1].Trigger == "OnHit",
	"Same Cleave effect is valid from a mutation on a Dagger")
assert(close(list[1].Params.DamageFraction, 0.4)
	and list[1].Params.MaxTargets == Cleave.MAX_TARGETS,
	"Effect-specific rules validate and cap stored parameters")

local planned = Dispatcher.Prepare("OnHit", sourceMutationWeapon, context)
assert(#planned == 1 and #planned[1].State.Targets == 2,
	"Dispatcher prepares at most two eligible nearby trees")
assert(targetA.HP == 200 and targetB.HP == 200,
	"Prepare is side-effect free")
-- Simulate primary tree dying/unregistering during its normal hit.
registry[primary] = nil
assert(Dispatcher.ApplyPrepared(planned, context) == 2,
	"Successful primary hit activates prepared effect")
assert(targetA.HP == 160 and targetB.HP == 160
	and targetC.HP == 200 and protected.HP == 200,
	"Two secondaries get 40 damage; denied/extra trees untouched")

assert(#Dispatcher.Prepare("OnKill", sourceMutationWeapon, context) == 0,
	"OnHit effects are not triggered by other events")
assert(#Dispatcher.List({ Effects = {
	{ Id = "UnknownEffect", Trigger = "OnHit", Params = {} },
	{ Id = "Cleave", Trigger = "OnKill",
		Params = { Radius = 10, DamageFraction = 0.4 } },
} }) == 0, "Unknown IDs and mismatched triggers are ignored")

assert(#Dispatcher.List({ Effects = {
	{ Id = "Cleave", Trigger = "OnHit",
		Params = { Radius = 10, DamageFraction = 0.4 } },
	{ Id = "Cleave", Trigger = "OnHit",
		Params = { Radius = 20, DamageFraction = 0.5 } },
} }) == 1, "Duplicate effect IDs cannot silently stack")

local legacyHammer = { ExperimentalClass = "Battlehammer",
	CleaveRadius = 10, CleaveDamageFraction = 0.4 }
assert(#Dispatcher.List(legacyHammer) == 1
	and Dispatcher.List(legacyHammer)[1].Source == "LegacyWeaponClass",
	"Existing hammers with old fields still work")
assert(#Dispatcher.List({ ExperimentalClass = "Dagger",
	CleaveRadius = 10, CleaveDamageFraction = 0.4 }) == 0,
	"Legacy fallback remains restricted to old hammer records")
assert(#Dispatcher.List({ ExperimentalClass = "Battlehammer",
	CleaveRadius = 10, CleaveDamageFraction = 0.4,
	Effects = {} }) == 0,
	"Explicit empty canonical effects list takes precedence over legacy fields")
assert(#Dispatcher.List({ Effects = {
	{ Id = "Cleave", Trigger = "OnHit",
		Params = { Radius = 0 / 0, DamageFraction = 0.4 } },
} }) == 0, "Malformed numeric metadata fails closed")

local sourceClassWeapon = {
	ExperimentalClass = "Battlehammer",
	Effects = {
		{ Id = "Cleave", Trigger = "OnHit", Source = "WeaponClass",
			Params = { Radius = 10, DamageFraction = 0.4 } },
	},
}
assert(#Dispatcher.List(sourceClassWeapon) == 1
	and Dispatcher.List(sourceClassWeapon)[1].Source == "WeaponClass",
	"Forge class grant uses the same handler and dispatcher as mutation grant")

print("WeaponEffects: independent source, trigger, no chaining, caps, legacy and safety passed")
return true
