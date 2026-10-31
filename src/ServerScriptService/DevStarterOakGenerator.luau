-- Studio-only gallery adapter over the shared server-side Oak generator.
local RunService = game:GetService("RunService")
local StarterOakGenerator = require(
	game:GetService("ServerScriptService"):WaitForChild("Trees"):WaitForChild("StarterOakGenerator")
)

local DevStarterOakGenerator = {}

function DevStarterOakGenerator.Generate(seed, options)
	assert(RunService:IsServer(), "DevStarterOakGenerator.Generate must run on the server")
	assert(RunService:IsStudio(), "DevStarterOakGenerator is available only in Roblox Studio")

	local model = StarterOakGenerator.Generate(seed, options)
	model.Name = "DevStarterOak_" .. tostring(model:GetAttribute("Seed"))
	model:SetAttribute("DevTreeGalleryPreview", true)
	model:SetAttribute("VisualOnly", true)
	model:SetAttribute("PrototypeOnly", true)
	model:SetAttribute("DesignDirection", "StarterOakStructuralStudy")
	return model
end

return DevStarterOakGenerator
