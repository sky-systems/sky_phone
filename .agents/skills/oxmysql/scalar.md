# scalar

MySQL.scalar.await(sql, parameters) returns the first column of the first row, or nil when
there is no value. Use it for a single field or aggregate, not as a row object.

Preserve meaningful false/zero values; Lua zero is truthy. COUNT over no matches is usually
zero rather than a missing row. Check null/type conversion at the installed driver boundary.
Await rejection is distinct from an absent scalar.

[Scalar docs](https://overextended.dev/docs/oxmysql/Functions/scalar), [source](sources.md).

## Examples

[Example setup](examples-setup.md); a count consumes a scalar, not `result.count`:

```lua
local sql = "SELECT COUNT(*) FROM example_notes WHERE owner = ?"
local count = MySQL.scalar.await(sql, { owner_key })
print(("Note count: %s"):format(count))

-- Callback alternative.
MySQL.scalar(sql, { owner_key }, function(result)
    print(("Note count: %s"):format(result))
end)
```

```js
const count = await MySQL.scalar("SELECT COUNT(*) FROM example_notes WHERE owner = ?", [ownerKey]);
console.log("Note count:", count);
```

For an optional field lookup, test Lua `value == nil` / JS `value == null` when absence is
the distinction. An expression such as JS `value || fallback` also replaces legitimate zero.
