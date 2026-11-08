# Banking and invoice providers

Phone includes its own invoices and uses the framework's personal bank balance by default.
Optional providers display their existing records and retain ownership of settlement and permissions.
No existing invoice or balance is copied when selecting a provider.

## Setup

Update Phone and the selected provider together, then start the provider and Phone normally.
The adapters register on startup and register again after a Phone restart. They are optional;
Phone does not require another Sky resource to start.

With Phone Configurator enabled, open `/phonepanel` → **Phone Configurator** and set
**Billing → Provider** and **Banking → Provider**, then save. In file mode, change the
same values in `sky_phone/config/config.lua` and restart Phone.

| Setting | Value | Behavior |
| --- | --- | --- |
| `Billing.Provider` | `phone` | Existing Phone invoices and Phone billing accounts; default. |
| `Billing.Provider` | `sky_jobs_base` | The character's received Jobs Base invoices; payment uses Jobs Base's existing settlement. |
| `Banking.Provider` | `framework` | Framework bank balance and Phone statement; default. |
| `Banking.Provider` | `qs` | Quasar Banking Creator held-fund checks, boss company balances and transfer history writes. |

Company balances are read-only in Phone. Quasar company balances require the framework's
boss flag (QBCore/Qbox).

Jobs Base remains responsible for invoice ownership, outstanding amounts, on-site restrictions,
society deposits, employee shares and duplicate-payment prevention. Its configured banking provider
receives the society credit when society deposits are enabled. When combining Jobs Base billing with
an external banking app, configure both resources to use the same existing society accounts.
Phone does not change the selected banking providers or migrate their balances. Phone does not credit its own billing
account for these payments. Only the character's received invoices are exposed; sent-invoice views
and disputes are unavailable for this provider. Phone pays monetary invoices from the personal bank account;
other currencies remain visible and use the Jobs Base interface for payment. The overview monetary
total covers bank/cash invoices; it does not sum item currencies.

Provider invoice IDs are scoped to the provider. An invoice opened before changing providers cannot
be paid against another provider's invoice with the same local number. Payments submit the displayed
outstanding amount and paid amount for the owner to reject stale confirmations.

Stopping the selected provider makes that app unavailable. Phone never switches to another ledger
after a failed request. Previous Phone invoices remain stored and are accessible again by selecting
`phone`. New provider settings preserve these defaults when loading an older saved configuration.

## History and transfers

Personal transfers continue to move framework money exactly once. A banking adapter checks its
restrictions first, then records the completed transfer without moving money again. If history
updates fail after a completed transfer, Phone reports the transfer as completed with a statement
warning. It never retries the payment to repair a statement.

Quasar Banking Creator's [documented exports](https://dev.quasar-store.com/docs/banking-creator/commands-and-exports)
provide `GetHeldAmount`, company balance reads and `AddTransaction`, but no public statement reader.
The `qs` adapter requires that API version. Its Phone statement therefore shows Phone-recorded
activity, while Phone transfers are also written to Quasar's statement. It does not claim to import
Quasar's existing history or to support the separate qs-core bundled bank.

The adapter does not add company withdrawals or cash deposits to Phone.

## Optional provider API

From the provider's server resource, register an export with:

```lua
exports.sky_phone:RegisterFinanceProvider("billing", "PhoneBilling")
-- or: RegisterFinanceProvider("banking", "PhoneBanking")
```

The calling resource name becomes the provider ID. The endpoint is invoked as
`Endpoint(source, action, data)` and returns `{ success = boolean, data?, error? }`.
Registration is server-only. Phone validates its device session and actor, scopes invoice IDs,
discards replies after a character/provider change and removes stopped registrations.
The provider must authorize its records, revalidate yielding mutations and settle through its owner.

Billing actions: `overview`, `list`, `detail`, `markRead`, `pay`, `dispute`.
Use the Phone billing DTOs; return provider-local string invoice IDs. Payments receive the viewed
`amount` and `amountPaid`, not authority to change the invoice amount.

Banking actions: `overview` returns the provider’s own overview (Phone does not read an unused
second statement first); `prepareTransfer` checks and
prepares a transfer without moving money; `recordTransfer` records an already completed transfer.
`recordPayment` records a confirmed invoice payment without moving money. Confirmed Phone invoice
payments are also written to the selected bank’s history. Transfer data contains server-resolved
actor/recipient identifiers, amount and display names.
Treat repeated logging and uncertain replies as owner concerns; Phone never replays a logging call.

Listen for the local server event `sky_phone:server:financeReady` to register after Phone starts.
`GetApiCapabilities().features.financeProviders` identifies compatible Phone builds.
After a native ledger change, the registered owner may call
`NotifyFinanceChanged(kind, source)` (or `-1` for an intentional global invalidation).
Only the selected registered owner can send this payload-free app invalidation.

## Verification boundary

Regression checks cover provider/session ownership, scoped IDs, stopped providers, stale payment
amounts, held funds, character changes and transfer logging failures.
Run the Phone tests from its repository and the Jobs Base test from its repository:

```text
lua54 tests/server_finance.lua
lua54 tests/phone_configurator.lua
lua54 tests/phone_billing.lua
```

The inspected Cfx source revision is `5c3065c261fb3ba82032fee6803f247198fec221`,
`data/shared/citizen/scripting/lua/scheduler.lua`, export registration/invocation and stop-cache
invalidation (lines 595–699), alongside the official
[Lua runtime documentation](https://docs.fivem.net/docs/scripting-manual/runtimes/lua/).
The integration retains export names instead of cross-resource function references.
Static tests and builds do not establish live FiveM or installed Quasar-version compatibility.

Resource ownership/state was also checked in the same Cfx revision at
`code/components/citizen-scripting-core/src/ResourceScriptFunctions.cpp`
(`GET_INVOKING_RESOURCE`, `GET_CURRENT_RESOURCE_NAME`, `GET_RESOURCE_STATE`).
The runtime reports script provenance, not player authorization; device and invoice/account
checks remain mandatory. The [resource-start event](https://docs.fivem.net/docs/scripting-reference/events/list/onResourceStart/)
provides the registration notification after all Phone scripts load.
