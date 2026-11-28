-- Golden Jackpot: bounded server RNG payout on each confirmed tree kill.
-- No history and never rolls or pays on ordinary hits.
local GoldenJackpot = {}
GoldenJackpot.Id = "GoldenJackpot"
GoldenJackpot.Trigger = "OnKill"
local random = Random.new()
local function finite(x)
	return type(x)=="number" and x==x and x>-math.huge and x<math.huge
end
function GoldenJackpot.Resolve(params)
	if type(params)~="table" or not finite(params.Chance)
		or params.Chance<0.01 or params.Chance>0.5
		or not finite(params.PayoutMultiplier)
		or params.PayoutMultiplier<2 or params.PayoutMultiplier>10 then return nil end
	return {Chance=params.Chance,PayoutMultiplier=params.PayoutMultiplier}
end
function GoldenJackpot.ShouldProc(chance,roll)
	return finite(chance) and chance>0 and chance<=1
		and finite(roll) and roll>=0 and roll<1 and roll<chance
end
function GoldenJackpot.Prepare(params,context)
	local p=GoldenJackpot.Resolve(params)
	if not p or type(context)~="table" then return nil end
	return {Profile=p}
end
function GoldenJackpot.Apply(prepared,context)
	if type(prepared)~="table" or not prepared.Profile
		or type(context)~="table" or context.Killed~=true
		or type(context.AwardCoins)~="function" then return 0 end
	local base=context.TreeCoinBase
	if not finite(base) or base<=0 or base>100000 then return 0 end
	-- Synthetic server smoke tests may inject RandomUnit; production does not.
	local roll = if type(context.RandomUnit)=="function"
		then context.RandomUnit() else random:NextNumber()
	if not GoldenJackpot.ShouldProc(prepared.Profile.Chance,roll) then return 0 end
	local coins=math.clamp(math.floor(base*prepared.Profile.PayoutMultiplier+0.5),1,50000)
	context.AwardCoins(coins)
	if type(context.OnMutationProc)=="function" then
		context.OnMutationProc("GoldenJackpot",{Amount=coins})
	end
	return 0
end
return GoldenJackpot
