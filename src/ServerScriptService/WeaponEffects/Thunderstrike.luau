-- Shocked Thunderstrike: every N CONFIRMED primary chops, add one
-- nonrecursive lightning burst to the CURRENT tree's primary hit.
-- Neighboring trees are deliberately untouched; that is Chain Lightning's job.
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
		or params.DamageFraction > 0.8 then return nil end
	return {
		EveryHits = params.EveryHits,
		DamageFraction = params.DamageFraction,
	}
end

-- Pure helper: one confirmed hit advances the counter by one.
function Thunderstrike.Advance(count, every)
	if type(count) ~= "number" or count < 0 or count % 1 ~= 0
		or type(every) ~= "number" or every < 1 or every % 1 ~= 0 then return 0, false end
	local nextCount = count + 1
	if nextCount >= every then return 0, true end
	return nextCount, false
end

-- Pure, bounded bonus. Composed with the PRIMARY hit BEFORE TakeDamage, so
-- a proc can finish a tree without depending on that tree surviving the hit.
function Thunderstrike.BonusDamage(primaryDamage, params)
	local profile = Thunderstrike.Resolve(params)
	if not profile or not finite(primaryDamage) or primaryDamage <= 0 then return 0 end
	return math.clamp(math.floor(primaryDamage * profile.DamageFraction), 0, 1000000000)
end

-- Preparation never advances counters. If the primary hit fails or has 0 HP
-- removed, no proc, XP or combo progress is committed.
function Thunderstrike.Prepare(params, context)
	local profile = Thunderstrike.Resolve(params)
	if not profile or type(context) ~= "table" or not context.Player
		or type(context.WeaponUID) ~= "string" or #context.WeaponUID == 0
		or type(context.PrimaryTree) ~= "table"
		or not finite(context.PrimaryDamage) or context.PrimaryDamage <= 0 then return nil end

	local previous = histories[context.Player]
	local count = if previous and previous.UID == context.WeaponUID
		then previous.Count else 0
	local nextCount, proc = Thunderstrike.Advance(count, profile.EveryHits)
	local bonus = if proc then Thunderstrike.BonusDamage(context.PrimaryDamage, profile) else 0

	-- Capture VFX source BEFORE the primary damage event. A lethal swing
	-- can remove the tree's Model synchronously.
	local tree = context.PrimaryTree
	local model = tree.model
	local visible = typeof(model) == "Instance" and model.Parent ~= nil
	local position = if typeof(tree.CFrame) == "CFrame" then tree.CFrame.Position else nil
	return {
		Profile = profile,
		Player = context.Player,
		WeaponUID = context.WeaponUID,
		PrimaryTree = tree,
		NextCount = nextCount,
		WillProc = proc,
		BonusDamage = bonus,
		PrimaryHPBefore = if finite(tree.HP) then tree.HP else nil,
		BaseDamage = context.PrimaryDamage,
		Model = if visible then model else nil,
		WorldPosition = position,
	}
end

local function showLightning(prepared)
	-- Visual-only world bolt: survives a killing blow that removes the model.
	if not prepared.Model or not prepared.WorldPosition then return end
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
	bolt.CFrame = CFrame.new(prepared.WorldPosition + Vector3.new(0, 10, 0))
	bolt.Parent = workspace
	Debris:AddItem(bolt, 0.3)

	local model = prepared.Model
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

-- Called only after TakeDamage confirmed a successful primary hit. Damage
-- was already combined into that one TakeDamage call by ChopHandler; DO NOT
-- damage anything again or call back into the dispatcher.
function Thunderstrike.Apply(prepared, context)
	if type(prepared) ~= "table" or type(context) ~= "table"
		or context.PrimarySucceeded ~= true
		or context.Player ~= prepared.Player
		or context.WeaponUID ~= prepared.WeaponUID
		or context.PrimaryTree ~= prepared.PrimaryTree
		or type(prepared.Profile) ~= "table"
		or not finite(context.PrimaryAppliedDamage)
		or context.PrimaryAppliedDamage <= 0 then return 0 end

	histories[prepared.Player] = {
		UID = prepared.WeaponUID,
		Count = prepared.NextCount,
	}
	if type(context.OnMutationTelemetry) == "function" then
		context.OnMutationTelemetry("Thunderstrike", {
			Count = if prepared.WillProc then prepared.Profile.EveryHits else prepared.NextCount,
			EveryHits = prepared.Profile.EveryHits,
			Proc = prepared.WillProc,
		})
	end
	if not prepared.WillProc then return 0 end

	-- Only report actual extra HP removed. No separate hit record or XP:
	-- the primary hit already accounts for the FULL clamped damage once.
	local extraHP = 0
	if finite(prepared.PrimaryHPBefore) then
		local normalApplied = math.min(math.floor(prepared.BaseDamage), prepared.PrimaryHPBefore)
		extraHP = math.max(0, context.PrimaryAppliedDamage - normalApplied)
	end
	if type(context.OnMutationTelemetry) == "function" then
		context.OnMutationTelemetry("ThunderstrikeResult", {
			Outcome = "HIT",
			Damage = extraHP,
			BonusRequested = prepared.BonusDamage,
			Killed = context.PrimaryKilled == true,
		})
	end
	showLightning(prepared)
	return 0 -- zero SECONDARY hits; primary already contains the bonus
end

function Thunderstrike.Clear(player)
	histories[player] = nil
end

return Thunderstrike
