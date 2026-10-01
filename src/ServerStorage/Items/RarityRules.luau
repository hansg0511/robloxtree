local RarityRules = {

	Common = {
		Weight = 70,
		StatCount = 1,
		Color = Color3.fromRGB(200, 200, 200)
	},

	Rare = {
		Weight = 20,
		StatCount = 2,
		Color = Color3.fromRGB(80, 120, 255)
	},

	Epic = {
		Weight = 9,
		StatCount = 3,
		Color = Color3.fromRGB(170, 80, 255)
	},

	Legendary = {
		Weight = 1,
		StatCount = 4,
		Color = Color3.fromRGB(255, 170, 50)
	}
}

return RarityRules