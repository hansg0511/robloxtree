-- Server-owned mutation catalogue. These identifiers are persistent data, while
-- their future gameplay effects intentionally remain outside Milestone 3A.
local MutationDefinitions = {}

MutationDefinitions.OrderedIds = {
	"Golden",
	"Giant",
	"Crystal",
}

MutationDefinitions.ById = {
	Golden = {
		Id = "Golden",
		DisplayName = "Golden",
		Weight = 1,
	},
	Giant = {
		Id = "Giant",
		DisplayName = "Giant",
		Weight = 1,
	},
	Crystal = {
		Id = "Crystal",
		DisplayName = "Crystal",
		Weight = 1,
	},
}

function MutationDefinitions.IsKnown(id)
	return type(id) == "string" and MutationDefinitions.ById[id] ~= nil
end

function MutationDefinitions.CopyKnown(mutations)
	local copy = {}
	if type(mutations) ~= "table" then return copy end
	for _, id in ipairs(MutationDefinitions.OrderedIds) do
		if mutations[id] == true then
			copy[id] = true
		end
	end
	return copy
end

return MutationDefinitions
