# Resource structure

Keep existing resource/package boundaries and manifest load order. Separate client, server
and genuinely shared code so authority and available APIs are visible. Shared files are shipped
to clients; secrets and server-only rules belong in server code.

Use the least exposure the caller needs: local function for internal work, exports for an
explicit cross-resource API, events for notifications and network events for remote requests.
These are different contracts, not interchangeable wrappers. A bare `function Name()` normally
assigns a global; it is not a file-local declaration.

Group code by ownership and lifecycle. Prefer names and paths already used by the resource.
When required by the applicable Sky bridge workspace rules, use underscore resource names, lowercase filenames, four-space indentation,
double quotes, snake_case locals and PascalCase classes. Do not create one-line wrappers.

For a new resource, a small layout can make the execution sides visible:

```text
example_resource/
  fxmanifest.lua
  shared/config.lua
  client/state.lua
  client/main.lua
  server/main.lua
  server/persistence.lua
```

Keep a public operation and its private helpers together when that hides implementation
details. Place function-local values near their use; group longer-lived state at its owning
module's top. Either declaration-kind grouping or call-order grouping can work; do not
scatter an operation across files just to make every file smaller. Declare intentional
globals in one owning file per execution side rather than redefining them in each consumer.
Use names without spaces and follow existing resource/file naming instead of renaming public
resources for cosmetic consistency.

See [manifest semantics and runtime sources](reference-links.md).
