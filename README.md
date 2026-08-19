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
  <a href="https://github.com/sky-systems/sky_phone"><strong>Download for free</strong></a>
  &nbsp;&bull;&nbsp;
  <a href="https://discord.gg/sky-systems"><strong>Discord support</strong></a>
</p>

---

**Jump to:** [App ecosystem](#one-phone-a-complete-app-ecosystem) · [Compatibility](#compatibility-at-a-glance) · [Installation](#quick-installation) · [LB Phone migration](#lb-phone-migration) · [Custom apps](#external-custom-apps) · [Support](#support-and-community)

Sky Phone is a **free and open-source FiveM phone script** built to give serious roleplay servers the depth, polish, and flexibility normally associated with paid marketplace phones. It combines a modern iPhone-inspired interface, persistent devices and SIM cards, social networks, media, business tools, services, games, and broad framework support in one complete resource.

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
| **Inventories** | ox_inventory, qb-inventory, lj-inventory, qs-inventory, codem-inventory, core_inventory, mf-inventory, smx-inventory, hex_4_inventory, and native ESX inventory |
| **Calls** | YACA, PMA Voice, SaltyChat |
| **Radio** | YACA, PMA Voice, SaltyChat |
| **Housing** | ESX Property, qbx_properties |
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

| Requirement | Supported options |
| --- | --- |
| **Database** | MySQL or MariaDB |
| **Database bridge** | `oxmysql` |
| **Framework** | ESX Legacy (`es_extended`), QBCore (`qb-core`), or Qbox (`qbx_core`) |
| **Inventory** | Choose one supported adapter from the table below |

| Inventory | Metadata support | Unique Phones | Notes |
| --- | --- | --- | --- |
| `ox_inventory` | Yes | Yes | Full per-item phone and physical SIM metadata |
| `qb-inventory` | Yes | Yes | Uses item `info` metadata |
| `lj-inventory` | Yes | Yes | QBCore inventory with item `info` metadata |
| `qs-inventory` | Yes | Yes | Full per-slot metadata |
| `codem-inventory` | Yes | Yes | Full per-slot metadata |
| `core_inventory` | Yes | Yes | Full per-slot metadata |
| `mf-inventory` | Yes | Yes | Supported with ESX |
| `smx-inventory` | Yes | Yes | Supported with ESX through the player metadata bridge |
| `hex_4_inventory` | **No metadata support** | **No, Unique Phones are not possible** | ESX only; set `Config.Phone.Unique = false` and `Config.Sim.Enabled = false` |
| Native ESX inventory | **No metadata support** | **No, Unique Phones are not possible** | Count-based items; set `Config.Phone.Unique = false` and `Config.Sim.Enabled = false` |

`hex_4_inventory` and native ESX inventory cannot persist per-item metadata. Unique Phones and physical SIM cards are therefore unavailable with these adapters.

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

1. Copy the resource into your FiveM resources directory.
2. Keep the resource folder name `sky_phone`.
3. Start `oxmysql`, your framework, inventory, and voice resource before Sky Phone.
4. Review `sky_phone/config/config.lua` and `sky_phone/config/media.lua`.
5. Add the required inventory items.
6. Add `ensure sky_phone` to `server.cfg`.
7. Restart the server and watch the console for warnings.

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

### Language

Available locales:

- English: `en`
- German: `de`

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

The German locale uses the complete English structure as a fallback, so newly introduced keys never leave the interface without text.

### Debug output

```lua
Config.Bridge.Debug = false
```

When enabled, Sky Phone prints debug and informational messages. Warnings and errors are always shown.

The short LB Phone detection notice also remains visible when debug mode is disabled.

## Security values

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

### ox_inventory

Default entries for unique phones with physical SIM cards:

```lua
["phone"] = {
    label = "iFruit Phone",
    weight = 200,
    stack = false,
    close = true,
    consume = 0,
},

["sky_phone_sim_registered"] = {
    label = "Registered SIM",
    weight = 5,
    stack = false,
    close = true,
    consume = 0,
},

["sky_phone_sim_anonymous"] = {
    label = "Anonymous SIM",
    weight = 5,
    stack = false,
    close = true,
    consume = 0,
},
```

Do not configure an LB Phone client event or client export. Sky Phone registers the usable items through its server-side inventory adapter.

The server registers `Config.Phone.Item` as usable for every supported inventory adapter: `ox`, `qb`, `lj`, `qs`, `codem`, `core`, `mf`, `smx`, `hex`, and `esx`. Resource startup fails visibly if the selected adapter cannot complete that registration.

The `hex` and `esx` adapters use ESX's count-based item API. They require both `Config.Phone.Unique = false` and `Config.Sim.Enabled = false` because this API cannot persist per-item phone or physical SIM metadata. `auto` selects `hex` when `hex_4_inventory` is started and otherwise falls back to `esx` on an ESX server when no metadata-capable inventory is detected.

### QBCore-style item tables

- Set the phone's `unique` value to match `Config.Phone.Unique`.
- Set `useable = true` and `shouldClose = true`.
- Physical SIM items must always be unique.
- SIM items are not required when `Config.Sim.Enabled = false`.

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

Select the provider under `Config.Garage.System`. Vehicle images use the configured CDN template with an icon fallback when no image is available.

### Housing

Select the provider under `Config.Housing.System`. Automatic mode supports the configured provider priority.

### Companies

Company jobs, public profiles, service numbers, services, permissions, locations, and default availability are configured under `Config.Companies.Definitions`.

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

Third-party acknowledgements and license information are available in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
