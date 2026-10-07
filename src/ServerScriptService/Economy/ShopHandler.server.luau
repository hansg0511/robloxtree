-- Server-authoritative axe-head purchases, standard-axe crafting, and bag upgrades.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local profileCache = require(ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local itemDataBase = require(game.ServerStorage.Items.ItemDataBase)
local catalog = require(script.Parent.AxeShopCatalog)
local MaterialDefinitions = require(script.Parent.MaterialDefinitions)
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

local function isNonnegativeInteger(value)
	return isFiniteNumber(value) and value >= 0 and value % 1 == 0
end

local function getProfileData(player)
	local profile = profileCache.GetProfile(player)
	if not profile or type(profile.Data) ~= "table" or type(profile.Data.Runtime) ~= "table" then
		return nil, nil
	end
	profileCache.NormalizeCarryCapacity(profile.Data)
	return profile, profile.Data
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
	local data = profile.Data
	local runtime = type(data.Runtime) == "table" and data.Runtime or nil
	local equippedWeapon = runtime and runtime.EquippedWeaponUID
		or (data.Equipped and data.Equipped.Weapon)
	for _, item in ipairs(profile.Data.Inventory or {}) do
		if type(item) ~= "table" or type(item.UID) ~= "string" then continue end
		-- ItemID 9001 is session-only. A stale saved copy must not make the
		-- debug axe visible outside the allowlisted runtime injection path.
		if item.ItemID == 9001 then continue end
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
			Tier = catalog.ResolveAxeTier(item),
		})
	end

	-- The debug axe lives only in the server runtime, so expose that exact
	-- ephemeral record in the same snapshot used by the normal AXES UI.
	local debugUID = runtime and runtime.DebugProAxeUID
	local debugWeapon = type(debugUID) == "string"
		and type(runtime.EphemeralWeaponUIDs) == "table"
		and runtime.EphemeralWeaponUIDs[debugUID] == true
		and type(runtime.Weapon) == "table"
		and runtime.Weapon[debugUID]
		or nil
	local debugInfo = debugWeapon and itemDataBase.Info[debugWeapon.ItemID]
	local debugTemplate = debugWeapon and itemDataBase.Instances[debugWeapon.ItemID]
	if debugWeapon
		and debugWeapon.ItemType == "Weapon"
		and debugWeapon.ItemUID == debugUID
		and debugWeapon.ItemID == 9001
		and type(debugWeapon.WeaponData) == "table"
		and debugWeapon.WeaponData.DebugOnly == true
		and debugInfo
		and debugTemplate
		and debugTemplate:IsA("Tool")
		and debugWeapon.InstanceName == debugTemplate.Name then
		local alreadyListed = false
		for _, axe in ipairs(axes) do
			if axe.UID == debugUID then
				alreadyListed = true
				break
			end
		end
		if not alreadyListed then
			local attack = type(debugWeapon.ItemStats) == "table" and debugWeapon.ItemStats.Attack or 0
			if not isFiniteNumber(attack) then attack = 0 end
			table.insert(axes, {
				Id = "debug_pro_axe",
				Name = debugInfo.Name,
				Power = catalog.BaseAttack + attack,
				ItemID = debugWeapon.ItemID,
				UID = debugUID,
				Owned = true,
				Equipped = equippedWeapon == debugUID,
				Tier = catalog.ResolveAxeTier(debugWeapon),
			})
		end
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
		local headCount = headCounts[head.Id]
		if not isNonnegativeInteger(headCount) then headCount = 0 end
		axeHeads[#axeHeads + 1] = {
			Id = head.Id,
			Name = head.Name,
			Price = head.Price,
			Count = headCount,
			RequiredForestId = head.RequiredForestId,
			Available = unlocked,
			CanBuy = unlocked and atAxeShop and coins >= head.Price,
		}
	end

	local recipes = {}
	local eligibleCraftLogs = LogService.GetEligibleCraftLogs(player)
	for _, recipe in ipairs(catalog.StandardAxeRecipes) do
		local head = catalog.FindAxeHead(recipe.HeadId)
		local ownedHeadCount = head and headCounts[head.Id] or 0
		if not isNonnegativeInteger(ownedHeadCount) then ownedHeadCount = 0 end
		local unlocked = WorldProgressService.CanAccessForest(player, recipe.RequiredForestId)
		local progressionValid = recipe.Tier <= standardTier or recipe.Tier == standardTier + 1
		local outputDefined = validOutputDefinition(recipe)
		recipes[#recipes + 1] = {
			Id = recipe.Id,
			Name = recipe.Name,
			Tier = recipe.Tier,
			HeadId = recipe.HeadId,
			HeadName = head and head.Name or recipe.HeadId,
			HeadOwned = ownedHeadCount,
			RequiredLogCount = recipe.RequiredLogCount,
			HeadBasePower = recipe.HeadBasePower,
			RequiredForestId = recipe.RequiredForestId,
			Unlocked = unlocked,
			ProgressionValid = progressionValid,
			AtForge = atForge,
			CanCraft = atForge
				and unlocked
				and progressionValid
				and outputDefined
				and ownedHeadCount >= 1,
		}
	end

	local upgrades = {}
	for _, entry in ipairs(catalog.CapacityUpgrades) do
		upgrades[#upgrades + 1] = {
			CapacityKg = entry.CapacityKg,
			Price = entry.Price,
		}
	end
	local capacityState = LogService.GetCapacitySnapshot(player)

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
		ItemCount = capacityState and capacityState.ItemCount or 0,
		UsedKg = capacityState and capacityState.UsedKg or 0,
		CarryCapacityKg = capacityState and capacityState.CarryCapacityKg or catalog.DEFAULT_CAPACITY_KG,
		RemainingKg = capacityState and capacityState.RemainingKg or catalog.DEFAULT_CAPACITY_KG,
		AxeHeads = axeHeads,
		Recipes = recipes,
		EligibleCraftLogs = eligibleCraftLogs,
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

local function isExactUidSelection(value, expectedCount)
	if type(value) ~= "table" or type(expectedCount) ~= "number" or expectedCount < 1
		or expectedCount % 1 ~= 0 then
		return false
	end
	local count = 0
	local maxIndex = 0
	for key in pairs(value) do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return false end
		count += 1
		maxIndex = math.max(maxIndex, key)
	end
	if count ~= expectedCount or maxIndex ~= expectedCount then return false end
	local seen = {}
	for index = 1, expectedCount do
		local uid = value[index]
		if typeof(uid) ~= "string" or #uid < 1 or #uid > 80 or seen[uid] then return false end
		seen[uid] = true
	end
	return true
end

local function cloneMutationValue(value, seen)
	local valueType = type(value)
	if valueType == "string" or valueType == "number" or valueType == "boolean" then
		return value
	end
	if valueType ~= "table" or seen[value] then return nil end
	local copy = {}
	seen[value] = true
	for key, child in pairs(value) do
		local keyType = type(key)
		if keyType == "string" or keyType == "number" then
			local childCopy = cloneMutationValue(child, seen)
			if childCopy ~= nil then copy[key] = childCopy end
		end
	end
	seen[value] = nil
	return copy
end

local function cloneMutations(mutations)
	if type(mutations) ~= "table" then return {} end
	return cloneMutationValue(mutations, {}) or {}
end

local function restoreCraftLogs(player, recipe, removedLogs)
	local restoreOk, restored = pcall(function()
		return LogService.RestoreCraftLogRecords(player, removedLogs)
	end)
	if not restoreOk or restored ~= true then
		warn(string.format("Could not roll back source logs after failed %s craft for %s", recipe.Id, player.Name))
	end
end

craftRecipe.OnServerEvent:Connect(function(player, recipeId, selectedLogUids, ...)
	if select("#", ...) ~= 0 or not takeBudget(player, "CraftRecipe") then return end
	if typeof(recipeId) ~= "string" or #recipeId < 1 or #recipeId > 64 then return end
	local recipe = catalog.FindStandardAxeRecipe(recipeId)
	if not recipe or not isExactUidSelection(selectedLogUids, recipe.RequiredLogCount) then return end
	if not canUseForge(player) then return end
	local profile, data = getProfileData(player)
	if not profile then return end
	if not validOutputDefinition(recipe)
		or not isFiniteNumber(recipe.HeadBasePower)
		or recipe.RequiredLogCount < 1
		or recipe.RequiredLogCount % 1 ~= 0 then
		return
	end

	local progress = data.RunProgress
	if type(progress) ~= "table"
		or not isFiniteNumber(progress.StandardAxeTier)
		or progress.StandardAxeTier < 0
		or progress.StandardAxeTier % 1 ~= 0 then
		return
	end
	local previousTier = progress.StandardAxeTier
	local progressionValid = recipe.Tier <= previousTier or recipe.Tier == previousTier + 1
	if not progressionValid then return end
	if not WorldProgressService.CanAccessForest(player, recipe.RequiredForestId) then return end

	local head = catalog.FindAxeHead(recipe.HeadId)
	if not head or type(data.AxeHeads) ~= "table" then return end
	local headCount = data.AxeHeads[head.Id]
	if not isFiniteNumber(headCount) or headCount < 1 or headCount % 1 ~= 0 then return end

	-- Exact selection is revalidated against authoritative logs in this atomic
	-- take. Mutation data remains attached to the original records for metadata.
	local removedLogs = LogService.TakeCraftLogUIDs(player, selectedLogUids, recipe.RequiredLogCount)
	if not removedLogs or #removedLogs ~= recipe.RequiredLogCount then return end

	local bonusTotal = 0
	local sourceMaterials = {}
	for _, logRecord in ipairs(removedLogs) do
		local definition = type(logRecord) == "table" and MaterialDefinitions.Get(logRecord.SpeciesId) or nil
		if logRecord.ItemType ~= "Log"
			or not definition
			or not isFiniteNumber(definition.CraftPowerBonus) then
			restoreCraftLogs(player, recipe, removedLogs)
			return
		end
		bonusTotal += definition.CraftPowerBonus
		table.insert(sourceMaterials, {
			SourceUID = logRecord.UID,
			SpeciesId = logRecord.SpeciesId,
			Mutations = cloneMutations(logRecord.Mutations),
		})
	end

	local finalPower = math.floor((recipe.HeadBasePower + bonusTotal / #removedLogs) * 10 + 0.5) / 10
	local itemRecordOk, itemRecord = pcall(function()
		return {
			ItemID = recipe.OutputItemID,
			UID = HttpService:GenerateGUID(false),
			Stats = { Attack = finalPower - catalog.BaseAttack },
			Substat = {},
			Rarity = "Common",
			WeaponData = {
				AxeTier = recipe.Tier,
				HeadId = recipe.HeadId,
				CraftedPower = finalPower,
				Materials = sourceMaterials,
			},
		}
	end)
	if not itemRecordOk or type(itemRecord) ~= "table" then
		restoreCraftLogs(player, recipe, removedLogs)
		return
	end

	-- Keep head and progression writes silent until the output path succeeds.
	data.AxeHeads[head.Id] = headCount - 1
	progress.StandardAxeTier = math.max(previousTier, recipe.Tier)

	local invokeOk, added = pcall(function()
		return addShopItem:Invoke(player, itemRecord)
	end)
	if not invokeOk or added ~= true then
		data.AxeHeads[head.Id] = headCount
		progress.StandardAxeTier = previousTier
		restoreCraftLogs(player, recipe, removedLogs)
		return
	end

	-- Publish the final resources only after inventory insertion succeeded.
	LogService.NotifyState(player)
	economyUpdated:FireClient(player, "Progression")
end)

purchaseCapacity.OnServerEvent:Connect(function(player, requestedCapacityKg, ...)
	if select("#", ...) ~= 0 then return end
	if not takeBudget(player, "PurchaseCapacity") then return end
	if not BaseStationAccess.CanUseAxeShop(player) then return end
	local profile, data = getProfileData(player)
	if not profile then return end
	if not isFiniteNumber(requestedCapacityKg) or requestedCapacityKg % 1 ~= 0 then return end

	profileCache.NormalizeCarryCapacity(data)
	local currentCapacityKg = data.CarryCapacityKg
	local upgrade = catalog.FindNextCapacityUpgrade(currentCapacityKg)
	if not upgrade or upgrade.CapacityKg ~= requestedCapacityKg then return end

	local coins = data.Coins
	if not isFiniteNumber(coins) or coins < upgrade.Price then return end
	data.Coins = coins - upgrade.Price
	data.CarryCapacityKg = upgrade.CapacityKg
	economyUpdated:FireClient(player, "Coins", data.Coins)
	LogService.NotifyState(player)
end)

Players.PlayerRemoving:Connect(function(player)
	nextRequestAt[player] = nil
end)
