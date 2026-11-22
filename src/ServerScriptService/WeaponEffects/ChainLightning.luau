-- Chain Lightning: independent from single-target Thunderstrike and
-- simultaneous class Cleave. Each server-verified proc jumps sequentially
-- from the current tree to the closest eligible NEW tree, then from there,
-- with bounded range, jump count and diminishing damage.
local Debris = game:GetService("Debris")
local ChainLightning = {}
ChainLightning.Id="ChainLightning"
ChainLightning.Trigger="OnHit"
local random=Random.new()
local MAX_VERTICAL_DELTA=12
local function finite(x)
	return type(x)=="number" and x==x and x>-math.huge and x<math.huge
end
function ChainLightning.Resolve(params)
	if type(params)~="table" or not finite(params.Chance)
		or params.Chance<0.05 or params.Chance>0.6
		or not finite(params.DamageFraction) or params.DamageFraction<0.1
		or params.DamageFraction>0.9
		or not finite(params.JumpFalloff) or params.JumpFalloff<0.3
		or params.JumpFalloff>0.9
		or not finite(params.MaxJumps) or params.MaxJumps%1~=0
		or params.MaxJumps<1 or params.MaxJumps>4
		or not finite(params.Radius) or params.Radius<4
		or params.Radius>24 then return nil end
	return {
		Chance=params.Chance,DamageFraction=params.DamageFraction,
		JumpFalloff=params.JumpFalloff,MaxJumps=params.MaxJumps,
		Radius=params.Radius,
	}
end
function ChainLightning.ShouldProc(chance,roll)
	return finite(chance) and chance>0 and chance<=1
		and finite(roll) and roll>=0 and roll<1 and roll<chance
end
-- A stable nearest-neighbor selection on the HORIZONTAL plane. Origin may
-- be a just-killed tree; its CFrame is immutable and safe to use.
function ChainLightning.NextTarget(origin, activeTrees, visited, profile, eligible)
	if type(origin)~="table" or typeof(origin.CFrame)~="CFrame"
		or type(activeTrees)~="table" or type(visited)~="table"
		or type(profile)~="table" or type(eligible)~="function"
		or not finite(profile.Radius) or profile.Radius<=0 then return nil end
	local center=origin.CFrame.Position
	local radius=math.min(24,profile.Radius)
	local best,bestDistance,bestId=nil,math.huge,math.huge
	for tree in pairs(activeTrees) do
		if tree~=origin and not visited[tree] and activeTrees[tree]==true
			and type(tree)=="table" and typeof(tree.CFrame)=="CFrame"
			and eligible(tree) then
			local pos=tree.CFrame.Position
			local dx,dz=pos.X-center.X,pos.Z-center.Z
			local dist=dx*dx+dz*dz
			local id=if finite(tree.CreationId) then tree.CreationId else math.huge
			if dist<=radius*radius and math.abs(pos.Y-center.Y)<=MAX_VERTICAL_DELTA
				and (dist<bestDistance or (dist==bestDistance and id<bestId)) then
				best,bestDistance,bestId=tree,dist,id
			end
		end
	end
	return best
end
function ChainLightning.JumpDamage(primaryDamage,params,jump)
	local p=ChainLightning.Resolve(params)
	if not p or not finite(primaryDamage) or primaryDamage<=0
		or type(jump)~="number" or jump%1~=0
		or jump<1 or jump>p.MaxJumps then return 0 end
	return math.clamp(math.floor(primaryDamage*p.DamageFraction
		*(p.JumpFalloff^(jump-1))),0,1000000000)
end
function ChainLightning.Prepare(params,context)
	local p=ChainLightning.Resolve(params)
	if not p or type(context)~="table"
		or type(context.PrimaryTree)~="table"
		or type(context.ActiveTrees)~="table"
		or type(context.EligibleSecondary)~="function"
		or not finite(context.PrimaryDamage) or context.PrimaryDamage<=0 then return nil end
	local roll=if type(context.RandomUnit)=="function"
		then context.RandomUnit() else random:NextNumber()
	return {
		Profile=p,Proc=ChainLightning.ShouldProc(p.Chance,roll),
		PrimaryTree=context.PrimaryTree,
	}
end
local function arc(from,to)
	if typeof(from)~="CFrame" or typeof(to)~="CFrame" then return end
	local a=from.Position+Vector3.new(0,6,0)
	local b=to.Position+Vector3.new(0,6,0)
	local delta=b-a
	if delta.Magnitude<0.1 then return end
	local beam=Instance.new("Part")
	beam.Name="ChainLightningArc"
	beam.Anchored=true
	beam.CanCollide=false
	beam.CanTouch=false
	beam.CanQuery=false
	beam.Material=Enum.Material.Neon
	beam.Color=Color3.fromRGB(100,205,255)
	beam.Size=Vector3.new(0.35,0.35,delta.Magnitude)
	beam.CFrame=CFrame.lookAt((a+b)/2,b)
	beam.Parent=workspace
	Debris:AddItem(beam,0.23)
end
function ChainLightning.Apply(prepared,context)
	if type(prepared)~="table" or not prepared.Profile
		or prepared.Proc~=true or type(context)~="table"
		or context.PrimarySucceeded~=true
		or context.PrimaryTree~=prepared.PrimaryTree
		or type(context.ActiveTrees)~="table"
		or type(context.EligibleSecondary)~="function"
		or not finite(context.PrimaryDamage) or context.PrimaryDamage<=0 then return 0 end
	local p=prepared.Profile
	local visited={[context.PrimaryTree]=true}
	local from=context.PrimaryTree
	local hits=0
	for jump=1,p.MaxJumps do
		local target=ChainLightning.NextTarget(from,context.ActiveTrees,visited,p,
			context.EligibleSecondary)
		if not target then break end
		visited[target]=true
		local damage=ChainLightning.JumpDamage(context.PrimaryDamage,p,jump)
		if damage<1 then break end
		local maxHP=target.MaxHP
		local sourceCFrame=from.CFrame
		local targetCFrame=target.CFrame
		local ok,applied,killed=target:TakeDamage({
			Damage=damage,IsCrit=false,EffectId="ChainLightning",
		},context.Player)
		if not ok then break end
		hits += 1
		if type(applied)=="number" and applied>0
			and type(context.OnAppliedHit)=="function" then
			context.OnAppliedHit(target,applied,killed==true,maxHP)
		end
		arc(sourceCFrame,targetCFrame)
		from=target
	end
	if hits>0 and type(context.OnMutationProc)=="function" then
		context.OnMutationProc("ChainLightning",{Hits=hits})
	end
	return hits
end
return ChainLightning
