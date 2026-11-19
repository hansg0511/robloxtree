-- Run in Roblox Studio SERVER Command Bar while a player is in Play mode.
-- Uses synthetic profile tables: NEVER touches the real player's inventory.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Sandbox = require(game.ServerScriptService.Economy.StudioForgeSandbox)
assert(RunService:IsStudio(), "Studio-only test")
assert(Sandbox.IsEnabled(), "Enable StudioForgeSandbox.ENABLED for test")
local player = Players:GetPlayers()[1]
assert(player, "Start Studio Play with a player first")

local original = {
	UID = "real-player-log-preserve",
	ItemType = "Log", SpeciesId = "Oak", SizeScale = 1,
	Mutations = {}, Locked = false, CreatedAt = 1,
}
local fakeProfile = {
	Coins = 0,
	AxeHeads = { copper_head = 0, iron_head = 0 },
	RunProgress = { StandardAxeTier = 0, UnlockedForests = {
		Base = true, Forest1 = true, Forest2 = false,
	} },
	Logs = {},
	StoredLogs = { original },
}
assert(Sandbox.Refill(player, fakeProfile) == true, "Initial grant should change profile")
assert(fakeProfile.Coins == Sandbox.COIN_FLOOR, "Coins should be stocked")
assert(fakeProfile.AxeHeads.copper_head == Sandbox.HEAD_FLOOR
	and fakeProfile.AxeHeads.iron_head == Sandbox.HEAD_FLOOR, "Both heads stocked")
assert(fakeProfile.RunProgress.StandardAxeTier == 2
	and fakeProfile.RunProgress.UnlockedForests.Forest2 == true, "Studio progression bypass")
assert(fakeProfile.StoredLogs[1] == original, "Existing owned record must be untouched")

local expected = #Sandbox.SPECIES * #Sandbox.SIZES * #Sandbox.MUTATION_TYPES
	* Sandbox.FIXTURES_PER_VARIANT
assert(#fakeProfile.StoredLogs == expected + 1, "All fixture combinations stocked")

local seen = {}
local sizes, species, mutations = {}, {}, {}
for _, record in ipairs(fakeProfile.StoredLogs) do
	assert(not seen[record.UID], "Unique UID for every test log")
	seen[record.UID] = true
	assert(record.Locked == false, "Stored fixtures are craft-eligible")
	sizes[record.SizeScale] = true
	species[record.SpeciesId] = true
	if record.Mutations.Golden then mutations.Golden = true end
	if record.Mutations.Crystal then mutations.Crystal = true end
end
assert(sizes[0.5] and sizes[5] and species.Bamboo and species.Oak
	and species.Ironwood and mutations.Golden and mutations.Crystal,
	"Quality, species and mutation variety is present")
assert(Sandbox.Refill(player, fakeProfile) == false, "Full stock refill is idempotent")

local usedUID = fakeProfile.StoredLogs[2].UID
table.remove(fakeProfile.StoredLogs, 2)
assert(Sandbox.Refill(player, fakeProfile) == true, "Consumed dev log must replenish")
assert(#fakeProfile.StoredLogs == expected + 1, "Refill restores stock size")
for _, record in ipairs(fakeProfile.StoredLogs) do
	assert(record.UID ~= usedUID, "Restocked fixture must receive a NEW unique UID")
end

fakeProfile.Coins = 100
fakeProfile.AxeHeads.iron_head = 1
assert(Sandbox.Refill(player, fakeProfile) == true, "Money and components restock")
assert(fakeProfile.Coins == Sandbox.COIN_FLOOR
	and fakeProfile.AxeHeads.iron_head == Sandbox.HEAD_FLOOR, "Resource refill correct")

print("Studio forge sandbox: funding, log variety, safe auto-refill and unique UIDs passed")
return true
