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
