## Summary

<!-- What user or developer problem does this PR solve? -->

Closes #

## Root cause and approach

<!-- For fixes: trace the real failing path. For features: explain the chosen boundary and behavior. -->

## Changes

-

## Compatibility and migrations

<!-- List config, locale, SQL, framework, public API, event, export, or deployment impact. Write "None" when not applicable. -->

## Validation

- [ ] I ran the narrowest relevant automated tests.
- [ ] I ran `pnpm typecheck`, `pnpm lint`, and `pnpm test` for frontend changes.
- [ ] I ran a production frontend build for frontend changes.
- [ ] I tested affected Lua/native behavior with experimental OAL enabled, or marked the live runtime test as pending below.
- [ ] I verified every changed NUI callback responds on every reachable path.
- [ ] I reviewed the final diff and excluded unrelated work and generated-only edits.

Commands and results:

```text

```

## Runtime evidence

<!-- Distinguish local/static/build checks from an actual restarted FiveM runtime test. Add screenshots for visible UI changes. -->

## Security and architecture

- [ ] Consequential actions remain server-authoritative and validate identity, permissions, ownership, limits, and payloads.
- [ ] This change introduces no dependency, event, export, global, config, persistence, or fallback connection to another `sky_*` resource.
- [ ] No secret, credential, private URL, or personal player data is included.

## Reviewer notes

<!-- Call out risky areas, intentional tradeoffs, or follow-up work. -->
