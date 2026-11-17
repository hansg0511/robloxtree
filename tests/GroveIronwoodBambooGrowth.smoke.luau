-- Paste into Roblox Studio SERVER Command Bar after connecting Rojo.
-- Non-mutating previews: inspect exact Ironwood trunk order and Bamboo
-- synchronized cane layers without touching any Grove profile entries.
local Tree = require(game.ServerScriptService.Trees.TreeObject)
local function check(label, condition)
	assert(condition, label .. " failed")
end

local function preview(species, fraction)
	local model = Tree.BuildPreviewModel(species, {
		GroveStage = if fraction >= 1 then "mature" else "young",
		SizePotential = 1,
		GrowthProgress = fraction,
	})
	check(species .. " model built", model ~= nil)
	return model
end

local function visible(part)
	return part ~= nil and part.Transparency < 0.99
end

-- A three-section Ironwood should never grow its top section before
-- its middle section, regardless of part height or decorative studs.
for _, case in ipairs({
	{ Fraction = 0.1, Bottom = true, Middle = false, Top = false },
	{ Fraction = 0.25, Bottom = true, Middle = true, Top = false },
	{ Fraction = 0.35, Bottom = true, Middle = true, Top = true },
	{ Fraction = 1, Bottom = true, Middle = true, Top = true },
}) do
	local tree = preview("Ironwood", case.Fraction)
	local lower = tree:FindFirstChild("Bark", true)
	local middle = tree:FindFirstChild("BarkBrick1", true)
	local upper = tree:FindFirstChild("BarkBrick2", true)
	check("Ironwood contains lower/middle/upper", lower and middle and upper)
	check("Ironwood lower at " .. case.Fraction, visible(lower) == case.Bottom)
	check("Ironwood middle at " .. case.Fraction, visible(middle) == case.Middle)
	check("Ironwood upper at " .. case.Fraction, visible(upper) == case.Top)
	for _, part in ipairs(tree:GetDescendants()) do
		if part:IsA("BasePart") and part.Name == "BarkStud" then
			check("No floating-looking Ironwood studs during Grove growth", not visible(part))
		end
	end
	tree:Destroy()
end

local caneNames = {
	BambooCore = true,
	BambooStalk2 = true,
	BambooStalk3 = true,
	BambooStalk4 = true,
	BambooStalk5 = true,
}
for _, case in ipairs({
	{ Fraction = 0, SegmentCount = 0, Stumps = true, Native = false },
	{ Fraction = 0.16, SegmentCount = 1, Stumps = true, Native = false },
	{ Fraction = 0.35, SegmentCount = 3, Stumps = false, Native = false },
	{ Fraction = 0.60, SegmentCount = 6, Stumps = false, Native = false },
	{ Fraction = 0.65, SegmentCount = 0, Stumps = false, Native = true },
	{ Fraction = 1, SegmentCount = 0, Stumps = false, Native = true },
}) do
	local tree = preview("Bamboo", case.Fraction)
	local byCane = {}
	local stumpCount = 0
	local nativeCount = 0
	for _, part in ipairs(tree:GetDescendants()) do
		if part:IsA("BasePart") then
			if part.Name == "GroveBambooGrowthSegment" and visible(part) then
				local caneName = part:GetAttribute("GroveGrowthCane")
				check("Bamboo segment belongs to a known cane", caneNames[caneName] == true)
				byCane[caneName] = (byCane[caneName] or 0) + 1
			elseif string.match(part.Name, "^GroveBambooCulm%d+Stump$") and visible(part) then
				stumpCount += 1
			elseif caneNames[part.Name] and visible(part) then
				nativeCount += 1
			end
		end
	end
	check("Bamboo stump visibility at " .. case.Fraction,
		(stumpCount == 5) == case.Stumps)
	check("Bamboo native canes together at " .. case.Fraction,
		(nativeCount == 5) == case.Native)
	for cane in pairs(caneNames) do
		check("Bamboo " .. cane .. " grows in sync at " .. case.Fraction,
			(byCane[cane] or 0) == case.SegmentCount)
	end
	tree:Destroy()
end

-- Keep the user's already-approved Oak path free of Bamboo proxy pieces.
local oak = preview("GroveOak", 0.35)
check("Grove Oak remains the approved procedural model",
	oak:GetAttribute("ProceduralStarterOak") == true)
check("Oak is never given bamboo growth proxies",
	oak:FindFirstChild("GroveBambooGrowthSegment", true) == nil)
oak:Destroy()

print("Grove Ironwood/Bamboo growth regression checks passed")
return true
