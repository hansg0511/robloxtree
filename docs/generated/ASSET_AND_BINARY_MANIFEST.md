# Binary source artifacts

Rojo preserves complex Studio instances as `.rbxm` files. They are versioned here but are not useful for line-by-line code review without opening them in Roblox Studio.

Notable binary artifacts:

- `src/StarterGui/EconomyGui.rbxm`, `InventoryScreenGui.rbxm`, and `TEMPLATES.rbxm` — existing GUI hierarchy and embedded GUI scripts.
- `src/ServerStorage/TreeTypes/Basic.rbxm`, `PlotTemplate/PlotModel.rbxm`, and `PassivePlotTemplate/**/*.rbxm` — gameplay templates instantiated at runtime.
- `src/ServerStorage/Goblin.rbxm`, `Platform.rbxm`, `Tree Minecraft.rbxm`, and `AxeParts/**/*.rbxm` — models and imported assets.
- `archive/pre-normalization/Trees-before-filename-normalization.rbxm` — rollback-only copy of the formerly slash-named `Trees` branch.

For review: inspect the adjacent `.luau` and `.json` files first. Open the `.rbxm` in Studio when reviewing instance properties, constraints, attachments, GUI layout, or scripts nested inside the binary model.
