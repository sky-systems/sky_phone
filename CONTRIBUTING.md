# Contributing to Sky Phone

Sky Phone uses `dev` as its default integration branch. All normal changes reach `dev` through a pull request; do not push feature work directly to it.

## Branches

Create a short-lived branch from an up-to-date `dev` branch. Use lowercase kebab-case after one of these prefixes:

| Prefix      | Purpose                                          |
| ----------- | ------------------------------------------------ |
| `feat/`     | New behavior or app capability                   |
| `fix/`      | Bug fix                                          |
| `hotfix/`   | Urgent release repair                            |
| `docs/`     | Documentation only                               |
| `refactor/` | Internal change without intended behavior change |
| `perf/`     | Performance work                                 |
| `test/`     | Test-only work                                   |
| `build/`    | Build or packaging work                          |
| `ci/`       | GitHub Actions and repository automation         |
| `chore/`    | Focused maintenance                              |
| `release/`  | Release preparation                              |

`feature/` remains accepted for existing branches, but new feature branches should use `feat/`.

Examples: `feat/mail-signatures`, `fix/radio-focus`, `ci/release-package`. Avoid personal names, issue titles, uppercase characters, spaces, and branches that combine unrelated work.

## Commits and pull requests

Use the repository commit format:

```text
TAG - short imperative summary
```

Allowed tags are `ENH`, `ADD`, `FIX`, `DOC`, `BLD`, `PERF`, `CLN`, and `TRY`. Examples:

```text
FIX - validate mail ownership before deletion
ENH - add per-account notification settings
DOC - clarify Qbox installation order
```

Use the same format for the pull request title. Keep commits focused, stage only task files, link the issue, and complete the pull request template with actual commands and results.

## Architecture and security rules

- Sky Phone is standalone. It must not depend on or exchange state with `sky_base`, `sky_jobs_base`, or another `sky_*` resource.
- The server validates and decides permissions, identity, money, inventory, ownership, proximity, limits, and all other consequential state.
- Treat NUI and client payloads as untrusted. Every NUI callback must invoke its response callback on every reachable path.
- Parameterize SQL, keep persistence owned by `sky_phone`, and send only the required data over the network.
- Keep credentials, tokens, private endpoints, and player-identifying data out of source, fixtures, logs, issues, and pull requests.

## Schema, configuration, and compatibility

- Prefix new resource-owned tables, persistent keys, convars, callbacks, and events with `sky_phone` where the technology permits it.
- Keep the runtime schema in `sky_phone/source/server/db_migrate.lua` and the clean-install schema in `sky_phone/sql/install.sql` aligned.
- Prefer additive, idempotent migrations. Destructive or lossy migrations require an explicit migration plan, backup guidance, and reviewer approval.
- Do not force a database charset or collation unless a documented compatibility requirement has been reviewed.
- Preserve public events, callbacks, exports, configuration defaults, and stored data unless the linked issue explicitly authorizes a breaking change.
- Update both English and German locales for user-facing text. Logs and developer diagnostics remain in English.
- New or substantially changed NUI screens use the public Sky UI components and semantic tokens under `frontend/src/ui`.

## Local validation

Install frontend dependencies with pnpm, then run the checks relevant to the change:

```powershell
cd frontend
pnpm install --frozen-lockfile
pnpm typecheck
pnpm lint
pnpm test
pnpm build
```

The build publishes the generated NUI into `sky_phone/source/html`. Do not hand-edit generated output. A successful build proves source/build consistency, not behavior inside FiveM; report live runtime testing separately.

Lua, config, manifest, locale, SQL, and native changes must also be tested in a restarted FiveM resource with experimental OAL enabled. Pass native coordinates as separate numeric arguments and verify native signatures against authoritative documentation.

## Review and merge

A pull request is ready when required checks pass, review conversations are resolved, the latest push is approved by someone other than its author, and migrations or operational steps are explicit. The default ruleset allows merge, squash, and rebase so maintainers can preserve meaningful merge history when needed.

Release tags use numeric semantic versions without a `v` prefix, for example `0.2.0`. Tags are immutable after creation.
