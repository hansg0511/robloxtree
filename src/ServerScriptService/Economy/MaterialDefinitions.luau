-- Server-owned gameplay properties for each physical wood material.
-- Item records store species only; weight, sale value, and carry size are
-- resolved here so clients cannot author per-piece capacity costs.
local MaterialDefinitions = {}

local DEFINITIONS = {
	Bamboo = {
		CapacityKg = 0.5,
		SellValue = 5,
		CarryVisualScale = 0.45,
		CraftPowerBonus = 1,
	},
	Oak = {
		CapacityKg = 4,
		SellValue = 16,
		CarryVisualScale = 1,
		CraftPowerBonus = 3,
	},
	Ironwood = {
		CapacityKg = 10,
		SellValue = 144,
		CarryVisualScale = 1.15,
		CraftPowerBonus = 9,
	},
}

function MaterialDefinitions.Get(speciesId)
	if type(speciesId) ~= "string" then return nil end
	return DEFINITIONS[speciesId]
end

function MaterialDefinitions.GetCapacityKg(speciesId)
	local definition = MaterialDefinitions.Get(speciesId)
	return definition and definition.CapacityKg or nil
end

function MaterialDefinitions.GetSellValue(speciesId)
	local definition = MaterialDefinitions.Get(speciesId)
	return definition and definition.SellValue or nil
end

function MaterialDefinitions.GetCarryVisualScale(speciesId)
	local definition = MaterialDefinitions.Get(speciesId)
	return definition and definition.CarryVisualScale or nil
end

return MaterialDefinitions
