# ESX source map

Checked 2026-09-20 against ESX fe59ca0bd6da59e2ec6eb4a8d06ece312e96ae7a.
This is an inspected upstream revision, not a promise about the installed server.

- [Official ESX docs](https://docs.esx-framework.org/): locate the current page for the exact
  method/version. Some deep links were unavailable during the audit; a failed fetch does not
  confirm a contract.
- [imports.lua](https://github.com/esx-framework/esx_core/blob/fe59ca0bd6da59e2ec6eb4a8d06ece312e96ae7a/%5Bcore%5D/es_extended/imports.lua):
  shared object and PlayerData lifecycle.
- [Client functions](https://github.com/esx-framework/esx_core/blob/fe59ca0bd6da59e2ec6eb4a8d06ece312e96ae7a/%5Bcore%5D/es_extended/client/functions.lua):
  IsPlayerLoaded, GetPlayerData, SecureNetEvent.
- [Server functions](https://github.com/esx-framework/esx_core/blob/fe59ca0bd6da59e2ec6eb4a8d06ece312e96ae7a/%5Bcore%5D/es_extended/server/functions.lua):
  player lookups, filters and provider registration.
- [Player class](https://github.com/esx-framework/esx_core/blob/fe59ca0bd6da59e2ec6eb4a8d06ece312e96ae7a/%5Bcore%5D/es_extended/server/classes/player.lua):
  account/inventory/job/metadata methods; inspect active overrides as well.
- [Server callback adapter](https://github.com/esx-framework/esx_core/blob/fe59ca0bd6da59e2ec6eb4a8d06ece312e96ae7a/%5Bcore%5D/es_extended/server/modules/callback.lua),
  [client callback adapter](https://github.com/esx-framework/esx_core/blob/fe59ca0bd6da59e2ec6eb4a8d06ece312e96ae7a/%5Bcore%5D/es_extended/client/modules/callback.lua):
  current ESX-to-xLib argument mapping; [xLib server compatibility handler](https://github.com/esx-framework/esx_core/blob/fe59ca0bd6da59e2ec6eb4a8d06ece312e96ae7a/%5Bcore%5D/esx_lib/imports/callback/server.lua),
  registerCompat maps source/reply/request arguments. Recheck the installed handler for replies.
- CFX [event source docs](https://docs.fivem.net/docs/scripting-manual/working-with-events/listening-for-events/)
  and [Await docs](https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/Citizen.Await);
  [scheduler.lua](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/data/shared/citizen/scripting/lua/scheduler.lua)
  at 0d8a2a6f78a9922445d8930305af82a7b1826980, SetEventRoutine/Citizen.Await.

For additional CFX/native use verify official signature/context, then matching registration,
binding and implementation; record SHA/function, yield/RPC semantics and unavailable engine limits.
A wrapper inspection or build does not prove live gameplay or performance.

## Event and restoration source details

The semantic restoration checked the following **same pinned ESX revision**, not an unidentified installed server:

| Source | Relevant contract |
|---|---|
| [client callback module](https://github.com/esx-framework/esx_core/blob/fe59ca0bd6da59e2ec6eb4a8d06ece312e96ae7a/%5Bcore%5D/esx_lib/imports/callback/client.lua) and [server callback module](https://github.com/esx-framework/esx_core/blob/fe59ca0bd6da59e2ec6eb4a8d06ece312e96ae7a/%5Bcore%5D/esx_lib/imports/callback/server.lua), `registerCompat`, trigger helpers | Client compatibility handler `(reply, ...)`, server `(source, reply, ...)`; explicit reply resolves promise; await invalid/timeout rejection; owner-stop cleanup |
| [server/main.lua](https://github.com/esx-framework/esx_core/blob/fe59ca0bd6da59e2ec6eb4a8d06ece312e96ae7a/%5Bcore%5D/es_extended/server/main.lua), `loadESXPlayer`, `onPlayerDropped`, join/logout hooks | Serialized PlayerData, local versus client playerLoaded payload, multichar join distinction, dropped/logout lifecycle, pickup types |
| [client/modules/events.lua](https://github.com/esx-framework/esx_core/blob/fe59ca0bd6da59e2ec6eb4a8d06ece312e96ae7a/%5Bcore%5D/es_extended/client/modules/events.lua) | playerLoaded/spawn progression, inventory/account/job consumers, updatePlayerData → SetPlayerData |
| [client/modules/actions.lua](https://github.com/esx-framework/esx_core/blob/fe59ca0bd6da59e2ec6eb4a8d06ece312e96ae7a/%5Bcore%5D/es_extended/client/modules/actions.lua), [death.lua](https://github.com/esx-framework/esx_core/blob/fe59ca0bd6da59e2ec6eb4a8d06ece312e96ae7a/%5Bcore%5D/es_extended/client/modules/death.lua) | `esx:playerPedChanged(ped)` producer; death payload fields and client-to-server trust boundary |
| [client/functions.lua](https://github.com/esx-framework/esx_core/blob/fe59ca0bd6da59e2ec6eb4a8d06ece312e96ae7a/%5Bcore%5D/es_extended/client/functions.lua), SearchInventory, SpawnPlayer, SetPlayerData, HashString, GetVehicleTypeClient | Search mutates supplied item list; count result shape; `(skin, coords, cb)` spawn; local data event; input token and vehicle category |
| [client/compat.lua](https://github.com/esx-framework/esx_core/blob/fe59ca0bd6da59e2ec6eb4a8d06ece312e96ae7a/%5Bcore%5D/es_extended/client/compat.lua#L60) | RegisterInput maps to xLib.addKeybind fields |
| [server/functions.lua](https://github.com/esx-framework/esx_core/blob/fe59ca0bd6da59e2ec6eb4a8d06ece312e96ae7a/%5Bcore%5D/es_extended/server/functions.lua), RegisterCommand, GetExtendedPlayers/GetNumPlayers, GetIdentifier, GetVehicleType, GetJobs, item/override registration, Core.SavePlayer | Typed command arguments; grouped/minimal selection; identifier prefix removal; client-derived vehicle cache; catalogue/readiness; metadata save path |
| [server/modules/createJob.lua](https://github.com/esx-framework/esx_core/blob/fe59ca0bd6da59e2ec6eb4a8d06ece312e96ae7a/%5Bcore%5D/es_extended/server/modules/createJob.lua) | CreateJob fourth jobType argument, transaction and existing-grade behavior |
| [server/classes/player.lua](https://github.com/esx-framework/esx_core/blob/fe59ca0bd6da59e2ec6eb4a8d06ece312e96ae7a/%5Bcore%5D/es_extended/server/classes/player.lua), CreateExtendedPlayer and bound methods | Full arrays/minimal maps; getWeapon two returns; heading option; money/item/weapon result differences; setMeta truthiness overload; all override factories applied at construction |

For `getPlayTime`, Cfx [GET_PLAYER_TIME_ONLINE declaration](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/ext/native-decls/GetPlayerTimeOnline.md) specifies server string source → integer seconds; [PlayerScriptFunctions.cpp](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/citizen-server-impl/src/PlayerScriptFunctions.cpp#L280) returns `Client::GetSecondsOnline()`. Event/command/source primitives additionally use [ResourceScriptFunctions.cpp](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/citizen-scripting-core/src/ResourceScriptFunctions.cpp), [ResourceEventComponent.cpp](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/citizen-resources-core/src/ResourceEventComponent.cpp) and the scheduler/binding path above. Framework wrappers that invoke proprietary engine natives are not evidence of their in-game effects.
