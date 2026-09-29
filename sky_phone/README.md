<p align="center">
  <img src="config/images/phone.png" alt="Sky Phone, the free FiveM phone script" width="128">
</p>

<h1 align="center">Sky Phone: Free FiveM Phone Script</h1>

For server-only Discord webhooks, Phonepanel editing, app coverage and the
optional avatar URL, see [Discord logging](LOGGING.md).

<p align="center">
  <strong>The complete, free FiveM phone for ESX, QBCore, and Qbox.</strong><br>
  A premium-grade smartphone experience with 41 built-in apps, LB Phone migration, and first-class custom app support.
</p>

<p align="center">
  <a href="https://www.sky-systems.net/shop/phone#live-demo">
    <img alt="Try the interactive Sky Phone live demo" src="../readme-assets/live-demo-button.svg" width="780">
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
  <a href="https://github.com/sky-systems/sky_phone"><strong>Download for free</strong></a>
  &nbsp;&bull;&nbsp;
  <a href="https://discord.gg/sky-systems"><strong>Discord support</strong></a>
</p>

---

**Jump to:** [App ecosystem](#one-phone-a-complete-app-ecosystem) · [Compatibility](#compatibility-at-a-glance) · [Installation](#quick-installation) · [LB Phone migration](#lb-phone-migration) · [Custom apps](#external-custom-apps) · [Support](#support-and-community)

Sky Phone is a **free and open-source FiveM phone script** built to give serious roleplay servers the depth, polish, and flexibility normally associated with paid marketplace phones. It combines a modern iPhone-inspired interface, persistent devices and SIM cards, social networks, media, business tools, services, games, and broad framework support in one complete resource.

Instead of maintaining separate ESX phone, QBCore phone, or Qbox phone versions, Sky Phone supports all three frameworks through one standalone resource.

**Coming from LB Phone?** Sky Phone is designed to replace it. A controlled migration workflow transfers supported player data, while compatibility adapters keep supported LB Phone custom apps available. You can preview the import, migrate when you are ready, retry safely, and roll back migration-created Sky Phone records.

This is not a cut-down free alternative. Sky Phone includes the core experience server owners and players expect from a leading paid FiveM phone, plus full source access, no purchase price, no feature paywalls, and no forced ecosystem lock-in.

The production frontend is included, so a normal server installation does not require Node.js or pnpm.

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
| **Games** | Snake, Memory, Number Merge, Minesweeper, Tower Stack, Sky Flappy, and Neon Drop |
| **Phone system** | App Store, Settings, lock screen, setup assistant, notifications, widgets, folders, passcodes, multiple wallpapers, and light/dark appearance |

## Built for players, owners, and developers

| For players | For server owners | For developers |
| --- | --- | --- |
| A polished phone that feels like one connected product | A free replacement for fragmented or expensive phone setups | Full source access and a documented-in-code integration surface |
| Persistent phones, SIMs, accounts, settings, and content | Automatic schema installation and upgrades | Client and server exports for custom app lifecycle and permissions |
| Social, business, media, utility, and game experiences | Framework, inventory, voice, garage, and housing bridges | Compatibility layers for established FiveM phone app ecosystems |
| English and German localization | Controlled LB Phone migration with preview and rollback | Vue 3, TypeScript, Pinia, Vite, and reusable Sky UI components |

## Compatibility at a glance

| Layer | Supported options |
| --- | --- |
| **Frameworks** | ESX Legacy, QBCore, Qbox |
| **Inventories** | ak47_inventory, codem-inventory, core_inventory, jaksam_inventory, jpr-inventory, lj-inventory, mf-inventory, one_inventory, origen_inventory, ox_inventory, ps-inventory, qb-inventory, qs-inventory, smx-inventory, tgiann-inventory, hex_4_inventory, and native ESX inventory; see the inventory guide for framework and version limits |
| **Calls** | YACA, PMA Voice, SaltyChat |
| **Radio** | YACA, PMA Voice, SaltyChat |
| **Housing** | RTX Housing, Quasar Housing, VMS Housing, RX Housing, NoLag Properties, SN Properties, ESX Property, qbx_properties |
| **Garages** | Built-in/custom data and a broad set of popular garage providers configured through the bridge |
| **Custom app contracts** | Sky Phone, LB Phone, 17Movement, High Phone, Quasar Smartphone, YSeries |
| **Languages** | English, German |
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
- English and German localization throughout the player-facing interface

## Requirements

### Required

- MySQL or MariaDB
- `oxmysql`
- One supported framework:
  - ESX Legacy (`es_extended`)
  - Qbox (`qbx_core`)
  - QBCore (`qb-core`)
- One inventory from the [adapter and item setup guide](https://www.sky-systems.net/docs/scripts/free-phone/inventory-items#inventory-selector), using its supported framework and version.

`mf-inventory` and `smx-inventory` require ESX. SMX stores metadata per character and item name, so it cannot represent independently transferable copies. Core and MF need the version checks described in the guide. The native ESX and HEX adapters use count-based items, so Sky Phone automatically disables unique phones and physical SIM cards while either adapter is active.

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

> **Read this first:** [PHONE_INSTALLATION_IMPORTANT.md](PHONE_INSTALLATION_IMPORTANT.md) contains the required item, shop, startup-order, metadata, multi-device, and troubleshooting steps.

1. Copy the resource into your FiveM resources directory.
2. Keep the resource folder name `sky_phone`.
3. Start `oxmysql`, your framework, inventory, and voice resource before Sky Phone.
4. Choose the [configuration mode](#in-game-phone-configurator). SQL mode is enabled by default; change managed settings in `/phonepanel`, not in the Lua files.
5. Add the required [inventory items and their images](#inventory-items). With **ox_inventory**, also remove the existing NPWD phone handler as described below.
6. Add the two Phone ACE grants below, verify administrator group membership, then add `ensure sky_phone` to `server.cfg`.
7. Restart the server and watch the console for warnings.

> [!WARNING]
> **Using ox_inventory? Removing its NPWD phone handler is a required installation step when that block exists.**
> Changing `data/items.lua` alone is not enough. Follow [Remove the NPWD phone handler](#1-remove-the-npwd-phone-handler-required) before testing the phone item, even if NPWD is stopped or not installed.

Example start order:

```cfg
add_ace resource.sky_phone command.add_ace allow
add_ace resource.sky_phone command.remove_ace allow

ensure oxmysql
ensure es_extended
ensure ox_inventory
ensure pma-voice
ensure sky_phone
```

Replace the example framework, inventory, and voice resources with the providers used by your server.

Sky Phone creates and upgrades its database tables automatically. A manual SQL import is normally not required.

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

### In-game phone configurator

Throughout this guide, `Config.*` paths identify the settings in both modes. With
SQL mode enabled, edit those managed fields in the Configurator and save; Lua
examples describe the corresponding file-mode values. Restart after file edits.

`config/config.lua` is split into **Part 1: always file-owned** and **Part 2: panel-managed**.
Part 1 contains the Configurator switch, fixed command permissions and local custom tones.
When the Configurator is enabled, Part 2 and `media.lua` are replaced by shipped defaults plus
saved SQL values; editing those files does not change the active configuration, even on first start.

Start with **/phonepanel → Phone configurator → General**. Devices and SIM cards, framework and
inventory, phone-use restrictions, hotkeys and commands are grouped there with explanations.
Detail sections remain available and share the same draft. Physical SIM service and one-device-per-item
identity are separate switches. Native ESX and hex inventories force both off because they lack metadata.

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
in the Phone Configurator tool and press the checkmark. Saving validates and stores both SQL
payloads, then broadcasts the current configuration through the existing runtime refresh.
Restart after changing frameworks, inventory/voice providers, identity modes or keyboard defaults;
the panel does not restart the resource or overwrite players' saved key bindings.

Part 2 of `config.lua`, including server-only sections, and `Config.Media` are discovered
automatically. Part 1 remains file-owned: `PhoneConfigurator` selects SQL or file mode,
`CommandPermissions` controls access, and `CustomTones` registers local audio files. The fixed
permission table is never displayed or overwritten by the Phone Configurator, and its stable keys do
not change when their commands are renamed in the panel. Lists, nested objects, vectors,
and numeric-keyed Lua tables use structured editors instead of raw JSON. Shipped schema rows stay
editable but cannot be renamed, converted, or removed. Every list and table still accepts any number
of additional rows; administrator-added rows remain removable. Company job keys are intentionally
fully removable because `Config.Companies.Definitions` is a freely managed job collection.
Cell tower entries and their offline app/action policies are also fully editable and removable.

Phone command access uses **ACE groups**, with the same convention as the Jobs resources:
`admin` means `group.admin`; QBCore also grants `qbcore.admin`. Each protected action checks
`sky_phone.<permission>` on the server. Framework roles and Qbox job/group fallbacks no longer
grant Phone administration access. Keep player membership in your server/framework permission
setup and restart `sky_phone` after changing the fixed group lists.

Add both lines **before** `ensure sky_phone` in `server.cfg`:

```cfg
add_ace resource.sky_phone command.add_ace allow
add_ace resource.sky_phone command.remove_ace allow
```

The phone registers its own ACE grants and removes its automatically created entries when it
stops. It needs no `add_principal` / `remove_principal` capability. Grants for
`resource.sky_base` do not apply to `resource.sky_phone`. Existing installations must verify
their administrators' ACE membership when updating from the earlier framework-role checks.

See the [configuration and access guide](https://github.com/sky-systems/sky_phone/blob/dev/docs/phone-configurator.md) for the file/SQL boundary,
General page, permission migration, keyboard IDs, restart behavior and troubleshooting.

Media API keys and server peppers are never returned in plaintext to the NUI. Existing secrets are
shown only as configured and are replaced only when an administrator enters a new value.

### Cell towers and social moderation

`Config.CellTowers.Enabled` switches the coverage simulation on or off. The defaults include 18
virtual towers across Los Santos, mainland towns and Cayo Perico. Manage positions, ranges and
app availability through **Phonepanel > Phone Configurator > Cell towers**.
**Phonepanel > Social media** also lets authorized administrators find and remove Feather,
FlipTok, Picstagram and Weazel News posts with confirmation and an audit entry.
See [cell tower configuration and the default offline app list](https://github.com/sky-systems/sky_phone/blob/dev/CELL_TOWERS.md).

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

In SQL mode, select the default language under **Phone configurator → General → Framework & integrations**, then save with the checkmark. In file mode, edit `Bridge.Locale` in Part 2 of `config.lua` and restart:

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

In SQL mode, change `Bridge.Debug` in the Bridge detail section and save. In file mode, change the same value in Part 2 of `config.lua` and restart:

```lua
Config.Bridge.Debug = false
```

When enabled, Sky Phone prints debug and informational messages. Warnings and errors are always shown.

The short LB Phone detection notice also remains visible when debug mode is disabled.

## Security values

Sky Phone ships with four password/passcode pepper defaults under `Server`:

```lua
Config.Server = {
    PasscodePepper = "...",
    CrewLinkPasswordPepper = "...",
    FlipTokPasswordPepper = "...",
    PicstagramPasswordPepper = "...",
}
```

For a new production server, enter your own long, random, different values through **Phone configurator → Server** before players create passcodes or social accounts. Existing values are masked; leaving them unchanged preserves them. Back up the SQL configuration with the database.

Important:

- Keep the values private and stable.
- Changing `PasscodePepper` invalidates existing device passcodes.
- Changing a social-app pepper invalidates existing passwords for that app.
- Do not replace these values during routine updates.

Sky Cloud logins are in-character credentials for the roleplay phone. Players must never reuse a
real-world password. FlipTok and Picstagram passwords are stored as salted hashes using their
configured peppers.

The `IsDuplicityVersion()` block only controls execution. Clients still download `config.lua`, so private pepper values written into that file are exposed. Use the SQL Configurator for private peppers; file mode does not provide private pepper storage. Never put real account credentials in a shared configuration file or generated defaults.

## Inventory items

**Use the [Inventory Items & Setup guide](https://www.sky-systems.net/docs/scripts/free-phone/inventory-items)** for all 17 adapters: Phonepanel selection, item definitions, images, provider-specific setup, and version limits. TGIANN and other native adapters must not use the ox-only `sky_phone.UsePhoneItem` / `sky_phone.UseSimItem` handlers. The [source guide](https://github.com/sky-systems/sky_phone/blob/dev/docs/inventory-setup.md) is also available in the repository.

This resource includes an image for each default item in `config/images/`:

| Item | Image |
| --- | --- |
| `phone` | `phone.png` |
| `sky_phone_sim_registered` | `sky_phone_sim_registered.png` |
| `sky_phone_sim_anonymous` | `sky_phone_sim_anonymous.png` |

Copy these PNG files into your inventory's item image directory. For the default `ox_inventory` image path, use `ox_inventory/web/images/`. Other inventories use their own image directory. If you change an item name in `Config.Phone` or `Config.Sim`, give its image the same name expected by your inventory.

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

Default entries in `ox_inventory/data/items.lua` for unique phones with physical SIM cards:

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

Do not configure an LB Phone client event or client export. The shown Sky Phone exports are slot-aware and revalidate the selected item on the server. The server-side inventory registration remains as a fallback for item definitions without `client.export`; do not configure both handlers.

**Restart the complete server after both changes**, then verify that using the `phone` item opens Sky Phone. Recheck the NPWD handler after updating or replacing ox_inventory, as an update may restore it.

The server registers `Config.Phone.Item` as usable for every supported inventory adapter: `ox`, `qb`, `lj`, `qs`, `codem`, `core`, `mf`, `smx`, `hex`, and `esx`. Resource startup fails visibly if the selected adapter cannot complete that registration.

The `hex` and `esx` adapters use ESX's count-based item API, which cannot persist per-item phone or physical SIM metadata. Sky Phone automatically forces `Config.Phone.Unique = false` and `Config.Sim.Enabled = false` while either adapter is active. `auto` selects `hex` when `hex_4_inventory` is started and otherwise falls back to `esx` on an ESX server when no metadata-capable inventory is detected.

### QBCore-style item tables

- Set the phone's `unique` value to match `Config.Phone.Unique`.
- Set `useable = true` and `shouldClose = true`.
- Physical SIM items must always be unique.
- SIM items are not required when `Config.Sim.Enabled = false`.

## Phone and SIM modes

Set these independent switches under **Phone configurator → General → Devices & SIM cards** in SQL mode. In file mode, edit their values in Part 2 of `config.lua`:

```lua
Config.Phone.Unique = true
Config.Sim.Enabled = true
```

| Phone mode | Behavior |
| --- | --- |
| `Unique = true` | Every phone item receives its own IMEI. Settings, apps, local data, linked account, and SIM move with the item. The item must not stack. |
| `Unique = false` | Every framework character receives one persistent virtual device. Any configured phone item opens that device. The item may stack. |

With unique phones, using an inventory item selects that exact handset whenever the inventory reports its slot. The F1 hotkey reopens the last selected IMEI; if no handset has been selected yet, the server chooses the first concrete phone slot. The client never supplies a slot or IMEI.

| SIM mode | Behavior |
| --- | --- |
| `Enabled = true` | A registered or anonymous physical SIM item is required for cellular service. |
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

In SQL mode, enter FiveManage and GIPHY API keys in the **Media** detail section of the Phone Configurator and save. In file mode, edit the server-only `sky_phone/config/media.lua` and restart. The corresponding fields are:

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

`Config.Phone.Keybind` defaults to `F1` and can be rebound in FiveM's key bindings. Set it to `false` to disable the phone hotkey. In **Phone configurator → General → Keyboard & commands**, select a key or click **Record key**. Capture stores FiveM IDs (German Ü becomes `OEM_1`); NumPad keys remain distinct. Escape cancels capture. Restart for changed defaults; existing player bindings take priority. GTA control IDs, such as `Phone.HoldToLook.Control = 19`, remain numeric and are not keyboard codes.

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

For Picstagram, FlipTok, and Feather, the active LB Phone login is attached to the migrated player's Sky Cloud account. If LB has no active-login row, the oldest mapped profile is used. Additional social profiles remain separate, and a normal import automatically runs versioned ownership repairs for older Sky Phone migrations.

Supported domains include devices, settings, alarms, contacts, blocked numbers, calls, messages, photos, notes, wallet, voice memos, Picstagram, Mail, map markers, compatible DarkChat data, FlipTok, Feather, and Flare (LB Tinder profiles, photos, swipes, and mutual matches).

The migration command is server-console only.

## Garage, Housing, and Companies

### Garage

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

Select `rtx`, `quasar`, `vms`, `rx`, `nolag`, `sn`, `esx_property`, or `qbx_properties` under `Config.Housing.System`. Automatic mode uses `Config.Housing.AutoPriority` and keeps the existing `esx_property` and `qbx_properties` defaults ahead of newly supported providers. Select a provider explicitly when multiple housing resources are running. Each bridge exposes only the capabilities supported by the documented provider API.

### Companies

Company jobs, public profiles, service numbers, services, permissions, locations, and default availability are configured under `Config.Companies.Definitions`.

Company names are limited to 32 Unicode characters in Lua and the Phone Configurator; Discover
wraps names instead of truncating them. Shorten any existing longer names before restarting.
Set each definition's `CoverUrl` to an HTTPS image URL in the configuration or Phone Configurator
(an empty value hides the cover). Set `LogoUrl` to the company logo HTTPS URL in the same definition. Both images are
admin-managed; job members cannot change them through Companies. Previously uploaded job
logos and covers are no longer used automatically.

Opening hours use 24-hour `HH:MM` input. `ServiceLine.CanMessage` enables company SMS and defaults
to `true` for new companies and the shipped service lines. On the first restart after this update,
the Phone Configurator enables SMS once for the stored `ambulance`, `fire`, `mechanic`, and `taxi`
definitions; later admin changes are preserved. App requests still require the company and the
selected public service to accept requests, plus a registered SIM.

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

### CityWarn map blips

Active CityWarn warnings with coordinates appear on the GTA map and minimap for
all players, including with the phone closed. Radius warnings include a translucent
area; district warnings with coordinates use a point marker. City-wide warnings
and districts without coordinates remain available in the phone app without an
invented map location. The existing in-app map and its personal filters still work;
those filters do not hide the public GTA warning blips.

Publishing or updating a warning triggers a server sync. Resolving it removes its
blips immediately, and expiration removes them locally even if a server request
times out. Joining or restarting the resource restores active warnings, with a
30-second reconciliation for missed events and a 5-second retry after failures.
Disabling `Config.CityWarn.Enabled` through the Phone Configurator or stopping the
resource removes the blips. No additional configuration or SQL migration is needed.

### The phone item does nothing

- Confirm the framework and inventory are supported and started first.
- Confirm the item name matches `Config.Phone.Item`.
- Confirm the item is usable.
- In unique mode, confirm the phone is non-stackable.
- Check the server console for inventory adapter warnings.

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

## License, credits, and notices

Sky Phone is free and open-source software licensed under the [GNU General Public License v3.0](LICENSE).

Third-party acknowledgements and complete library license texts are included in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The GPL and these notices accompany the resource in release and pull-request packages. The listed licenses apply to the identified components; they do not grant additional rights to unrelated artwork, maps, or audio.

The corresponding Vue/TypeScript and Lua sources, dependency lockfile, and build scripts are available in the [public repository](https://github.com/sky-systems/sky_phone). Published release and pull-request packages include `SOURCE.txt` with links to the exact source commit and its archive. A pull-request filename identifies the PR head; `SOURCE.txt` records the actual checkout tested by CI, which may be GitHub's merge commit. Published releases also provide the matching version tag and source archives on the [releases page](https://github.com/sky-systems/sky_phone/releases).
