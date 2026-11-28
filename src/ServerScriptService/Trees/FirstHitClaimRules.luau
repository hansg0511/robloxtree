-- Pure first-hit ownership rules for shared wild trees.
-- Claims expire after a short interval of no *successful* damage.
-- All mutation/class AoE targets use the same server TreeObject gate.
local Rules = {}
Rules.CLAIM_IDLE_SECONDS = 5 -- initial playtest tuning value

local function validTime(x)
	return type(x) == "number" and x == x
		and x >= 0 and x < math.huge
end

-- Studio multiplayer test clients may use negative or zero UserIds;
-- identity is validated as a real Player by TreeObject before invoking us.
local function validUserId(x)
	return type(x) == "number" and x == x and x % 1 == 0
		and x > -math.huge and x < math.huge
end

function Rules.IsActive(ownerUserId, lastDamageAt, now)
	return validUserId(ownerUserId) and validTime(lastDamageAt)
		and validTime(now) and now >= lastDamageAt
		and now - lastDamageAt < Rules.CLAIM_IDLE_SECONDS
end

function Rules.CanHit(ownerUserId, lastDamageAt, attackerUserId, now)
	if not validUserId(attackerUserId) or not validTime(now) then return false end
	return not Rules.IsActive(ownerUserId, lastDamageAt, now)
		or ownerUserId == attackerUserId
end

return Rules
