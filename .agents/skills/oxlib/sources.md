# ox_lib source map

Checked 2026-09-20 at upstream b8f5a04351b1d427e0e112150d36094e9889ec7b.
Match the installed version before relying on a changing contract.

- [init.lua](https://github.com/overextended/ox_lib/blob/b8f5a04351b1d427e0e112150d36094e9889ec7b/init.lua):
  module loading and execution-side setup.
- [Client callbacks](https://github.com/overextended/ox_lib/blob/b8f5a04351b1d427e0e112150d36094e9889ec7b/imports/callback/client.lua),
  [server callbacks](https://github.com/overextended/ox_lib/blob/b8f5a04351b1d427e0e112150d36094e9889ec7b/imports/callback/server.lua):
  eventTimer, pending callbacks, timeouts and Citizen.Await.
- [Commands](https://github.com/overextended/ox_lib/blob/b8f5a04351b1d427e0e112150d36094e9889ec7b/imports/addCommand/server.lua):
  argument parsing and lib.addCommand.
- [Zones](https://github.com/overextended/ox_lib/blob/b8f5a04351b1d427e0e112150d36094e9889ec7b/imports/zones/shared.lua):
  execution-side tracking, geometry and removal.
- [Client interface implementations](https://github.com/overextended/ox_lib/tree/b8f5a04351b1d427e0e112150d36094e9889ec7b/resource/interface/client):
  alert.lua, input.lua, notify.lua, progress.lua, context.lua, menu.lua, textui.lua, skillcheck.lua.
  Alert close with a reason rejects its promise; input cancellation resolves nil.
- CFX [Await docs](https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/Citizen.Await)
  and [event source lifetime](https://docs.fivem.net/docs/scripting-manual/working-with-events/listening-for-events/);
  [scheduler.lua](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/data/shared/citizen/scripting/lua/scheduler.lua)
  at 0d8a2a6f78a9922445d8930305af82a7b1826980, Citizen.Await/SetEventRoutine.

Use the [current docs index](https://overextended.dev/docs/ox_lib) for unlisted APIs. Verify
each relevant CFX native's docs and registration/binding/source path separately; a provider
wrapper is not proof of proprietary engine behavior. Report source/build/runtime evidence distinctly.

## Additional lookup routes

- `lib.addKeybind(data)`: [client docs](https://overextended.dev/docs/ox_lib/AddKeybind/Client),
  [pinned registration](https://github.com/overextended/ox_lib/blob/b8f5a04351b1d427e0e112150d36094e9889ec7b/imports/addKeybind/client.lua).
  Inspect registered names, localized descriptions and press/release lifecycle before adding
  a competing handler. Follow the resource's existing input owner.
- `lib.getNearbyVehicles(coords, maxDistance, includePlayerVehicle)`:
  [Lua shared docs](https://overextended.dev/docs/ox_lib/GetNearbyVehicles/Lua/Shared),
  [pinned implementation](https://github.com/overextended/ox_lib/blob/b8f5a04351b1d427e0e112150d36094e9889ec7b/imports/getNearbyVehicles/shared.lua).
  Returns records containing `vehicle` handles and `coords`; client-local entity handles
  are not server handles or network IDs. A client reply cannot authorize deletion/ownership.
- Lua `vec3`/`vector3` in the shape examples: [CFX vector docs and pinned constructor map](../fivem-basics/reference-links.md).
