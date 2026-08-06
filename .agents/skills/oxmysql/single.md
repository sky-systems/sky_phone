# single

Returns a single row (first match) or nil/null if none.

**Lua (Promise)**

```lua
local user = MySQL.single.await('SELECT * FROM `users` WHERE `identifier` = ?', { identifier })
if user then
  print(user.firstname, user.lastname)
end
```

**Lua (Callback)**

```lua
MySQL.single('SELECT * FROM `users` WHERE `identifier` = ?', { identifier }, function(user)
  if user then print(user.firstname) end
end)
```

**JavaScript**

```js
const user = await MySQL.single('SELECT * FROM `users` WHERE `identifier` = ?', [identifier]);
// user is one object or null
```

Reference: [single – coxdocs.dev](https://coxdocs.dev/oxmysql/Functions/single).
