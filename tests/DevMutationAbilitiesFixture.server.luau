-- Studio Mock-profile test loadout. This tracked file is never Rojo-mounted.
-- Agent may copy to src/ServerScriptService/ locally for manual Play sessions.
-- The game's ProfileInit uses ProfileStore.Mock in Studio: test weapons never
-- touch production DataStores. No existing weapons are deleted or modified.
local RunService=game:GetService("RunService")
if not RunService:IsStudio() then return end
local Players=game:GetService("Players")
local Profiles=require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local Catalog=require(game.ServerScriptService.Economy.AxeShopCatalog)
local Forge=require(game.ReplicatedStorage.Shared.ForgeMutationRules)
local AddShop=game.ServerScriptService.Inventory:WaitForChild("AddShopAxeItem")
local abilities={
	{Id="GoldenRush",Family="Golden"},
	{Id="GoldenJackpot",Family="Golden"},
	{Id="Bloodrush",Family="Frenzied"},
	{Id="Rampage",Family="Frenzied"},
	{Id="ChainLightning",Family="Shocked"},
}
local function findAbility(family,id)
	local logs={}
	for _=1,4 do
		logs[#logs+1]={SpeciesId="Oak",SizeScale=5,Mutations={[family]=true}}
	end
	local preview=Forge.Preview(logs,2)
	assert(preview and preview.Family==family,"Tier2 mutation preview unavailable")
	local cumulative=0
	for _,entry in ipairs(preview.AbilityOdds) do
		if entry.Id==id then
			local roll=cumulative+entry.Chance/2
			local rng={NextNumber=function() return roll end}
			local chosen=Forge.Roll(preview,2,rng)
			assert(chosen and chosen.Id==id,"Invalid fixture mutation roll "..id)
			return chosen
		end
		cumulative+=entry.Chance
	end
	error("Unknown test ability: "..id)
end
local function alreadyOwned(data,uid)
	for _,item in ipairs(data.Inventory or {}) do
		if item.UID==uid then return true end
	end
	return false
end
local function createRecord(player,spec)
	local ability=findAbility(spec.Family,spec.Id)
	-- Make Jackpot easy to SEE in a short manual playtest. This override
	-- belongs to this Studio-only sample weapon, NOT the real forge odds.
	if spec.Id=="GoldenJackpot" then
		ability.Effect.Params.Chance=0.5
	end
	return {
		ItemID=102,
		UID="dev-batch2-"..tostring(player.UserId).."-"..spec.Id,
		Stats={Attack=math.max(0,35-Catalog.BaseAttack)},
		Substat={},Rarity="Common",
		WeaponData={
			RecipeId="dev_batch2_studio",
			WeaponKind="Axe",ExperimentalClass="Axe",
			AxeTier=1,Metal="Copper",HeadId="copper_head",
			CraftedPower=35,AttacksPerSecond=2.2,Reach=1,
			Effects={ability.Effect},
			MutationAbility={
				Family=ability.Family,Id=ability.Id,
				Potency=ability.Potency,ForgeTier=ability.Tier,
			},Materials={},
		},
	}
end
local function start(player)
	local started=os.clock()
	while player.Parent and os.clock()-started<45 do
		local profile=Profiles.GetProfile(player)
		local data=profile and profile.Data
		if type(data)=="table" and type(data.Inventory)=="table"
			and type(data.Runtime)=="table" then
			local success=0
			for _,spec in ipairs(abilities) do
				local record=createRecord(player,spec)
				if alreadyOwned(data,record.UID) then
					success+=1
				else
					local added=false
					for attempt=1,15 do
						if not player.Parent then return end
						local ok,result=pcall(function()
							return AddShop:Invoke(player,record)
						end)
						if ok and result==true then
							added=true
							break
						end
						task.wait(0.6)
					end
					if added then
						success+=1
						print("[MutationBatch2Fixture] ADDED "..spec.Id)
					else
						warn("[MutationBatch2Fixture] COULD NOT ADD "..spec.Id..
							" (inventory full or inventory not ready)")
					end
				end
			end
			print(string.format(
				"[MutationBatch2Fixture] READY %d/5: M > AXES > INFO; equip by ability name.",
				success))
			print("[MutationBatch2Fixture] GoldenJackpot sample uses 50% PROC CHANCE only for short Studio testing.")
			print("[MutationBatch2Fixture] All five are ordinary equipped Axe tools with saved WeaponData.Effects in Studio Mock only.")
			return
		end
		task.wait(0.5)
	end
	warn("[MutationBatch2Fixture] Profile unavailable after 45s; no weapons injected.")
end
task.spawn(function()
	local limit=os.clock()+60
	while os.clock()<limit do
		local players=Players:GetPlayers()
		if #players==1 then
			start(players[1])
			return
		end
		task.wait(0.5)
	end
end)
