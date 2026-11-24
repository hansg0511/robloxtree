-- Global deterministic catalogue; each profile gets its own purchase quota.
local Quality=require(script.Parent.SaplingQualityRules)
local Rules={}
Rules.RESTOCK_SECONDS=600
Rules.MAX_UNPLANTED_SAPLINGS=96
-- Provisional stock and prices; no special species or new currency.
Rules.COMMON={
	{Id="common_bamboo",SpeciesId="Bamboo",Name="Bamboo Sapling",Price=100,Forest="Forest1",MinStock=3,MaxStock=8},
	{Id="common_oak",SpeciesId="Oak",Name="Oak Sapling",Price=250,Forest="Forest1",MinStock=2,MaxStock=5},
	{Id="common_ironwood",SpeciesId="Ironwood",Name="Ironwood Sapling",Price=800,Forest="Forest2",MinStock=1,MaxStock=3},
}
Rules.COMMON_STOCK_CHANCE=0.95
Rules.MUTATED_STOCK_CHANCE=0.08
local RARE_FAMILIES={"Golden","Frenzied","Shocked","Giant"}
function Rules.Cycle(timestamp)
	if type(timestamp)~="number" or timestamp~=timestamp or timestamp<0 or timestamp>=math.huge then return nil end
	return math.floor(timestamp/Rules.RESTOCK_SECONDS)
end
function Rules.Offers(timestamp)
	local cycle=Rules.Cycle(timestamp)
	if not cycle then return nil end
	local rng=Random.new(cycle%2147483*791+11031)
	local offers={}
	for _,base in ipairs(Rules.COMMON) do
		offers[#offers+1]={
			Id=base.Id, Name=base.Name, SpeciesId=base.SpeciesId, Forest=base.Forest,
			Price=base.Price, SizePotential=1, Mutations={}, Rare=false,
			Stock=if rng:NextNumber()<Rules.COMMON_STOCK_CHANCE then rng:NextInteger(base.MinStock,base.MaxStock) else 0,
		}
	end
	for _,base in ipairs(Rules.COMMON) do
		for _,family in ipairs(RARE_FAMILIES) do
			if rng:NextNumber()<Rules.MUTATED_STOCK_CHANCE then
				local mutations={[family]=true}
				offers[#offers+1]={
					Id="rare_"..base.SpeciesId:lower().."_"..family:lower(),
					Name=family.." "..base.SpeciesId.." Sapling", SpeciesId=base.SpeciesId,
					Mutations=mutations, SizePotential=Quality.Shop(mutations,rng),
					Price=if base.SpeciesId=="Ironwood" then 5500 else 3000,
					Forest=base.Forest, Rare=true, Stock=rng:NextInteger(1,2),
				}
			end
		end
	end
	return {Cycle=cycle,RestockAt=(cycle+1)*Rules.RESTOCK_SECONDS,Offers=offers}
end
function Rules.Find(offers,id)
	if type(offers)~="table" or type(id)~="string" then return nil end
	for _,offer in ipairs(offers.Offers or {}) do if offer.Id==id then return offer end end
	return nil
end
function Rules.Remaining(shop,cycle,offer)
	-- A legacy rare purchase cannot be reset by migrating mid-cycle.
	if offer.Rare and shop.RareBoughtCycle==cycle then return 0 end
	local used=if shop.Cycle==cycle and type(shop.Purchased)=="table" then shop.Purchased[offer.Id] or 0 else 0
	if type(used)~="number" or used~=used or used<0 or used%1~=0 then return 0 end
	return math.max(0,offer.Stock-used)
end
return Rules
