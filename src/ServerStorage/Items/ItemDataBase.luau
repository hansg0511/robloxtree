local itemDataBase = {}
local IMS = require(game.ServerScriptService.Inventory.Module.IMS)

itemDataBase.Info = {
	[101] = {
		Name = "Starter Hatchet",
		Icon = "rbxasset://Textures/Sword128.png",
		Type = "Weapon",
		Skill = "",
		Substat = "AttackSpeed"
	},
	[102] = {
		Name = "Copper Axe",
		Icon = "rbxasset://Textures/Sword128.png",
		Type = "Weapon",
		Skill = "",
		Substat = "AttackSpeed"
	},
	[103] = {
		Name = "Iron Axe",
		Icon = "rbxasset://Textures/Sword128.png",
		Type = "Weapon",
		Skill = "",
		Substat = "AttackSpeed"
	},
	[104] = {
		Name = "Steel Axe",
		Icon = "rbxasset://Textures/Sword128.png",
		Type = "Weapon",
		Skill = "",
		Substat = "AttackSpeed"
	},
	[105] = {
		Name = "Heavy Cleaver",
		Icon = "rbxasset://Textures/Sword128.png",
		Type = "Weapon",
		Skill = "",
		Substat = "AttackSpeed"
	},
	[9001] = {
		Name = "Debug Pro Axe",
		Icon = "rbxasset://Textures/Sword128.png",
		Type = "Weapon",
		Skill = "",
		Substat = "AttackSpeed"
	},
	[201] = {
		Name = "Basic Seed",
		Icon = "http://www.roblox.com/asset/?id=399568011",
		Type = "Seed",
		Skill = "",
		Substat = {}
	}
}

local Parts = game.ServerStorage.AxeParts

itemDataBase.Instances = {
	[101] = Parts["Starter Hatchet"],
	[102] = Parts["Copper Axe"],
	[103] = Parts["Iron Axe"],
	[104] = Parts["Steel Axe"],
	[105] = Parts["Heavy Cleaver"],
	[9001] = Parts["Starter Hatchet"],
}

itemDataBase.StatPools = {
	Weapon = {
		"Attack",
		"CritChance",
		"CritDamage",
	},

	Seed = {
		"Health",
		"Defense",
		"Regen"
	},

	Pet = {
		"DamageBoost",
		"DropRate",
		"MoveSpeed"
	}
}

local function deepCopy(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for key, child in pairs(value) do
		copy[deepCopy(key)] = deepCopy(child)
	end
	return copy
end

function itemDataBase.ParseItem(item: IMS.ITEM_TYPE)
	local itemInfo = itemDataBase.Info[item.ItemID]
	local itemInstance = itemDataBase.Instances[item.ItemID]
	if not itemInfo then return nil end
	local weaponData = type(item.WeaponData) == "table" and deepCopy(item.WeaponData) or nil

	return {
		ItemName = itemInfo.Name,
		ItemIcon = itemInfo.Icon,
		ItemType = itemInfo.Type,
		ItemRarity = item.Rarity,
		ItemStats = deepCopy(item.Stats),
		ItemUID = item.UID,
		ItemSubstat = deepCopy(item.Substat),
		InstanceName = itemInstance and itemInstance.Name or nil,
		WeaponData = weaponData,
		ItemWeaponData = weaponData and deepCopy(weaponData) or nil,
		ItemMaterials = weaponData and type(weaponData.Materials) == "table"
			and deepCopy(weaponData.Materials) or nil,
	}
end


return itemDataBase
