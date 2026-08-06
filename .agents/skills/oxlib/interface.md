# interface — Notifications, alert dialog, input dialog

The UI is shown on the **client** (player screen). You can invoke these functions from **client** or from **server**: from server, trigger the client (e.g. `TriggerClientEvent`) so the client runs `lib.notify` / `lib.alertDialog` / etc., or use ox_lib’s server-side exports when available (e.g. to send a notification to a specific player). Icons use Font Awesome 6; default type is `solid`. For brand icons use a table: `icon = {'fab', 'apple'}`.

## lib.notify — Notifications

```lua
lib.notify({
  title = 'Title',
  description = 'Description (markdown supported)',
  type = 'success',  -- 'inform' | 'error' | 'success' | 'warning'
  duration = 3000,
  position = 'top-right',
  icon = 'check',
})
```

Optional: `id` (string) for a unique notification so it only shows once when spammed; `iconColor`, `style`, `sound`, etc. See [Notifications](https://coxdocs.dev/ox_lib/Modules/Interface/Client/notify).

## lib.alertDialog — Simple alert / confirm

Returns `'confirm'` or `'cancel'` (or `nil` if closed). Call from client, or from server by triggering the client.

```lua
local result = lib.alertDialog({
  header = 'Title',
  content = 'Body with **markdown** support.',
  centered = true,
  cancel = true,
  labels = { cancel = 'Cancel', confirm = 'OK' },
})
if result == 'confirm' then
  -- player pressed OK
end
```

## lib.inputDialog — Form inputs

Takes a heading, rows (array of field definitions), and optional options. Returns a table (array) of values by index, or `nil` if cancelled. Call from client, or from server by triggering the client.

```lua
local input = lib.inputDialog('Dialog title', {
  { type = 'input', label = 'Name', placeholder = 'Your name', required = true },
  { type = 'number', label = 'Amount', min = 1, max = 100, default = 1 },
  { type = 'checkbox', label = 'Accept' },
})
if not input then return end
local name, amount, accepted = input[1], input[2], input[3]
```

Row types: `input`, `number`, `checkbox`, `select`, `multi-select`, `slider`, `color`, `date`, `time`, `textarea`. See [Input Dialog](https://coxdocs.dev/ox_lib/Modules/Interface/Client/input).

## Other UI

- **lib.progress** — progress bar with duration/cancel.
- **lib.showTextUI** / **lib.hideTextUI** — TextUI.
- **lib.context** — context menu.
- **lib.menu** — list menu.

Full list: [Interface – coxdocs.dev](https://coxdocs.dev/ox_lib/Modules/Interface).
