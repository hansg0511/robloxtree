-- Pure, reward-free server profile counters for verified wild-tree kills.
-- These are descriptive stats, NOT a balanced global competition score.
local QuestRules = require(game.ServerScriptService.Quests.QuestRules)
local Rules = {}
Rules.MAX_COUNT = 1000000000000

local function validCount(value)
	return type(value) == "number" and value == value and value % 1 == 0
		and value >= 0 and value <= Rules.MAX_COUNT
end

function Rules.WeekId(now)
	local id = QuestRules.Window(QuestRules.Categories.Weekly, now)
	return id
end

-- Save shape: {Lifetime=int, WeeklyWindowId=int, WeeklyCount=int}.
-- The week follows the existing quest Monday 00:00 UTC boundary.
-- Invalid saves and old/future weeks never credit the new week.
function Rules.Normalize(raw, now)
	local id = Rules.WeekId(now)
	if id == nil then return nil, false end
	local input = if type(raw) == "table" then raw else {}
	local lifetime = if validCount(input.Lifetime) then input.Lifetime else 0
	local sameWeek = input.WeeklyWindowId == id
	local weekly = if sameWeek and validCount(input.WeeklyCount)
		then input.WeeklyCount else 0
	local clean = {
		Lifetime = lifetime,
		WeeklyWindowId = id,
		WeeklyCount = weekly,
	}
	local changed = type(raw) ~= "table"
		or input.Lifetime ~= lifetime
		or input.WeeklyWindowId ~= id
		or input.WeeklyCount ~= weekly
	return clean, changed
end

-- Caller guarantees an actual server-owned tree death and verified winner.
function Rules.Record(raw, now)
	local state = Rules.Normalize(raw, now)
	if not state then return nil end
	state.Lifetime = math.min(Rules.MAX_COUNT, state.Lifetime + 1)
	state.WeeklyCount = math.min(Rules.MAX_COUNT, state.WeeklyCount + 1)
	return state
end

return Rules
