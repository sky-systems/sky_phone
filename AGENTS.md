# AGENTS - sky_phone

This workspace contains the standalone FiveM resource `sky_phone`. These rules apply to every file
in this repository unless a more specific `AGENTS.md` explicitly tightens them.

## Hard architecture boundary

`sky_phone` is an independent product. It must not depend on, import, call, configure, or exchange
state with `sky_base`, `sky_jobs_base`, or any other Sky resource.

- Never add a manifest dependency, shared script, import, export, callback, or event integration for
  `sky_base`, `sky_jobs_base`, or another `sky_*` resource.
- Never use the `Sky`, `Sky_Jobs`, `Sky.FW`, `Sky.Cb`, `Sky.DB`, `Sky.Query`, or similar globals and
  APIs supplied by those resources.
- Never read or write their config, state bags, database tables, files, caches, or runtime state.
- Never trigger or handle their event namespaces, including `sky_base:*` and `sky_jobs_base:*`.
- Do not add a compatibility adapter, optional fallback, or resource-state probe for them. The
  separation is intentional, including when one of those resources happens to be installed.
- `sky_phone` owns its code, configuration, persistence, localization, callbacks, events, and any
  framework abstraction it needs.

Third-party integrations are allowed only when they are part of the phone's own documented design.
Keep each one explicit and isolated so disabling it does not create an implicit Sky dependency.

## Frontend conventions

- Use Vue 3 Composition API with TypeScript, Pinia for state, and Vue Router for views.
- Use 2-space indentation, single quotes, PascalCase component names, and kebab-case filenames.
- All user-facing copy must resolve through the frontend language store and originate in
  `sky_phone/config/locales/`.
- The phone intentionally uses Konsta UI's iOS liquid-glass styling. Any `backdrop-filter` or
  `-webkit-backdrop-filter` prohibition inherited from sibling-resource conventions does not apply
  anywhere in `sky_phone`; these effects are explicitly allowed here.
- For every design implementation, prefer Konsta UI's native iOS components (for example Navbar,
  Tabbar, Sheet, Dialog, List, Card, Button, and Glass) over custom equivalents. Preserve their
  built-in iOS interaction, motion, active, and glass behavior so the phone feels native; add
  scoped styling only where the product design requires it.

## Working method

1. Trace the real client, server, NUI, config, persistence, and event flow before changing code.
2. Fix the root cause with the smallest coherent change; do not mask symptoms with waits, retries,
   broad guards, or silent fallbacks.
3. Preserve existing public behavior and compatibility unless the task explicitly changes it.
4. Treat the server as authoritative for permissions, identity, money, inventory, and all other
   state-changing actions. Never trust NUI or client payloads.
5. Verify every native, framework API, export, and external integration against the current source
   or authoritative documentation. Do not invent interfaces.
6. Inspect the final diff and run the narrowest relevant tests or builds before handing work back.

## Resource conventions

- The resource and its own public namespace are `sky_phone`.
- Prefix resource-owned net events and callbacks with `sky_phone:`.
- Prefix new resource-owned database tables, convars, and persistent keys with `sky_phone` where the
  surrounding technology permits it, to avoid collisions.
- Keep client-only, server-only, and shared code separate. Do not expose an export or net event when
  a local function is sufficient.
- Use `joaat("...")` instead of `GetHashKey("...")`.
- Check FiveM native results as truthy/falsy values; do not compare them with `== true` or
  `== false`.
- Use `PlayerPedId()` instead of `GetPlayerPed(-1)` and vector distance (`#(a - b)`) instead of
  `GetDistanceBetweenCoords`.
- Avoid unconditional `Wait(0)` loops. Sleep while idle and use per-frame work only while needed.
- Do not create one-line wrapper functions that only return another function call or expression.
- Keep defensive failures visible in English debug logs; never silently swallow an invalid state.

## Experimental OAL is enabled

The resource manifest must contain `use_experimental_fxv2_oal "yes"`. OAL provides faster native
calls and more accurate return types, but it is experimental and changes how natives must be called.

- Vector unpacking into native arguments no longer works. Never pass a `vector3` where a native
  expects separate coordinates: use `coords.x, coords.y, coords.z` explicitly.
- Native parameter types must match the documented types. OAL does not tolerate relying on implicit
  conversion of a wrong type; undocumented or incorrectly documented natives can therefore fail in
  unexpected ways.
- Verify every native signature before use and test affected calls with OAL enabled.

```lua
local coords = vector3(1, 2, 3)

SetEntityCoords(ped, coords) -- invalid with OAL
SetEntityCoords(ped, coords.x, coords.y, coords.z) -- valid with OAL
```

## Security and data ownership

- The client may request an action; the server validates and decides the result.
- Revalidate permissions, ownership, proximity, rate limits, identifiers, and configured limits on
  the server before changing state.
- Parameterize SQL and keep schema/migrations owned by `sky_phone`. Do not reuse tables owned by
  other Sky resources.
- Send the smallest required payload across the network and never accept client-provided prices,
  rewards, balances, roles, or ownership as truth.
- Keep secrets and credentials out of source, NUI bundles, logs, examples, and commits.

## UI and localization

- Treat NUI input as untrusted and validate consequential actions server-side.
- Every NUI callback must call its response callback on every reachable path.
- Localize all user-facing text through the phone's own locale system.
- Logs and developer diagnostics stay in English and do not belong in locale files.
- After frontend work, run the repository's actual frontend build and verify the generated output
  expected by `fxmanifest.lua`.

## Local deployment

- The deployable resource lives at `sky_phone/` inside this repository.
- After frontend changes, run `build_frontend.bat`; it builds `sky_phone/frontend` and then runs
  `build_copy.bat` automatically.
- After Lua, config, locale, SQL, manifest, or other resource-only changes, run `build_copy.bat`
  before handing the task back.
- `build_copy.bat` deploys only `sky_phone` to the configured ESX and Qbox `[sky]` directories.
- Use `build_copy.bat -DryRun` to validate source and target paths without deleting or copying files.
- A successful copy proves source/deployment consistency, not live FiveM runtime behavior.

## Commits

- Format: `TAG - short imperative summary`.
- Tags: `ENH`, `ADD`, `FIX`, `DOC`, `BLD`, `PERF`, `CLN`, `TRY`.
- Keep commits focused and call out required config, SQL, or locale migrations.
- Stage only files belonging to the task; never use broad staging that captures unrelated work.
