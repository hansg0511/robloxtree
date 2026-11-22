-- Bloodrush: kill grants a refreshable, non-stacking temporary
-- movement-speed bonus. Restores baseline after expiry/equip switch;
-- does NOT override speed later changed by another movement controller.
local Bloodrush = {}
Bloodrush.Id = "Bloodrush"
Bloodrush.Trigger = "OnKill"
local states=setmetatable({}, {__mode="k"})
local MAX_SPEED=50
local function finite(x)
	return type(x)=="number" and x==x and x>-math.huge and x<math.huge
end
function Bloodrush.Resolve(params)
	if type(params)~="table" or not finite(params.SpeedMultiplier)
		or params.SpeedMultiplier<1.05 or params.SpeedMultiplier>1.5
		or not finite(params.DurationSeconds) or params.DurationSeconds<2
		or params.DurationSeconds>15 then return nil end
	return {SpeedMultiplier=params.SpeedMultiplier,DurationSeconds=params.DurationSeconds}
end
function Bloodrush.Speed(base,multiplier)
	if not finite(base) or base<0 or base>100
		or not finite(multiplier) or multiplier<1 or multiplier>1.5 then return nil end
	return math.min(MAX_SPEED,base*multiplier)
end
local function restore(state)
	if not state then return end
	local humanoid=state.Humanoid
	if typeof(humanoid)=="Instance" and humanoid:IsA("Humanoid")
		and humanoid.Parent and finite(humanoid.WalkSpeed)
		and math.abs(humanoid.WalkSpeed-state.Applied)<0.01 then
		humanoid.WalkSpeed=state.Baseline
	end
end
function Bloodrush.Clear(player)
	restore(states[player])
	states[player]=nil
end
function Bloodrush.OnWeaponEquipped(player,previousUID,nextUID)
	if previousUID~=nextUID then Bloodrush.Clear(player) end
end
function Bloodrush.Prepare(params,context)
	local p=Bloodrush.Resolve(params)
	if not p or type(context)~="table" then return nil end
	return {Profile=p}
end
function Bloodrush.Apply(prepared,context)
	if type(prepared)~="table" or not prepared.Profile
		or type(context)~="table" or context.Killed~=true
		or not context.Player or type(context.WeaponUID)~="string" then return 0 end
	local humanoid=context.Humanoid
	if not humanoid then
		local character=context.Player.Character
		humanoid=character and character:FindFirstChildOfClass("Humanoid")
	end
	if typeof(humanoid)~="Instance" or not humanoid:IsA("Humanoid")
		or humanoid.Health<=0 or not humanoid.Parent then return 0 end
	local previous=states[context.Player]
	local baseline
	if previous and previous.UID==context.WeaponUID
		and previous.Humanoid==humanoid
		and math.abs(humanoid.WalkSpeed-previous.Applied)<0.01 then
		baseline=previous.Baseline
	else
		Bloodrush.Clear(context.Player)
		baseline=humanoid.WalkSpeed
	end
	local p=prepared.Profile
	local speed=Bloodrush.Speed(baseline,p.SpeedMultiplier)
	if not speed then return 0 end
	humanoid.WalkSpeed=speed
	local token=if previous then previous.Token+1 else 1
	local state={UID=context.WeaponUID,Humanoid=humanoid,Baseline=baseline,
		Applied=speed,Token=token}
	states[context.Player]=state
	-- Refresh extends duration; obsolete expiry callbacks cannot cancel it.
	if context.NoTimer~=true then
		task.delay(p.DurationSeconds,function()
			if states[context.Player]==state then Bloodrush.Clear(context.Player) end
		end)
	end
	if type(context.OnMutationProc)=="function" then
		context.OnMutationProc("Bloodrush",{Duration=p.DurationSeconds,Speed=speed})
	end
	return 0
end
return Bloodrush
