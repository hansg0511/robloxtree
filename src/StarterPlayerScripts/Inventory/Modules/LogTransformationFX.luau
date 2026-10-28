-- Local-only visual transformation from an irregular wood section to a
-- standardized log. This module owns only temporary cosmetic clones.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LogTransformationFX = {}

local FX_FOLDER_NAME = "ClientLogTransformationFX"
local ORIGINAL_TRANSPARENCY_ATTRIBUTE = "DevOriginalTransparency"
local activeBySourceTemplate = setmetatable({}, { __mode = "k" })

local DEFAULTS = {
	LiftDuration = 0.10,
	CompressionDuration = 0.15,
	RevealDuration = 0.10,
	FinishDuration = 0.55,
	LiftHeight = 0.9,
	RotationTurns = 0.35,
	SourceEndScale = 0.08,
	DestinationStartScale = 0.84,
	ChipCount = 8,
	ChipDuration = 0.28,
	ChipStrength = 1,
	HoverHeight = 0.08,
	SurfaceEpsilon = 0.04,
}

local function optionNumber(options, name, minimum, maximum)
	local value = options[name]
	if typeof(value) ~= "number" or value ~= value then
		value = DEFAULTS[name]
	end
	return math.clamp(value, minimum, maximum)
end

local function getFxFolder()
	local existing = Workspace:FindFirstChild(FX_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = FX_FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

local function getVisualTransparency(instance)
	local original = instance:GetAttribute(ORIGINAL_TRANSPARENCY_ATTRIBUTE)
	if typeof(original) ~= "number" then
		original = instance.Transparency
		instance:SetAttribute(ORIGINAL_TRANSPARENCY_ATTRIBUTE, original)
	end
	return math.clamp(original, 0, 1)
end

local function isTransparencyVisual(instance)
	return instance:IsA("BasePart") or instance:IsA("Decal") or instance:IsA("Texture")
end

local function cloneVisualTemplate(template, name, initiallyVisible)
	if not template or not template:IsA("Model") then
		return nil, nil, "template is not a Model"
	end

	local ok, cloneOrError = pcall(function()
		return template:Clone()
	end)
	if not ok or not cloneOrError then
		return nil, nil, "template could not be cloned: " .. tostring(cloneOrError)
	end

	local clone = cloneOrError
	clone.Name = name
	clone:SetAttribute("DevLogTransformationFXClone", true)
	local transparencyRecords = {}

	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript")
			or descendant:IsA("ProximityPrompt") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			-- Templates may have been hidden locally; clones must render according
			-- to their recorded Transparency, independent of the template.
			descendant.LocalTransparencyModifier = 0
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end

		if isTransparencyVisual(descendant) then
			local transparency = getVisualTransparency(descendant)
			table.insert(transparencyRecords, {
				Instance = descendant,
				Transparency = transparency,
			})
			descendant.Transparency = if initiallyVisible then transparency else 1
		end
	end

	return clone, transparencyRecords
end

local function setVisibility(records, alpha)
	alpha = math.clamp(alpha, 0, 1)
	for _, record in ipairs(records) do
		local instance = record.Instance
		if instance.Parent then
			instance.Transparency = record.Transparency + (1 - record.Transparency) * alpha
		end
	end
end

local function getBounds(model)
	local ok, boundsCFrame, boundsSize = pcall(function()
		return model:GetBoundingBox()
	end)
	if not ok then
		return nil, nil, tostring(boundsCFrame)
	end
	return boundsCFrame, boundsSize
end

local function getVerticalHalfExtent(boundsCFrame, boundsSize)
	return (
		math.abs(boundsCFrame.RightVector.Y) * boundsSize.X
			+ math.abs(boundsCFrame.UpVector.Y) * boundsSize.Y
			+ math.abs(boundsCFrame.LookVector.Y) * boundsSize.Z
	) * 0.5
end

local function easeInOut(alpha)
	alpha = math.clamp(alpha, 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

local function moveBoundsCenterTo(model, targetPosition)
	local boundsCFrame = getBounds(model)
	if not boundsCFrame then
		return false
	end
	local delta = targetPosition - boundsCFrame.Position
	if delta.Magnitude > 0.0001 then
		model:PivotTo(CFrame.new(delta) * model:GetPivot())
	end
	return true
end

local function getLongAxis(boundsCFrame, boundsSize, requestedAxis)
	if typeof(requestedAxis) == "Vector3" and requestedAxis.Magnitude > 0.0001 then
		return boundsCFrame:VectorToWorldSpace(requestedAxis.Unit).Unit
	end

	if boundsSize.X >= boundsSize.Y and boundsSize.X >= boundsSize.Z then
		return boundsCFrame.RightVector
	elseif boundsSize.Y >= boundsSize.Z then
		return boundsCFrame.UpVector
	end
	return boundsCFrame.LookVector
end

local function normalizedFiniteAxis(value)
	if typeof(value) ~= "Vector3" then return nil end
	local x, y, z = value.X, value.Y, value.Z
	if x ~= x or y ~= y or z ~= z
		or math.abs(x) == math.huge or math.abs(y) == math.huge or math.abs(z) == math.huge then
		return nil
	end
	local magnitude = value.Magnitude
	if magnitude ~= magnitude or magnitude == math.huge or magnitude <= 0.0001 then
		return nil
	end
	return value / magnitude
end

local function rotationBetween(from, to)
	local dot = math.clamp(from:Dot(to), -1, 1)
	local axis = from:Cross(to)
	if axis.Magnitude > 0.0001 then
		return CFrame.fromAxisAngle(axis.Unit, math.acos(dot))
	end
	if dot < 0 then
		local perpendicular = from:Cross(Vector3.yAxis)
		if perpendicular.Magnitude < 0.0001 then perpendicular = from:Cross(Vector3.xAxis) end
		return CFrame.fromAxisAngle(perpendicular.Unit, math.pi)
	end
	return CFrame.new()
end

local function makeChipBurst(effectFolder, sourceModel, center, count, strength, random)
	local colors = {}
	for _, descendant in ipairs(sourceModel:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Transparency < 1 then
			table.insert(colors, descendant.Color)
		end
	end
	if #colors == 0 then
		table.insert(colors, Color3.fromRGB(119, 77, 46))
	end

	local chips = {}
	for _ = 1, count do
		local chip = Instance.new("Part")
		chip.Name = "WoodChip"
		chip.Size = Vector3.new(
			random:NextNumber(0.16, 0.30),
			random:NextNumber(0.10, 0.20),
			random:NextNumber(0.18, 0.36)
		)
		chip.Color = colors[random:NextInteger(1, #colors)]
		chip.Material = Enum.Material.Wood
		chip.Anchored = true
		chip.CanCollide = false
		chip.CanTouch = false
		chip.CanQuery = false
		chip.CastShadow = false
		chip.CFrame = CFrame.new(center)
			* CFrame.fromOrientation(
				random:NextNumber(-math.pi, math.pi),
				random:NextNumber(-math.pi, math.pi),
				random:NextNumber(-math.pi, math.pi)
			)
		chip.Parent = effectFolder

		local horizontal = Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1))
		if horizontal.Magnitude < 0.05 then
			horizontal = Vector3.xAxis
		else
			horizontal = horizontal.Unit
		end
		table.insert(chips, {
			Part = chip,
			Origin = center,
			Velocity = horizontal * random:NextNumber(2.5, 5.5) * strength
				+ Vector3.yAxis * random:NextNumber(3, 6) * strength,
			Rotation = chip.CFrame.Rotation,
			RotationAxis = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-1, 1), random:NextNumber(-1, 1)).Unit,
			RotationSpeed = random:NextNumber(-9, 9),
		})
	end
	return chips
end

local function updateChips(chips, elapsed, burstTime, duration)
	for index = #chips, 1, -1 do
		local chipRecord = chips[index]
		local chip = chipRecord.Part
		local age = elapsed - burstTime
		if not chip.Parent or age >= duration then
			if chip.Parent then
				chip:Destroy()
			end
			table.remove(chips, index)
		else
			local gravity = Vector3.new(0, -Workspace.Gravity, 0)
			local position = chipRecord.Origin + chipRecord.Velocity * age + gravity * (0.5 * age * age)
			local rotation = CFrame.fromAxisAngle(chipRecord.RotationAxis, chipRecord.RotationSpeed * age)
			chip.CFrame = CFrame.new(position) * rotation * chipRecord.Rotation
			chip.Transparency = math.clamp(age / duration, 0, 1)
		end
	end
end

local function destroyIfParented(instance)
	if instance and instance.Parent then
		instance:Destroy()
	end
end

function LogTransformationFX.Play(sourceTemplate, destinationTemplate, options)
	if not RunService:IsStudio() then
		return nil, "LogTransformationFX is available only in Studio"
	end
	options = options or {}
	if type(options) ~= "table" then
		return nil, "options must be a table"
	end
	if not sourceTemplate or not sourceTemplate:IsA("Model") then
		return nil, "source template is missing or is not a Model"
	end
	if not destinationTemplate or not destinationTemplate:IsA("Model") then
		return nil, "destination template is missing or is not a Model"
	end

	local previous = activeBySourceTemplate[sourceTemplate]
	if previous then
		previous:Cancel()
	end

	local settings = {
		LiftDuration = optionNumber(options, "LiftDuration", 0.02, 2),
		CompressionDuration = optionNumber(options, "CompressionDuration", 0.02, 3),
		RevealDuration = optionNumber(options, "RevealDuration", 0.02, 2),
		FinishDuration = optionNumber(options, "FinishDuration", 0, 10),
		LiftHeight = optionNumber(options, "LiftHeight", 0, 8),
		RotationTurns = optionNumber(options, "RotationTurns", -2, 2),
		SourceEndScale = optionNumber(options, "SourceEndScale", 0.01, 0.5),
		DestinationStartScale = optionNumber(options, "DestinationStartScale", 0.4, 1),
		ChipCount = math.floor(optionNumber(options, "ChipCount", 0, 24)),
		ChipDuration = optionNumber(options, "ChipDuration", 0.05, 2),
		ChipStrength = optionNumber(options, "ChipStrength", 0, 3),
		HoverHeight = optionNumber(options, "HoverHeight", 0, 1),
		SurfaceEpsilon = optionNumber(options, "SurfaceEpsilon", 0, 0.5),
		RotationAxis = options.RotationAxis,
	}
	local groundY = options.GroundY
	if typeof(groundY) ~= "number" or groundY ~= groundY then
		groundY = nil
	else
		groundY = math.clamp(groundY, -100000, 100000)
	end

	local sourceClone, sourceVisuals, sourceError = cloneVisualTemplate(
		sourceTemplate,
		"TransformationSource_ClientFX",
		true
	)
	if not sourceClone then
		return nil, sourceError
	end

	local destinationClone, destinationVisuals, destinationError = cloneVisualTemplate(
		destinationTemplate,
		"TransformationDestination_ClientFX",
		false
	)
	if not destinationClone then
		destroyIfParented(sourceClone)
		return nil, destinationError
	end
	-- The Studio gallery uses a named standardized body. Its replicated
	-- template can arrive without a PrimaryPart reference, even when the body
	-- itself is present. Restore the clone's pivot before positioning it.
	if not destinationClone.PrimaryPart then
		local body = destinationClone:FindFirstChild("LogHandle")
		if not body or not body:IsA("BasePart") then
			sourceClone:Destroy()
			destinationClone:Destroy()
			return nil, "standardized destination has no LogHandle"
		end
		destinationClone.PrimaryPart = body
	end

	local sourceBoundsCFrame, sourceBoundsSize, sourceBoundsError = getBounds(sourceClone)
	if not sourceBoundsCFrame then
		destroyIfParented(sourceClone)
		destroyIfParented(destinationClone)
		return nil, "source has no measurable visual bounds: " .. tostring(sourceBoundsError)
	end

	-- Gallery templates stay in their reference positions. Reposition only the
	-- local source clone so the transformation plays at the isolated demo slot.
	-- A position-only override preserves the template's intended fallen angle.
	if typeof(options.SourcePosition) == "Vector3" then
		local targetPosition = options.SourcePosition
		if groundY ~= nil then
			targetPosition = Vector3.new(targetPosition.X, sourceBoundsCFrame.Position.Y, targetPosition.Z)
		end
		local translation = CFrame.new(targetPosition - sourceBoundsCFrame.Position)
		sourceClone:PivotTo(translation * sourceClone:GetPivot())
		sourceBoundsCFrame, sourceBoundsSize = getBounds(sourceClone)
	elseif typeof(options.SourceCFrame) == "CFrame" then
		local sourceAlignment = options.SourceCFrame * sourceBoundsCFrame:Inverse()
		sourceClone:PivotTo(sourceAlignment * sourceClone:GetPivot())
		sourceBoundsCFrame, sourceBoundsSize = getBounds(sourceClone)
	end
	if not sourceBoundsCFrame or not sourceBoundsSize then
		destroyIfParented(sourceClone)
		destroyIfParented(destinationClone)
		return nil, "source bounds became unavailable during placement"
	end
	if groundY ~= nil then
		local sourceHalfHeight = getVerticalHalfExtent(sourceBoundsCFrame, sourceBoundsSize)
		local targetCenterY = groundY + sourceHalfHeight + settings.SurfaceEpsilon
		local translation = CFrame.new(0, targetCenterY - sourceBoundsCFrame.Position.Y, 0)
		sourceClone:PivotTo(translation * sourceClone:GetPivot())
		sourceBoundsCFrame, sourceBoundsSize = getBounds(sourceClone)
		if not sourceBoundsCFrame or not sourceBoundsSize then
			destroyIfParented(sourceClone)
			destroyIfParented(destinationClone)
			return nil, "source bounds became unavailable during ground placement"
		end
	end

	local destinationBoundsCFrame, destinationBoundsSize, destinationBoundsError = getBounds(destinationClone)
	if not sourceBoundsCFrame or not destinationBoundsCFrame or not destinationBoundsSize then
		destroyIfParented(sourceClone)
		destroyIfParented(destinationClone)
		return nil, "source or destination has no measurable visual bounds: " .. tostring(destinationBoundsError)
	end

	local originalSourcePivot = sourceClone:GetPivot()
	local sourceCenter = sourceBoundsCFrame.Position
	local originalSourceScale = sourceClone:GetScale()
	local originalDestinationScale = destinationClone:GetScale()
	local axis = getLongAxis(sourceBoundsCFrame, sourceBoundsSize, settings.RotationAxis)
	local destinationAlignment = sourceBoundsCFrame * destinationBoundsCFrame:Inverse()
	if options.AlignLongAxis == true then
		local destinationAxis = getLongAxis(destinationBoundsCFrame, destinationBoundsSize)
		destinationAlignment = CFrame.new(sourceCenter)
			* rotationBetween(destinationAxis, axis)
			* CFrame.new(-destinationBoundsCFrame.Position)
	end
	local fxFolder = getFxFolder()
	local effectFolder = Instance.new("Folder")
	effectFolder.Name = "TransformationRun"
	effectFolder.Parent = fxFolder
	sourceClone.Parent = effectFolder
	destinationClone.Parent = effectFolder

	local liftDuration = settings.LiftDuration
	local compressionDuration = settings.CompressionDuration
	local revealDuration = settings.RevealDuration
	local compressionStart = liftDuration
	local revealStart = liftDuration + compressionDuration
	local transformDuration = liftDuration + compressionDuration + revealDuration
	local fadeStart = liftDuration + compressionDuration * 0.62
	local chips = {}
	local chipsCreated = false
	local burstTime = compressionStart + compressionDuration * 0.24
	local random = Random.new()
	local controller = {
		Active = true,
		Completed = false,
		Phase = "setup",
		Failure = nil,
		SourceTemplate = sourceTemplate,
		Connection = nil,
	}

	local function removeEmptyFxFolder()
		if fxFolder.Parent and #fxFolder:GetChildren() == 0 then
			fxFolder:Destroy()
		end
	end

	function controller:Cancel()
		if not self.Active then
			return
		end
		self.Active = false
		if self.Connection then
			self.Connection:Disconnect()
			self.Connection = nil
		end
		destroyIfParented(effectFolder)
		if activeBySourceTemplate[sourceTemplate] == self then
			activeBySourceTemplate[sourceTemplate] = nil
		end
		removeEmptyFxFolder()
	end

	-- Transfer the actual revealed visual, rather than replacing it for flight.
	function controller:TakeResult(parent)
		if not self.Active or not self.Ready or not parent or not parent.Parent or not destinationClone.Parent then
			return nil
		end
		-- Complete the reveal explicitly before handing this same model to the
		-- pickup animation. Preserve each part's original template transparency.
		setVisibility(destinationVisuals, 0)
		for _, record in ipairs(destinationVisuals) do
			if record.Instance:IsA("BasePart") then
				record.Instance.LocalTransparencyModifier = 0
			end
		end
		destinationClone.Parent = parent
		self.Result = destinationClone
		self:Cancel()
		if not destinationClone.PrimaryPart then
			local body = destinationClone:FindFirstChild("LogHandle")
			if body and body:IsA("BasePart") then destinationClone.PrimaryPart = body end
		end
		return destinationClone
	end

	local placed, placementError = pcall(function()
		destinationClone:PivotTo(destinationAlignment * destinationClone:GetPivot())
	end)
	if not placed then
		controller:Cancel()
		return nil, "destination alignment failed: " .. tostring(placementError)
	end
	local destinationAlignedBoundsCFrame, destinationAlignedBoundsSize = getBounds(destinationClone)
	if not destinationAlignedBoundsCFrame or not destinationAlignedBoundsSize then
		destroyIfParented(effectFolder)
		removeEmptyFxFolder()
		return nil, "destination bounds became unavailable during alignment"
	end
	local destinationFinalPivot = destinationClone:GetPivot()
	local sourceInitialScale = originalSourceScale
	local transformAxis = normalizedFiniteAxis(options.SpinAxisWorld) or axis
	local rotationRadians = math.pi * 2 * settings.RotationTurns
	local sourceDestroyed = false

	local function sourceTransformAt(elapsed)
		local rotationProgress = math.clamp(elapsed / (liftDuration + compressionDuration), 0, 1)
		local easedRotation = easeInOut(rotationProgress)
		local angle = rotationRadians * easedRotation

		local rise
		if elapsed <= liftDuration then
			rise = settings.LiftHeight * easeInOut(elapsed / liftDuration)
		elseif options.HoldLift == true then
			rise = settings.LiftHeight
		else
			local compressionProgress = math.clamp((elapsed - liftDuration) / compressionDuration, 0, 1)
			rise = settings.LiftHeight * (1 - easeInOut(compressionProgress))
		end

		return CFrame.new(sourceCenter + Vector3.yAxis * rise)
			* CFrame.fromAxisAngle(transformAxis, angle)
			* CFrame.new(-sourceCenter)
	end

	local finalSourceTransform = sourceTransformAt(liftDuration + compressionDuration)
	local finalDestinationPivot = finalSourceTransform * destinationClone:GetPivot()
	local destinationCenter = finalSourceTransform:PointToWorldSpace(sourceCenter)
	local destinationGroundCenter = destinationCenter
	if groundY ~= nil then
		local alignedDestinationBounds = finalSourceTransform * destinationAlignedBoundsCFrame
		local destinationHalfHeight = getVerticalHalfExtent(alignedDestinationBounds, destinationAlignedBoundsSize)
		destinationGroundCenter = Vector3.new(
			alignedDestinationBounds.Position.X,
			groundY + destinationHalfHeight + settings.SurfaceEpsilon,
			alignedDestinationBounds.Position.Z
		)
	end
	local startedAt = os.clock()
	local readyAt = nil

	local function update(elapsed)
		if not sourceDestroyed then
			controller.Phase = "source compression"
			local transform = sourceTransformAt(elapsed)
			local compressionProgress = math.clamp((elapsed - compressionStart) / compressionDuration, 0, 1)
			local sourceScaleFactor = if elapsed < compressionStart
				then 1
				else 1 + (settings.SourceEndScale - 1) * easeInOut(compressionProgress)

			sourceClone:PivotTo(transform * originalSourcePivot)
			sourceClone:ScaleTo(sourceInitialScale * sourceScaleFactor)
			local transformedCenter = transform:PointToWorldSpace(sourceCenter)
			moveBoundsCenterTo(sourceClone, transformedCenter)

			local sourceFadeAlpha = if elapsed <= fadeStart
				then 0
				else easeInOut((elapsed - fadeStart) / math.max(0.001, transformDuration - fadeStart))
			setVisibility(sourceVisuals, sourceFadeAlpha)

			if not chipsCreated and elapsed >= burstTime and settings.ChipCount > 0 then
				controller.Phase = "wood-chip creation"
				chipsCreated = true
				chips = makeChipBurst(
					effectFolder,
					sourceClone,
					transformedCenter,
					settings.ChipCount,
					settings.ChipStrength,
					random
				)
			end
		end

		controller.Phase = "wood-chip update"
		updateChips(chips, elapsed, burstTime, settings.ChipDuration)

		if elapsed >= revealStart then
			controller.Phase = "standard log reveal"
			local revealProgress = math.clamp((elapsed - revealStart) / revealDuration, 0, 1)
			local easedReveal = easeInOut(revealProgress)
			local destinationCenterAtReveal = destinationCenter:Lerp(destinationGroundCenter, easedReveal)
			local targetPivot = CFrame.new(
				0,
				(destinationGroundCenter.Y - destinationCenter.Y) * easedReveal,
				0
			) * finalDestinationPivot
			if elapsed < transformDuration then
				destinationClone:PivotTo(targetPivot)
			else
				local hover = math.sin((elapsed - transformDuration) * math.pi * 2) * settings.HoverHeight
				destinationClone:PivotTo(CFrame.new(0, hover, 0) * targetPivot)
			end
			destinationClone:ScaleTo(originalDestinationScale * (
				settings.DestinationStartScale + (1 - settings.DestinationStartScale) * easedReveal
			))
			local hover = if elapsed >= transformDuration
				then math.sin((elapsed - transformDuration) * math.pi * 2) * settings.HoverHeight
				else 0
			moveBoundsCenterTo(destinationClone, destinationCenterAtReveal + Vector3.yAxis * hover)
			setVisibility(destinationVisuals, 1 - easedReveal)
		end

		if elapsed >= transformDuration and not sourceDestroyed then
			controller.Phase = "transformation completion"
			sourceDestroyed = true
			destroyIfParented(sourceClone)
			setVisibility(sourceVisuals, 1)
			controller.Ready = true
			controller.Phase = "ready for handoff"
			readyAt = os.clock()
		end

		-- Give the consumer its full handoff window even after a delayed frame.
		if readyAt and os.clock() - readyAt >= settings.FinishDuration then
			controller.Completed = true
			controller.Failure = "handoff window expired"
			controller:Cancel()
		end
	end

	activeBySourceTemplate[sourceTemplate] = controller
	controller.Connection = RunService.Heartbeat:Connect(function()
		if not controller.Active then
			return
		end
		if not effectFolder.Parent or (not sourceDestroyed and not sourceClone.Parent) or not destinationClone.Parent then
			controller.Failure = "effect, source, or standardized destination was removed during " .. controller.Phase
			controller:Cancel()
			return
		end

		local success, errorMessage = pcall(update, os.clock() - startedAt)
		if not success then
			controller.Failure = controller.Phase .. ": " .. tostring(errorMessage)
			warn("[LogTransformationFX] Animation stopped safely: " .. controller.Failure)
			controller:Cancel()
		end
	end)

	return controller
end

return LogTransformationFX
