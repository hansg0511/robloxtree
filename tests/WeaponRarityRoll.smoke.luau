-- Existing rarity smoke suite updated to cover every configured Forge level.
local Roll=require(game.ServerScriptService.WeaponRarityRoll)
local Progression=require(game.ServerScriptService.WeaponProgressionRules)
local Config=require(game.ReplicatedStorage.Shared.ProgressionConfig)
local total=Roll.TOTAL_WEIGHT
local function fixed(draw)
	return {NextInteger=function(_,lo,hi) assert(lo==1 and hi==total); return draw end}
end
local oldFloor,oldCeiling=1,1
for level=1,Config.MAX_FORGE_LEVEL do
	local floor,ceiling=Config.RarityWindow(level)
	assert(floor>=oldFloor and ceiling>=oldCeiling and floor<=ceiling)
	oldFloor,oldCeiling=floor,ceiling
	local weights=Roll.WeightsForLevel(level)
	local sum=0
	for index,id in ipairs(Config.Order) do
		local weight=weights[id]
		assert(weight>=0 and weight%1==0)
		if index<floor or index>ceiling then assert(weight==0,"locked rarity rolled")
		else assert(weight>0,"eligible rarity silently retired") end
		if weight>0 then
			assert(Roll.Roll(fixed(sum+1),level)==id)
			assert(Roll.Roll(fixed(sum+weight),level)==id)
		end
		sum+=weight
	end
	assert(sum==total)
end
assert(Roll.Roll(fixed(1),1)=="Common")
assert(Roll.Roll(fixed(total),Config.MAX_FORGE_LEVEL)==Config.Order[#Config.Order])
for _,draw in ipairs({0,-1,total+1,0/0,1.5,math.huge}) do assert(Roll.Roll(fixed(draw),1)==nil) end
local saved={Rarity="Ultra",Stats={Attack=100},WeaponData={Progression={Level=45}}}
assert(Progression.NormalizeWeaponItem(saved) and saved.Rarity=="Ultra" and saved.WeaponData.Progression.Level==45)
print("Expanded rarity windows, exact integer rolls and saved rarity identity passed")
return true
