-- Server-owned seam for future mutation and Grove-stage tree visuals.
-- Milestone 3B.0 only publishes sanitized presentation metadata; it does not
-- recolor, decorate, or otherwise modify tree geometry.
--
-- Builder contract for future modifiers:
-- * Visible foliage is grouped under the `Leaves` Folder.
-- * Harvestable trunk Models live under species-specific *HarvestSections
--   Folders and carry AuthoredHarvestSection/HarvestSectionIndex attributes.
-- * Root carriers and ChopHitbox parts have AlwaysInvisible=true and are
--   gameplay infrastructure, never decoration targets.
-- Future effects must remain idempotent across Apply calls so a Grove stage
-- update can refresh them without duplicating geometry.
local TreeVisualModifiers = {}

local MutationDefinitions = require(game.ServerScriptService.Grove.MutationDefinitions)
local MaterialDefinitions = require(game.ServerScriptService.Economy.MaterialDefinitions)

local VALID_GROVE_STAGES = {
	sapling = true,
	young = true,
	mature = true,
}

local MIN_SIZE_POTENTIAL = 0.1
local MAX_SIZE_POTENTIAL = 2

local function isFiniteNumber(value)
	return type(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
end

function TreeVisualModifiers.Apply(model, context)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or type(context) ~= "table" then
		return false
	end

	local speciesId = context.SpeciesId
	if type(speciesId) ~= "string" or not MaterialDefinitions.Get(speciesId) then
		speciesId = nil
	end

	local mutations = MutationDefinitions.CopyKnown(context.Mutations)
	local mutationIds = {}
	for _, mutationId in ipairs(MutationDefinitions.OrderedIds) do
		if mutations[mutationId] == true then
			table.insert(mutationIds, mutationId)
		end
	end

	local groveStage = context.GroveStage
	if type(groveStage) ~= "string" or not VALID_GROVE_STAGES[groveStage] then
		groveStage = nil
	end

	local sizePotential = context.SizePotential
	if not isFiniteNumber(sizePotential)
		or sizePotential < MIN_SIZE_POTENTIAL
		or sizePotential > MAX_SIZE_POTENTIAL then
		sizePotential = nil
	end

	local currentScale = context.CurrentScale
	if not isFiniteNumber(currentScale) or currentScale <= 0 or currentScale > 100 then
		currentScale = nil
	end

	-- These attributes are debugging/presentation hints only. Gameplay systems
	-- must continue to use the server-owned TreeObject and profile records.
	model:SetAttribute("VisualSpeciesId", speciesId)
	model:SetAttribute("VisualMutationIds", table.concat(mutationIds, ","))
	model:SetAttribute("VisualMutationCount", #mutationIds)
	model:SetAttribute("VisualGrowthStage", groveStage)
	model:SetAttribute("VisualSizePotential", sizePotential)
	model:SetAttribute("VisualScale", currentScale)
	model:SetAttribute("VisualModifierVersion", 1)

	return true
end

return TreeVisualModifiers
