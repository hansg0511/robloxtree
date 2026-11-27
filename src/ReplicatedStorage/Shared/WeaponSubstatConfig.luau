-- Provisional balance only. Base rolls are in percentage points, growth is
-- linear relative to the original roll. Tune sources together before launch.
local Config = {}
Config.Slots = {
	Common=0, Uncommon=1, Rare=1, Epic=2, Legendary=2, Mythical=3,
	Ultra=3, Divine=4, Celestial=4, Eternal=5, Primordial=5, Transcendent=6,
}
Config.Stats = {
	{ Id="Damage", Label="Bonus damage", Min=3, Max=10, Growth=0.02, Weight=1 },
	{ Id="Haste", Label="Attack speed", Min=2, Max=6, Growth=0.02, Weight=1 },
	{ Id="CritChance", Label="Critical chance", Min=1, Max=5, Growth=0.02, Weight=1, Points=true },
	{ Id="CritDamage", Label="Critical damage", Min=5, Max=15, Growth=0.02, Weight=1, Points=true },
	{ Id="CoinGain", Label="Bonus coins", Min=5, Max=15, Growth=0.02, Weight=1 },
	{ Id="WeaponXP", Label="Weapon XP gain", Min=5, Max=15, Growth=0.02, Weight=1 },
	{ Id="ExtraLogs", Label="Extra log drop chance", Min=2, Max=5, Growth=0.02, Weight=1 },
}
Config.RollPrecision = 10 -- tenths of a percentage point
Config.MaxHarvestLogs = 16 -- operational bound; not a balance target
Config.ById = {}
for _, row in ipairs(Config.Stats) do
	assert(not Config.ById[row.Id] and row.Min>0 and row.Max>=row.Min and row.Weight>0 and row.Growth>=0, "invalid passive config")
	Config.ById[row.Id] = row
end
return Config
