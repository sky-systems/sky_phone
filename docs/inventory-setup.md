# Inventory Items & Setup

Choose your inventory below, register the phone and SIM items in its own format, then verify item use and metadata. These instructions describe the adapters included in Sky Phone **1.1.0**. An inventory accepting ox-style item fields does not make its use callbacks compatible with ox_inventory.

## Choose the inventory in Phonepanel

1. Finish your inventory provider's framework installation first.
2. Open `/phonepanel → Phone configurator → General → Framework & integrations → Inventory` and choose the adapter value from the table below.
3. Check `Phone.Item`, `Phone.Unique`, `Sim.Enabled`, `Sim.RegisteredItem`, and `Sim.AnonymousItem` in the same Configurator. The examples on this page use the default names, unique phones, and physical SIMs.
4. Save with the checkmark and confirm success. Restart after changing the inventory adapter; saving does not restart the resources.

With `Config.PhoneConfigurator.Enabled = true`, these settings come from the Configurator, including on first start. Editing Part 2 of `config.lua` does not apply them. Only in file mode, use the corresponding setting, for example:

```lua
Config.Bridge.Inventory = "tgiann"
```

`auto` selects the first compatible started inventory in Phone's detection order. Select an explicit adapter when troubleshooting or replacing an inventory. The inventory alias `qbox` means `ox`; it is not a request to detect any inventory installed on Qbox. See [configuration modes and access](phone-configurator.md).

## Inventory selector

The constraints below describe **Sky Phone's adapters**. Also follow the provider's installation guide for your framework and exact inventory version.

| Inventory & setup → Phone adapter | Constraints |
| --- | --- |
| [ox_inventory](#ox-inventory) → `ox` | Per-item metadata; requires the server `usedItem` event |
| [tgiann-inventory](#tgiann-inventory) → `tgiann` | Enable `hasMetadata`; use native framework callbacks |
| [qb-inventory](#qb-inventory) → `qb` | Stock QBCore setup; `info` metadata |
| [lj-inventory](#lj-inventory) → `lj` | QBCore setup; `info` metadata |
| [ps-inventory](#ps-inventory) → `ps` | Phone adapter requires QBCore |
| [jpr-inventory](#jpr-inventory) → `jpr` | Phone adapter requires QBCore |
| [qs-inventory](#qs-inventory) → `qs` | ESX and QB use different item locations |
| [codem-inventory](#codem-inventory) → `codem` | mInventory Remake; not `codem-inventoryv2` |
| [ak47_inventory](#ak47-inventory) → `ak47` | Native `stacksize` format; `info` metadata |
| [jaksam_inventory](#jaksam-inventory) → `jaksam` | Native item schema and usable-item registration |
| [core_inventory](#core-inventory) → `core` | Version check required; current documented APIs differ from Phone 1.1.0 |
| [one_inventory](#one-inventory) → `one` | Persistent item editor; per-item metadata |
| [origen_inventory](#origen-inventory) → `origen` | Native `stack` / `close` format; per-item metadata |
| [mf-inventory](#mf-inventory) → `mf` | ESX only; verify the installed usable-item callback contract |
| [smx-inventory](#smx-inventory) → `smx` | ESX only; one metadata record per character and item name |
| [hex_4_inventory](#hex-and-native-esx-inventory) → `hex` | ESX only; no unique phones or physical SIMs |
| [Native ESX inventory](#hex-and-native-esx-inventory) → `esx` | No unique phones or physical SIMs |

## Required items and images

| Default item ID | Purpose | Required when | Included image |
| --- | --- | --- | --- |
| `phone` | Opens the phone | Always, including character-based phone mode | `phone.png` |
| `sky_phone_sim_registered` | Registered physical SIM | `Sim.Enabled = true` | `sky_phone_sim_registered.png` |
| `sky_phone_sim_anonymous` | Anonymous physical SIM | `Sim.Enabled = true` | `sky_phone_sim_anonymous.png` |

The images are included in `sky_phone/config/images/`. Copy them to your inventory's image location below. If your inventory has a configurable image URL or a separate image resource, use its active location.

- Merge the entries into the existing item catalogue. Replace an existing definition of the same name instead of adding a duplicate key.
- Keep the item IDs identical in Phonepanel, the inventory, and any shops or distribution scripts. Display labels can be translated.
- Unique phones and physical SIMs each need their own slot. Physical SIMs remain non-stackable even if `Phone.Unique = false`.
- Leave default identity metadata empty. Sky Phone assigns IMEIs, SIM identities, and numbers; do not prefill or duplicate these values in items or shop stock.
- Sky Phone handles removal of a SIM after a successful insertion. Do not add separate consumption or use handlers that remove it first.

**The client exports `sky_phone.UsePhoneItem` and `sky_phone.UseSimItem` belong only in the ox_inventory definitions below.** Other Phone adapters register item use through their own inventory or framework. Remove these ox-only use hooks when moving to another inventory, including compatibility fields that call them. This does not refer to the separate optional `EjectSimFromSlot` context-menu export.

## ox inventory

Select **`ox`**. Merge all three entries into `ox_inventory/data/items.lua`, inside its existing returned table:

```lua
["phone"] = {
    label = "iFruit Phone",
    weight = 200,
    stack = false,
    close = true,
    consume = 0,
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

Copy all three PNGs to `ox_inventory/web/images/`. Keep `consume = 0`; the inventory must not consume the phone or remove the SIM before Phone finishes inserting it. [Ox item fields and client callbacks](https://overextended.dev/docs/ox_inventory/Guides/creatingItems).

### Required ox version contract

Phone listens for the **server-side `ox_inventory:usedItem` event** after use completes. Upstream added that event in [ox_inventory 2.38.0](https://github.com/overextended/ox_inventory/releases/tag/v2.38.0). Older versions such as 2.37.4 do not provide this path. An item can close the inventory without reaching Phone's server handler.

Use an up-to-date inventory release compatible with your framework and retain your custom item changes during the update. For forks, verify that the completed-use event still exists; an ox-compatible resource name or `useItem` export alone is insufficient.

### Remove the old NPWD phone handler

Search the complete ox_inventory resource for `Item('phone'` and `Item("phone"`. Check `modules/items/client.lua`; older packages can use `items/client.lua`.

**Delete the following NPWD handler if present. This is code to remove, not to add:**

```lua
Item('phone', function(data, slot)
    local success, result = pcall(function()
        return exports.npwd:isPhoneVisible()
    end)

    if success then
        exports.npwd:setPhoneVisible(not result)
    end
end)
```

Keep the `phone` definition and its Sky Phone `client.export` in `data/items.lua`. The old NPWD handler can intercept use even if NPWD is stopped or absent. Remove competing handlers for the same item, restart the complete server, and recheck this step after inventory updates.

## TGIANN inventory

Select **`tgiann`**, save, and restart. Merge these definitions into the active item file under `tgiann-inventory/items/`:

```lua
["phone"] = {
    name = "phone",
    label = "iFruit Phone",
    weight = 200,
    type = "item",
    image = "phone.png",
    unique = true,
    hasMetadata = true,
    useable = true,
    shouldClose = true,
    description = "A personal mobile phone",
},
["sky_phone_sim_registered"] = {
    name = "sky_phone_sim_registered",
    label = "Registered SIM",
    weight = 5,
    type = "item",
    image = "sky_phone_sim_registered.png",
    unique = true,
    hasMetadata = true,
    useable = true,
    shouldClose = true,
    description = "A registered physical SIM card",
},
["sky_phone_sim_anonymous"] = {
    name = "sky_phone_sim_anonymous",
    label = "Anonymous SIM",
    weight = 5,
    type = "item",
    image = "sky_phone_sim_anonymous.png",
    unique = true,
    hasMetadata = true,
    useable = true,
    shouldClose = true,
    description = "An anonymous physical SIM card",
},
```

All three entries need `hasMetadata = true`. Keep their normal usable-item flow; do not add a `roleplay` item action, which bypasses framework callbacks. Do not add `client.export = "sky_phone.UsePhoneItem"` or `"sky_phone.UseSimItem"`. [TGIANN item schema](https://tgiann.gitbook.io/tgiann/scripts/tgiann-inventory/guides/creating-items).

Copy the PNGs into the separately supplied `inventory_images/images/` folder. Keep the explicit `image` filenames above: TGIANN otherwise defaults to `<itemName>.webp`. [TGIANN image setup](https://tgiann.gitbook.io/tgiann/scripts/tgiann-inventory/guides/item-images).

Sky Phone already includes the TGIANN adapter and registers usable items through the framework; on ESX, this uses `ESX.RegisterUsableItem`. If you see `No such export useItem in resource ox_inventory`, the item is calling the ox-specific handler. Check both the selected adapter and the item's use hooks. Selecting `tgiann` does not rewrite your inventory's item definitions.

## Shared QB-style item definitions

Use this complete template for the QB, LJ, PS, JPR, QS, and CodeM setups below. Their item-file locations differ. Do not apply this format to Core, AK47, Jaksam, One, or Origen without their provider-specific changes.

```lua
["phone"] = {
    name = "phone",
    label = "iFruit Phone",
    weight = 200,
    type = "item",
    image = "phone.png",
    unique = true,
    useable = true,
    shouldClose = true,
    description = "A personal mobile phone",
},
["sky_phone_sim_registered"] = {
    name = "sky_phone_sim_registered",
    label = "Registered SIM",
    weight = 5,
    type = "item",
    image = "sky_phone_sim_registered.png",
    unique = true,
    useable = true,
    shouldClose = true,
    description = "A registered physical SIM card",
},
["sky_phone_sim_anonymous"] = {
    name = "sky_phone_sim_anonymous",
    label = "Anonymous SIM",
    weight = 5,
    type = "item",
    image = "sky_phone_sim_anonymous.png",
    unique = true,
    useable = true,
    shouldClose = true,
    description = "An anonymous physical SIM card",
},
```

For character-based phones, change only the phone entry's `unique` value to match `Phone.Unique`. The SIM entries stay unique. The `useable` spelling is intentional. Do not register another phone callback or add ox-only use exports. [QBCore shared-item schema](https://qbcore.org/docs/qb-core/shared#items).

### qb inventory

Select **`qb`**. Put the [shared definitions](#shared-qb-style-item-definitions) in `qb-core/shared/items.lua`; copy the PNGs to `qb-inventory/html/images/`. Complete the stock QBCore inventory installation before testing Phone. [QB installation and image files](https://github.com/qbcore-framework/qb-inventory).

### lj inventory

Select **`lj`**. Put the [shared definitions](#shared-qb-style-item-definitions) in `qb-core/shared/items.lua`; copy the PNGs to `lj-inventory/html/images/`. Phone's LJ path uses QBCore player items. Follow LJ's framework changes so QBCore loads and saves through the active inventory. [LJ installation](https://github.com/loljoshie/lj-inventory#how-to-install-lj-inventory-latest-qbcore-update).

### ps inventory

Select **`ps`**. Put the [shared definitions](#shared-qb-style-item-definitions) in `qb-core/shared/items.lua`; copy the PNGs to `ps-inventory/html/images/`. Sky Phone's PS adapter requires **QBCore**. Follow the provider's framework installation as well as the Phone setting. [PS installation](https://github.com/Project-Sloth/ps-inventory#installation).

### jpr inventory

Select **`jpr`**. Put the [shared definitions](#shared-qb-style-item-definitions) in `qb-core/shared/items.lua`; copy the PNGs to `jpr-inventory/html/images/`. Sky Phone's JPR adapter requires **QBCore**, even if your JPR release also supports other frameworks. Apply the provider's QBCore-version settings for your installed release. [JPR item locations](https://joaos-organization-3.gitbook.io/jpresources-documentation/installation/inventory/faq), [QBCore installation](https://joaos-organization-3.gitbook.io/jpresources-documentation/installation/inventory/installation-page/qbcore).

### qs inventory

Select **`qs`**. Add the [shared definitions](#shared-qb-style-item-definitions) to `qs-inventory/shared/items.lua` on **ESX**, or `qb-core/shared/items.lua` on **QBCore**. Copy the PNGs to `qs-inventory/html/images/`.

Phone registers use through Quasar's inventory callback on ESX and the framework callback on QB. Keep normal inventory use enabled; do not restrict these entries to hotbar-only use. For another framework or fork, follow its matching provider installation instead of assuming the QB file path. [Quasar installation](https://www.quasar-store.com/docs/advanced-inventory/installation#item-management), [item configuration](https://www.quasar-store.com/docs/advanced-inventory/item-configuration).

### codem inventory

Select **`codem`** for **`codem-inventory` / mInventory Remake**. Add the [shared definitions](#shared-qb-style-item-definitions) to `codem-inventory/config/itemlist.lua`; place the named PNGs in the image location configured by your installed mInventory version. Phone uses framework usable-item registration and per-item `info`. [CodeM item setup](https://codem.gitbook.io/codem-documentation/m-series/essentials/minventory-remake/how-to).

**`codem-inventoryv2` / Supreme Inventory is a different resource.** Phone 1.1.0's `codem` adapter does not target it. Its ox compatibility features do not make Phone's ox use exports a CodeM integration.

## AK47 inventory

Select **`ak47`**. Merge these native entries into `Config.Shared.Items` in `ak47_inventory/shared/items.lua`:

```lua
["phone"] = {
    name = "phone",
    label = "iFruit Phone",
    weight = 200,
    type = "item",
    stacksize = 1,
    close = true,
},
["sky_phone_sim_registered"] = {
    name = "sky_phone_sim_registered",
    label = "Registered SIM",
    weight = 5,
    type = "item",
    stacksize = 1,
    close = true,
},
["sky_phone_sim_anonymous"] = {
    name = "sky_phone_sim_anonymous",
    label = "Anonymous SIM",
    weight = 5,
    type = "item",
    stacksize = 1,
    close = true,
},
```

`stacksize = 1` gives each device or SIM its own slot. Use AK47's existing image convention for the three matching PNGs. Keep Phone's framework usable callbacks; do not add a competing `onUse` handler. For hover details, enable `imei` and `phone_number` in `Config.ShowValueFromItemInfo` and translate their labels. [Item location](https://docs.menanak47.com/multi-framework/ak47_inventory/guides/configuration), [native fields](https://docs.menanak47.com/multi-framework/ak47_inventory/templates/item), [tooltips](https://docs.menanak47.com/multi-framework/ak47_inventory/templates/tooltip).

## Jaksam inventory

Select **`jaksam`**. Add the entries to `jaksam_inventory/_data/items.lua`, or create the same definitions persistently through Jaksam's `/inventory` editor:

```lua
["phone"] = {
    label = "iFruit Phone",
    weight = 200,
    type = "item",
    image = "phone.png",
    description = "A personal mobile phone",
    stackable = false,
    maxStack = 1,
    close = true,
    consume = 0,
},
["sky_phone_sim_registered"] = {
    label = "Registered SIM",
    weight = 5,
    type = "item",
    image = "sky_phone_sim_registered.png",
    description = "A registered physical SIM card",
    stackable = false,
    maxStack = 1,
    close = true,
    consume = 0,
},
["sky_phone_sim_anonymous"] = {
    label = "Anonymous SIM",
    weight = 5,
    type = "item",
    image = "sky_phone_sim_anonymous.png",
    description = "An anonymous physical SIM card",
    stackable = false,
    maxStack = 1,
    close = true,
    consume = 0,
},
```

Copy the PNGs to `jaksam_inventory/_images/`. Phone registers use directly through Jaksam. Remove imported `oxClientExport` / `oxClientEvent` hooks that call the ox-specific Phone handlers. Runtime `registerItem` definitions do not replace persistent file/editor setup. [Jaksam item and callback schema](https://documentation.jaksam-scripts.com/jaksam-inventory/functions/server#registeritem), [persistent items and display fields](https://documentation.jaksam-scripts.com/jaksam-inventory/guides/metadata), [image resolution](https://documentation.jaksam-scripts.com/jaksam-inventory/functions/shared#getitemimagepath).

## Core inventory

**Check your Core version before using this setup.** Phone 1.1.0 contains a `core` adapter, but it expects a flat item list from `getInventory` and passes a slot to `removeItemExact`. Core's current public API describes an inventory wrapper with `content` and an internal unique item ID for removal. If your installed Core follows that contract, the adapter needs updating; changing item definitions cannot resolve it. [Core API](https://docs.c8re.store/core-inventory/exports), [Phone 1.1.0 adapter](https://github.com/sky-systems/sky_phone/blob/1.1.0/sky_phone/source/bridge/server/inventory/core.lua).

For a compatible Core installation, select **`core`**. Native QBCore definitions belong in `qb-core/shared/items.lua`; native ESX definitions use the `items` database table after Core's schema installation. Core also documents an optional `core_inventory/data/items.lua` file mode. Follow the mode actually enabled on your server. [Core installation and file mode](https://docs.c8re.store/core-inventory/installation).

Core controls stacking through item categories. Add a dedicated category with **no `stack` property** to the existing configuration:

```lua
Config.ItemCategories["sky_phone_devices"] = {
    color = "#f2f2f2",
    takeSound = "take",
    putSound = "put",
}
```

Core QBCore definitions for the three default items, retaining the framework fields alongside Core's dimensions and category:

```lua
["phone"] = {
    name = "phone",
    label = "iFruit Phone",
    weight = 200,
    type = "item",
    image = "phone.png",
    unique = true,
    useable = true,
    shouldClose = true,
    x = 1,
    y = 1,
    category = "sky_phone_devices",
    description = "A personal mobile phone",
},
["sky_phone_sim_registered"] = {
    name = "sky_phone_sim_registered",
    label = "Registered SIM",
    weight = 5,
    type = "item",
    image = "sky_phone_sim_registered.png",
    unique = true,
    useable = true,
    shouldClose = true,
    x = 1,
    y = 1,
    category = "sky_phone_devices",
    description = "A registered physical SIM card",
},
["sky_phone_sim_anonymous"] = {
    name = "sky_phone_sim_anonymous",
    label = "Anonymous SIM",
    weight = 5,
    type = "item",
    image = "sky_phone_sim_anonymous.png",
    unique = true,
    useable = true,
    shouldClose = true,
    x = 1,
    y = 1,
    category = "sky_phone_devices",
    description = "An anonymous physical SIM card",
},
```

On ESX, enter the equivalent fields using Core's installed SQL schema. Keep any additional fields required by your framework. Add all three item names to the existing `Config.CloseAfterUse` list, copy the images using Core's installed image convention, and configure `ShownMetadata` / `ShowInformationsOnHover` for hover details. Do not replace the existing category or close-on-use lists. [Core item structure](https://docs.c8re.store/core-inventory/item-structure), [Core configuration](https://docs.c8re.store/core-inventory/configuration).

An ox-style **file format** in Core does not change the Phone adapter into `ox`; keep the ox-specific use exports out of those definitions.

## One inventory

Select **`one`**. Use One's persistent **`/inventory:manage`** item editor with its `one_inventory.admin` permission. Create or update these three entries:

| Name | Label | Weight | Image |
| --- | --- | --- | --- |
| `phone` | iFruit Phone | 200 | `phone.png` |
| `sky_phone_sim_registered` | Registered SIM | 5 | `sky_phone_sim_registered.png` |
| `sky_phone_sim_anonymous` | Anonymous SIM | 5 | `sky_phone_sim_anonymous.png` |

For each, set **`unique = true`**, **`close = true`**, and **`consume = 0`**, and add a description. Leave `clientExport`, `serverExport`, `clientEvent`, and `serverEvent` unset: One's framework usable registry handles Phone's callbacks. Copy the PNGs to `one_inventory/web/images/` or upload them through its editor. [One usable items and editor](https://onestudios.gg/docs/guides/usable-items), [native item fields](https://onestudios.gg/docs/server/exports#createitemsdefinition), [images](https://onestudios.gg/docs/guides/item-images), [admin permissions](https://onestudios.gg/docs/guides/permissions).

The runtime `CreateItemsDefinition` export is temporary. Use the persistent editor for an installation that survives an inventory restart. Phone registers IMEI and number tooltip labels automatically.

## Origen inventory

Select **`origen`**. Current Origen documentation places native entries in **`origen_inventory/config/items.lua`**. If your installed version uses a different item loader, follow its matching instructions. Complete Origen's framework integration, including its ESX overrides when applicable. [Origen installation and item locations](https://docs.origennetwork.com/scripts/origen_inventory/installation).

```lua
["phone"] = {
    label = "iFruit Phone",
    weight = 200,
    type = "item",
    image = "phone.png",
    description = "A personal mobile phone",
    stack = false,
    close = true,
    consume = 0,
},
["sky_phone_sim_registered"] = {
    label = "Registered SIM",
    weight = 5,
    type = "item",
    image = "sky_phone_sim_registered.png",
    description = "A registered physical SIM card",
    stack = false,
    close = true,
    consume = 0,
},
["sky_phone_sim_anonymous"] = {
    label = "Anonymous SIM",
    weight = 5,
    type = "item",
    image = "sky_phone_sim_anonymous.png",
    description = "An anonymous physical SIM card",
    stack = false,
    close = true,
    consume = 0,
},
```

Place the PNGs in the image directory used by your Origen version. Keep native framework item use with no ox-only Phone client export. Origen's `stack` and `close` fields should not be replaced by QB's `unique` and `shouldClose` merely because your framework is QB. [Origen item fields](https://docs.origennetwork.com/scripts/origen_inventory/custom).

## MF inventory

Select **`mf`** on **ESX**. Install MF's database extensions and framework integration first, then add the three IDs from the [item list](#required-items-and-images) to the ESX `items` table using that installed schema.

MF adds `unique` and `degrademodifier` fields. Set **`unique = 1`** for each unique handset and physical SIM, and **`degrademodifier = 0.0`** to disable decay. Choose weights in the units used by your MF installation and follow its active image convention. Do not paste a QB Lua table into SQL. [MF installation](https://github.com/meta-hub/mf-inventory/wiki/Legacy-Installation), [unique items and degradation](https://github.com/meta-hub/mf-inventory/wiki/Features).

**Verify the MF/ESX integration version:** Phone 1.1.0 expects the actual slot item as the fourth usable-callback argument. The older public MF examples show a different argument layout. An installation using that older layout needs a matching adapter/integration update; `unique = 1` alone cannot fix item use. [MF examples](https://github.com/meta-hub/mf-inventory/wiki/Examples), [Phone MF adapter](https://github.com/sky-systems/sky_phone/blob/1.1.0/sky_phone/source/bridge/server/inventory/mf.lua).

## SMX inventory

Select **`smx`** on **ESX**. The bundled Phone adapter registers the configured phone and enabled SIM item names through `ESX.AddItems`; there is no additional Phone QB/ox item table to paste. Add the matching images using your installed SMX image configuration. [Phone SMX adapter](https://github.com/sky-systems/sky_phone/blob/1.1.0/sky_phone/source/bridge/server/inventory/smx.lua).

**This adapter stores one metadata record per character and configured item name.** Multiple copies of `phone`, for example, cannot hold separate device identities through this bridge. Do not use it for independently transferable collections of phones/SIMs or assume normal inventory trades move the identity metadata.

For a character-based setup, use `Phone.Unique = false` and `Sim.Enabled = false`. For distinct physical handsets and transferable physical SIMs, choose an inventory with verified per-item metadata support instead. No current public SMX item schema or universal image path is assumed here.

## HEX and native ESX inventory

Select **`hex`** for `hex_4_inventory`, or **`esx`** for native ESX inventory. Both require ESX. Register the configured **phone item only** in the active ESX item catalogue and use the image path configured by HEX or your ESX inventory UI.

| Item field | Value |
| --- | --- |
| `name` | `phone`, or your configured `Phone.Item` |
| `label` | iFruit Phone |
| `weight` | Set for your server's item weight convention |
| `rare` | `0`, if this field exists in the installed schema |
| `can_remove` | `1`, if this field exists in the installed schema |

These Phone adapters expose count-based items without per-item metadata. Phone automatically forces **`Phone.Unique = false`** and **`Sim.Enabled = false`**. Data belongs to the character and a number is assigned without a physical SIM. Creating SIM rows or adding `unique` flags does not enable physical SIM support. [Phone ESX/HEX adapter](https://github.com/sky-systems/sky_phone/blob/1.1.0/sky_phone/source/bridge/server/inventory/esx.lua), [mode enforcement](https://github.com/sky-systems/sky_phone/blob/1.1.0/sky_phone/source/bridge/server/inventory.lua).

## Tooltips and SIM removal

Metadata storage and tooltip display are separate. A missing IMEI label in a hover tooltip does not by itself mean that the item lost its metadata.

Phone automatically registers tooltip labels for ox, TGIANN, and One. Other inventories may need their own display configuration. For Jaksam display fields, Core and AK47 settings, LJ/PS formatting, and optional SIM context-menu buttons, follow the [inventory tooltip and SIM-button guide](https://github.com/sky-systems/sky_phone/blob/1.1.0/README.md#inventory-tooltip-setup). Use the normal in-phone SIM controls when your inventory has no supported custom button.

## Restart and verify

After changing framework item definitions or inventory code, restart the complete server. Start `oxmysql`, your framework, the selected inventory and its dependencies, and your voice resource **before `sky_phone`**. See the [installation and ACE setup](https://www.sky-systems.net/docs/scripts/free-phone/installation).

1. Check the console for missing resources, exports, incompatible frameworks, or metadata warnings.
2. Obtain the configured phone through your normal inventory/admin tool. Use it from the inventory and confirm that Phone opens.
3. With physical SIMs enabled, use a registered SIM and then an anonymous SIM. Confirm successful insertion, correct number/type, and removal/ejection without duplication.
4. With unique phones enabled, test two separate handsets in different slots. Confirm that each keeps its own IMEI and SIM.
5. On an inventory with per-item metadata, move a device through a stash and a player trade, then reconnect/restart and verify its identity and number. This checks your installed inventory's persistence, not just the item declaration.

Item definitions do not add shop stock. Add the configured IDs to your own shops or distribution flow as needed, with fresh identity metadata.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| `No such export useItem in resource ox_inventory` on TGIANN or another inventory | Remove ox-only Phone use exports from the item/custom hook; select the correct Phone adapter, save, and restart |
| Old ox closes the inventory but the SIM does nothing | Check the server `ox_inventory:usedItem` event; upstream versions before 2.38.0 do not provide it |
| Editing `config.lua` changes nothing | SQL configuration is enabled; edit the corresponding Phonepanel field and save |
| Phone item is not found | Match the exact item ID, active inventory resource, selected adapter, and the player's actual inventory |
| Item appears but cannot be used | Check the provider's usable/close fields, its framework installation, and competing phone handlers |
| `phone_slot_missing` / `sim_slot_missing` | Check that the provider returns the actual selected slot/item and that the item still exists there |
| `metadata_unsupported` | Check per-item storage, non-stacking rules, TGIANN `hasMetadata`, and the inventory/API version |
| Several devices share an identity | Check stacking and cloned metadata; SMX's character/item-name bridge cannot represent independent copies |
| Physical SIMs are disabled on HEX/ESX | Expected: those adapters cannot store per-item identity metadata |
| Item icon is missing | Check the active image location, exact filename and extension; TGIANN defaults to WebP when `image` is omitted |

If the problem remains, include your Phone version, exact inventory resource/version, framework, active Phonepanel adapter, phone and both SIM definitions, and the relevant server/client error. Remove credentials and unrelated player data before sharing logs.

Provider documentation and Phone source were checked on **2026-09-29**. These examples are not a claim that every provider release or fork has been tested in FiveM; use the verification steps on your installed versions.
