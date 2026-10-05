-- Shared character-local layout for carried logs and pickup arrival effects.
-- Slot helpers return CFrames relative to the live torso so callers can update
-- destinations as the character moves without duplicating layout constants.
local CarryLayout = {}

-- This bounds cosmetic projection only. Inventory capacity and item count are
-- server-owned and use their own limits.
CarryLayout.MAX_CARRIED_LOGS = 96
CarryLayout.COLUMNS_PER_STACK = 4
CarryLayout.LOG_STACK_GAP = 0.04
CarryLayout.LOG_BASE_DIAMETER = 0.48
CarryLayout.NORMAL_STACK_CENTER_X = -1.15
CarryLayout.RARE_STACK_CENTER_X = 1.15
CarryLayout.CARGO_BACK_OFFSET = 1.75
CarryLayout.CARGO_BASE_HEIGHT = 0.68
CarryLayout.TORSO_ANCHOR_HEIGHT = 0.42

function CarryLayout.GetAnchorRelativeCFrame()
	return CFrame.new(0, CarryLayout.TORSO_ANCHOR_HEIGHT, CarryLayout.CARGO_BACK_OFFSET)
end

local function getScale(scales, index)
	local value = scales and scales[index]
	if type(value) ~= "number" or value ~= value or value <= 0 or value == math.huge then
		return 1
	end
	return math.clamp(value, 0.05, 4)
end

function CarryLayout.GetAnchorRelativeSlotCFrame(stackName, stackIndex, visualScales)
	if (stackName ~= "Normal" and stackName ~= "Rare")
		or type(stackIndex) ~= "number"
		or stackIndex % 1 ~= 0
		or stackIndex < 1
		or stackIndex > CarryLayout.MAX_CARRIED_LOGS then
		return nil
	end
	if type(visualScales) == "table" and stackIndex > #visualScales then
		return nil
	end

	local stackCenterX = stackName == "Rare"
		and CarryLayout.RARE_STACK_CENTER_X
		or CarryLayout.NORMAL_STACK_CENTER_X
	local columnIndex = (stackIndex - 1) % CarryLayout.COLUMNS_PER_STACK
	local rowIndex = math.floor((stackIndex - 1) / CarryLayout.COLUMNS_PER_STACK)
	local itemCount = if type(visualScales) == "table" then #visualScales else stackIndex
	local maximumDiameter = CarryLayout.LOG_BASE_DIAMETER
	for index = 1, itemCount do
		maximumDiameter = math.max(
			maximumDiameter,
			CarryLayout.LOG_BASE_DIAMETER * getScale(visualScales, index)
		)
	end

	local heightBeforeRow = 0
	for row = 0, rowIndex - 1 do
		local rowMaximumDiameter = 0
		local rowFirstIndex = row * CarryLayout.COLUMNS_PER_STACK + 1
		local rowLastIndex = math.min(rowFirstIndex + CarryLayout.COLUMNS_PER_STACK - 1, itemCount)
		for index = rowFirstIndex, rowLastIndex do
			rowMaximumDiameter = math.max(
				rowMaximumDiameter,
				CarryLayout.LOG_BASE_DIAMETER * getScale(visualScales, index)
			)
		end
		heightBeforeRow += rowMaximumDiameter + CarryLayout.LOG_STACK_GAP
	end

	local currentRowFirstIndex = rowIndex * CarryLayout.COLUMNS_PER_STACK + 1
	local currentRowLastIndex = math.min(currentRowFirstIndex + CarryLayout.COLUMNS_PER_STACK - 1, itemCount)
	local currentRowMaximumDiameter = 0
	for index = currentRowFirstIndex, currentRowLastIndex do
		currentRowMaximumDiameter = math.max(
			currentRowMaximumDiameter,
			CarryLayout.LOG_BASE_DIAMETER * getScale(visualScales, index)
		)
	end
	if currentRowMaximumDiameter == 0 then
		currentRowMaximumDiameter = CarryLayout.LOG_BASE_DIAMETER * getScale(visualScales, stackIndex)
	end
	local columnStep = maximumDiameter + CarryLayout.LOG_STACK_GAP
	local zOffset = (columnIndex - (CarryLayout.COLUMNS_PER_STACK - 1) * 0.5) * columnStep
	return CFrame.new(
		stackCenterX,
		CarryLayout.CARGO_BASE_HEIGHT + heightBeforeRow + currentRowMaximumDiameter * 0.5,
		zOffset
	)
end

-- Returns the full torso-local cargo slot. Multiply by the current torso CFrame
-- on each frame to track a moving/turning character during pickup flight.
function CarryLayout.GetTorsoRelativeTargetCFrame(stackName, stackIndex, visualScales)
	local slotCFrame = CarryLayout.GetAnchorRelativeSlotCFrame(stackName, stackIndex, visualScales)
	if not slotCFrame then
		return nil
	end
	return CarryLayout.GetAnchorRelativeCFrame() * slotCFrame
end

return CarryLayout
