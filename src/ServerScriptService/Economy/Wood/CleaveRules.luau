-- Small, server-only Battlehammer passive prototype.
-- A normal chop selects exactly one primary tree. This module determines
-- whether an additional, capped secondary-impact effect should occur.
-- No client-supplied target, radius, damage, weapon class or mutation is trusted.
local Rules = {}

Rules.MAX_TARGETS = 2
Rules.MIN_RADIUS_STUDS = 2
Rules.MAX_RADIUS_STUDS = 24
Rules.MAX_VERTICAL_DELTA_STUDS = 12
Rules.MAX_DAMAGE_FRACTION = 0.75

local function finitePositive(value)
	return type(value) == "number" and value == value
		and value > 0 and value < math.huge
end

function Rules.Resolve(weaponData)
	if type(weaponData) ~= "table"
		or weaponData.ExperimentalClass ~= "Battlehammer" then return nil end
	local radius = weaponData.CleaveRadius
	local fraction = weaponData.CleaveDamageFraction
	if not finitePositive(radius) or not finitePositive(fraction) then return nil end
	return {
		Radius = math.clamp(radius, Rules.MIN_RADIUS_STUDS, Rules.MAX_RADIUS_STUDS),
		DamageFraction = math.clamp(fraction, 0, Rules.MAX_DAMAGE_FRACTION),
		MaxTargets = Rules.MAX_TARGETS,
	}
end

-- Collect first, then damage: killing the primary may synchronously delete it
-- from the live ActiveTrees registry. The effect must never chain recursively.
function Rules.FindSecondaryTargets(primary, activeTrees, profile, eligible)
	if type(primary) ~= "table" or typeof(primary.CFrame) ~= "CFrame"
		or type(activeTrees) ~= "table" or type(profile) ~= "table"
		or type(eligible) ~= "function" then return {} end
	local radius = profile.Radius
	if not finitePositive(radius) then return {} end
	radius = math.min(radius, Rules.MAX_RADIUS_STUDS)
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
				and math.abs(pos.Y - origin.Y) <= Rules.MAX_VERTICAL_DELTA_STUDS then
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
	local count = math.min(#candidates,
		math.clamp(math.floor(profile.MaxTargets or 0), 0, Rules.MAX_TARGETS))
	local result = {}
	for i = 1, count do
		result[i] = candidates[i].Tree
	end
	return result
end

function Rules.SecondaryDamage(primaryDamage, profile)
	if not finitePositive(primaryDamage) or type(profile) ~= "table"
		or not finitePositive(profile.DamageFraction) then return 0 end
	return math.max(0, math.floor(primaryDamage
		* math.clamp(profile.DamageFraction, 0, Rules.MAX_DAMAGE_FRACTION)))
end

return Rules
