-- Shared deterministic forge-tier mutation rules.
-- Only the server passes owned material UIDs and rolls Random.new().
-- All numeric tuning is provisional until the full economy is balanced.
local Rules = {}

Rules.MAX_LOG_SIZE = 5
Rules.PER_LOG_POTENCY = 0.22
Rules.FAMILIES = { "Golden", "Frenzied", "Shocked" }
Rules.TIERS = {
	[1] = { PotencyCap = 0.35, ClassCountOffset = 0, UpgradeCoins = 0 },
	[2] = { PotencyCap = 0.70, ClassCountOffset = 2, UpgradeCoins = 2000 },
}
-- Order is explicit for deterministic roll boundaries and preview parity.
-- Tier 1 remains guaranteed. Tier 2 introduces real weighted variety.
Rules.WEIGHT_POOLS = {
	Golden = {
		[1] = { { Id="GoldenTouch", Weight=100 } },
		[2] = {
			{ Id="GoldenTouch", Weight=50 },
			{ Id="GoldenRush", Weight=30 },
			{ Id="GoldenJackpot", Weight=20 },
		},
	},
	Frenzied = {
		[1] = { { Id="Fervor", Weight=100 } },
		[2] = {
			{ Id="Fervor", Weight=50 },
			{ Id="Bloodrush", Weight=25 },
			{ Id="Rampage", Weight=25 },
		},
	},
	Shocked = {
		[1] = { { Id="Thunderstrike", Weight=100 } },
		[2] = {
			{ Id="Thunderstrike", Weight=65 },
			{ Id="ChainLightning", Weight=35 },
		},
	},
}
-- Preserve the old public lookup for other consumers.
Rules.ABILITIES = {
	Golden = { [1]={"GoldenTouch"}, [2]={"GoldenTouch","GoldenRush","GoldenJackpot"} },
	Frenzied = { [1]={"Fervor"}, [2]={"Fervor","Bloodrush","Rampage"} },
	Shocked = { [1]={"Thunderstrike"}, [2]={"Thunderstrike","ChainLightning"} },
}

local function finite(n)
	return type(n)=="number" and n==n and n > -math.huge and n < math.huge
end

function Rules.Tier(tier)
	return Rules.TIERS[tier]
end

function Rules.ClassCount(count, tier)
	local config = Rules.Tier(tier)
	if not config or not finite(count) or count < 1 or count % 1 ~= 0 then return nil end
	return math.max(1, count - config.ClassCountOffset)
end

function Rules.AbilityOdds(family, tier)
	local pools = Rules.WEIGHT_POOLS[family]
	local pool = pools and pools[tier]
	if not pool then return {} end
	local total = 0
	for _, choice in ipairs(pool) do
		if not finite(choice.Weight) or choice.Weight <= 0 then return {} end
		total += choice.Weight
	end
	if total <= 0 then return {} end
	local results = {}
	for _, choice in ipairs(pool) do
		results[#results+1] = {
			Id = choice.Id, Weight = choice.Weight,
			Chance = choice.Weight/total,
		}
	end
	return results
end

-- roll is a uniform unit interval, injected for pure tests. Production
-- passes the server RNG; client-provided rolls are never accepted.
function Rules.SelectAbility(family, tier, roll)
	local odds = Rules.AbilityOdds(family,tier)
	if #odds == 0 or not finite(roll) or roll < 0 or roll > 1 then return nil end
	local draw = math.min(roll, 1 - 1e-12)
	local cumulative = 0
	for _, choice in ipairs(odds) do
		cumulative += choice.Chance
		if draw < cumulative then return choice.Id end
	end
	return odds[#odds].Id
end

-- Giant only affects genetics/size. Legacy Crystal is preserved on old
-- materials but does not grant a new skill.
-- Ordinary material NEVER dilutes a qualifying mutated log contribution.
function Rules.Preview(logs, tier)
	local config = Rules.Tier(tier)
	if not config or type(logs) ~= "table" or #logs<1 or #logs>96 then return nil end
	local family, sum, count = nil,0,0
	for _, log in ipairs(logs) do
		if type(log)~="table" or not finite(log.SizeScale) or log.SizeScale<=0 then return nil end
		local mutations = log.Mutations
		if mutations~=nil and type(mutations)~="table" then return nil end
		for _, id in ipairs(Rules.FAMILIES) do
			if type(mutations)=="table" and mutations[id]==true then
				if family and family~=id then return { InvalidReason="MIXED_MUTATION_FAMILIES" } end
				family = id
				sum += math.clamp(log.SizeScale / Rules.MAX_LOG_SIZE,0,1)*Rules.PER_LOG_POTENCY
				count += 1
			end
		end
	end
	local potency = math.min(sum,config.PotencyCap)
	return {
		Family=family, Tier=tier, QualifyingLogs=count,
		RawPotency=sum, Potency=potency,
		PotencyCap=config.PotencyCap,
		WastedPotency=math.max(0,sum-potency),
		AvailableAbilities=if family then table.clone(Rules.ABILITIES[family][tier]) else {},
		AbilityOdds=if family then Rules.AbilityOdds(family,tier) else {},
	}
end

function Rules.Roll(preview, tier, rng)
	if not Rules.Tier(tier) or type(preview)~="table" or preview.InvalidReason
		or (preview.Tier~=nil and preview.Tier~=tier) then return nil end
	local family = preview.Family
	if not family or not rng or type(rng.NextNumber)~="function" then return nil end
	local potency = preview.Potency
	if not finite(potency) or potency<=0 or potency>Rules.TIERS[tier].PotencyCap then return nil end
	-- Maintain tier-one deterministic behavior: no extra ability RNG draw
	-- when a family offers exactly one choice.
	local odds = Rules.AbilityOdds(family,tier)
	if #odds==0 then return nil end
	local roll = if #odds==1 then 0 else rng:NextNumber()
	local id = Rules.SelectAbility(family,tier,roll)
	if not id then return nil end
	local params
	if id=="GoldenTouch" then
		params={CoinFraction=0.20+potency*0.85}
	elseif id=="GoldenRush" then
		params={CoinFractionPerStack=0.10+potency*0.32,MaxStacks=4,WindowSeconds=8}
	elseif id=="GoldenJackpot" then
		params={Chance=0.10+potency*0.15,PayoutMultiplier=4+potency*4}
	elseif id=="Fervor" then
		params={SpeedPerStack=0.06+potency*0.15,MaxStacks=5,WindowSeconds=3}
	elseif id=="Bloodrush" then
		params={SpeedMultiplier=1.12+potency*0.20,DurationSeconds=7}
	elseif id=="Rampage" then
		params={DamageMultiplier=1.20+potency*0.25,DurationSeconds=8}
	elseif id=="Thunderstrike" then
		params={EveryHits=math.max(3,math.floor(7-3*potency)),DamageFraction=0.20+potency*0.5}
	elseif id=="ChainLightning" then
		params={Chance=0.25+potency*0.15,DamageFraction=0.45+potency*0.25,
			JumpFalloff=0.7,MaxJumps=3,Radius=20}
	else return nil end

	local trigger = if id=="Fervor" or id=="Thunderstrike" or id=="ChainLightning"
		then "OnHit" else "OnKill"
	return {
		Family=family,Id=id,Potency=potency,Tier=tier,
		Effect={Id=id,Trigger=trigger,Source="WoodMutation",Params=params},
	}
end

return Rules
