-- Studio-only local prompt bridge for the DevTreeGallery transformation demo.
-- The preview is cosmetic and does not communicate with gameplay remotes.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local modules = script.Parent:WaitForChild("Inventory"):WaitForChild("Modules")
local LogTransformationFX = require(modules:WaitForChild("LogTransformationFX"))

local GALLERY_NAME = "DevTreeGallery"
local PLAYGROUND_NAME = "TransformationPlayground"
local PROMPT_ATTRIBUTE = "DevTreeGalleryTransformationPrompt"
local SOURCE_TEMPLATE_FALLBACK = "TransformationSourceTemplate"
local DESTINATION_TEMPLATE_FALLBACK = "TransformationDestinationTemplate"

-- These are the first tuning values for the visual prototype. The module can
-- also be reused with a different table for other species or effects.
local ANIMATION_OPTIONS = {
	LiftDuration = 0.10,
	CompressionDuration = 0.15,
	RevealDuration = 0.10,
	FinishDuration = 0.65,
	LiftHeight = 0.9,
	RotationTurns = 0.35,
	SourceEndScale = 0.08,
	DestinationStartScale = 0.84,
	ChipCount = 8,
	ChipDuration = 0.28,
	ChipStrength = 1,
	HoverHeight = 0,
	SurfaceEpsilon = 0.04,
}

local activeController = nil

local function findSupportTopY(gallery, demoSlot)
	local bestTopY = nil
	for _, descendant in ipairs(gallery:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= demoSlot and descendant.CanCollide then
			local up = descendant.CFrame.UpVector
			if up.Y > 0.99 then
				local topY = descendant.Position.Y + descendant.Size.Y * 0.5 * up.Y
				local pointInPart = descendant.CFrame:PointToObjectSpace(
					Vector3.new(demoSlot.Position.X, topY, demoSlot.Position.Z)
				)
				local coversSlot = math.abs(pointInPart.X) <= descendant.Size.X * 0.5
					and math.abs(pointInPart.Z) <= descendant.Size.Z * 0.5
				if coversSlot and topY <= demoSlot.Position.Y + demoSlot.Size.Y * 0.5 then
					bestTopY = if bestTopY == nil then topY else math.max(bestTopY, topY)
				end
			end
		end
	end

	-- The slot's lower face is the gallery's intended surface plane when no
	-- collidable gallery surface covers it.
	return bestTopY or (demoSlot.Position.Y - demoSlot.Size.Y * 0.5)
end

local function getMarkedPlayground(prompt)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return nil
	end
	if prompt:GetAttribute(PROMPT_ATTRIBUTE) ~= true then
		return nil
	end

	local playground = prompt:FindFirstAncestor(PLAYGROUND_NAME)
	if not playground or playground.Parent ~= Workspace:FindFirstChild(GALLERY_NAME) then
		return nil
	end
	return playground
end

local function resolveTemplate(playground, demoSlot, attributeName, fallbackName)
	local configuredName = demoSlot and demoSlot:GetAttribute(attributeName)
	local templateName = if typeof(configuredName) == "string" and configuredName ~= ""
		then configuredName
		else fallbackName
	local template = playground:FindFirstChild(templateName)
	if template and template:IsA("Model") then
		return template
	end
	return nil, templateName
end

local function onPromptTriggered(prompt)
	local playground = getMarkedPlayground(prompt)
	if not playground then
		return
	end
	local demoSlot = playground:FindFirstChild("DemoSlot")
	if not demoSlot or not demoSlot:IsA("BasePart") then
		warn("[DevTreeGallery] Transformation DemoSlot is missing")
		return
	end

	local sourceTemplate, sourceName = resolveTemplate(
		playground,
		demoSlot,
		"SourceTemplateName",
		SOURCE_TEMPLATE_FALLBACK
	)
	local destinationTemplate, destinationName = resolveTemplate(
		playground,
		demoSlot,
		"DestinationTemplateName",
		DESTINATION_TEMPLATE_FALLBACK
	)
	if not sourceTemplate or not destinationTemplate then
		warn(
			"[DevTreeGallery] Transformation preview needs Model templates named "
				.. tostring(sourceName)
				.. " and "
				.. tostring(destinationName)
		)
		return
	end

	if activeController and activeController.Active then
		activeController:Cancel()
	end
	activeController = nil

	local options = table.clone(ANIMATION_OPTIONS)
	options.SourcePosition = demoSlot.Position
	options.GroundY = findSupportTopY(playground.Parent, demoSlot)
	local controller, errorMessage = LogTransformationFX.Play(
		sourceTemplate,
		destinationTemplate,
		options
	)
	if not controller then
		warn("[DevTreeGallery] Could not play log transformation: " .. tostring(errorMessage))
		return
	end
	activeController = controller
end

ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)
