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
