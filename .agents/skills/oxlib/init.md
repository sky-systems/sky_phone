# Setup and scope

Import @ox_lib/init.lua as a shared_script before consumers in fxmanifest.lua. Declare/order
the actual dependency according to the resource's manifest. This adds lib, cache and a require
mechanism; inspect the installed initializer when resolving module-loading issues.

lib dynamically loads library modules. require imports modules and is not interchangeable
with inventing a lib.require("callback") call. Optional ox_libs metadata preloads named modules
supported by that version; add only those the resource needs.

Client/server/shared availability is module-specific. A shared initializer does not make every
UI function callable on the server. Likewise, Lua and JavaScript packages do not guarantee
identical APIs. Inspect the execution-side implementation before choosing an export/import.
Do not silently change server configuration or install a second library to fix a caller contract.

[Setup docs](https://overextended.dev/docs/ox_lib) and [pinned init.lua](sources.md).

## Minimal direct integration

For a resource that owns a direct ox_lib integration, its `fxmanifest.lua` can contain:

```lua
fx_version "cerulean"
game "gta5"

shared_script "@ox_lib/init.lua"
client_script "client.lua"
server_script "server.lua"
dependency "ox_lib"

-- Optional: preload locale when this resource uses locale(...).
ox_libs { "locale" }
```

Start `ox_lib` before the consumer (`ensure ox_lib`, then `ensure your_resource`). Merge
these declarations into the existing manifest; preserve configuration/import order. An
`ox_libs` entry names a supported module, whereas `require` loads a Lua module by its own
contract. Calling a supported `lib` method loads that library module on demand.
