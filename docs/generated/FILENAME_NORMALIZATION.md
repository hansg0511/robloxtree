# Filename normalization

`ServerScriptService.Trees.BuildTree/Plots` was a Studio Script whose name contains `/`. Windows and Rojo cannot represent that name as a normal source path, so the first syncback preserved the entire `Trees` branch as `src/ServerScriptService/Trees.rbxm`.

It has now been converted to text-backed Rojo source:

| Studio name before sync | Rojo source | Studio name after next Rojo sync |
| --- | --- | --- |
| `BuildTree/Plots` | `Trees/BuildTreePlots.server.luau` | `BuildTreePlots` |
| `TreeObject` ModuleScript | `Trees/TreeObject/init.luau` | `TreeObject` |
| `TreeObject.TreeDatabase` | `Trees/TreeObject/TreeDatabase.luau` | `TreeDatabase` |

The original binary branch is preserved at `archive/pre-normalization/Trees-before-filename-normalization.rbxm` for rollback. No known source reference depends on the old slash-containing name; the next Studio connection should still be checked to ensure the old Script does not remain alongside the renamed one.
