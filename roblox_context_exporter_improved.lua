-- Roblox Studio Context Exporter (command-bar friendly)
--
-- This script READS the current DataModel and writes Markdown to Studio Output
-- in labelled chunks. It does not modify the place or send data over the network.
-- Copy the chunks, concatenate them in order, and save the result as CONTEXT.md.
--
-- Recommended use: run from Studio's Command Bar while in Edit mode.

local CollectionService = game:GetService("CollectionService")

local CONFIG = {
	includeScriptSource = true,
	includeServiceScripts = true,
	maxHierarchyDepth = 12,
	maxNodes = 8000,
	outputChunkCharacters = 9000,
}

local SERVICES = {
	"Workspace",
	"ReplicatedFirst",
	"ReplicatedStorage",
	"ServerScriptService",
	"ServerStorage",
	"StarterGui",
	"StarterPack",
	"StarterPlayer",
	"Lighting",
	"SoundService",
	"Teams",
	"TextChatService",
	"MaterialService",
}

local lines = {}
local nodeCount = 0
local scriptCount = 0

local function add(line)
	table.insert(lines, line)
end

local function markdownText(value)
	return tostring(value):gsub("\r?\n", " ")
end

local function sortedChildren(instance)
	local children = instance:GetChildren()
	table.sort(children, function(a, b)
		if a.Name == b.Name then
			return a.ClassName < b.ClassName
		end
		return a.Name < b.Name
	end)
	return children
end

local function appendAttributes(instance, indent)
	local attributes = instance:GetAttributes()
	local names = {}
	for name in pairs(attributes) do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in ipairs(names) do
		add(indent .. "  - Attribute `" .. name .. "`: `" .. markdownText(attributes[name]) .. "`")
	end
end

local function appendUsefulProperties(instance, indent)
	local properties = {}
	if instance:IsA("ValueBase") then
		table.insert(properties, "Value=" .. markdownText(instance.Value))
	end
	if instance:IsA("Model") or instance:IsA("BasePart") then
		local ok, pivot = pcall(function()
			return instance:GetPivot()
		end)
		if ok then
			table.insert(properties, string.format("Position=(%.2f, %.2f, %.2f)", pivot.Position.X, pivot.Position.Y, pivot.Position.Z))
		end
	end
	if instance:IsA("BasePart") then
		table.insert(properties, "Size=" .. markdownText(instance.Size))
	end
	if instance:IsA("MeshPart") then
		table.insert(properties, "MeshId=" .. markdownText(instance.MeshId))
		table.insert(properties, "TextureID=" .. markdownText(instance.TextureID))
	elseif instance:IsA("Decal") or instance:IsA("Texture") then
		table.insert(properties, "Texture=" .. markdownText(instance.Texture))
	elseif instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
		table.insert(properties, "Image=" .. markdownText(instance.Image))
	elseif instance:IsA("Sound") then
		table.insert(properties, "SoundId=" .. markdownText(instance.SoundId))
	elseif instance:IsA("Animation") then
		table.insert(properties, "AnimationId=" .. markdownText(instance.AnimationId))
	end
	if #properties > 0 then
		add(indent .. "  - " .. table.concat(properties, "; "))
	end
end

local function exportHierarchy(instance, depth)
	if nodeCount >= CONFIG.maxNodes then
		return
	end

	for _, child in ipairs(sortedChildren(instance)) do
		if nodeCount >= CONFIG.maxNodes then
			return
		end

		nodeCount += 1
		local indent = string.rep("  ", depth)
		add(indent .. "- `" .. child.Name .. "` (" .. child.ClassName .. ") — `" .. child:GetFullName() .. "`")
		appendAttributes(child, indent)
		appendUsefulProperties(child, indent)

		local tags = CollectionService:GetTags(child)
		if #tags > 0 then
			table.sort(tags)
			add(indent .. "  - Tags: `" .. table.concat(tags, "`, `") .. "`")
		end

		if depth < CONFIG.maxHierarchyDepth then
			exportHierarchy(child, depth + 1)
		elseif #child:GetChildren() > 0 then
			add(indent .. "  - _Children omitted at depth limit: " .. #child:GetChildren() .. "_")
		end
	end
end

local function exportScript(scriptObject)
	scriptCount += 1
	add("### `" .. scriptObject:GetFullName() .. "`")
	add("- Class: `" .. scriptObject.ClassName .. "`")

	if not CONFIG.includeScriptSource then
		add("")
		return
	end

	local ok, source = pcall(function()
		return scriptObject.Source
	end)
	if not ok then
		add("- Source unavailable: `" .. markdownText(source) .. "`")
		add("")
		return
	end

	-- Four backticks avoid breaking when source itself contains a Lua code fence.
	add("````lua")
	add(source)
	add("````")
	add("")
end

local function exportScripts(instance)
	for _, child in ipairs(sortedChildren(instance)) do
		if child:IsA("LuaSourceContainer") then
			exportScript(child)
		end
		exportScripts(child)
	end
end

add("# Roblox Studio Context Export")
add("")
add("- Generated: `" .. os.date("!%Y-%m-%dT%H:%M:%SZ") .. "`")
add("- PlaceId: `" .. game.PlaceId .. "`")
add("- JobId: `" .. (game.JobId ~= "" and game.JobId or "Edit mode / no job") .. "`")
add("- Export mode: `read-only; no network requests; no place changes`")
add("")
add("## Service and hierarchy snapshot")

for _, name in ipairs(SERVICES) do
	local ok, service = pcall(game.GetService, game, name)
	if ok then
		add("")
		add("### " .. name)
		exportHierarchy(service, 0)
	end
end

if nodeCount >= CONFIG.maxNodes then
	add("")
	add("> Hierarchy export stopped at `maxNodes=" .. CONFIG.maxNodes .. "`. Raise the limit only if needed.")
end

if CONFIG.includeServiceScripts then
	add("")
	add("## Script source")
	for _, name in ipairs(SERVICES) do
		local ok, service = pcall(game.GetService, game, name)
		if ok then
			exportScripts(service)
		end
	end
	add("_Scripts exported: " .. scriptCount .. "_")
end

local markdown = table.concat(lines, "\n")
local chunkSize = CONFIG.outputChunkCharacters
local partCount = math.ceil(#markdown / chunkSize)

print(string.format("--- ROBLOX CONTEXT EXPORT START (%d parts) ---", partCount))
for part = 1, partCount do
	local first = (part - 1) * chunkSize + 1
	local last = math.min(part * chunkSize, #markdown)
	print(string.format("--- CONTEXT PART %d/%d ---", part, partCount))
	print(markdown:sub(first, last))
end
print("--- ROBLOX CONTEXT EXPORT END ---")
