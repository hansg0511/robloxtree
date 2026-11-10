# Creator Store toolbox asset catalog

Research snapshot: 2026-11-11. This catalog covers all 33 requested Creator Store IDs and records separately (1) listing and price evidence, and (2) whether an asset is present in the current source-backed preview snapshot or was attempted for import.

The price check used Roblox Studio's Creator Store search for each numeric ID with Model type and all prices. A matching result with `isFree=true` and `priceCents=0` is marked **free verified**. `MarketplaceService:GetProductInfo` also resolved metadata for the candidate IDs, but its `IsForSale=false`, `ProductId=0`, and absent `PriceInRobux` fields do not prove a currently free or available listing. Four exact IDs did not appear in the current Creator Store search; their present price and availability remain **unknown**. No candidate was identified as currently paid in an exact listing result.

## Status summary

- 29 of the 33 requested IDs have an exact Creator Store result at 0 cents.
- 8 of the requested 33 candidates are source-backed preview selections in `src/ServerStorage/DevToolboxAssets/ForestToolboxAssets.rbxm`; the two previously liked extras below are also source-backed previews.
- `8421400545` (Rock Pack) is free verified, but its import attempt returned HTTP 502. Retry through Studio or use the manual steps below; this is not a finding that the asset is unavailable.
- 20 other free verified candidates have not been attempted.
- 4 IDs have unresolved exact listing price/availability: `7436760067`, `6594760658`, `5642566546`, and `8729589253`.
- The rows below preserve each requested ID. Where the exact Store search did not return a result, the canonical ID URL is provided as a navigation link, not as proof that the live listing is available or free.

## Requested candidates

### Priority A — Complete nature packs

| Asset | Creator Store ID | Creator / listing | Price evidence | Import / source status |
| --- | ---: | --- | --- | --- |
| Synty Nature Pack | `6933438443` | [Roblox](https://create.roblox.com/store/asset/6933438443) | 0 cents (free verified) | Source-backed preview selection in `ForestToolboxAssets.rbxm`. |
| Low Poly Asset Pack | `7436760067` | [albinoBrotha67](https://create.roblox.com/store/asset/7436760067) | Unknown — exact ID not returned by current Creator Store search | Not attempted; current exact listing price/availability unknown. |
| Stylised Low-Poly Nature Pack | `6503281311` | [DarkWatery](https://create.roblox.com/store/asset/6503281311) | 0 cents (free verified) | Source-backed preview selection in `ForestToolboxAssets.rbxm`. |
| Forest Pack | `6432306802` | [Roblox](https://create.roblox.com/store/asset/6432306802) | 0 cents (free verified) | Source-backed preview selection in `ForestToolboxAssets.rbxm`. |
| Stylized Nature Pack | `6594760658` | [Soulskor](https://create.roblox.com/store/asset/6594760658) | Unknown — exact ID not returned by current Creator Store search | Not attempted; current exact listing price/availability unknown. |
| [FREE] Low polly asset pack (candidate: Free Low Poly Asset Pack) | `79195618410265` | [Jax0nStream201042](https://create.roblox.com/store/asset/79195618410265) | 0 cents (free verified) | Free verified; not attempted. |
| Crazed's Stylized Asset Pack | `12477025465` | [Crazedbrick1](https://create.roblox.com/store/asset/12477025465) | 0 cents (free verified) | Free verified; not attempted. |

### Priority B — Bushes and shrubs

| Asset | Creator Store ID | Creator / listing | Price evidence | Import / source status |
| --- | ---: | --- | --- | --- |
| Low Poly Bushes Kit | `14438790919` | [kidtraxdev](https://create.roblox.com/store/asset/14438790919) | 0 cents (free verified) | Source-backed preview selection in `ForestToolboxAssets.rbxm`. |
| Bush V2 | `5555817140` | [Z_Zeros](https://create.roblox.com/store/asset/5555817140) | 0 cents (free verified) | Free verified; not attempted. |
| Low poly big bush (candidate: Low Poly Big Bush) | `14720410685` | [Tanakob12345](https://create.roblox.com/store/asset/14720410685) | 0 cents (free verified) | Free verified; not attempted. |
| Bush (2) | `8782385501` | [SergoUral_2](https://create.roblox.com/store/asset/8782385501) | 0 cents (free verified) | Free verified; not attempted. |

### Priority C — Rocks, boulders and pebbles

| Asset | Creator Store ID | Creator / listing | Price evidence | Import / source status |
| --- | ---: | --- | --- | --- |
| Mesh Rock Pack | `5642566546` | [MemerBoi1789](https://create.roblox.com/store/asset/5642566546) | Unknown — exact ID not returned by current Creator Store search | Not attempted; current exact listing price/availability unknown. |
| Rock Pack | `8421400545` | [RedWood Roleplay GROUP](https://create.roblox.com/store/asset/8421400545) | 0 cents (free verified) | Free verified; import attempt returned HTTP 502. Retry in Studio or use manual import; not classified unavailable. |
| Pebble | `337332869` | [WentLimited](https://create.roblox.com/store/asset/337332869) | 0 cents (free verified) | Free verified; not attempted. |
| Old Pebble | `10592816110` | [renoikaii](https://create.roblox.com/store/asset/10592816110) | 0 cents (free verified) | Free verified; not attempted. |
| Arid Rock Pack - HIGH POLY (candidate: Arid Rock Pack) | `104711608624243` | [1231551](https://create.roblox.com/store/asset/104711608624243) | 0 cents (free verified) | Free verified; not attempted. |

### Priority D — Fallen logs and stumps

| Asset | Creator Store ID | Creator / listing | Price evidence | Import / source status |
| --- | ---: | --- | --- | --- |
| Low Poly Log | `11312714034` | [osddxx](https://create.roblox.com/store/asset/11312714034) | 0 cents (free verified) | Source-backed preview selection in `ForestToolboxAssets.rbxm`. |
| Wood Log | `265431546` | [Glitterkittyparty108](https://create.roblox.com/store/asset/265431546) | 0 cents (free verified) | Free verified; not attempted. |
| Dead Tree Fallen | `18986398652` | [quickRoberto045](https://create.roblox.com/store/asset/18986398652) | 0 cents (free verified) | Free verified; not attempted. |
| Tree Stump | `167792459` | [Inferuno](https://create.roblox.com/store/asset/167792459) | 0 cents (free verified) | Free verified; not attempted. |

### Priority E — Flowers, grass and plants

| Asset | Creator Store ID | Creator / listing | Price evidence | Import / source status |
| --- | ---: | --- | --- | --- |
| Colored Flowers Pack | `17638037773` | [RealDipperBot](https://create.roblox.com/store/asset/17638037773) | 0 cents (free verified) | Source-backed preview selection in `ForestToolboxAssets.rbxm`. |
| Flowers pack (candidate: Flowers Pack) | `15522563459` | [justGiffix](https://create.roblox.com/store/asset/15522563459) | 0 cents (free verified) | Free verified; not attempted. |
| Grass Pack | `8729589253` | [wooful67](https://create.roblox.com/store/asset/8729589253) | Unknown — exact ID not returned by current Creator Store search | Not attempted; current exact listing price/availability unknown. |
| Fern | `4620415269` | [John_Frontflip](https://create.roblox.com/store/asset/4620415269) | 0 cents (free verified) | Free verified; not attempted. |
| fourleaf clover (candidate: Fourleaf Clover) | `10862920725` | [kblee0729](https://create.roblox.com/store/asset/10862920725) | 0 cents (free verified) | Free verified; not attempted. |
| Retro Mushrooms | `16573639066` | [2_908](https://create.roblox.com/store/asset/16573639066) | 0 cents (free verified) | Free verified; not attempted. |
| Glowing Mushroom | `3350230927` | [AddictedComputerGuy](https://create.roblox.com/store/asset/3350230927) | 0 cents (free verified) | Free verified; not attempted. |

### Priority F — Paths and additional decorations

| Asset | Creator Store ID | Creator / listing | Price evidence | Import / source status |
| --- | ---: | --- | --- | --- |
| Dirt Path | `5216151629` | [Titan Overlords](https://create.roblox.com/store/asset/5216151629) | 0 cents (free verified) | Source-backed preview selection in `ForestToolboxAssets.rbxm`. |
| Wooden Fence | `8399365124` | [A_RandomPuppy](https://create.roblox.com/store/asset/8399365124) | 0 cents (free verified) | Source-backed preview selection in `ForestToolboxAssets.rbxm`. |
| Wood Wooden Fence | `10348034923` | [A_RandomPuppy](https://create.roblox.com/store/asset/10348034923) | 0 cents (free verified) | Free verified; not attempted. |
| Wooden Sign | `3382116092` | [trestsc](https://create.roblox.com/store/asset/3382116092) | 0 cents (free verified) | Free verified; not attempted. |
| Medium Wooden Sign | `12949136308` | [SimplyCube](https://create.roblox.com/store/asset/12949136308) | 0 cents (free verified) | Free verified; not attempted. |
| low poly campfire (candidate: Low Poly Campfire) | `8636042955` | [jasonkingtou](https://create.roblox.com/store/asset/8636042955) | 0 cents (free verified) | Free verified; not attempted. |

## Previously liked free extras

These two IDs are outside the original set of 33. Creator Store search returned exact Model listings at 0 cents for both.

| Asset | Creator Store ID | Creator / listing | Price evidence | Note |
| --- | ---: | --- | --- | --- |
| Low Poly Flower Bush | `1353190583` | [Catmen126](https://create.roblox.com/store/asset/1353190583) | 0 cents (free verified) | Previously user-liked source-backed preview in the snapshot. |
| Blocky Flowers | `244971827` | [Mossbird](https://create.roblox.com/store/asset/244971827) | 0 cents (free verified) | Previously user-liked source-backed preview; listing requests credit to ilovegixx. |

## Source snapshot and inspection limits

The current `ForestToolboxAssets.rbxm` is a **visual-only preview snapshot** with 36 template Models, 301 descendants, and 97 BaseParts. It includes 43 MeshParts that reference 34 distinct external MeshIds, 11 SurfaceAppearance instances, and 24 Decals. The snapshot contains 0 Script, LocalScript, ModuleScript, RemoteEvent, RemoteFunction, or ProximityPrompt instances. These external mesh and texture assets may require separate permissions or may fail to load for another account or place. The .rbxm snapshot does not establish published-game loading behavior.

Triangle counts and full external asset permission status remain unknown, so no performance or cross-account availability claim is made. The imports have not been subjected to a Studio playtest as part of this documentation task. A Store listing marked free also does not guarantee that the requesting place can load its content.

## Usage and attribution notes

- **Synty Nature Pack (6933438443):** its listing description says several Synty packs were officially licensed for use in any Roblox game. Preserve the Creator Store ID and listing attribution.
- **Stylised Low-Poly Nature Pack (6503281311):** its listing description says it is free to use and requires no credit.
- **Low Poly Asset Pack (7436760067):** its ProductInfo description says simulator-map use is allowed but resale and commission use are not. The current exact listing price and availability are unknown, so this text is not proof of current free access.
- **Stylized Nature Pack (6594760658):** its ProductInfo description says “Feel Free to use”; current exact listing price and availability are unknown.
- **Blocky Flowers (244971827):** its listing description says “Credit to ilovegixx”; retain that credit if used.
- **Free Low polly asset pack (79195618410265)** has a long unrelated keyword-stuffed description. **Dead Tree Fallen (18986398652)** also has a keyword-stuffed description. Inspect the model carefully before adding either.
- The other descriptions were blank or did not state special usage conditions in the checked metadata. Check the live Creator Store listing and creator terms before reuse; do not infer a broad license from a 0-cent price.

## Manual Studio import for future candidates

1. In Roblox Studio, open **Toolbox** and choose **Creator Store / Marketplace**, then filter to **Models** or **3D Assets**.
2. Search the numeric Creator Store ID. Confirm the returned title and creator against this catalog, then verify the current price is explicitly free before importing. If the ID does not return an exact match or a price is shown, stop and record the status as unknown or paid.
3. Import the selected model into an isolated inspection place. Inspect its descendants in Explorer. Remove or reject any Script, LocalScript, or ModuleScript from the preview copy; check MeshParts, texture references, materials, and package dependencies. Do not use a runtime-loading workaround to bypass Creator Store permissions.
4. After review, select the sanitized model in Explorer, right-click it, and choose **Save to File** to create an individual `.rbxm`. Add only that reviewed file to `src/ServerStorage/DevToolboxAssets` and record its original ID, creator, and any required attribution.
5. Keep each addition deliberate and individually reviewed. Recheck permissions and price when Studio or account context changes.

## Evidence and scope

Listing identity, creator, and price status came from Studio's Creator Store exact-ID search and read-only `MarketplaceService:GetProductInfo` metadata in Edit mode. Source status reflects the existing preview snapshot and the recorded HTTP 502 result for Rock Pack. This document does not claim that every free candidate was imported, that the four unresolved entries are free, or that external mesh/texture access is available in another place or account.
