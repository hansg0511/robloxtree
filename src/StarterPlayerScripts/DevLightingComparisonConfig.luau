-- Studio-only preview presets. LightingStyle is intentionally read-only here;
-- set it to Soft in Studio Properties if needed.
local commonValues = {
	Brightness = 2,
	ClockTime = 14,
	EnvironmentSpecularScale = 0,
	EnvironmentDiffuseScale = 0,
	ExposureCompensation = 0,
}

local function preset(mode, label, ambient, outdoorAmbient, globalShadows)
	local values = table.clone(commonValues)
	values.Ambient = Color3.fromRGB(ambient, ambient, ambient)
	values.OutdoorAmbient = Color3.fromRGB(outdoorAmbient, outdoorAmbient, outdoorAmbient)
	values.GlobalShadows = globalShadows
	return {
		Mode = mode,
		Label = label,
		Values = values,
	}
end

return {
	RequiredLightingStyle = "Soft",
	-- These are the writable Lighting fields the preview changes and restores.
	LightingProperties = {
		"Brightness",
		"ClockTime",
		"Ambient",
		"OutdoorAmbient",
		"EnvironmentSpecularScale",
		"EnvironmentDiffuseScale",
		"ExposureCompensation",
		"GlobalShadows",
	},
	AtmosphereProperties = { "Density", "Haze", "Glare" },
	AtmospherePreviewValues = {
		Density = 0,
		Haze = 0,
		Glare = 0,
	},
	Presets = {
		BrightCartoonSoft = preset("A", "A · BRIGHT CARTOON SOFT", 150, 180, true),
		FlatCartoon = preset("B", "B · FLAT CARTOON", 175, 175, false),
	},
}
