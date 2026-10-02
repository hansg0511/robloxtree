-- Server-only development fixtures. New profiles never receive these values.
-- To opt a Studio account into one, add its numeric UserId below and choose a
-- preset. Keep this table empty before publishing.
local RunService = game:GetService("RunService")

local DevelopmentLoadouts = {}

DevelopmentLoadouts.STUDIO_PRESET_BY_USER_ID = {
	-- [123456789] = "Strong",
}

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

return DevelopmentLoadouts
