# Sky Phone 1.1.3

## Changes

- CityWarn notifications use a dedicated bundled emergency sound. Administrators can change the sound under `/phonepanel` > Phone configurator > CityWarn > General. Notification volume, mute, repeating extreme alerts and dismissal retain their existing behavior.
- Overflowing company job tabs in the Phone Configurator have a visible horizontal scrollbar.
- Account setup, authentication, mail recipients and contact compose links use the active `Mail.Domain`, including live Phone Configurator updates. Domain hints are translated in all supported locales; server validation accepts hyphenated domains and handles domain case consistently.
- Custom-app text fields retain keyboard focus when input claims, background configuration or owner cleanup change. Reloading the NUI still restores the phone's focus ownership.

## Update instructions

1. Back up the installed resource, retained configuration and any custom files under `source/html/sounds`.
2. Replace `fxmanifest.lua`, `SOURCE.txt` and the complete `source/` directory from the release ZIP. Delete and reinsert `source/` so old generated assets are removed. Restore custom sound files after replacing it. The new bundled file is `source/html/sounds/citywarn_alert.mp3`.
3. Replace `config/locales/` with the release's locale files. Merge any local translation overrides; mail hints now interpolate `{domain}` and CityWarn gains a sound label and description.
4. Retain your existing `config/config.lua` values. In its `Config.CityWarn` block, add `NotificationSound = "sounds/citywarn_alert.mp3",` if absent. When `Config.PhoneConfigurator.Enabled = false`, this setting is required for file-mode startup. With SQL configuration enabled, missing saved values receive the bundled default automatically; existing overrides are preserved.
5. Keep any custom CityWarn sound as a path relative to `source/html` or a direct HTTPS audio URL. Unsupported schemes, absolute paths, empty HTTPS hosts and leading/trailing whitespace are rejected. For source builds, store custom local sounds under `frontend/public/sounds` before rebuilding.
6. Run `refresh`, then `restart sky_phone` in the server console so FiveM reloads the manifest before restarting the resource. Start Phone before resources that register external phone apps. For a hot update, restart those app resources afterward (for Sky Emergency: `sky_jobs_base`) and restore any stopped dependents in dependency order; a full server restart in the normal startup order also restores their registrations.
7. Verify the CityWarn sound and dismissal, company tab scrolling, configured mail-domain hints and custom-app typing on your test server before deploying the update to players.

No manual SQL migration, new item, framework change or dependency update is required. `Mail.Domain` does not migrate existing account or contact addresses. If you change that setting, plan the address migration separately: addresses on the previous domain are rejected by the existing account and recipient validators.

## Changed shipped files

- `fxmanifest.lua`
- `SOURCE.txt` — replace the release's source-commit reference.
- `config/config.lua` — merge the new CityWarn field into retained configurations.
- `config/locales/` — replace and reapply local translations.
- `source/` — delete and reinsert, including the rebuilt NUI, new sound, generated defaults and updated Lua.

There are no shipped removals or renames outside `source/`. LICENSE and THIRD_PARTY_NOTICES retain their existing contents. Review screenshots, frontend sources, tests and repository documentation are not included in the deployable resource folder.
