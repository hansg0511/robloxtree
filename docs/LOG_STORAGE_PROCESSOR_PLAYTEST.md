# Protected log storage + physical processor prototype

Branch: `feature/log-storage-processor-prototype`, based on `design/fixed-weapon-crafting-foundation`.

## Included

- Separate profile-owned **Carry Bag** (`Logs`, existing kg upgrades) and **Saved Storage** (`StoredLogs`, provisional max **240 unique records**). Neither is a stackable timber commodity.
- Original species, mutation flags, UID and **source tree SizeScale** survive pickup, storage and forge. Legacy records without SizeScale normalize to **1.0x**. Older bag-locked logs migrate to Saved Storage when room exists.
- **Auto-keep** defaults: mutations ON, oversized ON, threshold **1.5x** source-tree size. Change from the **STORAGE N** overlay; the chosen preferences apply to **future pickups**, not retroactively. Save/To Bag moves individual UIDs. Old bag LOCK also protects/moves a log when there is room.
- Chopped ordinary logs remain visually stacked on the back. Auto-kept pickups go directly into Saved Storage (without consuming bag kg); a small local fly-and-fade effect marks collection.
- **E at WOOD PROCESSOR** immediately sells eligible ordinary *carried* logs; server credits Coins and broadcasts a bounded unload visual to nearby players aimed at `ProcessorIntake`. No timber items.
- Forge lists unique eligible logs from **both** inventories, labeled BAG/SAVED plus size. Server consumes exact UIDs and restores each record to its source on failed output insertion.
- Sell value is a **prototype** `floor(BaseSellValue * SizeScale^2 + 0.5)`. This is a visual/progression demo, not a finalized economy.
- No new weapons, special-quality RNG, Grove regrowth, sapling shop, or finished weapon size scaling were added.

## Studio smoke test

1. **Save/commit any local work first.** Run `git fetch origin`; `git switch --track origin/feature/log-storage-processor-prototype` from the repo directory. If you already have the branch locally, `git switch feature/log-storage-processor-prototype` and `git pull --ff-only`.
2. Open the existing **BrickWorldBase.rbxl** Studio place; run `rojo serve default.project.json`; connect Rojo. Confirm `ServerScriptService.Inventory.LogStorageRules`, `StarterPlayerScripts.Economy.LogStorageUI`, `LogProcessingFX`, and the three new Economy remotes appear.
3. Press Play, then press **N** or click **STORAGE N**. Confirm defaults: mutated ON, large ON, 1.5x, saved 0/240.
4. Chop Oak/Bamboo/Ironwood. Normal size logs should go to the bag/back; unusual logs at least 1.5x should disappear into Saved Storage. Source trees currently roll rare extreme sizes; for deterministic tests, manually move any carried log via N.
5. In the **BAG** tab of the storage overlay, click SAVE on a log; it should disappear from the visible back stack and appear in SAVED with the **same UID**. Move it back if bag kg permits. Verify moving back fails (with warning) when bag is full.
6. Change auto-keep toggles and threshold, collect more logs, and verify new drops follow the updated rule. Existing logs should not be reclassified retroactively.
7. Walk to **WOOD PROCESSOR**, press **E**, and verify eligible bag logs disappear, coins increase, and cosmetic logs fly into the visible mouth of the processor. **SAVED logs must remain intact and unsold.** Pressing E with an empty bag should show a no-logs message.
8. Buy a Copper Axe Head and open the Forge. Select three eligible logs from any combination of BAG and SAVED. The output is always the fixed Copper Axe, with no craft-failure roll. Confirm each consumed UID disappears from exactly one inventory; the finished weapon remains equipable.
9. Verify original carry visuals and ground overflow behavior still work. Check Studio Output for new warnings/errors; playtest with two clients if possible.
10. Paste and run `tests/LogStorageRules.smoke.luau` and `tests/WeaponRecipeRules.smoke.luau` in the **SERVER** Command Bar. They are not inside Rojo's mapped source roots.

## Edge cases / known limitations

- **ProfileStore.Mock** is still active in `PlayerProfile/ProfileInit`; session-to-session persistence is **not validated**. Do not ship a public trading economy until live persistence and consistency testing are complete.
- Storage is not literally unlimited. At 240 saved pieces, protected new logs may fall back into the bag **locked** if room remains. If both inventories are full, ordinary owner-reserved ground overflow behavior and its expiry still apply. The UI warns about storage fullness. **This is not guaranteed long-term retention; solve that before release**.
- The carry bag's kg cost is still a **fixed cost per species**, while a log's SizeScale controls the new keep threshold and prototype sale bonus. True per-log weight, Grove exceptional quality, and size-based weapon geometry remain future design work.
- The new E-to-process interaction directly sells without a confirmation menu. The old modal code remains as legacy UI but is no longer opened by the station's prompt.
- In-game script/unit tests and Studio multiplayer behavior have **not been executed** by the ChatGPT GitHub connector. This is an implementation branch pending human Studio playtest, not a verified release.
