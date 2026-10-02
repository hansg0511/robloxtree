local DefaultPlayerData = {}
	-- List of axe names the player owns
export type PlayerData = { 
	Inventory: {
		{
			ItemID : number,
			UID : string,
			Stats : {
				[string] : number,
			},
			Rarity: string
		}
	},
		
	Equipped : {
		Weapon:string,},
	Coins : number,
	Wood : number,
	ActivePets : { string },

}

return DefaultPlayerData
