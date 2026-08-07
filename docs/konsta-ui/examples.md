# Existing project examples

Use these as navigation aids, not as substitutes for reading the component and its current types.

| Pattern | Project example |
| --- | --- |
| Root Konsta application context | `frontend/src/App.vue` |
| Global Konsta Vue theme import | `frontend/src/assets/main.css` |
| Glass springboard surface | `frontend/src/views/SpringboardView.vue` |
| Navbar, lists, inputs, toggles, dialogs, popover | `frontend/src/views/apps/SettingsApp.vue` |
| Messages, message bar, toolbar pane | `frontend/src/views/apps/MessagesApp.vue` |
| Sheet, tabbar, glass, cards, form controls | `frontend/src/views/apps/BankingApp.vue` |
| Dialog, preloader, toast | `frontend/src/views/apps/MailApp.vue` |
| Cards, navbar, preloader | `frontend/src/views/apps/WeatherApp.vue` |
| Floating action button | `frontend/src/views/apps/MapApp.vue` |
| Notification component | `frontend/src/components/PhoneNotifications.vue` |
| Badge component | `frontend/src/components/AppIcon.vue` |

## Components currently represented

The frontend currently imports components including:

`kApp`, `kBadge`, `kBlock`, `kBlockTitle`, `kButton`, `kCard`, `kDialog`, `kDialogButton`, `kFab`,
`kGlass`, `kIcon`, `kLink`, `kList`, `kListButton`, `kListInput`, `kListItem`, `kMessage`,
`kMessagebar`, `kMessages`, `kMessagesTitle`, `kNavbar`, `kNavbarBackLink`, `kNotification`, `kPage`,
`kPopover`, `kPreloader`, `kRange`, `kSearchbar`, `kSegmented`, `kSegmentedButton`, `kSheet`, `kTabbar`,
`kTabbarLink`, `kToast`, `kToggle`, and `kToolbarPane`.

Regenerate this inventory from imports when adding or removing a substantial group of components;
do not treat the list as the package's complete API.
