# Player methods and provider contracts

Read the installed player implementation and active overrides before using a method. Default
ESX inventory, an external inventory and custom xPlayer overrides can have different shapes,
side effects and return values. The [source map](reference-links.md) links the inspected class.

- getAccount(name) returns the matching account record or nil at the inspected revision;
  the balance is a field of that record. getAccounts(minimal) changes representation.
- Money/item mutations need a server-owned reason/operation, positive bounded quantities,
  authorized accounts and a defined failure path. Do not infer success from a successful pcall.
  Inspect false/nil/void/success semantics on the installed method and adapter; read post-state
  for void writes when the result matters.
- Capacity or balance checks alone do not make a later mutation atomic. Serialize the operation
  through the established owner and prevent repeat grants, especially across provider awaits.
- Default canCarryItem/inventory methods do not prove a replacement inventory supports
  the same metadata, slots, nesting or return contract. Verify that provider version separately.
- Default loadout methods and inventory weapons are distinct models. Do not run both grants
  for one weapon or assume removing an inventory item also updates a default ESX loadout.
- Job changes have grade/duty and event/cache effects. Where AGENTS requires Sky job APIs,
  read PlayerCache and change state through the documented bridge and existing update lifecycle.
- get/set variables and metadata methods do not automatically have identical persistence
  semantics. Inspect getMeta, setMeta, clearMeta overloads and the actual save path.
  Preserve nested values and false values; avoid replacing an entire record for one field.

Use the method's documented calling form; many xPlayer functions are bound closures called as
x_player.method(...). Do not add a colon and shift arguments without checking its definition.
Cache a resolved object within a valid operation, not indefinitely across logout/disconnect.

## Identity, position, job and permissions

All examples below assume the server has resolved the current player through the established adapter and authorized the operation. Do not paste mutation calls into an unrestricted event. When AGENTS requires the Sky bridge, keep `Sky.FW` for framework operations and `Sky_Jobs.PlayerCache` for name/job/duty reads.

| Method | Pinned default contract |
|---|---|
| `getName()`, `setName(name)` | Name getter/setter; setter also updates the name state bag |
| `getIdentifier()`, `getSSN()` | Existing character identifier/SSN; no fixed formatting guarantee |
| `getSource()` / `getPlayerId()` | Online numeric source |
| `getCoords(vector?, heading?)` | Current server ped coordinates: table by default, vector3 with `true`, vector4 with `true,true`; heading appears only when requested |
| `setCoords(coordinates)` | Reads `x,y,z` and `w` or `heading` (defaults heading to zero); calls server natives |
| `getJob()` | Job record including `name`, `label`, `type`, grade fields and `onDuty` |
| `setJob(name, grade, on_duty?)` | Validates job/grade, applies default duty when omitted, forces unemployed off duty, updates metadata/state bag and emits job events |
| `getGroup()`, `setGroup(group)` | Group getter/setter; setter changes ACE principals and emits group events |
| `togglePaycheck(enabled)`, `isPaycheckEnabled()` | Boolean paycheck setting/query |
| `kick(reason)` | Disconnects this player; requires an authorized moderation action |

```lua
local coords = x_player.getCoords(false, true)
print(("[example] heading: %s"):format(coords.heading))
local position = x_player.getCoords(true)
local position_and_heading = x_player.getCoords(true, true)

-- Server-selected destination inside an authorized teleport flow.
x_player.setCoords({ x = 100.0, y = 200.0, z = 50.0, heading = 90.0 })

if ESX.DoesJobExist(server_job_name, server_grade) then
    x_player.setJob(server_job_name, server_grade, false)
else
    print("[example] job change rejected: unknown job or grade")
end
```

Coordinate methods are live wrappers, not a promise that every engine/RPC action has completed. Their Cfx/native path and runtime availability still need target verification. Client-supplied destination/job/group values are not automatically authorized.

## Money and account representation

```lua
local cash = x_player.getMoney()
local bank = x_player.getAccount("bank") -- record or nil
for _, account in ipairs(x_player.getAccounts()) do
    print(("[example] configured account: %s"):format(account.name))
end
local amounts = x_player.getAccounts(true) -- map name -> amount
local bank_amount = amounts.bank
```

Full accounts are an array, not `accounts.bank.money`. Account names come from server configuration. `getAccount` compares names case-insensitively at this revision.

| Mutation | Parameters |
|---|---|
| `addMoney`, `removeMoney` | `(amount, reason?)`, cash-account wrappers |
| `setMoney` | `(amount)`, exact cash balance |
| `addAccountMoney`, `removeAccountMoney`, `setAccountMoney` | `(account_name, amount, reason?)` |

```lua
-- Within an already-authorized, serialized server operation; amount/reason are server-owned.
local account = x_player.getAccount("bank")
if not account or type(amount) ~= "number" or not (amount > 0 and amount <= 1000000)
    or amount % 1 ~= 0 or account.money < amount then
    print("[example] debit rejected: invalid account, amount or available balance")
    return
end
local removed = x_player.removeAccountMoney("bank", amount, server_reason)
if not removed then
    error("[example] provider did not confirm the authorized debit")
end
```

This covers a single debit, not a complete transfer or purchase. The pinned default money mutators return `true` after changing state and can throw on invalid input; provider overrides may differ. Default removal does not supply a general insufficient-funds transaction guard. Recheck the active provider, bounds/rounding, serialization, operation identity and multi-step compensation/transaction policy. Never regard `pcall` success as proof that a provider accepted a debit.

## Default inventory and capacity

```lua
for _, item in ipairs(x_player.getInventory()) do
    print(("[example] %s count=%s weight=%s"):format(item.name, item.count, item.weight))
end
local positive_counts = x_player.getInventory(true) -- map; zero-count items omitted
local bread = x_player.getInventoryItem("bread") -- record or nil
local owned_item, owned_count = x_player.hasItem("bread") -- item/count, or false
local current_weight = x_player.getWeight()
local capacity = x_player.getMaxWeight()
```

| Method | Meaning / result edge case |
|---|---|
| `addInventoryItem(item, count)` | Adds/rounds count and weight; true/false at pinned default. It does not itself perform a capacity check. |
| `removeInventoryItem(item, count)` | Requires positive count and sufficient existing count; true/false or invalid-input error |
| `setInventoryItem(item, count)` | Exact nonnegative count; returns nil for already-equal state, delegated mutation result otherwise, false for rejected state |
| `canCarryItem(item, count)` | Capacity predicate, not entitlement or reservation |
| `canSwapItem(first_item, first_count, second_item, second_count)` | Checks default inventory count/weight feasibility; it performs no transfer |
| `setMaxWeight(weight)` | Updates max weight and sends the client update; use the provider's unit |

```lua
-- In an authorized operation with a validated positive integer quantity.
if not x_player.canCarryItem(server_item, quantity) then
    print("[example] inventory change rejected: capacity exceeded")
    return
end
local added = x_player.addInventoryItem(server_item, quantity)
if not added then
    error("[example] provider did not confirm the inventory change")
end
```

Do not expose this as a generic give-item event. A swap needs the owner's atomicity/failure handling for both operations; a capacity predicate is not enough. Third-party inventory may use slots, metadata, nested values and void returns, so the example's result check is specific to the pinned default implementation.

## Default loadout and weapons

```lua
for _, weapon in ipairs(x_player.getLoadout()) do
    print(("[example] loadout item: %s ammo=%s"):format(weapon.name, weapon.ammo))
end
local compact_loadout = x_player.getLoadout(true) -- map keyed by weapon name
local index, pistol = x_player.getWeapon("WEAPON_PISTOL")
if pistol then
    print(("[example] pistol ammo=%s"):format(pistol.ammo))
end
```

`getWeapon` returns **index, record**, or `nil, nil`; the first return is not the record. Minimal loadout entries always include ammo, and include nondefault tint/components when present. `hasWeapon(name)` and `hasWeaponComponent(name, component)` are predicates; `getWeaponTint(name)` returns tint or zero, so zero does not prove ownership.

| Mutation | Arguments / distinction |
|---|---|
| `addWeapon`, `removeWeapon` | `(name, ammo)` / `(name)`; loadout, entity and UI effects |
| `addWeaponAmmo`, `removeWeaponAmmo` | `(name, amount)`; changes ammo and invokes the native update |
| `updateWeaponAmmo` | `(name, absolute_ammo)`; updates stored loadout; depleted throwable can be removed. Do not assume it is identical to native ammo-setting. |
| `addWeaponComponent`, `removeWeaponComponent` | `(name, component_key)`; use a key supported by the configured weapon catalogue |
| `setWeaponTint` | `(name, tint_index)` validated against that weapon's configured tints |

```lua
-- Example single edit inside an authorized default-loadout service.
if x_player.hasWeapon("WEAPON_PISTOL") and not x_player.hasWeaponComponent("WEAPON_PISTOL", "suppressor") then
    local changed = x_player.addWeaponComponent("WEAPON_PISTOL", "suppressor")
    if not changed then
        print("[example] component change rejected by weapon catalogue/provider")
    end
end
```

Inspect each mutator's success/no-op/false semantics; do not assume all return the same shape. Inventory-based weapons are a different provider model, so do not additionally grant an ESX loadout weapon for the same item. These wrappers invoke engine natives; the framework source alone does not validate the proprietary engine outcome.

## Variables and metadata overloads

`set(key, value)` / `get(key)` use `variables` and replicate the variable table to the client. This does not prove durable storage. `getMeta()` returns metadata; `getMeta(key)` returns one value; `getMeta(key, subkey)` reads a nested value and accepts a string-list to select multiple fields. Missing metadata can throw when ESX debug mode is enabled, so inspect the owned schema before optional reads.

```lua
x_player.set("example_view", "home")
local page = x_player.get("example_view")

x_player.setMeta("example_profile", { title = "Dr.", compact = false })
local title = x_player.getMeta("example_profile", "title")
local selected = x_player.getMeta("example_profile", { "title", "compact" })
x_player.setMeta("example_profile", "title", "Prof.")
x_player.clearMeta("example_profile", "title")
```

Pinned `setMeta(index, value, subvalue)` has two modes: `(key, whole_value)` or `(key, subkey, subvalue)`. The implementation tests **truthiness** of `subvalue`, so passing a false subvalue selects the wrong mode. Its top-level validator also rejects plain booleans. To set a nested `false`, copy the owned table, change that field and write the complete table while preserving siblings:

```lua
local existing = x_player.getMeta().example_profile or {}
local updated = {}
for key, value in pairs(existing) do
    updated[key] = value
end
updated.compact = false
x_player.setMeta("example_profile", updated)
```

`clearMeta(key)` deletes a whole field; `clearMeta(key, subkey_or_string_list)` removes selected nested fields. Metadata is included by ESX's save path; a setter call is not proof of immediate DB durability. Recheck the installed implementation before relying on this revision-specific overload workaround.

## Client communication and utility

```lua
x_player.triggerEvent("example:showStatus", { status = "ready" })
x_player.showNotification(localized_message, "info", 3000, localized_title, "top-right")
local hours = math.floor(x_player.getPlayTime() / 3600)
```

`showAdvancedNotification(sender, subject, message, texture_dict, icon_type, flash?, save_to_brief?, hud_color?)` and `showHelpNotification(message, this_frame?, beep?, duration?)` forward the client notification contracts. Keep visible copy localized. `getPlayTime()` adds stored prior playtime to the current connection time in seconds at the inspected revisions. `executeCommand(command)` sends the `esx:executeCommand` client event; it is not a general server-command executor. Never pass arbitrary client text through a privileged command facility.
