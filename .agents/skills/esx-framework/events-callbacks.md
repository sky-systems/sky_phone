# Events and callbacks

Signatures checked at the [pinned revision](reference-links.md); confirm them in the installed
version before editing an adapter. Current implementations delegate to xLib.

| Side | API |
| --- | --- |
| Server registers client request | ESX.RegisterServerCallback(name, handler); compatibility handler receives source, reply callback, then request arguments |
| Client invokes server | ESX.TriggerServerCallback(name, callback, ...) or ESX.AwaitServerCallback(name, ...) |
| Client registers server request | ESX.RegisterClientCallback(name, handler) |
| Server invokes client | ESX.TriggerClientCallback(player, name, callback, ...) or ESX.AwaitClientCallback(player, name, ...) |

Keep callback style and return/await style distinct. Settle the compatibility reply on every
normal rejection/success branch exactly once. Await yields the current scheduler coroutine;
it does not block the entire server. Handle the actual provider's rejection/timeout contract.
Client responses remain untrusted for permissions, prices, rewards and ownership.

For raw network events capture a local copy of source before a yield or delayed callback.
Preserve request-local identity and recheck session ownership if a later action could target a
reconnected player. A callback parameter named source is local already; do not replace it
with a later read of the global. Where AGENTS requires the Sky bridge, retain its Sky.Cb interface.

ESX lifecycle event signatures differ by side and version. Inspect where the event is emitted,
not only where another script happens to listen. Avoid creating a new network entrypoint for
an internal loaded/job-changed notification. SecureNetEvent is a client origin filter, not a
server authorization layer; validate mutations in server-owned services.

[ESX callback implementations and CFX source lifetime evidence](reference-links.md).

## Complete client request and server reply

These direct ESX examples belong in an ESX adapter or standalone resource that actually uses ESX. When the applicable AGENTS requires the Sky bridge, preserve `Sky.Cb`, `Sky.FW` and `Sky_Jobs.PlayerCache` in feature code. Rename `example:` to the resource's own namespace. This read-only example exposes only the caller's view; it is not a purchase authorization.

```lua
-- SERVER: registered once after the established ESX import.
ESX.RegisterServerCallback("example:getSummary", function(src, cb, account_name)
    if account_name ~= "bank" and account_name ~= "money" then
        print("[example] getSummary rejected: unsupported account")
        cb({ ok = false, error = "invalid_account" })
        return
    end

    local x_player = ESX.GetPlayerFromId(src)
    if not x_player then
        print("[example] getSummary rejected: player is not loaded")
        cb({ ok = false, error = "player_not_loaded" })
        return
    end

    local account = x_player.getAccount(account_name)
    if not account then
        print("[example] getSummary rejected: account is not configured")
        cb({ ok = false, error = "account_unavailable" })
        return
    end

    cb({ ok = true, balance = account.money, job = x_player.getJob().name })
end)
```

```lua
-- CLIENT: the function receives the reply, not the immediate return value.
ESX.TriggerServerCallback("example:getSummary", function(result)
    if not result.ok then
        print(("[example] getSummary rejected: %s"):format(result.error))
        return
    end
    print(("[example] bank display updated: %s"):format(result.balance))
end, "bank")
```

For UI use, replace the diagnostic with the existing store update/localized error UI. The same route can be awaited **inside an existing yieldable coroutine**:

```lua
local result = ESX.AwaitServerCallback("example:getSummary", "bank")
if result.ok then
    print(("[example] bank display updated: %s"):format(result.balance))
else
    print(("[example] getSummary rejected: %s"):format(result.error))
end
```

At the pinned revision, ESX delegates to `xLib.callback`/`.await` and `registerCompat`. A compatibility handler must call `cb(...)`; returning a table from the handler alone does not resolve its reply promise. The compatibility wrapper ignores duplicate replies, but the application should still reply exactly once. Await rejects on invalid callbacks/timeouts; handle that actual failure at the owning operation boundary, without translating it into success or adding broad retries. Callback style is asynchronous and does not pause the caller; await yields only that coroutine. Do not assume callback style has the same timeout delivery behavior as await. The configured xLib timeout is not a universal ESX constant.

## Client callbacks are untrusted display data

This example returns a local UI preference, deliberately not an amount, permission or entity authority:

```lua
-- CLIENT: ui_preferences is the existing local presentation state.
ESX.RegisterClientCallback("example:getDisplayMode", function(cb)
    cb({ compact = ui_preferences.compact })
end)
```

```lua
-- SERVER: target_source came from the server's existing interaction/session owner.
ESX.TriggerClientCallback(target_source, "example:getDisplayMode", function(view)
    if type(view) ~= "table" or type(view.compact) ~= "boolean" then
        print("[example] display-mode response rejected: invalid shape")
        return
    end
    print(("[example] client display mode: compact=%s"):format(view.compact))
end)

-- Alternative, inside a yieldable coroutine:
local view = ESX.AwaitClientCallback(target_source, "example:getDisplayMode")
```

The client compatibility handler receives `cb, ...`, without a server-style `source` argument. Validate the awaited result too. A valid shape does not make a client statement trustworthy. Do not use this for economy, ownership, proximity or anti-cheat decisions. When a callback needs an entity, a network ID and a local entity handle are different types; resolve it on the receiving side using verified native contracts. The former example incorrectly passed a network ID to `GetEntityModel` as a handle.

## Client lifecycle events and payloads

The following payloads are traced through the pinned producers/consumers in [the source map](reference-links.md#event-and-restoration-source-details). Other ESX versions or inventory/character providers can differ.

| Event | Current payload and boundary |
|---|---|
| `esx:playerLoaded` | `(player_data, is_new, skin)` from server. The import/core owns `PlayerData`; loading the ped may still be in progress. |
| `esx:onPlayerLogout` | No payload. Clear resource-owned character state and pending view work. |
| `esx:setPlayerData` | Local `(key, value, previous)` from `ESX.SetPlayerData`; imports filter the invoking resource. This is the broad local data-change hook, except the special `loadout` path. |
| `esx:updatePlayerData` | Network `(key, value)` consumed by core, which calls `SetPlayerData`. It is not a notification for every possible client data update. |
| `esx:setJob` | `(job, previous_job)` from the server player class. Core uses the first argument to update its local job view. |
| `esx:setAccountMoney` | `(account_record)` containing `name` and `money`; core updates the accounts array. |
| `esx:addInventoryItem`, `esx:removeInventoryItem` | Default inventory: `(item_name, resulting_total_count, show_notification?)`; not an item record or amount added/removed. Loadout notification paths also use these names with a label, `false` count and `true` notification flag. |
| `esx:onPlayerDeath` | Local death report table; also sent to server by the client and thus untrusted there. `killedByPlayer`, `victimCoords`, `deathCause`; player-kill path adds killer coordinates/distance/server/client IDs. |
| `esx:onPlayerSpawn` | Local hook with no required payload in the inspected core; character/spawn providers own when it is emitted. |
| `esx:playerPedChanged` | Local `(ped)` from the actions module. Invalidate cached entity handles when it changes. |

Subscribe to state changes **and initialize from the already-loaded state**, so restarting a dependent resource works. Avoid writing ESX's own `PlayerData` again in every handler:

```lua
-- CLIENT, after @es_extended/imports.lua. This flag controls presentation only.
local police_view_enabled = false

local function apply_job_view(job)
    local next_enabled = job.name == "police"
    if next_enabled == police_view_enabled then
        return -- Idempotent state transition, not an invalid-state guard.
    end
    police_view_enabled = next_enabled
    print(("[example] police view enabled: %s"):format(next_enabled))
    -- Start/stop this resource's actual view effects here; do not grant server permissions.
end

AddEventHandler("esx:playerLoaded", function(player_data)
    apply_job_view(player_data.job)
end)
AddEventHandler("esx:setJob", apply_job_view)
AddEventHandler("esx:onPlayerLogout", function()
    police_view_enabled = false
    -- Dispose the resource-owned view effects and invalidate pending character requests.
end)

if ESX.IsPlayerLoaded() then
    apply_job_view(ESX.GetPlayerData().job)
end
```

The established import already registers the network ESX lifecycle events. Use `AddEventHandler` for observation; do not expose an internal server notification with `RegisterNetEvent`. If initialization needs a ped, follow the provider's ped-ready lifecycle instead of assuming `playerLoaded` implies collision/model readiness.

```lua
-- CLIENT: observe resulting inventory totals, not fictional deltas.
AddEventHandler("esx:addInventoryItem", function(item_name, total_count, notification_only)
    if type(total_count) == "number" then
        print(("[example] %s total: %s"):format(item_name, total_count))
    end
end)
AddEventHandler("esx:setAccountMoney", function(account)
    print(("[example] account display updated: %s"):format(account.name))
end)
```

## Server lifecycle hooks

| Event | Current payload |
|---|---|
| `esx:playerLoaded` | Local `(player_id, x_player, is_new)` after player creation. |
| `esx:playerDropped` | Local `(player_id, reason)` during ESX cleanup; character logout also uses this cleanup path. |
| `esx:setJob` | Local `(player_id, job, previous_job)`; do not use global `source` as the player ID. |
| `esx:onPlayerJoined` | Framework entrypoint, not a generic connection hook: multichar uses local `(src, char, data)`, non-multichar uses a network event with caller `source`. Do not replay it from features. |

```lua
-- SERVER: per-session cache ownership only; no welcome reward.
local session_jobs = {}
AddEventHandler("esx:playerLoaded", function(player_id, x_player, is_new)
    session_jobs[player_id] = x_player.getJob().name
end)
AddEventHandler("esx:setJob", function(player_id, job, previous_job)
    session_jobs[player_id] = job.name
end)
AddEventHandler("esx:playerDropped", function(player_id, reason)
    session_jobs[player_id] = nil
end)
for _, x_player in ipairs(ESX.GetExtendedPlayers()) do
    session_jobs[x_player.source] = x_player.getJob().name
end
```

Use the resource's existing cache, including `PlayerCache` where required; this illustrates lifecycle ownership, not a new cache requirement. Do not pay rewards merely because a hook ran. Persistent one-time rewards require a server-owned, atomically consumed eligibility record.

## Secure events and ordinary dispatch

`ESX.SecureNetEvent` registers a client net event and rejects the local empty-string `source` at this revision. It is a client origin filter. It cannot make a compromised client's state trusted or protect a server grant by itself.

```lua
-- CLIENT: presentation event only.
ESX.SecureNetEvent("example:status", function(status)
    print(("[example] server status: %s"):format(status))
end)
```

```lua
-- SERVER: all three dispatch forms are valid in their intended context.
x_player.triggerEvent("example:status", "ready")
TriggerClientEvent("example:status", x_player.source, "ready")
ESX.TriggerClientEvent("example:status", { first_source, second_source }, "ready")
```

Use one form for one delivery, not all three together. For a plain client request, register the actual network boundary and derive the actor from `source`:

```lua
-- CLIENT
TriggerServerEvent("example:requestStatus")

-- SERVER
RegisterNetEvent("example:requestStatus", function()
    local src = source
    local x_player = ESX.GetPlayerFromId(src)
    if not x_player then
        print("[example] status request rejected: player is not loaded")
        return
    end
    x_player.triggerEvent("example:status", "ready")
end)
```

An event request/result pair needs correlation when multiple requests can overlap; an existing callback transport already provides it. Neither transport is an authorization mechanism. For mutations, add the action-specific authority/rate/replay checks in the server service; do not copy a generic give-item or unchecked shop endpoint. Use `TriggerEvent` + `AddEventHandler` for local-only notifications.
