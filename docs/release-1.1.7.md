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
