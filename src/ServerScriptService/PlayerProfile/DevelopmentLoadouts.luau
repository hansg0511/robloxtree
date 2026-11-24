-- Server-only development fixtures. New profiles never receive these values.
-- To opt a Studio account into one, add its numeric UserId below and choose a
-- preset. Keep this table empty before publishing.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local DevelopmentLoadouts = {}
local ForgeRules = require(game.ReplicatedStorage.Shared.ExperimentalForgeRules)
local AxeShopCatalog = require(game.ServerScriptService.Economy.AxeShopCatalog)

-- Enabled only in Studio's existing forge sandbox. A fresh session starts
-- unarmed, with the three reproducible weapons available in the normal bag.
DevelopmentLoadouts.COMBAT_FIXTURES_ENABLED = true
local COMBAT_FIXTURE_PREFIX = "dev-cadence-"

function DevelopmentLoadouts.ApplyCombatFixtures(player, data)
	if not RunService:IsStudio() or type(data) ~= "table"
		or type(data.Inventory) ~= "table" then return false end

	local sandbox = require(game.ServerScriptService.Economy.StudioForgeSandbox)
	-- Remove only this fixture family's old test records when refreshing the
	-- baseline or disabling it for a clean economy session.
	for i = #data.Inventory, 1, -1 do
		local item = data.Inventory[i]
		if type(item) == "table" and type(item.UID) == "string"
			and string.sub(item.UID, 1, #COMBAT_FIXTURE_PREFIX) == COMBAT_FIXTURE_PREFIX
			and type(item.WeaponData) == "table" and item.WeaponData.DevCadenceFixture == true then
			if type(data.Equipped) == "table" and data.Equipped.Weapon == item.UID then
				data.Equipped.Weapon = nil
			end
			table.remove(data.Inventory, i)
		end
	end
	if not DevelopmentLoadouts.COMBAT_FIXTURES_ENABLED or not sandbox.IsEnabled() then return false end

	local recipe = AxeShopCatalog.FindExperimentalForgeRecipe("experiment_copper")
	if not recipe then return false end
	local preview = ForgeRules.Preview(recipe.HeadBasePower, {
		{ SpeciesId = "Sapwood", SizeScale = 1, Mutations = {} },
	}, 1)
	if not preview then return false end
	local function midpoint(range)
		return (range.Min + range.Max) * 0.5
	end
	for _, class in ipairs(ForgeRules.CLASSES) do
		local range = preview.Ranges[class]
		local power = math.floor(midpoint(range.Damage) * 10 + 0.5) / 10
		local effects = {}
		if class == "Battlehammer" then
			effects[1] = { Id = "Cleave", Trigger = "OnHit", Source = "WeaponClass",
				Params = { DamageFraction = midpoint(range.CleaveDamageFraction),
					Radius = midpoint(range.CleaveRadius) } }
		end
		table.insert(data.Inventory, {
			ItemID = recipe.Outputs[class],
			UID = COMBAT_FIXTURE_PREFIX .. string.lower(class),
			Stats = { Attack = math.max(0, power - AxeShopCatalog.BaseAttack) },
			Substat = {},
			Rarity = "Common",
			WeaponData = {
				RecipeId = recipe.Id, WeaponKind = class, ExperimentalClass = class,
				Metal = "Copper", AxeTier = recipe.Tier, HeadId = recipe.HeadId,
				CraftedPower = power, MaterialQuality = preview.MaterialQuality,
				AverageWoodStrength = preview.AverageWoodStrength,
				AttacksPerSecond = midpoint(range.AttacksPerSecond),
				Reach = midpoint(range.Reach), Effects = effects,
				Progression = { Level = 1, XP = 0 },
				Materials = {}, DevCadenceFixture = true,
			},
		})
	end
	return true
end

DevelopmentLoadouts.STUDIO_PRESET_BY_USER_ID = {
	-- [123456789] = "Strong",
}

DevelopmentLoadouts.GROVE_SAPLINGS_USER_IDS = {
}

-- Resolve this named development account to its server-issued numeric ID once.
-- The grant still checks the numeric allowlist and only runs in Studio.
local GROVE_SAPLINGS_DEVELOPER_NAME = "ForsakenDemonz"
local groveAllowlistState = "unresolved"
local groveAllowlistResolved = Instance.new("BindableEvent")

local function resolveGroveSaplingDeveloper(player)
	if player.Name ~= GROVE_SAPLINGS_DEVELOPER_NAME then return false end
	if groveAllowlistState == "resolving" then
		groveAllowlistResolved.Event:Wait()
	elseif groveAllowlistState == "unresolved" then
		groveAllowlistState = "resolving"
		local ok, userId = pcall(function()
			return Players:GetUserIdFromNameAsync(GROVE_SAPLINGS_DEVELOPER_NAME)
		end)
		if ok and typeof(userId) == "number" and userId > 0 and userId % 1 == 0 then
			DevelopmentLoadouts.GROVE_SAPLINGS_USER_IDS[userId] = true
		else
			warn("[DevelopmentLoadouts] Could not resolve the Grove sapling developer allowlist")
		end
		groveAllowlistState = "resolved"
		groveAllowlistResolved:Fire()
	end
	return player:IsDescendantOf(Players)
		and DevelopmentLoadouts.GROVE_SAPLINGS_USER_IDS[player.UserId] == true
end

local PRESETS = {
	Weak = {
		Inventory = {
			{
				ItemID = 101,
				UID = "dev-weak-basic-axe",
				Stats = { Attack = 1 },
				Substat = {},
				Rarity = "Common",
			},
		},
		EquippedWeapon = "dev-weak-basic-axe",
	},
	Strong = {
		Inventory = {
			{
				ItemID = 101,
				UID = "dev-strong-basic-axe",
				Stats = { Attack = 250, CritChance = 20, CritDamage = 300 },
				Substat = { Attack = 50 },
				Rarity = "Common",
			},
		},
		EquippedWeapon = "dev-strong-basic-axe",
	},
}

local function copyInventory(inventory)
	local copy = {}
	for index, item in ipairs(inventory) do
		copy[index] = {
			ItemID = item.ItemID,
			UID = item.UID,
			Stats = table.clone(item.Stats),
			Substat = table.clone(item.Substat),
			Rarity = item.Rarity,
		}
	end
	return copy
end

function DevelopmentLoadouts.ApplyStudioPreset(player, profileData)
	if not RunService:IsStudio() then return false end
	local presetName = DevelopmentLoadouts.STUDIO_PRESET_BY_USER_ID[player.UserId]
	local preset = presetName and PRESETS[presetName]
	if not preset then return false end

	profileData.Inventory = copyInventory(preset.Inventory)
	profileData.Equipped = profileData.Equipped or {}
	profileData.Equipped.Weapon = preset.EquippedWeapon
	return true
end

local DEVELOPMENT_GROVE_SAPLINGS = {
	{ SpeciesId = "Oak", Count = 2 },
	{ SpeciesId = "Bamboo", Count = 2 },
	{ SpeciesId = "Ironwood", Count = 2 },
}

local function hasGroveUID(profileData, uid)
	for _, collectionName in ipairs({ "Saplings", "GroveTrees" }) do
		local collection = profileData[collectionName]
		if type(collection) == "table" then
			for _, record in pairs(collection) do
				if type(record) == "table"
					and (record.UID == uid or record.SourceSaplingUID == uid) then
					return true
				end
			end
		end
	end
	return false
end

function DevelopmentLoadouts.ApplyGroveSaplings(player, profileData)
	if not RunService:IsStudio()
		or typeof(player) ~= "Instance"
		or not player:IsA("Player")
		or not player:IsDescendantOf(Players)
		or type(profileData) ~= "table"
		or not resolveGroveSaplingDeveloper(player) then
		return false
	end

	if type(profileData.Saplings) ~= "table" then
		profileData.Saplings = {}
	end
	local createdAt = os.time()
	local changed = false
	for _, definition in ipairs(DEVELOPMENT_GROVE_SAPLINGS) do
		for index = 1, definition.Count do
			local uid = string.format(
				"dev-grove-%d-%s-%d",
				player.UserId,
				string.lower(definition.SpeciesId),
				index
			)
			if not hasGroveUID(profileData, uid) then
				table.insert(profileData.Saplings, {
					UID = uid,
					SpeciesId = definition.SpeciesId,
					Mutations = {},
					SizePotential = 1,
					CreatedAt = createdAt,
				})
				changed = true
			end
		end
	end
	return changed
end

return DevelopmentLoadouts
