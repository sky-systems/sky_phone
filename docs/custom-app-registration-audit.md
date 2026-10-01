# Custom app registration and device persistence

Checked on 2026-10-01 against the working tree based on
`7eb8545e9a4d3bd214070c5776d308520cc7d6bc`. Scope: existing providers' UI-app
registration, return values and lifecycle, including registration while the phone
is closed. This is not a complete audit of every vendor export.

## Cause and fix

Registration publishes `custom-apps:catalog` independently of phone visibility.
The frontend replaces the catalog and calls `app-store.reconcileCatalog()`. After
an earlier phone session ended, that store remained hydrated and retained the
last device's layout. Every changed catalog could therefore enqueue an `apps`
write with the old IMEI and no active session token. The server correctly rejected
it with `device_not_open`.

Reconciliation now requires a hydrated, open phone. Closed registrations still
update the resource catalog, but leave the previous device's layout untouched.
On opening a phone, existing hydration combines that device's persisted layout
with the latest catalog. Active-session writes and server authorization are
unchanged; actual save failures remain visible.

## Registration contracts

| Provider   | Contract checked                                                                               | Result for ordinary UI-app registration                                                                                  |
| ---------- | ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| LB Phone   | `AddCustomApp(table)`, `RemoveCustomApp(identifier)`, `SendCustomAppMessage(identifier, data)` | Identifier, resource UI path, defaults, orientation, icon, hooks and boolean/error return shape match the mapped subset. |
| 17Movement | `AddApplication(table)`, `RemoveApplication(table)`                                            | Registration fields and current object-based removal are accepted; the older removal form is also accepted.              |
| High Phone | Shared `addApplication(name, data, locales)`                                                   | Client/server registration, `@resource` UI path and success/error handling match.                                        |
| Quasar     | `addCustomApp`, `addCustomAppsBatch`, `updateCustomApp`, `removeCustomApp`, `getCustomApps`    | Names and parameter shapes match; documentation recommends startup batch registration.                                   |
| YSeries    | `AddCustomApp(table)`, `RemoveCustomApp(key)`                                                  | Key, defaults, game classification and icon selection match.                                                             |

LB's [client export contract](https://docs.lbscripts.com/phone/exports/client-exports/#addcustomapp)
and [official template at de5d5c5](https://github.com/lbphone/lb-phone-app-template/blob/de5d5c5f2b1e98347e6ac920e5260fd951f1cf57/lb-reactjs/client.lua)
register after provider startup, without requiring an open device. The template's
HTTP development URL is outside Sky Phone's existing HTTPS asset contract.

The same startup separation is supported by
[17Movement's registration documentation](https://docs.17movement.net/phone/building-custom-apps/registering-the-application)
and [client template](https://github.com/17movement-net/17mov_Phone_app_boilerplate/blob/main/client/main.lua),
[High's shared API](https://docs.high-scripts.com/phone/exports/shared) and
[template at 212dbcf](https://github.com/high-phone/app-templates/blob/212dbcf2a9a21a2dfb846c1b0122a30f002b1d7c/vue-high-phone-app/server/main.lua),
[Quasar's developer API](https://www.quasar-store.com/docs/smartphone/developer-api),
and [YSeries custom app documentation](https://www.teamsgg.dev/docs/paid-scripts/phone/custom-apps)
and [template at 6605ef5](https://github.com/TeamsGG-Development/yseries-custom-app-templates/blob/6605ef5a0da271055464a1b2792d58118ac5c7b8/react-ts-app-template/client.lua).
Their local registrations share the same catalog flow; no vendor-specific wait
or retry was added to fix device persistence.

## Implemented compatibility corrections

- LB function-only apps accept an omitted UI when `onUse`/`onOpen` is callable.
  They execute the action without creating an iframe. UI apps keep the existing
  HTTPS asset boundary. Price, size (kB), screenshots and notification suppression
  now reach the catalog and store.
- 17Movement supports validated gradient icon backgrounds, rating and job/grade
  restrictions. `RemoveApplication({ name, resourceName, uninstall = true })`
  records a permanent removal on the currently known owned device, even while
  closed. Removal without `uninstall` remains temporary. No known device produces
  a visible `device_unavailable` diagnostic rather than modifying another phone.
- High maps store visibility, previews, size (MB converted to kB), developer and
  banner image/background. External details display supplied metadata and no
  fabricated version, chart, age, review count or release notes.
- Quasar price patches retain the other vendor fields and reach the install flow.
- YSeries maps allowed/disabled jobs. Preinstallation and removability are
  independent in the shared catalog; each vendor mapper decides its own defaults.

Sky policy for publicly unspecified details: job grades are minimum grades; deny
lists win; an empty allow list is unrestricted. Job display is refreshed with
phone bootstrap snapshots and server access is checked on every install/open.
LB notification suppression affects noncritical banners/sounds from the same
currently active app; history is retained. These choices are not a claim about
undocumented vendor internals.

## Server policy for prices and job access

Client registrations cannot establish authoritative money or permissions. A
paid/job-restricted app must also register the matching **server** policy from
its owning resource. Existing free/unrestricted client apps continue to work.
For example, in the external application's server script after Phone is started:

```lua
local success, error_code = exports.sky_phone:AddCustomAppPolicy({
    id = "dispatch",
    permissions = {}, -- use the existing capability list if the app needs it
    store = {
        price = 500,
        allowedJobs = { police = 2 },
        disabledJobs = {},
    },
})
assert(success, error_code)
```

Keep the owning resource, app ID, client quote and server policy aligned. Update
cost/access with `UpdateCustomAppPolicy` when updating the client descriptor.
Prices are integer in-game bank amounts. The server checks its own policy,
owner, unlocked device session/token, inventory ownership, job and balance.
Neither NUI prices nor job fields choose the actual charge or permission result.
Frames/actions wait for server authorization; local install claims and lifecycle
hooks wait for the server install result and successful device persistence.
Direct custom-app storage callbacks enforce the same current job/purchase policy
and recheck it after database reads, so bypassing the frontend open check does
not grant storage access.

Purchases are retained per device/app/owner in the server-only
`customAppPurchases` namespace of the existing `sky_phone_device_data` table.
There is no schema migration. Reinstallation does not charge twice; uninstalling
does not refund or erase the entitlement. Factory reset follows existing device
namespace deletion. The ledger is omitted from client bootstrap data and cannot
be written through `device:save`.

The server reserves a durable pending entry before debit and holds its device
lock through provider/database operations. A failed final write attempts a
refund. An uncertain provider outcome, crash or failed reconciliation remains
pending and blocks automatic repeated charges. Inspect framework payment logs
and the pending device/app entry before manually reconciling it; do not blindly
delete pending entries or retry payments. Framework money and Phone SQL are
separate systems, so cross-system crash recovery cannot be transactional.

## Remaining verification boundaries

This fixes the registration options above, not every export of every commercial
phone. High's `keepAlive` and per-alert default notification bitmask are outside
this change. Quasar public documentation does not establish batch atomicity or
exact add-return semantics. YSeries `GetDataLoaded` still derives from navigation
synchronization; provider-startup timing needs a live FiveM check.

## Platform evidence and validation

The client NUI transport was checked against the official
[SendNUIMessage documentation](https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/SendNUIMessage/)
and [NUI callback documentation](https://docs.fivem.net/docs/scripting-manual/nui-development/nui-callbacks/).
Inspected Cfx revision: `e34d12cd9a39cc223548a5be1ab09f60e9183051`:

- [Lua scheduler](https://github.com/citizenfx/fivem/blob/e34d12cd9a39cc223548a5be1ab09f60e9183051/data/shared/citizen/scripting/lua/scheduler.lua): `SendNUIMessage` JSON encoding and `RegisterNUICallback` event wrapper.
- [Native binding declaration](https://github.com/citizenfx/fivem/blob/e34d12cd9a39cc223548a5be1ab09f60e9183051/ext/native-decls/SendNuiMessage.md): client-only JSON string input and boolean native return; the Lua wrapper discards that return.
- [ResourceUIScripting.cpp](https://github.com/citizenfx/fivem/blob/e34d12cd9a39cc223548a5be1ab09f60e9183051/code/components/nui-resources/src/ResourceUIScripting.cpp): `SEND_NUI_MESSAGE`, JSON validation and dispatch to the resource frame.
- [ResourceUICallbacks.cpp](https://github.com/citizenfx/fivem/blob/e34d12cd9a39cc223548a5be1ab09f60e9183051/code/components/nui-resources/src/ResourceUICallbacks.cpp): native registration and `MakeUICallback`, JSON/MessagePack conversion, queued legacy event and JSON response.
- [RPCSchemeHandler.cpp](https://github.com/citizenfx/fivem/blob/e34d12cd9a39cc223548a5be1ab09f60e9183051/code/components/nui-resources/src/RPCSchemeHandler.cpp): browser request dispatch through `ResourceUI::InvokeCallback` and response continuation.

These are client UI transport paths, not an automatic server device session or a
OneSync RPC. No native, pointer/out-value or OAL call was changed. The inspected
revision is upstream, not a verified match to the user's running client artifact.

The real-store regression suite reproduced the closed-session failure before
its fix. Coverage includes cold startup, closed registration, device switching,
identical updates, payment rejection, stale payment responses and persistent
removal markers. Lua tests exercise vendor mappings, function-only registration,
policy ownership, minimum grades/deny precedence, forged quotes, insufficient
funds, concurrent installs, refunds, pending recovery and closed-device removal
ownership/CAS conflicts. Frontend types/lint/full tests and production build are
checked separately from browser theme checks and local deployment consistency.
No restarted FiveM/CEF/OAL or actual database/payment runtime test is claimed.

Money contracts were checked against official source:

- [ESX 1.13.4](https://github.com/esx-framework/esx_core/blob/78ed0c6ad31060f28286c46f974f1f64d7e4ce2e/%5Bcore%5D/es_extended/server/classes/player.lua): account methods return no success value; the Phone adapter checks balance and treats a completed call as success. Current [ESX upstream](https://github.com/esx-framework/esx_core/blob/fe59ca0bd6da59e2ec6eb4a8d06ece312e96ae7a/%5Bcore%5D/es_extended/server/classes/player.lua) adds true success returns.
- [Qbox player money/job source](https://github.com/Qbox-project/qbx_core/blob/1825a3c3cf6b5057d6909a44a8fc4444ac3f89d3/server/player.lua) and [money hooks](https://github.com/Qbox-project/qbx_core/blob/1825a3c3cf6b5057d6909a44a8fc4444ac3f89d3/modules/hooks.lua): boolean results, configuration-dependent overdraft, and arbitrary pre-mutation hooks. Their possible yielding is inferred from the call path; it is not a profiler/runtime measurement.
- [QBCore player methods](https://github.com/qbcore-framework/qb-core/blob/9b3cddcce93e5e12cbcf6b47b866b687d32ac7bf/server/player.lua): boolean success and configured negative-money limits. The Phone purchase callback independently requires a sufficient bank balance.

Installed ESX 1.13.4 account methods match the linked version. Installed Qbox
files were inspected but do not establish an exact upstream artifact match or
which runtime is active. Existing Phone-owned framework adapters remain intact.
