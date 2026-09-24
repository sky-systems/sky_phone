# Interface contracts

Preserve the resource's existing UI path. Functions below describe client-side ox_lib modules;
do not infer the same server signature merely because lib is imported on both sides.

| Need | Client API / result |
| --- | --- |
| Notification | lib.notify(data); display request, not operation success |
| Confirmation | lib.alertDialog(data, optionalTimeout); confirm/cancel/nil, with rejection possible on a reasoned close/timeout in the inspected source |
| Form | lib.inputDialog(heading, rows, options); indexed values or nil on cancellation |
| Progress | lib.progressBar or lib.progressCircle |
| Skill check | lib.skillCheck(difficulty, optionalInputs); client result, not server authorization |
| Context menu | lib.registerContext then lib.showContext |
| List menu | lib.registerMenu then lib.showMenu |
| Text UI | lib.showTextUI / lib.hideTextUI |

Do not invent lib.progress or call lib.context/lib.menu as the public constructors.
Check the installed version for additional fields, icons and close/cancel behavior.
Awaiting dialogs require a scheduler context. Reopening, cancelling and stopping the owner
must not leave stale pending work or focus state.

Dialog validation and successful progress animation do not authorize server rewards. Revalidate
submitted values on the server; labels and choices must follow the resource's localization.

[Alert docs](https://overextended.dev/docs/ox_lib/Interface/Client/alert),
[input docs](https://overextended.dev/docs/ox_lib/Interface/Client/input),
[notification docs](https://overextended.dev/docs/ox_lib/Interface/Client/notify)
and [module source](sources.md).

## Notification example and options

These are client Lua examples using existing `locale(...)` keys. Substitute the owning
resource's established localization interface when different.

```lua
lib.notify({
    id = "example:settings-saved",
    title = locale("settings.title"),
    description = locale("settings.saved"),
    type = "success",
    duration = 3000,
    position = "top-right",
    icon = "check"
})
```

The pinned type contract uses `info`, `error`, `success`, `warning`; the legacy
`defaultNotify` compatibility path maps `inform` to `info`. `id` controls repeated display;
it is not a persisted operation ID. Other fields include `iconColor`, `style` and `sound`;
verify their exact installed schema. Icons accept a name or a supported icon tuple such
as `{ "fab", "apple" }`. Do not announce success before the authoritative operation finishes.
Notification `description` and alert-dialog `content` support Markdown; do not assume that
every title, option label or other UI field uses the same renderer.

## Confirmation and cancellation

```lua
local choice = lib.alertDialog({
    header = locale("settings.reset_title"),
    content = locale("settings.reset_question"),
    centered = true,
    cancel = true,
    labels = { cancel = locale("common.cancel"), confirm = locale("common.confirm") }
})
if choice == "confirm" then
    print("User confirmed the settings dialog")
end
```

`cancel` and `nil` are not confirmation. `lib.closeAlertDialog()` closes normally; a
reason argument or an elapsed optional timeout can reject the await at this revision.
Route that rejection through the resource's existing cancellation/error handling.

## Form rows and indexed results

```lua
local values = lib.inputDialog(locale("profile.title"), {
    { type = "input", label = locale("profile.name"), required = true, min = 1, max = 40 },
    { type = "number", label = locale("profile.quantity"), min = 1, max = 25, default = 1 },
    { type = "checkbox", label = locale("profile.remember"), checked = false }
}, { allowCancel = true, size = "md" })
if not values then return end

local display_name, quantity, remember = values[1], values[2], values[3]
print(("Form submitted: nameLength=%d quantity=%s remember=%s"):format(
    #display_name, quantity, remember
))
```

Supported row kinds include `input`, `number`, `checkbox`, `select`, `multi-select`,
`slider`, `color`, `date`, `date-range`, `time`, `textarea`. A select's `options` is an
array of `{ value = ..., label = ... }`; optional `searchable`/`clearable` affect input.
Other per-kind fields include `placeholder`, `password`, `required`, `default`, `disabled`,
`min`, `max`, `step`, `format`, `returnString` and text length limits. Check the specific row
component; not every option applies to every kind. `lib.closeInputDialog()` resolves
cancellation with `nil`. False checkbox values and zero numbers are meaningful values.

Client form bounds improve usability; the server must validate submitted values again.

## Progress, context/list menus and TextUI

Use these only where the resource already owns a direct ox_lib UI. A completed progress
animation is a client report, not an entitlement to an item or payment.

```lua
local completed = lib.progressBar({
    duration = 1500,
    label = locale("preview.preparing"),
    canCancel = true,
    disable = { move = true, car = true, combat = true }
})
if completed then
    print("Preview animation completed")
else
    print("Preview animation cancelled or interrupted")
end
```

`lib.progressCircle` uses the same core flow with `position = "middle"` or `"bottom"`.
Animation options accept `anim.dict`/`clip` or a scenario; props require valid models and
attachment transforms. Check the installed module and actual assets before adding them.
`lib.progressActive()` reports the current state; `lib.cancelProgress()` requests cancellation
under the provider's rules. Do not register a new poll loop merely to mirror that state.

```lua
lib.registerContext({
    id = "example:settings",
    title = locale("settings.title"),
    options = {
        {
            title = locale("settings.preview"),
            description = locale("settings.preview_description"),
            icon = "eye",
            onSelect = function()
                print("Settings preview selected")
            end
        }
    }
})
lib.showContext("example:settings")
```

Context items can use a registered submenu `menu`, `disabled`, `readOnly`, `metadata` and
`args`; keep event/serverEvent dispatch behind server validation. Array options preserve
their chosen order. Register static menus once; refresh data deliberately for dynamic menus.
`lib.hideContext(true)` requests closing with `onExit`; inspect `getOpenContextMenu()` when needed.

```lua
lib.registerMenu({
    id = "example:appearance",
    title = locale("settings.appearance"),
    position = "top-right",
    options = {
        {
            label = locale("settings.theme"),
            values = { locale("settings.light"), locale("settings.dark") },
            args = { setting = "theme" }
        }
    }
}, function(selected, scroll_index, args)
    print(("Menu selection: row=%s value=%s setting=%s"):format(selected, scroll_index, args.setting))
end)
lib.showMenu("example:appearance")
```

List-menu options also support `checked`, `defaultIndex`, `close` and `description`; use
`onCheck`/`onSideScroll` when their specific change event matters. `setMenuOptions` updates
a registered menu; `hideMenu` and `getOpenMenu` address its lifecycle.

```lua
-- Show once on entering the interaction state, not on every frame.
lib.showTextUI(locale("interaction.open_hint"), { position = "right-center", icon = "hand" })

-- At the matching exit/owner cleanup:
lib.hideTextUI()
```

Coordinate ownership so one feature does not hide another feature's prompt.
`lib.isTextUIOpen()` returns the open state and current text. Source and full option
contracts: [progress](https://overextended.dev/docs/ox_lib/Interface/Client/progress),
[context](https://overextended.dev/docs/ox_lib/Interface/Client/context),
[menu](https://overextended.dev/docs/ox_lib/Interface/Client/menu),
[TextUI](https://overextended.dev/docs/ox_lib/Interface/Client/textui), [source map](sources.md).

## Skill-check example

```lua
local passed = lib.skillCheck({ "easy", { areaSize = 45, speedMultiplier = 1.2 } }, { "e", "q" })
if passed then
    print("Client skill check reported success")
else
    print("Client skill check failed, was cancelled or could not start")
end
```

The client accepts `easy`/`medium`/`hard`, a custom difficulty, or a sequence. `inputs`
selects the candidate keys. A second check while one is active can return `nil` at the
inspected revision. Check `lib.skillCheckActive()` before a deliberate owner cancellation;
`lib.cancelSkillCheck()` raises if none is active. A positive client result is untrusted:
the server still owns eligibility, operation state and any reward.
[Official skill-check contract](https://overextended.dev/docs/ox_lib/Interface/Client/skillcheck)
and [implementation](sources.md).
