# sky_phone

Standalone FiveM phone built with Vue 3, TypeScript, Pinia, Vue Router, Konsta UI 5, and Tailwind CSS 4. Each non-stackable `phone` item receives a unique 15-digit IMEI and owns its server-persisted device state. The phone opens through the usable item; `/phone` is disabled unless `Config.Phone.DevelopmentCommand` is enabled explicitly.

An iFruit account is optional. Unlinked devices retain local settings, alarms, media, apps, notes, contacts, and recent calls. Linking from Mail or Settings moves local data into an empty cloud account; an existing cloud dataset wins over local contacts and recents. Signing out keeps an editable local snapshot without deleting cloud data.

## Requirements

- ESX Legacy (`es_extended`), Qbox (`qbx_core`), or QBCore (`qb-core`). The bridge selects a running supported framework when `Config.Bridge.Framework` is set to `"auto"`.
- A supported inventory: `ox_inventory`, `qb-inventory`, `lj-inventory`, `qs-inventory`, `codem-inventory`, `core_inventory`, `mf-inventory`, or `smx-inventory`. The bridge auto-detects a running provider and normalizes metadata, slots, counts, item mutations, and usable-item callbacks. `mf-inventory` and `smx-inventory` require ESX. Because SMX stores standard ESX items as stacks, its adapter persists one active Phone/SIM metadata record per player and item type in ESX player metadata.
- A non-stackable inventory item named `phone`.
- Two unique, non-stackable inventory items named `sky_phone_sim_registered` and `sky_phone_sim_anonymous`. Their metadata is initialized automatically on first use, so shops and crafting recipes add plain items without supplying a number.
- `oxmysql` with MySQL/MariaDB.
- `pma-voice` when `Config.Calls.VoiceProvider` is set to `"pma"`.
- A FiveManage V3 Media API token for Camera photo/video uploads and Gallery deletion. Set the
  server-only `Config.Media.FiveManage.ApiKey` in `sky_phone/config/media.lua`; the token is never
  sent to NUI because clients receive temporary presigned upload URLs instead.
- `yaca-voice`, `pma-voice`, or `saltychat` when the Radio app is enabled. `Config.Radio.VoiceProvider = "auto"` selects the first running provider in that order.

## Messages GIF provider

Configure GIF search in `sky_phone/config/config.lua`:

```lua
Config.Media.GiphyApiKey = "YOUR_GIPHY_API_KEY"
```

GIPHY provides trending and searched GIFs through a paginated server-side proxy. The shared
`config.lua` is loaded by both FiveM runtimes, so its values are available to clients even though
only the server uses the GIPHY key. Photo and video actions in Messages are intentionally inactive
until their dedicated implementation is available.

Database migrations run automatically. Existing `sky_phone_mail_accounts` installations are renamed to `sky_phone_accounts` while preserving account IDs and mail foreign keys. iFruit passwords are intentional in-character credentials and remain plaintext `VARCHAR(64)` values; registration screens warn players never to reuse a real password.

Camera and Gallery media is stored in `sky_phone_media`. Signed-out captures belong to the current
IMEI; linking an iFruit account moves those rows into the account gallery so every linked phone sees
them. Signing out hides cloud media without deleting it. Factory reset removes device-local media
and attempts to delete its remote FiveManage files, while account-owned media remains in the cloud.

For a fresh manual database installation, import `sky_phone/sql/install.sql`. It contains the complete current table, key, index, collation, and foreign-key schema. Runtime migrations remain authoritative for upgrading an existing installation and must stay enabled.

Framework, inventory, callback, notification, and database integrations live under `sky_phone/source/bridge`. The resource has no dependency on any other Sky resource.

## Radio app

The built-in Radio app supports a primary frequency, volume, recent channels, participant lists, automatic rejoin, join/leave notifications, and an optional service number. YACA and SaltyChat support the configured secondary frequency; PMA Voice exposes one radio channel, so the secondary input is hidden automatically.

Configure frequency bounds and precision, restricted channel ranges and allowed jobs, history length, defaults, badge validation, radio display-name permissions, and the built-in speaker HUD under `Config.Radio`. `Config.Radio.DisplayName.AllowedJobs` maps authoritative framework job names to their minimum grade. Unlisted jobs cannot change the name; an empty name restores the normal player or character name. Channel and display-name access are always checked server-side. `Config.Radio.Hud` controls the phone-owned overlay, its screen edge, offsets, and recent-speaker duration without depending on another HUD resource. Active-speaker highlighting uses the YACA radio events; the Radio app itself continues to support every configured voice provider.

Radio profiles are stored in `sky_phone_radio_profiles`. Runtime migration creates the table automatically; fresh installations receive it through `sky_phone/sql/install.sql`.

Inventory metadata has no framework-wide standard: providers differ in export names, callback payloads, slot handling, and whether metadata is called `metadata` or `info`. For that reason, `sky_phone` uses explicit provider adapters instead of guessing exports at runtime. Every supported adapter implements slot lookup, item lookup, metadata replacement, capacity handling, add/remove operations, and usable-item registration. Providers without a separate capacity export use their authoritative add operation as the final capacity gate.

When a SIM is ejected or replaced, the returned inventory item is rebuilt from the authoritative `sky_phone_sims` row. Its metadata contains `sim_metadata_version`, `sim_id`, `phone_number`, `formatted_number`, and `sim_type`. Registered SIMs additionally contain `firstname`, `lastname`, `birthdate`, and `registered_at`. The internal framework owner identifier remains database-only. Inserting the item again resolves the SIM by `sim_id`; contacts and device/cloud data remain attached to their existing phone-owned persistence instead of being copied into inventory metadata.

For `ox_inventory`, configure all three items with `stack = false` and `consume = 0`. Do not configure a client event or export. Ox then completes its normal server-authoritative use flow and emits `ox_inventory:usedItem`; the bridge resolves the authoritative slot again and only opens the matching device or SIM. A client export would return before Ox calls `useItem` and therefore prevent `ox_inventory:usedItem` from being emitted.

Example `ox_inventory/data/items.lua` entries:

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

For QBCore-style item tables, define the same names with `unique = true`, `useable = true`, and `shouldClose = true`. The provider adapter registers the server-side usable callbacks; no `lb-phone` event or export is used.

The homescreen is an original implementation inspired by the interaction and layout concepts in [lukejacksonn/homescreen](https://github.com/lukejacksonn/homescreen), inspected at commit [`98a812f`](https://github.com/lukejacksonn/homescreen/tree/98a812f4f7c33594e791d65092f73b8f54b3c598). No source code or image assets from that project are included.

## Development

From `frontend/`, run `pnpm dev` for browser development. The phone opens automatically and NUI callbacks are mocked. Run `pnpm test`, `pnpm typecheck`, `pnpm lint`, and `pnpm build` before packaging.

`pnpm build` uses `build.cjs` to replace `sky_phone/source/html` deterministically with the Vite output. Production assets use relative paths so they work through the FiveM NUI protocol.
