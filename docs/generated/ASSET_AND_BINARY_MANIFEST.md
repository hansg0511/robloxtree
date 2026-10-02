# Active binary source artifacts

The major old-world and Goblin/Gun binaries were removed from active source after the full Studio place backup. They remain recoverable from `archive/pre-gameplay-rework` and the archive Git branch.

The active repo still includes `.rbxm` GUI hierarchies under `src/StarterGui` and reusable axe/item assets under `src/ServerStorage/AxeParts` and `src/ServerStorage/Items`. These binaries need Studio inspection for visual hierarchy and nested instance properties; adjacent `.luau` and `.json` files are preferable for code review.

`BrickWorldBase.rbxl` is the cleaned full place. It is not a source of truth for Rojo-mapped scripts; use `src/` for those. `archive/pre-normalization/Trees-before-filename-normalization.rbxm` is rollback-only.
