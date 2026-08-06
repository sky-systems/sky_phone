# AGENTS - sky_phone

Standalone FiveM phone resource with a Vue 3 and Konsta UI frontend. It must not depend on or
interact with `sky_base`, `sky_jobs_base`, or any other Sky resource.

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

## Build and validation

Run commands from `frontend/`:

- `pnpm dev` starts Vite and the mock NUI server.
- `pnpm typecheck` validates TypeScript and Vue files.
- `pnpm lint` runs ESLint without rewriting files.
- `pnpm build` validates and publishes the NUI into `sky_phone/source/html/`.

After frontend changes, run the workspace-root `build_frontend.bat`; it builds the NUI and copies
`sky_phone` to the configured local servers. After Lua/config-only changes, run the workspace-root
`build_copy.bat`.

## Commits

Use the monorepo commit format: `TAG - short imperative summary`.
