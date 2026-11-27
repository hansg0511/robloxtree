-- Shared additive gameplay buckets. A future pet/buff provider contributes
-- the same canonical IDs rather than independently multiplying rewards.
-- Crit fields are percentage points, other bonuses are fractions.
local Grove = require(script.Parent.Grove.GrovePassiveRules)
local Substats = require(script.Parent.WeaponSubstatRules)
local World = require(script.Parent.WorldProgressService)
local Stats = {}
function Stats.Empty()
	return {Damage=0,Haste=0,CritChance=0,CritDamage=0,CoinGain=0,
		WeaponXP=0,ExtraLogs=0,SaplingChance=0}
end
function Stats.Add(totals,source)
	for id,value in pairs(source or {}) do
		if totals[id]~=nil and type(value)=="number" and value==value and value>=0 and value<math.huge then
			totals[id]+=value
		end
	end
	return totals
end
function Stats.Totals(data,weapon,now)
	local total=Stats.Empty()
	local grove=Grove.Totals(data,now)
	-- Existing Grove Sale means log-sale bonuses, so preserve that scope.
	-- CoinGain covers ordinary earned tree coins; sale combines the two
	-- additively at its single application site, never as separate multipliers.
	Stats.Add(total,grove)
	Stats.Add(total,Substats.Totals(weapon))
	return total
end
function Stats.ForPlayer(player,data,now)
	local weapon=World.GetEquippedRuntimeWeapon(player)
	return Stats.Totals(data,weapon,now)
end
function Stats.SaleValue(player,data,base,now)
	local totals=Stats.ForPlayer(player,data,now)
	local grove=Grove.Totals(data,now)
	return Stats.ScaleReward(base,totals.CoinGain+grove.Sale)
end
function Stats.ScaleReward(base,bonus)
	return math.floor(base*(1+bonus)+0.5)
end
function Stats.RollExtraLogs(bonus,rng)
	local whole=math.floor(bonus)
	local remainder=bonus-whole
	return whole+(if remainder>0 and rng:NextNumber()<remainder then 1 else 0)
end
return Stats
