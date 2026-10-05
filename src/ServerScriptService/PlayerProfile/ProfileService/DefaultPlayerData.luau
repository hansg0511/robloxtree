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
	Mutations: { [string]: any },
	Locked: boolean,
	CreatedAt: number,
}

export type AxeHeadCounts = { [string]: number }

export type RunProgress = {
	StandardAxeTier: number,
	UnlockedForests: { [string]: boolean },
}

export type PlayerData = {
	Inventory: { InventoryItem },
	Logs: { LogItem },
	AxeHeads: AxeHeadCounts,
	RunProgress: RunProgress,
	CarryCapacityKg: number,
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
