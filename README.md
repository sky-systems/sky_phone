# sky_phone

Standalone FiveM phone built with Vue 3, TypeScript, Pinia, Vue Router, Konsta UI 5, and Tailwind CSS 4. Each non-stackable `phone` item receives a unique 15-digit IMEI and owns its server-persisted device state. The phone opens through the usable item; `/phone` is disabled unless `Config.Phone.DevelopmentCommand` is enabled explicitly.

An iFruit account is optional. Unlinked devices retain local settings, alarms, media, apps, and notes. Linking from Mail or Settings moves local notes into the account and exposes the same notes and mailbox on every linked device. Signing out hides cloud data without deleting it, while a factory reset removes only the current device's local data and account link.

## Requirements

- `sky_base` with a slot-aware inventory adapter implementing `GetInventorySlot`, `GetInventorySlotsWithItem`, and `SetInventorySlotMetadata`.
- A non-stackable inventory item named `phone` (or the matching value in `Config.Phone.Item`).
- MySQL/MariaDB through the database driver configured in `sky_base`.

Database migrations run automatically. Existing `sky_phone_mail_accounts` installations are renamed to `sky_phone_accounts` while preserving account IDs and mail foreign keys. iFruit passwords are intentional in-character credentials and remain plaintext `VARCHAR(64)` values; registration screens warn players never to reuse a real password.

The homescreen is an original implementation inspired by the interaction and layout concepts in [lukejacksonn/homescreen](https://github.com/lukejacksonn/homescreen), inspected at commit [`98a812f`](https://github.com/lukejacksonn/homescreen/tree/98a812f4f7c33594e791d65092f73b8f54b3c598). No source code or image assets from that project are included.

## Development

From `frontend/`, run `pnpm dev` for browser development. The phone opens automatically and NUI callbacks are mocked. Run `pnpm test`, `pnpm typecheck`, `pnpm lint`, and `pnpm build` before packaging.

`pnpm build` uses `build.cjs` to replace `sky_phone/source/html` deterministically with the Vite output. Production assets use relative paths so they work through the FiveM NUI protocol.
