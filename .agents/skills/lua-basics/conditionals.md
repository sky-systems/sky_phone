# Conditional semantics

Only nil and false are false in Lua. Numeric zero and the empty string are true. `or` chooses
an operand; it is not a ternary operator. `value or default` replaces both nil and false, so
use an explicit nil check when false is a valid configured value. Likewise, `a and b or c`
fails as a ternary when b is false/nil.

Match comparisons to the contract: distinguish absent data, false status, zero counts and
empty sequences. For numeric handles or counts, check the documented invalid/zero condition.
Under the Sky bridge workspace rules, preserve truthy native boolean checks rather than `== true`/`== false`; verify
the actual binding representation instead of explaining this with false numeric-zero semantics.

Prefer readable early exits or positive branches as appropriate. Unexpected failed invariants
need an explanatory error; expected boundary rejection needs the resource's explicit result
and diagnostics. Do not replace this distinction with silent blanket guards.

## Defaults and direct expressions

```lua
local display_name = supplied_name or "Unknown" -- Both nil and false mean absent here.

local enabled = configured_enabled
if enabled == nil then
    enabled = true -- Preserve an explicitly configured false.
end

local is_supported = mode == "walk" or mode == "run"
-- No if/else is needed merely to assign true or false from that comparison.
```

Default text that is shown to a player must come from the resource locale. The example's
`"Unknown"` is a placeholder, not a new untranslated UI label. Prefer a positive branch when
both branches are equally readable; use an early rejection when it removes distracting nesting.

[Lua truthiness and expressions](https://www.lua.org/manual/5.4/manual.html#3.4.5).
