-- Shared presentation data and proportion rules for standardized Oak logs.
-- Keep this module free of inventory and gameplay state so server-built logs
-- and client-only pickup visuals use the same appearance.
local OakLogAppearance = {}

local OAK_PALETTE = {
	Bark = Color3.fromRGB(151, 82, 43),
	BarkHighlight = Color3.fromRGB(190, 116, 58),
	BarkShadow = Color3.fromRGB(112, 59, 34),
	CutEnd = Color3.fromRGB(244, 202, 133),
	CutRing = Color3.fromRGB(186, 132, 75),
	CutRingShadow = Color3.fromRGB(143, 92, 50),
	Leaf = Color3.fromRGB(105, 202, 67),
	LeafHighlight = Color3.fromRGB(156, 226, 77),
	LeafShadow = Color3.fromRGB(69, 160, 58),
}

OakLogAppearance.Palette = table.freeze(OAK_PALETTE)

function OakLogAppearance.SetSmoothSurfaces(part)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.FrontSurface = Enum.SurfaceType.Smooth
	part.BackSurface = Enum.SurfaceType.Smooth
	part.LeftSurface = Enum.SurfaceType.Smooth
	part.RightSurface = Enum.SurfaceType.Smooth
end

function OakLogAppearance.GetBarkStripDefinitions(length, diameter, sizeScale, palette, isOak)
	local stripThickness = 0.045 * sizeScale
	local stripWidth = diameter * 0.09
	local stripLength = length * 0.82
	if isOak then
		-- Match the gallery's warm negative-Z and recessed positive-Y accents.
		return {
			{
				Name = "BarkGrain1",
				Position = Vector3.new(0, 0, -diameter * 0.5 + stripThickness * 0.15),
				Size = Vector3.new(stripLength, stripWidth, stripThickness),
				Color = palette.BarkHighlight,
			},
			{
				Name = "BarkGrain2",
				Position = Vector3.new(0, diameter * 0.5 - stripThickness * 0.15, 0),
				Size = Vector3.new(stripLength, stripThickness, stripWidth),
				Color = palette.BarkShadow,
			},
		}
	end

	return {
		{
			Name = "BarkGrain1",
			Position = Vector3.new(0, diameter * 0.5 - stripThickness * 0.15, 0),
			Size = Vector3.new(stripLength, stripThickness, stripWidth),
			Color = palette.BarkHighlight,
		},
		{
			Name = "BarkGrain2",
			Position = Vector3.new(0, -diameter * 0.5 + stripThickness * 0.15, 0),
			Size = Vector3.new(stripLength, stripThickness, stripWidth),
			Color = palette.BarkShadow,
		},
		{
			Name = "BarkGrain3",
			Position = Vector3.new(0, 0, diameter * 0.5 - stripThickness * 0.15),
			Size = Vector3.new(stripLength, stripWidth, stripThickness),
			Color = palette.BarkHighlight,
		},
		{
			Name = "BarkGrain4",
			Position = Vector3.new(0, 0, -diameter * 0.5 + stripThickness * 0.15),
			Size = Vector3.new(stripLength, stripWidth, stripThickness),
			Color = palette.BarkShadow,
		},
	}
end

function OakLogAppearance.GetEndGrainLayerDefinitions(direction, length, diameter, sizeScale, palette, isOak)
	-- Oak keeps a restrained two-layer cut face; non-Oak retains its existing
	-- four-layer treatment.
	local layers = if isOak then {
		{ DiameterScale = 0.68, Color = palette.CutRingShadow },
		{ DiameterScale = 0.34, Color = palette.CutRing },
	} else {
		{ DiameterScale = 0.68, Color = palette.CutRingShadow },
		{ DiameterScale = 0.48, Color = palette.CutRing },
		{ DiameterScale = 0.25, Color = palette.CutRingShadow },
		{ DiameterScale = 0.12, Color = palette.CutEnd },
	}
	local definitions = table.create(#layers)
	for index, layer in ipairs(layers) do
		local thickness = 0.012 * sizeScale
		definitions[index] = {
			Name = "GrowthRing" .. index,
			Position = Vector3.new(direction * (length * 0.5 + thickness * index), 0, 0),
			Size = Vector3.new(thickness, diameter * layer.DiameterScale, diameter * layer.DiameterScale),
			Color = layer.Color,
		}
	end
	return definitions
end

return OakLogAppearance
