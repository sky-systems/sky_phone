# AGENTS - sky_phone

## Scope

This repository contains the standalone FiveM resource `sky_phone`. These rules
apply throughout the repository unless a more specific `AGENTS.md` adds stricter
requirements.

## Repository governance for AI contributors

AI agents and automated coding tools must treat the repository governance files
as project instructions, not as optional documentation.

- Before changing code, read `CONTRIBUTING.md` and every more specific
  `AGENTS.md` that applies to the target files. For issue or pull-request work,
  also read the matching file under `.github/ISSUE_TEMPLATE` and
  `.github/PULL_REQUEST_TEMPLATE.md`.
- Before changing CI, packaging, releases, contribution policy, branch policy,
  or dependency handling, inspect all relevant files under `.github/workflows`,
  `.github/rulesets`, and `.github/scripts`. Keep their contracts synchronized.
- Preserve the required check names `Repository policy`, `Frontend`, `CodeQL`,
  `Dependency review`, and `Pull request policy`. If a task intentionally
  renames or replaces one, update `.github/rulesets/protect-dev.json`,
  `.github/scripts/validate-repository.mjs`, `.github/rulesets/README.md`, and
  the corresponding workflow in the same change.
- Anyone may open a pull request, but only collaborators with GitHub's built-in
  `Maintain` role may merge into `dev`, and maintainers must merge through a
  pull request. Preserve this behavior in branch rules and documentation.
- Treat `.github/rulesets/*.json` as the version-controlled ruleset baseline.
  Editing or merging these files does not update GitHub settings automatically;
  report that an administrator must import or reconcile the live ruleset.
- Preserve the secure PR artifact boundary: untrusted pull-request code may
  build the test resource only with read permissions. A workflow with write
  permissions may inspect trusted GitHub metadata and maintain the PR comment,
  but must never check out, download, extract, import, or execute PR-controlled
  code or artifacts.
- PR and release packages must contain one top-level `sky_phone` directory with
  `fxmanifest.lua` and the built NUI at `source/html/index.html`. Build generated
  NUI from `frontend`; never hand-edit `sky_phone/source/html`.
- Keep automated review and test-resource findings visible. Do not weaken,
  skip, or silence validation merely to make a check pass. Automated review
  complements and never replaces the required human maintainer review.
- After governance changes, run the repository validator, Prettier, and
  actionlint where available. Inspect the final diff and stage only files that
  belong to the task.

## Architecture and security

- Keep `sky_phone` independent. Do not add dependencies or integrations with
  `sky_base`, `sky_jobs_base`, or other `sky_*` resources.
- Keep resource-owned configuration, persistence, callbacks, events, and
  framework abstractions inside `sky_phone`.
- Prefix new resource-owned callbacks and events with `sky_phone:`.
- Keep client, server, and shared responsibilities separate. Prefer a local
  function when an export or network event is unnecessary.
- Treat all client and NUI input as untrusted. The server must authorize every
  state-changing action involving identity, permissions, ownership, money,
  inventory, proximity, or configured limits.
- Parameterize SQL and keep database objects owned by this resource.
- Never commit credentials, tokens, private keys, personal data, internal
  infrastructure details, or deployment-specific paths.

## FiveM and Lua

- Keep `use_experimental_fxv2_oal "yes"` enabled in the resource manifest.
- Pass native coordinates as separate numeric arguments. Do not pass a
  `vector3` where a native expects individual coordinates.
- Verify native signatures and use the documented parameter types.
- Use `joaat("...")`, `PlayerPedId()`, and vector distance where applicable.
- Treat native results as truthy or falsy values instead of comparing them with
  `true` or `false`.
- Avoid unconditional per-frame loops. Sleep while idle and use `Wait(0)` only
  while per-frame work is required.
- Keep failures visible in concise English diagnostics instead of silently
  swallowing invalid states.

## Frontend and NUI

- Use Vue 3 Composition API with TypeScript and the existing stores and router.
- Use the shared Sky UI through `@/ui` for new or substantially changed screens.
  Export reusable primitives through the relevant UI indexes.
- Do not add new direct `konsta/vue` imports.
- Use the shared semantic tokens and stylesheet order. Avoid duplicating common
  colors, spacing, radii, safe areas, or interaction geometry in app-local CSS.
- Localize all user-facing text through the phone locale system. Keep logs and
  developer diagnostics in English.
- Every NUI callback must invoke its response callback on every reachable path.
- Preserve one intended vertical scroll owner, visible keyboard focus, reduced
  motion support, and interaction targets of at least 44 CSS pixels.
- FiveM CEF is the runtime contract. Keep critical behavior compatible with the
  configured browser target and do not treat a desktop preview as live FiveM
  proof.
- Do not hand-edit generated frontend output.

## Phone Configurator parity (mandatory)

- Every new, changed, renamed, moved, or removed configurable value in
  `sky_phone/config/config.lua` or `sky_phone/config/media.lua` **must** be
  reflected in the in-game Phone Configurator in the same change. Config-only
  changes without matching Configurator support are incomplete and must not be
  committed or merged.
- Keep the Configurator's runtime schema, defaults, value types, fixed versus
  extensible collection rules, labels, descriptions, English and German
  locales, SQL persistence, validation, and save/load roundtrip aligned with
  the Lua configuration.
- The Configurator must remain complete when file-based configuration is
  disabled. Do not introduce a setting that can only be managed by editing Lua
  after `Config.PhoneConfigurator.Enabled` is enabled.
- Add or update contract/fixture coverage so configuration parity regressions
  fail automated checks.

## Working method and verification

1. Trace the relevant client, server, NUI, configuration, persistence, and event
   flow before changing behavior.
2. Fix the root cause with the smallest coherent change while preserving public
   compatibility unless the task explicitly changes it.
3. Verify external APIs and integrations against their current source or
   authoritative documentation.
4. Run the narrowest relevant checks and inspect the final diff.

For frontend changes, use the scripts declared in `frontend/package.json` as
appropriate, including type checking, linting, tests, and the production build.
Report build or browser-preview evidence separately from live in-game testing.

## Git

- Use `TAG - short imperative summary` for commit subjects.
- Supported tags are `ENH`, `ADD`, `FIX`, `DOC`, `BLD`, `PERF`, `CLN`, and `TRY`.
- Keep commits focused and document required configuration, locale, or database
  migrations.
- Stage only files belonging to the task and preserve unrelated worktree
  changes.
