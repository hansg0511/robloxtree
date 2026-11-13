# Lighting comparison

This is a Studio-only visual comparison guide for place 121864357793790. A and B are preview variants; neither is a finalized production lighting preset.

## Captured Studio baseline

Read from the open place in Edit mode on 2026-11-14:

| Lighting property | Baseline |
| --- | --- |
| LightingStyle | Soft |
| Technology | Not readable through the Studio inspection API; no value is inferred |
| Brightness | 2 |
| Ambient | RGB(138, 138, 138), approximately |
| OutdoorAmbient | RGB(128, 128, 128), approximately |
| EnvironmentSpecularScale / EnvironmentDiffuseScale | 0 / 0 |
| ClockTime | 14:00 (14) |
| ExposureCompensation | 0 |
| GlobalShadows | true |
| ShadowSoftness / GeographicLatitude | 0.2 / 41.7333 |
| FogColor / FogStart / FogEnd | RGB(192, 192, 192), approximately / 0 / 100000 |
| ColorShift_Top / ColorShift_Bottom | RGB(0, 0, 0) / RGB(0, 0, 0) |
| PrioritizeLightingQuality | true |

There were no Sky, Atmosphere, or PostEffect instances directly under Lighting. The current Edit camera also had no PostEffect descendants. `Lighting.StudioReferenceOriginals` is the only direct Lighting child; it contains the original Terrain folder and Border model.

## Rojo and Studio ownership

`default.project.json` does not map the Lighting service. Rojo therefore does not reconstruct Lighting properties or descendants; the place in Studio is the source of truth for this baseline. Preserve `Lighting.StudioReferenceOriginals` and its contents. It holds original scene assets, not preview effects, and must not be removed, renamed, or repurposed during comparison. See `docs/REFERENCE_ASSETS.md` for the asset note.

## Manual Studio Play comparison

Start Studio Play manually. During the client session, click the LIGHTING PREVIEW button at the lower-left to open the dock; use its controls:

| Control | Preview |
| --- | --- |
| `ORIGINAL` | Disabled until the first A or B selection. That selection captures a fixed snapshot at that moment; afterward, ORIGINAL restores it for this client preview session. |
| `A · BRIGHT CARTOON SOFT` | Brightness 2; ClockTime 14; Ambient RGB(150, 150, 150); OutdoorAmbient RGB(180, 180, 180); both environment scales 0; ExposureCompensation 0; GlobalShadows true. |
| `B · FLAT CARTOON` | Same brightness, time, exposure, and environment scales as A; Ambient and OutdoorAmbient RGB(175, 175, 175); GlobalShadows false. |

Both A and B require `LightingStyle = Soft`. The preview script cannot set this protected property; confirm or change it manually in Studio Properties before comparing. A/B/ORIGINAL run client-side in Studio Play; preview settings never persist to the place. For A/B, the preview temporarily disables direct PostEffects under Lighting and the current camera, and sets direct Lighting Atmosphere Density, Haze, and Glare to zero. ORIGINAL restores the captured values; teardown restores any active preview and removes the UI. No instances are removed.

Use the controls for manual visual comparison only. No production preset has been selected, and no automated playtest has been run.

## Material audit

All BaseParts in the twelve selected templates in ForestToolboxAssets.rbxm have `Reflectance = 0`, including the 24 dirt-path parts. `Stylised_Rock01`, `Stylised_Rock02`, and `Stylised_Rock03` each include a `SurfaceAppearance`; their rendered appearance and gloss have not been visually verified. The forge anvil intentionally uses `Metal` in `WorldLayoutService`. Approved asset appearances remain unchanged.
