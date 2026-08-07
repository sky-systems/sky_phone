# Konsta UI patterns

## Application shell

- Keep one root `kApp`; the current shell lives in `frontend/src/App.vue`.
- Keep the global Konsta theme import in `frontend/src/assets/main.css`.
- Use `kPage` as the root of a phone app view so page sizing, scrolling, and iOS component context
  stay consistent.

## Navigation

- Use `kNavbar` for an app title bar.
- Use `kNavbarBackLink` for hierarchical back navigation instead of a custom chevron button.
- Use `kLink` for lightweight navbar actions.
- Use `kTabbar` with `kTabbarLink` for persistent top-level app sections.
- Use Vue Router for navigation between phone apps; use local view state only for screens that are
  internal to one app and should not become routes.

## Content and forms

- Use `kList` with `kListItem` for iOS settings rows and grouped data.
- Use `kListInput` for text, numeric, and select-like form fields when its API fits.
- Use `kListButton` for actions presented as list rows.
- Use `kBlock`, `kBlockTitle`, and `kCard` for grouped explanatory or summary content.
- Use `kSearchbar` for filtering list content.
- Use `kToggle`, `kRange`, and `kSegmented`/`kSegmentedButton` for their native control semantics.

## Actions and transient UI

- Use `kButton` for normal actions and `kFab` only for a primary floating action.
- Use `kDialog` with `kDialogButton` for decisions that require confirmation.
- Use `kSheet` for a compact task or form that slides over the current context.
- Use `kPopover` for anchored choices; provide the actual target element and a portal target inside
  the phone screen when required by the component API.
- Use `kToast` for short non-blocking feedback and `kNotification` for notification presentation.
- Use `kPreloader` while an operation is genuinely pending; do not use it to hide missing state.

## Messages and media

- Compose conversations from `kMessages`, `kMessagesTitle`, `kMessage`, and `kMessagebar` before
  building custom message primitives.
- Keep complex product-specific content, such as voice messages and attachments, in focused Vue
  components placed inside the Konsta message structure.

## Liquid glass

- Use `kGlass` when the element should participate in Konsta's native liquid-glass treatment.
- `backdrop-filter` and `-webkit-backdrop-filter` are explicitly allowed in this repository.
- Avoid stacking several glass layers without checking contrast, pointer behavior, and animation in
  the FiveM CEF runtime.

## Component verification checklist

Before using an unfamiliar component:

1. inspect its export and props in `frontend/node_modules/konsta/vue/konsta-vue.d.ts`;
2. inspect the installed Vue implementation if slot, event, portal, or class behavior is unclear;
3. compare a current project example from [examples.md](examples.md);
4. verify the rendered result in the browser test server and, for CEF-specific behavior, in FiveM.
