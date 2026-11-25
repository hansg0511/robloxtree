-- Phase 4 minimal sapling supply. Players can always buy ordinary
-- saplings, with at most one rare sapling per player per rotating window.
-- The wild-discovery/quest systems remain separate sources of saplings.
local Players=game:GetService("Players")
local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Profiles=require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local WorldProgress=require(game.ServerScriptService.WorldProgressService)
local Grove=require(script.Parent.GroveService)
local Shop=require(script.Parent.SaplingShopRules)
local Station=require(game.ServerScriptService.WorldLayout.BaseStationAccess)
local Passives=require(script.Parent.GrovePassiveRules)

local remotes=ReplicatedStorage:WaitForChild("Grove")
local getShop=remotes:WaitForChild("GetSaplingShopRF")
local buy=remotes:WaitForChild("BuySaplingRE")
local economyUpdated=ReplicatedStorage.Economy:WaitForChild("EconomyUpdated")
local Service={}
local started=false
local lastPurchase=setmetatable({}, {__mode="k"})
local function validMoney(money)
	return type(money)=="number" and money==money
		and money>=0 and money<math.huge
end
local function getData(player)
	local profile=Profiles.GetProfile(player)
	return profile and type(profile.Data)=="table" and profile.Data or nil
end
local function uidUsed(data,uid)
	for _,key in ipairs({"Saplings","GroveTrees","GroveMaterials","Logs","StoredLogs"}) do
		for _,row in ipairs(type(data[key])=="table" and data[key] or {}) do
			if type(row)=="table" and (row.UID==uid
				or row.SourceSaplingUID==uid or row.SourceGroveTreeUID==uid) then
				return true
			end
		end
	end
	return false
end
local function newUID(data)
	for _=1,8 do
		local id=HttpService:GenerateGUID(false)
		if type(id)=="string" and #id>0 and not uidUsed(data,id) then return id end
	end
	return nil
end
function Service.GetState(player)
	local data=getData(player)
	if not data then return nil end
	local offers=Shop.Offers(os.time())
	if not offers then return nil end
	local result={Cycle=offers.Cycle,RestockAt=offers.RestockAt,
		Coins=data.Coins,OwnedSaplings=#(data.Saplings or {}),Offers={}}
	local shop=if type(data.SaplingShop)=="table" then data.SaplingShop else {}
	for _,offer in ipairs(offers.Offers) do
		local unlocked=WorldProgress.CanAccessForest(player,offer.Forest)==true
		local remaining=Shop.Remaining(shop,offers.Cycle,offer)
		local sold=remaining<=0
		local view=table.clone(offer)
		view.Mutations=table.clone(offer.Mutations)
		view.Unlocked=unlocked
		view.InitialStock=offer.Stock
		view.Stock=remaining
		view.Available=unlocked and not sold
		view.SoldOut=sold==true
		view.CanBuy=unlocked and not sold
			and validMoney(data.Coins) and data.Coins>=offer.Price
			and type(data.Saplings)=="table"
			and #data.Saplings<Shop.MAX_UNPLANTED_SAPLINGS
		result.Offers[#result.Offers+1]=view
	end
	return result
end
function Service.Purchase(player,id,expectedCycle)
	if not Station.CanUseGroveShop(player) then return {Reason="NOT_AT_GROVE_SHOP"} end
	local data=getData(player)
	if not data or type(data.Saplings)~="table"
		or type(data.SaplingShop)~="table" then
		return {Reason="PROFILE_UNAVAILABLE"}
	end
	local offers=Shop.Offers(os.time())
	if not offers or expectedCycle~=offers.Cycle then return {Reason="OFFER_NOT_AVAILABLE"} end
	local offer=Shop.Find(offers,id)
	if not offer then return {Reason="OFFER_NOT_AVAILABLE"} end
	if not WorldProgress.CanAccessForest(player,offer.Forest) then
		return {Reason="FOREST_LOCKED"}
	end
	if #data.Saplings>=Shop.MAX_UNPLANTED_SAPLINGS then
		return {Reason="SAPLING_STORAGE_FULL"}
	end
	if not validMoney(data.Coins) or data.Coins<offer.Price then
		return {Reason="NOT_ENOUGH_COINS"}
	end
	if Shop.Remaining(data.SaplingShop,offers.Cycle,offer)<=0 then
		return {Reason="SOLD_OUT"}
	end
	local uid=newUID(data)
	if not uid then return {Reason="UID_UNAVAILABLE"} end
	local now=os.time()
	-- Server-owned nonyielding commit: the exact offered mutation, species,
	-- genetic size potential and price come from Shop.Offers() only.
	local record={
		UID=uid,SpeciesId=offer.SpeciesId,
		Mutations=table.clone(offer.Mutations),
		SizePotential=offer.SizePotential,
		GeneticPassive=Passives.RollGenetic(),
		CreatedAt=now,
	}
	table.insert(data.Saplings,record)
	data.Coins-=offer.Price
	local shop=data.SaplingShop
	if shop.Cycle~=offers.Cycle then shop.Cycle=offers.Cycle; shop.Purchased={} end
	if type(shop.Purchased)~="table" then shop.Purchased={} end
	shop.Purchased[id]=(shop.Purchased[id] or 0)+1
	return {Reason="PURCHASED",UID=uid,OfferId=id,Name=offer.Name,
		Coins=data.Coins,Rare=offer.Rare,Cycle=offers.Cycle}
end
function Service.Start()
	if started then return end
	started=true
	getShop.OnServerInvoke=function(player,...)
		if select("#",...)~=0 then return nil end
		return Service.GetState(player)
	end
	buy.OnServerEvent:Connect(function(player,id,cycle,...)
		if select("#",...)~=0 or type(id)~="string" or #id>90 or type(cycle)~="number" or cycle%1~=0 then return end
		local now=os.clock()
		if now-(lastPurchase[player] or -math.huge)<0.4 then return end
		lastPurchase[player]=now
		local ok,result=pcall(function() return Service.Purchase(player,id,cycle) end)
		if not ok then
			warn("[SaplingShop] purchase error:",result)
			buy:FireClient(player,{Reason="SERVER_ERROR"})
			return
		end
		buy:FireClient(player,result)
		if result.Reason=="PURCHASED" then
			economyUpdated:FireClient(player,"Coins",result.Coins)
			Grove.NotifyState(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastPurchase[player]=nil
	end)
end
return Service
