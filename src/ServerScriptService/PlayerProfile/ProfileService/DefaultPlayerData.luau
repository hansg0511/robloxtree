local DefaultPlayerData = {}

-- Persistent profile shape only. Runtime data is initialized separately and is
-- intentionally excluded because the current foundation does not persist it.
export type InventoryItem = {
	ItemID: number,
	UID: string,
	Stats: { [string]: number },
	Substat: { [string]: number },
	Rarity: string,
}

export type LogItem = {
	UID: string,
	ItemType: "Log",
	SpeciesId: string,
	WeightKg: number,
	SizeScale: number,
	Mutations: { [string]: any },
	Locked: boolean,
	CreatedAt: number,
}

export type PlayerData = {
	Inventory: { InventoryItem },
	Logs: { LogItem },
	LogCapacity: number,
	LumberjackStrength: number,
	Coins: number,
	Wood: number,
	LogInTimes: number,
	Equipped: {
		Weapon: string,
	},
	ActivePets: { string },
}

return DefaultPlayerData
