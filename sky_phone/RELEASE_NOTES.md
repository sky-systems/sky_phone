# Sky Phone 1.2.1

## Changes

- Add progress feedback and a working animation when lockpicking or repairing physical cell towers. Press **X** to cancel; interrupted actions consume no items. The server validates the duration, player state, distance and inventory before completing an action and consuming its item.
- Add `CellTowers.Props.LockpickSeconds`, defaulting to 5 seconds. Set it in Lua file mode or under **Phonepanel -> Cell towers -> Physical towers**; Phonepanel accepts 1 to 300 seconds. Existing saved configurations receive the new default while retaining their other values.
- Use supported installed help, notification and progress providers through standalone Phone bridges, with native fallbacks. Show tower completion, cancellation and error feedback without requiring another Sky resource.
- Route payphone interaction and active-call hints through the same help provider. Ending or leaving one interaction releases its own hint without clearing another interaction's prompt.
- Add the action feedback and lockpicking-duration entries to all sixteen bundled locales and rebuild the Phonepanel interface.

## Update instructions

These steps cover upgrading from 1.2.0. For older installations, also apply the intervening release instructions, including the physical tower asset update in 1.2.0.

1. Back up the installed resource and database. Preserve configuration, translations, server peppers, custom hooks and custom files, including files under `source/html/sounds`.
2. Stop resources registering Phone apps, then stop `sky_phone`. Replace `fxmanifest.lua`, `SOURCE.txt`, `RELEASE_NOTES.md`, `PHONE_INSTALLATION_IMPORTANT.md` and the complete `source/` directory from **sky_phone-1.2.1.zip**, then restore custom files. Keep the folder named `sky_phone`; install the rebuilt NUI together with the Lua changes.
3. In file mode, add `LockpickSeconds = 5` inside `Config.CellTowers.Props` in `config/config.lua`, or choose the duration you want. In SQL mode, review the new duration under **Phonepanel -> Cell towers -> Physical towers**; do not reset saved Phonepanel configuration. Physical tower props remain disabled by default.
4. Merge the new tower feedback and Phone Configurator entries from `config/locales/` into your translations. Keep both your selected language and the English fallback installed.
5. Run `refresh`, then `start sky_phone`. Start consuming app resources afterward in their normal order. Existing supported UI providers are detected automatically; installing an additional provider is optional.
6. If physical props are enabled, check lockpicking and repair completion, **X** cancellation, walking away and item consumption. Check payphone interaction and call hints with your selected UI providers.

There is no SQL schema migration, new inventory item, mandatory dependency upgrade or public API version change. Existing `LockpickItem`, `RepairItem`, `RepairSeconds` and repair job restrictions remain in use. Streamed tower assets are unchanged from 1.2.0. See the [cell tower guide](https://github.com/sky-systems/sky_phone/blob/dev/assets/cell-towers/README.md) for configuration and operation.

## Changed shipped files

Relative to the installed `sky_phone` directory:

- `fxmanifest.lua` - version `1.2.1` and the three standalone client feedback bridges.
- `SOURCE.txt` - generated source-commit reference in the release package.
- `RELEASE_NOTES.md`, `PHONE_INSTALLATION_IMPORTANT.md` - update and tower item instructions.
- `config/config.lua` - new `CellTowers.Props.LockpickSeconds` default.
- `config/locales/` - tower action feedback and Phone Configurator entries in every bundled locale.
- `source/` - timed tower actions, server completion checks, client feedback bridges, payphone hints, Phone Configurator validation/defaults and rebuilt NUI. Delete and reinsert the complete directory, then restore custom files.

No files are removed or renamed outside the rebuilt `source/html/` bundle. Tests, frontend source and the editable cell tower guide remain outside the deployable resource.

Included pull request: [#142](https://github.com/sky-systems/sky_phone/pull/142).

---

# Sky Phone 1.2.0

## Changes

- Garage vehicles stored as numeric model hashes now receive the configured vehicle preview image, including signed hashes and registered custom models. Explicit image overrides and the existing placeholder remain supported.
- New SMS notifications show the sender's saved contact name on the lock screen and notification banner. Contact lookup stays within the receiving device's local or cloud-account contacts; unknown senders keep their number. Existing notification history is unchanged.
- Load the selected server language and English fallback when needed. Reuse unchanged realtime call and broadcast snapshots while preserving chat updates, participant changes and delivery revisions.
- Add optional physical cell towers with cabinets, lockpicking, weapon damage and timed repairs. An opened cabinet consumes one configured lockpick; a successful repair consumes one configured repair part. Damaged towers stop supplying reception, while overlapping healthy towers can still provide coverage.
- Configure physical towers, destructibility, repair jobs, item names, repair time, models, offsets and door angles in Phonepanel or Lua. Physical props remain disabled by default.
- Add a current-location action to Phonepanel tower positions, company locations, SkyRide quick locations and custom payphones.
- Move the 18 default coverage sites to rooftops and hills. Matching legacy defaults are migrated; custom sites are preserved. These coordinate changes can affect coverage boundaries even when physical props are disabled.

## Update instructions

These steps cover upgrading from 1.1.7. For older installations, also apply the intervening release instructions.

1. Back up the installed resource and database. Preserve configuration, translations, server peppers, custom hooks and custom files, including files under `source/html/sounds`.
2. Schedule maintenance and have players disconnect before stopping `sky_phone` and resources registering Phone apps. Replace `fxmanifest.lua`, `SOURCE.txt`, `RELEASE_NOTES.md`, `PHONE_INSTALLATION_IMPORTANT.md`, the complete `source/` directory and the bundled `stream/` directory from the 1.2.0 package, then restore custom files. Keep the folder named `sky_phone`; install the rebuilt NUI together with the Lua and streamed assets.
3. Update `config/init.lua` and merge the new entries from the bundled locale files into your translations. The server now loads locale files on demand, so keep the selected language and English locale installed.
4. In file mode, merge the new `Config.CellTowers.Props` block and review `Config.CellTowers.Towers`. In SQL mode, use **Phonepanel -> Cell towers**; do not reset saved Phonepanel configuration. Review the migrated default coverage sites on your map before enabling physical props. Custom tower models require separate mast, hinged-door, intact-panel and damaged-panel models, with matching offsets and door angles.
5. When enabling physical towers, register `CellTowers.Props.LockpickItem` and `CellTowers.Props.RepairItem` in the active inventory catalogue and provide them through your normal distribution flow. The defaults are `lockpick` and `radiotowerparts`; they are ordinary count-based items. See the [inventory setup guide](https://github.com/sky-systems/sky_phone/blob/dev/docs/inventory-setup.md). `RepairJobs = {}` allows everyone to repair; set job names to restrict it. Disabling `Destructible` prevents new weapon damage but does not repair existing damage.
6. With players still disconnected, run `refresh`, then `start sky_phone` so FiveM loads the updated manifest and streamed assets. Start consuming app resources afterward in their normal order, then reconnect clients to release cached model collision.
7. Verify garage previews, saved and unknown SMS senders, the configured language and any realtime calls or broadcasts you use. Check coverage on your map. If physical props are enabled, also check cabinet access, item consumption, damage, repair timing and configured job restrictions.

There is no SQL schema migration, mandatory dependency upgrade or public API version change. Existing stored notifications are not rewritten. The new inventory items and physical tower gameplay are only required when physical props are enabled. Placement and operation details are in the [cell tower guide](https://github.com/sky-systems/sky_phone/blob/dev/assets/cell-towers/README.md).

## Changed shipped files

Relative to the installed `sky_phone` directory:

- `fxmanifest.lua` - version `1.2.0`, server locale loading and cell tower modules/assets.
- `SOURCE.txt` - generated source-commit reference in the release package.
- `RELEASE_NOTES.md`, `PHONE_INSTALLATION_IMPORTANT.md` - update and installation instructions.
- `config/init.lua`, `config/config.lua` - server locale loading support and physical tower configuration/default sites.
- `config/locales/` - new tower interaction and Phonepanel entries in every bundled locale.
- `source/` - garage previews, SMS sender labels, lazy server locales, realtime snapshots, tower gameplay, Phonepanel location actions and rebuilt NUI. Replace the complete directory and restore custom files.
- `stream/sky_phone_cell_tower.ydr`, `stream/sky_phone_cell_door.ydr`, `stream/sky_phone_cell_panel.ydr`, `stream/sky_phone_cell_panel_broken.ydr`, `stream/sky_phone_cell_towers.ytyp` - new physical tower models and archetypes.

No files are removed or renamed outside the rebuilt `source/html/` bundle. Tests, editable Blender sources, frontend source and asset validation reports remain outside the deployable resource.

Included pull requests: [#137](https://github.com/sky-systems/sky_phone/pull/137), [#138](https://github.com/sky-systems/sky_phone/pull/138), [#139](https://github.com/sky-systems/sky_phone/pull/139), [#140](https://github.com/sky-systems/sky_phone/pull/140).

---

# Sky Phone 1.1.7

## Changes

- Add Japanese as the sixteenth bundled locale, including Phone Configurator selection. Regional `ja-JP` codes resolve to `ja`; `jp` is also accepted. English remains the fallback for unknown languages.
- Accept existing phone numbers with 1 to 24 digits independently of new-SIM generation settings. Preserve leading zeroes and every digit when dialing, formatting, saving contacts and resolving calls, messages or transfers. Newly generated SIMs still follow the configured length and prefix; company service numbers remain reserved.
- Add the read-only server export `ValidatePhoneNumberChange(source, number)` and the `features.phoneNumberValidation` capability. Integrations can validate before charging; the final number change still rechecks ownership, format and availability and may fail if another change claims the number first.
- Stop abandoned CrewLink and live-broadcast views from leaving polling timers behind. Prevent overlapping timer requests and share concurrent CrewLink presence rebuilds instead of repeating full-player SQL scans.
- Reuse unchanged mirrored-screen pixels and stop JPEG header decoding once dimensions are known. Keep the existing delivery cadence, quality, input/scroll updates and animated canvas/video/CSS capture.
- Update QB/Qbox restriction metadata from framework events instead of fetching complete PlayerData on every poll. Preserve login, logout, provider restart and immediate status updates.
- Respect `Config.Bridge.Debug` for routine media-upload progress on the server and client. Warnings and errors remain visible. Align the new Japanese number-change error with the accepted number format.
- Update Vue to 3.5.42 and patch the transitive selector parser, shell quoting and development-server query parser. Rebuild the NUI and regenerate matching third-party notices; the existing `nanoid` override remains intact.

## Update instructions

These steps cover upgrading from 1.1.6. For older installations, also apply the intervening release instructions.

1. Back up the installed resource and database. Preserve configuration, translations, server peppers, custom hooks and custom files under `source/`, including `source/html/sounds`.
2. Schedule maintenance and have players disconnect before stopping `sky_phone` and resources registering Phone apps. Replace `fxmanifest.lua`, `SOURCE.txt`, `README.md`, `LOGGING.md`, `RELEASE_NOTES.md`, `THIRD_PARTY_NOTICES.md`, `integrations/NUMBER_API.md` and the complete `source/` directory from **sky_phone-1.1.7.zip**, then restore custom files. Keep the folder named `sky_phone`; install the rebuilt NUI together with the Lua changes.
3. Update `config/init.lua` and the bundled English/German locales. Add `config/locales/ja.lua` to use Japanese, or install all sixteen bundled locale files while preserving custom translations. No existing configuration default changes. In SQL mode select `ja` under **Phone configurator → General → Framework & integrations**; in file mode set `Config.Bridge.Locale = "ja"`. Do not reset saved Phonepanel configuration.
4. With players still disconnected, run `refresh`, then `restart sky_phone` so FiveM reloads the manifest. Restart consuming integrations and app resources afterward in their normal startup order, then reconnect clients. Avoid unloading the streamed Phone prop during active gameplay. Preflight consumers must check API readiness and `features.phoneNumberValidation`, preserve numbers as strings and handle the final authoritative change result. See [NUMBER_API.md](https://github.com/sky-systems/sky_phone/blob/1.1.7/sky_phone/integrations/NUMBER_API.md).
5. Verify opening/closing the phone, configured locale selection and short/long numbers with leading zeroes. If used, check occupied/reserved-number rejection, media uploads with the existing debug flag disabled/enabled, CrewLink reopen behavior and multiplayer screen mirroring.

There is no SQL schema migration, new inventory item, new custom asset requirement or mandatory dependency upgrade. The public API version stays `1.0.0`; the preflight export and capability are additive. Preflight reserves no number and does not replace the final change.

## Changed shipped files

Relative to the installed `sky_phone` directory:

- `fxmanifest.lua` — version `1.1.7`.
- `SOURCE.txt` — generated source-commit reference.
- `README.md`, `LOGGING.md`, `RELEASE_NOTES.md`, `THIRD_PARTY_NOTICES.md` — locale, logging, update documentation and regenerated dependency notices.
- `config/init.lua`, `config/locales/en.lua`, `config/locales/de.lua` — locale alias registration and number-change feedback.
- `config/locales/ja.lua` — new complete Japanese locale.
- `integrations/NUMBER_API.md` — format-independent numbers and read-only preflight.
- `source/` — framework metadata, media logging, number handling, CrewLink presence, JPEG validation and rebuilt NUI. Replace the complete directory and restore custom files.

No files are removed or renamed outside `source/html/`. Generated NUI filenames are replaced by the rebuilt bundle. Tests, frontend source and review reports remain outside the deployable resource.

[All changes since 1.1.6](https://github.com/sky-systems/sky_phone/compare/1.1.6...1.1.7)

---

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
