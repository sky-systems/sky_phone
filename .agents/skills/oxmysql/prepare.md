# prepare

Prepared statements: faster for repeated queries. **Only `?` (value) and `??` (column name) placeholders** — named placeholders throw.

- Date does not return the datestring commonly used in FiveM.
- TINYINT(1) and BIT do not return boolean.
- SELECT result shape: column, row, or array of rows depending on columns/rows selected (unlike rawExecute).

**Lua (Promise)**

```lua
local response = MySQL.prepare.await('SELECT `firstname`, `lastname` FROM `users` WHERE `identifier` = ?', { identifier })
```

**Lua (Callback)**

```lua
MySQL.prepare('SELECT `firstname`, `lastname` FROM `users` WHERE `identifier` = ?', { identifier }, function(response)
  -- use response
end)
```

**Upsert (insert or update on duplicate)**

```lua
MySQL.prepare('INSERT INTO ox_inventory (owner, name, data) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)', { owner, dbId, inventory })
```

Reference: [prepare – coxdocs.dev](https://coxdocs.dev/oxmysql/Functions/prepare).
