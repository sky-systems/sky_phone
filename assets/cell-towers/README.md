# Physical cell towers

`Config.CellTowers.Props.Enabled` is **false by default**. Enable it in
`config/config.lua` or `/phonepanel` → Cell towers → Physical cell towers.
The existing `CellTowers.Enabled` switch must also be enabled.
After installing this resource update, run `refresh` before `restart sky_phone`
so FiveM reloads the manifest's new script and archetype registrations.

Each tower contains a static mast/cabinet, a hinged door and an interchangeable
intact/damaged interior. Press **E** near the cabinet to open or close it.
Opening consumes one `Props.LockpickItem` (default `lockpick`); closing is free.
Only an open interior accepts weapon damage. The damage check accepts any weapon
type, rather than a weapon-name allowlist. A damaged tower stops contributing
coverage; another healthy tower can still cover the same position.
`Props.Destructible` defaults to `true`. Set it to `false` to prevent new weapon
damage, including client reports sent directly to the server. Already damaged
towers remain damaged and can still be repaired. The switch is available in
both Lua and Phonepanel; `Props.Enabled` remains `false` by default.

Press **G** at an open, damaged cabinet to repair it. `Props.RepairJobs = {}`
allows everyone; a nonempty list allows only those framework job names.
`Props.RepairSeconds` defaults to 10. Moving away, dying, losing the required job
or closing the cabinet cancels repair. A successful repair restores coverage and
closes the cabinet. Repair requires `Props.RepairItem` (default `radiotowerparts`)
in the active inventory. The server checks it at the start and removes one only
on successful completion. Losing the item during repair prevents completion;
cancelled repairs consume nothing. Register the item in your inventory catalogue
as described in [inventory setup](../../docs/inventory-setup.md#physical-tower-materials).
Damage persists in resource KVP storage across restarts;
doors restart closed. Disabling props restores ordinary virtual-tower coverage.

Tower `Coords` is the bottom center of the foundation, not the antenna or player
center. `Heading` rotates the entire assembly. The 18 defaults now use technical
rooftops and hills instead of public squares or street-level spots. Downtown is
on a rooftop at `(102, -861, 133.750)`, replacing the mast on Legion Square.
The hilltop radio sites, Fort Zancudo water-tower roof and Cayo airstrip control
tower provide other elevated locations. Each site has a sampled 4 x 4 metre
foundation area and a clear sampled approach to the cabinet. The bottom sits
2 cm below the lowest sampled surface; the 48 cm foundation accommodates the
small terrain differences at hillside sites.

[sites.json](sites.json) records coordinates, headings, collision sources and
surface ranges. Checks used CodeWalker against the locally installed GTA
1.0.3889.0 map archives, including placed props and Cayo, with 25 cm sampling.
North Yankton collision was excluded because its world coordinates overlap Cayo.
This is an offline placement check, not a live GTA 3258 visual/access-route test.
Some roofs require a ladder, aircraft or a server-specific access route; custom
map geometry may require adjusting the positions. Moving coverage centres can
change edge coverage; existing configured ranges are preserved.

Exact earlier virtual and street-level defaults with a missing or zero heading
normalize to the new sites when loading Phonepanel configuration. Custom
coordinates, nonzero headings, ranges and list ordering remain intact.
Position (rounded to 1 mm) identifies a tower;
moving it creates a fresh damage state. Duplicate positions are rejected.

The panel's current-location button uses the ground below the player for towers.
It also supports company locations, SkyRide quick locations and custom payphones;
these use player coordinates, with heading for vector4 locations. Requests have
loading/error feedback and failed requests preserve the edited values.

## Customer models

All model settings are editable in the same Phonepanel section and in
`Config.CellTowers.Props`:

| Setting | Purpose |
| --- | --- |
| `Models.Tower` | Mast and fixed cabinet casing model |
| `Models.Door` | Separate door with its model origin at the hinge |
| `Models.Intact`, `Models.Damaged` | Separate interior states with matching origins/orientation |
| `DoorOffset` | Door hinge relative to the mast origin, in local metres |
| `PanelOffset` | Both interior models' position relative to the mast origin |
| `CabinetOffset` | Interaction point used by client and server proximity checks |
| `DoorClosedAngle`, `DoorOpenAngle` | Door headings relative to the mast heading |

Use model names without extensions. Stream custom files and register their YTYP
in this resource or a resource started before it. The supplied assets remain the
defaults; no Lua source edits are required to use alternatives. These offsets are
local, so the current-location button is intentionally absent on them.
A single rigid model cannot acquire an animated door or a separate damageable
interior automatically: replacement assets must provide those separate parts.
Keep the casing collision clear of the interior opening, and give each interior
a weapon-compatible collider. The archetype's physics dictionary must reference
the drawable containing its embedded collision.

## Assets and authoring

The mast comes from the owner's textured Meshy model, `tower_textured.glb`.
Input SHA-256 hashes are recorded in `export-report.json`, including the two
historical cabinet inputs. The original GLBs are kept outside the repository.
The current cabinets are authored by `cabinet.py`: flat steel leaves, rounded
edges, hinges, latches, louvres, geometric warning symbols and separate intact /
damaged electrical components. They do not reuse the blurred cabinet atlases.
`cell_towers.blend` is the editable source, with packed DDS textures; `textures/`
contains the standalone textures. The exported four YDRs and YTYP live under
`sky_phone/stream/`. Textures are embedded, so no separate YTD is required.

Authoring used Blender 5.2.1 and Sollumz 2.9.0 with its native GEN8 exporter.
`build.py` welds glTF seam vertices before reduction, preserves the mast's UV
boundaries, transfers the original surface normals and reprojects the original
maps onto the reduced surface. `cabinet.py` retains the shipped door hinge and
panel origins, so existing configuration needs no offset migration. Cabinet
parts share 256 x 256 colour, flat-normal and specular/gloss swatches. Surface
detail comes from geometry; increasing a blurry atlas's resolution is unnecessary.
Cabinets use four explicitly authored detail levels; the distant levels omit
screws, wires and small fittings. Each YTYP archetype references its embedded physics data.
The casing collider belongs to the invulnerable mast; only the interior opening
belongs to the damageable panel. Do not combine these collisions.

The mast and fixed cases have approximately 317,000 triangles near the player,
with 90,000 / 23,000 / 5,200 in the remaining LODs. Its drawable LOD thresholds are
35 / 100 / 230 / 500 metres; selection also depends on GTA's LOD calculation.
The mast uses reprojected 4K diffuse/normal maps and a 2K specular/gloss map,
BC1/BC3 compression and mipmaps. Original metallic/roughness channels are
converted to the GTA specular workflow; tangent-normal Y is converted for GTA.
This preserves the source detail, but GTA's lighting is not identical to Meshy's
PBR viewer. Geometry is concentrated in the near view instead of
keeping the original 1.7 million triangles at every distance. These are asset
budgets, not measured frame-time guarantees.

The earlier 40,000-triangle near mesh visibly flattened small braces and curved
parts. A fresh atlas also produced black triangular texture artifacts; plain
decimation with the original UVs distorted their boundaries and surface shading.
The near mesh now protects UV-boundary vertices, retains source normals and
reprojects texture details after reduction. Merely increasing polygon count or
copying the original texture onto changed interpolation did not correct those
artifacts. The protruding side enclosure is now replaced within its measured
volume, outside the neighbouring lattice; retained mast faces keep their UVs
and split normals. The animated fuse cabinet remains at the front.
Twelve simple colliders cover the foundation, posts, head and cases. A separate
embedded Bound Geometry of approximately 6,000 triangles follows the actual
diagonal/horizontal lattice, including its irregular ends and open gaps. All
colliders use the General preset. The former box-only collision omitted the braces.
The archetype bounds include the full 16-metre mast. The build exports YTYP
after the YDR's temporary LOD switches and a dependency-graph update, so cached
mesh bounds cannot truncate the antenna tip. Validation checks that each
archetype encloses its exported near mesh.

```sh
blender --background --python-exit-code 1 --python assets/cell-towers/build.py -- \
  --inputs /path/to/original-glbs --texconv /path/to/texconv.exe
blender --background --python-exit-code 1 --python assets/cell-towers/validate.py
blender --background --python-exit-code 1 --python assets/cell-towers/render_native.py
```

Use `--cabinet-only` to rebuild the cabinets from the saved blend, or
`--collision-only` to rebuild lattice collision without changing the visible
models. These two modes do not need the original GLB or texconv. `--tower-only`
rebuilds the mast from its GLB and refits the cabinets. All four LODs remain
editable in the blend file. Repeated builds preserve Blender's packed DDS paths.

Texconv is the Microsoft DirectXTex command-line utility. Validation reimports
all four native exports in a fresh Blender process, checking LOD triangle counts,
finite vertices, UV/color layers, packed DDS textures, collision counts/weapon
flags, texture dimensions/mip levels and each archetype's physics dictionary
reference. It records native triangle/vertex counts, bounds and file sizes.
The source DDS files have full mip chains. The GEN8 importer strips compressed
levels below a 4x4 block when extracting DDS images; validation checks native mip
counts separately and compares the retained DDS payload with the source texture.
`native-validation.json` records the exported hashes and results. The lattice
check casts 48,256 rays against reimported visual/collision surfaces on all four
sides: over 95% surface coverage, over 98% clear gaps and under 5 cm distance
error at the 95th percentile. `render_native.py` renders the actual exported
models in closed, open, damaged, whole-mast and side-cabinet views. These are
Blender renders of the native exports, not in-game screenshots.

## Runtime and verification boundary

The server owns door/damage state, inventory consumption, repair permissions,
repair duration, proximity, routing bucket and persistence. Client-simulated
local props report weapon collision; those reports are not independent proof of
a hit from an untrusted client. The server still requires an enabled, configured,
open, healthy tower, a live player in bucket zero, and proximity. GTA object
health is not available through the server entity-health native, and
`weaponDamageEvent` only covers applicable remote-owned targets, so neither is
used as fabricated authority over local props.

Natives were checked against the [official native metadata](https://github.com/citizenfx/natives)
and FiveM source revision
[`e34d12cd9a39cc223548a5be1ab09f60e9183051`](https://github.com/citizenfx/fivem/tree/e34d12cd9a39cc223548a5be1ab09f60e9183051).
That source revision is an inspected snapshot, not a verified match to server
artifact 36897. Reproducible source locations:

- `ext/natives/natives_stash/gta_21E43A33.lua`: object creation, model streaming,
  transforms, freezing/deletion, weapon damage/clearing, health, controls and help
  text native signatures. `HAS_ENTITY_BEEN_DAMAGED_BY_WEAPON(entity, 0, 2)` selects
  any weapon. GTA engine implementations are proprietary.
- `ext/natives/codegen_out_lua.lua` and
  `code/components/citizen-scripting-lua/src/LuaScriptNatives.cpp`
  (`Lua_DoInvokeNative`, `LuaScriptNativeContext::PushArgument`, `ProcessResult`):
  numeric/vector arguments, pointer outputs and Lua native result representation,
  including the OAL path used by this resource.
- `data/shared/citizen/scripting/lua/scheduler.lua` and
  `code/components/citizen-scripting-lua/src/LuaScriptRuntime.cpp`: event handlers,
  coroutine scheduling, `CreateThread`, `Wait` and `SetTimeout`.
- `code/components/citizen-server-impl/src/state/ServerGameState_Scripting.cpp`:
  server ped coordinates/health, player routing buckets and the object-health
  boundary; `code/components/citizen-resources-gta/src/PlayerScriptFunctions.cpp`:
  `GET_PLAYER_PED` registration.
- `code/components/citizen-server-impl/src/ServerKVScriptFunctions.cpp`:
  resource-scoped KVP keys, string serialization and synchronous RocksDB writes.
- `code/components/citizen-server-impl/src/state/ServerGameState.cpp`:
  `weaponDamageEvent` parsing and remote-owner routing.

No prop loops run while disabled. Enabled clients stream nearby assemblies every
500 ms and inspect weapon damage every 100 ms while idle; frame updates are used
only for door motion or nearby interaction/help. No profiler performance claim is
made. Source inspection and offline/browser tests do not prove GTA collision or
CEF behavior; live results must be reported separately.

Focused checks: `tests/cell_tower_props.lua`, `tests/cellular.lua`,
`tests/phone_configurator.lua`, the frontend locale-contract Vitest suite and
`frontend/theme-tests/cell-towers.pw.mjs`.

Live verification on GTA build 3258 / server artifact 36897 confirmed model
streaming, the missing-lockpick and closed-cabinet rejections, consumption of
exactly one lockpick, and door headings of 250 degrees open / 0 degrees closed.
A pistol projectile hit the custom interior, switched to its damaged model and
made an online callback return `no_signal`. Completing the 10-second repair
restored the intact model and closed the door; the same callback then passed the
coverage gate and reached its normal `device_not_open` check. An early repair
completion was rejected. This exercises a representative weapon; it is not an
exhaustive test of every GTA weapon or third-party replacement model.

The collision reproduction exposed two asset-authoring omissions: incomplete
weapon collision flags and an empty YTYP physics dictionary. The exports now use
the General collision preset and reference their embedded physics by drawable
name. A standalone projectile probe confirmed damage before the complete phone
workflow was retested. In the actual CitizenFX 37151 / Chromium 103 CEF runtime,
both current-player and ground-level coordinate callbacks returned successfully.
Browser tests separately cover the English/German controls, loading/error states,
preserved values, company locations and editable customer model settings.

The clean cabinet / lattice-collision revision passed native reimport of all
four models and their four LODs, plus close-up renders from those native files.
The tower YDR is approximately 34.9 MiB on disk; exact sizes and counts are in
`native-validation.json`. After copying all 570 resource files with matching
hashes and restarting the resource, FiveM reported 48 MiB physical and 22.8 MiB
virtual memory for the mast. It still flags the physical allocation as large;
LODs and mipmaps do not establish a frame-time guarantee.

Live probes of freshly loaded copies of the final models passed all 17 lattice
checks: eight diagonal hits, eight clear gaps and a foundation control. Cabinet
probes hit the door at 0 degrees, the intact interior at -110 degrees, and the
door again after closing. Swapping in the damaged interior also produced the
expected hit. Temporary probe resources and objects were removed afterward.
The client retained old collision under the original model name across resource
restarts; a fresh test name loaded the new data correctly. Reconnect after this
asset update to release previously loaded models. This does not require renaming
customer configuration or adding a production cache workaround.
After reconnecting, the same 17 lattice checks, closed/open/closed door checks
and damaged-interior check also passed using the regular `sky_phone_cell_*`
model names. All temporary test objects were removed.

The new models have not repeated the complete lockpick, projectile, repair-item
and network-coverage workflow. The earlier gameplay evidence above applies to
the earlier models. Before this asset-only change, `radiotowerparts` was confirmed
in the active ox_inventory catalogue, and the production NUI build, 1,897 frontend
tests, all 52 browser scenarios and the focused Lua suites passed.

A subsequent live startup exposed two initialization defects: SQL-serialized
float32 heights did not exactly equal the historical decimal defaults, and tower
states were reconciled before the saved configuration finished loading. Legacy
height matching now permits only the sub-millimetre float32 rounding difference;
state initialization and initial client requests wait for configuration readiness.
Regression tests cover both the saved heights and delayed startup with persisted
custom-site damage. After deployment and restart, the live client configuration
and all 18 state keys agreed. The nearest mast, door and intact panel were present
at the new Downtown rooftop, with visible entities and full opacity. This confirms
spawning and synchronization; it does not extend the earlier weapon/repair or
streaming-performance evidence.
