# Sky Phone 1.1.6

## Changes

- Add a server API for changing the number of a player's equipped phone. Phone validates the configured number format and availability, preserves the SIM identity and other inventory metadata, and refreshes the equipped-number cache and active device after completion. Invalid, occupied or unchanged numbers return a failure result.
- Let trusted server integrations answer incoming calls and manage company call readiness through the same authoritative call flow as the phone UI. Call snapshots and local lifecycle events distinguish company service calls and confirmed connections.
- Match General settings to the Phonepanel's compact typography, fields, spacing and toggles using the shared UI controls.
- Add **Phone → Blocked GTA controls** in the Phone configurator. The defaults block the weapon wheel and weapon switching while the mobile phone is open; administrators can add, edit or remove control IDs, including clearing the list. Camera and closed-phone notification input keep their existing rules.
- Update the frontend dependency lockfile and matching third-party notices for `source-map-js` 1.2.2 and the development server's `proxy-addr` 2.0.8. The existing `nanoid` override remains in place.

## Update instructions

These steps cover upgrading from 1.1.5. For older installations, also apply the intervening release instructions.

1. Back up the installed resource and database. Preserve configuration, translations, server peppers, custom hooks and custom files under `source/`, including `source/html/sounds`.
2. Stop `sky_phone` and resources registering Phone apps. Install `fxmanifest.lua`, `SOURCE.txt`, `README.md`, `RELEASE_NOTES.md`, `THIRD_PARTY_NOTICES.md`, the complete `source/` directory and the integration guides from the **sky_phone-1.1.6.zip** release package. Restore your custom files. Keep the folder named `sky_phone`.
3. Merge the new `Config.Phone.DisabledControls` setting from the bundled `config/config.lua` into a retained file configuration. Its default is `{ 14, 15, 16, 17, 37, 99, 100, 115, 116, 261, 262 }`; `{}` disables these additional filters. In SQL mode, existing configurations receive the default when the field is absent. Edit it through `/phonepanel` → Phone configurator → **Phone** → **Blocked GTA controls**, then save with the checkmark. An explicitly saved empty or shortened list remains intact.
4. Update all fifteen bundled `config/locales/*.lua` files, or merge their new blocked-control labels and descriptions into your custom translations. Do not reset saved Phonepanel configuration.
5. Run `refresh`, then `restart sky_phone` in the server console so FiveM reloads the manifest. Restart consuming integrations and app resources afterward in their normal startup order. Number-change consumers must check `features.phoneNumberChange` and the completed result; call-control consumers must check `features.calls.externalControl`. Both require the server API to be ready. See [NUMBER_API.md](https://github.com/sky-systems/sky_phone/blob/1.1.6/sky_phone/integrations/NUMBER_API.md) and [CALL_API.md](https://github.com/sky-systems/sky_phone/blob/1.1.6/sky_phone/integrations/CALL_API.md).
6. Verify opening/closing the phone, editing and reopening the saved control list, and the normal movement/camera behavior. If an integration changes numbers, check a successful change and an occupied-number rejection with the equipped phone. If using server call controls, test actual recipients, simultaneous answers and two-way audio with two players before production use.

There is no SQL schema migration, new inventory item, asset requirement or mandatory dependency upgrade. The public API version remains `1.0.0`; capability flags identify the additive exports. A separate resource using its own key mapping or reading disabled inputs must handle its own input; the control list filters native GTA actions.

## Changed shipped files

Relative to the installed `sky_phone` directory:

- `fxmanifest.lua` — version `1.1.6`.
- `SOURCE.txt` — generated source-commit reference.
- `README.md`, `RELEASE_NOTES.md`, `THIRD_PARTY_NOTICES.md` — API/update documentation and dependency notices.
- `config/config.lua` — the new `Phone.DisabledControls` default.
- `config/locales/` — new blocked-control labels and descriptions in all fifteen bundled locales.
- `integrations/CALL_API.md` and `integrations/NUMBER_API.md` — new server API guides.
- `source/` — updated focus/configuration handling, server call/number APIs, shipped defaults and rebuilt NUI. Replace the complete directory and restore custom files.

There are no removals or renames outside `source/`. Generated NUI filenames are replaced with the rebuilt bundle as part of the complete source update. Repository tests, frontend source and audit screenshots are outside the deployable resource folder.

## Validation boundary

The number-change flow was tested on restarted local ESX with ox_inventory: an occupied number was rejected, a successful change agreed across SIM, inventory metadata, equipped-number cache and source lookup, and the managed fixture confirmed cleanup. The Phonepanel change has separately recorded local CEF/OAL control-state evidence. Automated Lua and frontend checks, theme browser tests, production builds and package/copy comparisons provide additional source and artifact evidence. Qbox gameplay, the full purchase UI, physical controller input and multiplayer call audio are not covered by these local results.

[All changes since 1.1.5](https://github.com/sky-systems/sky_phone/compare/1.1.5...1.1.6)

---

The following notes describe earlier releases.

# Sky Phone 1.1.5

## Changes

- Fix Yaca calls being rejected with "configured voice service is unavailable" when its enabled export returns numeric `1` instead of boolean `true`. Disabled and invalid provider states still block calls.
- Preserve compatibility with Yaca releases before `isEnabled` existed, and adapt older radio selectors and realtime speaking/mute APIs. Calls, speaker and mute keep using Yaca's stable server exports.
- Fix radio volume with Yaca 3.3.0's reversed export arguments. Reconnecting older Yaca no longer invokes toggle-only channel mute exports.
- Record the API changes across all 53 official tags from 1.0.0 through 3.6.0 in the [Yaca compatibility audit](https://github.com/sky-systems/sky_phone/blob/1.1.5/docs/yaca-voice-compatibility.md). This is source/API coverage; live multiplayer Yaca/TeamSpeak acceptance remains pending.

## Update instructions

These steps cover upgrading from 1.1.4. For older installations, also apply the intervening release instructions.

1. Back up the installed resource, retained configuration and custom files under `source/`, including `source/html/sounds`.
2. Replace `fxmanifest.lua`, `SOURCE.txt`, `README.md`, `RELEASE_NOTES.md`, `integrations/README.md` and the complete `source/` directory from the 1.1.5 release ZIP, then restore your custom files. The new shared `source/bridge/yaca.lua` must be installed together with the manifest that loads it. Preserve existing configuration and locale overrides.
3. Keep the intended voice resource running before Phone. Yaca requires its normal `yaca-voice` resource name; choose `yaca`, `yaca-voice` or `auto` through your existing Phone configuration/Configurator. No Yaca patch or forced Yaca upgrade is needed for this change.
4. Run `refresh`, then `restart sky_phone` in the server console so FiveM reloads the manifest. Restart resources that register external Phone apps afterward, or use a full server restart in the normal startup order.
5. With two players on a Yaca test server, accept and end a mobile/payphone call, check mute and speaker audio, reconnect both radio frequencies and move the volume slider. If using realtime microphone capture, check speaking, microphone mute/disable and Phone/provider restarts before updating players.

No configuration, Configurator, SQL, item, locale, custom asset or mandatory dependency migration is required. Dedicated secondary radio transmission still depends on Yaca's own 3.x selector support; earlier releases retain primary transmission and raw secondary reception.

## Changed shipped files

- `fxmanifest.lua` — version 1.1.5 and the shared Yaca bridge entry.
- `SOURCE.txt` — release source-commit reference.
- `README.md` and `integrations/README.md` — voice compatibility documentation.
- `RELEASE_NOTES.md` — current update instructions, with the older 1.1.1 notes retained.
- `source/bridge/yaca.lua` — new shared provider compatibility bridge.
- `source/bridge/server/voice.lua`, `source/bridge/client/radio.lua`, `source/client/realtime.lua` — adapter changes.

The CI resource package was compared against the published 1.1.4 ZIP. The rebuilt NUI files are byte-identical; there are no shipped removals or renames. Configuration, locales, SQL, assets, LICENSE and THIRD_PARTY_NOTICES keep their contents. Repository tests and audit sources are not included in the deployable resource folder.

---

The following historical notes apply to the earlier 1.1.0 to 1.1.1 update.

# Sky Phone 1.1.1

## What changed

- External app registration after closing the phone no longer saves app state without an open device session or changes the previous device's layout. The next phone opening applies the current catalog to that device.
- Improved registration compatibility for LB Phone, 17Movement, High Phone, Quasar and YSeries: function-only LB apps, supplied store metadata and screenshots, prices, job restrictions, notification suppression and permanent 17Movement uninstall requests.
- Paid and job-restricted apps enforce owning-resource server policies before installation, launch and custom storage access. Bank purchases are recorded per device and app owner; ordinary uninstall/reinstall preserves the entitlement.
- External store pages show the supplied description, developer, rating, size, banner and previews without invented version history or review counts. Installation failures have translated feedback in all 15 bundled locales.
- Database startup reads migration column metadata in bounded pages, avoiding oversized result sets while inspecting every column before schema changes.
- Expanded inventory setup documentation for all 17 adapters, including native item formats, provider version limits and the ox-only phone/SIM use handlers.

## Update from 1.1.0

1. Stop `sky_phone` and resources registering custom apps. Back up your resource and database. Preserve custom assets, Lua hooks, translations, existing configuration and all server peppers.
2. Use **sky_phone-1.1.1.zip**. Replace `fxmanifest.lua` and the complete `source` directory, including generated NUI. Keep the resource folder named `sky_phone`.
3. Merge the new app installation/access error translations into custom locales, or replace the bundled locale files.
4. For paid or job-restricted custom apps, register a matching server policy from the same owning resource using `AddCustomAppPolicy` / `UpdateCustomAppPolicy`: `store.price`, `store.allowedJobs` and/or `store.disabledJobs`. Free, unrestricted apps do not need this companion policy. See the [registration guide](https://github.com/sky-systems/sky_phone/blob/1.1.1/docs/custom-app-registration-audit.md).
5. Start Phone, then the app resources. Verify registration while closed, reopening and device switching, installation errors, restricted access and any real bank purchase/refund flow used by your apps.

No configuration reset, manual SQL migration, new inventory items, dependencies or custom assets are required. Existing SQL-managed settings remain authoritative. The new server-only purchase ledger uses the existing device-data table; factory reset keeps its existing data-deletion behavior.

Framework bank transactions and Phone SQL are separate systems. A crash or uncertain payment/refund result leaves the purchase pending and blocks another automatic charge. Reconcile against framework payment evidence before changing a pending record; the registration guide explains this boundary.

## Changed package paths

Relative to the resource directory:

- `fxmanifest.lua`
- `source/bridge/phones/client/seventeen.lua` and `source/bridge/phones/shared/{high,lb,quasar,seventeen,yseries}.lua`
- `source/bridge/server/migrations.lua`
- `source/client/custom_apps.lua`, `source/client/nui_server_bridge.lua`
- `source/server/custom_app_installations.lua` (new), `custom_app_storage.lua`, `custom_apps.lua`, `phone.lua`, `phone_persistence.lua`
- `source/shared/custom_apps.lua`
- Generated `source/html/*`
- All 15 `config/locales/*.lua` files
- `README.md`, `PHONE_INSTALLATION_IMPORTANT.md`, `RELEASE_NOTES.md`

The archive includes unchanged license notices and a `SOURCE.txt` identifying its commit, with a separate SHA-256 checksum. Configuration files, SQL schema and inventory definitions remain unchanged.

## Validation boundary

Frontend unit tests, Lua contracts, light/dark browser tests, production builds, archive inspection and local ESX/Qbox copy checks provide automated/source evidence. Restarted FiveM/CEF/OAL, real database concurrency, real framework payments/refunds and vendor startup timing still require in-game verification; no live runtime result is claimed.

[All changes since 1.1.0](https://github.com/sky-systems/sky_phone/compare/1.1.0...1.1.1)
