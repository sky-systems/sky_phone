---
name: fivem-nui
description: Create or change FiveM NUI HTML/CSS/JS and its resource manifests, messages, callbacks and focus. Use for game/browser integration; use fivem-cef-rules for embedded-browser compatibility and lifecycle diagnosis.
---

# FiveM NUI Integration

Trace the resource manifest, client transport, frontend listener/callback, and server authority before editing. Reuse the resource's existing transport and UI components. Keep a browser request being accepted separate from a server mutation succeeding.

Read only the relevant reference:

| Task | Reference |
| --- | --- |
| Add/package a UI or fix asset paths | [setup.md](setup.md) |
| Send state, show/close UI, manage focus | [fullscreen-nui.md](fullscreen-nui.md) |
| Browser-to-game callbacks and responses | [nui-callbacks.md](nui-callbacks.md) |
| Security, performance, error handling | [best-practices.md](best-practices.md) |
| Verify platform/API facts | [reference-links.md](reference-links.md) |

Before changing a Cfx API contract, verify official docs and the matching `citizenfx/fivem` implementation, registration, binding and call path. Record the inspected SHA and paths; prefer the deployed revision when identifiable. A docs example or a desktop browser alone is insufficient evidence.

Use the injected `GetParentResourceName()` with HTTPS callback URLs. Complete each callback exactly once on every reachable path. Never infer resource identity from the page hostname, blindly retry mutating requests, or treat client-side validation as authority. Gameplay permissions and mutations remain server-owned.

Register listeners before a ready/rehydration exchange; release focus and dispose owned effects on close/stop. Use `fivem-cef-rules` when compatibility, reloads, input, rendering or media matter, reading only its applicable references. An in-game runtime probe is required for compatibility claims.

Follow the repository build/copy rules and verify final manifest paths, generated asset URLs and affected callback routes. Test the changed behavior and report static/build/copy evidence separately from actual FiveM validation. Broaden to a full runtime matrix for a release or platform audit.
