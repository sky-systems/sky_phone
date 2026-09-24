# Errors, provider results and yielding

Fail clearly on broken internal invariants. Validate real external boundaries such as client
payloads, absent players, provider failures and missing persisted records. When AGENTS requires the Sky bridge,
documented `Sky`/`Sky_Jobs` APIs are guaranteed: call them directly without existence checks.
Explain defensive rejection in English diagnostics; keep user-facing responses localized.

`pcall` returning true means the call did not throw; it does not mean the provider operation
succeeded. Inspect the returned result separately. Some APIs return false, some return no
status, and promises can reject. For a void write, verify post-state where the task needs proof
of success. Do not introduce pcall/retries/fallbacks merely to hide an unexplained error.

`Citizen.Await` yields a scheduler coroutine and raises a rejected promise value. Provider
await wrappers may propagate this; they do not guarantee nil on failure. Capture event source
before any yield and use the established operation lock/session identity handling. Keep claims
or once-only transitions protected before a yielding side effect and release/compensate through
the resource's defined failure path. Handle cancellation/disconnect without reusing stale state.

## Invariants versus expected rejection

Use a precise assertion for an internal condition that must hold. Test the actual invariant:
`assert(record ~= nil, "Expected the prepared record")` allows false, while `assert(record, ...)`
does not. Do not mechanically replace a check with a differently defined condition, or add
assertions around guaranteed framework APIs.

Expected validation failures can return an explicit error value for the caller to handle:

```lua
local function parse_quantity(raw_quantity)
    if type(raw_quantity) ~= "string" and type(raw_quantity) ~= "number" then
        return nil, "invalid_quantity"
    end

    local quantity = tonumber(raw_quantity)
    if quantity == nil or quantity % 1 ~= 0 or quantity < 1 or quantity > 100 then
        return nil, "invalid_quantity"
    end

    return quantity
end

local quantity, reason = parse_quantity("3")
if quantity == nil then
    print(("Quantity rejected: %s"):format(reason))
    return nil, reason
end
-- Continue with the validated quantity under the operation's authority checks.
```

The caller must handle the result; an error value is not permission to fail invisibly. Translate
the rejection through the resource's existing localized response path. A parser does not grant
ownership, permission, inventory capacity or funds.

An error aborts the current call path. For independent batch items, record a recoverable failure
and continue only if partial completion is the defined contract; an all-or-nothing operation
needs its transaction/compensation path instead. Design idempotent operations where appropriate:
an already-satisfied requested state can be a successful no-op. Repeating a payout is a side
effect, so it requires an operation identity and once-only claim, not a repeated success flag.

[Lua protected calls and pinned scheduler evidence](reference-links.md).
