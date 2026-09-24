# Packaging a NUI

Read this for a new UI, a blank page, missing assets or a build-path change. Follow the resource's existing frontend/build layout rather than introducing another toolchain.

## Resource contract

```lua
fx_version "cerulean"
game "gta5"

ui_page "html/index.html"

files {
    "html/index.html",
    "html/assets/**/*"
}
```

This is an illustrative manifest fragment: retain the resource's actual scripts/dependencies and include every emitted file it needs, including fonts, workers, WASM and media. Check exact filename case and the generated HTML, not only source templates. An external HTTPS `ui_page` is also supported, but hosting and availability then become part of the delivery path.

For a complete manifest/HTML/CSS/client/browser example, read [the local panel](examples.md#complete-local-panel-package-open-hydrate-and-close). It includes relative assets, initial hidden state, ready hydration, open/close, Escape, focus and resource-stop cleanup.

## Build and hosting options

Keep the installed framework and lockfile. The relevant Vite options are concrete configuration, not a reason to reinstall React/Vue or pin an obsolete Vite major:

```js
import { defineConfig } from "vite";

export default defineConfig({
    base: "./",
    build: {
        outDir: "dist",
        emptyOutDir: true,
        assetsInlineLimit: 0,
        // Add target/cssTarget from the project's verified supported CEF floor.
    },
});
```

`outDir` must match the real packaging path. `emptyOutDir` clears that build directory; never point it at source or unrelated files. `assetsInlineLimit: 0` is an optional choice to keep imported assets external, not a FiveM requirement. Preserve required framework plugins. Include emitted nested chunks, not only `index.html`:

```lua
ui_page "ui/dist/index.html"
files { "ui/dist/index.html", "ui/dist/**/*" }
```

An explicitly hosted page uses `ui_page "https://ui.example.com/releases/1/index.html"`; packaged local dependencies still need `files`. Hosting can reduce the resource download and support web deployments, but adds availability, latency, certificate, caching/version-consistency and external-network dependencies. Deploying a web page does not force an already loaded NUI to refresh. Test its parent-resource callback origin and strict-mode behavior. See the CEF runtime/build reference for JS/CSS targets, capability probes and fallbacks.

Use relative packaged URLs; in Vite an embedded build commonly uses `base: "./"`. Set JS/CSS output targets from the supported client floor. A successful desktop build does not establish CEF support. Inspect the actual resource manifest and final bundle before assuming a conventional `html/` directory.

`https://cfx-nui-<resource>/path` is the resource asset origin. Callback POSTs use `https://${GetParentResourceName()}/callback`; these serve different purposes. Do not add `nui://` asset URLs or derive resource identity from `window.location.hostname`. The platform injects `GetParentResourceName()` even when page hosting differs from the resource name.

## Startup and browser preview

Keep the initial fullscreen page transparent and noninteractive until opened. Register browser listeners before sending a `ready` callback; the client then provides the effective state snapshot. Existing handshakes should be reused. Arbitrary delays do not establish readiness.

Use a separate explicit preview/mock entrypoint for desktop development. Production code must use the injected platform identity and real callback routes. Mock success is presentation evidence, not proof of a server mutation or FiveM behavior.

For compatibility and lifecycle details, use the relevant `fivem-cef-rules` reference when available. Packaging checks remain necessary even when a browser preview works.

## Verify the delivered artifact

- Trace source → generated HTML/assets → manifest → deployed resource copy.
- Confirm referenced files exist with matching case and URLs; inspect Console/Network for the failing request.
- Follow repository-prescribed frontend build and deployment-copy commands.
- Test the changed route in the target FiveM client when available; label missing runtime validation.

Primary sources: [resource manifest](https://docs.fivem.net/docs/scripting-reference/resource-manifest/), [fullscreen NUI](https://docs.fivem.net/docs/scripting-manual/nui-development/full-screen-nui/), and [the pinned source map](reference-links.md).
