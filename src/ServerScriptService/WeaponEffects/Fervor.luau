-- Frenzied Fervor: server-owned consecutive hits against SAME tree speed up
-- subsequent swings. State is per-player, per-equipped weapon, and expires.
local Fervor = {}
Fervor.Id = "Fervor"
Fervor.Trigger = "OnHit"
local histories = setmetatable({}, { __mode = "k" })

local function finite(value)
	return type(value) == "number" and value == value
		and value > -math.huge and value < math.huge
end

function Fervor.Resolve(params)
	if type(params) ~= "table"
		or not finite(params.SpeedPerStack) or params.SpeedPerStack <= 0
		or params.SpeedPerStack > 0.3
		or not finite(params.WindowSeconds) or params.WindowSeconds < 1
		or params.WindowSeconds > 5
		or not finite(params.MaxStacks) or params.MaxStacks % 1 ~= 0
		or params.MaxStacks < 1 or params.MaxStacks > 8 then return nil end
	return {
		SpeedPerStack = params.SpeedPerStack,
		MaxStacks = params.MaxStacks,
		WindowSeconds = params.WindowSeconds,
	}
end

-- Fervor uses a trusted server cooldown rather than secondary-hit damage.
function Fervor.Prepare(_params, _context)
	return nil
end

function Fervor.Apply(_prepared, _context)
	return 0
end

function Fervor.Interval(player, uid, target, now, baseInterval, params)
	local config = Fervor.Resolve(params)
	if not config or not finite(baseInterval) or baseInterval <= 0
		or not finite(now) then return baseInterval end
	local state = histories[player]
	if not state or state.UID ~= uid or state.Tree ~= target
		or now - state.At > config.WindowSeconds then return baseInterval end
	local stacks = math.min(config.MaxStacks, math.max(0, state.Hits - 1))
	return baseInterval / (1 + stacks * config.SpeedPerStack)
end

function Fervor.RecordHit(player, uid, target, now, params)
	local config = Fervor.Resolve(params)
	if not config or not finite(now) then return 0 end
	local state = histories[player]
	local hits = if state and state.UID == uid and state.Tree == target
		and now - state.At <= config.WindowSeconds
		then math.min(config.MaxStacks + 1, state.Hits + 1) else 1
	histories[player] = { UID = uid, Tree = target, At = now, Hits = hits }
	return math.min(config.MaxStacks, math.max(0, hits - 1))
end

function Fervor.Clear(player)
	histories[player] = nil
end

-- Equipping a different weapon must start a fresh combo. Re-equipping the
-- same UID leaves its active combo intact; the caller invokes this only after
-- the server has completed a valid equip transaction.
function Fervor.OnWeaponEquipped(player, previousUID, nextUID)
	if previousUID ~= nextUID then
		histories[player] = nil
	end
end

return Fervor
