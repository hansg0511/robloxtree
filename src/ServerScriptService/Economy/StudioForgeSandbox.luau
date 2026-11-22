-- Studio-only auto-refill for rapid forging balance tests.
-- This module is intentionally server-only and never runs in published servers.
-- All fixtures are real, individual stored-log records with unique UIDs so
-- existing server forge ownership, mutation and transaction checks remain real.
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local MaterialDefinitions = require(script.Parent.MaterialDefinitions)
local LogStorageRules = require(game.ServerScriptService.Inventory.LogStorageRules)

local Sandbox = {}

-- Flip this to false if you need to test normal progression in Roblox Studio.
Sandbox.ENABLED = true
Sandbox.COIN_FLOOR = 1_000_000_000
Sandbox.HEAD_FLOOR = 1_000
Sandbox.FIXTURES_PER_VARIANT = 2
Sandbox.MAX_TOTAL_STORED = 210 -- leave 30 places free for Grove harvest/other logs
Sandbox.SPECIES = { "Bamboo", "Oak", "Ironwood" }
Sandbox.SIZES = { 0.5, 1, 2, 3.5, 5 }
Sandbox.MUTATION_TYPES = { "Normal", "Golden", "Frenzied", "Shocked", "Crystal" }
local UID_PREFIX = "devforge-"

function Sandbox.IsEnabled()
	return Sandbox.ENABLED == true and RunService:IsStudio()
end

local function fixtureKey(species, size, mutation)
	return species .. "|" .. tostring(size) .. "|" .. mutation
end

local function mutationKind(mutations)
	if type(mutations) ~= "table" then return "Normal" end
	if mutations.Golden == true then return "Golden" end
	if mutations.Frenzied == true then return "Frenzied" end
	if mutations.Shocked == true then return "Shocked" end
	if mutations.Crystal == true then return "Crystal" end
	return "Normal"
end

local function existingDevFixtureCounts(data)
	local counts = {}
	for _, list in ipairs({ data.StoredLogs, data.Logs }) do
		for _, record in ipairs(type(list) == "table" and list or {}) do
			if type(record) == "table"
				and type(record.UID) == "string"
				and string.sub(record.UID, 1, #UID_PREFIX) == UID_PREFIX
				and type(record.SpeciesId) == "string" then
				local key = fixtureKey(record.SpeciesId,
					LogStorageRules.SizeScale(record), mutationKind(record.Mutations))
				counts[key] = (counts[key] or 0) + 1
			end
		end
	end
	return counts
end

-- Does not overwrite, clear, sell, unlock or modify any existing player logs.
-- A consumed fixture is replaced with a NEW UID, and the consumed UID remains
-- preserved as provenance in the crafted weapon record.
function Sandbox.Refill(player, data)
	if not Sandbox.IsEnabled() or typeof(player) ~= "Instance"
		or not player:IsA("Player") or type(data) ~= "table" then
		return false
	end
	local changed = false

	if type(data.Coins) ~= "number" or data.Coins ~= data.Coins
		or data.Coins < Sandbox.COIN_FLOOR then
		data.Coins = Sandbox.COIN_FLOOR
		changed = true
	end

	if type(data.AxeHeads) == "table" then
		for _, headId in ipairs({ "copper_head", "iron_head" }) do
			local quantity = data.AxeHeads[headId]
			if type(quantity) ~= "number" or quantity ~= quantity
				or quantity < Sandbox.HEAD_FLOOR then
				data.AxeHeads[headId] = Sandbox.HEAD_FLOOR
				changed = true
			end
		end
	end

	-- Let a freshly joined test player try BOTH experimental metal tiers.
	-- This is a sandbox-only override; normal progression remains intact
	-- when the toggle above is disabled or outside Studio.
	if type(data.RunProgress) == "table" then
		-- Convenience for existing Studio iron-forge playtests. Disable
		-- sandbox when testing the real paid workstation upgrade.
		if data.RunProgress.ForgeLevel ~= 2 then
			data.RunProgress.ForgeLevel = 2
			changed = true
		end
		local tier = data.RunProgress.StandardAxeTier
		if type(tier) ~= "number" or tier < 2 then
			data.RunProgress.StandardAxeTier = 2
			changed = true
		end
		if type(data.RunProgress.UnlockedForests) == "table"
			and data.RunProgress.UnlockedForests.Forest2 ~= true then
			data.RunProgress.UnlockedForests.Forest2 = true
			changed = true
		end
	end

	if type(data.StoredLogs) ~= "table" or type(data.Logs) ~= "table" then
		return changed
	end
	local counts = existingDevFixtureCounts(data)
	local maxCount = math.min(Sandbox.MAX_TOTAL_STORED, LogStorageRules.MAX_STORED_LOGS)
	for _, species in ipairs(Sandbox.SPECIES) do
		if MaterialDefinitions.Get(species) then
			for _, size in ipairs(Sandbox.SIZES) do
				for _, mutation in ipairs(Sandbox.MUTATION_TYPES) do
					local key = fixtureKey(species, size, mutation)
					local have = counts[key] or 0
					while have < Sandbox.FIXTURES_PER_VARIANT
						and #data.StoredLogs < maxCount do
						local mutations = {}
						if mutation ~= "Normal" then mutations[mutation] = true end
						table.insert(data.StoredLogs, {
							UID = UID_PREFIX .. HttpService:GenerateGUID(false),
							ItemType = "Log",
							SpeciesId = species,
							Mutations = mutations,
							SizeScale = size,
							Locked = false,
							CreatedAt = os.time(),
						})
						have += 1
						changed = true
					end
					counts[key] = have
				end
			end
		end
	end
	return changed
end

return Sandbox
