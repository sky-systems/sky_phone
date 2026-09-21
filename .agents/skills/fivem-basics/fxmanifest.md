# Resource manifest

Use `fxmanifest.lua` with the resource's supported `fx_version` and `game`; current standard
resources use `cerulean`. The manifest runs separately from resource scripts. An import's
position matters: load a provider's initializer before scripts that consume its API.
When inspecting older resources, recognize the legacy `__resource.lua` filename and older
`adamant`/`bodacious` FX versions; do not change their compatibility behavior as a cosmetic edit.

- `client_script(s)`: client code, included in the resource download.
- `server_script(s)`: server code.
- `shared_script(s)`: executed on both sides and downloaded by clients.
- `files`: additional downloadable assets; include the NUI entry and its built assets.
- `ui_page`: NUI entry; preserve the actual build output path.
- `dependency`/`dependencies`: required resources and supported runtime constraints.

Script loaders also support JavaScript and .NET; do not describe every script as Lua.
Use explicit ordering where files depend on one another rather than assuming glob order.
Do not add `lua54 'yes'` to new manifests: current docs mark it deprecated because Lua 5.4
is the default. Older deployed artifacts still require checking their actual compatibility.
Enable experimental runtime options only for a justified, tested change; OAL changes native
argument behavior, including vector unpacking.

## Minimal manifest and file patterns

For a new standalone Lua example, the manifest can be:

```lua
fx_version "cerulean"
game "gta5"

author "Example author"
description "Example resource"
version "1.0.0"

shared_script "shared/config.lua"
client_scripts {
    "client/state.lua",
    "client/main.lua"
}
server_script "server/main.lua"
```

The metadata fields are optional. `game "gta5"` selects FiveM; `rdr3` selects RedM;
`common` permits CFX APIs without a game-specific API set. Singular declarations take a
string; plural forms expand a table into individual metadata entries. Existing resources
still require their own provider imports, dependencies and package paths; this is not a
replacement for their manifests. Manifest exports are covered in [exports](exports.md).

Script declarations support globbing:

| Pattern | Intended matches |
| --- | --- |
| `*.lua` | Lua files directly in the resource root |
| `client/cl_*.lua` | Matching files directly in `client` |
| `**/*.lua` | Lua matches recursively, including the root |

Use globs for independent files. Keep ordered imports explicit when one file initializes
symbols consumed by the next, and avoid a broad recursive glob that loads server code on
the client. A `dependency "provider_resource"` orders resource startup; it does not await
an asynchronous database load inside that provider.

Follow the applicable resource's build/copy launchers and canonical package paths.
[Official manifest docs](https://docs.fivem.net/docs/scripting-reference/resource-manifest/resource-manifest/)
and the [pinned loader/runtime map](reference-links.md) are the verification starting points.
