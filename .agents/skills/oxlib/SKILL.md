---
name: oxlib
description: "Ox Lib for FiveM - UI (notify, alert, input, menu, progress), callbacks client-server, addCommand, zones (poly/box/sphere), keybinds, shared utilities. Use when writing resources that need ox_lib or when the user mentions notifications, dialogs, menus, zones/areas, or client-server communication."
author: germanfndez
version: "1.0.0"
mcp-server: projecthub
---

# Ox Lib

Standalone library for FiveM: reusable UI, callbacks, commands, and shared modules. Used by many Ox resources (ox_inventory, ox_target, etc.). Always prefer ox_lib over custom NUI or legacy patterns when the user wants notifications, dialogs, menus, or client-server calls.

## When to use

- User asks for notifications, alert dialogs, input dialogs, menus, progress bars, or TextUI.
- Client needs to call server (or server calls client): use `lib.callback` / `lib.callback.await` and `lib.callback.register`.
- Registering server commands with help and params: use `lib.addCommand`.
- Keybinds, context menus, skill checks, locales, or shared helpers (lib.table, lib.string, etc.).
- **Zones**: “when player enters/leaves area”, “is player inside” — use `lib.zones.poly`, `lib.zones.box`, `lib.zones.sphere` (prefer client; server has limited support for onEnter/onExit/inside).

## Setup

- In `fxmanifest.lua`: `shared_scripts { '@ox_lib/init.lua' }`. Optional: `ox_libs { 'locale', 'callback', ... }` to preload modules.

## Rules

Read the rule that matches what you're doing:

- **rules/init.md** — Adding ox_lib to fxmanifest, shared_script, ox_libs.
- **rules/callback.md** — Client↔server: `lib.callback`, `lib.callback.await`, `lib.callback.register`.
- **rules/interface.md** — UI: `lib.notify`, `lib.alertDialog`, `lib.inputDialog`; icons (Font Awesome 6).
- **rules/addCommand.md** — Server commands: `lib.addCommand` with help, params, restricted.
- **rules/zones.md** — Zones: `lib.zones.poly`, `lib.zones.box`, `lib.zones.sphere`; onEnter, onExit, inside; remove, contains, setDebug.

## References (look up if not covered in the rules above)

If something isn't covered in the rules above, check the official docs:

- **Ox Lib (index):** https://coxdocs.dev/ox_lib  
- **Interface (notify, alert, input, menu, progress, textui):** https://coxdocs.dev/ox_lib/Modules/Interface  
- **Callback (client/server):** https://coxdocs.dev/ox_lib/Modules/Callback/Lua/Server and …/Client  
- **AddCommand:** https://coxdocs.dev/ox_lib/Modules/AddCommand/Server  
- **Zones:** https://coxdocs.dev/ox_lib/Modules/Zones/Shared  
- **AddKeybind:** https://coxdocs.dev/ox_lib/Modules/AddKeybind/Client  
- **Locale, Table, String, Math, etc.:** navigate from https://coxdocs.dev/ox_lib
