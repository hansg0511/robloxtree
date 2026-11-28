-- Permanent, server-owned descriptive achievement statistics. No title rewards.
local Config=require(game.ReplicatedStorage.Shared.ProgressionConfig)
local Geometry=require(game.ReplicatedStorage.Shared.MaterialGeometry)
local Rules={}
local MAX_COUNT=1000000000000
local function bounded(v,upper,integer)
	if type(v)~="number" or v~=v or v<0 or v>upper or (integer and v%1~=0) then return 0 end
	return v
end
local function rarity(v)
	return type(v)=="string" and Config.ById[v] and v or ""
end
local function bestRarity(a,b)
	local first,second=Config.ById[a],Config.ById[b]
	if second and (not first or second.Index>first.Index) then return b end
	return a
end
local maxQuality=Geometry.MAX_PHYSICAL_LOG_SIZE/Geometry.MAX_LOG_SIZE
function Rules.Normalize(raw)
	local v=if type(raw)=="table" then raw else {}
	local guards={}
	for key,cleared in pairs(type(v.GuardiansCleared)=="table" and v.GuardiansCleared or {}) do
		if type(key)=="string" and #key<=80 and cleared==true then guards[key]=true end
	end
	return {
		WeaponsForged=bounded(v.WeaponsForged,MAX_COUNT,true),
		GroveHarvests=bounded(v.GroveHarvests,MAX_COUNT,true),
		SuccessfulAscensions=bounded(v.SuccessfulAscensions,MAX_COUNT,true),
		HighestLogQuality=bounded(v.HighestLogQuality,maxQuality,false),
		HighestSaplingPotential=bounded(v.HighestSaplingPotential,Geometry.MAX_PHYSICAL_LOG_SIZE,false),
		HighestWeaponLevel=bounded(v.HighestWeaponLevel,Config.RARITIES[#Config.RARITIES].LevelCap,true),
		HighestRarityForged=rarity(v.HighestRarityForged),
		HighestWeaponRarity=rarity(v.HighestWeaponRarity),
		HighestCraftedMaterialQuality=bounded(v.HighestCraftedMaterialQuality,maxQuality,false),
		GuardiansCleared=guards,
	}
end
local function get(data)
	if type(data)~="table" then return nil end
	if type(data.LifetimeStats)~="table" or type(data.LifetimeStats.WeaponsForged)~="number" then
		data.LifetimeStats=Rules.Normalize(data.LifetimeStats)
	end
	return data.LifetimeStats
end
local function increment(s,key) s[key]=math.min(MAX_COUNT,s[key]+1) end
function Rules.RecordCraft(data,id,quality)
	local s=get(data)
	if not s or not Config.ById[id] then return end
	increment(s,"WeaponsForged")
	s.HighestRarityForged=bestRarity(s.HighestRarityForged,id)
	s.HighestWeaponRarity=bestRarity(s.HighestWeaponRarity,id)
	s.HighestWeaponLevel=math.max(s.HighestWeaponLevel,1)
	s.HighestCraftedMaterialQuality=math.max(s.HighestCraftedMaterialQuality,bounded(quality,maxQuality,false))
end
function Rules.RecordGroveHarvest(data)
	local s=get(data)
	if s then increment(s,"GroveHarvests") end
end
function Rules.RecordAscension(data,id)
	local s=get(data)
	if not s or not Config.ById[id] then return end
	increment(s,"SuccessfulAscensions")
	s.HighestWeaponRarity=bestRarity(s.HighestWeaponRarity,id)
end
function Rules.RecordLog(data,size)
	local s=get(data)
	if s then s.HighestLogQuality=math.max(s.HighestLogQuality,bounded(size,Geometry.MAX_PHYSICAL_LOG_SIZE,false)/Geometry.MAX_LOG_SIZE) end
end
function Rules.RecordSaplingDiscovery(data,potential)
	local s=get(data)
	if s then s.HighestSaplingPotential=math.max(s.HighestSaplingPotential,bounded(potential,Geometry.MAX_PHYSICAL_LOG_SIZE,false)) end
end
function Rules.RecordLevel(data,level,id)
	local s=get(data)
	if not s or not Config.ById[id] then return end
	s.HighestWeaponLevel=math.max(s.HighestWeaponLevel,bounded(level,Config.ById[id].LevelCap,true))
	s.HighestWeaponRarity=bestRarity(s.HighestWeaponRarity,id)
end
function Rules.RecordGuardian(data,id)
	local s=get(data)
	if s and type(id)=="string" and #id>0 and #id<=80 then s.GuardiansCleared[id]=true end
end
return Rules
