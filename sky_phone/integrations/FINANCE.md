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
| `Billing.Provider` | `sky_jobs_base` | Received Jobs Base invoices; requires its Phone adapter update and enabled Jobs Base billing.  |

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

For custom server adapters, see the [provider API and verification notes](https://github.com/sky-systems/sky_phone/blob/1.6.0/docs/finance-integrations.md).
