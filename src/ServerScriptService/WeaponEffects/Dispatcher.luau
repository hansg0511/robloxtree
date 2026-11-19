-- Server-only combat effect dispatcher.
-- Weapon class / material mutation / other source determine WHAT effects a
-- weapon owns, while handlers implement HOW an effect behaves. No player-
-- supplied effect configuration, target list or damage payload is accepted.
local Dispatcher = {}

local handlers = {
	Cleave = require(script.Parent.Cleave),
}
Dispatcher.MAX_EFFECTS = 8

local function legacyClassEffects(weaponData)
	-- Existing Battlehammers created before WeaponData.Effects was introduced
	-- may still have the original scalar fields. Read them, don't migrate or
	-- rewrite the weapon during a chop.
	if weaponData.ExperimentalClass ~= "Battlehammer" then return {} end
	return {
		{
			Id = "Cleave",
			Trigger = "OnHit",
			Source = "LegacyWeaponClass",
			Params = {
				Radius = weaponData.CleaveRadius,
				DamageFraction = weaponData.CleaveDamageFraction,
			},
		},
	}
end

-- Return only registered, validated, bounded descriptions. A supplied Source
-- is informational and NEVER bypasses effect validation or player access.
function Dispatcher.List(weaponData)
	if type(weaponData) ~= "table" then return {} end
	local entries = if type(weaponData.Effects) == "table"
		then weaponData.Effects else legacyClassEffects(weaponData)
	local descriptions = {}
	local seen = {}
	for index = 1, math.min(#entries, Dispatcher.MAX_EFFECTS) do
		local entry = entries[index]
		if type(entry) == "table" and type(entry.Id) == "string"
			and not seen[entry.Id] then
			local handler = handlers[entry.Id]
			if handler and entry.Trigger == handler.Trigger then
				local params = handler.Resolve(entry.Params)
				if params then
					seen[entry.Id] = true
					descriptions[#descriptions + 1] = {
						Id = entry.Id,
						Trigger = handler.Trigger,
						Source = if type(entry.Source) == "string"
							and #entry.Source > 0 and #entry.Source <= 64
							then entry.Source else "Unspecified",
						Params = params,
					}
				end
			end
		end
	end
	return descriptions
end

-- Prepare the relevant effect(s) BEFORE the primary hit. This preserves
-- nearby targets even if the primary tree dies and is removed immediately.
function Dispatcher.Prepare(trigger, weaponData, context)
	local prepared = {}
	if type(trigger) ~= "string" or type(context) ~= "table" then return prepared end
	for _, effect in ipairs(Dispatcher.List(weaponData)) do
		if effect.Trigger == trigger then
			local handler = handlers[effect.Id]
			local state = handler.Prepare(effect.Params, context)
			if state then
				prepared[#prepared + 1] = {
					Id = effect.Id,
					State = state,
				}
			end
		end
	end
	return prepared
end

-- Called ONLY after a successful server-authoritative primary hit.
-- Secondary effects do not call back into the dispatcher: no recursion.
function Dispatcher.ApplyPrepared(prepared, context)
	if type(prepared) ~= "table" or type(context) ~= "table" then return 0 end
	local totalHits = 0
	for index = 1, math.min(#prepared, Dispatcher.MAX_EFFECTS) do
		local entry = prepared[index]
		if type(entry) == "table" then
			local handler = handlers[entry.Id]
			if handler then
				local ok, hits = pcall(handler.Apply, entry.State, context)
				if ok and type(hits) == "number" then
					totalHits += hits
				elseif not ok then
					warn("[WeaponEffects] " .. entry.Id .. " failed:", hits)
				end
			end
		end
	end
	return totalHits
end

return Dispatcher
