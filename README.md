<p align="center">
  <img src=".github/assets/sky-phone-banner.png" alt="Sky Phone, the free FiveM phone script">
</p>

<h1 align="center">Sky Phone: Free FiveM Phone Script</h1>

<p align="center">
  <strong>The complete, free FiveM phone for ESX, QBCore, and Qbox.</strong><br>
  A premium-grade smartphone experience with 41 built-in apps, LB Phone migration, and first-class custom app support.
</p>

<p align="center">
  <a href="https://www.sky-systems.net/shop/phone#live-demo">
    <img alt="Try the interactive Sky Phone live demo" src=".github/assets/live-demo-button.svg" width="780">
  </a>
</p>

<p align="center">
  <strong>Explore the real phone directly in your browser.</strong><br>
  No download, no FiveM server, and no installation required.
</p>

<p align="center">
  <img alt="Free and open source" src="https://img.shields.io/badge/price-free-22c55e?style=for-the-badge">
  <img alt="GPL 3.0 license" src="https://img.shields.io/badge/license-GPL--3.0-2563eb?style=for-the-badge">
  <img alt="FiveM frameworks: ESX, QBCore, Qbox" src="https://img.shields.io/badge/FiveM-ESX%20%7C%20QBCore%20%7C%20Qbox-f97316?style=for-the-badge">
</p>

<p align="center">
  <a href="https://www.sky-systems.net/shop/phone#live-demo"><strong>Live demo</strong></a>
  &nbsp;&bull;&nbsp;
  <a href="https://github.com/sky-systems/sky_phone/releases/latest"><strong>Download for free</strong></a>
  &nbsp;&bull;&nbsp;
  <a href="https://discord.gg/sky-systems"><strong>Discord support</strong></a>
</p>

---

**Jump to:** [App ecosystem](#one-phone-a-complete-app-ecosystem) · [Compatibility](#compatibility-at-a-glance) · [Installation](#quick-installation) · [LB Phone migration](#lb-phone-migration) · [Custom apps](#external-custom-apps) · [Support](#support-and-community)

Sky Phone is a **free and open-source FiveM phone script** built to give serious roleplay servers the depth, polish, and flexibility normally associated with paid marketplace phones. It combines a modern iPhone-inspired interface, persistent devices and SIM cards, social networks, media, business tools, services, games, and broad framework support in one complete resource.

**Coming from LB Phone?** Sky Phone is designed to replace it. A controlled migration workflow transfers supported player data, while compatibility adapters keep supported LB Phone custom apps available. You can preview the import, migrate when you are ready, retry safely, and roll back migration-created Sky Phone records.

This is not a cut-down free alternative. Sky Phone includes the core experience server owners and players expect from a leading paid FiveM phone, plus full source access, no purchase price, no feature paywalls, and no forced ecosystem lock-in.

The production frontend is included in the published release package, so a normal server installation does not require Node.js or pnpm. GitHub's automatically generated source archives do not contain that build.

## Why Sky Phone stands out

| What matters | What Sky Phone delivers |
| --- | --- |
| **Value** | A complete FiveM phone that is free to download, use, inspect, and customize under GPL-3.0. |
| **Player experience** | A cohesive, responsive Sky UI with light and dark modes, persistent accounts, devices, SIM cards, media, social apps, services, and games. |
| **Feature depth** | 41 built-in apps covering communication, social roleplay, business, navigation, media, utilities, and entertainment. |
| **LB Phone replacement** | Command-only migration with dry runs, progress output, safe retries, and removal of migration-created records. |
| **Custom apps** | Native custom app APIs plus compatibility adapters for LB Phone, 17Movement, High Phone, Quasar Smartphone, and YSeries app contracts. |
| **Server flexibility** | ESX, QBCore, and Qbox support with adapters for popular inventories, voice systems, garages, and housing resources. |
| **Ownership** | Readable source code, automatic database upgrades, customer-owned configuration, and no paid add-on packs required for the complete core experience. |
| **Help when needed** | Installation and configuration help from the Sky-Systems community on the [official Discord](https://discord.gg/sky-systems). |

Sky Phone is built to be the **free FiveM phone you can choose without accepting a downgrade**. Instead of paying first and discovering limitations later, server owners get the complete foundation, the source, migration tooling, and room to extend it from day one.

## One phone, a complete app ecosystem

| Category | Included apps and experiences |
| --- | --- |
| **Communication** | Phone, Messages, Mail, DarkChat, Radio, EasyShare, group messaging, company calls, voice messages, and world payphones |
| **Social** | Picstagram, FlipTok, Feather, Flare, and CrewLink |
| **City & business** | Banking, Billing, Companies, CityMarkt, Local Pages, Garage, Housing, Maps, SkyRide, Weazel News, CityWarn, Crypto, and Health |
| **Media & productivity** | Camera, Photos, Music, Calendar, Clock, Notes, Voice Memos, Calculator, and Weather |
| **Games** | Snake with levels, changing fruit and skins; Memory, Number Merge, Minesweeper, Tower Stack, Sky Flappy, and Neon Drop |
| **Phone system** | App Store, Settings, lock screen, setup assistant, notifications, widgets, folders, passcodes, optional Face ID, multiple wallpapers, and light/dark appearance |

Snake advances one level every 10 points, cycles through six food appearances, and changes between four skins every 30 points. The selected game speed stays unchanged. Restarting a round resets the level and skin; the high score remains saved. Artwork prompts and the existing visual reference are recorded in [the Snake asset directory](frontend/src/assets/img/games/snake/PROMPTS.md).

## Built for players, owners, and developers

| For players | For server owners | For developers |
| --- | --- | --- |
| A polished phone that feels like one connected product | A free replacement for fragmented or expensive phone setups | Full source access and a documented-in-code integration surface |
| Persistent phones, SIMs, accounts, settings, and content | Automatic schema installation and upgrades | Client and server exports for custom app lifecycle and permissions |
| Social, business, media, utility, and game experiences | Framework, inventory, voice, garage, and housing bridges | Compatibility layers for established FiveM phone app ecosystems |
| 15 bundled locales with English fallback | Controlled LB Phone migration with preview and rollback | Vue 3, TypeScript, Pinia, Vite, and reusable Sky UI components |

## Compatibility at a glance

| Layer | Supported options |
| --- | --- |
| **Frameworks** | ESX Legacy, QBCore, Qbox |
| **Inventories** | ak47_inventory, codem-inventory, core_inventory, jaksam_inventory, jpr-inventory, lj-inventory, mf-inventory, one_inventory, origen_inventory, ox_inventory, ps-inventory, qb-inventory, qs-inventory, smx-inventory, tgiann-inventory, hex_4_inventory, and native ESX inventory |
| **Calls** | YACA, PMA Voice, SaltyChat |
| **Radio** | YACA, PMA Voice, SaltyChat |
| **Housing** | RTX Housing, Quasar Housing, TGIANN House, VMS Housing, RX Housing, NoLag Properties, SN Properties, ESX Property, qbx_properties |
| **Garages** | Built-in/custom data and a broad set of popular garage providers configured through the bridge |
| **Custom app contracts** | Sky Phone, LB Phone, 17Movement, High Phone, Quasar Smartphone, YSeries |
| **Languages** | Arabic, Chinese, Czech, Dutch, English, Finnish, French, German, Italian, Polish, Portuguese, Russian, Serbian, Spanish, Swedish |
| **Database** | MySQL or MariaDB through oxmysql |

## Feature highlights

- Modern Sky UI with responsive interactions, light and dark appearance, widgets, folders, notifications, and a full setup flow
- Unique physical handsets with IMEI metadata or one persistent virtual phone per character
- Registered, anonymous, physical, and automatic virtual SIM card modes
- Calls, group messages, reactions, media, contacts, location sharing, money sharing, voice messages, and payphones
- Real account-backed social and service apps with persistent player content
- Camera photos and videos, Gallery, Voice Memos, server music, YouTube playback, and EasyShare
- Banking, invoices, garages, housing, companies, ride hailing, news, marketplace listings, maps, and weather
- Seven built-in games plus an App Store for optional and custom apps
- Automatic database installation and versioned upgrades
- LB Phone migration with preview, progress reporting, safe retries, and rollback support
- Custom app APIs and compatibility adapters for established phone ecosystems
- 15 bundled locales with English fallback throughout the player-facing interface

## Requirements

### Required

| Requirement | Supported options |
| --- | --- |
| **Database** | MySQL or MariaDB |
| **Database bridge** | `oxmysql` |
| **Framework** | ESX Legacy (`es_extended`), QBCore (`qb-core`), or Qbox (`qbx_core`) |
| **Inventory** | Choose one supported adapter from the table below |

| Inventory (configuration value) | Metadata support | Unique Phones | Notes |
| --- | --- | --- | --- |
| `jaksam_inventory` (`jaksam`) | Yes | Yes | Direct per-slot metadata; usable items are registered through jaksam_inventory |
| `qs-inventory` (`qs`) | Yes | Yes | Full per-slot metadata |
| `ps-inventory` (`ps`) | Yes | Yes | QBCore only; uses item `info` metadata |
| `codem-inventory` (`codem`) | Yes | Yes | Full per-slot metadata |
| `tgiann-inventory` (`tgiann`) | Yes | Yes | Per-slot metadata; item definitions must enable `hasMetadata` |
| `core_inventory` (`core`) | Yes | Yes | Full per-slot metadata |
| `jpr-inventory` (`jpr`) | Yes | Yes | QBCore only; uses item `info` metadata |
| `origen_inventory` (`origen`) | Yes | Yes | Full per-slot metadata |
| `ak47_inventory` (`ak47`) | Yes | Yes | Uses per-slot item `info` metadata |
| `one_inventory` (`one`) | Yes | Yes | Full per-slot metadata |
| `ox_inventory` (`ox`) | Yes | Yes | Full per-item phone and physical SIM metadata |
| `mf-inventory` (`mf`) | Yes | Yes | ESX only |
| `smx-inventory` (`smx`) | Yes | Yes | ESX only; one metadata record per configured item name through the player metadata bridge |
| `lj-inventory` (`lj`) | Yes | Yes | QBCore inventory with item `info` metadata |
| `qb-inventory` (`qb`) | Yes | Yes | Uses item `info` metadata |
| `hex_4_inventory` (`hex`) | **No metadata support** | **No, Unique Phones are not possible** | ESX only; Sky Phone automatically disables unique phones and physical SIM cards |
| Native ESX inventory (`esx`) | **No metadata support** | **No, Unique Phones are not possible** | Count-based items; Sky Phone automatically disables unique phones and physical SIM cards |

`hex_4_inventory` and native ESX inventory cannot persist per-item metadata. Sky Phone therefore forces `Config.Phone.Unique` and `Config.Sim.Enabled` to `false` at runtime whenever either adapter is active.

`Config.Bridge.Inventory = "auto"` detects framework-compatible adapters in the table order. This deliberately matches the Sky inventory priority so a dedicated inventory is selected before a compatibility resource it may run beside. You may configure either the short value shown in parentheses or the exact resource name.

The adapters shared with `sky_base` are implemented locally inside Sky Phone. Installing or starting `sky_base` is not required; Sky Phone remains a standalone resource.

For configuration parity with `sky_base`, `qb-inv` is accepted as an alias for `qb`, while `qbox` selects the Qbox-native `ox_inventory` adapter.

### Voice

Phone calls support:

- YACA
- PMA Voice
- SaltyChat

The Radio app supports:

- YACA
- PMA Voice
- SaltyChat

Start the selected voice resource before Sky Phone.

### Optional services

- FiveManage V3 Media API for Camera uploads, videos, Voice Memos, and remote Gallery deletion
- GIPHY API for GIF search
- Supported Garage and Housing resources when those apps should use external provider data

## Quick installation

> **Read this first:** [PHONE_INSTALLATION_IMPORTANT.md](sky_phone/PHONE_INSTALLATION_IMPORTANT.md) contains the required item, shop, startup-order, metadata, multi-device, and troubleshooting steps.

1. Download and extract the latest published [Sky Phone release](https://github.com/sky-systems/sky_phone/releases/latest). Do not use GitHub's automatically generated "Source code" archives for a server installation because they do not contain the built frontend.
2. Copy the included resource into your FiveM resources directory and keep its folder name `sky_phone`.
3. Start `oxmysql`, your framework, inventory, and voice resource before Sky Phone.
4. Review `sky_phone/config/config.lua` and `sky_phone/config/media.lua`.
5. Add the required [inventory items and their images](#inventory-items). With **ox_inventory**, also remove the existing NPWD phone handler as described below.
6. Add `ensure sky_phone` to `server.cfg`.
7. Restart the server and watch the console for warnings.

> [!WARNING]
> **Using ox_inventory? Removing its NPWD phone handler is a required installation step when that block exists.**
> Changing `data/items.lua` alone is not enough. Follow [Remove the NPWD phone handler](#1-remove-the-npwd-phone-handler-required) before testing the phone item, even if NPWD is stopped or not installed.

Example start order:

```cfg
ensure oxmysql
ensure es_extended
ensure ox_inventory
ensure pma-voice
ensure sky_phone
```

Replace the example framework, inventory, and voice resources with the providers used by your server.

Sky Phone creates and upgrades its database tables automatically. A manual SQL import is normally not required.

### How players open the phone

- Give the player the item configured in `Config.Phone.Item` (default: `phone`).
- Players can use that inventory item or press the configured keybind (default: `F1`).
- The keybind still verifies server-side that the player owns a configured phone item; it does not bypass inventory ownership.
- A SIM card is **not required to open or use the phone itself**. With `Config.Sim.Enabled = true`, only cellular features such as calls and messages require an inserted SIM.

## Configuration

Customer settings are organized in:

```text
sky_phone/config/config.lua
sky_phone/config/media.lua
```

The files contain clearly separated sections for:

| Section | Purpose |
| --- | --- |
| `Config.Bridge` | Framework, inventory, language, callback timeout, and debug mode |
| `Config.CommandPermissions` | Fixed groups for the admin panel, test data, verification commands, and social moderation |
| `Config.Phone` | Phone item, movement, unique-device mode, and development command |
| `Config.Sim` | Physical or virtual SIM behavior and number formatting |
| `Config.Calls` / `Config.Radio` | Voice providers, call behavior, radio limits, and permissions |
| `Config.Payphones` | Payphone pricing, detected props, validation, and custom spawned locations |
| `Config.Animations` | Phone prop, animations, and portrait/landscape transforms |
| App sections | Limits and behavior for every built-in app |
| `Config.Server` | Stable password and passcode peppers |
| `Config.Companies` | Company directory, jobs, services, and permissions |
| `Config.Media` (`config/media.lua`) | FiveManage, GIPHY, uploads, and Gallery imports |
| `Config.Music` | Server music library and playlist limits |
| `Config.Migrations` | Manual LB Phone migration domains |
| `Config.WeazelNews` | Editorial jobs, categories, and article limits |

Restart `sky_phone` after changing Lua configuration.

### In-game phone configurator

Set the switch at the beginning of `config/config.lua` to use SQL-backed configuration:

```lua
Config.PhoneConfigurator = {
    Enabled = true,
}
```

When enabled, the generated `source/shared/config_default.lua` is the shipped first-run baseline.
The frontend build recreates this file from `config.lua` and the server-only `media.lua`; do not edit
the generated snapshot directly. Sky Phone creates the `sky_phone_configurator` table automatically,
loads its saved values before framework and phone
modules initialize, and exposes the editor through `/phonepanel`. Nothing autosaves: stage changes
in the Phone Configurator tool and press the green check. Saving verifies both SQL payloads and then
applies the new server, client, media, app, item, command, provider, animation, and UI values through
Sky Phone's internal runtime refresh. It does not execute a resource restart command.

Every configurable `Config.*` value from `config.lua`, including server-only sections, and every
value from `Config.Media` is discovered automatically. The bootstrap switch and
`Config.CommandPermissions` intentionally remain file-owned: the switch decides whether SQL
configuration is loaded, while permissions must remain authoritative outside the panel. The fixed
permission table is never displayed or overwritten by the Phone Configurator, and its stable keys do
not change when their commands are renamed in the panel. Lists, nested objects, vectors,
and numeric-keyed Lua tables use structured editors instead of raw JSON. Shipped schema rows stay
editable but cannot be renamed, converted, or removed. Every list and table still accepts any number
of additional rows; administrator-added rows remain removable. Company job keys are intentionally
fully removable because `Config.Companies.Definitions` is a freely managed job collection.
Cell tower entries and their offline app/action policies are also fully editable and removable.

ESX and QBCore use the groups listed in `Config.CommandPermissions`. Qbox checks the configured ACE
objects first and then its framework groups. The standard Qbox `permissions.cfg` grants the `admin`
ACE to `group.admin`, so an identifier assigned to `group.admin` can open `/phonepanel` with the
shipped `phonepanel` permission list. Restart `sky_phone` after changing fixed permissions.

Media API keys and server peppers are never returned in plaintext to the NUI. Existing secrets are
shown only as configured and are replaced only when an administrator enters a new value.

### Cell towers and social moderation

`Config.CellTowers.Enabled` switches the coverage simulation on or off. The defaults include 18
virtual towers across Los Santos, mainland towns and Cayo Perico. Manage positions, ranges and
app availability through **Phonepanel > Phone Configurator > Cell towers**.
**Phonepanel > Social media** also lets authorized administrators find and remove Feather,
FlipTok, Picstagram and Weazel News posts with confirmation and an audit entry.
See [cell tower configuration and the default offline app list](CELL_TOWERS.md).

### Language

Available locales:

| Language | Locale | Language | Locale | Language | Locale |
| --- | --- | --- | --- | --- | --- |
| Arabic | `ar` | Chinese | `cn` | Czech | `cz` |
| Dutch | `nl` | English | `en` | Finnish | `fi` |
| French | `fr` | German | `de` | Italian | `it` |
| Polish | `pl` | Portuguese | `pt` | Russian | `ru` |
| Serbian | `rs` | Spanish | `es` | Swedish | `se` |

Regional codes resolve to their base language. The aliases `zh`, `cs`, `sr`, and `sv` select `cn`, `cz`, `rs`, and `se`.

Select the language near the top of `config.lua`:

```lua
Config.Bridge.Locale = "en"
```

or:

```lua
Config.Bridge.Locale = "de"
```

Locale files are stored separately:

```text
sky_phone/config/locales/en.lua
sky_phone/config/locales/de.lua
```

Every locale uses the complete English structure as a fallback, so newly introduced keys never leave the interface without text.

### Debug output

```lua
Config.Bridge.Debug = false
```

When enabled, Sky Phone prints debug and informational messages. Warnings and errors are always shown.

The short LB Phone detection notice also remains visible when debug mode is disabled.

On every resource start, Sky Phone compares the `version` in `fxmanifest.lua` with the tag of the
latest published [GitHub release](https://github.com/sky-systems/sky_phone/releases/latest). The
server console reports whether the installed version is current and shows the release link when an
update is available. A failed GitHub request is reported but does not prevent the phone from starting.

## Security values

Face ID is optional during device setup and can be enabled or disabled later under **Settings → Passcode & Security**. A device passcode is required as a fallback, and changing Face ID requires that passcode. The server binds Face ID to the character identifier returned by the framework at enrollment and checks it against the current holder of that physical phone. No camera or biometric data is collected. Changing the SIM or Sky Cloud account does not transfer the enrollment; removing the passcode, an admin passcode reset, or a factory reset clears it. The nullable enrollment column is added automatically by the runtime migration.

Sky Phone ships with stable generated defaults in `Config.Server`:

```lua
Config.Server = {
    PasscodePepper = "...",
    FlipTokPasswordPepper = "...",
    PicstagramPasswordPepper = "...",
}
```

For a production server, replace them with your own long, random, different values before players create passcodes or social accounts.

Important:

- Keep the values private and stable.
- Changing `PasscodePepper` invalidates existing device passcodes.
- Changing a social-app pepper invalidates existing passwords for that app.
- Do not replace these values during routine updates.

Sky Cloud logins are in-character credentials for the roleplay phone. Players must never reuse a
real-world password. FlipTok and Picstagram passwords are stored as salted hashes using their
configured peppers.

The server-only block is evaluated only on the server. Because the project uses a customer-requested single configuration file that is also present in the client resource package, protect access to your distributed resource files if these values must remain strictly secret.

## Inventory items

The release includes an image for each default item in `sky_phone/config/images/`:

| Item | Image |
| --- | --- |
| `phone` | `phone.png` |
| `sky_phone_sim_registered` | `sky_phone_sim_registered.png` |
| `sky_phone_sim_anonymous` | `sky_phone_sim_anonymous.png` |

Copy these PNG files into your inventory's item image directory. For the default `ox_inventory` image path, use `ox_inventory/web/images/`. Other inventories use their own image directory; the QBCore-style definitions below already name the matching files. If you change an item name in `Config.Phone` or `Config.Sim`, give its image the same name expected by your inventory.

### ox_inventory

#### 1. Remove the NPWD phone handler (required)

> [!WARNING]
> **Remove the old NPWD handler before using Sky Phone.** It can intercept the `phone` item even when NPWD is stopped or not installed. Updating the item definition in `data/items.lua` does not remove this separate handler.

Search the **entire `ox_inventory` resource** for `Item('phone'` (or `Item("phone"` if the file uses double quotes). Check these locations:

- Current releases: `ox_inventory/modules/items/client.lua`
- Older releases: `ox_inventory/items/client.lua`

**REMOVE the following complete NPWD block if present, from `Item('phone', ...` through its final `end)`. This is code to delete, not code to add:**

```lua
-- REMOVE this entire NPWD block if present. Do not add it.
Item('phone', function(data, slot)
    local success, result = pcall(function()
        return exports.npwd:isPhoneVisible()
    end)

    if success then
        exports.npwd:setPhoneVisible(not result)
    end
end)
```

Keep the `phone` item definition in `ox_inventory/data/items.lua`; remove only the NPWD handler above. If no matching NPWD handler exists, continue with the item definitions.

#### 2. Add the inventory items

Default entries in `ox_inventory/data/items.lua` for unique phones with physical SIM cards. The phone includes an **Eject SIM** context button ([Ox item buttons](https://overextended.dev/ox_inventory/Guides/creatingItems)):

```lua
["phone"] = {
    label = "iFruit Phone",
    weight = 200,
    stack = false,
    close = true,
    consume = 0,
    client = { export = "sky_phone.UsePhoneItem" },
    buttons = {
        {
            label = "Eject SIM", -- Translate this static inventory label, e.g. "SIM entfernen".
            action = function(slot)
                exports.sky_phone:EjectSimFromSlot(slot)
            end,
        },
    },
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

Do not configure an LB Phone client event or client export. The shown Sky Phone exports are slot-aware and revalidate the selected item on the server. The server-side inventory registration remains as a fallback for item definitions without `client.export`; do not configure both handlers.

**Restart the complete server after both changes**, then verify that using the `phone` item opens Sky Phone. Recheck the NPWD handler after updating or replacing ox_inventory, as an update may restore it.

The server registers `Config.Phone.Item` as usable for every supported inventory adapter: `ak47`, `codem`, `core`, `jaksam`, `jpr`, `lj`, `mf`, `one`, `origen`, `ox`, `ps`, `qb`, `qs`, `smx`, `tgiann`, `hex`, and `esx`. Resource startup fails visibly if the selected adapter or its resource is unavailable.

The `hex` and `esx` adapters use ESX's count-based item API, which cannot persist per-item phone or physical SIM metadata. Sky Phone automatically forces `Config.Phone.Unique = false` and `Config.Sim.Enabled = false` while either adapter is active. `auto` selects `hex` when `hex_4_inventory` is started and otherwise falls back to `esx` on an ESX server when no metadata-capable inventory is detected.

### QBCore-style item tables

- Set the phone's `unique` value to match `Config.Phone.Unique`.
- Set `useable = true` and `shouldClose = true`.
- Physical SIM items must always be unique.
- SIM items are not required when `Config.Sim.Enabled = false`.

Example for `qb-inventory`, `lj-inventory`, `ps-inventory`, and `jpr-inventory`:

```lua
phone = {
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

sky_phone_sim_registered = {
    name = "sky_phone_sim_registered",
    label = "Registered SIM",
    weight = 5,
    type = "item",
    image = "sky_phone_sim_registered.png",
    unique = true,
    useable = true,
    shouldClose = true,
},

sky_phone_sim_anonymous = {
    name = "sky_phone_sim_anonymous",
    label = "Anonymous SIM",
    weight = 5,
    type = "item",
    image = "sky_phone_sim_anonymous.png",
    unique = true,
    useable = true,
    shouldClose = true,
},
```

For `tgiann-inventory`, set `hasMetadata = true`, `useable = true`, and `shouldClose = true` on all three item definitions. Follow the inventory's own item schema for the remaining adapters; the required behavior is always the same: a unique phone or physical SIM must occupy its own slot and its metadata table must survive moving, dropping, storing, and trading the item.

### Unique Phones and metadata

Sky Phone owns the metadata values and writes them server-side. Do not pre-generate IMEIs or phone numbers in item definitions:

| Item | Metadata written by Sky Phone |
| --- | --- |
| Phone | `imei`; when a SIM is inserted, also `sim_id`, `phone_number`, and `formatted_number` |
| Physical SIM | `sim_metadata_version`, `sim_id`, `phone_number`, `formatted_number`, `sim_type`, and registration details where applicable |

When a metadata-capable phone item is used for the first time, Sky Phone reserves an IMEI and writes it back to that exact slot. Existing metadata is preserved. The adapter then reads the slot again and rejects the operation if the inventory did not persist the requested values.

Sky Phone automatically registers IMEI and phone-number tooltip labels for `ox_inventory`, `tgiann-inventory`, and `one_inventory`, using `Config.Bridge.Locale`. Other inventories need the configuration described below. A new phone has no IMEI until it is initialized; its phone number appears once a physical or automatic SIM is assigned. With `Config.Phone.Unique = false`, identity and number belong to the character and are not written to the phone item.

For reliable Unique Phones:

- Set `Config.Phone.Unique = true`.
- Make the phone item non-stackable/unique. Every phone slot must contain exactly one item.
- If `Config.Sim.Enabled = true`, make both physical SIM items non-stackable/unique and metadata-capable too.
- Do not use inventory conversion, admin, crafting, or shop scripts that strip item metadata. Copying an item with its metadata also copies its IMEI; duplicated IMEIs are reported in the server console.
- When changing inventory systems, migrate the complete item metadata table. Without the old `imei`, the next use creates a new device identity and does not automatically attach the old handset data.

With `Config.Phone.Unique = false`, the handset identity is stored once per framework character instead of on each phone item. The phone item may stack. Physical SIMs still require per-item metadata, so `Config.Sim.Enabled` must be `false` on `hex` and native `esx`.

### Inventory tooltip setup

Persisting item metadata and displaying it are separate inventory features. Sky Phone writes the values through every metadata-capable bridge; the inventory controls which fields its UI renders. The following covers all bundled adapters, based on the linked public documentation/source. Inventory versions and custom UI forks can differ.

| Inventory | IMEI / number display | SIM context button |
| --- | --- | --- |
| [Ox](https://overextended.dev/ox_inventory/Functions/Client#displaymetadata) | Automatic `displayMetadata` labels | `buttons` in the phone definition above |
| [TGIANN](https://tgiann.gitbook.io/tgiann/scripts/tgiann-inventory/exports/client) | Automatic `DisplayItemMetadata` labels for the configured phone and SIM items; enable `hasMetadata` | `buttons`; example below |
| [One Inventory](https://onestudios.gg/docs/client/exports) | Automatic `ShowItemMetadata` labels for the configured phone and SIM items | `RegisterItemButton`; example below |
| [Jaksam](https://documentation.jaksam-scripts.com/jaksam-inventory/guides/metadata) | Add `displayFields`; example below | `contextActions`; example below |
| [Core](https://docs.c8re.store/core-inventory/configuration#metadata-display) | Add `ShownMetadata` entries and enable hover information | No custom item-button API verified in the public exports |
| [AK47](https://docs.menanak47.com/multi-framework/ak47_inventory/templates/tooltip) | Enable the fields in `Config.ShowValueFromItemInfo` | No custom item-button API verified in the public exports |
| [QB](https://github.com/qbcore-framework/qb-inventory/blob/main/html/app.js) | Current stock UI lists `info` fields automatically unless `info.display = false`; labels come from the inventory UI | No stock per-item custom-button API |
| [PS](https://github.com/Project-Sloth/ps-inventory/blob/main/html/js/app.js), [LJ](https://github.com/loljoshie/lj-inventory/blob/main/html/js/app.js) | Add the phone/SIM fields to `FormatItemInfo`; example below | No stock per-item custom-button API |
| [Quasar](https://www.quasar-store.com/docs/advanced-inventory/commands-and-exports) (`qs`) | Values persist in `info`; UI formatting depends on the installed version. No label-registration API verified | No custom item-button contract verified in the public docs |
| [CodeM mInventory](https://codem.gitbook.io/codem-documentation/m-series/essentials/minventory-remake/exports-and-commands/client-exports) (`codem-inventory`) | Values persist; configure the installed inventory's tooltip UI. No label-registration API verified for this resource | No custom item-button contract verified for this resource |
| [JPR](https://joaos-organization-3.gitbook.io/jpresources-documentation/installation/inventory/events-and-commands) | Values persist in `info`; configure the installed inventory's tooltip UI. No label-registration API verified | No custom item-button contract verified in the public docs |
| [Origen](https://docs.origennetwork.com/scripts/origen_inventory/exports) | Has a metadata viewer via `displayMetadata(slot)`, not Ox-style label registration | `buttons` with `action(slot)`; example and integration sources below |
| [MF](https://github.com/meta-hub/mf-inventory/wiki/Examples) | Values persist; no public tooltip-label registration API verified | No custom item-button contract verified in the public docs |
| SMX | The bridge stores metadata per item name in character metadata; no per-slot hover integration verified | No custom item-button contract verified |
| `hex_4_inventory`, native ESX | No per-item metadata; unique phones and physical SIMs are disabled | Physical SIM removal unavailable |

The automatic labels use the existing translations in all 15 phone locales, including regional aliases and English fallback. They are registered again after the selected inventory restarts. Repeated Configurator updates do not append duplicate labels. If you change the locale, restart the inventory and Sky Phone (or reconnect clients): some inventories can append labels but cannot replace/remove earlier labels. Static item definitions and inventory-owned tooltip formatters use that inventory's own translations.

CodeM's newer [Supreme Inventory documentation](https://codem.gitbook.io/codem-documentation/supreme-series/essentials/inventory/exports/client-exports) describes `codem-inventoryv2`, a different resource from the bundled `codem` adapter. Its Ox compatibility exports must not be assumed to exist on `codem-inventory`.

#### Jaksam: hover fields and SIM button

Merge these fields into your phone in `jaksam_inventory/_data/items.lua`; retain its other properties. Add the `phone_number` display field to both physical SIM definitions too. Change the static labels to your inventory language. [Metadata](https://documentation.jaksam-scripts.com/jaksam-inventory/guides/metadata), [context actions](https://documentation.jaksam-scripts.com/jaksam-inventory/guides/context-actions).

```lua
displayFields = {
    { field = "imei", label = "IMEI: ${value}" },
    { field = "phone_number", label = "Phone number: ${value}" },
},
contextActions = {
    {
        label = "Eject SIM",
        icon = "bi-sim",
        callback = function(inventoryId, slotIndex)
            exports.sky_phone:EjectSimFromSlot(slotIndex, inventoryId)
        end,
    },
},
```

Pass `inventoryId` through: Jaksam actions can also refer to a stash or vehicle inventory. Sky Phone checks that it is the acting player's inventory before resolving the slot. The bridge accepts Jaksam's numeric and `SLOT-N` slot representations.

#### Core: hover fields

In Core's configuration, set `ShowInformationsOnHover = true` and add these entries to the existing `ShownMetadata` table, preserving its other entries. If Core's in-game configuration editor is enabled, make the equivalent changes there; Core then ignores file-based configuration. [Core configuration](https://docs.c8re.store/core-inventory/configuration#metadata-display).

```lua
["imei"] = "IMEI",
["phone_number"] = "Phone number",
```

#### AK47: hover fields

Add the two flags to AK47's configuration and translate `imei` and `phone_number` in its locale file. Existing tooltip flags remain enabled. [AK47 tooltip configuration](https://docs.menanak47.com/multi-framework/ak47_inventory/templates/tooltip).

```lua
Config.ShowValueFromItemInfo.imei = true
Config.ShowValueFromItemInfo.phone_number = true
```

#### PS / LJ: hover formatter

In the stock `html/js/app.js`, place the following inside `FormatItemInfo(itemData, dom)`, after its tooltip positioning code and before its existing item-specific branches. Match the item names to your configuration and translate the two labels in your inventory UI. Values are inserted as text, so metadata cannot inject HTML. [PS source](https://github.com/Project-Sloth/ps-inventory/blob/main/html/js/app.js), [LJ source](https://github.com/loljoshie/lj-inventory/blob/main/html/js/app.js).

```javascript
const phoneItems = ['phone', 'sky_phone_sim_registered', 'sky_phone_sim_anonymous'];
if (itemData && phoneItems.includes(itemData.name)) {
    const info = itemData.info || {};
    $('.item-info-title').empty().append($('<p>').text(itemData.label));
    const description = $('.item-info-description').empty();
    if (itemData.description) description.append($('<p>').text(itemData.description));
    for (const [key, label] of [['imei', 'IMEI'], ['phone_number', 'Phone number']]) {
        if (info[key] != null && info[key] !== '') {
            description.append($('<p>').append(
                $('<strong>').text(label + ': '), $('<span>').text(String(info[key]))
            ));
        }
    }
    return;
}
```

### Remove a SIM from the inventory

With `Config.Sim.Enabled = true`, the client export `exports.sky_phone:EjectSimFromSlot(slot)` removes the physical SIM from the clicked phone and returns `{ success = true }` or `{ success = false, error = "..." }`. It also displays a notification in the configured phone language. `slot` can be a slot number/string or an item payload containing `slot` and optionally `metadata.imei`. `GetInventoryLabels()` returns localized `imei`, `phone_number`, and `eject_sim` labels for custom client integrations.

The server resolves the phone and inserted SIM from its own inventory/database state. The phone must be in the player's inventory; move it out of a stash first. The action works with a closed or locked handset and never opens or unlocks its contents. With multiple unique phones it targets the clicked handset, independently of the currently open phone. In non-unique mode, any owned phone refers to the character's device. Automatic virtual SIMs cannot be ejected.

A successful action returns one SIM item, preserves its number and registration data, clears the handset's SIM/number metadata, ends calls on that SIM, and refreshes the phone. A full inventory or failed metadata write leaves the SIM in the handset. Repeated/concurrent requests are guarded. Inventories without a verified custom-button contract can still use **Phone Settings → General → Eject SIM**.

#### TGIANN button

Merge this field into the configured phone item; retain `hasMetadata = true`, `useable = true`, and `shouldClose = true`. Both physical SIM items also need `hasMetadata = true`. [TGIANN item buttons](https://tgiann.gitbook.io/tgiann/scripts/tgiann-inventory/guides/creating-items).

```lua
buttons = {
    {
        label = "Eject SIM",
        action = function(slot)
            exports.sky_phone:EjectSimFromSlot(slot)
        end,
    },
},
```

#### One Inventory button

One Inventory's item-button editor can call the client export `sky_phone.EjectSimFromSlot` with its item payload. Alternatively, put the following in a client integration resource started after `one_inventory` and `sky_phone`. Use exactly one registration method. Replace `phone` if you use another item name. Export registrations are temporary; rerun this integration after a resource restart. [One client exports](https://onestudios.gg/docs/client/exports).

```lua
local registered = false
local function registerSimButton()
    if registered or GetResourceState("one_inventory") ~= "started"
        or GetResourceState("sky_phone") ~= "started" then return end
    registered = exports.one_inventory:RegisterItemButton(
        "phone", exports.sky_phone:GetInventoryLabels().eject_sim,
        function(payload)
            exports.sky_phone:EjectSimFromSlot(payload)
        end
    )
end

AddEventHandler("onClientResourceStart", function(resource)
    if resource == "one_inventory" or resource == "sky_phone" then registerSimButton() end
end)
AddEventHandler("onClientResourceStop", function(resource)
    if resource == "one_inventory" then registered = false end
end)
CreateThread(registerSimButton)
```

#### Origen button

Merge this into the phone definition in `origen_inventory/data/items.lua`. Origen documents the [custom-item `buttons` field](https://docs.origennetwork.com/scripts/origen_inventory/custom); the client `action(slot)` form is shown in the **origen_inventory** tabs of Prodigy Studios' published [Notebook integration](https://docs.prodigyrp.net/civ/prp-notebook/installation) and [Drug Drops integration](https://docs.prodigyrp.net/crime/prp-drug-drops/installation.html). The example below follows those integrations.

```lua
buttons = {
    {
        label = "Eject SIM",
        action = function(slot)
            exports.sky_phone:EjectSimFromSlot(slot)
        end,
    },
},
```

Origen's separate `displayMetadata(slot)` export opens its metadata viewer; it does not accept Ox's `displayMetadata(key, label)` arguments. Keep the existing phone use handler so using the item continues to open the phone. The bridge prefers the canonical `getItems(source)` export and keeps a fallback for legacy `getInventoryItems(source)`, while using the slot-before-info `addItem(source, item, amount, slot, info)` / `removeItem(source, item, amount, slot)` signatures from the [current export reference](https://docs.origennetwork.com/scripts/origen_inventory/exports), also used by the published [AK47 integration](https://github.com/MenanAk47/ak47_lib/blob/main/integration/server/inventory.lua). The current Phone adapter supports the documented `origen_inventory` resource. `origen_inventoryv2` is a separate package and is not a drop-in alias; a separately named V2 resource therefore needs its own verified adapter. If a V2 installation logs missing `registerHook`, `SelectStash`, or `LoadInventory` exports, fix that provider's package/resource-name contract first instead of copying V1 files or adding compatibility exports to Sky Phone.

#### Other custom context menus

Custom client menus can call the same export, or dispatch the local event `TriggerEvent("sky_phone:sim:eject-item", slot, inventoryId)`. Do not call the existing Settings NUI callback from an inventory button: that callback deliberately targets the open, unlocked phone session.

## Phone and SIM modes

The two mode switches are independent:

```lua
Config.Phone.Unique = true
Config.Sim.Enabled = true
```

| Phone mode | Behavior |
| --- | --- |
| `Unique = true` | Every phone item receives its own IMEI. Settings, apps, local data, linked account, and SIM move with the item. The item must not stack. |
| `Unique = false` | Every framework character receives one persistent virtual device. Any configured phone item opens that device. The item may stack. |

With unique phones, using an inventory item selects that exact handset whenever the inventory reports its slot. The F1 hotkey reopens the last selected IMEI; if no handset has been selected yet, the server chooses the first concrete phone slot. These opening paths resolve the device server-side. The optional inventory SIM button sends a slot that the server validates separately.

| SIM mode | Behavior |
| --- | --- |
| `Enabled = true` | The phone opens with or without a SIM. A registered or anonymous physical SIM item is required only for cellular service such as calls and messages. |
| `Enabled = false` | Sky Phone creates a persistent automatic number for devices without a SIM. Physical SIM items are not required. |

When changing these modes on an existing production server, restart the resource and test with a copy of the database first. The first phone used after switching to non-unique mode may adopt an existing valid IMEI so its local data is preserved.

## Database

Runtime migrations create and update the Sky Phone schema automatically.

For hosts that require a manual fresh installation, import:

```text
sky_phone/sql/install.sql
```

Keep runtime migrations enabled after importing the SQL file because they remain responsible for future upgrades.

A Sky Cloud account is optional. Devices without an account retain local settings and supported local app data. Linking an account synchronizes supported data across linked devices.

## Media and uploads

Configure FiveManage in the server-only `sky_phone/config/media.lua` file:

```lua
Config.Media.FiveManage.ApiKey = "your-fivemanage-v3-media-token"
```

Without a valid token:

- Camera uploads are disabled
- Video uploads are disabled
- Voice Memo uploads are disabled
- FiveManage Gallery imports are unavailable

Configure GIF search with:

```lua
Config.Media.GiphyApiKey = "your-giphy-api-key"
```

Gallery import websites are configured under `Config.Media.Import.Websites`. Direct URLs are accepted only when their HTTPS hostname matches the configured allowed hosts.

## Music

Place server-owned audio files anywhere below:

```text
sky_phone/config/music/
```

Supported audio formats:

- OGG
- MP3

Optional artwork may use:

- WEBP
- PNG
- JPG
- JPEG

Configure each track in `Config.Music.Tracks`:

```lua
Config.Music.Tracks = {
    {
        Id = "night-drive",
        Title = "Night Drive",
        Artist = "Sky Records",
    },
}
```

Name the audio and artwork files after the stable track ID, for example:

```text
night-drive.ogg
night-drive.webp
```

Restart Sky Phone after adding files. A frontend rebuild is not required.

Players may also add public YouTube video links to their personal music library.

## Voice and Radio

### Calls

```lua
Config.Calls.VoiceProvider = "pma"
```

Supported values:

- `yaca` or `yaca-voice`
- `pma` or `pma-voice`
- `saltychat` or `salty`

YACA supports calls, payphone calls, provider-backed speaker mode, and real microphone mute. SaltyChat supports provider-backed speaker mode. PMA Voice keeps speaker and mute controls unavailable.

### Radio

```lua
Config.Radio.VoiceProvider = "auto"
```

Automatic selection checks YACA, PMA Voice, and SaltyChat. Restricted frequency ranges and job access are configured in `Config.Radio.LockedChannels`.

Radio display-name permissions are configured in `Config.Radio.DisplayName.AllowedJobs`.

## Discord logging

Configure separate app/action webhooks and an optional avatar URL in the
server-only `config/WebHooks.lua` or through **Phonepanel > Webhooks**. See the
[logging setup and coverage](sky_phone/LOGGING.md), including prepared SkyPic support.

## Payphones

Sky Phone automatically detects nearby world props listed in `Config.Payphones.Props`; GTA V payphones do not need configured coordinates. Pricing, payment account, prop models, and validation distances are configured under `Config.Payphones`.

Use `CustomLocations` only when Sky Phone should spawn additional payphone props at custom positions:

```lua
Config.Payphones.CustomProp = "prop_phonebox_01b"
Config.Payphones.CustomLocations = {
    vector4(123.45, 678.90, 21.0, 90.0),
}
```

`CustomProp` must also be listed in `Config.Payphones.Props`. Each custom position uses `vector4(x, y, z, heading)`.

## Commands

`Config.Phone.Keybind` defaults to `F1` and can be rebound in FiveM's key bindings. Set it to `false` to disable the phone hotkey.

| Command | Where | Purpose |
| --- | --- | --- |
| `/phone` | In game | Opens the development phone command when `Config.Phone.DevelopmentCommand` is enabled |
| `/phonetestdata` | In game | Creates customer-scoped test data when `Config.TestData.Enabled` is enabled |
| `/fliptokverify <@handle> [on\|off]` | In game | Toggles or sets FlipTok verification for configured admin groups |
| `/picstagramverify <@handle> <on\|off>` | In game | Sets Picstagram verification for configured admin groups |
| `skyphone:migrate lb-phone dry` | Server console | Previews the LB Phone migration |
| `skyphone:migrate lb-phone` | Server console | Imports enabled LB Phone domains |
| `skyphone:migrate lb-phone force` | Server console | Re-runs enabled domains idempotently |
| `skyphone:migrate lb-phone remove` | Server console | Removes imported Sky Phone records and migration markers |

Command names and admin groups for the social apps are configurable.

Disable test data on production servers:

```lua
Config.TestData.Enabled = false
```

## LB Phone migration

Sky Phone detects supported LB Phone database tables during startup and prints a short notice. Detection never starts a migration automatically.

Recommended workflow:

1. Create a database backup.
2. Run the preview:
   `skyphone:migrate lb-phone dry`
3. Review the domain summaries.
4. Run the import:
   `skyphone:migrate lb-phone`
5. Restart and verify the migrated accounts and apps.

The importer:

- Reads LB Phone source tables without modifying them
- Supports preserved `_lb` tables created by sd-phone migrations
- Records per-domain completion markers
- Can be retried safely with `force`
- Can remove migration-created Sky Phone data with `remove`
- Reports unsupported source records instead of forcing them into incompatible Sky Phone structures

For Picstagram, FlipTok, and Feather, the active LB Phone login is attached to the migrated player's Sky Cloud account. If LB Phone has no active-login row, the oldest mapped profile is used. Additional social profiles remain separate, and a normal import automatically runs versioned ownership repairs for older Sky Phone migrations.

Supported domains include devices, settings, alarms, contacts, blocked numbers, calls, messages, photos, notes, wallet, voice memos, Picstagram, Mail, map markers, compatible DarkChat data, FlipTok, Feather, and Flare data from LB Tinder, including profiles, photos, swipes, and mutual matches.

The migration command is server-console only.

## Garage, Housing, and Companies

### Garage

Set `Config.Garage.VehicleKeySystem` (default: `auto`) to give vehicle keys after a valet delivery. The same setting is available under Garage in the Phone Configurator.

Select the provider under `Config.Garage.System`. Vehicle images use the configured CDN template with an icon fallback when no image is available.

For MSK Garage, select `msk` (or use `auto`) and start `msk_garage` before `sky_phone`.
With the Phone Configurator enabled, set `Garage.System` to `msk` in `/phonepanel` instead.
Automatic detection checks `jg-advancedgarages` before `msk_garage`; select `msk` explicitly if both run.
The adapter uses MSK's standard framework vehicle schema: ESX `owned_vehicles` / `stored`,
or QBCore and Qbox `player_vehicles` / `state` (MSK 5.6+). It reads the garage ID,
custom vehicle name, properties and fuel, and changes only the parked flag for valet orders.
MSK treats unparked vehicles as impound candidates; the phone shows them as out and only
delivers parked, personally owned vehicles. Cancelled or failed deliveries restore the parked flag.
With `msk_fuel`, valet preserves liters; the fuel percentage is available when that resource
configures a tank capacity for the model. Otherwise the percentage is shown as unavailable.
See the [MSK database contract](https://docu.msk-scripts.de/docs/msk_garage/database/).

### Housing

Select `rtx`, `quasar`, `tgiann`, `vms`, `rx`, `nolag`, `sn`, `esx_property`, or `qbx_properties` under `Config.Housing.System`. Automatic mode uses `Config.Housing.AutoPriority` and keeps the existing `esx_property` and `qbx_properties` defaults ahead of newly supported providers. Select a provider explicitly when multiple housing resources are running. Each bridge exposes only the capabilities supported by the documented provider API. The TGIANN bridge expects `tgiann-core` to start before `tgiann-house`, lists server-authorized owner properties, and supports entrance waypoints; TGIANN does not publish stable external contracts for keyholders, lock controls, CCTV, or live garage status.

### Companies

Company jobs, public profiles, service numbers, services, permissions, locations, and default
availability are configured under `Config.Companies.Definitions`. Definitions are not limited to the
shipped jobs: add any number of company IDs in the in-game configurator and fill the freely
configurable `Job` value in the automatically generated full company template. Existing job keys can
also be removed; the remaining Companies settings stay available as normal individual fields.

Company names are limited to 32 Unicode characters in Lua and the Phone Configurator; Discover
wraps names instead of truncating them. Shorten any existing longer names before restarting.
Set each definition's `CoverUrl` to an HTTPS image URL in the configuration or Phone Configurator
(an empty value hides the cover). Set `LogoUrl` to the company logo HTTPS URL in the same definition. Both images are
admin-managed; job members cannot change them through Companies. Previously uploaded job
logos and covers are no longer used automatically.

Changes to `Description`, `District`, `LocationLabel`, and `Address` in the Phone Configurator
also update existing company profiles. Each profile stores the last applied configuration so
manager edits survive unrelated panel saves and resource restarts; changing a field in the panel
overrides that field only. On the first restart after this update, the automatic schema migration
adds `config_profile` and replaces remaining stock profile texts with the configured values.
Existing custom texts are preserved during this initial reconciliation.

Opening hours use 24-hour `HH:MM` input. `ServiceLine.CanMessage` enables company SMS and defaults
to `true` for new companies and the shipped service lines. On the first restart after this update,
the Phone Configurator enables SMS once for the stored `ambulance`, `fire`, `mechanic`, and `taxi`
definitions; later admin changes are preserved. App requests still require the company and the
selected public service to accept requests. A registered SIM is required when `Config.Sim.Enabled`
is enabled; with SIM cards disabled, the phone's automatic number can use company services.

In **Companies → Work**, employees allowed to take company calls can enable **Take dispatch duty**
(German: **Leitstelle übernehmen**). This also enables their call availability on the active phone.
With `ServiceLine.Routing = "round_robin"`, incoming calls try available dispatchers first, rotating between them, then other
available employees. Busy or unreachable phones are skipped; declined or unanswered calls move to
the next eligible recipient within `Config.Companies.CallRouting.MaxAttempts` and `RingSeconds`.
The existing `ServiceLine.CanCall` and `ServiceLine.MinimumGrade` settings control access to both
ordinary calls and dispatch duty. Turning off dispatch duty keeps ordinary call availability active;
turning off company calls, disconnecting, or losing eligibility also removes dispatch priority.
Closing the phone keeps call readiness active. Dispatch duty is session state and must be enabled
again after reconnecting or restarting the resource; no database or configuration migration is needed.

With `ServiceLine.Routing = "ring_all"`, every eligible available employee rings, including dispatchers.
The first accepted answer connects and the other phones stop ringing. `RingSeconds` applies to the
whole group; `MaxAttempts` applies only to round robin. Ring-all calls do not advance either
dispatcher or ordinary employee round-robin positions.

### Weazel News

Configure editorial jobs and minimum grades:

```lua
Config.WeazelNews.AllowedJobs = {
    weazel = 0,
    reporter = 2,
}
```

Unlisted jobs can read news but cannot manage articles.

## External custom apps

Sky Phone is not limited to the apps that ship with it. Other resources can register installable custom apps, publish them through the App Store, exchange messages with their NUI, send notifications, and use server-controlled permissions and storage.

Its native custom app surface includes client and server exports for app registration, lifecycle control, messaging, notifications, capability discovery, and policy management. Sky Phone also normalizes supported custom-app contracts from:

- LB Phone
- 17Movement
- High Phone
- Quasar Smartphone
- YSeries

The resource provides the compatibility aliases `lb-phone`, `17mov_Phone`, `high-phone`, `qs-smartphone`, and `yseries`.

That means servers can replace LB Phone without giving up supported custom apps, while developers can build directly against Sky Phone for deeper lifecycle, permission, and storage integration.

Start Sky Phone before the custom app resources and do not start the original phone resource for an alias at the same time. For example, an unchanged app using `exports["lb-phone"]:AddCustomApp(...)` must run with `sky_phone`, not with the original `lb-phone`, as the active provider. Two active providers expose the same FiveM export event and can send registrations to the wrong phone.

## Frontend development

Customers installing a release do not need to build the frontend.

For development:

```powershell
cd frontend
pnpm install
pnpm dev
```

The browser mock links `demo@ifruit.com` and signs in the seeded SkyPic profile
`@alexm` by default. To exercise SkyPic registration with an empty profile, open
`http://localhost:5174/?testScenario=skypic-onboarding#/apps/skypic` while the
development server is running.

Create a production frontend build with:

```powershell
pnpm build
```

The production output is written to `sky_phone/source/html`.

Useful checks:

```powershell
pnpm typecheck
pnpm test
pnpm lint
pnpm build
```

## Troubleshooting

### The phone item does nothing

- A warning that the inventory returned no configured phone item means an item definition, `Config.Phone.Item`, inventory selection, or player ownership problem. It is not caused by a missing SIM card.
- Confirm the framework and inventory are supported and started first.
- Confirm the item name matches `Config.Phone.Item`.
- Confirm the item is usable.
- In unique mode, confirm the phone is non-stackable.
- Check the server console for inventory adapter warnings.

### The resource starts but the phone UI is missing

- On startup, the server console prints `SKY PHONE UI BUILD IS MISSING OR INCOMPLETE`, lists the missing or invalid packaged files, and shows repository-native build commands.
- Install the latest published release package rather than GitHub's automatically generated source archive.
- Confirm `sky_phone/source/html/index.html`, `assets`, `img`, and `sounds` exist.
- Developers working from source must run the frontend production build before starting the resource.

### Calls connect without audio

- Confirm the configured voice resource is running.
- Confirm `Config.Calls.VoiceProvider` matches the installed provider.
- Start the voice resource before Sky Phone.

### Camera or Voice Memos cannot upload

- Configure a valid FiveManage V3 Media API token.
- Confirm the token has the required file permissions.
- Restart Sky Phone after changing the token.

### Social app password or passcode warnings appear

- Check the values in `Config.Server`.
- Use long, stable values.
- Do not change them after accounts or passcodes have been created.

### The LB Phone notice appears

This is only a detection notice. No data is imported automatically. Run the `dry` command from the server console when you are ready.

### More diagnostic output is needed

Enable:

```lua
Config.Bridge.Debug = true
```

Reproduce the problem, collect the relevant server and client console lines, and disable debug mode again afterward.

## Support and community

Sky Phone is free, but you are not left alone with it. For installation help, configuration questions, bug reports, integration discussions, and community support, join the official Sky-Systems Discord:

**[Join the Sky-Systems Discord](https://discord.gg/sky-systems)**

If Sky Phone helps your server, star the repository and share it with other FiveM developers. Feedback and focused pull requests are welcome.

## Music integrations

The server-only [Music library export](MUSIC_API.md) lets authorized resources read the equipped phone's playlists and tracks.

## License, credits, and notices

Sky Phone is free and open-source software licensed under the [GNU General Public License v3.0](LICENSE).

Third-party acknowledgements and complete library license texts are available in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The production build updates this inventory and copies it together with the GPL into the deployable resource, so release and pull-request packages include both files. The listed licenses apply to the identified components; they do not grant additional rights to unrelated artwork, maps, or audio.

The inventory includes the declared frontend dependency tree and Tailwind's generated CSS, with supplemental notices maintained in [licenses/ADDITIONAL_NOTICES.md](licenses/ADDITIONAL_NOTICES.md). It conservatively includes supporting packages, not only code present in the final NUI bundle. After dependency updates, run `pnpm build` from `frontend` to regenerate and publish the notices; `pnpm licenses:check` verifies the checked-in inventory. Preserve upstream copyright and license texts when updating the supplements.

The corresponding source and build scripts for each published release are available through the matching version tag and source archives on the [releases page](https://github.com/sky-systems/sky_phone/releases). Release and pull-request packages include `SOURCE.txt` linking the exact built commit and its source archive. A pull-request filename identifies the PR head; `SOURCE.txt` records the actual checkout tested by CI, which may be GitHub's merge commit.
