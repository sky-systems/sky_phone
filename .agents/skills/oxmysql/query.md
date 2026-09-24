# query

MySQL.query.await(sql, parameters) returns an array of row objects for SELECT. A non-SELECT
statement returns a result header with fields such as insertId and affectedRows, not those
scalar numbers directly. Use insert/update when their scalar contracts are desired.

Select only needed columns and bound rows. An empty result array is a successful empty result;
it is not an SQL error. Lua empty tables are truthy. Await rejection can raise, so do not equate
nil/false checks with complete error handling. The callback form receives the result instead
of returning it synchronously.

[Official query contract](https://overextended.dev/docs/oxmysql/Functions/query)
and [parseResponse/rawQuery source](sources.md).

## Lua await and callback examples

See [imports and example schema](examples-setup.md). Select a bounded, deterministic page:

```lua
local sql = "SELECT id, note FROM example_notes WHERE owner = ? ORDER BY id DESC LIMIT 20"
local rows = MySQL.query.await(sql, { owner_key })
for _, row in ipairs(rows) do
    print(("Note id: %s"):format(row.id))
end

-- Alternative callback style; its return does not synchronously contain rows.
MySQL.query(sql, { owner_key }, function(result)
    print(("Returned notes: %d"):format(#result))
end)
```

## JavaScript

```js
const sql = "SELECT id, note FROM example_notes WHERE owner = ? ORDER BY id DESC LIMIT 20";
const rows = await MySQL.query(sql, [ownerKey]);
for (const row of rows) console.log("Note id:", row.id);

// Optional callback alternative; await also observes promise rejection.
await MySQL.query(sql, [ownerKey], (result) => {
    console.log("Returned notes:", result.length);
});
```

For a non-SELECT statement, inspect the returned header (`result.affectedRows`,
`result.insertId`) or select the dedicated helper. Do not iterate a mutation header as rows.
