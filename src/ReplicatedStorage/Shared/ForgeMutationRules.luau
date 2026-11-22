-- Phase 2 Batch 1: pure forge-tier mutation calculations and ability rolls.
-- Shared by preview and server forge, but only the server supplies owned logs
-- and RNG. Existing forged Crystal/Golden metadata stays untouched.
local Rules = {}

Rules.MAX_LOG_SIZE = 5
Rules.PER_LOG_POTENCY = 0.22 -- each qualifying log adds at most 0.22
Rules.FAMILIES = { "Golden", "Frenzied", "Shocked" }
Rules.TIERS = {
	[1] = { PotencyCap = 0.35, ClassCountOffset = 0, UpgradeCoins = 0 },
	[2] = { PotencyCap = 0.70, ClassCountOffset = 2, UpgradeCoins = 2000 },
}
Rules.ABILITIES = {
	Golden = { [1] = { "GoldenTouch" }, [2] = { "GoldenTouch" } },
	Frenzied = { [1] = { "Fervor" }, [2] = { "Fervor" } },
	Shocked = { [1] = { "Thunderstrike" }, [2] = { "Thunderstrike" } },
}

local function finite(x)
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

function Rules.Tier(tier)
	return Rules.TIERS[tier]
end

function Rules.ClassCount(count, tier)
	local config = Rules.Tier(tier)
	if not config or not finite(count) or count < 1 or count % 1 ~= 0 then return nil end
	-- Higher tiers make small weapon classes accessible at larger log counts.
	return math.max(1, count - config.ClassCountOffset)
end

-- Mixed ability-bearing families are deliberately unsupported for the MVP.
-- Giant only modifies wood size; Crystal is legacy, never grants an ability.
-- Ordinary logs do not dilute the qualifying mutated log contributions.
function Rules.Preview(logs, tier)
	local config = Rules.Tier(tier)
	if not config or type(logs) ~= "table" or #logs < 1 or #logs > 96 then return nil end
	local family, sum, count = nil, 0, 0
	for _, log in ipairs(logs) do
		if type(log) ~= "table" or not finite(log.SizeScale)
			or log.SizeScale <= 0 then return nil end
		local mutations = log.Mutations
		if mutations ~= nil and type(mutations) ~= "table" then return nil end
		for _, id in ipairs(Rules.FAMILIES) do
			if type(mutations) == "table" and mutations[id] == true then
				if family and family ~= id then
					return { InvalidReason = "MIXED_MUTATION_FAMILIES" }
				end
				family = id
				sum += math.clamp(log.SizeScale / Rules.MAX_LOG_SIZE, 0, 1)
					* Rules.PER_LOG_POTENCY
				count += 1
			end
		end
	end
	local potency = math.min(sum, config.PotencyCap)
	return {
		Family = family,
		QualifyingLogs = count,
		RawPotency = sum,
		Potency = potency,
		PotencyCap = config.PotencyCap,
		WastedPotency = math.max(0, sum - potency),
		AvailableAbilities = if family then table.clone(Rules.ABILITIES[family][tier]) else {},
	}
end

function Rules.Roll(preview, tier, rng)
	if not Rules.Tier(tier) or type(preview) ~= "table"
		or preview.InvalidReason then return nil end
	if not preview.Family then return nil end
	if not rng then return nil end
	local choices = Rules.ABILITIES[preview.Family]
	choices = choices and choices[tier]
	if not choices or #choices < 1 then return nil end
	-- New higher-tier choices will use weighted odds in Batch 2.
	-- One ability per family is unlocked at launch; no additional draw needed.
	local id = choices[1]
	local potency = preview.Potency
	if not finite(potency) or potency <= 0 or potency > Rules.TIERS[tier].PotencyCap then return nil end
	local params
	if id == "GoldenTouch" then
		params = { CoinFraction = 0.20 + potency * 0.85 }
	elseif id == "Fervor" then
		params = { SpeedPerStack = 0.06 + potency * 0.15, MaxStacks = 5, WindowSeconds = 3 }
	elseif id == "Thunderstrike" then
		params = {
			EveryHits = math.max(3, math.floor(7 - 3 * potency)),
			DamageFraction = 0.20 + potency * 0.5,
			Radius = 18,
		}
	else return nil end
	return {
		Family = preview.Family,
		Id = id,
		Potency = potency,
		Tier = tier,
		Effect = { Id = id, Trigger = if id == "GoldenTouch" then "OnKill" else "OnHit",
			Source = "WoodMutation", Params = params },
	}
end

return Rules
