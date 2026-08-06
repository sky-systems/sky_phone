# AGENTS — sky_phone

Standalone FiveM phone resource built on `sky_base`, with a Vue 3 and Konsta UI frontend.

> The shared conventions in the monorepo-root `AGENTS.md` apply to this resource. Read them first.

## Project structure

- `sky_phone/` contains the deployable FiveM resource.
- `sky_phone/config/` contains customer configuration and locales.
- `sky_phone/source/client/` contains client-side phone and NUI behavior.
- `frontend/` contains the Vue 3, TypeScript, Vite, Tailwind CSS, and Konsta UI application.
- Production frontend assets are generated in `sky_phone/source/html/`; do not edit them manually.

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

## Build and validation

Run commands from `frontend/`:

- `pnpm dev` starts Vite and the mock NUI server.
- `pnpm typecheck` validates TypeScript and Vue files.
- `pnpm lint` runs ESLint without rewriting files.
- `pnpm build` validates and publishes the NUI into `sky_phone/source/html/`.

After frontend changes, run the monorepo-root `build_frontend.bat`. Local servers consume the
workspace resource through symlinks, so Lua/config-only changes require no deployment copy step.

## Commits

- Format: `TAG - short imperative summary`.
- Tags: `ENH`, `ADD`, `FIX`, `DOC`, `BLD`, `PERF`, `CLN`, `TRY`.
- Keep commits focused and call out required config, SQL, or locale migrations.
- Stage only files belonging to the task; never use broad staging that captures unrelated work.
