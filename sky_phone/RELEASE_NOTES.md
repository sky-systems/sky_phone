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
