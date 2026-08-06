# query

SELECT returns all matching rows (array of rows). Other statements return insertId, affectedRows, etc.

**Lua (Promise)**

```lua
local response = MySQL.query.await('SELECT `firstname`, `lastname` FROM `users` WHERE `identifier` = ?', { identifier })
if response then
  for i = 1, #response do
    local row = response[i]
    print(row.firstname, row.lastname)
  end
end
```

**Lua (Callback)**

```lua
MySQL.query('SELECT `firstname`, `lastname` FROM `users` WHERE `identifier` = ?', { identifier }, function(response)
  if response then
    for i = 1, #response do
      local row = response[i]
      print(row.firstname, row.lastname)
    end
  end
end)
```

**JavaScript**

```js
const rows = await MySQL.query('SELECT `firstname`, `lastname` FROM `users` WHERE `identifier` = ?', [identifier]);
// rows is array of objects
```

Reference: [query – coxdocs.dev](https://coxdocs.dev/oxmysql/Functions/query).
