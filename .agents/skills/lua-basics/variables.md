# Scope and lifetime

Use local bindings unless an API deliberately exposes state. A bare function declaration is
not automatically file-local. Keep names consistent with the owning resource; the Sky bridge workspace
uses snake_case locals, PascalCase classes, four spaces and double quotes.

A closure captures a variable, not a frozen snapshot of its value. Decide whether a callback
needs the current binding, a request-local snapshot or a stable identifier to re-resolve later.
Capture FiveM event `source` locally before yielding. Numeric player sources and entity handles
must not become long-lived identity records across disconnect/recreation.

Represent mutually exclusive workflow phases with one explicit state rather than independent
booleans that allow impossible combinations. Keep state transitions with their owning module.
If a table is keyed by a session/player, define cleanup and stale-work rejection at that lifecycle.
Do not add generic state machinery when existing ownership already handles the case.

## Names, placement and ignored values

Declare a function-local value near its use. Keep long-lived module state and intentional globals
in a clear owning section; initialize a shared global in one owning file per client/server context
rather than scattering competing definitions across files. Shared scripts still run separately
on the client and server.

Where the owning module uses upper-case constants, use a descriptive name such as `MAX_ATTEMPTS`;
capitalization alone does not prevent reassignment. Lua 5.4's `<const>` makes the binding constant:

```lua
local MAX_ATTEMPTS <const> = 3
local SETTINGS <const> = { enabled = true }
SETTINGS.enabled = false -- Legal: the table itself is not frozen.

for _, label in ipairs({ "first", "second" }) do
    print(label)
end
```

`_` is an ordinary variable conventionally used for an ignored result, not special discard syntax.
Follow the resource's naming convention for ordinary locals instead of imposing the archive's
generic camelCase rule on a snake_case codebase.

Lua 5.4 also supports `<close>` locals. A non-nil/non-false value must supply `__close`; the scope
exit calls that metamethod, including when unwinding an error. This is resource-lifetime behavior,
not a general substitute for the owning asynchronous operation's explicit cleanup policy.

## One state for mutually exclusive phases

```lua
local PHASE = {
    IDLE = "idle",
    PREPARING = "preparing",
    COMPLETE = "complete",
}
local phase = PHASE.IDLE

-- A transition changes one state, rather than allowing preparing and complete together.
phase = PHASE.PREPARING
```

Use an explicit unknown state only when the model actually permits incomplete information.
Separate booleans remain appropriate for independent facts that can legitimately hold together.

[Lua scope and CFX scheduler evidence](reference-links.md).
