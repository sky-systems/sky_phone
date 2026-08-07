# Konsta UI reference for sky_phone

This directory is the durable, project-specific Konsta UI reference for `sky_phone`. Read it before
creating or substantially changing phone UI.

## Version and source of truth

- `frontend/package.json` allows Konsta UI `~5.2.0`.
- `frontend/pnpm-lock.yaml` currently locks `konsta@5.2.0`.
- Vue components are imported from `konsta/vue`.
- The theme is loaded once in `frontend/src/assets/main.css` with
  `@import 'konsta/vue/theme.css';`.
- `frontend/node_modules/konsta/vue/konsta-vue.d.ts` is the exact local API contract after
  dependencies are installed.

When documentation, memory, and installed declarations differ, use the declarations for the locked
version. Confirm behavior in the installed component source when types alone are insufficient.

## Required reading by task

| Task | Read |
| --- | --- |
| Choose or compose components | [patterns.md](patterns.md) |
| Debug styling, portals, scrolling, or NUI behavior | [pitfalls.md](pitfalls.md) |
| Find a working implementation | [examples.md](examples.md) |
| Verify researched API facts and upstream links | [research.md](research.md) |

## Decision order

1. Reuse an existing `sky_phone` pattern when it matches the interaction.
2. Prefer a native Konsta component over recreating the same control with custom markup.
3. Preserve Konsta's iOS interaction, active, motion, and glass behavior.
4. Add scoped CSS only for product-specific layout, sizing, or visual identity.
5. Keep all user-facing text in `sky_phone/config/locales/` and resolve it through the phone store.
6. Treat data from NUI as untrusted; consequential actions remain server-authoritative.

## Updating this reference

After changing the Konsta version:

1. update the version statements above;
2. compare `konsta/vue/konsta-vue.d.ts` and affected component implementations;
3. update changed props or patterns in this directory;
4. run `build_frontend.bat` and inspect the generated NUI output.

Do not mirror the complete upstream website here. Keep this reference small, versioned, and focused
on decisions that recur in this codebase.
