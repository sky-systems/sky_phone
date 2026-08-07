# Konsta UI and FiveM NUI pitfalls

## Version drift

Konsta examples found online may target another major or framework adapter. This project uses Vue
and locks `konsta@5.2.0`; never copy React syntax or assume props from a different version.

## Import names

This project consistently uses the `k`-prefixed Vue exports, for example `kPage`, `kNavbar`, and
`kListItem`, imported from `konsta/vue`. Do not mix these with React imports or invent global
component names.

## Theme and app context

- Do not import the Konsta theme separately in individual components.
- Do not add another root `kApp` inside normal phone app views.
- A control that renders incorrectly may be missing the expected `kApp`/`kPage` context rather than
  needing a large CSS override.

## Scoped CSS

Vue scoped selectors may not reach Konsta's internal descendants. Prefer documented props, slots,
and class props first. If an internal selector is unavoidable, keep `:deep(...)` narrow and explain
which installed Konsta structure it relies on.

Do not replace full component class lists. Add product-specific classes through supported class
props so Konsta retains state, platform, and theme classes.

## Portals and the phone boundary

Dialogs, sheets, popovers, toasts, and notifications may render outside the component's immediate
DOM subtree. Ensure overlays remain inside the `.phone-screen` visual and stacking context when the
installed API offers a portal target. Verify clipping, z-index, focus, and pointer events.

## Scrolling and fixed chrome

Avoid competing scroll containers. Decide whether `kPage` or an inner region owns scrolling, then
keep navbars, tabbars, message bars, and toolbars outside that scroll region as intended. Test long
localized strings and empty/loading/error states.

## CEF behavior

FiveM NUI runs in CEF, not a normal browser tab. Browser preview is useful but does not prove:

- focus and keyboard behavior after `SetNUIFocus`;
- transparency and compositing over the game;
- backdrop filtering and nested glass performance;
- portal stacking within the scaled phone frame;
- touch-like dragging and pointer capture.

Do not add arbitrary waits or retries to compensate for a rendering problem. Trace the actual
mounting, state, focus, and message flow.

## Localization and security

- Konsta labels, placeholders, dialog text, and accessibility copy are still user-facing copy and
  must come through the phone locale system.
- A polished Konsta control does not make its payload trusted. Validate consequential requests on
  the server, and ensure every Lua NUI callback invokes its response callback on every path.
