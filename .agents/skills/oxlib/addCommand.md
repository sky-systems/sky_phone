# addCommand — Server commands with validation and suggestions

Use `lib.addCommand` (server-side) to register commands with help text, parameter validation, and optional permission (restricted). Prefer over raw `RegisterCommand` when you want typed args and chat suggestions.

```lua
lib.addCommand('giveitem', {
  help = 'Give an item to a player',
  restricted = 'group.admin',  -- or true (ace only) or array of permissions
  params = {
    { name = 'target', type = 'playerId', help = 'Target player server id' },
    { name = 'item', type = 'string', help = 'Item name' },
    { name = 'count', type = 'number', help = 'Amount', optional = true },
  },
}, function(source, args, raw)
  local target = args.target
  local item = args.item
  local count = args.count or 1
  -- ...
end)
```

**Param types:** `'number'`, `'playerId'`, `'string'`, `'longString'`. Use `optional = true` for optional params.

**Multiple names for the same command:**

```lua
lib.addCommand({'giveitem', 'gi'}, { help = '...', params = { ... } }, cb)
```

Docs: [AddCommand (Server) – coxdocs.dev](https://coxdocs.dev/ox_lib/Modules/AddCommand/Server).
