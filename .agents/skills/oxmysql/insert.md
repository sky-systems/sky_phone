# insert

Inserts a row and returns the insert id (or nil/falsy on failure).

**Lua (Promise)**

```lua
local id = MySQL.insert.await('INSERT INTO `users` (identifier, firstname, lastname) VALUES (?, ?, ?)', { identifier, firstName, lastName })
print(id)
```

**Lua (Callback)**

```lua
MySQL.insert('INSERT INTO `users` (identifier, firstname, lastname) VALUES (?, ?, ?)', { identifier, firstName, lastName }, function(id)
  print(id)
end)
```

**JavaScript**

```js
const insertId = await MySQL.insert('INSERT INTO `users` (identifier, firstname, lastname) VALUES (?, ?, ?)', [identifier, firstName, lastName]);
```

Reference: [insert – coxdocs.dev](https://coxdocs.dev/oxmysql/Functions/insert).
