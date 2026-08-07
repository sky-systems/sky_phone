# Konsta UI 5.2.0 / Vue – project research

Stand: 2026-08-07. This note is a version-bound reference for `sky_phone`. Re-check it when the `konsta` dependency changes; URLs point to first-party documentation and sources rather than reproducing the whole upstream documentation.

## Installed version and entry points

- `frontend/package.json` declares `konsta: ~5.2.0`; `frontend/pnpm-lock.yaml` resolves that range to exactly `konsta@5.2.0`. The installed `frontend/node_modules/konsta/package.json` also reports `5.2.0` (release date June 29, 2026). Konsta's official Vue documentation currently identifies itself as v5.2.0: [Konsta UI Vue](https://konstaui.com/vue).
- Vue components and the `useTheme` helper are exported from `konsta/vue`. Both prefixed and unprefixed component names exist upstream (`kPage` and `Page`, etc.); this project consistently uses the `k*` exports. See the package's official [Vue entry point source](https://github.com/konstaui/konsta/blob/master/src/vue/konsta-vue.js) and [Vue documentation](https://konstaui.com/vue).
- The Konsta theme is imported globally with `@import 'konsta/vue/theme.css';`. The project does this immediately after `@import 'tailwindcss';` in `frontend/src/assets/main.css`, matching the official [Vue installation guide](https://konstaui.com/vue/installation).
- The installed package exports `./vue`, `./vue/theme.css`, `./theme.css`, and framework-specific React/Svelte entry points. For `sky_phone`, use only the Vue paths above; do not deep-import component files from `node_modules`.

```ts
import { kApp, kNavbar, kPage, useTheme } from 'konsta/vue'
```

## Project-wide iOS conventions

- Wrap the phone UI in `kApp theme="ios"`. `kApp` supplies the theme context and global behavior; relevant props in 5.2.0 are `theme`, `dark`, `materialTouchRipple`, `iosHoverHighlight`, and `safeAreas`. The project already uses `theme="ios"`, `:dark="isDark"`, and `safe-areas` in `frontend/src/App.vue` and its notification preview. Source: [App API](https://konstaui.com/vue/app).
- `safe-areas` is intended for a full-screen app container. Browser safe-area insets additionally require `viewport-fit=cover`; Konsta supplies utilities such as `pt-safe`, `pb-safe`, and `no-safe-areas-*`. The current `frontend/index.html` viewport does **not** include `viewport-fit=cover`, so do not assume browser notch insets are active merely because `kApp safe-areas` is set. Source: [Safe Areas](https://konstaui.com/vue/safe-areas).
- Use `kPage` as the main content container for an app view: [Page API](https://konstaui.com/vue/page).
- Prefer Konsta's iOS-native components and their built-in active, motion, and glass behavior. Konsta v5 is the release family that introduced the iOS 26 Liquid Glass design: [Release notes](https://konstaui.com/release-notes).
- `kGlass` produces Liquid Glass only in the iOS theme and otherwise renders a plain element. Its v5.2.0 props are `component` and `highlight` (default `true`), plus color-class overrides. Navbar, Toolbar, Tabbar, and Popover use the same glass foundation: [Glass API](https://konstaui.com/vue/glass).
- For brand colors in v5, define Tailwind theme variables with the required `--color-brand-*` prefix and select them with `k-color-[name]`: [Colors](https://konstaui.com/vue/colors).

## Relevant component patterns

- **Navbar:** `kNavbar` centers the title by default on iOS. Use its `left`, `right`, `title`, `subtitle`, and `subnavbar` slots. Put `kNavbarBackLink` in `#left` for back navigation rather than rebuilding the affordance: [Navbar API](https://konstaui.com/vue/navbar).
- **Lists and forms:** `kList` is content-inset and has dividers by default on iOS; control this with `dividers`, `dividersIos`, and `dividersMaterial`. Compose it with `kListItem`, `kListInput`, `kListButton`, `kToggle`, and `kRange`: [List API](https://konstaui.com/vue/list).
- **Dialogs:** Control `kDialog` with `:opened`; normally close it on `@backdropclick`. Use the `title`, `content`, and `buttons` slots and `kDialogButton`: [Dialog API](https://konstaui.com/vue/dialog).
- **Sheets:** Control `kSheet` with `:opened` and handle `@backdropclick`. The official pattern combines it with `kToolbar`/`kToolbarPane` and `kLink`: [Sheet API](https://konstaui.com/vue/sheet).
- **Tabs:** `kTabbar` extends Toolbar and supports icon/label layouts; place the active state on `kTabbarLink` through `:active`. Use `kToolbarPane` for content that should participate in the iOS glass treatment: [Tabbar API](https://konstaui.com/vue/tabbar), [Toolbar Pane API](https://konstaui.com/vue/toolbar-pane).
- **Router links:** To retain Konsta styling while using Vue Router, set `component="router-link"` and pass router props through `:link-props="{ to: '/path' }"`: [Link API](https://konstaui.com/vue/link).
- **Searchbar and inputs:** Listen to the component's documented Vue/native-style events. `kSearchbar`, for example, exposes `input`, `change`, `clear`, `disable`, `focus`, and `blur`; do not invent callback prop names: [Searchbar API](https://konstaui.com/vue/searchbar).

## Components actually imported by `sky_phone`

The following inventory was derived from all `from 'konsta/vue'` imports under `frontend/src` on the date above:

| Area | Components |
| --- | --- |
| Root and surfaces | `kApp`, `kPage`, `kGlass`, `kBlock`, `kBlockTitle`, `kCard` |
| Navigation and actions | `kNavbar`, `kNavbarBackLink`, `kLink`, `kButton`, `kFab`, `kToolbarPane` |
| Lists and input | `kList`, `kListItem`, `kListInput`, `kListButton`, `kSearchbar`, `kToggle`, `kRange` |
| Selection and tabs | `kSegmented`, `kSegmentedButton`, `kTabbar`, `kTabbarLink` |
| Overlays and feedback | `kDialog`, `kDialogButton`, `kSheet`, `kPopover`, `kToast`, `kNotification`, `kPreloader` |
| Messaging | `kMessages`, `kMessage`, `kMessagesTitle`, `kMessagebar` |
| Decoration | `kBadge`, `kIcon` |

Notable current usage:

- `frontend/src/App.vue` is the main `kApp` owner; `NotificationPhonePreview.vue` uses a separate app wrapper for its isolated preview context.
- `BankingApp.vue` currently has the broadest glass/navigation composition (`kGlass`, `kNavbar`, `kSheet`, `kTabbar`, `kTabbarLink`, `kToolbarPane`).
- `MessagesApp.vue` uses Konsta's dedicated message stack rather than custom message primitives.
- `SettingsApp.vue`, `ClockApp.vue`, `NotesApp.vue`, and `PhoneApp.vue` are the strongest in-repository examples of list/form composition.

## Maintenance rule

When changing a Konsta-based view, first consult the component page at `https://konstaui.com/vue/<component-name>` and then confirm uncertain props/events against the installed `frontend/node_modules/konsta/vue/types/` declaration and `frontend/node_modules/konsta/vue/components/` implementation. After a Konsta upgrade, update the exact version, re-check imports and changed APIs, and rebuild the frontend.
