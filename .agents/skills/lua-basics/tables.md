# Tables, sequences and ownership

Use `pairs` for maps and `ipairs` or numeric iteration for dense sequences. `ipairs` stops at
the first nil. The default `#table` operator finds a border; it is not a reliable entry count
for sparse tables or maps. Lua 5.4 documents O(log n) worst-case border lookup, not an O(n)
scan. A `__len` metamethod can define other behavior.

For a dense append, `items[#items + 1] = value` is clear. Use `table.insert` for positional
insertion and `table.remove` when shifting a sequence is intended. Setting a middle element
to nil creates a hole; it is not equivalent to removing and shifting. Maintain an explicit
count only when the data representation requires it or profiling justifies it.

Table assignment, arguments and returns share references in ordinary Lua. A shallow copy
still shares nested tables; table equality normally compares identity. Compare the relevant
nested content when a provider copied/serialized it. Reusing a scratch table across concurrent
yielding requests can corrupt data; do not make reuse a universal optimization rule.

Dropping one reference permits collection only when the object is otherwise unreachable.
Prefer bounded caches and lifecycle cleanup to redundant `value = nil` assignments at scope end.

## Dense sequences and named keys

```lua
local labels = { "first", "second", "third" }
labels[#labels + 1] = "fourth"
table.insert(labels, 2, "inserted") -- Shift later sequence elements.
table.remove(labels, 2) -- Close the gap again.

for index = 1, #labels do
    print(index, labels[index])
end

local company = { boss = "Sam" }
local field = "boss"
print(company.boss) -- A constant key that is a valid identifier.
print(company[field]) -- A computed key.
company[field] = "Alex" -- Assign a map entry directly.
```

Use implicit array indices for a dense literal unless explicit indices carry meaning.
`table.insert(map, "key", value)` is not string-key assignment: its optional position must be
an integer. Dot access is shorthand for a constant string key; brackets are also necessary
for keys such as `record["display-name"]`.

For a map, iterate entries with `for key, value in pairs(map) do ... end`; its iteration order
is not a sorting contract. `ipairs(labels)` also fits the dense sequence above. Pick the
iteration form for the representation rather than claiming one is always faster.

Extract a repeated lookup when it clarifies the expression:

```lua
local boss = company.boss
local diagnostic = boss .. ": " .. boss
```

That local is a snapshot of the lookup, so re-read it if intervening code can replace the value.
For table-valued fields, the local still references the same nested table. Indexing can also
invoke `__index`; changing lookup frequency can change behavior, not just runtime cost.

See [Lua semantics and the pinned Cfx table implementation](reference-links.md).
