# Initialization and lifecycle

Inspect fxmanifest.lua, imports and resource start order before changing initialization.
Current ESX imports obtain the shared object through the es_extended getSharedObject export.
Use the installed import contract rather than adding legacy polling/getSharedObject network
events. When AGENTS requires the Sky bridge, use its existing framework initialization.

Client PlayerData is a local view, not the server player object or a permission authority.
Inspect the actual serialized shape; do not assume inventories/accounts are always keyed maps
or every optional field exists. Distinguish login, character selection, player-loaded, job
change, logout and disconnect. A resource can start after the player is already loaded.
Initialize from current state and subscribe to the relevant installed-version lifecycle once.

Avoid duplicating ESX import handlers that already maintain PlayerData. Recreating caches by
blindly assigning event payloads can lose updates or retain old character data. Keep entity,
job and player caches invalidated through their owners; do not freeze values at startup.
The exact event names and payloads must come from the installed producer and consumer.

[ESX imports and core source](reference-links.md).

## Established import and script layout

For a direct ESX resource, the installed import is loaded before scripts that use its global. Keep the actual resource's dependency layout; this is not a Sky feature manifest:

```lua
-- fxmanifest.lua fragment
shared_script "@es_extended/imports.lua"
dependency "es_extended"
client_script "client.lua"
server_script "server.lua"
```

If the adapter intentionally uses only the export, its established initialization may instead be:

```lua
local ESX = exports["es_extended"]:getSharedObject()
```

An export alone does not install every per-resource lifecycle handler in `imports.lua`. Preserve the current import choice rather than combining imports, export polling and legacy `esx:getSharedObject` events. An ESX object being available does not imply that the player/character or every DB-backed job catalogue has finished loading. `ESX.GetJobs()` has its own readiness wait at the pinned revision.

Typical concerns remain separate: manifest/imports; client presentation and input; server authority/persistence; shared data definitions; configuration; locales; generated NUI. Keep real loaders and filenames instead of imposing a new generic directory tree.

## PlayerData and xPlayer shape

The following is a **shape sketch**, not an assignment to copy over live ESX data:

```lua
-- CLIENT view: fields depend on core, character and inventory providers.
local player_view = {
    job = { name = "police", grade = 0, onDuty = true },
    accounts = { { name = "bank", money = 5000 }, { name = "money", money = 100 } },
    inventory = { { name = "bread", count = 2, weight = 1 } },
    loadout = { { name = "WEAPON_PISTOL", ammo = 12, components = {} } },
    metadata = {},
    variables = {}
}
```

Full account/inventory/loadout values are arrays in default ESX. Minimal server getters produce maps. Use `GetAccount`/`getAccount` for a named account rather than assuming `accounts.bank.money`. Coordinates may be computed by the import metatable rather than a permanently current stored field. Identity, name/firstName/lastName, SSN, license, group, ped, playerId/source, weight/maxWeight, dead/skin and other optional character fields must be read from the installed serialization path; do not invent a universal complete `PlayerData` record or SSN/identifier format.

```lua
-- SERVER: xPlayer is a live framework object, not the serialized client table.
local x_player = ESX.GetPlayerFromId(player_id)
if not x_player then
    print("[example] player lookup failed: player is not loaded")
    return
end
local job = x_player.getJob()
local bank = x_player.getAccount("bank")
```

Default bound methods use `x_player.method(...)`, not an added colon. Treat a source as an online session, and use the actual character identifier for durable data. See [server lookup](server-functions.md#player-selection-examples) and [player methods](xplayer-methods.md).

## Startup and changes

Use [the complete client and server lifecycle examples](events-callbacks.md#client-lifecycle-events-and-payloads): subscribe once, initialize from current state when already loaded, invalidate on logout/disconnect, and refresh job/ped views when their owner changes them. Do not start permanent per-frame loops merely to wait for ESX, freeze the initial job, or duplicate import handlers. Resource-start, player-load and ped-ready are separate conditions.
