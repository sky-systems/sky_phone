# scalar

Returns a single value (one row, one column). Use for COUNT, one field, etc.

**Lua (Promise)**

```lua
local count = MySQL.scalar.await('SELECT COUNT(*) FROM `users` WHERE `group` = ?', { group })
local name = MySQL.scalar.await('SELECT `username` FROM `users` WHERE `identifier` = ?', { identifier })
```

**Lua (Callback)**

```lua
MySQL.scalar('SELECT `username` FROM `users` WHERE `identifier` = ?', { identifier }, function(name)
  if name then print(name) end
end)
```

**JavaScript**

```js
const count = await MySQL.scalar('SELECT COUNT(*) FROM `users` WHERE `group` = ?', [group]);
const name = await MySQL.scalar('SELECT `username` FROM `users` WHERE `identifier` = ?', [identifier]);
```

Reference: [scalar – coxdocs.dev](https://coxdocs.dev/oxmysql/Functions/scalar).
