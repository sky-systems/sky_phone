# CFX source map

Checked 2026-09-20 against upstream `citizenfx/fivem`
`0d8a2a6f78a9922445d8930305af82a7b1826980`; this is not a deployed-artifact fingerprint.
For a task, first verify official docs, then the matching implementation/registration/generated
binding and call path. Prefer the deployed revision; record changed assumptions and runtime limits.

| Contract | Official docs | Pinned source / function |
| --- | --- | --- |
| Manifest/context | [Manifest](https://docs.fivem.net/docs/scripting-reference/resource-manifest/resource-manifest/) | [resource_init.lua](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/data/shared/citizen/scripting/resource_init.lua), metadata declarations; [LuaMetaDataLoader.cpp](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/citizen-resources-metadata-lua/src/LuaMetaDataLoader.cpp), separate Lua state/load path |
| Manifest file patterns | Same manifest docs, globbing section | [ResourceMetaDataComponent.cpp](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/citizen-resources-core/src/ResourceMetaDataComponent.cpp), GlobEntries/GlobValue/GlobValueInternal and MatchFiles |
| Events/source | [Listening](https://docs.fivem.net/docs/scripting-manual/working-with-events/listening-for-events/), [RegisterNetEvent](https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/RegisterNetEvent/) | [scheduler.lua](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/data/shared/citizen/scripting/lua/scheduler.lua), SetEventRoutine, RegisterNetEvent, TriggerEvent/TriggerClientEvent/TriggerServerEvent |
| Yield/export | [Await](https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/Citizen.Await), [Wait](https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/Citizen.Wait) | Same scheduler: Citizen.Await and exports metatable; [LuaScriptRuntime.cpp](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/citizen-scripting-lua/src/LuaScriptRuntime.cpp), Lua_Wait/CreateThread |
| Event origin | [Security](https://docs.fivem.net/docs/developers/server-security/), [native declaration](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/ext/native-decls/GetInvokingResource.md) | [ResourceScriptFunctions.cpp](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/citizen-scripting-core/src/ResourceScriptFunctions.cpp), GET_INVOKING_RESOURCE |
| State/OneSync | [State bags](https://docs.fivem.net/docs/scripting-manual/networking/state-bags/), [OneSync](https://docs.fivem.net/docs/scripting-reference/onesync/) | Scheduler NewStateBag; [StateBagComponent.cpp](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/citizen-resources-core/src/StateBagComponent.cpp), SetKey/SetKeyInternal; [StateBagPacketHandler.cpp](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/citizen-server-impl/src/packethandlers/StateBagPacketHandler.cpp), strict-mode checks |
| Server coordinates | [GET_ENTITY_COORDS declaration](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/ext/native-decls/GetEntityCoords.md) | [ServerGameState_Scripting.cpp](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/citizen-server-impl/src/state/ServerGameState_Scripting.cpp), GET_ENTITY_COORDS reads syncTree position |
| Lua vectors | [vector3/vec3](https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/vector3/) | [Pinned Lua constructor registration and implementation](../lua-basics/reference-links.md); `vec3` and `vector3` share glmVec_vec3, not an engine native |

For new natives use the [native reference](https://docs.fivem.net/natives/) and inspect the exact
binding. Proprietary GTA engine internals are not verified by a Cfx wrapper; uncertain behavior
needs a minimal runtime reproduction. Performance claims need representative profiling.

Experimental OAL selection is in [LuaScriptNatives.cpp](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/citizen-scripting-lua/src/LuaScriptNatives.cpp),
Lua_LoadNative; parameter compatibility still requires inspecting the chosen generated binding.

For the state-bag example, scheduler `Entity`/`GetEntityStateBagId`/`NewStateBag` constructs
the entity bag, serializes writes and forwards the explicit replication flag.
[ResourceScriptFunctions.cpp](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/citizen-scripting-core/src/ResourceScriptFunctions.cpp#L340-L393)
registers GET_STATE_BAG_VALUE/SET_STATE_BAG_VALUE and calls GetKey/SetKey; their shared
[read declaration](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/ext/native-decls/GetStateBagValue.md)
and [write declaration](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/ext/native-decls/SetStateBagValue.md)
record argument/return representations. The Lua setter does not forward a native return value.
