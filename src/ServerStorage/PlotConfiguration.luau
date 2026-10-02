-- Server-owned layout configuration. The locations are plot boundaries only;
-- individual trees are still placed inside each plot's open GroveArea.
local PlotConfiguration = {
	MAX_PLOTS = 8,
	PLOT_SIZE = Vector3.new(42, 0.05, 42),
	GROVE_MARGIN = 6,
	PLOT_COLOR = Color3.fromRGB(118, 160, 98),

	-- A ground-level U leaves its front open for the eventual base-to-forest route.
	-- This is presentation/layout data, not progression security.
	PLOT_CENTERS = {
		Vector3.new(-70, 0, -48),
		Vector3.new(-70, 0, 0),
		Vector3.new(-70, 0, 48),
		Vector3.new(-24, 0, 96),
		Vector3.new(24, 0, 96),
		Vector3.new(70, 0, 48),
		Vector3.new(70, 0, 0),
		Vector3.new(70, 0, -48),
	},
}

assert(#PlotConfiguration.PLOT_CENTERS == PlotConfiguration.MAX_PLOTS,
	"PlotConfiguration must define exactly one center for every plot")

return PlotConfiguration
