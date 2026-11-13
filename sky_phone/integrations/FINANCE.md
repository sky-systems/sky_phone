# Banking and invoices

Phone uses the framework's personal bank balance and its own invoices by default.
Optional adapters display an existing provider's records. Selecting one does not
copy invoices, migrate balances or change that provider's configuration.

Update Phone and the selected provider to builds containing their matching adapters.
Start both resources in your normal server startup order. The adapters register
again after Phone restarts.

With SQL configuration enabled, open `/phonepanel` → **Phone Configurator**, choose
**Banking → Provider** and **Billing → Provider**, then save with the checkmark.
In file mode, edit `config/config.lua` and restart Phone and its consumers during maintenance.

| Setting            | Value           | Result                                                                                         |
| ------------------ | --------------- | ---------------------------------------------------------------------------------------------- |
| `Banking.Provider` | `framework`     | Framework balance and Phone statement; default.                                                |
| `Banking.Provider` | `qs`            | Quasar Banking Creator held-fund checks, boss company balances and transfer logging.           |
| `Billing.Provider` | `phone`         | Phone's own invoices; default.                                                                 |
| `Billing.Provider` | `sky_jobs_base` | Received invoices from Jobs Base 1.55.0 or later with the Phone adapter and billing enabled.   |

Company balances are read-only. Quasar company balances require the QBCore/Qbox boss flag. These options do
not add company withdrawals or cash deposits to Phone.

Jobs Base settles its invoices through its own payment and society-account rules.
Configure its banking integration to use the intended existing society accounts.
Phone pays monetary invoices from the personal bank account. Item currencies use
the Jobs Base interface for payment. Sent invoices and disputes are unavailable in
Phone for this provider. Previous Phone invoices remain stored; select `phone` to
open them again.

The `qs` adapter requires Quasar Banking Creator's documented `GetHeldAmount`,
`GetAccountBalance` and `AddTransaction` exports. The separate qs-core bundled bank
is not covered. Quasar exposes no public statement reader: Phone shows its own
recorded activity and writes completed Phone transfers to Quasar. Earlier Quasar
history is not imported.

If the selected provider stops, its app becomes unavailable. Phone does not switch
ledgers automatically. A statement warning after a successful transfer means the
money was transferred but the history could not be fully refreshed; check the
statement before taking further action.

## Custom server adapters

Register the provider's own server export with
`exports.sky_phone:RegisterFinanceProvider(kind, endpoint)`, where `kind` is
`"billing"` or `"banking"` and `endpoint` is the export name. Set the
corresponding Provider field in Phone to the adapter's resource name. The adapter
registers on its own startup if Phone is running and again on the server event
`sky_phone:server:financeReady` after Phone starts.

Phone calls the export with `(playerSource, action, data)`. Return a table with
`success = true` and the applicable `data`, or `success = false` with an
`error` code. Billing adapters handle `overview`, `list`, `detail`,
`markRead`, `pay` and `dispute`. The provider authorizes the invoice
owner and checks the confirmed `data.amount` and `data.amountPaid` before
settlement. Banking adapters handle `overview`, `prepareTransfer`,
`recordTransfer` and `recordPayment`. The record actions log completed
movements. Phone or the billing provider has already moved the money.

Call `exports.sky_phone:NotifyFinanceChanged(kind, playerSource)` after a
successful change so Phone can reload the affected view. For the action handlers
and response shapes, see the [finance bridge](../source/server/finance_providers.lua)
and [Quasar adapter](../source/bridge/server/finance_quasar.lua).
