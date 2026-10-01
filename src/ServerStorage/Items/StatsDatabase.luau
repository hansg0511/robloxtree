local StatDatabase = {

	Attack = {
		DisplayName = "Attack",
		Categories = { "Weapon", "Pet" },

		BaseRange = { min = 3, max = 6 },

		Scaling = {
			Common = 1.0,
			Rare = 1.3,
			Epic = 1.7,
			Legendary = 2.3
		},

		StackType = "Add" -- Add | Mult | Special
	},

	CritChance = {
		DisplayName = "Crit Chance",
		Categories = { "Weapon" },

		BaseRange = { min = 1, max = 5 }, -- percent

		Scaling = {
			Common = 1.0,
			Rare = 1.2,
			Epic = 1.5,
			Legendary = 2.0
		},

		StackType = "Add"
	},

	CritDamage = {
		DisplayName = "Crit Damage",
		Categories = { "Weapon" },

		BaseRange = { min = 10, max = 30 }, -- percent

		Scaling = {
			Common = 1.0,
			Rare = 1.25,
			Epic = 1.6,
			Legendary = 2.2
		},

		StackType = "Add"
	}
}

return StatDatabase
