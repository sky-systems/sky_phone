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

Press **G** at an open, damaged cabinet to repair it. `Props.RepairJobs = {}`
allows everyone; a nonempty list allows only those framework job names.
`Props.RepairSeconds` defaults to 10. Moving away, dying, losing the required job
or closing the cabinet cancels repair. A successful repair restores coverage and
closes the cabinet. Damage persists in resource KVP storage across restarts;
doors restart closed. Disabling props restores ordinary virtual-tower coverage.

Tower `Coords` is the bottom center of the foundation, not the antenna or player
center. `Heading` rotates the entire assembly. The 18 default sites were measured
against GTA build 3258 terrain, including foundation corners and the four Cayo
Perico sites. Custom map geometry may require adjusting them. Exact old default
positions without a heading migrate automatically; custom positions/ranges and
list ordering remain intact. Position (rounded to 1 mm) identifies a tower;
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

The owner supplied three Meshy models. Input names and SHA-256 hashes are recorded
in `export-report.json`: `tower_textured.glb`, `intact.glb`, `damaged.glb`.
The original multi-million-triangle GLBs are kept outside the repository.
`cell_towers.blend` is the editable source, with packed DDS textures; `textures/`
contains the standalone textures. The exported four YDRs and YTYP live under
`sky_phone/stream/`. Textures are embedded, so no separate YTD is required.

Authoring used Blender 5.2.1 and Sollumz 2.9.0 with its native GEN8 exporter.
`build.py` welds glTF seam vertices before reduction, rebakes diffuse/normal maps,
separates and reorients the door around its hinge, adds four LODs and box
collision using Sollumz's General preset, and exports game assets. Far cabinet
LODs are simple boxes. Each YTYP archetype references its embedded physics data.
The casing collider belongs to the invulnerable mast; only the interior opening
belongs to the damageable panel. Do not combine these collisions.

```sh
blender --background --python-exit-code 1 --python assets/cell-towers/build.py -- \
  --inputs /path/to/original-glbs --texconv /path/to/texconv.exe
blender --background --python-exit-code 1 --python assets/cell-towers/validate.py
```

Texconv is the Microsoft DirectXTex command-line utility. Validation reimports
all four native exports in a fresh Blender process, checking LOD triangle counts,
finite vertices, UV/color layers, packed DDS textures, collision counts/weapon
flags and each archetype's physics dictionary reference.
`native-validation.json` records the exported hashes and results. Previews are
authoring renders, not in-game screenshots.

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
