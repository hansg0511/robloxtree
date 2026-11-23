-- Server-authoritative, per-server player-list leaderboard.
-- Counters persist in the existing player profile; no global ranking, prize,
-- difficulty weighting, new currency, or DataStore OrderedDataStore yet.
local Players = game:GetService("Players")
local Profiles = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local Rules = require(game.ServerScriptService.ChopLeaderboardRules)

local Service = {}
local lastCreditedGeneration = setmetatable({}, { __mode = "k" })

local function stat(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing and not existing:IsA("IntValue") then return nil end
	if existing then return existing end
	local value = Instance.new("IntValue")
	value.Name = name
	value.Value = 0
	value.Parent = parent
	return value
end

local function ensureLeaderstats(player)
	local folder = player:FindFirstChild("leaderstats")
	if folder and not folder:IsA("Folder") then return nil end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
	end
	-- Weekly first so the in-server player list prioritizes the active week.
	local weekly = stat(folder, "Weekly Chops")
	local lifetime = stat(folder, "Total Chops")
	return weekly, lifetime
end

local function render(player, counters)
	if player.Parent ~= Players then return end
	local weekly, lifetime = ensureLeaderstats(player)
	if not weekly or not lifetime then return end
	weekly.Value = counters.WeeklyCount
	lifetime.Value = counters.Lifetime
end

function Service.RefreshPlayer(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player")
		or player.Parent ~= Players then return false end
	local data = Profiles.GetData(player)
	if type(data) ~= "table" then return false end
	local clean = Rules.Normalize(data.ChopLeaderboard, os.time())
	if not clean then return false end
	data.ChopLeaderboard = clean
	render(player, clean)
	return true
end

function Service.RecordWildTreeChopped(player, tree)
	if typeof(player) ~= "Instance" or not player:IsA("Player")
		or player.Parent ~= Players or type(tree) ~= "table"
		or tree.IsPersistentGrove == true or tree.YieldsLog ~= true
		or tree.isDead ~= true then return false end
	local generation = tree.DeathGeneration
	if type(generation) ~= "number" or generation % 1 ~= 0
		or generation < 1 or lastCreditedGeneration[tree] == generation then
		return false
	end
	local data = Profiles.GetData(player)
	if type(data) ~= "table" then return false end
	local updated = Rules.Record(data.ChopLeaderboard, os.time())
	if not updated then return false end
	-- Mark generation before side effects. This exact tree life can be
	-- credited only once, even if the same callback is retried.
	lastCreditedGeneration[tree] = generation
	data.ChopLeaderboard = updated
	render(player, updated)
	return true
end

-- The native player-list stats also roll over for players who remain idle
-- in an online server across the Monday UTC reset.
task.spawn(function()
	while true do
		task.wait(30)
		for _, player in ipairs(Players:GetPlayers()) do
			if Profiles.GetData(player) then
				local ok, err = pcall(Service.RefreshPlayer, player)
				if not ok then warn("[ChopLeaderboard] Refresh failed", err) end
			end
		end
	end
end)

return Service
