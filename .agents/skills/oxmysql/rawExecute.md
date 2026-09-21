# rawExecute

MySQL.rawExecute uses the prepared execute path, with less automatic result unpacking than
prepare. It is not an escape hatch for concatenating raw client SQL. Use bound ? values.

A SELECT retains row-oriented results rather than prepare's single-value/row extraction.
Inspect result nesting for the statement and number of parameter sets instead of guessing
the return shape. Prefer query/insert/update/single/scalar when their explicit contract fits.

[RawExecute docs](https://overextended.dev/docs/oxmysql/Functions/rawExecute)
and [rawExecute/connection source](sources.md).

## Single-parameter-set examples

[Example setup](examples-setup.md). This bounded SELECT preserves the row collection,
including for a single matching row. Multi-set result nesting must be checked separately.

```lua
local sql = "SELECT id, note FROM example_notes WHERE id = ? AND owner = ? LIMIT 1"
local rows = MySQL.rawExecute.await(sql, { note_id, owner_key })
if rows[1] then print(("Found note: %s"):format(rows[1].id)) end

-- Callback alternative.
MySQL.rawExecute(sql, { note_id, owner_key }, function(result)
    if result[1] then print(("Found note: %s"):format(result[1].id)) end
end)
```

```js
const rows = await MySQL.rawExecute(
    "SELECT id, note FROM example_notes WHERE id = ? AND owner = ? LIMIT 1", [noteId, ownerKey]
);
if (rows[0]) console.log("Found note:", rows[0].id);
```

At the pinned execute converter, SQL `DATE`/`NEWDATE`, `DATETIME`/`DATETIME2` and
`TIMESTAMP`/`TIMESTAMP2` fields become epoch milliseconds or null; `TIME` falls through to the driver.
It does not add the query converter's boolean mapping for one-digit TINY / one-byte BIT
values 0 and 1. Check the actual driver representation and timezone semantics; do not assume
formatted date strings or identical booleans. See `typeCast.ts` in the [source map](sources.md).
