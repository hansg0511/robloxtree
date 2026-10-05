-- Server-authoritative axe-head purchases, standard-axe crafting, and bag upgrades.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local profileCache = require(ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local itemDataBase = require(game.ServerStorage.Items.ItemDataBase)
local catalog = require(script.Parent.AxeShopCatalog)
local LogService = require(ServerScriptService.Inventory.LogService)
local WorldProgressService = require(ServerScriptService.WorldProgressService)
local BaseStationAccess = require(ServerScriptService.WorldLayout.BaseStationAccess)

local economyRemotes = ReplicatedStorage:WaitForChild("Economy")
local getShopData = economyRemotes:WaitForChild("GetShopDataRF")
local purchaseAxeHead = economyRemotes:WaitForChild("PurchaseAxeHeadRE")
local craftRecipe = economyRemotes:WaitForChild("CraftRecipeRE")
local purchaseCapacity = economyRemotes:WaitForChild("PurchaseCapacityRE")
local economyUpdated = economyRemotes:WaitForChild("EconomyUpdated")

-- The existing inventory owns all finished weapons. This server-only function
-- validates and inserts a weapon through the same runtime/profile path as shop axes.
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
	return typeof(value) == "number"
		and value == value
		and math.abs(value) < math.huge
end

local function getProfileData(player)
	local profile = profileCache.GetProfile(player)
	if not profile or type(profile.Data) ~= "table" or type(profile.Data.Runtime) ~= "table" then
		return nil, nil
	end
	return profile, profile.Data
end

local function getOwnedAxe(profile, itemId)
	for _, item in ipairs(profile.Data.Inventory or {}) do
		if type(item) == "table" and item.ItemID == itemId then
			return item
		end
	end
	return nil
end

local function findRecipeForHead(headId)
	for _, recipe in ipairs(catalog.StandardAxeRecipes) do
		if recipe.HeadId == headId then return recipe end
	end
	return nil
end

local function canUseForge(player)
	local check = BaseStationAccess.CanUseForge
	-- Until the server-owned Forge station/API is installed, crafting fails closed.
	return type(check) == "function" and check(player) == true
end

local function validOutputDefinition(recipe)
	local info = itemDataBase.Info[recipe.OutputItemID]
	local template = itemDataBase.Instances[recipe.OutputItemID]
	return info ~= nil
		and info.Type == "Weapon"
		and template ~= nil
		and template:IsA("Tool")
end

local function buildOwnedAxes(profile)
	local axes = {}
	local equippedWeapon = profile.Data.Equipped and profile.Data.Equipped.Weapon
	for _, item in ipairs(profile.Data.Inventory or {}) do
		if type(item) ~= "table" or type(item.UID) ~= "string" then continue end
		local info = itemDataBase.Info[item.ItemID]
		if not info or info.Type ~= "Weapon" then continue end
		local recipe = catalog.FindRecipeForOutput(item.ItemID)
		local attack = type(item.Stats) == "table" and item.Stats.Attack or 0
		if not isFiniteNumber(attack) then attack = 0 end
		table.insert(axes, {
			Id = recipe and recipe.Id or ("item_" .. tostring(item.ItemID)),
			Name = info.Name,
			Power = catalog.BaseAttack + attack,
			ItemID = item.ItemID,
			UID = item.UID,
			Owned = true,
			Equipped = equippedWeapon == item.UID,
			Tier = recipe and recipe.Tier or nil,
		})
	end
	return axes
end

local function buildShopSnapshot(player, profile)
	local data = profile.Data
	local progression = data.RunProgress
	local standardTier = progression and progression.StandardAxeTier or 0
	if not isFiniteNumber(standardTier) or standardTier < 0 or standardTier % 1 ~= 0 then
		standardTier = 0
	end
	local headCounts = type(data.AxeHeads) == "table" and data.AxeHeads or {}
	local coins = isFiniteNumber(data.Coins) and data.Coins or 0
	local atAxeShop = BaseStationAccess.CanUseAxeShop(player)
	local atForge = canUseForge(player)
	local axeHeads = {}

	for _, head in ipairs(catalog.AxeHeads) do
		local unlocked = WorldProgressService.CanAccessForest(player, head.RequiredForestId)
		axeHeads[#axeHeads + 1] = {
			Id = head.Id,
			Name = head.Name,
			Price = head.Price,
			Count = headCounts[head.Id] or 0,
			RequiredForestId = head.RequiredForestId,
			Available = unlocked,
			CanBuy = unlocked and atAxeShop and coins >= head.Price,
		}
	end

	local recipes = {}
	for _, recipe in ipairs(catalog.StandardAxeRecipes) do
		local head = catalog.FindAxeHead(recipe.HeadId)
		local ownedHeadCount = head and (headCounts[head.Id] or 0) or 0
		local ownedWoodCount = LogService.CountCraftableLogs(player, recipe.Wood.SpeciesId)
		local outputOwned = getOwnedAxe(profile, recipe.OutputItemID) ~= nil
		local unlocked = WorldProgressService.CanAccessForest(player, recipe.RequiredForestId)
		local atNextTier = standardTier + 1 == recipe.Tier
		local outputDefined = validOutputDefinition(recipe)
		recipes[#recipes + 1] = {
			Id = recipe.Id,
			Name = recipe.Name,
			Tier = recipe.Tier,
			Power = recipe.Power,
			HeadId = recipe.HeadId,
			HeadName = head and head.Name or recipe.HeadId,
			HeadRequired = 1,
			HeadOwned = ownedHeadCount,
			WoodSpeciesId = recipe.Wood.SpeciesId,
			WoodRequired = recipe.Wood.Count,
			WoodOwned = ownedWoodCount,
			OutputOwned = outputOwned,
			Unlocked = unlocked,
			AtNextTier = atNextTier,
			AtForge = atForge,
			CanCraft = atForge
				and unlocked
				and atNextTier
				and not outputOwned
				and outputDefined
				and ownedHeadCount >= 1
				and ownedWoodCount >= recipe.Wood.Count,
		}
	end

	local upgrades = {}
	for _, entry in ipairs(catalog.CapacityUpgrades) do
		upgrades[#upgrades + 1] = {
			Capacity = entry.Capacity,
			Price = entry.Price,
		}
	end

	local unlockedForests = {}
	if progression and type(progression.UnlockedForests) == "table" then
		for forestId, unlocked in pairs(progression.UnlockedForests) do
			if type(forestId) == "string" and type(unlocked) == "boolean" then
				unlockedForests[forestId] = unlocked
			end
		end
	end

	return {
		Coins = coins,
		Capacity = isFiniteNumber(data.LogCapacity) and data.LogCapacity or 10,
		AxeHeads = axeHeads,
		Recipes = recipes,
		-- Axes are now owned inventory only. The Axe Shop no longer exposes a
		-- purchasable list of finished progression weapons.
		Axes = buildOwnedAxes(profile),
		CapacityUpgrades = upgrades,
		StandardAxeTier = standardTier,
		UnlockedForests = unlockedForests,
	}
end

getShopData.OnServerInvoke = function(player, ...)
	if select("#", ...) ~= 0 then return nil end
	local profile = profileCache.GetProfile(player)
	if not profile or not profile.Data or not profile.Data.Runtime then return nil end
	return buildShopSnapshot(player, profile)
end

purchaseAxeHead.OnServerEvent:Connect(function(player, headId, ...)
	if select("#", ...) ~= 0 or not takeBudget(player, "PurchaseAxeHead") then return end
	if typeof(headId) ~= "string" or #headId < 1 or #headId > 64 then return end
	if not BaseStationAccess.CanUseAxeShop(player) then return end
	local profile, data = getProfileData(player)
	if not profile then return end

	local head = catalog.FindAxeHead(headId)
	if not head or not isFiniteNumber(head.Price) or head.Price <= 0 then return end
	if not WorldProgressService.CanAccessForest(player, head.RequiredForestId) then return end
	if type(data.AxeHeads) ~= "table" then return end
	local count = data.AxeHeads[head.Id]
	if not isFiniteNumber(count) or count < 0 or count % 1 ~= 0 then return end
	local coins = data.Coins
	if not isFiniteNumber(coins) or coins < head.Price then return end

	-- Head ownership is material state only. This mutation does not create a
	-- weapon, change the current-run tier, or unlock another forest.
	data.Coins = coins - head.Price
	data.AxeHeads[head.Id] = count + 1
	economyUpdated:FireClient(player, "Coins", data.Coins)
	economyUpdated:FireClient(player, "Progression")
end)

craftRecipe.OnServerEvent:Connect(function(player, recipeId, ...)
	if select("#", ...) ~= 0 or not takeBudget(player, "CraftRecipe") then return end
	if typeof(recipeId) ~= "string" or #recipeId < 1 or #recipeId > 64 then return end
	if not canUseForge(player) then return end
	local profile, data = getProfileData(player)
	if not profile then return end

	local recipe = catalog.FindStandardAxeRecipe(recipeId)
	if not recipe or not validOutputDefinition(recipe) then return end
	local progress = data.RunProgress
	if type(progress) ~= "table"
		or not isFiniteNumber(progress.StandardAxeTier)
		or progress.StandardAxeTier < 0
		or progress.StandardAxeTier % 1 ~= 0 then
		return
	end
	if recipe.Tier ~= progress.StandardAxeTier + 1 then return end
	if not WorldProgressService.CanAccessForest(player, recipe.RequiredForestId) then return end
	if getOwnedAxe(profile, recipe.OutputItemID) then return end

	local head = catalog.FindAxeHead(recipe.HeadId)
	if not head or type(data.AxeHeads) ~= "table" then return end
	local headCount = data.AxeHeads[head.Id]
	if not isFiniteNumber(headCount) or headCount < 1 or headCount % 1 ~= 0 then return end

	-- The server selects exact owned UIDs. Locked, mutated, or still-arriving
	-- pickup records are not eligible for deterministic standard recipes.
	local logUids = LogService.GetCraftableLogUIDs(player, recipe.Wood.SpeciesId, recipe.Wood.Count)
	if not logUids or #logUids ~= recipe.Wood.Count then return end

	local itemRecord = {
		ItemID = recipe.OutputItemID,
		UID = HttpService:GenerateGUID(false),
		Stats = { Attack = math.max(0, recipe.Power - catalog.BaseAttack) },
		Substat = {},
		Rarity = "Common",
	}
	-- Begin a silent transaction: reserve/remove only the exact validated logs,
	-- then update the head and tier before the inventory path can notify the client.
	-- The BindableFunction handler is synchronous and contains no waits/yields.
	local removedLogs = LogService.TakeCraftableLogUIDs(player, recipe.Wood.SpeciesId, logUids)
	if not removedLogs then return end
	local previousTier = progress.StandardAxeTier
	data.AxeHeads[head.Id] = headCount - 1
	progress.StandardAxeTier = recipe.Tier

	local invokeOk, added = pcall(function()
		return addShopItem:Invoke(player, itemRecord)
	end)
	if not invokeOk or added ~= true then
		data.AxeHeads[head.Id] = headCount
		progress.StandardAxeTier = previousTier
		if not LogService.RestoreCraftableLogRecords(player, removedLogs) then
			warn(string.format("Could not roll back source logs after failed %s craft for %s", recipe.Id, player.Name))
		end
		return
	end

	-- Publish one coherent final resource snapshot only after the same inventory
	-- path confirms that the finished weapon exists in profile/runtime inventory.
	LogService.NotifyState(player)
	economyUpdated:FireClient(player, "Progression")
end)

purchaseCapacity.OnServerEvent:Connect(function(player, requestedCapacity, ...)
	if select("#", ...) ~= 0 then return end
	if not takeBudget(player, "PurchaseCapacity") then return end
	if not BaseStationAccess.CanUseAxeShop(player) then return end
	local profile, data = getProfileData(player)
	if not profile then return end
	if not isFiniteNumber(requestedCapacity) or requestedCapacity % 1 ~= 0 then return end

	local currentCapacity = data.LogCapacity
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

	local coins = data.Coins
	if not isFiniteNumber(coins) or coins < upgrade.Price then return end
	data.Coins = coins - upgrade.Price
	data.LogCapacity = upgrade.Capacity
	economyUpdated:FireClient(player, "Coins", data.Coins)
	LogService.NotifyState(player)
end)

Players.PlayerRemoving:Connect(function(player)
	nextRequestAt[player] = nil
end)
