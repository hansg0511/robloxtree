-- Shared character-local layout for carried logs and pickup arrival effects.
-- Slot helpers return CFrames relative to the live torso so callers can update
-- destinations as the character moves without duplicating layout constants.
local CarryLayout = {}

CarryLayout.MAX_CARRIED_LOGS = 40
CarryLayout.COLUMNS_PER_STACK = 1
CarryLayout.LOG_LAYER_HEIGHT = 0.5
CarryLayout.NORMAL_STACK_CENTER_X = -1.15
CarryLayout.RARE_STACK_CENTER_X = 1.15
CarryLayout.CARGO_BACK_OFFSET = 1.75
CarryLayout.CARGO_BASE_HEIGHT = 0.68
CarryLayout.TORSO_ANCHOR_HEIGHT = 0.42

function CarryLayout.GetAnchorRelativeCFrame()
	return CFrame.new(0, CarryLayout.TORSO_ANCHOR_HEIGHT, CarryLayout.CARGO_BACK_OFFSET)
end

function CarryLayout.GetAnchorRelativeSlotCFrame(stackName, stackIndex)
	if (stackName ~= "Normal" and stackName ~= "Rare")
		or type(stackIndex) ~= "number"
		or stackIndex % 1 ~= 0
		or stackIndex < 1
		or stackIndex > CarryLayout.MAX_CARRIED_LOGS then
		return nil
	end

	local stackCenterX = stackName == "Rare"
		and CarryLayout.RARE_STACK_CENTER_X
		or CarryLayout.NORMAL_STACK_CENTER_X
	local layerIndex = math.floor((stackIndex - 1) / CarryLayout.COLUMNS_PER_STACK)
	return CFrame.new(
		stackCenterX,
		CarryLayout.CARGO_BASE_HEIGHT + layerIndex * CarryLayout.LOG_LAYER_HEIGHT,
		0
	)
end

-- Returns the full torso-local cargo slot. Multiply by the current torso CFrame
-- on each frame to track a moving/turning character during pickup flight.
function CarryLayout.GetTorsoRelativeTargetCFrame(stackName, stackIndex)
	local slotCFrame = CarryLayout.GetAnchorRelativeSlotCFrame(stackName, stackIndex)
	if not slotCFrame then
		return nil
	end
	return CarryLayout.GetAnchorRelativeCFrame() * slotCFrame
end

return CarryLayout
