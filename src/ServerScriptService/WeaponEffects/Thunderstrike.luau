-- Shocked Thunderstrike: every N CONFIRMED primary chops releases one
-- nonrecursive secondary lightning hit on a server-eligible target.
local Cleave = require(script.Parent.Cleave)
local Debris = game:GetService("Debris")
local Thunderstrike = {}
Thunderstrike.Id = "Thunderstrike"
Thunderstrike.Trigger = "OnHit"
local histories = setmetatable({}, { __mode = "k" })

local function finite(value)
	return type(value) == "number" and value == value
		and value > -math.huge and value < math.huge
end

function Thunderstrike.Resolve(params)
	if type(params) ~= "table" or not finite(params.EveryHits)
		or params.EveryHits % 1 ~= 0 or params.EveryHits < 3
		or params.EveryHits > 10
		or not finite(params.DamageFraction) or params.DamageFraction <= 0
		or params.DamageFraction > 0.8
		or not finite(params.Radius) or params.Radius < 2
		or params.Radius > 24 then return nil end
	return {
		EveryHits = params.EveryHits,
		DamageFraction = params.DamageFraction,
		Radius = params.Radius,
	}
end

function Thunderstrike.Prepare(params, context)
	local profile = Thunderstrike.Resolve(params)
	if not profile or type(context) ~= "table"
		or type(context.EligibleSecondary) ~= "function" then return nil end
	return {
		Profile = profile,
		Targets = Cleave.FindSecondaryTargets(context.PrimaryTree,
			context.ActiveTrees, { Radius = profile.Radius, MaxTargets = 1 },
			context.EligibleSecondary),
	}
end

-- Pure counter helper for deterministic boundary tests.
function Thunderstrike.Advance(count, every)
	if type(count) ~= "number" or count < 0 or count % 1 ~= 0
		or type(every) ~= "number" or every < 1 or every % 1 ~= 0 then return 0, false end
	local nextCount = count + 1
	if nextCount >= every then return 0, true end
	return nextCount, false
end

function Thunderstrike.Apply(prepared, context)
	if type(prepared) ~= "table" or not prepared.Profile
		or type(context) ~= "table" or context.PrimarySucceeded ~= true
		or type(context.ActiveTrees) ~= "table"
		or type(context.EligibleSecondary) ~= "function"
		or not finite(context.PrimaryDamage) or context.PrimaryDamage <= 0
		or not context.Player or type(context.WeaponUID) ~= "string" then return 0 end
	local player, uid = context.Player, context.WeaponUID
	local previous = histories[player]
	local count = if previous and previous.UID == uid then previous.Count else 0
	local nextCount, proc = Thunderstrike.Advance(count, prepared.Profile.EveryHits)
	histories[player] = { UID = uid, Count = nextCount }
	-- Optional trusted server diagnostic: counts every accepted primary hit,
	-- including cycles after the first proc. No remote or player inputs.
	if type(context.OnMutationTelemetry) == "function" then
		context.OnMutationTelemetry("Thunderstrike", {
			Count = if proc then prepared.Profile.EveryHits else nextCount,
			EveryHits = prepared.Profile.EveryHits,
			Proc = proc,
		})
	end
	if not proc then return 0 end
	local target
	for _, candidate in ipairs(prepared.Targets or {}) do
		if context.ActiveTrees[candidate] == true
			and context.EligibleSecondary(candidate) then
			target = candidate
			break
		end
	end
	-- Single-target fallback: if the primary survived, a lightning strike
	-- still feels useful. A killed primary is never attacked twice.
	if not target and context.ActiveTrees[context.PrimaryTree] == true
		and context.EligibleSecondary(context.PrimaryTree) then
		target = context.PrimaryTree
	end
	if not target or type(target.TakeDamage) ~= "function" then return 0 end
	local damage = math.floor(context.PrimaryDamage * prepared.Profile.DamageFraction)
	if damage < 1 then return 0 end
	local maxHP = target.MaxHP
	-- Capture the target's world position BEFORE TakeDamage, because a lethal
	-- strike can remove the tree's Model immediately. The lightning VFX must
	-- not depend on that destroyed instance still being parented afterwards.
	local model = target.model
	local showVisual = typeof(model) == "Instance" and model.Parent ~= nil
	local worldPosition = if typeof(target.CFrame) == "CFrame"
		then target.CFrame.Position else nil
	local success, applied, killed = target:TakeDamage({
		Damage = damage, IsCrit = false, EffectId = "Thunderstrike",
	}, player)
	if not success then return 0 end
	if type(applied) == "number" and applied > 0
		and type(context.OnAppliedHit) == "function" then
		context.OnAppliedHit(target, applied, killed == true, maxHP)
	end
	-- World-space neon bolt survives lethal tree removal. It is cosmetic,
	-- non-collidable, short lived, and not tied to a player's local scripts.
	if showVisual and worldPosition then
		local bolt = Instance.new("Part")
		bolt.Name = "ThunderstrikeFlash"
		bolt.Anchored = true
		bolt.CanCollide = false
		bolt.CanTouch = false
		bolt.CanQuery = false
		bolt.Material = Enum.Material.Neon
		bolt.Color = Color3.fromRGB(65, 185, 255)
		bolt.Transparency = 0.18
		bolt.Size = Vector3.new(0.7, 20, 0.7)
		bolt.CFrame = CFrame.new(worldPosition + Vector3.new(0, 10, 0))
		bolt.Parent = workspace
		Debris:AddItem(bolt, 0.3)
		-- Highlight survivors as a secondary accent, without requiring the
		-- model to survive for the lightning to be visible.
		if model.Parent then
			local light = Instance.new("Highlight")
			light.Name = "ThunderstrikeOutline"
			light.FillColor = Color3.fromRGB(68, 180, 255)
			light.OutlineColor = Color3.fromRGB(220, 248, 255)
			light.FillTransparency = 0.22
			light.OutlineTransparency = 0
			light.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			light.Parent = model
			Debris:AddItem(light, 0.3)
		end
	end
	return 1
end

function Thunderstrike.Clear(player)
	histories[player] = nil
end

return Thunderstrike
