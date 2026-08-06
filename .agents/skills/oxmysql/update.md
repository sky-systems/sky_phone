# update

Updates rows; returns affected row count (or result object with affectedRows).

**Lua (Promise)**

```lua
local affected = MySQL.update.await('UPDATE `users` SET `lastname` = ? WHERE `identifier` = ?', { newLastName, identifier })
```

**Lua (Callback)**

```lua
MySQL.update('UPDATE `users` SET `lastname` = ? WHERE `identifier` = ?', { newLastName, identifier }, function(affected)
  -- use affected
end)
```

**JavaScript**

```js
const result = await MySQL.update('UPDATE `users` SET `lastname` = ? WHERE `identifier` = ?', [newLastName, identifier]);
```

Always use `?` placeholders for values. Reference: [update – coxdocs.dev](https://coxdocs.dev/oxmysql/Functions/update).
