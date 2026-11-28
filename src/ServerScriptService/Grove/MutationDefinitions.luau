-- Server-owned mutation catalogue. These identifiers are persistent data, while
-- their future gameplay effects intentionally remain outside Milestone 3A.
local MutationDefinitions = {}

MutationDefinitions.OrderedIds = {
	"Golden",
	"Giant",
	"Frenzied",
	"Shocked",
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
	Frenzied = {
		Id = "Frenzied",
		DisplayName = "Frenzied",
		Weight = 1,
	},
	Shocked = {
		Id = "Shocked",
		DisplayName = "Shocked",
		Weight = 1,
	},
	-- Preserve already-owned Crystal logs/saplings in old player profiles.
	-- Crystal is deliberately absent from OrderedIds and never newly rolls.
	Crystal = {
		Id = "Crystal",
		DisplayName = "Crystal (legacy)",
		Weight = 0,
	},
}

function MutationDefinitions.IsKnown(id)
	return type(id) == "string" and MutationDefinitions.ById[id] ~= nil
end

function MutationDefinitions.CopyKnown(mutations)
	local copy = {}
	if type(mutations) ~= "table" then return copy end
	for id in pairs(MutationDefinitions.ById) do
		if mutations[id] == true then
			copy[id] = true
		end
	end
	return copy
end

return MutationDefinitions
