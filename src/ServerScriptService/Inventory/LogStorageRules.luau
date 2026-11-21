-- Pure, server-owned sorting rules for unique log records.
-- No item is deleted or monetized by these decisions.
local Rules = {}

Rules.MAX_STORED_LOGS = 240
Rules.MIN_SIZE_SCALE = 0.05 -- Supports small-genetics Grove crops without losing exact size
Rules.MAX_SIZE_SCALE = 5
Rules.DEFAULT_THRESHOLD = 1.5
Rules.MIN_THRESHOLD = 1
Rules.MAX_THRESHOLD = 3

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function Rules.SizeScale(record)
	local value = type(record) == "table" and record.SizeScale or nil
	if finite(value) and value >= Rules.MIN_SIZE_SCALE and value <= Rules.MAX_SIZE_SCALE then
		return value
	end
	return 1
end

function Rules.NormalizeSettings(data)
	local raw = type(data.AutoKeep) == "table" and data.AutoKeep or {}
	local settings = {
		Mutations = if type(raw.Mutations) == "boolean" then raw.Mutations else true,
		Oversized = if type(raw.Oversized) == "boolean" then raw.Oversized else true,
		SizeThreshold = if finite(raw.SizeThreshold)
			and raw.SizeThreshold >= Rules.MIN_THRESHOLD
			and raw.SizeThreshold <= Rules.MAX_THRESHOLD
			then math.floor(raw.SizeThreshold * 10 + 0.5) / 10
			else Rules.DEFAULT_THRESHOLD,
	}
	data.AutoKeep = settings
	return settings
end

function Rules.HasMutation(record)
	if type(record) ~= "table" or type(record.Mutations) ~= "table" then return false end
	for _, value in pairs(record.Mutations) do
		if value == true or (type(value) == "number" and value ~= 0)
			or (type(value) == "string" and #value > 0) then
			return true
		end
	end
	return false
end

function Rules.ShouldStore(record, settings)
	if type(record) ~= "table" or type(settings) ~= "table" then return false end
	return (settings.Mutations == true and Rules.HasMutation(record))
		or (settings.Oversized == true and Rules.SizeScale(record) >= settings.SizeThreshold)
end

return Rules
