-- PROVISIONAL balance. Premium is earned only through time-gated quests
-- and future scheduled competitive events. No Robux products are wired.
local C={}
C.PREMIUM="PremiumCurrency"
C.CRYSTAL="AscensionCrystal"
C.LABELS={PremiumCurrency="Gems",AscensionCrystal="Ascension Crystals"}
C.CRYSTAL_PRICE=2
C.MAX_CRYSTAL_PURCHASE=100
C.QUEST_REWARDS={
	daily_wild_chops=2,daily_grove_harvest=2,
	weekly_wild_chops=8,weekly_grove_harvest=8,
}
C.AWAKEN={Coins=5000,Premium=30}
C.REPLACE={Coins=20000,Premium=100}
C.ASCENSION_CRYSTALS={
	Common=1,Uncommon=1,Rare=1,Epic=2,Legendary=2,Mythical=3,
	Ultra=3,Divine=4,Celestial=5,Eternal=6,Primordial=8,
}
C.FREE_FAMILY_WEIGHTS={Golden=1,Frenzied=1,Shocked=1}
-- Fractions of current Forge potency cap, not additive bonuses.
C.FREE_POTENCY_MIN=0.10
C.FREE_POTENCY_MAX=0.30
C.STUDIO_PREMIUM_FLOOR=10000
C.STUDIO_CRYSTAL_FLOOR=1000
return C
