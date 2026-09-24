# Functions and return contracts

Give a function one coherent responsibility; split it when that improves ownership or reuse,
not merely to satisfy a line/parameter count. Keep local helpers local. When the applicable Sky bridge workspace rules require it, do not
create one-line wrapper aliases. Follow the owning module's public signatures and naming.

Document meaningful arguments, return values, side effects and whether a call can yield.
Lua functions can return several values; forwarding through a table, parentheses or an
expression may alter how many survive. Preserve the contract deliberately. Use
`table.pack(...)` and its `n` with `table.unpack(values, 1, values.n)` when nil-bearing varargs matter.

Ordinary Lua table arguments and returns share a table reference; they are not implicit deep
copies. Cross-resource exports/network calls add separate serialization and lifetime rules.
Inspect that boundary rather than assuming local mutation or identity semantics survive it.
Choose batching/accessor granularity based on semantics and measured provider work.

Anonymous callbacks are appropriate where their captures/lifetime are needed. Hoisting every
closure is not a universal performance improvement. Avoid retaining player objects or large
payloads after their owning request/session ends.

## Parameters and documented exports

For a new signature, put required parameters before optional ones. Use a leading verb when it
clarifies the operation, and preserve established public names/signatures when repairing an API.
Group related settings into a named options table when that makes calls easier to understand;
there is no mandatory parameter-count limit. A boolean can be legitimate data. Avoid an opaque
mode flag that makes one function perform unrelated operations, and avoid overloads whose types
or return shapes are ambiguous. Keep high-level orchestration readable separately from detailed
implementation when that separation has a real purpose.

Use LuaLS annotations for public/exported arguments and returns, including optional values.
This example gives the optional separator an explicit nil default:

```lua
---@param labels string[]
---@param separator string|nil
---@return string joined_labels
local function join_labels(labels, separator)
    if separator == nil then
        separator = ", "
    end

    return table.concat(labels, separator)
end

exports("JoinLabels", join_labels)
```

The export registration is FiveM-specific; follow the same-side provider/consumer and lifetime
rules in [exports](../fivem-basics/exports.md). Annotations describe a contract; they do not
validate untrusted input at runtime.

## Preserve nil-bearing multiple returns

```lua
local values = table.pack("first", nil, "third")
local first, second, third = table.unpack(values, 1, values.n)
-- first == "first", second == nil, third == "third", values.n == 3
```

The explicit end index preserves the nil slot. A plain table length cannot establish that
three values were supplied when the sequence contains holes. Likewise, `return operation()`
forwards all results, whereas `return (operation())` adjusts the call to one result.

[Lua/manual and CFX function-reference evidence](reference-links.md).
