# Custom-app input focus

Report editable-field focus through your app resource's own NUI callback. On the client, use:

```lua
-- Stop gameplay input while typing; the phone keeps keyboard and cursor focus.
local success, error_code = exports["sky_phone"]:SetPhoneGameInputEnabled(false)

-- Release this resource's override and restore Config.Phone.AllowMovement.
local released, release_error = exports["sky_phone"]:SetPhoneGameInputEnabled(nil)
```

`false` blocks game input, `true` explicitly allows it, and `nil` releases the calling resource's override. A release cannot clear another resource's override. The export returns `true`, or `false` plus `invalid_focus_claim`, `resource_required`, or `phone_closed`. A release after the phone has closed succeeds without acquiring focus.

Keep the claim while tabbing between editable fields. Release it on blur, app close, navigation, page hide, and unmount. Phone close and owner resource stop also clear the claim. Use `nil` on release instead of `true` so servers with movement disabled retain that setting. Calling `SetNuiFocusKeepInput(false)` from your app resource cannot clear the phone resource's vote.

## Source verification

Inspected official Cfx source revision `0d8a2a6f78a9922445d8930305af82a7b1826980`:

- [Fullscreen NUI documentation](https://docs.fivem.net/docs/scripting-manual/nui-development/full-screen-nui/) describes resource-owned keyboard and cursor focus.
- [`SetNuiFocus.md`](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/ext/native-decls/SetNuiFocus.md) and [`SetNuiFocusKeepInput.md`](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/ext/native-decls/SetNuiFocusKeepInput.md) declare client-only boolean arguments and void returns, without pointer outputs.
- [`ResourceUIScripting.cpp`](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/nui-resources/src/ResourceUIScripting.cpp), `SET_NUI_FOCUS`, `SET_NUI_FOCUS_KEEP_INPUT`, and `updateFocus`, register the handlers and maintain resource-keyed focus and keep-input votes.
- [`CefInput.cpp`](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/nui-core/src/CefInput.cpp), `KeepInput` and the `OnWndProc` input path, set the input flag and suppress forwarding when keep-input is disabled.

These focus transitions use the client scripting runtime; they do not perform server RPC or OneSync work. This source revision was not matched to the reporting player's client artifact. Automated focus tests and copied files do not verify live FiveM input behavior.
