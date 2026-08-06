# fxmanifest.lua

The resource manifest is a file named `fxmanifest.lua` (or legacy `__resource.lua`) at the root of the resource folder. It runs in a separate Lua runtime and uses semi-declarative syntax.

## Essential entries

| Entry | Description |
|-------|-------------|
| **fx_version** | Use `'cerulean'` (recommended). Alternatives: `'bodacious'`, `'adamant'`. |
| **game** | `'gta5'` (FiveM), `'rdr3'` (RedM), or `'common'` (no game-specific APIs). |
| **author**, **description**, **version** | Optional metadata. |
| **client_scripts** / **server_script** / **shared_scripts** | Arrays or single string. Support globbing. |
| **files** | Files sent to client (e.g. for `data_file` or other assets). |
| **dependency** / **dependencies** | Other resources that must start before this one. |
| **exports** | Client-side export names (Lua). |
| **server_export** | Server-side export names. |

## Scripts

Scripts are Lua (`.lua`). Use **client_scripts**, **server_script**, or **shared_scripts** to load them.

## Globbing

Script entries support glob patterns:

- `'*.lua'` — all Lua in root (non-recursive)
- `'**/*.lua'` — all Lua files recursively
- `'client/cl_*.lua'` — client Lua in `client/` folder

## Minimal example

```lua
fx_version 'cerulean'
game 'gta5'
author 'Your Name'
description 'My resource'
version '1.0.0'

client_scripts { 'client.lua' }
server_script 'server.lua'
```

## Full reference

https://docs.fivem.net/docs/scripting-reference/resource-manifest/resource-manifest/
