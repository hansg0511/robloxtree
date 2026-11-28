-- Fixed-output recipe invariants shared by the server forge path.
-- The recipe (never ingredient RNG) determines the finished weapon identity.
-- Extra weapon kinds can use this contract without changing existing axes.
local WeaponRecipeRules = {}

local function validString(value)
	return type(value) == "string" and #value > 0 and #value <= 80
end

function WeaponRecipeRules.ResolveFixedOutput(recipe)
	if type(recipe) ~= "table"
		or not validString(recipe.Id)
		or type(recipe.OutputItemID) ~= "number"
		or recipe.OutputItemID < 1
		or recipe.OutputItemID % 1 ~= 0
		or recipe.OutputItemID == math.huge
	then
		return nil
	end
	local weaponKind = recipe.WeaponKind
	if not validString(weaponKind) then return nil end
	return {
		RecipeId = recipe.Id,
		ItemID = recipe.OutputItemID,
		WeaponKind = weaponKind,
	}
end

-- Only a dense array of exactly N distinct owned log UIDs is a valid request.
-- The server must still resolve each UID to an eligible owned log and then
-- validate the recipe, head, forge access and world requirements.
function WeaponRecipeRules.IsExactUidSelection(value, expectedCount)
	if type(value) ~= "table"
		or type(expectedCount) ~= "number"
		or expectedCount < 1
		or expectedCount % 1 ~= 0
	then
		return false
	end
	local count = 0
	local maxIndex = 0
	for key in pairs(value) do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return false end
		count += 1
		maxIndex = math.max(maxIndex, key)
	end
	if count ~= expectedCount or maxIndex ~= expectedCount then return false end
	local seen = {}
	for index = 1, expectedCount do
		local uid = value[index]
		if type(uid) ~= "string" or #uid < 1 or #uid > 80 or seen[uid] then
			return false
		end
		seen[uid] = true
	end
	return true
end

return WeaponRecipeRules
