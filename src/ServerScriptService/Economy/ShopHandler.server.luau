-- Server-authoritative axe-head purchases, standard-axe crafting, and bag upgrades.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ExperimentalForgeRules = require(ReplicatedStorage.Shared.ExperimentalForgeRules)
local ForgeMutations = require(ReplicatedStorage.Shared.ForgeMutationRules)
local WeaponEffects = require(game.ServerScriptService.WeaponEffects.Dispatcher)
local ProgressionRules = require(game.ServerScriptService.WeaponProgressionRules)
local WeaponAscensionService = require(game.ServerScriptService.WeaponAscensionService)
local WeaponUpgradeService = require(script.Parent.WeaponUpgradeService)
local SlotRules=require(script.Parent.WeaponUpgradeRules)
local Premium=require(ReplicatedStorage.Shared.PremiumEconomyConfig)
local WeaponRarityRoll = require(game.ServerScriptService.WeaponRarityRoll)
local ServerScriptService = game:GetService("ServerScriptService")

local profileCache = require(ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local itemDataBase = require(game.ServerStorage.Items.ItemDataBase)
local catalog = require(script.Parent.AxeShopCatalog)
local WeaponRecipeRules = require(script.Parent.WeaponRecipeRules)
local MaterialDefinitions = require(script.Parent.MaterialDefinitions)
local LogService = require(ServerScriptService.Inventory.LogService)
local StudioForgeSandbox = require(script.Parent.StudioForgeSandbox)
local LogStorageRules = require(ServerScriptService.Inventory.LogStorageRules)
local WorldProgressService = require(ServerScriptService.WorldProgressService)
local BaseStationAccess = require(ServerScriptService.WorldLayout.BaseStationAccess)

local economyRemotes = ReplicatedStorage:WaitForChild("Economy")
local getShopData = economyRemotes:WaitForChild("GetShopDataRF")
local buyCrystals=economyRemotes:WaitForChild("BuyAscensionCrystalsRE")
local purchaseAxeHead = economyRemotes:WaitForChild("PurchaseAxeHeadRE")
local craftRecipe = economyRemotes:WaitForChild("CraftRecipeRE")
local purchaseCapacity = economyRemotes:WaitForChild("PurchaseCapacityRE")
local economyUpdated = economyRemotes:WaitForChild("EconomyUpdated")
local ascendWeapon = economyRemotes:WaitForChild("AscendWeaponRE")
local upgradeForge = economyRemotes:WaitForChild("UpgradeForgeRE")
local upgradeWeapon = economyRemotes:WaitForChild("UpgradeWeaponRE")

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

local function canUseForge(player)
	local check = BaseStationAccess.CanUseForge
	-- Until the server-owned Forge station/API is installed, crafting fails closed.
	return type(check) == "function" and check(player) == true
end

-- Prototype recipes use existing Tool templates until distinct weapon models exist.
local function validExperimentalOutputs(recipe)
	if type(recipe) ~= "table" or type(recipe.Outputs) ~= "table" then return false end
	for _, class in ipairs(ExperimentalForgeRules.CLASSES) do
		local itemId = recipe.Outputs[class]
		local info = itemDataBase.Info[itemId]
		local tool = itemDataBase.Instances[itemId]
		if not info or info.Type ~= "Weapon" or not tool or not tool:IsA("Tool") then
			return false
		end
	end
	return true
end

-- Only send display-safe weapon metadata. Future mutation abilities can
-- extend this list without changing the inventory screen's layout.
local KNOWN_MUTATIONS = { "Golden", "Frenzied", "Shocked", "Crystal", "Giant" }

local function materialMutationSummary(materials)
	if type(materials) ~= "table" then return {}, nil end
	local total = #materials
	if total == 0 then return {}, 0 end
	local summary = {}
	for _, name in ipairs(KNOWN_MUTATIONS) do
		local count, weightedQuality = 0, 0
		for _, material in ipairs(materials) do
			if type(material) == "table" and type(material.Mutations) == "table"
				and material.Mutations[name] == true then
				count += 1
				local size = material.SizeScale
				if isFiniteNumber(size) and size > 0 then
					weightedQuality += math.clamp(
						size / ExperimentalForgeRules.MAX_LOG_SIZE, 0, 1)
				end
			end
		end
		if count > 0 then
			table.insert(summary, {
				Name = name,
				LogCount = count,
				MaterialQuality = weightedQuality / total,
			})
		end
	end
	return summary, total
end

local function buildOwnedAxes(player, profile, eligibleAscensionLogs)
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
		local weaponData = type(item.WeaponData) == "table" and item.WeaponData or nil
		local mutationMaterials, materialCount = materialMutationSummary(
			weaponData and weaponData.Materials)
		local rarity = if ProgressionRules.IsRarity(item.Rarity)
			then item.Rarity else "Common"
		local progression = ProgressionRules.NormalizeProgression(
			weaponData and weaponData.Progression, rarity)
		local level = progression.Level
		local ascension = WeaponAscensionService.Preview(player, item, eligibleAscensionLogs)
		local experimentalClass = weaponData and weaponData.ExperimentalClass
		local experimentalName = if (experimentalClass == "Dagger"
			or experimentalClass == "Axe" or experimentalClass == "Battlehammer")
			and (weaponData.Metal == "Copper" or weaponData.Metal == "Iron")
			then weaponData.Metal .. " " .. experimentalClass else nil
		-- Identifiable temporary test axes, without changing real names or
		-- persisting any customer-visible nickname in published gameplay.
		if RunService:IsStudio() and type(weaponData)=="table"
			and (weaponData.DevUpgradeTestLabel=="AWAKEN TEST (RARE)"
				or weaponData.DevUpgradeTestLabel=="INFUSE TEST (LEGENDARY)") then
			experimentalName=weaponData.DevUpgradeTestLabel
		end
		if RunService:IsStudio() and weaponData and weaponData.DevCadenceFixture == true then
			experimentalName = "TEST • " .. tostring(experimentalClass)
		end
		table.insert(axes, {
			Id = recipe and recipe.Id or ("item_" .. tostring(item.ItemID)),
			Name = experimentalName or info.Name,
			Power = catalog.BaseAttack + attack
				+ ProgressionRules.DerivedAttackBonus(item, catalog.BaseAttack),
			Rarity = rarity,
			Level = level,
			LevelCap = ProgressionRules.GetLevelCap(rarity),
			XP = progression.XP,
			XPToNextLevel = ProgressionRules.XPToNextLevel(rarity, level),
			Ascension = ascension,
			Experimental = experimentalName ~= nil,
			WeaponKind = weaponData and weaponData.WeaponKind,
			MaterialQuality = weaponData and weaponData.MaterialQuality,
			ForgedQuality = weaponData and weaponData.ForgedQuality,
			QuantityQualityMultiplier = weaponData and weaponData.QuantityQualityMultiplier,
			AttacksPerSecond = weaponData and weaponData.AttacksPerSecond,
			Reach = weaponData and weaponData.Reach,
			GoldenQuality = weaponData and weaponData.GoldenQuality,
			GoldenBonus = weaponData and weaponData.GoldenBonus,
			MutationAbility = weaponData and weaponData.MutationAbility,
			MutationSlots = weaponData and weaponData.MutationSlots,
			Upgrade = WeaponUpgradeService.Preview(player, item),
			Effects = WeaponEffects.List(weaponData),
			MaterialCount = materialCount,
			MutationMaterials = mutationMaterials,
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
				Rarity = "Debug", -- session-only item has no natural rarity or XP
				Effects = WeaponEffects.List(debugWeapon.WeaponData),
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
	local forgeLevel = progression and progression.ForgeLevel or 1
	if not isNonnegativeInteger(forgeLevel) or not ForgeMutations.Tier(forgeLevel) then forgeLevel = 1 end
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
	for _, recipe in ipairs(catalog.ExperimentalForgeRecipes) do
		local head = catalog.FindAxeHead(recipe.HeadId)
		local count = head and headCounts[head.Id] or 0
		if not isNonnegativeInteger(count) then count = 0 end
		local unlocked = WorldProgressService.CanAccessForest(player, recipe.RequiredForestId)
		local progressionValid = true -- no mandatory intermediate crafted metal
		recipes[#recipes + 1] = {
			Id = recipe.Id, Name = recipe.Name, Experimental = true,
			Tier = recipe.Tier,
			HeadId = recipe.HeadId,
			HeadName = head and head.Name or recipe.HeadId,
			HeadOwned = count,
			HeadBasePower = recipe.HeadBasePower,
			RequiredLogCount = 1, -- minimum, not exact quantity
			MaxLogCount = ExperimentalForgeRules.MAX_OFFERED_LOGS,
			RequiredForestId = recipe.RequiredForestId,
			Unlocked = unlocked, ProgressionValid = progressionValid,
			AtForge = atForge,
			CanCraft = atForge and unlocked and progressionValid
				and forgeLevel >= recipe.Tier
				and validExperimentalOutputs(recipe) and count >= 1,
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
		-- Own unique nonlog materials are previewed by UID and kind. A UI
		-- selection never authorizes consumption; the server checks again.
		UpgradeBalances = (function()
			local counts={}
			for id,count in pairs(type(data.MaterialBalances)=="table" and data.MaterialBalances or {}) do
				if type(id)=="string" and #id<=80
					and isNonnegativeInteger(count) then
					counts[id]=count
				end
			end
			return counts
		end)(),
		UpgradeMaterials = (function()
			local materials = {}
			for _,record in ipairs(type(data.GroveMaterials)=="table" and data.GroveMaterials or {}) do
				if type(record)=="table" and type(record.UID)=="string"
					and type(record.MaterialType)=="string" then
					materials[#materials+1]={
						UID=record.UID,MaterialType=record.MaterialType,
					}
				end
			end
			return materials
		end)(),
		-- Axes are now owned inventory only. The Axe Shop no longer exposes a
		-- purchasable list of finished progression weapons.
		Axes = buildOwnedAxes(player, profile, #WeaponAscensionService.EligibleLogs(player)),
		CapacityUpgrades = upgrades,
		StandardAxeTier = standardTier,
		ForgeLevel = forgeLevel,
		ForgePotencyCap = ForgeMutations.Tier(forgeLevel).PotencyCap,
		ForgeMutatedLogLimit = ForgeMutations.Tier(forgeLevel).MaxMutatedLogs,
		ForgeRarityWeights = WeaponRarityRoll.WeightsForLevel(forgeLevel),
		ForgeUpgrade = if ForgeMutations.NextUpgrade(forgeLevel) then {
			ToLevel = forgeLevel + 1,
			CoinCost = ForgeMutations.NextUpgrade(forgeLevel).CoinCost,
			CanUpgrade = atForge and coins >= ForgeMutations.NextUpgrade(forgeLevel).CoinCost,
		} else nil,
		UnlockedForests = unlockedForests,
	}
end

getShopData.OnServerInvoke = function(player, ...)
	if select("#", ...) ~= 0 then return nil end
	local profile = profileCache.GetProfile(player)
	if not profile or not profile.Data or not profile.Data.Runtime then return nil end
	-- Keep refill transparent to the normal forge snapshot: it must show
	-- real owned, uniquely identified records before any client selection.
	StudioForgeSandbox.Refill(player, profile.Data)
	return buildShopSnapshot(player, profile)
end

-- Persistent Forge upgrade. A client never chooses the paid tier/cost.
upgradeForge.OnServerEvent:Connect(function(player, ...)
	if select("#", ...) ~= 0 or not takeBudget(player, "UpgradeForge") then return end
	if not canUseForge(player) then return end
	local profile, data = getProfileData(player)
	if not profile or type(data.RunProgress) ~= "table" then return end
	local progress = data.RunProgress
	if not ForgeMutations.Tier(progress.ForgeLevel) then return end
	local upgrade = ForgeMutations.NextUpgrade(progress.ForgeLevel)
	if not upgrade then return end
	if not isFiniteNumber(data.Coins) or data.Coins < upgrade.CoinCost then return end
	data.Coins -= upgrade.CoinCost
	progress.ForgeLevel = upgrade.ToLevel
	economyUpdated:FireClient(player, "Coins", data.Coins)
	economyUpdated:FireClient(player, "ForgeUpgraded", { Level = progress.ForgeLevel })
	economyUpdated:FireClient(player, "Progression")
end)

-- Ascension request takes only a weapon UID. Costs, eligible logs, pity
-- and RNG remain server-owned; errors return a safe display reason.
ascendWeapon.OnServerEvent:Connect(function(player, uid, ...)
	if select("#", ...) ~= 0 or not takeBudget(player, "AscendWeapon") then return end
	if type(uid) ~= "string" or #uid < 1 or #uid > 128 then return end
	local ok, result = pcall(function()
		return WeaponAscensionService.Attempt(player, uid)
	end)
	if not ok then
		warn("[Ascension] transaction error:", result)
		ascendWeapon:FireClient(player, { Reason = "SERVER_ERROR" })
		return
	end
	ascendWeapon:FireClient(player, result)
	if result and result.Reason == "ATTEMPT_RESOLVED" then
		local profile = profileCache.GetProfile(player)
		if profile and type(profile.Data) == "table" then
			economyUpdated:FireClient(player, "Coins", profile.Data.Coins)
		end
		economyUpdated:FireClient(player, "Progression")
	end
end)

-- Awakening/Infusion are mutually exclusive transactions on ONE owned UID.
-- The client supplies selection intent only; the server validates every
-- price, mutation family, rarity, forge access and exact resource identity.
upgradeWeapon.OnServerEvent:Connect(function(player, uid, mode, family, selections, ...)
	if select("#",...)~=0 or not takeBudget(player,"UpgradeWeapon") then return end
	if type(uid)~="string" or #uid<1 or #uid>128
		or (mode~="Awaken" and mode~="Replace")
		or not table.find(ForgeMutations.FAMILIES,family)
		or type(selections)~="table" then return end
	local ok,result=pcall(function()
		return WeaponUpgradeService.Attempt(player,uid,mode,family,selections)
	end)
	if not ok then
		warn("[WeaponUpgrade] request failed:",result)
		upgradeWeapon:FireClient(player,{Reason="SERVER_ERROR"})
		return
	end
	upgradeWeapon:FireClient(player,result)
	if result and result.Reason=="UPGRADED" then
		local profile=profileCache.GetProfile(player)
		if profile and type(profile.Data)=="table" then
			economyUpdated:FireClient(player,"Coins",profile.Data.Coins)
		end
		economyUpdated:FireClient(player,"Progression")
	end
end)

-- Premium exchange is independent of gold; all prices server-owned.
buyCrystals.OnServerEvent:Connect(function(player,quantity,...)
	if select("#",...)~=0 or not takeBudget(player,"UpgradeWeapon") then return end
	if type(quantity)~="number" or quantity%1~=0 or quantity<1 or quantity>Premium.MAX_CRYSTAL_PURCHASE then return end
	local profile,data=getProfileData(player)
	if not profile or type(data.MaterialBalances)~="table" then return end
	local balances=data.MaterialBalances
	local price=quantity*Premium.CRYSTAL_PRICE
	if not isNonnegativeInteger(balances[Premium.PREMIUM]) or balances[Premium.PREMIUM]<price then
		buyCrystals:FireClient(player,{Success=false,Reason="NOT_ENOUGH_PREMIUM"}); return
	end
	local owned=balances[Premium.CRYSTAL] or 0
	if not isNonnegativeInteger(owned) or owned>1e12-quantity then buyCrystals:FireClient(player,{Success=false,Reason="BALANCE_INVALID"}); return end
	balances[Premium.PREMIUM]-=price
	balances[Premium.CRYSTAL]=owned+quantity
	buyCrystals:FireClient(player,{Success=true,Quantity=quantity})
	economyUpdated:FireClient(player,"PremiumBalances")
end)

purchaseAxeHead.OnServerEvent:Connect(function(player, headId, quantity, ...)
	if select("#", ...) ~= 0 or not takeBudget(player, "PurchaseAxeHead") then return end
	-- Accept legacy one-head requests; bound each transaction, not total stock.
	if quantity == nil then quantity = 1 end
	if not isNonnegativeInteger(quantity) or quantity < 1 or quantity > 1000 then return end
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
	local total = head.Price * quantity
	if not isFiniteNumber(total) or total <= 0 or not isFiniteNumber(coins)
		or coins < total or count + quantity > 1e12 then return end

	-- Atomic all-or-nothing purchase; head ownership is material state only.
	-- This does not create a weapon, change tier, or unlock another forest.
	data.Coins = coins - total
	data.AxeHeads[head.Id] = count + quantity
	economyUpdated:FireClient(player, "Coins", data.Coins)
	economyUpdated:FireClient(player, "Progression")
end)

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

local function restoreCraftLogs(player, recipe, removedLogs, sourceByUid)
	local restoreOk, restored = pcall(function()
		return LogService.RestoreCraftLogRecords(player, removedLogs, sourceByUid)
	end)
	if not restoreOk or restored ~= true then
		warn(string.format("Could not roll back source logs after failed %s craft for %s", recipe.Id, player.Name))
	end
end

-- Sole crafting transaction: server-authoritative RNG forge.
local function craftRng(player, recipe, selectedLogUids)
	if not canUseForge(player) then return end
	if type(selectedLogUids) ~= "table"
		or not ExperimentalForgeRules.ValidateCount(#selectedLogUids)
		or not WeaponRecipeRules.IsExactUidSelection(selectedLogUids, #selectedLogUids)
		or not validExperimentalOutputs(recipe) then return end

	local profile, data = getProfileData(player)
	if not profile or type(data.AxeHeads) ~= "table" then return end
	local progress = data.RunProgress
	if type(progress) ~= "table"
		or not isNonnegativeInteger(progress.StandardAxeTier) then return end
	local previousTier = progress.StandardAxeTier
	if not isNonnegativeInteger(progress.ForgeLevel)
		or progress.ForgeLevel < recipe.Tier then return end
	if not WorldProgressService.CanAccessForest(player, recipe.RequiredForestId) then return end
	local head = catalog.FindAxeHead(recipe.HeadId)
	if not head then return end
	local headCount = data.AxeHeads[head.Id]
	if not isNonnegativeInteger(headCount) or headCount < 1 then return end

	-- TakeCraftLogUIDs confirms ALL exact UIDs and their ownership server-side,
	-- across carry bag and protected storage. Never trust the client preview.
	local removedLogs, sourceByUid = LogService.TakeCraftLogUIDs(
		player, selectedLogUids, #selectedLogUids)
	if not removedLogs or #removedLogs ~= #selectedLogUids then return end

	local sourceMaterials = {}
	local rollLogs = {}
	for _, logRecord in ipairs(removedLogs) do
		if type(logRecord) ~= "table" or logRecord.ItemType ~= "Log"
			or not MaterialDefinitions.Get(logRecord.SpeciesId) then
			restoreCraftLogs(player, recipe, removedLogs, sourceByUid)
			return
		end
		local normalizedSize = LogStorageRules.SizeScale(logRecord)
		table.insert(rollLogs, {
			SpeciesId = logRecord.SpeciesId,
			SizeScale = normalizedSize,
			Mutations = logRecord.Mutations,
		})
		table.insert(sourceMaterials, {
			SourceUID = logRecord.UID,
			SpeciesId = logRecord.SpeciesId,
			SizeScale = normalizedSize,
			Source = sourceByUid[logRecord.UID],
			SourceType = logRecord.SourceType,
			SourceGroveTreeUID = logRecord.SourceGroveTreeUID,
			SourceSaplingUID = logRecord.SourceSaplingUID,
			Mutations = cloneMutations(logRecord.Mutations),
		})
	end

	-- ForgeLevel is the upgradeable workstation tier. recipe.Tier remains the
	-- material/forest tier and only gates access.
	local forgeLevel = progress.ForgeLevel
	local mutationPreview = ForgeMutations.Preview(rollLogs, forgeLevel)
	if not mutationPreview or mutationPreview.InvalidReason then
		restoreCraftLogs(player, recipe, removedLogs, sourceByUid)
		return
	end
	local mutationAbility = ForgeMutations.Roll(mutationPreview, forgeLevel, Random.new())
	local metal = if recipe.Tier == 1 then "Copper" else "Iron"
	local rollOk, result = pcall(function()
		return ExperimentalForgeRules.Roll(recipe.HeadBasePower,
			rollLogs, Random.new(), forgeLevel)
	end)
	if not rollOk or type(result) ~= "table" or not recipe.Outputs[result.Class] then
		restoreCraftLogs(player, recipe, removedLogs, sourceByUid)
		return
	end
	local power = math.floor(result.Damage * 10 + 0.5) / 10
	-- Rarity is a SEPARATE server roll, independent of logs/class/quality.
	-- Roll only after all material checks, restoring logs on failure.
	local rarity = WeaponRarityRoll.Roll(nil, forgeLevel)
	if not ProgressionRules.IsRarity(rarity) then
		restoreCraftLogs(player, recipe, removedLogs, sourceByUid)
		return
	end
	-- Assignment policy lives here, not inside the Cleave behavior module.
	-- Later another source (mutation, skill, upgrade) can grant the same
	-- validated effect without requiring the Battlehammer class.
	local grantedEffects = {}
	if result.CleaveDamageFraction and result.CleaveRadius then
		grantedEffects[1] = {
			Id = "Cleave",
			Trigger = "OnHit",
			Source = "WeaponClass",
			Params = {
				DamageFraction = result.CleaveDamageFraction,
				Radius = result.CleaveRadius,
			},
		}
	end
	if mutationAbility then
		grantedEffects[#grantedEffects + 1] = mutationAbility.Effect
	end
	local weapon = {
		ItemID = recipe.Outputs[result.Class],
		UID = HttpService:GenerateGUID(false),
		Stats = { Attack = math.max(0, power - catalog.BaseAttack) },
		Substat = {},
		Rarity = rarity,
		WeaponData = {
			RecipeId = recipe.Id,
			WeaponKind = result.Class,
			ExperimentalClass = result.Class,
			Metal = metal,
			AxeTier = recipe.Tier,
			HeadId = recipe.HeadId,
			CraftedPower = power,
			MaterialQuality = result.MaterialQuality,
			ForgedQuality = result.ForgedQuality,
			QuantityQualityMultiplier = result.QuantityQualityMultiplier,
			AverageEffectiveWoodStrength = result.AverageEffectiveWoodStrength,
			GoldenQuality = result.GoldenQuality,
			AverageWoodStrength = result.AverageWoodStrength,
			AttacksPerSecond = result.AttacksPerSecond,
			Reach = result.Reach,
			Effects = grantedEffects,
			MutationAbility = if mutationAbility then {
				Family = mutationAbility.Family, Id = mutationAbility.Id,
				Potency = mutationAbility.Potency, ForgeTier = mutationAbility.Tier,
			} else nil,
			GoldenBonus = result.GoldenBonus, -- legacy prototype metadata
			Materials = sourceMaterials,
		},
	}

	local grantedOk,granted=pcall(SlotRules.GrantSecond,weapon.WeaponData,rarity,forgeLevel,Random.new())
	if not grantedOk or not granted then restoreCraftLogs(player,recipe,removedLogs,sourceByUid); return end
	weapon.WeaponData=granted
	data.AxeHeads[head.Id] = headCount - 1
	progress.StandardAxeTier = math.max(previousTier, recipe.Tier)
	local ok, added = pcall(function()
		return addShopItem:Invoke(player, weapon)
	end)
	if not ok or added ~= true then
		data.AxeHeads[head.Id] = headCount
		progress.StandardAxeTier = previousTier
		restoreCraftLogs(player, recipe, removedLogs, sourceByUid)
		return
	end

	LogService.NotifyState(player)
	economyUpdated:FireClient(player, "ForgeResult", {
		Class = result.Class,
		Metal = metal,
		Rarity = rarity,
		Power = power + ProgressionRules.DerivedAttackBonus(weapon, catalog.BaseAttack),
		Quality = result.MaterialQuality,
		ForgedQuality = result.ForgedQuality,
		AbilityId = mutationAbility and mutationAbility.Id or nil,
	})
	economyUpdated:FireClient(player, "Progression")
end

craftRecipe.OnServerEvent:Connect(function(player, recipeId, selectedLogUids, ...)
	if select("#", ...) ~= 0 or not takeBudget(player, "CraftRecipe") then return end
	if typeof(recipeId) ~= "string" or #recipeId < 1 or #recipeId > 64 then return end
	-- Legacy fixed recipe IDs are intentionally no longer accepted.
	local recipe = catalog.FindExperimentalForgeRecipe(recipeId)
	if recipe then craftRng(player, recipe, selectedLogUids) end
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
