local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local profileCache = require(ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local itemDataBase = require(game.ServerStorage.Items.ItemDataBase)
local catalog = require(script.Parent.AxeShopCatalog)
local LogService = require(ServerScriptService.Inventory.LogService)
local LogService = require(ServerScriptService.Inventory.LogService)

local economyRemotes = ReplicatedStorage:WaitForChild("Economy")
local getShopData = economyRemotes:WaitForChild("GetShopDataRF")
local purchaseAxe = economyRemotes:WaitForChild("PurchaseAxeRE")
local purchaseCapacity = economyRemotes:WaitForChild("PurchaseCapacityRE")
local economyUpdated = economyRemotes:WaitForChild("EconomyUpdated")

-- This server-only function is installed by InventoryHandler after it has built
-- the per-player InventoryMaker instances. Shop purchases go through that same
-- authoritative inventory, rather than creating a parallel client inventory.
local addShopItem = ServerScriptService.Inventory:WaitForChild("AddShopAxeItem")

local REQUEST_INTERVAL = 0.4
local nextRequestAt = {}

local function takeBudget(player, action)
	local now = os.clock()
	local budgets = nextRequestAt[player]
	if not budgets then
		budgets = {}
		nextRequestAt[player] = budgets
	end
	if now < (budgets[action] or 0) then return false end
	budgets[action] = now + REQUEST_INTERVAL
	return true
end

local function isFiniteNumber(value)
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function getOwnedAxe(profile, itemId)
	for _, item in ipairs(profile.Data.Inventory or {}) do
		if type(item) == "table" and item.ItemID == itemId then
			return item
		end
	end
	return nil
end

local function findAxe(axeId)
	if typeof(axeId) ~= "string" then return nil end
	for _, entry in ipairs(catalog.Axes) do
		if entry.Id == axeId then return entry end
	end
	return nil
end

local function buildShopSnapshot(profile)
	local data = profile.Data
	local axes = {}
	for _, entry in ipairs(catalog.Axes) do
		local ownedItem = getOwnedAxe(profile, entry.ItemID)
		axes[#axes + 1] = {
			Id = entry.Id,
			Name = entry.Name,
			Power = entry.Power,
			Price = entry.Price,
			ItemID = entry.ItemID,
			Owned = ownedItem ~= nil,
			UID = ownedItem and ownedItem.UID or nil,
			Equipped = ownedItem ~= nil and data.Equipped and data.Equipped.Weapon == ownedItem.UID,
		}
	end

	local upgrades = {}
	for _, entry in ipairs(catalog.CapacityUpgrades) do
		upgrades[#upgrades + 1] = {
			Capacity = entry.Capacity,
			Price = entry.Price,
		}
	end

	return {
		Coins = isFiniteNumber(data.Coins) and data.Coins or 0,
		Capacity = isFiniteNumber(data.LogCapacity) and data.LogCapacity or 10,
		Axes = axes,
		CapacityUpgrades = upgrades,
	}
end

getShopData.OnServerInvoke = function(player, ...)
	if select("#", ...) ~= 0 then return nil end
	local profile = profileCache.GetProfile(player)
	if not profile or not profile.Data or not profile.Data.Runtime then return nil end
	return buildShopSnapshot(profile)
end

purchaseAxe.OnServerEvent:Connect(function(player, axeId, ...)
	if select("#", ...) ~= 0 then return end
	if not takeBudget(player, "PurchaseAxe") then return end
	if not LogService.CanSellAtBase(player) then return end
	local profile = profileCache.GetProfile(player)
	if not profile or not profile.Data or not profile.Data.Runtime then return end

	local entry = findAxe(axeId)
	if not entry or entry.Price <= 0 then return end
	if getOwnedAxe(profile, entry.ItemID) then return end

	local coins = profile.Data.Coins
	if not isFiniteNumber(coins) or coins < entry.Price then return end
	local itemInfo = itemDataBase.Info[entry.ItemID]
	if not itemInfo or itemInfo.Type ~= "Weapon" then return end

	local itemRecord = {
		ItemID = entry.ItemID,
		UID = HttpService:GenerateGUID(false),
		Stats = { Attack = math.max(0, entry.Power - catalog.BaseAttack) },
		Substat = {},
		Rarity = "Common",
	}
	local added = addShopItem:Invoke(player, itemRecord)
	if added ~= true then return end

	profile.Data.Coins = coins - entry.Price
	economyUpdated:FireClient(player, "Coins", profile.Data.Coins)
	LogService.NotifyState(player)
end)

purchaseCapacity.OnServerEvent:Connect(function(player, requestedCapacity, ...)
	if select("#", ...) ~= 0 then return end
	if not takeBudget(player, "PurchaseCapacity") then return end
	if not LogService.CanSellAtBase(player) then return end
	local profile = profileCache.GetProfile(player)
	if not profile or not profile.Data or not profile.Data.Runtime then return end
	if not isFiniteNumber(requestedCapacity) or requestedCapacity % 1 ~= 0 then return end

	local currentCapacity = profile.Data.LogCapacity
	if not isFiniteNumber(currentCapacity) then currentCapacity = 10 end
	local upgrade
	for _, entry in ipairs(catalog.CapacityUpgrades) do
		if entry.Capacity == requestedCapacity and entry.Capacity > currentCapacity then
			local previousCapacity = 10
			for _, priorEntry in ipairs(catalog.CapacityUpgrades) do
				if priorEntry.Capacity < entry.Capacity then
					previousCapacity = priorEntry.Capacity
				end
			end
			if previousCapacity == currentCapacity then upgrade = entry end
			break
		end
	end
	if not upgrade then return end

	local coins = profile.Data.Coins
	if not isFiniteNumber(coins) or coins < upgrade.Price then return end
	profile.Data.Coins = coins - upgrade.Price
	profile.Data.LogCapacity = upgrade.Capacity
	economyUpdated:FireClient(player, "Coins", profile.Data.Coins)
	LogService.NotifyState(player)
end)

Players.PlayerRemoving:Connect(function(player)
	nextRequestAt[player] = nil
end)
