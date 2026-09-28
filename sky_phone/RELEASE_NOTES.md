# Sky Phone 1.1.0

## What changed

- **General configuration page:** `/phonepanel` → Phone configurator → General now groups device/SIM modes, framework/inventory/language/voice providers, phone-use restrictions and keyboard/command settings. General and detail pages edit the same draft; save with the header checkmark.
- **Phone-owned ACE permissions:** `Config.CommandPermissions` uses the same group suffix convention as the Jobs resources, implemented within standalone `sky_phone`. Every protected action checks the player's ACE permission again. Framework-role and Qbox job/group fallback access has been removed.
- **FiveM-aware keyboard capture:** select a key or click Record key and press it. German Ü stores `OEM_1`, Ö stores `OEM_3`, and Ä stores `OEM_7`; NumPad keys remain distinct. Escape cancels capture. Unsupported combinations, including two modifiers released in either order, are rejected. Server-side validation rejects invalid key IDs.
- **Clear configuration ownership:** Part 1 of `config.lua` remains file-owned; Part 2 and media settings are SQL-managed by default. Existing saved configuration and its schema are preserved. The panel remains read-only in file mode.
- **ESX status cache:** initialize player status once and keep it current through framework lifecycle, inventory and player-data events, including logout and provider restarts. This avoids fetching and serializing the complete player table on every status poll; no live performance benchmark is claimed.
- Updated all 15 locales, bundled installation/integration guides and the configuration documentation, including troubleshooting and existing personal FiveM bindings.

## Required update steps from 1.0.1

1. Stop `sky_phone`. Back up the resource and database, including `sky_phone_configurator`, webhook overrides, all four existing `Server` peppers, custom tones/music/assets and your Lua hooks.
2. Use the attached **sky_phone-1.1.0.zip**, not GitHub's source-code archives. Keep the resource folder named `sky_phone`.
3. Replace `fxmanifest.lua` and delete/reinsert the complete `source` directory from the package, including the generated NUI. Merge the configuration and locale changes below; preserve your existing custom values and files.
4. Add both lines to `server.cfg` before `ensure sky_phone`:

   ```cfg
   add_ace resource.sky_phone command.add_ace allow
   add_ace resource.sky_phone command.remove_ace allow
   ```

   Phone registers its own ACE grants and removes its installed grants when it stops. The Sky Base resource grants do not apply to Phone. Phone does not need `command.add_principal` or `command.remove_principal`; your server/framework continues to own player group membership.
5. Verify `Config.CommandPermissions` in Part 1. Group suffix `admin` means `group.admin`; QBCore additionally grants `qbcore.admin`. Ensure administrators actually inherit an allowed ACE group. A framework-only role or job is no longer sufficient. Keep the permission keys unchanged when renaming commands. Missing/empty lists deny player access, and explicit ACE denies still apply.
6. Perform a full server restart to apply edited `server.cfg` grants. Check startup diagnostics, test one authorized and one unprivileged user, then verify General settings, phone/SIM item use and calls. For policy and membership checks, use `test_ace group.admin sky_phone.phonepanel` and `test_ace identifier.license:YOUR_LICENSE sky_phone.phonepanel` with a real identifier.

## Configuration and data

- **Always file-owned:** `PhoneConfigurator`, `CommandPermissions` and `CustomTones` in Part 1; locale files, `config/functions.lua`, inventory definitions and custom assets remain file-owned too.
- **SQL mode (default):** use the panel for Part 2 and Media. Editing those files has no runtime effect, even on first start. Keep the existing `sky_phone_configurator` row; this update does not require a manual SQL migration or a configuration reset.
- **File mode:** set `PhoneConfigurator.Enabled = false`, edit the file values and restart. Switching modes does not copy SQL settings into Lua files.
- **Player checks:** merge the `config/functions.lua` changes if you maintain custom checks. The default hooks now read each state value once; preserve your custom conditions.
- **Locales:** merge the new General/key-capture/help keys into custom translations, or replace the bundled `config/locales` files with the release versions.
- **Secrets:** preserve all four peppers. Clients download shared `config.lua` even inside server-only execution blocks; use the SQL panel for private peppers. Media keys belong in the panel in SQL mode or server-only `config/media.lua` in file mode.
- **Items and dependencies:** no new item names, SQL scripts or third-party dependencies are required. Unique phones and physical SIMs still need per-item metadata; native ESX and hex inventories force both modes off.
- **Restarts and keys:** restart for changed providers, device identity modes and keyboard defaults. Existing player bindings keep priority; players can change/reset them in FiveM Settings → Key Bindings → FiveM. Numeric GTA controls such as `Phone.HoldToLook.Control = 19` are not keyboard mapper IDs.

## Changed package paths

Relative to the `sky_phone` resource directory:

- `fxmanifest.lua`
- `source/*` — delete and reinsert, including built `source/html`
- `config/config.lua`, `config/functions.lua`, `config/locales/*.lua`
- `config/custom_tones/README.md`
- `README.md`, `PHONE_INSTALLATION_IMPORTANT.md`, `LOGGING.md`, `RELEASE_NOTES.md`
- `integrations/README.md`, `integrations/PLAYER_CHECKS.md`

Custom inventory definitions, music files and other unchanged assets do not require migration. The release archive includes `LICENSE`, `THIRD_PARTY_NOTICES.md` and a `SOURCE.txt` identifying its source commit, plus a separate SHA-256 checksum.

## Validation boundary

Lua suites, frontend unit tests, browser tests, builds, package validation and local ESX/Qbox copy checks are automated/source evidence. Actual FiveM/CEF/OAL keyboard layouts, saved player bindings and live server ACE behavior still require in-game verification; no live runtime result is claimed.

[Configuration and access guide](https://github.com/sky-systems/sky_phone/blob/1.1.0/docs/phone-configurator.md) · [All changes since 1.0.1](https://github.com/sky-systems/sky_phone/compare/1.0.1...1.1.0)
