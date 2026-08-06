# rawExecute

Executes raw SQL. Does not normalize result shape like query/prepare (SELECT returns raw result). Use when you need full control or non-standard result handling.

**Lua (Promise)**

```lua
local result = MySQL.rawExecute.await('DELETE FROM `sessions` WHERE `expires` < NOW()')
```

**Lua (Callback)**

```lua
MySQL.rawExecute('DELETE FROM `sessions` WHERE `expires` < NOW()', {}, function(result)
  -- raw result
end)
```

Prefer **query**, **insert**, **update**, **single**, **scalar**, or **prepare** when they match the use case; use rawExecute only when necessary. Reference: [rawExecute – coxdocs.dev](https://coxdocs.dev/oxmysql/Functions/rawExecute).
