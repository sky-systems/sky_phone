---
name: fivem-dev
description: FiveM development orchestrator for the standalone sky_phone resource, covering Lua, NUI, security, framework adapters, ox_lib, oxmysql, and optional external integrations. Use when creating or editing FiveM Lua, manifests, client/server events, NUI, SQL, or integrations in this repository.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, WebFetch
---

# FiveM development orchestrator for sky_phone

Use this guide together with the root `AGENTS.md`. The phone is standalone: never introduce a
dependency or interaction with `sky_base`, `sky_jobs_base`, another `sky_*` resource, or their
globals, APIs, events, state, files, config, and database tables.

## Core workflow

1. Trace the complete client, server, NUI, config, persistence, and integration flow.
2. Verify natives and external APIs against authoritative documentation or installed source.
3. Identify the root cause and make the smallest coherent fix.
4. Preserve server authority and validate every client-controlled value.
5. Run focused syntax checks, tests, and the real frontend/resource build when present.
6. Inspect the final diff for accidental coupling, generated-file drift, and unrelated edits.

## Standalone boundary

- The resource namespace is `sky_phone`.
- Do not add `sky_base`, `sky_jobs_base`, or another Sky resource to `dependency`, `dependencies`,
  `shared_script`, `server_script`, or `client_script` entries.
- Do not use `Sky`, `Sky_Jobs`, `Sky.FW`, `Sky.Cb`, `Sky.DB`, `Sky.Query`, Sky exports, or Sky event
  namespaces.
- Do not probe whether those resources are started and do not add optional compatibility fallbacks.
- Build phone-owned framework, callback, persistence, notification, and logging adapters where the
  existing phone architecture calls for them.
- Third-party integrations must be explicit, documented, isolated, and verified from their own
  source/API. Never route them through another Sky resource.

## Source verification

Never invent a native, framework API, export, event, parameter, or return type.

| Topic | Authoritative source |
|---|---|
| FiveM natives | https://docs.fivem.net/natives/ |
| FiveM events, manifests, NUI | https://docs.fivem.net/docs/ |
| ESX | https://docs.esx-framework.org/ |
| QBCore | https://docs.qbcore.org/ |
| Qbox | https://docs.qbox.re/ |
| ox_lib / oxmysql | https://coxdocs.dev/ |
| Fivemanage | https://docs.fivemanage.com/ |

Before using a framework or library API, inspect `fxmanifest.lua`, configuration, lockfiles, and the
installed integration code to determine the actual version and context. Prefer the phone's existing
adapter over scattering direct framework calls across feature code. If an adapter is missing, add it
inside `sky_phone`; do not borrow one from another resource.

## Lua and resource structure

- Use 4-space indentation, double quotes, `snake_case` locals, and `PascalCase` classes when the
  surrounding source does not establish a stronger convention.
- Prefer locals and guard clauses. Do not create wrappers that merely return another call.
- Use `joaat("...")`, `PlayerPedId()`, and vector distance (`#(a - b)`).
- Treat native results as truthy/falsy; avoid strict comparisons with `true` or `false`.
- Separate client, server, shared, config, locale, and NUI concerns.
- Use a local function before a resource export, local event, callback, or network event.
- Prefix public resource-owned events and callbacks with `sky_phone:`.
- Avoid per-frame loops unless rendering/input truly requires them; dynamically increase `Wait()`
  while idle.

A manifest may declare only dependencies that `sky_phone` actually uses and documents:

```lua
fx_version "cerulean"
game "gta5"

shared_scripts { "config.lua" }
client_scripts { "client/*.lua" }
server_scripts { "server/*.lua" }

ui_page "html/index.html"
files { "html/index.html", "html/**/*" }
```

Add library imports such as ox_lib or oxmysql only when confirmed in the resource architecture.

## Server authority and events

- The client and NUI request; the server validates and applies.
- Re-check identity, authorization, ownership, distance, state, rate limits, and configured limits on
  the server.
- Never accept client-provided balances, prices, rewards, item counts, roles, phone ownership, or
  recipient identity as authoritative.
- Send minimal network payloads and use state bags for suitable replicated state rather than event
  spam.
- Rate-limit sensitive and spammable actions with phone-owned server logic.
- Log rejected or suspicious actions without leaking secrets or personal data.

```lua
RegisterNetEvent("sky_phone:server:updateSetting", function(setting_name, requested_value)
    local src = source
    if not isAllowedSetting(setting_name, requested_value) then
        logSecurityEvent(src, "invalid phone setting update")
        return
    end

    updateOwnedPhoneSetting(src, setting_name, requested_value)
end)
```

The example names describe responsibilities, not guaranteed existing APIs. Resolve them to actual
phone-owned functions after inspecting the repository.

## NUI

- Declare the real `ui_page` and generated files in `fxmanifest.lua`.
- Lua to UI: use `SendNUIMessage`; manage focus with `SetNUIFocus` and always release it on close.
- UI to Lua: post to `https://${GetParentResourceName()}/callbackName` and handle it with
  `RegisterNUICallback`.
- Treat every NUI payload as untrusted. Send consequential requests to the server and validate there.
- Call the NUI response callback on every reachable path so browser requests cannot hang.
- Keep user-facing strings in the phone's locale system; logs remain English-only.

## SQL and persistence

- Use the persistence layer already owned by `sky_phone`.
- Parameterize every value; never concatenate client input into SQL.
- Own phone schema and migrations under this repository and use collision-resistant `sky_phone`
  table/key prefixes where appropriate.
- Never query or mutate tables owned by `sky_base`, `sky_jobs_base`, or another Sky resource.
- Use transactions for multi-step mutations that must succeed or fail together.
- Treat deployment/schema checks as static evidence, not proof of live server behavior.

## Anti-patterns

- Adding a Sky dependency, import, export, event, state probe, or database shortcut.
- Trusting NUI or client state for permissions or mutations.
- Hiding failures with broad guards, `pcall`, arbitrary waits, retries, or silent fallbacks.
- Hardcoding direct framework calls throughout feature code instead of using the phone's adapter.
- Re-fetching stable data every frame.
- Leaving NUI callbacks unanswered.
- Editing generated frontend output without updating its source and running the build.

## Final verification

- Search the diff for forbidden Sky dependencies and symbols.
- Validate manifest paths and dependency order.
- Run targeted Lua/JS/TS checks, tests, and builds available in the repository.
- Verify SQL/config/locale migrations are explicit.
- Clearly distinguish static/build validation from live FiveM runtime proof.
