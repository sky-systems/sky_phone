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
# Phone-owned ACE registration and cleanup; place before ensure sky_phone.
add_ace resource.sky_phone command.add_ace allow
add_ace resource.sky_phone command.remove_ace allow

ensure oxmysql
ensure es_extended       # or qbx_core / qb-core, use only your framework
ensure ox_inventory      # or the one inventory configured for Sky Phone
ensure pma-voice         # or your configured voice provider
ensure sky_phone
```

Use only one framework and one active inventory provider. If more than one inventory resource is running, set `Config.Bridge.Inventory` explicitly instead of relying on automatic detection.

## 3. Check Sky Phone configuration

Check `Config.PhoneConfigurator.Enabled` in **Part 1** of `sky_phone/config/config.lua` first.
It is enabled by default. With it enabled, use **/phonepanel → Phone configurator → General**;
Part 2 and `config/media.lua` edits are ignored, including on first start. With it disabled,
edit Part 2 / `media.lua` directly and restart. Verify these values in the active configuration:

1. `Config.Bridge.Inventory` matches the inventory that is actually started.
2. `Config.Phone.Item` exactly matches the item key in the inventory.
3. If physical SIMs are enabled, `Config.Sim.RegisteredItem` and `Config.Sim.AnonymousItem` in the SIM detail section exactly match the two inventory item keys.
4. The configured framework matches the resource that is actually running.

Save panel changes with the checkmark. Restart after changing framework, inventory, voice,
device identity modes or keyboard defaults. General and detail sections share one draft.

**Admin access:** `Config.CommandPermissions` always remains in Part 1 and uses ACE group
suffixes: `admin` means `group.admin` (QBCore also supports `qbcore.admin`). Give administrators
membership through your normal server permission setup. A framework role or Qbox job named
`admin` is not sufficient. Existing users updating from the earlier framework-role checks must
verify ACE membership. The phone checks `sky_phone.phonepanel` for every protected panel action.
The two resource grants above apply to `resource.sky_phone`; grants for another resource do not
apply. No `add_principal` / `remove_principal` capability is required by the phone itself.

If the panel is inaccessible, check the server console for a missing ACE setup message and
run `test_ace group.admin sky_phone.phonepanel` plus a test for the actual player's identifier.
Missing/empty configured lists deny player access. Restart after changing fixed permissions.

For unique phones and physical SIM cards, use a metadata-capable inventory and keep the items non-stackable. The default mode is:

```lua
Config.Phone.Unique = true
Config.Sim.Enabled = true
```

Do not use native ESX inventory or `hex_4_inventory` for unique phones or physical SIM cards. Those inventory paths cannot persist per-item metadata, so Sky Phone disables those features automatically.

### General page and keyboard defaults

General groups devices/SIMs, framework/integrations, phone-use restrictions, and
keyboard/commands. The switches are server-wide; the player's Settings app does
not control them. Turning physical SIMs off gives devices without a SIM an
automatic number; it does not disable the phone. Turning unique phones off makes
phone items open one persistent device per character.

For the phone shortcut and CrewLink quick ping, choose a key or click **Record key**
and press it. The stored value is a FiveM KEYBOARD ID: German Ü becomes `OEM_1`, Ö
becomes `OEM_3`, and Ä becomes `OEM_7`. Escape cancels recording; Tab leaves it.
Use the selector for those keys. Key combinations are unsupported. GTA control
fields such as `Phone.HoldToLook.Control = 19` stay numeric.

Save with the checkmark and restart for changed defaults. Existing player bindings
still take priority and can be changed under FiveM Settings → Key Bindings → FiveM.
See the [full configuration and access guide](https://github.com/sky-systems/sky_phone/blob/dev/docs/phone-configurator.md).

### Keep configuration during updates

Back up the database, including `sky_phone_configurator`, plus file-owned config,
custom tones and other assets. Preserve all four `Server` peppers. Switching off
the Configurator does not copy SQL values into Lua files; review file values first.
Use the SQL Configurator for private peppers because clients download `config.lua`
even when a block runs only on the server. Media keys belong in the panel in SQL
mode, or in server-only `config/media.lua` in file mode.

## 4. ox_inventory: complete both required parts

For another inventory, use the [Inventory Items & Setup guide](https://www.sky-systems.net/docs/scripts/free-phone/inventory-items). It includes all 17 Phone adapters and their own item formats. Do not copy the following ox-only use handlers into TGIANN or another inventory.

The ox adapter requires the server `ox_inventory:usedItem` event, introduced in upstream [2.38.0](https://github.com/overextended/ox_inventory/releases/tag/v2.38.0). Update older versions before testing this setup.

### 4.1 Remove old NPWD phone code

Search the **whole `ox_inventory` resource**, not only `data/items.lua`, for an old handler similar to this:

```lua
Item('phone', function(data, slot)
    return exports.npwd:isPhoneVisible()
end)
```

Remove the complete NPWD handler if it exists. It can intercept the `phone` item even when NPWD is stopped. Also remove old LB Phone or another phone's `client.event`/item handler for the same item.

### 4.2 Define the items in the active `ox_inventory/data/items.lua`

Use the exact item names from the active Phone/SIM configuration (the panel in SQL
mode, Part 2 of `config.lua` in file mode). These examples use the shipped names:

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

## 6. QBCore-style inventories

For `qb-inventory`, `lj-inventory`, or another QBCore-style item table:

- Set `useable = true` and `shouldClose = true`.
- Set the phone `unique` value to match `Config.Phone.Unique`.
- Physical SIM items must always be unique when physical SIMs are enabled.
- Keep the configured item names exactly the same as in Sky Phone.

Use the item format documented for the installed inventory. The `sky_phone.UsePhoneItem` and `sky_phone.UseSimItem` client exports are ox-only, even if another inventory accepts ox-style fields. Use the [inventory-specific guide](https://www.sky-systems.net/docs/scripts/free-phone/inventory-items) for the correct native setup, including TGIANN's `hasMetadata` flag and Phonepanel adapter selection.

## 7. Final verification

After the complete server restart:

1. Open the inventory and use the actual configured phone item.
2. Use each physical SIM item separately if multiple SIMs exist.
3. Confirm the correct phone/SIM slot is changed and the other items remain untouched.
4. Watch the server console for Sky Phone inventory warnings.
5. Open the phone again after reconnecting to confirm the metadata persisted.

If the item still does nothing, temporarily set `Bridge.Debug = true` in the Configurator's Bridge section and save. In file mode, edit Part 2 of `config.lua` and restart instead. Reproduce the issue once and collect the relevant server-console and F8 lines, then disable debug mode. Never send API keys, tokens, database passwords, or full player identifiers in a support ticket.

Useful error directions:

| Message or symptom                                   | Usually means                                                                                                        |
| ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `/phonepanel` is denied | Check the two Phone resource grants, `CommandPermissions.phonepanel`, the player's ACE membership and explicit denies. |
| Config file edits do not apply | SQL mode is enabled; change the corresponding panel field and save. Part 1 always remains file-owned. |
| Changed shortcut still uses the old key | Restart for changed defaults, then review the player's own saved FiveM key binding. |
| No phone item was found                              | Wrong item name, wrong inventory adapter, or the player does not own the configured item                             |
| `phone_slot_missing` or `sim_slot_missing`           | The inventory did not return the selected slot or the item was changed before the server check                       |
| `metadata_unsupported`                               | The active inventory cannot persist the required per-item metadata                                                   |
| Inventory adapter `nil` / missing `GetSlotsWithItem` | Wrong or mixed provider configuration; fix the inventory installation first                                          |
| No Sky Phone usable-item log at all                  | An old NPWD/LB/custom item handler is intercepting the item, or the active item definition is not the one being used |
