# Phone configuration and command access

For a first installation, also follow the [installation guide](../sky_phone/PHONE_INSTALLATION_IMPORTANT.md).
This guide covers the administrator's `/phonepanel`; the Settings app on a player's
phone changes that device's personal preferences, not the server-wide SIM or identity mode.

## Choose the configuration owner first

`config/config.lua` has two clearly separated parts. The configuration keys and
SQL format have not changed; existing saved configuration is retained.

| Part / file | Configurator enabled (default) | Configurator disabled |
| --- | --- | --- |
| Part 1: `PhoneConfigurator`, `CommandPermissions`, `CustomTones` | Always read from the file; restart after edits | Always read from the file; restart after edits |
| Part 2: phone, apps, framework, inventory, voice and other settings | Edit in `/phonepanel` → Phone configurator; save to SQL | Edit `config.lua`; restart |
| `config/media.lua`, including upload API keys | Edit the media section in Phone configurator | Edit the server-only file; restart |
| `config/locales/`, inventory item definitions and integrations | File-owned | File-owned |
| `config/functions.lua` | File-owned Lua hooks; restart after edits | File-owned Lua hooks; restart after edits |
| `config/WebHooks.lua` | Separate Webhooks editor and SQL overrides | Same separate Webhooks editor; unaffected by the Configurator switch |

With `Config.PhoneConfigurator.Enabled = true`, editing Part 2 does **not** change
the running configuration, including on the first start. The shipped generated
`source/shared/config_default.lua` supplies defaults; SQL supplies saved overrides.
Do not edit that generated file or clear the Configurator table to apply a setting.
The build regenerates defaults from the source files.

The server creates `sky_phone_configurator` automatically. No SQL migration is
needed for the General page or the permission change. Save commits the shared
draft through the existing revision and validation checks. A failed or conflicting
save leaves the draft available to review. Nothing autosaves. Use the checkmark
in the panel header to save, and confirm success before closing.

Framework/inventory/voice provider selection, identity mode changes and changed
keyboard defaults should be followed by a resource restart. A panel save does not
execute a restart and cannot overwrite a player's saved FiveM keyboard bindings.

Turning SQL mode off does not export saved settings into the Lua files. Review
file values before switching modes. Saved SQL values remain available when SQL
mode is enabled again. In file mode the Configurator displays settings read-only;
the other authorized Phonepanel tools remain available when `AdminPanel.Enabled` is on.

### CityWarn notification sound

CityWarn uses the bundled `sounds/citywarn_alert.mp3` emergency sound, independently
of the handset's ordinary notification tone. In `/phonepanel` → Phone configurator
→ CityWarn → General, edit **Warning notification sound** and save. The next
CityWarn notification uses the new sound; the setting survives resource restarts.

With `Config.PhoneConfigurator.Enabled = false`, set
`Config.CityWarn.NotificationSound` in `config/config.lua` and restart the resource.
Use a direct HTTPS audio URL or a path relative to `source/html`, for example
`sounds/custom-alert.mp3`. Local files must be shipped with the NUI: place them in
`frontend/public/sounds` before building, or in `source/html/sounds` in a packaged
resource. Keep custom files when updating or rebuilding the resource.

The existing notification volume, mute and critical-alert rules still apply.
Extreme alerts repeat until dismissed; other alerts stop when their banner closes.
Existing SQL configurations receive the new default automatically when the setting
is absent. No manual SQL migration is required.

### Credentials and backups

In SQL mode, use the Media, Server and RealtimeSecrets detail sections for their
credentials. Existing secret values are masked; leave them unchanged to preserve
them. Back up the database, including `sky_phone_configurator`, along with your
file-owned settings and custom assets. Do not clear that row during an update.

`config.lua` is downloaded by clients, even for code inside `IsDuplicityVersion()`.
It is not private storage. In file mode, media keys belong in server-only
`config/media.lua`, and Cloudflare credentials use the non-replicated convars in
the [Realtime guide](../REALTIME.md#configuration-and-secrets). Private password
peppers require SQL mode; file mode has no private pepper storage. Preserve all
four existing `Server` peppers when updating to avoid invalidating credentials.

## General page

Open `/phonepanel` → Phone configurator → **General** (German: **Allgemein**).
This is the first configuration page. Its four groups contain:

| Group | Settings |
| --- | --- |
| Devices & SIM cards | Per-item device identity, physical SIM mode, phone item, initial device name, number prefix and length |
| Framework & integrations | Framework, inventory, default language and voice provider |
| Phone use | Death/unconscious and cuff restrictions, movement, hold-to-look |
| Keyboard & commands | Phone shortcut, CrewLink quick ping, GTA look control, phone command and its enable switch |

The Phone, SIM, Bridge, CrewLink and other detail sections still contain the full
configuration. General and detail views edit the **same draft**. Moving between
them preserves earlier edits. Search includes the General labels and descriptions
as well as configuration paths.

### Device identity and SIM service are independent

| Setting | On | Off |
| --- | --- | --- |
| `Phone.Unique` | Each item has its own IMEI and data; giving the item to someone transfers that handset | All phone items for one framework character open that character's persistent device |
| `Sim.Enabled` | Calls/messages require an inserted physical SIM; the phone itself can open without one | Devices without a SIM get a persistent automatic number; physical SIM items are unnecessary |

Unique phones require per-slot metadata and a non-stackable phone item. Physical
SIMs require metadata-capable, non-stackable SIM items even when unique phones
are disabled. Native ESX inventory and `hex_4_inventory` cannot preserve that
metadata, so the resource forces both options off. This also applies when `auto`
detects one of those inventories. The two configured switches alone do not prove
that the active inventory supports them.

Before changing identity/SIM modes on an established server, back up the database
and test the change with a copy. Restart the resource and verify item use, the
retained IMEI/data, calls and messages. Disabling SIM mode is not a bulk replacement
of existing numbers. Prefix/length changes apply to newly generated numbers.

## Command permissions: ACE groups

Phone uses the same **group convention** as the Jobs resources, implemented
inside `sky_phone`. It never calls another Sky resource.

```cfg
# Before ensure sky_phone, in server.cfg:
add_ace resource.sky_phone command.add_ace allow
add_ace resource.sky_phone command.remove_ace allow
```

`add_ace` registers the configured Phone permissions; `remove_ace` removes its
automatically installed grants when the resource stops, so removed groups do not
retain access after a restart. Missing grants are reported in the server console
and Phone command access stays disabled. The phone does **not** need
`command.add_principal` or `command.remove_principal`: player membership is owned
by the server/framework. Permissions granted to `resource.sky_base` do not grant
anything to `resource.sky_phone`.

In Part 1 of `config/config.lua`:

```lua
Config.CommandPermissions = {
    phonepanel = { "god", "superadmin", "admin" },
    phonetestdata = { "god", "superadmin", "admin" },
    fliptokverify = { "god", "superadmin", "admin" },
    picstagramverify = { "god", "superadmin", "admin" },
    picstagramadmin = { "god", "superadmin", "admin" },
}
```

`admin` registers `group.admin` → `sky_phone.<permission>`. On QBCore it also
registers the same grant for `qbcore.admin`. ESX and Qbox use `group.*`. Values
are group suffixes, so enter `admin`, not `group.admin`.

The player's ACE principal must inherit an allowed group. If your server does
not already establish that membership, configure it through your normal admin
setup. For example, substitute a real identifier in this **server configuration**:

```cfg
add_principal identifier.license:YOUR_LICENSE group.admin
```

Do not put player identifiers in `CommandPermissions`. Phone neither changes nor
removes framework/player membership. Every protected action checks
`IsPlayerAceAllowed(player, "sky_phone.<permission>")` again. Revocation therefore
applies to the next action even if the panel is already open. Explicit ACE denies
are respected. A job named `admin`, Qbox `HasGroup`, or a framework-only role is no
longer an alternative way to authorize a Phone admin action.

Missing/empty permission lists deny player access. Existing commands that support
the server console retain that behavior; the panel itself needs a player/NUI.
`phonetestdata` applies when `TestData.AdminOnly` is enabled. Keep the permission
keys stable when changing command names in the panel. Do not use `command.phonepanel`
alone to grant access: server callbacks also require `sky_phone.phonepanel`.

### Updating from the previous permission model

1. Add both `resource.sky_phone` grants above before starting the resource.
2. Verify that administrators belong to the appropriate ACE group. The previous
   ESX/QBCore role checks and Qbox role/job fallback no longer apply.
3. Keep the existing `CommandPermissions` group lists, or adjust them in Part 1.
4. Restart `sky_phone`. Test one allowed and one unprivileged player.
5. In the server console, use `test_ace group.admin sky_phone.phonepanel` to check
   a group's policy, and `test_ace identifier.license:YOUR_LICENSE sky_phone.phonepanel`
   to check the identifier's inheritance. A group test alone does not verify player
   membership.

Grants that already allow access before startup are not rewritten. They can continue
to grant access independently of the configured lists. Phone manages each newly
installed principal/object allow pair until it stops: do not duplicate those exact
pairs manually. Cfx removes all matching allow entries during cleanup, including
duplicates hidden by a deny; deny entries themselves remain untouched. Keep separate
manual grants in server configuration. The permission lists remain file-owned and
are never exposed as editable Configurator fields.

## Keyboard capture and GTA controls

For `Phone.Keybind` and `CrewLink.QuickPing.DefaultKey`, choose a FiveM key from
the list or click **Record key** and press one key. Escape cancels capture without
closing the panel; Tab leaves capture. Modifier combinations and unknown inputs
are rejected. The Phone shortcut also has a disable switch which saves Lua `false`.

The stored value is a Cfx **KEYBOARD mapper ID**, not the printed character and
not `KeyboardEvent.code`. CEF supplies Windows virtual-key codes. German layout
examples: Ü → `OEM_1`, Ö → `OEM_3`, Ä → `OEM_7`, ß → `OEM_4`, `<` → `OEM_102`.
The OEM assignment depends on the OS keyboard layout; a US physical-key map would
produce the wrong result. NumPad Enter and main Enter remain separate
(`NUMPADENTER` / `RETURN`), as do NumPad digits and the top number row. Unknown OEM
events without a usable virtual-key code are rejected; select their verified ID
from the list instead. The server validates the IDs again before persisting them.

These fields set **server defaults**. FiveM retains existing bindings by command
name, including bindings already saved on a player's machine. After changing a
default, restart the resource; existing players may still need to change/reset
their own binding under FiveM Settings → Key Bindings → FiveM. Capturing a key in
the panel does not rebind the administrator's personal controls.

`Phone.HoldToLook.Control` and `SkyPic.Camera.*Control` use numeric **GTA control
indices**, a different API. They remain numeric fields. For example, `19` means
`INPUT_CHARACTER_WHEEL` (normally Left Alt); it is not a keyboard virtual-key code.
Do not paste `OEM_1` or a browser key code into those fields.

## Blocking GTA controls while using the phone

Open `/phonepanel` → Phone configurator → **Phone** → **Blocked GTA controls**.
`Phone.DisabledControls` accepts one unique GTA control ID (0-360) per row.
Add, edit or remove entries, then save with the checkmark; changes apply to open
phones immediately. In file mode, edit `Config.Phone.DisabledControls` and restart.

The defaults block the weapon wheel and weapon switching:
`14, 15, 16, 17, 37, 99, 100, 115, 116, 261, 262`. Walking and driving remain
available with `Phone.AllowMovement = true`. An empty list disables these extra
filters; existing attack protection remains. `AllowMovement = false` continues
to block all game input. Closed-phone notifications and the camera retain their
own input rules.

Use [GTA control IDs](https://docs.fivem.net/docs/game-references/controls/),
not FiveM keyboard mapper names. A separate resource using its own key mapping
or reading disabled controls must handle its own blocking; disabling a GTA action
does not disable that resource's command.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Editing Part 2 or `media.lua` has no effect | SQL mode is enabled by default. Edit the corresponding panel field and save, or deliberately switch to file mode and restart. |
| `/phonepanel` is unavailable | Check both `resource.sky_phone` ACE grants, player ACE group membership, `CommandPermissions.phonepanel`, and the active `AdminPanel.Enabled` / `AdminPanel.Command` settings. Read startup diagnostics. |
| The group passes `test_ace`, but a player is denied | Test that player's identifier as well. Group policy alone does not establish membership; a matching framework role/job alone is insufficient. Explicit ACE denies still apply. |
| Save fails or reports a revision conflict | Keep the unsaved values for comparison, load the current server revision, reapply the intended changes and save again. Only a successful save confirms persistence. |
| Unique phones or physical SIMs stay off | Check the actually selected inventory. Native ESX and `hex_4_inventory` force both off, including when detected through `auto`. |
| Changing the default key does not change an existing player's key | Restart for the new default, then change/reset the player's saved binding in FiveM settings. The panel does not replace personal bindings. |
| An OEM key is not recognized or Escape cannot be recorded | Use the key selector with a verified FiveM ID. Escape cancels capture and Tab leaves it; combinations are unsupported. |
| No number or cellular service after changing SIM mode | Test on the active device after restart. Physical mode needs an inserted SIM; coverage rules still apply. Disabling physical SIMs does not bulk-replace existing numbers. |

For logs, enable `Bridge.Debug` in the active configuration owner, reproduce once,
then disable it. Remove keys, tokens and full player identifiers before sharing logs.

## Source verification and runtime boundary

Phone control filtering was checked against Cfx revision
`0105063b0394b1b9d085c917a8dc9c9abf0a620f` on 2026-10-09.
[DISABLE_CONTROL_ACTION](https://github.com/citizenfx/natives/blob/master/PAD/DisableControlAction.md)
is a client native taking an integer input group, an integer control ID and a
boolean, with no return/out parameters. It must run each frame. Phone uses group
0 in its existing focus worker and stops that worker when its last focus claim ends.
The new list is validated and cached on configuration changes.

[codegen_out_lua.lua](https://github.com/citizenfx/fivem/blob/0105063b0394b1b9d085c917a8dc9c9abf0a620f/ext/natives/codegen_out_lua.lua)
(`printNative`),
[natives_loader.lua](https://github.com/citizenfx/fivem/blob/0105063b0394b1b9d085c917a8dc9c9abf0a620f/data/shared/citizen/scripting/lua/natives_loader.lua),
[LuaScriptNatives.cpp](https://github.com/citizenfx/fivem/blob/0105063b0394b1b9d085c917a8dc9c9abf0a620f/code/components/citizen-scripting-lua/src/LuaScriptNatives.cpp)
(`Lua_GetNativeHandler`, `Lua_InvokeNativeHandler`, `Lua_DoInvokeNative`,
`LuaScriptNativeContext::PushArgument`) and
[ScriptEngine.cpp](https://github.com/citizenfx/fivem/blob/0105063b0394b1b9d085c917a8dc9c9abf0a620f/code/components/scripting-gta/src/ScriptEngine.cpp)
(`CallNativeHandlerUniversal`, `CallNativeHandlerRage`) trace the generated Lua/OAL
wrapper to GTA's native handler. Integer arguments and booleans are pushed with
their native representations; there is no OneSync RPC. GTA's PAD implementation
is outside the public Cfx source. This revision was not identified as the
deployed client revision.

Local ESX verification on 2026-10-09 restarted the built/copied Phone resource
with experimental OAL enabled. The authorized phone was opened through its public
API. All eleven default weapon controls were disabled across 120 sampled frames;
sprint, jump, movement axes, steering, acceleration, braking and handbrake stayed
enabled. After closing, each control returned to its measured pre-open state
(some controls were already disabled before the test). Both managed probes ended
with zero running threads/timers, the phone session closed and the temporary phone
item removed. The CEF panel showed the compact 10-pixel setting titles and default
control list. A bounded NUI capture recorded no JavaScript/network errors.
This verifies local control flags, not physical mouse/controller input or a
customer's separate radial script. Qbox deployment bytes were checked, but its
runtime was not exercised.

CityWarn audio transport was checked against Cfx revision
`e34d12cd9a39cc223548a5be1ab09f60e9183051` on 2026-10-03:
[TriggerClientEvent documentation](https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/TriggerClientEvent/),
[SendNUIMessage documentation](https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/SendNUIMessage/),
[scheduler.lua](https://github.com/citizenfx/fivem/blob/e34d12cd9a39cc223548a5be1ab09f60e9183051/data/shared/citizen/scripting/lua/scheduler.lua),
[ServerResources.cpp](https://github.com/citizenfx/fivem/blob/e34d12cd9a39cc223548a5be1ab09f60e9183051/code/components/citizen-server-impl/src/ServerResources.cpp),
and [ResourceUIScripting.cpp](https://github.com/citizenfx/fivem/blob/e34d12cd9a39cc223548a5be1ab09f60e9183051/code/components/nui-resources/src/ResourceUIScripting.cpp).
The server packs the event arguments with MessagePack; target `-1` broadcasts
reliably to all connected clients. The existing client handler forwards the
configured audio path as JSON through `SendNUIMessage` to the resource's NUI frame.
These event-driven calls have no pointer/out parameters or OneSync entity RPC;
no per-frame work was added. The Lua NUI wrapper discards the native boolean
result. Playback uses the existing HTML audio player, not a GTA engine native.
The deployed artifact revision and live FiveM audio behavior remain unverified.

Inspected Cfx revision: `e60d29ac2d6e894e20ba78d5fdf3c190d976fd2a`.
The deployed client/server artifact revision was not identified; this is source
evidence, not a live FiveM/CEF test.

- [Cfx access-control commands](https://docs.fivem.net/docs/server-manual/server-commands/#access-control-commands)
  and [Security.cpp](https://github.com/citizenfx/fivem/blob/e60d29ac2d6e894e20ba78d5fdf3c190d976fd2a/code/client/citicore/se/Security.cpp): ACE registration/removal and inherited allow/deny evaluation.
- [ResourceScriptFunctions.cpp](https://github.com/citizenfx/fivem/blob/e60d29ac2d6e894e20ba78d5fdf3c190d976fd2a/code/components/citizen-scripting-core/src/ResourceScriptFunctions.cpp): `EXECUTE_COMMAND` runs under `resource.<name>`; `IS_PRINCIPAL_ACE_ALLOWED` evaluates the specified principal. Both use string arguments; the permission check returns a boolean and the command has no return value.
- [PlayerScriptFunctions.cpp](https://github.com/citizenfx/fivem/blob/e60d29ac2d6e894e20ba78d5fdf3c190d976fd2a/code/components/citizen-server-impl/src/PlayerScriptFunctions.cpp): server `IS_PLAYER_ACE_ALLOWED(char* playerSrc, char* object)` resolves the client and enters its principal scope. The Phone checks synchronously on the server; no RPC or pointer/out arguments.
- [RegisterKeyMapping declaration](https://github.com/citizenfx/fivem/blob/e60d29ac2d6e894e20ba78d5fdf3c190d976fd2a/ext/native-decls/RegisterKeyMapping.md), [GameInputFunctions.cpp](https://github.com/citizenfx/fivem/blob/e60d29ac2d6e894e20ba78d5fdf3c190d976fd2a/code/components/citizen-resources-gta/src/GameInputFunctions.cpp), and [GameInput.cpp](https://github.com/citizenfx/fivem/blob/e60d29ac2d6e894e20ba78d5fdf3c190d976fd2a/code/components/gta-core-five/src/GameInput.cpp): four string arguments on the client, no return/out arguments; registration validates mapper/parameter names, queues binding work on the game frame, and preserves existing command bindings. GTA's engine-side mapper implementation is outside the available Cfx source.
- [CefInput.cpp](https://github.com/citizenfx/fivem/blob/e60d29ac2d6e894e20ba78d5fdf3c190d976fd2a/code/components/nui-core/src/CefInput.cpp): `NuiInputTarget::KeyEvent` forwards `vKey` as `windows_key_code` and the scan code separately. This is why capture intentionally reads the deprecated but available `KeyboardEvent.keyCode` for OEM keys.
- [Cfx KEYBOARD IDs](https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/keyboard/), [Microsoft virtual-key codes](https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes), and [Microsoft German keyboard layout](https://github.com/microsoft/Windows-driver-samples/blob/main/input/layout/all_kbds/kbdgr/kbdgr.c) define the ID names, OEM values and German layout examples.

Before production use, verify German and US layouts in the actual FiveM CEF,
including OEM keys, left/right modifiers, NumPad Enter, cancellation and existing
personal bindings. Also test missing ACE setup, allowed/denied users and revocation
while the panel is open. Unit tests, browser screenshots, builds and copy hashes
do not establish those live runtime results.
