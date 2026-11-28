-- Golden Rush: each real tree kill within a short window increases its
-- extra coin payout, capped at MaxStacks. Per-player/weapon server state.
local GoldenRush = {}
GoldenRush.Id = "GoldenRush"
GoldenRush.Trigger = "OnKill"
local histories = setmetatable({}, { __mode="k" })
local function finite(x)
	return type(x)=="number" and x==x and x>-math.huge and x<math.huge
end
function GoldenRush.Resolve(params)
	if type(params)~="table" or not finite(params.CoinFractionPerStack)
		or params.CoinFractionPerStack<=0 or params.CoinFractionPerStack>0.5
		or not finite(params.MaxStacks) or params.MaxStacks%1~=0
		or params.MaxStacks<1 or params.MaxStacks>6
		or not finite(params.WindowSeconds) or params.WindowSeconds<2
		or params.WindowSeconds>15 then return nil end
	return {CoinFractionPerStack=params.CoinFractionPerStack,
		MaxStacks=params.MaxStacks,WindowSeconds=params.WindowSeconds}
end
function GoldenRush.Prepare(params,context)
	local p = GoldenRush.Resolve(params)
	if not p or type(context)~="table" then return nil end
	return {Profile=p}
end
function GoldenRush.Apply(prepared,context)
	if type(prepared)~="table" or not prepared.Profile
		or type(context)~="table" or context.Killed~=true
		or not context.Player or type(context.WeaponUID)~="string"
		or type(context.AwardCoins)~="function" then return 0 end
	local base = context.TreeCoinBase
	if not finite(base) or base<=0 or base>100000 then return 0 end
	local now = if finite(context.Now) then context.Now else os.clock()
	local p = prepared.Profile
	local previous = histories[context.Player]
	local stacks = if previous and previous.UID==context.WeaponUID
		and now<=previous.Until and now>=previous.At
		then math.min(p.MaxStacks,previous.Stacks+1) else 1
	histories[context.Player] = {
		UID=context.WeaponUID,Stacks=stacks,At=now,Until=now+p.WindowSeconds,
	}
	local coins = math.clamp(math.floor(base*p.CoinFractionPerStack*stacks+0.5),1,50000)
	context.AwardCoins(coins)
	if type(context.OnMutationProc)=="function" then
		context.OnMutationProc("GoldenRush",{Amount=coins,Stacks=stacks,MaxStacks=p.MaxStacks})
	end
	return 0
end
function GoldenRush.Clear(player) histories[player]=nil end
function GoldenRush.OnWeaponEquipped(player,previousUID,nextUID)
	if previousUID~=nextUID then GoldenRush.Clear(player) end
end
return GoldenRush
