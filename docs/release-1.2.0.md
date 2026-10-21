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
