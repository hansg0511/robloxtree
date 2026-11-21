-- Server-only Cleave effect behavior. It knows nothing about whether
-- Cleave came from a weapon class, a wood mutation, or a player ability.
-- All game-facing targets and effect values are independently server-checked.
local Cleave = {}

Cleave.Id = "Cleave"
Cleave.Trigger = "OnHit"
Cleave.MAX_TARGETS = 2
Cleave.MIN_RADIUS_STUDS = 2
Cleave.MAX_RADIUS_STUDS = 24
Cleave.MAX_VERTICAL_DELTA_STUDS = 12
Cleave.MAX_DAMAGE_FRACTION = 0.75

local function finitePositive(value)
	return type(value) == "number" and value == value
		and value > 0 and value < math.huge
end

function Cleave.Resolve(params)
	if type(params) ~= "table" then return nil end
	if not finitePositive(params.Radius)
		or not finitePositive(params.DamageFraction) then return nil end
	return {
		Radius = math.clamp(params.Radius,
			Cleave.MIN_RADIUS_STUDS, Cleave.MAX_RADIUS_STUDS),
		DamageFraction = math.clamp(params.DamageFraction,
			0, Cleave.MAX_DAMAGE_FRACTION),
		-- The effect module, not weapon data, owns the current target cap.
		MaxTargets = Cleave.MAX_TARGETS,
	}
end

function Cleave.FindSecondaryTargets(primary, activeTrees, profile, eligible)
	if type(primary) ~= "table" or typeof(primary.CFrame) ~= "CFrame"
		or type(activeTrees) ~= "table" or type(profile) ~= "table"
		or type(eligible) ~= "function" then return {} end
	local radius = profile.Radius
	if not finitePositive(radius) then return {} end
	radius = math.min(radius, Cleave.MAX_RADIUS_STUDS)
	local origin = primary.CFrame.Position
	local candidates = {}
	for tree in pairs(activeTrees) do
		if tree ~= primary and type(tree) == "table"
			and typeof(tree.CFrame) == "CFrame"
			and eligible(tree) then
			local pos = tree.CFrame.Position
			local dx, dz = pos.X - origin.X, pos.Z - origin.Z
			local distanceSquared = dx * dx + dz * dz
			if distanceSquared <= radius * radius
				and math.abs(pos.Y - origin.Y) <= Cleave.MAX_VERTICAL_DELTA_STUDS then
				candidates[#candidates + 1] = {
					Tree = tree,
					DistanceSquared = distanceSquared,
					CreationId = type(tree.CreationId) == "number"
						and tree.CreationId or math.huge,
				}
			end
		end
	end
	table.sort(candidates, function(a, b)
		if a.DistanceSquared ~= b.DistanceSquared then
			return a.DistanceSquared < b.DistanceSquared
		end
		return a.CreationId < b.CreationId
	end)
	local limit = math.min(#candidates,
		math.clamp(math.floor(profile.MaxTargets or 0), 0, Cleave.MAX_TARGETS))
	local targets = {}
	for i = 1, limit do
		targets[i] = candidates[i].Tree
	end
	return targets
end

function Cleave.SecondaryDamage(primaryDamage, profile)
	if not finitePositive(primaryDamage) or type(profile) ~= "table"
		or not finitePositive(profile.DamageFraction) then return 0 end
	return math.max(0, math.floor(primaryDamage *
		math.clamp(profile.DamageFraction, 0, Cleave.MAX_DAMAGE_FRACTION)))
end

function Cleave.Prepare(params, context)
	if type(context) ~= "table" then return nil end
	local profile = Cleave.Resolve(params)
	if not profile then return nil end
	return {
		Profile = profile,
		-- Prepare BEFORE the primary hit: the tree may die and be removed
		-- from ActiveTrees during TakeDamage. Nothing is damaged here.
		Targets = Cleave.FindSecondaryTargets(context.PrimaryTree,
			context.ActiveTrees, profile, context.EligibleSecondary),
	}
end

function Cleave.Apply(prepared, context)
	if type(prepared) ~= "table" or type(context) ~= "table"
		or type(context.ActiveTrees) ~= "table"
		or type(context.EligibleSecondary) ~= "function" then return 0 end
	local damage = Cleave.SecondaryDamage(context.PrimaryDamage, prepared.Profile)
	if damage < 1 then return 0 end
	local hits = 0
	for _, tree in ipairs(prepared.Targets or {}) do
		-- Check again after the primary hit. A killed/despawned tree, a
		-- now-ineligible target, or a protected Grove tree cannot be hit.
		if hits < Cleave.MAX_TARGETS and context.ActiveTrees[tree] == true
			and context.EligibleSecondary(tree)
			and type(tree.TakeDamage) == "function" then
			if tree:TakeDamage({
				Damage = damage,
				IsCrit = false,
				-- Mark secondary damage for the Studio-only diagnostic popup.
				EffectId = "Cleave",
			}, context.Player) then
				hits += 1
			end
		end
	end
	return hits
end

return Cleave
