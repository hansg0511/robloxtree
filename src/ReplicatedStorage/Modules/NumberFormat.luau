local NumberFormat = {}


--[[

	Converts large numbers e.g. 2e39 to use the appropriate suffix
	
	Accepts number, returns { full_string, number, suffix }
	Omits the suffix if one is not needed
]]
function NumberFormat.formatNumber(num: number)
	-- Define the suffixes for large numbers
	local suffixes = {
		"K",  -- Thousands (10^3)
		"M",  -- Millions (10^6)
		"B",  -- Billions (10^9)
		"T",  -- Trillions (10^12)
		"Qa", -- Quadrillions (10^15)
		"Qt", -- Quintillions (10^18)
		"Sx", -- Sextillions (10^21)
		"Sp", -- Septillions (10^24)
		"Oc", -- Octillions (10^27)
		"No", -- Nonillions (10^30)
		"Dc", -- Decillions (10^33)
		"Ud", -- Undecillions (10^36)
		"Dd", -- Duodecillions (10^39)
		"Td", -- Tredecillions (10^42)
		"Qd",  -- Quattuordecillions (10^45)
		"Qnd", -- Quindecillions (10^48)
		"Sd",  -- Sexdecillions (10^51)
		"Spd", -- Septendecillions (10^54)
		"Od", -- Octodecillions (10^57)
		"Nd", -- Novemdecillions (10^60)
		"Vd"   -- Vigintillions (10^63)
	}

	-- Calculate the order of magnitude of the number (logarithmic scale)
	local order = math.floor(math.log(num) / math.log(10))
	
	if order < 3 then
		return {tostring(num), num}
	end

	-- Find the closest suffix based on the number's magnitude
	local suffixIndex = math.floor(order / 3)

	-- If the number exceeds the largest supported value (vigintillions), return "Too large"
	if suffixIndex > #suffixes then
		return "Too large"
	end

	-- The actual number format (simplified to 2 significant figures)
	local divisor = 10^(3 * suffixIndex)
	local formattedNum = num / divisor
	local numString = string.format("%.1f", formattedNum)

	-- Get the appropriate suffix
	local suffix = suffixes[suffixIndex]

	-- Return the formatted result
	return {numString .. " " ..suffix, numString, suffix}
end

return NumberFormat