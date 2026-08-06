# transaction

Run multiple queries in a transaction. If any fails, the transaction is rolled back.

**Lua (Promise)**

```lua
MySQL.transaction.await({
  { query = 'UPDATE `accounts` SET `balance` = `balance` - ? WHERE `id` = ?', values = { amount, fromId } },
  { query = 'UPDATE `accounts` SET `balance` = `balance` + ? WHERE `id` = ?', values = { amount, toId } },
})
```

**Lua (Callback)**

```lua
MySQL.transaction({
  { query = 'UPDATE `accounts` SET `balance` = `balance` - ? WHERE `id` = ?', values = { amount, fromId } },
  { query = 'UPDATE `accounts` SET `balance` = `balance` + ? WHERE `id` = ?', values = { amount, toId } },
}, function(success)
  if not success then -- rollback happened
  end
end)
```

**JavaScript**

```js
await MySQL.transaction([
  { query: 'UPDATE `accounts` SET `balance` = `balance` - ? WHERE `id` = ?', values: [amount, fromId] },
  { query: 'UPDATE `accounts` SET `balance` = `balance` + ? WHERE `id` = ?', values: [amount, toId] },
]);
```

Reference: [transaction – coxdocs.dev](https://coxdocs.dev/oxmysql/Functions/transaction).
