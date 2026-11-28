-- Rampage: kills grant one refreshable, non-stacking damage buff.
-- Multiplier is read on a FUTURE primary swing, never retroactively on
-- the kill that granted it. Weapon switching clears the buff.
local Rampage = {}
Rampage.Id = "Rampage"
Rampage.Trigger = "OnKill"
local states=setmetatable({}, {__mode="k"})
local function finite(x)
	return type(x)=="number" and x==x and x>-math.huge and x<math.huge
end
function Rampage.Resolve(params)
	if type(params)~="table" or not finite(params.DamageMultiplier)
		or params.DamageMultiplier<1.05 or params.DamageMultiplier>1.8
		or not finite(params.DurationSeconds) or params.DurationSeconds<2
		or params.DurationSeconds>15 then return nil end
	return {DamageMultiplier=params.DamageMultiplier,DurationSeconds=params.DurationSeconds}
end
function Rampage.Prepare(params,context)
	local p=Rampage.Resolve(params)
	if not p or type(context)~="table" then return nil end
	return {Profile=p}
end
function Rampage.Apply(prepared,context)
	if type(prepared)~="table" or not prepared.Profile
		or type(context)~="table" or context.Killed~=true
		or not context.Player or type(context.WeaponUID)~="string" then return 0 end
	local now=if finite(context.Now) then context.Now else os.clock()
	local p=prepared.Profile
	states[context.Player]={UID=context.WeaponUID,At=now,
		Until=now+p.DurationSeconds,Multiplier=p.DamageMultiplier}
	if type(context.OnMutationProc)=="function" then
		context.OnMutationProc("Rampage",{
			Duration=p.DurationSeconds,Multiplier=p.DamageMultiplier})
	end
	return 0
end
function Rampage.Multiplier(player,uid,now)
	local state=states[player]
	if not state or state.UID~=uid or not finite(now) then return 1 end
	if now>=state.At and now<state.Until then return state.Multiplier end
	if now>=state.Until then states[player]=nil end
	return 1
end
function Rampage.Clear(player) states[player]=nil end
function Rampage.OnWeaponEquipped(player,previousUID,nextUID)
	if previousUID~=nextUID then Rampage.Clear(player) end
end
return Rampage
