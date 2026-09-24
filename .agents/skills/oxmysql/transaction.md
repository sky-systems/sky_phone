# Transactions and business invariants

MySQL.transaction.await accepts a sequence of statements and returns a boolean result.
The inspected implementation commits when all statements execute without an SQL exception
and rolls back on an SQL error. It does not inspect each statement's affected-row count.

A conditional debit that updates zero rows does not automatically abort a later credit.
Transaction success therefore does not prove sufficient balance, existing accounts,
authorization or the expected state transition. Do not use a generic two-UPDATE transfer
example as a complete economy implementation.

Validate the actor and bounded inputs at the server owner. Choose a transaction/locking or
conditional-mutation design that can check required row/state invariants and abort when they
fail. Keep SQL invariants under the same transaction/connection where atomicity is required;
a read before it is not enough. Check the result and preserve the existing failure/compensation
path for effects outside the database. Do not add retries to hide a concurrency defect.

Use a uniqueness/idempotency constraint where one persisted operation must occur once.
Confirm the supported transaction API in the installed provider instead of inventing a callback
transaction method. [Official transaction contract](https://overextended.dev/docs/oxmysql/Functions/transaction)
and [rawTransaction implementation](sources.md).

## Per-statement parameters: complete syntax

[Example setup](examples-setup.md) specifies illustrative audit tables with unique operation
keys and a foreign key. These inserts have SQL-enforced failure conditions; this is not a
money-transfer or reward implementation. Choose one of the three alternative calling styles.

```lua
local statements = {
    {
        query = "INSERT INTO example_audit (operation_id, kind) VALUES (?, ?)",
        values = { operation_id, "note_created" }
    },
    {
        query = "INSERT INTO example_audit_details (operation_id, note) VALUES (?, ?)",
        values = { operation_id, note_text }
    }
}
local committed = MySQL.transaction.await(statements)
if not committed then
    print("[audit] Transaction did not commit")
    return
end
print("Audit transaction committed")
```

```lua
-- Callback alternative, using the same statements table.
MySQL.transaction(statements, function(committed)
    if not committed then
        print("[audit] Transaction did not commit")
        return
    end
    print("Audit transaction committed")
end)
```

```js
const committed = await MySQL.transaction([
    { query: "INSERT INTO example_audit (operation_id, kind) VALUES (?, ?)",
      values: [operationId, "note_created"] },
    { query: "INSERT INTO example_audit_details (operation_id, note) VALUES (?, ?)",
      values: [operationId, noteText] }
]);
if (!committed) console.log("[audit] Transaction did not commit");
else console.log("Audit transaction committed");
```

The inspected parser accepts `parameters` as an alias of each statement's `values`, and
also `{ sql, parameter_array }` pairs. The shared-parameter form passes an array of SQL
strings plus one parameter table to `transaction(statements, parameters[, callback])`.
Do not accidentally place a callback where a statement's parameter array belongs.

Database isolation is configured by the provider's `mysql_transaction_isolation_level`
(inspected values: 1 Repeatable Read, 2 Read Committed, 3 Read Uncommitted, 4 Serializable).
Inspect the active configuration and workload before changing it; a higher isolation level
does not make an unchecked zero-row debit a valid transfer.
