-- Mutated-wood Golden Touch. Award only when ChopHandler reports a
-- confirmed server-authoritative kill; never grants coins per ordinary hit.
local GoldenTouch = {}
GoldenTouch.Id = "GoldenTouch"
GoldenTouch.Trigger = "OnKill"

function GoldenTouch.Resolve(params)
	local fraction = type(params) == "table" and params.CoinFraction or nil
	if type(fraction) ~= "number" or fraction ~= fraction
		or fraction < 0.05 or fraction > 2 then return nil end
	return { CoinFraction = fraction }
end

function GoldenTouch.Prepare(params, context)
	local profile = GoldenTouch.Resolve(params)
	if not profile or type(context) ~= "table" then return nil end
	return { Profile = profile }
end

function GoldenTouch.Apply(prepared, context)
	if type(prepared) ~= "table" or not prepared.Profile
		or type(context) ~= "table" or context.Killed ~= true
		or type(context.AwardCoins) ~= "function" then return 0 end
	local base = context.TreeCoinBase
	if type(base) ~= "number" or base ~= base or base <= 0
		or base > 100000 then return 0 end
	local coins = math.clamp(
		math.floor(base * prepared.Profile.CoinFraction + 0.5), 1, 50000)
	context.AwardCoins(coins)
	return 0
end

return GoldenTouch
