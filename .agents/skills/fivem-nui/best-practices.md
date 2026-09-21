# NUI Integration Checks

Read this for a transport, security or performance change. Use the relevant checks rather than adding generic wrappers or rebuilding the UI architecture.

## Authority and error outcomes

Treat messages and callback payloads as untrusted client input. Server mutations must recheck the caller, permissions, proximity, ownership, values and allowed transition relevant to the action. Client validation and disabled buttons are user experience, not enforcement. Keep secrets out of bundles/browser storage and avoid interpreting untrusted values as HTML.

Complete callbacks on every path and distinguish accepted, pending, succeeded and failed outcomes. A transport failure can happen after a mutation succeeded. Do not automatically retry arbitrary requests, particularly purchases/payments. Reuse an established idempotency mechanism only when the server contract provides one. Report the actual failure visibly; broad catches and fallback success values obscure it.

## Messages and lifetime

Send changes at the rate the feature needs; avoid unchanged full-state messages every frame. Batch coherent updates and measure serialization/rendering cost before introducing timers or throttles. No fixed interval is universally correct.

Register listeners before readiness, hydrate after load and reject responses belonging to an older session/selection. Dispose owned listeners, timers, observers, workers, requests and media. Bound message histories and retained registries. Use framework lifecycle hooks already present in the frontend.

Worked code: [complete state/focus lifecycle](examples.md#complete-local-panel-package-open-hydrate-and-close), [batched state and safe DOM updates](examples.md#coherent-updates-and-safe-dom-rendering), [typed response handling](examples.md#callback-response-shapes-and-errors), and [explicit browser fixture](examples.md#explicit-desktop-preview). Keep one state owner; UI controllers manage visibility/presentation, server services own gameplay mutations. Do not add a Lua `require` pattern or a parallel callback layer without verifying the resource's existing loader and transport.

## Rendering and accessibility

Use the shared project controls and theme tokens. Prefer animation/rendering choices supported by the measured client floor; target output syntax and CSS deliberately. Transpilation does not provide DOM APIs, codec support or browser integration features.

Keep keyboard navigation, visible focus, Escape/close behavior and appropriate labels in the changed control. Restore focus predictably. Localize user-facing messages. Use viewport/layout checks matching the change and expand for phone/ultrawide work when relevant.

Use native buttons for Enter/Space activation. Menu/listbox ArrowUp/ArrowDown selection belongs to the shared widget's focus model; do not intercept those keys globally while a text field is editing. The worked panel demonstrates Escape, initial control focus and Tab containment for its one-control modal; real multi-control dialogs use the project's existing focus trap and restore the previous DOM control when closed.

## Verification boundaries

Browser mocks verify presentation and request shape. Build checks verify emitted files. Source-to-copy parity verifies the deployed copy. Actual FiveM testing verifies runtime behavior. State which evidence exists rather than equating the stages.

Use CEF compatibility, lifetime, media or GPU references from `fivem-cef-rules` when they affect the task. Run a full release matrix only for a release/platform audit; otherwise choose impacted cases and repository-required checks. Performance claims require representative profiling, not assumptions based on code style.

Sources: [NUI callbacks](https://docs.fivem.net/docs/scripting-manual/nui-development/nui-callbacks/), [secure server events](https://docs.fivem.net/docs/developers/server-security/), [source map](reference-links.md).
