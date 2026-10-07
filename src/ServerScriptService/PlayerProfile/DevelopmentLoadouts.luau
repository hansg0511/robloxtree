-- Server-only development fixtures. New profiles never receive these values.
-- To opt a Studio account into one, add its numeric UserId below and choose a
-- preset. Keep this table empty before publishing.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local DevelopmentLoadouts = {}

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
