local DefaultPlayerData = {}

-- Persistent profile shape only. Runtime data is initialized separately and is
-- intentionally excluded because the current foundation does not persist it.
-- WeaponData.Progression is an optional, versioned persistent payload.
-- Legacy weapons may still lack it until ProfileDataCache normalization.
export type WeaponProgression = {
	SchemaVersion: number,
	Level: number,
	XP: number,
	AscensionFailures: number,
}

export type InventoryItem = {
	ItemID: number,
	UID: string,
	Stats: { [string]: number },
	Substat: { [string]: number },
	Rarity: string,
	WeaponData: { [string]: any }?,
}

export type LogItem = {
	UID: string,
	ItemType: "Log",
	SpeciesId: string,
	Mutations: { [string]: any },
	Locked: boolean,
	CreatedAt: number,
	SizeScale: number?,
}

export type GroveMutations = { [string]: boolean }

export type Sapling = {
	UID: string,
	SpeciesId: string,
	Mutations: GroveMutations,
	SizePotential: number,
	CreatedAt: number,
}

export type GroveTree = {
	UID: string,
	SourceSaplingUID: string,
	SpeciesId: string,
	Mutations: GroveMutations,
	SizePotential: number,
	CurrentSizeScale: number?,
	HarvestCount: number?,
	LocalX: number,
	LocalZ: number,
	Yaw: number,
	PlantedAt: number,
	MaturesAt: number,
}

export type Heartwood = {
	UID: string,
	MaterialType: "Heartwood",
	SpeciesId: string,
	Mutations: GroveMutations,
	SizePotential: number,
	SourceGroveTreeUID: string,
	SourceSaplingUID: string,
	CreatedAt: number,
}

export type AxeHeadCounts = { [string]: number }

export type RunProgress = {
	StandardAxeTier: number,
	ForgeLevel: number,
	UnlockedForests: { [string]: boolean },
}

export type PlayerData = {
	Inventory: { InventoryItem },
	Logs: { LogItem },
	StoredLogs: { LogItem },
	AutoKeep: { Mutations: boolean, Oversized: boolean, SizeThreshold: number },
	Saplings: { Sapling },
	SaplingShop: { RareBoughtCycle: number },
	QuestProgress: { Stage: number, Count: number },
	QuestRecurring: { [string]: { WindowId: number, Counts: { [string]: number }, Claimed: { [string]: boolean } } },
	ChopLeaderboard: { Lifetime: number, WeeklyWindowId: number, WeeklyCount: number },
	GroveTrees: { GroveTree },
	GroveMaterials: { Heartwood },
	-- Future recipe catalysts/essences, counted by server-assigned material ID.
	MaterialBalances: { [string]: number },
	ActiveGroveTreeUIDs: { string },
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
