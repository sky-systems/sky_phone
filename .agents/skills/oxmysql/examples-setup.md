# Setup for the SQL examples

The examples illustrate direct oxmysql use in a **server** resource. Keep an existing
Sky.Query/Sky.DB or resource-owned adapter when required; inspect its contract first.
Lua imports precede their consumers in the existing `fxmanifest.lua`:

```lua
server_script "@oxmysql/lib/MySQL.lua"
server_script "server.lua"
dependency "oxmysql"
```

The JS snippets assume the resource already builds with the matching package:

```js
import { oxmysql as MySQL } from "@overextended/oxmysql";
```

Lua `.await` calls need the existing scheduler coroutine; JS `await` calls belong to an
async handler/function. Choose one shown calling style per operation: running the awaited
and callback alternatives both would execute a mutation twice. The JS methods return a
Promise even with an optional callback, so handle/await rejection there too.

These are illustrative schemas, not migrations to install into a customer's database:

| Table | Fields/constraints assumed by examples |
| --- | --- |
| `example_notes` | auto-increment primary `id`, `owner`, `note`, `state` |
| `example_preferences` | unique `(owner, preference_key)`, `value` |
| `example_audit` | primary/unique `operation_id`, `kind` |
| `example_audit_details` | unique `operation_id`, `note`, foreign key to the audit record |

`owner_key`, record/operation IDs and text are already resolved/validated by the server
owner. Query parameters do not supply authorization. Keep migrations/imports aligned and
inherit the database charset/collation. Use the resource's real schema/indexes when adapting.

Await can raise on provider/SQL failure. Callback examples show result consumption;
preserve the owning error path. At the pinned Lua import, `mysql_option "return_callback_errors"`
opts into an error argument for callback failures; do not assume it is enabled. Avoid
fire-and-forget writes when their result affects a user-visible outcome.

For old integration tracing, the inspected Lua compatibility aliases map `fetchAll` to
`query`, `fetchSingle` to `single`, `fetchScalar` to `scalar`, and `execute` to `update`.
`MySQL.Async` uses callbacks; the corresponding `MySQL.Sync` alias is an await-style call,
not a separate thread-blocking SQL engine. Keep current explicit method names in new code.

[Official setup](https://overextended.dev/docs/oxmysql) and the pinned
[Lua/JS implementations](sources.md) define the installed contract.

For a new server installation, the official provider guide recommends MariaDB for
compatibility with older FiveM schemas/resources. Evaluate the actual resource requirements
and supported database version; this is not a reason to replace an existing working database
or claim universal performance superiority. MySQL version differences in reserved words,
JSON/text defaults and SQL syntax must be checked against the real migrations.
