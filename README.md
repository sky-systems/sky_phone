# sky_phone

Standalone FiveM phone boilerplate built with Vue 3, TypeScript, Pinia, Vue Router, Konsta UI 5, and Tailwind CSS 4. The resource currently exposes only the localized `/phone` toggle and the private NUI `ui:ready`/`close` callbacks.

The homescreen is an original implementation inspired by the interaction and layout concepts in [lukejacksonn/homescreen](https://github.com/lukejacksonn/homescreen), inspected at commit [`98a812f`](https://github.com/lukejacksonn/homescreen/tree/98a812f4f7c33594e791d65092f73b8f54b3c598). No source code or image assets from that project are included.

## Development

From `frontend/`, run `pnpm dev` for browser development. The phone opens automatically and NUI callbacks are mocked. Run `pnpm test`, `pnpm typecheck`, `pnpm lint`, and `pnpm build` before packaging.

`pnpm build` uses `build.cjs` to replace `sky_phone/source/html` deterministically with the Vite output. Production assets use relative paths so they work through the FiveM NUI protocol.
