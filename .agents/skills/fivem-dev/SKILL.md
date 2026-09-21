---
name: fivem-dev
description: Implement or debug standalone sky_phone Lua, events, adapters, persistence and NUI integration. Use only for the Phone workspace; preserve its own resource and API boundaries.
---

# Standalone sky_phone development

Resolve the Phone repository first; read its `AGENTS.md`, `CONTRIBUTING.md`, and applicable workspace or nested instructions. Reuse them instead of loading every skill or repeating their policies.

## Architecture boundary

`sky_phone` owns its framework adapters, callbacks, persistence, configuration and state. Never introduce dependencies, imports, API calls, exports, events, probes, fallbacks or state/data access involving `sky_base`, `sky_jobs_base`, other Sky resources, `Sky` or `Sky_Jobs`. Phone Sky UI is its own frontend library; it does not relax this boundary. Verify existing Phone symbols in source before using them.

## Workflow

1. Trace the affected client/server/NUI and configuration flow to its owner; fix the root cause with the smallest coherent change.
2. Verify each used Cfx API in [official documentation](https://docs.fivem.net/docs/) or the [native reference](https://docs.fivem.net/natives/), then inspect the matching [official source](https://github.com/citizenfx/fivem) registration, wrapper and call path. Record revision, execution context, parameter/return behavior and any unavailable engine-source boundary. Reuse already verified evidence for the same revision and API.
3. Resolve third-party versions from the installed integration and verify their actual contract. Reuse Phone-owned adapters; do not scatter framework calls through features.
4. Keep authorization, ownership, proximity, rates and consequential values server-owned. Parameterize SQL; complete every NUI response path. Preserve public contracts and stored data.
5. Read only the matching specialist and references below, then inspect the focused diff and validate the changed behavior.

| Need | Read |
|---|---|
| Manifest, Cfx events, lifecycle or profiling | [fivem-basics](../fivem-basics/SKILL.md) |
| Lua semantics or errors | [lua-basics](../lua-basics/SKILL.md) |
| Server mutations or trust boundaries | [fivem-security](../fivem-security/SKILL.md) |
| NUI transport, focus or frontend runtime | [fivem-nui](../fivem-nui/SKILL.md) |
| ESX adapter contract | [esx-framework](../esx-framework/SKILL.md) |
| Existing ox_lib or SQL integration | [oxlib](../oxlib/SKILL.md) or [oxmysql](../oxmysql/SKILL.md) |

For an existing non-ESX integration, start with its installed Phone adapter and the matching primary docs: [QBCore](https://docs.qbcore.org/), [Qbox](https://docs.qbox.re/), or [Fivemanage](https://docs.fivemanage.com/). Verify version-specific signatures and responses in upstream/installed source; these links do not authorize adding an integration or routing through another Sky resource.

## Phone-specific invariants

- Where existing source establishes no stronger style, use four-space indentation, double quotes, snake_case locals and PascalCase classes. Keep useful local functions; do not introduce one-line wrapper aliases.
- Keep experimental OAL enabled; pass correctly typed native arguments and separate coordinate components. Validate affected calls with OAL enabled.
- Config changes in `sky_phone/config/config.lua` or `media.lua` require matching Phone Configurator schema, defaults, types, labels, English/German locales, persistence, validation and save/load coverage. Preserve operation when file configuration is disabled.
- New or substantially changed screens use `@/ui`, shared tokens and the Phone UI ADR. No new direct `konsta/vue` imports. Localize visible text through Phone locales; diagnostics stay English. Never hand-edit generated NUI.
- Prefix new owned events/callbacks and persistent objects with `sky_phone` as required by the repository rules. Keep schemas and migrations aligned.

## Verification and local delivery

Use the narrowest relevant repository checks. In the local `Scripts_Phone` container, `build_frontend.bat` builds `sky_phone/frontend` and invokes copying; resource-only edits use `build_copy.bat`. The deployable folder is `sky_phone/sky_phone` relative to that container. Skill-only edits do not change that resource.

Distinguish syntax/tests, generated output, deployment parity and actual FiveM/OAL runtime evidence. Search the diff for accidental Sky coupling, unrelated changes and migration requirements. Keep existing Git/PR governance and authorization boundaries.
