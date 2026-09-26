# Sky Phone — Important Installation Guide

Read this file before starting Sky Phone. Most reports that the phone item does nothing are caused by an incorrect item definition, an old phone handler, a wrong inventory adapter, or an incomplete restart. The database and the phone UI cannot fix those installation problems.

## 1. Install the correct package

- Download a published Sky Phone release. Do not install GitHub's automatically generated **Source code** archive; it does not contain the built NUI.
- Keep the resource folder name exactly `sky_phone`.
- `fxmanifest.lua` must be directly inside that folder.
- Do not start two phone resources that handle the same item. Stop NPWD, LB Phone, or another replacement phone before testing Sky Phone.

## 2. Start resources in the correct order

Start these resources before Sky Phone:

```cfg
ensure oxmysql
ensure es_extended       # or qbx_core / qb-core, use only your framework
ensure ox_inventory      # or the one inventory configured for Sky Phone
ensure pma-voice         # or your configured voice provider
ensure sky_phone
```

Use only one framework and one active inventory provider. If more than one inventory resource is running, set `Config.Bridge.Inventory` explicitly instead of relying on automatic detection.

## 3. Check Sky Phone configuration

Open `sky_phone/config/config.lua` and verify:

1. `Config.Bridge.Inventory` matches the inventory that is actually started.
2. `Config.Phone.Item` exactly matches the item key in the inventory.
3. `Config.Sim.RegisteredItem` and `Config.Sim.AnonymousItem` exactly match the two physical SIM item keys.
4. The configured framework matches the resource that is actually running.

For unique phones and physical SIM cards, use a metadata-capable inventory and keep the items non-stackable. The default mode is:

```lua
Config.Phone.Unique = true
Config.Sim.Enabled = true
```

Do not use native ESX inventory or `hex_4_inventory` for unique phones or physical SIM cards. Those inventory paths cannot persist per-item metadata, so Sky Phone disables those features automatically.

## 4. ox_inventory: complete both required parts

### 4.1 Remove old NPWD phone code

Search the **whole `ox_inventory` resource**, not only `data/items.lua`, for an old handler similar to this:

```lua
Item('phone', function(data, slot)
    return exports.npwd:isPhoneVisible()
end)
```

Remove the complete NPWD handler if it exists. It can intercept the `phone` item even when NPWD is stopped. Also remove old LB Phone or another phone's `client.event`/item handler for the same item.

### 4.2 Define the items in the active `ox_inventory/data/items.lua`

Use the exact item names from `config/config.lua`:

```lua
["phone"] = {
    label = "iFruit Phone",
    weight = 200,
    stack = false,
    close = true,
    consume = 0,
    buttons = {
        {
            label = "Eject SIM", -- Translate this static inventory label, e.g. "SIM entfernen".
            action = function(slot)
                exports.sky_phone:EjectSimFromSlot(slot)
            end,
        },
    },
    client = { export = "sky_phone.UsePhoneItem" },
},

["sky_phone_sim_registered"] = {
    label = "Registered SIM",
    weight = 5,
    stack = false,
    close = true,
    consume = 0,
    client = { export = "sky_phone.UseSimItem" },
},

["sky_phone_sim_anonymous"] = {
    label = "Anonymous SIM",
    weight = 5,
    stack = false,
    close = true,
    consume = 0,
    client = { export = "sky_phone.UseSimItem" },
},
```

Do not add an LB Phone, NPWD, or custom `client.event` for these items. Do not configure two handlers for the same item. The Sky Phone exports use ox_inventory's verified `useItem` flow, preserve the selected slot, and still validate ownership and metadata on the server.

After changing `data/items.lua` or removing an old handler, restart the **complete FiveM server**. Restarting only Sky Phone is not enough because ox_inventory loads item definitions and client item handlers during its own startup.

### 4.3 Add the items to an ox_inventory shop

Defining an item in `data/items.lua` only makes the item usable. To sell it, add the exact item keys to the shop's `inventory` list in `ox_inventory/data/shops.lua`:

```lua
General = {
    name = "General Store",
    inventory = {
        { name = "phone", price = 500 },
        { name = "sky_phone_sim_registered", price = 100 },
        { name = "sky_phone_sim_anonymous", price = 50 },

        -- Keep the shop's other items here as well.
        { name = "water", price = 10 },
    },
    locations = {
        -- Keep or add your shop coordinates here.
        vec3(25.7, -1347.3, 29.49),
    },
},
```

If `General` already exists, add only the three item rows to its existing `inventory` table. Do not create a second `General` entry. Replace the example prices and coordinates with your own server values.

The shop uses the item key, not the label. Do not put `client.export`, `buttons`, or phone metadata in `shops.lua`; those belong in `data/items.lua`. `ox_inventory` gives every purchased phone and SIM its own slot because the definitions above use `stack = false`. Sky Phone creates and persists the phone IMEI or SIM metadata when the item is first used, so do not prefill or copy `imei`, `sim_id`, or phone-number metadata manually.

After editing `data/shops.lua`, restart `ox_inventory` or the complete FiveM server and buy one phone plus one SIM for a clean test.

## 5. Multiple phones and SIM cards

Sky Phone supports multiple physical phones and SIM cards. For reliable per-item identity:

- Keep every phone and physical SIM `stack = false`.
- Never copy or convert an item in a way that removes its metadata.
- Do not manually duplicate `imei`, `sim_id`, or phone-number metadata.
- Give each phone and SIM its own inventory slot.
- Keep the item names and metadata field names unchanged after players already own items.

The ox_inventory item export is important here: it passes the exact slot the player clicked. Without it, the generic fallback can depend on the installed inventory/framework bridge and may select the first available item on older or modified providers.

## 6. Origen inventory and Origen Inventory V2

The ticket examples use `origen_inventoryv2`. That is a real, separate Origen package/resource name. It must not be treated as an alias for the documented `origen_inventory` adapter.

The current Sky Phone release supports the documented `origen_inventory` adapter. Its adapter lookup matches the resource name `origen_inventory`; it does not automatically turn a separately named `origen_inventoryv2` resource into a supported Phone adapter. This is why a server that runs only `origen_inventoryv2` can also show this Sky Phone error:

```text
[sky_phone] Inventory adapter 'nil' is missing required method 'GetSlotsWithItem'.
```

Do not rename the V2 folder, copy V1 files into it, or mix V1/V2 manifests and exports. The following errors from the customer ticket are provider startup errors from the Origen V2 package, not missing Sky Phone item exports:

```text
No such export registerHook in resource origen_inventory
attempt to call a nil value (field 'SelectStash')
attempt to call a nil value (field 'LoadInventory')
```

For the currently supported package, install one matching `origen_inventory` version, start it before `sky_phone`, and set `Config.Bridge.Inventory = "origen"` when automatic detection is not suitable. The public [Origen export reference](https://docs.origennetwork.com/scripts/origen_inventory/exports) is the contract used by this adapter.

Origen Inventory V2 needs a separate adapter. We will not guess or alias it to V1 because the Phone must be able to read the exact item slot, preserve nested metadata, write metadata, add/remove the item in that slot, check capacity, and register item use. Those function names and argument/return contracts are not verified by the V1 documentation. If you need V2 support, provide the exact V2 version, `fxmanifest.lua`, and vendor export documentation so the V2 adapter can be implemented and contract-tested properly.

## 7. QBCore-style inventories

For `qb-inventory`, `lj-inventory`, or another QBCore-style item table:

- Set `useable = true` and `shouldClose = true`.
- Set the phone `unique` value to match `Config.Phone.Unique`.
- Physical SIM items must always be unique when physical SIMs are enabled.
- Keep the configured item names exactly the same as in Sky Phone.

Use the item format documented for the installed inventory. Do not paste an ox_inventory `client.export` into a QBCore item table unless that inventory explicitly supports it.

## 8. Final verification

After the complete server restart:

1. Open the inventory and use the actual configured phone item.
2. Use each physical SIM item separately if multiple SIMs exist.
3. Confirm the correct phone/SIM slot is changed and the other items remain untouched.
4. Watch the server console for Sky Phone inventory warnings.
5. Open the phone again after reconnecting to confirm the metadata persisted.

If the item still does nothing, temporarily set `Config.Bridge.Debug = true`, reproduce the issue once, and collect the relevant server-console and F8 lines. Disable debug mode afterward. Never send API keys, tokens, database passwords, or full player identifiers in a support ticket.

Useful error directions:

| Message or symptom                                   | Usually means                                                                                                        |
| ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| No phone item was found                              | Wrong item name, wrong inventory adapter, or the player does not own the configured item                             |
| `phone_slot_missing` or `sim_slot_missing`           | The inventory did not return the selected slot or the item was changed before the server check                       |
| `metadata_unsupported`                               | The active inventory cannot persist the required per-item metadata                                                   |
| Inventory adapter `nil` / missing `GetSlotsWithItem` | Wrong or mixed provider configuration; fix the inventory installation first                                          |
| No Sky Phone usable-item log at all                  | An old NPWD/LB/custom item handler is intercepting the item, or the active item definition is not the one being used |
