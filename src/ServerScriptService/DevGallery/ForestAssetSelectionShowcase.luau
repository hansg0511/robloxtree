--!strict
-- Studio-only gallery for curated, source-controlled Creator Store templates.
-- No assets are loaded by ID. Only templates already under
-- ServerStorage.DevToolboxAssets.ForestToolboxAssets (or a supplied root) are cloned.
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Showcase = {}

local OWNER = "ForestAssetSelectionShowcase"
local TEMPLATE_ROOT = "ForestToolboxAssets"
local PER_MODEL_INSTANCE_CAP = 280
local PER_MODEL_PART_CAP = 100
local MODEL_EXTENT_CAP = 256
local CARD_PREVIEW_EXTENT = 8.5
local COMPOSITION_PREVIEW_EXTENT = 8.25
local OAK_PREVIEW_EXTENT = 20
local MESA_PREVIEW_EXTENT = 18
local TOTAL_MODEL_CAP = 64
local TOTAL_INSTANCE_CAP = 6000
local TOTAL_PART_CAP = 2800
local COMPOSITION_ASSET_CAP = 5
local COLUMNS = 8
local CARD_PITCH = 13.4
local ROW_PITCH = 14

local COLORS = {
	Deck = Color3.fromRGB(82, 117, 76),
	DeckAlt = Color3.fromRGB(70, 102, 67),
	Pad = Color3.fromRGB(216, 191, 132),
	Available = Color3.fromRGB(64, 106, 70),
	Unavailable = Color3.fromRGB(110, 76, 66),
	Text = Color3.fromRGB(247, 242, 220),
}

local PACKS = {
	{ Name = "Synty Nature Pack", Id = "6933438443" },
	{ Name = "Low Poly Asset Pack", Id = "7436760067" },
	{ Name = "Stylised Low-Poly Nature Pack", Id = "6503281311" },
	{ Name = "Forest Pack", Id = "6432306802" },
	{ Name = "Stylized Nature Pack", Id = "6594760658" },
	{ Name = "Free Low Poly Asset Pack", Id = "79195618410265" },
	{ Name = "Crazed's Stylized Asset Pack", Id = "12477025465" },
}

local CANDIDATES = {
	{ "Low Poly Bushes Kit", "14438790919", "Bushes" },
	{ "Bush V2", "5555817140", "Bushes" },
	{ "Low Poly Big Bush", "14720410685", "Bushes" },
	{ "Bush (2)", "8782385501", "Bushes" },
	{ "Mesh Rock Pack", "5642566546", "Rocks" },
	{ "Rock Pack", "8421400545", "Rocks" },
	{ "Pebble", "337332869", "Rocks" },
	{ "Old Pebble", "10592816110", "Rocks" },
	{ "Arid Rock Pack", "104711608624243", "Rocks" },
	{ "Low Poly Log", "11312714034", "Wood" },
	{ "Wood Log", "265431546", "Wood" },
	{ "Dead Tree Fallen", "18986398652", "Wood" },
	{ "Tree Stump", "167792459", "Wood" },
	{ "Colored Flowers Pack", "17638037773", "Plants" },
	{ "Flowers Pack", "15522563459", "Plants" },
	{ "Grass Pack", "8729589253", "Plants" },
	{ "Fern", "4620415269", "Plants" },
	{ "Fourleaf Clover", "10862920725", "Plants" },
	{ "Retro Mushrooms", "16573639066", "Plants" },
	{ "Glowing Mushroom", "3350230927", "Plants" },
	{ "Dirt Path", "5216151629", "Paths" },
	{ "Wooden Fence", "8399365124", "Props" },
	{ "Wood Wooden Fence", "10348034923", "Props" },
	{ "Wooden Sign", "3382116092", "Props" },
	{ "Medium Wooden Sign", "12949136308", "Props" },
	{ "Low Poly Campfire", "8636042955", "Props" },
}

local CATEGORY_ORDER = { "Source Packs", "Bushes", "Rocks", "Wood", "Plants", "Paths", "Props", "Other" }
local CATEGORY_LABEL = {
	["Source Packs"] = "SOURCE PACK FAMILIES",
	Bushes = "BUSHES & SHRUBS",
	Rocks = "ROCKS & PEBBLES",
	Wood = "FALLEN LOGS & STUMPS",
	Plants = "FLOWERS, GRASS & GROUND VEGETATION",
	Paths = "PATHS & GROUND TREATMENTS",
	Props = "FENCES, SIGNS & MISCELLANEOUS PROPS",
	Other = "OTHER CURATED TEMPLATES",
}
local CATEGORY_MAP = {
	bush = "Bushes", bushes = "Bushes", shrub = "Bushes", shrubs = "Bushes",
	rock = "Rocks", rocks = "Rocks", pebble = "Rocks", pebbles = "Rocks",
	wood = "Wood", log = "Wood", logs = "Wood", stump = "Wood", stumps = "Wood",
	plant = "Plants", plants = "Plants", flower = "Plants", flowers = "Plants",
	grass = "Plants", vegetation = "Plants",
	path = "Paths", paths = "Paths", ground = "Paths",
	prop = "Props", props = "Props", fence = "Props", fences = "Props",
	sign = "Props", signs = "Props", misc = "Props",
}

local COMPOSITIONS = {
	{
		PackIndex = 1,
		Name = "SYNTY-FOCUSED",
		ModelNames = { "Synty_Bush01", "Synty_Rock01", "Synty_Log", "Synty_Flowers", "Synty_Grass" },
	},
	{
		PackIndex = 3,
		Name = "STYLISED LOW-POLY",
		ModelNames = { "Stylised_Bush01", "Stylised_Bush02", "Stylised_Rock01", "Synty_Log", "Colored_Flower01" },
	},
	{
		Name = "CURATED MIXTURE",
		ModelNames = { "Forest_Bush", "Synty_Rock01", "Forest_Log", "Individual_FlowerBush", "Individual_BlockyFlowers" },
	},
}

type Template = {
	Model: Model,
	Name: string,
	Id: string,
	Pack: string,
	Creator: string,
	Category: string,
	Variant: string,
	Instances: number,
	Parts: number,
	Triangles: number?,
	Rejected: string?,
}

type Card = {
	Name: string,
	Id: string,
	Pack: string,
	Creator: string,
	Category: string,
	Variant: string,
	Template: Template?,
	Reason: string?,
	ListingStatus: string?,
	PackFamily: boolean?,
}

local function mark(instance: Instance)
	instance:SetAttribute("DevGalleryOwner", OWNER)
	instance:SetAttribute("DevOnly", true)
	instance:SetAttribute("VisualOnly", true)
	instance:SetAttribute("PrototypeOnly", true)
	instance:SetAttribute("AssetSelectionPreview", true)
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, collidable: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collidable
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	mark(p)
	p.Parent = parent
	return p
end

local function label(parent: Instance, name: string, title: string, body: string, pos: Vector3, color: Color3, size: UDim2?, maxDistance: number?)
	local anchor = part(parent, name .. "Anchor", Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), Color3.new(1, 1, 1), false)
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = size or UDim2.fromOffset(260, 112)
	gui.MaxDistance = maxDistance or 80
	gui.AlwaysOnTop = true
	gui.Parent = anchor
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	local heading = Instance.new("TextLabel")
	heading.Position = UDim2.fromOffset(7, 5)
	heading.Size = UDim2.new(1, -14, 0, 25)
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.GothamBold
	heading.Text = title
	heading.TextColor3 = COLORS.Text
	heading.TextSize = 15
	heading.TextWrapped = true
	heading.Parent = frame
	local details = Instance.new("TextLabel")
	details.Position = UDim2.fromOffset(8, 30)
	details.Size = UDim2.new(1, -16, 1, -36)
	details.BackgroundTransparency = 1
	details.Font = Enum.Font.Gotham
	details.Text = body
	details.TextColor3 = COLORS.Text
	details.TextSize = 12
	details.TextWrapped = true
	details.TextYAlignment = Enum.TextYAlignment.Top
	details.Parent = frame
end

local function normalized(text: string): string
	return string.lower(string.gsub(text, "[^%w]", ""))
end

local function stringAttr(value: any): string?
	if typeof(value) == "string" and value ~= "" then
		return value
	elseif typeof(value) == "number" then
		return string.format("%.0f", value)
	end
	return nil
end

local function inheritedAttr(instance: Instance, root: Instance, key: string): string?
	local current: Instance? = instance
	while current do
		local value = stringAttr(current:GetAttribute(key))
		if value then
			return value
		end
		if current == root then
			break
		end
		current = current.Parent
	end
	return nil
end

local function categoryFromName(name: string?): string
	if not name then
		return "Other"
	end
	return CATEGORY_MAP[normalized(name)] or "Other"
end

local function candidateCategory(id: string): string?
	for _, candidate in ipairs(CANDIDATES) do
		if candidate[2] == id then
			return candidate[3]
		end
	end
	return nil
end

local PRICE_UNVERIFIED = {
	["7436760067"] = true,
	["6594760658"] = true,
	["5642566546"] = true,
	["8729589253"] = true,
}

local function listingStatus(id: string, templatePresent: boolean): string
	if PRICE_UNVERIFIED[id] then
		return if templatePresent
			then "Price/availability unverified · source template present."
			else "Price/availability unverified · not imported."
	elseif id == "8421400545" and not templatePresent then
		return "Free listing · import attempt returned HTTP 502; not imported."
	elseif templatePresent then
		return "Free listing · source-controlled template present."
	end
	return "Free listing · not imported."
end

local function getTemplateRoot(options: any): Instance?
	if type(options) == "table" and typeof(options.AssetTemplates) == "Instance" then
		local supplied = options.AssetTemplates :: Instance
		if supplied:IsA("Model") or supplied:IsA("Folder") then
			return supplied
		end
	end
	local toolbox = ServerStorage:FindFirstChild("DevToolboxAssets")
	if not toolbox then
		return nil
	end
	local curated = toolbox:FindFirstChild(TEMPLATE_ROOT)
	if curated and (curated:IsA("Model") or curated:IsA("Folder")) then
		return curated
	end
	return toolbox
end

local function blocked(instance: Instance): boolean
	local class = instance.ClassName
	if class == "Tool" or class == "HopperBin" or class == "ClickDetector"
		or class == "ProximityPrompt" or class == "RemoteEvent" or class == "RemoteFunction"
		or class == "UnreliableRemoteEvent" or class == "BindableEvent" or class == "BindableFunction"
		or class == "TouchTransmitter" or class == "Humanoid" or class == "AnimationController"
		or class == "Animator" or class == "Sound" or class == "SoundGroup" or class == "SoundEffect"
		or class == "ParticleEmitter" or class == "Trail" or class == "Beam" or class == "Fire"
		or class == "Smoke" or class == "Sparkles" or class == "BillboardGui" or class == "SurfaceGui"
		or class == "ScreenGui" or class == "Seat" or class == "VehicleSeat" or class == "Explosion"
		or class == "ForceField" or class == "Highlight" or class == "SelectionBox"
		or class == "SelectionSphere"
	then
		return true
	end
	return instance:IsA("LuaSourceContainer")
		or instance:IsA("Constraint")
		or instance:IsA("JointInstance")
		or instance:IsA("BodyMover")
end

local function countSafe(model: Model): (number, number)
	local instances = 1
	local parts = 0
	for _, descendant in ipairs(model:GetDescendants()) do
		if not blocked(descendant) then
			instances += 1
			if descendant:IsA("BasePart") then
				parts += 1
			end
		end
	end
	return instances, parts
end

local function nearestModelAncestor(instance: Instance, root: Instance): Model?
	local current = instance.Parent
	while current and current ~= root.Parent do
		if current:IsA("Model") then
			return current
		end
		if current == root then
			break
		end
		current = current.Parent
	end
	return nil
end

local function collectTemplates(root: Instance?): { Template }
	local templates: { Template } = {}
	if not root then
		return templates
	end
	local models: { Model } = {}
	if root:IsA("Model") then
		table.insert(models, root)
	end
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("Model") then
			table.insert(models, item)
		end
	end
	for _, model in ipairs(models) do
		local id = inheritedAttr(model, root, "AssetId")
		local ownId = stringAttr(model:GetAttribute("AssetId"))
		local ancestorModel = nearestModelAncestor(model, root)
		if id and (not ancestorModel or ownId) then
			local name = inheritedAttr(model, root, "AssetName") or model.Name
			local packName = inheritedAttr(model, root, "SourcePack") or ""
			local creator = inheritedAttr(model, root, "Creator") or ""
			local rawCategory = inheritedAttr(model, root, "Category")
			local category = categoryFromName(rawCategory or candidateCategory(id))
			local variant = inheritedAttr(model, root, "Variant") or "Default"
			local instances, parts = countSafe(model)
			local trianglesValue = model:GetAttribute("EstimatedTriangles") or model:GetAttribute("TriangleCount")
			local triangles = if type(trianglesValue) == "number" and trianglesValue >= 0 then trianglesValue else nil
			local rejected = nil
			if parts == 0 then
				rejected = "Template has no visible BaseParts"
			elseif instances > PER_MODEL_INSTANCE_CAP then
				rejected = ("Template exceeds %d-instance cap"):format(PER_MODEL_INSTANCE_CAP)
			elseif parts > PER_MODEL_PART_CAP then
				rejected = ("Template exceeds %d-part cap"):format(PER_MODEL_PART_CAP)
			end
			local template: Template = {
				Model = model,
				Name = name,
				Id = id,
				Pack = packName,
				Creator = creator,
				Category = category,
				Variant = variant,
				Instances = instances,
				Parts = parts,
				Triangles = triangles,
				Rejected = rejected,
			}
			table.insert(templates, template)
		end
	end
	table.sort(templates, function(a, b)
		if a.Category ~= b.Category then return a.Category < b.Category end
		if a.Pack ~= b.Pack then return a.Pack < b.Pack end
		if a.Name ~= b.Name then return a.Name < b.Name end
		return a.Variant < b.Variant
	end)
	return templates
end

local function matchesPack(template: Template, pack: { Name: string, Id: string }): boolean
	local source = normalized(template.Pack)
	local target = normalized(pack.Name)
	return source == target
		or (source ~= "" and string.find(source, target, 1, true) ~= nil)
		or (source ~= "" and string.find(source, normalized(pack.Id), 1, true) ~= nil)
		or template.Id == pack.Id
end

local function buildCards(templates: { Template }): ({ [string]: { Card } }, number)
	local groups: { [string]: { Card } } = {}
	for _, category in ipairs(CATEGORY_ORDER) do
		groups[category] = {}
	end
	for _, pack in ipairs(PACKS) do
		local variants = 0
		for _, template in ipairs(templates) do
			if matchesPack(template, pack) then variants += 1 end
		end
		local reason = if variants > 0
			then ("%d curated model template(s) are present; category cards show each preview status."):format(variants)
			else "Not imported · no source-controlled model template is present."
		table.insert(groups["Source Packs"], {
			Name = pack.Name, Id = pack.Id, Pack = "Source pack family", Creator = "",
			Category = "Source Packs", Variant = if variants > 0 then tostring(variants) .. " curated variants" else "No imported variant",
			Template = nil, Reason = reason, ListingStatus = listingStatus(pack.Id, variants > 0), PackFamily = true,
		})
	end

	local used: { [Template]: boolean } = {}
	local missing = 0
	for _, candidate in ipairs(CANDIDATES) do
		local found = {}
		for _, template in ipairs(templates) do
			if template.Id == candidate[2] then table.insert(found, template) end
		end
		if #found == 0 then
			missing += 1
			table.insert(groups[candidate[3]], {
				Name = candidate[1], Id = candidate[2], Pack = "Standalone candidate", Creator = "",
				Category = candidate[3], Variant = "Not imported", Template = nil,
				Reason = "Not imported · no source-controlled model template is present.", ListingStatus = listingStatus(candidate[2], false),
			})
		else
			for _, template in ipairs(found) do
				used[template] = true
				table.insert(groups[candidate[3]], {
					Name = template.Name, Id = template.Id, Pack = template.Pack, Creator = template.Creator,
					Category = candidate[3], Variant = template.Variant, Template = template, Reason = template.Rejected, ListingStatus = listingStatus(candidate[2], true),
				})
			end
		end
	end
	for _, template in ipairs(templates) do
		if not used[template] and not candidateCategory(template.Id) then
			local category = if groups[template.Category] then template.Category else "Other"
			table.insert(groups[category], {
				Name = template.Name, Id = template.Id, Pack = template.Pack, Creator = template.Creator,
				Category = category, Variant = template.Variant, Template = template, Reason = template.Rejected, ListingStatus = "Source-controlled template imported from the attributed source pack.",
			})
		end
	end
	for _, category in ipairs(CATEGORY_ORDER) do
		table.sort(groups[category], function(a, b)
			if a.Name ~= b.Name then return a.Name < b.Name end
			return a.Variant < b.Variant
		end)
	end
	return groups, missing
end

local function cardBody(card: Card): string
	local pack = if card.Pack ~= "" then card.Pack else "Standalone listing"
	local creator = if card.Creator ~= "" then card.Creator else "Creator metadata not supplied"
	local lines = {
		"Creator Store ID: " .. card.Id,
		"Listing status: " .. (card.ListingStatus or "Listing status not verified"),
		"Source pack: " .. pack,
		"Creator: " .. creator,
		"Variant: " .. card.Variant,
	}
	if card.Template then
		local count = ("Preview estimate: %d instances · %d parts"):format(card.Template.Instances, card.Template.Parts)
		if card.Template.Triangles then
			count ..= (" · %d triangles"):format(card.Template.Triangles)
		else
			count ..= " · triangle data unavailable"
		end
		table.insert(lines, count)
	end
	if card.Reason then
		table.insert(lines, card.Reason)
	elseif card.Template then
		table.insert(lines, "Verified source-controlled template")
	end
	return table.concat(lines, "\n")
end

local function sanitize(clone: Model, template: Template)
	clone:SetAttribute("SourceAssetId", template.Id)
	clone:SetAttribute("SourceAssetName", template.Name)
	clone:SetAttribute("SourcePack", template.Pack)
	clone:SetAttribute("Creator", template.Creator)
	clone:SetAttribute("Variant", template.Variant)
	clone:SetAttribute("NonHarvestable", true)
	mark(clone)
	for _, descendant in ipairs(clone:GetDescendants()) do
		if blocked(descendant) then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		else
			mark(descendant)
		end
	end
end

type VisibleBounds = {
	Center: Vector3,
	MinimumY: number,
	Size: Vector3,
}

local function getVisibleBounds(model: Model): VisibleBounds?
	local minimumX = math.huge
	local minimumY = math.huge
	local minimumZ = math.huge
	local maximumX = -math.huge
	local maximumY = -math.huge
	local maximumZ = -math.huge
	local visiblePartCount = 0

	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			local hasVisibleSurface = item.Transparency < 1 and item.LocalTransparencyModifier < 1
			if not hasVisibleSurface and item.LocalTransparencyModifier < 1 then
				for _, surface in ipairs(item:GetDescendants()) do
					if (surface:IsA("Decal") or surface:IsA("Texture")) and surface.Transparency < 1 then
						hasVisibleSurface = true
						break
					end
				end
			end
			if hasVisibleSurface then
				visiblePartCount += 1
				local cf = item.CFrame
				local size = item.Size
				local halfX = math.abs(cf.RightVector.X) * size.X * 0.5
					+ math.abs(cf.UpVector.X) * size.Y * 0.5
					+ math.abs(cf.LookVector.X) * size.Z * 0.5
				local halfY = math.abs(cf.RightVector.Y) * size.X * 0.5
					+ math.abs(cf.UpVector.Y) * size.Y * 0.5
					+ math.abs(cf.LookVector.Y) * size.Z * 0.5
				local halfZ = math.abs(cf.RightVector.Z) * size.X * 0.5
					+ math.abs(cf.UpVector.Z) * size.Y * 0.5
					+ math.abs(cf.LookVector.Z) * size.Z * 0.5
				minimumX = math.min(minimumX, cf.Position.X - halfX)
				maximumX = math.max(maximumX, cf.Position.X + halfX)
				minimumY = math.min(minimumY, cf.Position.Y - halfY)
				maximumY = math.max(maximumY, cf.Position.Y + halfY)
				minimumZ = math.min(minimumZ, cf.Position.Z - halfZ)
				maximumZ = math.max(maximumZ, cf.Position.Z + halfZ)
			end
		end
	end

	if visiblePartCount == 0 then
		return nil
	end
	return {
		Center = Vector3.new((minimumX + maximumX) * 0.5, (minimumY + maximumY) * 0.5, (minimumZ + maximumZ) * 0.5),
		MinimumY = minimumY,
		Size = Vector3.new(maximumX - minimumX, maximumY - minimumY, maximumZ - minimumZ),
	}
end

local function clonePreview(
	template: Template,
	parent: Instance,
	position: Vector3,
	surfaceY: number,
	budget: { Models: number, Instances: number, Parts: number },
	targetExtent: number?
): (Model?, string)
	if template.Rejected then return nil, template.Rejected end
	if budget.Models >= TOTAL_MODEL_CAP then return nil, "Not shown · gallery preview model cap reached" end
	if budget.Instances + template.Instances > TOTAL_INSTANCE_CAP then return nil, "Not shown · gallery instance cap reached" end
	if budget.Parts + template.Parts > TOTAL_PART_CAP then return nil, "Not shown · gallery part cap reached" end
	local ok, cloned = pcall(function() return template.Model:Clone() end)
	if not ok or not cloned or not cloned:IsA("Model") then
		return nil, "Unavailable · template clone failed"
	end
	local preview = cloned :: Model
	local safe, errorText = pcall(sanitize, preview, template)
	if not safe then
		preview:Destroy()
		return nil, "Unavailable · sanitization failed: " .. tostring(errorText)
	end
	local instances, parts = countSafe(preview)
	if parts == 0 or instances > PER_MODEL_INSTANCE_CAP or parts > PER_MODEL_PART_CAP then
		preview:Destroy()
		return nil, "Not shown · sanitized model exceeds the preview cap"
	end

	local previewScale = 1
	local placed, placeError = pcall(function()
		local bounds = getVisibleBounds(preview)
		if not bounds then
			error("Template has no visible BasePart bounds")
		end
		local largestExtent = math.max(bounds.Size.X, bounds.Size.Y, bounds.Size.Z)
		if largestExtent <= 0.01 or largestExtent > MODEL_EXTENT_CAP then
			error(("Template has invalid display extent %.2f studs"):format(largestExtent))
		end
		local limit = targetExtent or CARD_PREVIEW_EXTENT
		if largestExtent > limit then
			previewScale = limit / largestExtent
			preview:ScaleTo(preview:GetScale() * previewScale)
			bounds = getVisibleBounds(preview)
			if not bounds then
				error("Scaled template has no visible BasePart bounds")
			end
		end
		preview.Parent = parent
		local offset = Vector3.new(
			position.X - bounds.Center.X,
			surfaceY - bounds.MinimumY,
			position.Z - bounds.Center.Z
		)
		preview:PivotTo(preview:GetPivot() + offset)
	end)
	if not placed then
		preview:Destroy()
		return nil, "Not shown · " .. tostring(placeError)
	end
	mark(preview)
	preview:SetAttribute("EstimatedPreviewInstances", instances)
	preview:SetAttribute("EstimatedPreviewBaseParts", parts)
	preview:SetAttribute("EstimatedTriangles", template.Triangles)
	preview:SetAttribute("PreviewScaleFactor", previewScale)
	budget.Models += 1
	budget.Instances += instances
	budget.Parts += parts
	return preview, ("Available · sanitized source template · preview scale %.2fx"):format(previewScale)
end

local function deck(parent: Instance, name: string, center: Vector3, size: Vector3, color: Color3): Part
	local result = part(parent, name, size, CFrame.new(center.X, center.Y - size.Y * 0.5, center.Z), color, true)
	result:SetAttribute("WalkableUtilitySurface", true)
	result:SetAttribute("NavigationTarget", true)
	return result
end

local function addCard(parent: Instance, card: Card, center: Vector3, surfaceY: number, budget: { Models: number, Instances: number, Parts: number })
	local item = Instance.new("Model")
	item.Name = "AssetCard_" .. string.gsub(card.Id, "%D", "")
	item:SetAttribute("AssetName", card.Name)
	item:SetAttribute("AssetId", card.Id)
	item:SetAttribute("SourcePack", card.Pack)
	item:SetAttribute("Creator", card.Creator)
	item:SetAttribute("Category", card.Category)
	item:SetAttribute("Variant", card.Variant)
	item:SetAttribute("AssetStatus", if card.Template then "TemplateFound" else "NotImported")
	item:SetAttribute("ListingStatus", card.ListingStatus)
	mark(item)
	item.Parent = parent
	part(item, "DisplayStand", Vector3.new(11.6, 0.3, 11.6), CFrame.new(center.X, surfaceY + 0.15, center.Z), COLORS.Pad, false)
	local shown: Model? = nil
	local status = card.Reason
	if card.Template and not card.PackFamily then
		local preview, cloneStatus = clonePreview(card.Template, item, Vector3.new(center.X, surfaceY + 0.3, center.Z), surfaceY + 0.3, budget, CARD_PREVIEW_EXTENT)
		shown = preview
		status = cloneStatus
		item:SetAttribute("AssetStatus", if preview then "PreviewAvailable" else "NotShown")
		if preview then preview.Name = "SanitizedPreview" end
	elseif card.PackFamily then
		item:SetAttribute("AssetStatus", if card.Reason and string.find(card.Reason, "Not imported", 1, true) then "NotImported" else "CuratedVariantsListed")
	else
		item:SetAttribute("AssetStatus", "NotImported")
	end
	local displayCard = table.clone(card)
	displayCard.Reason = status
	local isAvailable = shown ~= nil or (card.PackFamily == true and card.Reason ~= nil and not string.find(card.Reason, "Not imported", 1, true))
	label(item, "Attribution", card.Name, cardBody(displayCard), Vector3.new(center.X, surfaceY + 8.1, center.Z),
		if isAvailable then COLORS.Available else COLORS.Unavailable, UDim2.fromOffset(270, 122), 18)
	return item
end

local function packTemplates(templates: { Template }, pack: { Name: string, Id: string }): { Template }
	local found = {}
	for _, template in ipairs(templates) do
		if matchesPack(template, pack) then table.insert(found, template) end
	end
	return found
end

local function compositionTemplates(definition: any, templates: { Template }, pack: { Name: string, Id: string }): { Template }
	local byName: { [string]: Template } = {}
	for _, template in ipairs(templates) do byName[template.Model.Name] = template end
	local selected: { Template } = {}
	local included: { [Template]: boolean } = {}
	for _, modelName in ipairs(definition.ModelNames) do
		local template = byName[modelName]
		if template and not included[template] then
			table.insert(selected, template)
			included[template] = true
		end
	end
	if #selected == 0 then
		for _, template in ipairs(packTemplates(templates, pack)) do
			if #selected >= COMPOSITION_ASSET_CAP then break end
			if not included[template] then
				table.insert(selected, template)
				included[template] = true
			end
		end
	end
	while #selected > COMPOSITION_ASSET_CAP do table.remove(selected) end
	return selected
end

local function oakPreview(factory: any, parent: Instance, position: Vector3, surfaceY: number, budget: { Models: number, Instances: number, Parts: number }, seed: number): string
	if type(factory) ~= "function" then return "Starter Oak omitted · approved Oak factory not supplied." end
	local ok, source = pcall(factory, seed)
	if not ok or typeof(source) ~= "Instance" or not source:IsA("Model") then
		return "Starter Oak omitted · approved Oak factory unavailable."
	end
	local model = source :: Model
	local instances, parts = countSafe(model)
	local oak: Template = {
		Model = model, Name = "Approved Starter Oak", Id = "Approved Starter Oak",
		Pack = "Approved procedural reference", Creator = "Brick World", Category = "Wood",
		Variant = tostring(seed), Instances = instances, Parts = parts, Triangles = nil, Rejected = nil,
	}
	local preview, status = clonePreview(oak, parent, position, surfaceY, budget, OAK_PREVIEW_EXTENT)
	if model.Parent == nil then model:Destroy() end
	if not preview then return "Starter Oak omitted · " .. status end
	preview.Name = "ApprovedStarterOakPreview"
	preview:SetAttribute("ApprovedStarterOak", true)
	return "Approved Starter Oak included."
end

local function mesaPreview(template: any, parent: Instance, position: Vector3, surfaceY: number, budget: { Models: number, Instances: number, Parts: number }): string
	if typeof(template) ~= "Instance" or not template:IsA("Model") then
		return "Mesa omitted · no approved mesa template supplied."
	end
	local model = template :: Model
	local instances, parts = countSafe(model)
	local mesa: Template = {
		Model = model, Name = "Approved Mesa Style", Id = "Approved Mesa",
		Pack = "Approved World 1 mesa reference", Creator = "Brick World", Category = "Rocks",
		Variant = "Approved", Instances = instances, Parts = parts, Triangles = nil, Rejected = nil,
	}
	local preview, status = clonePreview(mesa, parent, position, surfaceY, budget, MESA_PREVIEW_EXTENT)
	if not preview then return "Mesa omitted · " .. status end
	preview.Name = "ApprovedMesaPreview"
	preview:SetAttribute("ApprovedMesaReference", true)
	return "Approved mesa included."
end

local function addComposition(
	parent: Instance,
	index: number,
	definition: any,
	templates: { Template },
	center: Vector3,
	options: any,
	budget: { Models: number, Instances: number, Parts: number }
): Vector3
	local pack = if definition.PackIndex then PACKS[definition.PackIndex]
		else { Name = "Curated multi-pack mixture", Id = "multiple" }
	local base = deck(parent, "CompositionDeck" .. index, center, Vector3.new(50, 0.8, 88),
		if index % 2 == 0 then COLORS.DeckAlt else COLORS.Deck)
	base:SetAttribute("SourcePack", pack.Name)
	base:SetAttribute("ComparisonComposition", definition.Name)

	local oakText = oakPreview(
		if type(options) == "table" then options.StarterOakFactory else nil,
		parent, Vector3.new(center.X - 13, center.Y, center.Z - 19), center.Y, budget, 5200 + index
	)
	local mesaText = mesaPreview(
		if type(options) == "table" then options.MesaTemplate else nil,
		parent, Vector3.new(center.X + 14, center.Y, center.Z - 16), center.Y, budget
	)
	local selected = compositionTemplates(definition, templates, pack)
	local included: { [Template]: boolean } = {}
	for _, template in ipairs(selected) do included[template] = true end
	local pathTemplate: Template? = nil
	for _, template in ipairs(templates) do
		if template.Model.Name == "Individual_DirtPath" then
			pathTemplate = template
			break
		end
	end
	if pathTemplate and not included[pathTemplate] then
		table.insert(selected, pathTemplate)
		included[pathTemplate] = true
	end

	local positions = {
		Vector3.new(center.X - 18, center.Y, center.Z),
		Vector3.new(center.X - 9, center.Y, center.Z + 14),
		Vector3.new(center.X, center.Y, center.Z + 4),
		Vector3.new(center.X + 9, center.Y, center.Z + 15),
		Vector3.new(center.X + 18, center.Y, center.Z),
		Vector3.new(center.X, center.Y, center.Z + 34),
	}
	local shown = 0
	local skipped = {}
	local provenance = {}
	for i, template in ipairs(selected) do
		local preview, status = clonePreview(template, parent, positions[i], center.Y, budget, COMPOSITION_PREVIEW_EXTENT)
		local sourcePack = if template.Pack ~= "" then template.Pack else "Source pack metadata not supplied"
		local creator = if template.Creator ~= "" then template.Creator else "creator not supplied"
		if preview then
			preview.Name = ("Composition%02d_%s"):format(index, template.Model.Name)
			preview:SetAttribute("CompositionSourcePack", template.Pack)
			shown += 1
			table.insert(provenance, ("%s · %s · ID %s · variant %s · %s"):format(
				template.Name, sourcePack, template.Id, template.Variant, creator
			))
		else
			table.insert(skipped, template.Name .. ": " .. status)
			table.insert(provenance, ("%s · %s · ID %s · variant %s · not shown"):format(
				template.Name, sourcePack, template.Id, template.Variant
			))
		end
	end
	local pathText = if pathTemplate then "Dirt path sample: Individual_DirtPath template selected."
		else "Dirt path omitted · Individual_DirtPath is not imported."
	local summary = if shown > 0
		then ("%d real, sanitized model variant(s) shown."):format(shown)
		elseif #selected == 0
		then "No verified source-pack model templates are available for this composition."
		else "Selected source variants were skipped by preview safety or scale limits."
	local sourceHeader = if pack.Id ~= "multiple"
		then "Creator Store pack ID: " .. pack.Id
		else "Curated mixture · each model below carries its own pack and ID."
	local details = table.concat({
		sourceHeader,
		"Grass: walkable comparison ground",
		oakText,
		mesaText,
		pathText,
		summary,
		"Selected models:",
		table.concat(provenance, "\n"),
	}, "\n")
	if #skipped > 0 then details ..= "\nSkipped: " .. table.concat(skipped, "; ") end
	local title = definition.Name .. " · " .. pack.Name
	label(parent, "Composition" .. index .. "Label", title, details,
		Vector3.new(center.X, center.Y + 15, center.Z - 37),
		if shown > 0 then COLORS.Available else COLORS.Unavailable, UDim2.fromOffset(500, 220), 80)
	return Vector3.new(center.X, center.Y + 7, center.Z + 1)
end

local function modelStats(model: Model): (number, number)
	local instances = 1
	local parts = 0
	for _, item in ipairs(model:GetDescendants()) do
		instances += 1
		if item:IsA("BasePart") then parts += 1 end
	end
	return instances, parts
end

function Showcase.Build(parent: Instance, center: Vector3, options: any?)
	assert(RunService:IsStudio(), "Forest asset selection is available only in Roblox Studio")
	assert(parent ~= nil, "ForestAssetSelectionShowcase.Build requires a parent")
	assert(typeof(center) == "Vector3", "ForestAssetSelectionShowcase.Build requires a world-space center")

	local root = Instance.new("Model")
	root.Name = "ForestAssetSelectionShowcase"
	root.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	root:SetAttribute("LabId", "Forest")
	root:SetAttribute("ShowcaseKind", "CreatorStoreAssetSelection")
	root:SetAttribute("Theme", "World1BrightWoodland")
	root:SetAttribute("BuildStatus", "Building")
	mark(root)

	local ok, result = pcall(function()
		local templateRoot = getTemplateRoot(options)
		local templates = collectTemplates(templateRoot)
		local groups, missing = buildCards(templates)
		root:SetAttribute("TemplateRoot", if templateRoot then templateRoot:GetFullName() else "ServerStorage.DevToolboxAssets.ForestToolboxAssets (not found)")
		root:SetAttribute("VerifiedTemplateCount", #templates)
		root:SetAttribute("MissingCandidateCount", missing)

		local rows = 0
		for _, category in ipairs(CATEGORY_ORDER) do
			rows += 1 + math.max(1, math.ceil(#groups[category] / COLUMNS))
		end
		local catalogDepth = rows * ROW_PITCH + 8
		local catalogCenter = Vector3.new(center.X - 78, center.Y, center.Z)
		local catalog = deck(root, "AssetCatalogWalkway", catalogCenter, Vector3.new(116, 0.8, catalogDepth), COLORS.Deck)
		catalog:SetAttribute("AssetCatalog", true)
		local bridges = {
			{ OffsetX = -18.5, Width = 4.5 },
			{ OffsetX = 36, Width = 7 },
			{ OffsetX = 92, Width = 7 },
		}
		for index, bridge in ipairs(bridges) do
			deck(root, "WalkwayConnector" .. index,
				Vector3.new(center.X + bridge.OffsetX, center.Y, center.Z + 4),
				Vector3.new(bridge.Width, 0.8, 88), COLORS.DeckAlt)
		end
		local intro = if #templates > 0
			then ("%d source-controlled model template(s) found. Only sanitized clones are shown."):format(#templates)
			else "No verified source-controlled model templates found. Candidate cards are marked Not imported; no substitute geometry is shown."
		label(root, "CatalogIntro", "FOREST TOOLBOX ASSET SELECTION",
			intro .. "\nNo Creator Store asset is loaded by ID at runtime.",
			Vector3.new(catalogCenter.X, center.Y + 9, catalogCenter.Z - catalogDepth * 0.5 + 5),
			if #templates > 0 then COLORS.Available else COLORS.Unavailable, UDim2.fromOffset(760, 104), 100)

		local budget = { Models = 0, Instances = 0, Parts = 0 }
		local firstRow = catalogCenter.Z - catalogDepth * 0.5 + 19
		local row = 0
		local cards = 0
		for _, category in ipairs(CATEGORY_ORDER) do
			local list = groups[category]
			label(root, "Category_" .. string.gsub(category, "%W", ""), CATEGORY_LABEL[category] or category,
				("%d catalog entry/entries"):format(#list),
				Vector3.new(catalogCenter.X, center.Y + 7, firstRow + row * ROW_PITCH),
				COLORS.Available, UDim2.fromOffset(520, 64), 80)
			row += 1
			for i, card in ipairs(list) do
				local r = math.floor((i - 1) / COLUMNS)
				local c = (i - 1) % COLUMNS
				local pos = Vector3.new(catalogCenter.X + (c - (COLUMNS - 1) * 0.5) * CARD_PITCH,
					center.Y, firstRow + (row + r) * ROW_PITCH)
				addCard(root, card, pos, center.Y, budget)
				cards += 1
			end
			row += math.max(1, math.ceil(#list / COLUMNS))
		end

		local focusSum = Vector3.zero
		local compositionCount = 0
		for index, definition in ipairs(COMPOSITIONS) do
			local compCenter = Vector3.new(center.X + 8 + (index - 1) * 56, center.Y, center.Z + 4)
			focusSum += addComposition(root, index, definition, templates, compCenter, options, budget)
			compositionCount += 1
		end
		local focus = focusSum / math.max(compositionCount, 1)
		local landing = CFrame.lookAt(Vector3.new(center.X + 120, center.Y + 3.5, center.Z + 35), focus)
		root:SetAttribute("LandingCFrame", landing)
		root:SetAttribute("FocusPosition", focus)
		root:SetAttribute("CatalogCardCount", cards)
		root:SetAttribute("AssetPreviewModelCount", budget.Models)
		root:SetAttribute("AssetPreviewInstanceCount", budget.Instances)
		root:SetAttribute("AssetPreviewBasePartCount", budget.Parts)
		root:SetAttribute("BuildStatus", "Ready")
		local totalInstances, totalParts = modelStats(root)
		root:SetAttribute("TotalInstanceCount", totalInstances)
		root:SetAttribute("TotalBasePartCount", totalParts)
		return {
			LandingCFrame = landing,
			FocusPosition = focus,
			Focus = focus,
			InstanceCount = totalInstances,
			BasePartCount = totalParts,
			AssetTemplateCount = #templates,
			AssetPreviewCount = budget.Models,
			AssetPreviewInstanceCount = budget.Instances,
			AssetPreviewBasePartCount = budget.Parts,
			MissingCandidateCount = missing,
		}
	end)
	if not ok then
		root:Destroy()
		error(result, 2)
	end
	root.Parent = parent
	return root, result
end

return Showcase
