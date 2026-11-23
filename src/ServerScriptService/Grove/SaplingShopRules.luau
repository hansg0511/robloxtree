-- Minimal evergreen + rotating rare sapling shop. Pure offer generation.
-- A GLOBAL server-time cycle supplies the same rare offer to all players,
-- while an owned profile tracks whether that player purchased its one copy.
-- Costs/intervals are entirely provisional; no paid currency or quests here.
local Rules={}
Rules.RESTOCK_SECONDS=600 -- 10-minute test cadence, tune after playtesting
Rules.RARE_STOCK_CHANCE=0.40
Rules.MAX_UNPLANTED_SAPLINGS=96
Rules.COMMON={
	{Id="common_bamboo",SpeciesId="Bamboo",Name="Bamboo Sapling",
		Price=100,SizePotential=1,Forest="Forest1"},
	{Id="common_oak",SpeciesId="Oak",Name="Oak Sapling",
		Price=250,SizePotential=1,Forest="Forest1"},
	{Id="common_ironwood",SpeciesId="Ironwood",Name="Ironwood Sapling",
		Price=800,SizePotential=1,Forest="Forest2"},
}
local RARE_FAMILIES={"Golden","Frenzied","Shocked","Giant"}

function Rules.Cycle(timestamp)
	if type(timestamp)~="number" or timestamp~=timestamp
		or timestamp<0 or timestamp>=math.huge then return nil end
	return math.floor(timestamp/Rules.RESTOCK_SECONDS)
end

function Rules.Offers(timestamp)
	local cycle=Rules.Cycle(timestamp)
	if not cycle then return nil end
	local available={}
	for _,offer in ipairs(Rules.COMMON) do
		available[#available+1]={
			Id=offer.Id,Name=offer.Name,SpeciesId=offer.SpeciesId,
			SizePotential=offer.SizePotential,Mutations={},
			Price=offer.Price,Forest=offer.Forest,Rare=false,
			Stock=math.huge,
		}
	end
	-- One global cycle -> one deterministic draw; ordinary saplings do not
	-- vanish when rare stock is absent. Not tied to player RNG or purchases.
	local rng=Random.new(cycle%2147483*791+11031)
	if rng:NextNumber()<Rules.RARE_STOCK_CHANCE then
		local base=Rules.COMMON[rng:NextInteger(1,#Rules.COMMON)]
		local family=RARE_FAMILIES[rng:NextInteger(1,#RARE_FAMILIES)]
		available[#available+1]={
			Id="rare_"..base.SpeciesId:lower().."_"..family:lower(),
			Name=family.." "..base.SpeciesId.." Sapling",
			SpeciesId=base.SpeciesId,
			Mutations={[family]=true},
			SizePotential=if family=="Giant" then 1.6 else 1.1,
			Price=if base.SpeciesId=="Ironwood" then 5500 else 3000,
			Forest=base.Forest,Rare=true,Stock=1,
		}
	end
	return {Cycle=cycle,RestockAt=(cycle+1)*Rules.RESTOCK_SECONDS,
		Offers=available}
end

function Rules.Find(offers,id)
	if type(offers)~="table" or type(id)~="string" then return nil end
	for _,offer in ipairs(offers.Offers or {}) do
		if offer.Id==id then return offer end
	end
	return nil
end

return Rules
