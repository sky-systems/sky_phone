# Sky Phone 1.1.4

## Changes

- Custom apps can report the actual opaque background beneath the status bar. Phone selects light or dark clock, reception, Wi-Fi and battery icons by contrast, so a supported red emergency header receives white icons independently of Phone's appearance setting.
- Loading and error screens, closing an app and switching apps restore the normal Phone status-bar appearance. Reopening a custom app retained during a call restores its reported contrast.
- Existing apps that do not report a background keep their current appearance. The compatible message extension and supported colors are documented in the [custom-app status-bar guide](https://github.com/sky-systems/sky_phone/blob/1.1.4/docs/custom-app-status-bar.md).

## Update instructions

These steps cover upgrading from 1.1.3. For older installations, also apply the configuration and locale steps in the [1.1.3 release instructions](https://github.com/sky-systems/sky_phone/releases/tag/1.1.3).

1. Back up the installed resource, retained configuration and any custom files under `source/`, including `source/html/sounds`.
2. Replace `fxmanifest.lua`, `SOURCE.txt` and the complete `source/` directory from the 1.1.4 release ZIP. Delete and reinsert `source/` so obsolete generated assets are removed, then restore your custom files. Keep your existing configuration and locale overrides.
3. For an external app to use adaptive status icons, install its background-reporting update as well. Sky Emergency requires a separately supplied compatible Jobs Base update that includes this sender; install it once that update is available to you. The sender is not included in the Sky Phone ZIP, and Emergency keeps its previous status-bar appearance until the companion update is installed. Other custom-app developers can use the optional message in the guide above.
4. Run `refresh`, then `restart sky_phone` in the server console so FiveM reloads the manifest. Start Phone before resources that register external phone apps. For a hot update, restart those app owners afterward (for Sky Emergency: `sky_jobs_base`) and restore any stopped dependents in dependency order. A full server restart in the normal startup order also restores their registrations.
5. On your test server, verify status icons on the supported app's light and dark backgrounds, change Phone's appearance setting, switch apps and reopen Phone during a call. Check that existing form inputs still work before updating your players' server.

No configuration, Phone Configurator, SQL, item, locale, framework or mandatory dependency change is required. Existing settings and saved data remain unchanged.

## Changed shipped files

- `fxmanifest.lua`
- `SOURCE.txt` — replace the release's source-commit reference.
- `source/` — delete and reinsert, including the rebuilt NUI.

There are no shipped removals or renames outside `source/`. Configuration, locales, LICENSE and THIRD_PARTY_NOTICES retain their existing contents. Frontend sources, tests and repository documentation are not included in the deployable resource folder.
