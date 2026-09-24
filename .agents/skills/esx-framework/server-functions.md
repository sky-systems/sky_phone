# Server lookup and service boundaries

Verified at the [inspected ESX revision](reference-links.md):

| Operation | Contract to preserve |
| --- | --- |
| ESX.GetPlayerFromId(source) | Current xPlayer or nil; a source is an online session, not durable character identity |
| ESX.GetPlayerFromIdentifier(identifier) | Current indexed player or nil; use the identifier format owned by the installed character system |
| ESX.GetExtendedPlayers(key, value, minimal) | Optional filters can change grouping; minimal returns sources instead of player objects |
| ESX.RegisterServerCallback(name, handler) | Remote request boundary; see [callbacks](events-callbacks.md) |

An online lookup is not an offline player API. Do not guess a character prefix from a license
or coerce a durable identifier to a numeric source. Where AGENTS requires Sky job APIs, use
PlayerCache for identity/job/duty rather than importing these lookups into feature code.

For commands, usable items, jobs, pickups and society money, trace the registered service and
provider first. Verify permissions, target/account/item validity, capacity and bounded quantities
before mutation. A typed command argument does not prove a positive integer or entitlement.
Keep player lookups close to the operation and revalidate after yielding when the session can change.

Do not write directly to framework tables while a provider owns the state; its cache/save path
may overwrite the DB or diverge. Inspect overrides and persistence hooks before designing a fix.

## Player selection examples

The following code belongs in the existing direct ESX adapter/resource. All lookups are online; they do not fetch offline characters.

```lua
local x_player = ESX.GetPlayerFromId(player_id)
local by_identifier = ESX.GetPlayerFromIdentifier(character_identifier)
local officers = ESX.GetExtendedPlayers("job", "police")
for _, officer in ipairs(officers) do
    print(("[example] online police source: %s"):format(officer.source))
end

local officer_ids = ESX.GetExtendedPlayers("job", "police", true)
local groups = ESX.GetExtendedPlayers("job", { "police", "ambulance" })
for job_name, players in pairs(groups) do
    print(("[example] %s count: %s"):format(job_name, #players))
end
local all_players = ESX.GetExtendedPlayers()
local police_count = ESX.GetNumPlayers("job", "police")
local counts = ESX.GetNumPlayers("job", { "police", "ambulance" })
local connected_count = ESX.GetNumPlayers()
```

Table filters return grouped results, not one flat list. `minimal=true` returns sources. Unfiltered `GetNumPlayers()` uses connected players, while `GetExtendedPlayers()` enumerates loaded ESX objects; counts can differ during initialization. The helper's convenient filter is not proof of better asymptotic/runtime performance; inspect and profile the relevant path.

`ESX.GetIdentifier(player_id)` resolves the configured FiveM identifier type and strips that type prefix in the pinned core. It is **not** a universal `char1:license:...` generator; multichar builds the character identifier separately. `x_player.getIdentifier()` returns the actual character identifier on that object. Never reconstruct one by guessing a prefix.

## Commands with typed arguments

`ESX.RegisterCommand(name, group, handler, allow_console?, suggestion?)` registers permissions through ACE. `name` and `group` may be strings or lists. The handler receives `(x_player_or_false, named_args, show_error)`; console has no player object.

```lua
-- Read-only example. labels contains the resource's localized command text.
ESX.RegisterCommand("example_jobcount", "admin", function(x_player, args, show_error)
    local jobs = ESX.GetJobs()
    if not jobs[args.job] then
        show_error(labels.invalid_job)
        return
    end
    print(("[example] %s online: %s"):format(args.job, ESX.GetNumPlayers("job", args.job)))
end, true, {
    help = labels.job_count,
    validate = true,
    arguments = { { name = "job", help = labels.job_name, type = "string" } }
})
```

| Argument type | Pinned parser result |
|---|---|
| `number` | Numeric conversion, without an automatic positive/integer/range guarantee |
| `player` | Current target xPlayer; supports `me` |
| `playerId` | Current numeric target source; supports `me` |
| `string` | Text rejected if it parses as a number |
| `item`, `weapon` | Validated item/weapon name; weapon uppercased |
| `any` | Raw token |
| `merge` | Remaining tokens joined as text |
| `coordinate` | Numeric coordinate extraction |

`suggestion.validate=true` checks argument count. A per-argument `Validator = { validate = function(value) ... end, err = localized_error }` can enforce additional constraints in the pinned version. Inspect installed compatibility before using it. Typed parsing and admin permission still do not substitute for action-specific targets, bounded quantities and server-owned authority.

## Jobs and items

```lua
for job_name, job in pairs(ESX.GetJobs()) do
    for grade_key, grade in pairs(job.grades) do
        print(("[example] %s grade %s salary %s"):format(job_name, grade_key, grade.salary))
    end
end
local exists = ESX.DoesJobExist("police", 4)
local items = ESX.GetItems()
local label = ESX.GetItemLabel("bread") -- nil/logged warning if unknown
local usable = ESX.GetUsableItems() -- map of name -> true
```

| API | Options and effects |
|---|---|
| `ESX.GetJobs(job_type?)` | Waits for job catalogue readiness; optional type string/list filters the job map |
| `ESX.CreateJob(name, label, grades, job_type?)` | SQL-backed creation/missing-grade insertion; default type `civ`; boolean success, can yield. Existing-job behavior is version-specific. |
| `ESX.RefreshJobs()` | Reloads DB job definitions and updates the provider's job/cache lifecycle |
| `ESX.AddItems(items)` | Default inventory only; entries use `name`, `label`, optional `weight`, `rare`, `canRemove` |
| `ESX.RefreshItems()` | Default inventory only; reloads catalogue and online inventories; returns loaded count at this revision |
| `ESX.RegisterUsableItem(name, handler)` | Registers handler `(source, item, ...)`; does not itself consume an item |
| `ESX.UseItem(source, item, ...)` | Invokes registered callback if catalogue/handler exist; not a complete ownership or transaction guard |

Example migration-time definitions, only when the resource owns the requested catalogue change:

```lua
local created = ESX.CreateJob("example_baker", localized_job_label, {
    { grade = 0, name = "apprentice", label = localized_grade_label, salary = 320 }
}, "civ")

ESX.AddItems({
    { name = "example_leaflet", label = localized_item_label, weight = 1, rare = false, canRemove = true }
})
```

These are persistent operations, not startup boilerplate to run blindly. Follow the installed provider's migration and readiness path. An external inventory uses its own item catalogue and registration contracts.

```lua
-- Default inventory, non-consuming display item. The item must exist in the catalogue.
ESX.RegisterUsableItem("example_leaflet", function(src)
    local x_player = ESX.GetPlayerFromId(src)
    if not x_player then
        print("[example] item use rejected: player is not loaded")
        return
    end
    local item = x_player.getInventoryItem("example_leaflet")
    if not item or item.count < 1 then
        print("[example] item use rejected: player does not own the leaflet")
        return
    end
    x_player.triggerEvent("example:openLeaflet")
end)
```

For consumables, validate/serialize the operation and inspect the removal result before the effect. Do not copy the old unchecked food/reward sample into a server endpoint.

## Vehicles, pickups and dispatch

```lua
ESX.GetVehicleType("t20", target_source, function(vehicle_type)
    print(("[example] client-reported vehicle type: %s"):format(vehicle_type))
end)
-- Alternative in a yieldable coroutine:
local vehicle_type = ESX.GetVehicleType("t20", target_source)
```

The server helper uses a model cache and, on a cache miss, asks the client through `esx:GetVehicleType` (case-sensitive). Do not treat that client result as security authority. The callback form returns asynchronously; the no-callback form can yield. See [client callback boundaries](events-callbacks.md#client-callbacks-are-untrusted-display-data).

Default-inventory `ESX.CreatePickup(item_type, name, count, label, player_id, components?, tint_index?, coords?)` records a pickup and broadcasts it. The matching core paths use `item_standard`, **`item_account`** and `item_weapon`; the old `item_money` example was incorrect. Calling CreatePickup does not remove the original item/account/loadout. The server owner must perform exactly one validated transfer into the pickup lifecycle and prevent duplication. Preserve weapon components/tint and position, and use external inventory drops when that provider owns inventory.

For dispatch, use `x_player.triggerEvent(name, ...)`, CFX `TriggerClientEvent(name, source, ...)`, or `ESX.TriggerClientEvent(name, source_or_source_list, ...)`. Complete examples are in [events and callbacks](events-callbacks.md#secure-events-and-ordinary-dispatch).

## Logging and player overrides

`ESX.Trace(message)` is conditional on the configured debug setting; it is not suitable as the only required failure log. `ESX.DiscordLog(webhook_name, title, color, message)` and `ESX.DiscordLogFields(webhook_name, title, color, fields)` use configured webhook/color keys. Field records contain `name`, `value`, optional `inline`. Keep secrets/personal data out and use only the resource's authorized logging design. Documentation examples do not authorize posting to Discord.

At the pinned revision, `ESX.RegisterPlayerFunctionOverrides(index, overrides)` stores **factories** used while creating a player. Each `factory(self)` must return the callable method:

```lua
ESX.RegisterPlayerFunctionOverrides("example_methods", {
    getDutySummary = function(self)
        return function()
            local job = self.getJob()
            return { name = job.name, onDuty = job.onDuty }
        end
    end
})
```

Do not add such a method when the existing `getJob()`/bridge already meets the need; the example documents the factory shape. The pinned class iterates all registered override sets at construction. `ESX.SetPlayerFunctionOverride(index)` sets configuration after validating the name, but this does **not** prove exclusive switching or retroactive replacement on already-created players. Trace the installed constructor and active inventory adapter before using either API. The original factory returning `table.contains(...)` would have installed a boolean, not an `xPlayer.isLeo()` function.
