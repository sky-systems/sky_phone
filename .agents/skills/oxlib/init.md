# init — Adding ox_lib to a resource

Add ox_lib as a shared script so `lib` (and optionally `cache`, `require`) are available in client and server.

**fxmanifest.lua**

```lua
fx_version 'cerulean'
game 'gta5'

shared_scripts {
  '@ox_lib/init.lua',
}
-- Or if it's the only shared script:
-- shared_script '@ox_lib/init.lua'

client_scripts { 'client.lua' }
server_scripts { 'server.lua' }
```

Optional: preload specific modules so they are available without `lib.require()`:

```lua
ox_libs {
  'locale',
  'callback',
  'math',
  'table',
}
```

Modules can also be loaded dynamically with `lib.require('callback')` or by calling `lib.callback`, `lib.notify`, etc. (ox_lib loads them on first use).

Ensure the resource `ox_lib` is started before your resource (e.g. in server.cfg or `ensure ox_lib`).
