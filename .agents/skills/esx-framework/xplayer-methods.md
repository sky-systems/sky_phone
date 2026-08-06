# xPlayer Methods (Server Only)

The xPlayer object represents a player on the **SERVER** with many useful methods.

## Getting xPlayer

```lua
local xPlayer = ESX.GetPlayerFromId(source)
if not xPlayer then return end
```

## Basic Info

### xPlayer.getName()

Returns player's name.

```lua
print('Player name:', xPlayer.getName())
```

### xPlayer.getIdentifier()

Returns player's identifier (with char prefix).

```lua
print('Identifier:', xPlayer.getIdentifier())
-- Output: "char1:license:abc123..."
```

### xPlayer.getSSN()

Returns player's Social Security Number.

```lua
print('SSN:', xPlayer.getSSN())
-- Output: "123-45-6789"
```

### xPlayer.setName(name)

Sets player's name.

```lua
xPlayer.setName('John Doe')
```

## Coordinates

### xPlayer.getCoords(vector)

Returns player's last known coordinates.

```lua
-- As table
local coords = xPlayer.getCoords()
print(coords.x, coords.y, coords.z, coords.heading)

-- As vector3
local coords = xPlayer.getCoords(true)
local distance = #(coords - vector3(0, 0, 0))
```

### xPlayer.setCoords(coords)

Teleports player to coordinates.

```lua
xPlayer.setCoords(vector3(100.0, 200.0, 50.0))

-- Or vector4 with heading
xPlayer.setCoords(vector4(100.0, 200.0, 50.0, 90.0))
```

### xPlayer.kick(reason)

Kicks player from server.

```lua
xPlayer.kick('You have been kicked')
```

## Job Management

### xPlayer.getJob()

Returns player's job data.

```lua
local job = xPlayer.getJob()
print('Job:', job.name)
print('Grade:', job.grade)
print('Label:', job.label)
print('Salary:', job.grade_salary)
print('On Duty:', job.onDuty)
```

### xPlayer.setJob(name, grade, onDuty)

Sets player's job.

```lua
-- Set job with default duty state
xPlayer.setJob('police', 4)

-- Set job and duty state
xPlayer.setJob('police', 4, true) -- On duty
xPlayer.setJob('police', 4, false) -- Off duty
```

## Money Management

### xPlayer.getMoney()

Returns cash amount.

```lua
local cash = xPlayer.getMoney()
print('Cash:', cash)
```

### xPlayer.addMoney(amount, reason)

Adds cash.

```lua
xPlayer.addMoney(500, 'Sold apples')
```

### xPlayer.removeMoney(amount, reason)

Removes cash.

```lua
if xPlayer.getMoney() >= 500 then
    xPlayer.removeMoney(500, 'Bought item')
end
```

### xPlayer.setMoney(amount)

Sets cash to exact amount.

```lua
xPlayer.setMoney(1000)
```

## Account Management

### xPlayer.getAccounts(minimal)

Returns all accounts.

```lua
-- Full data
local accounts = xPlayer.getAccounts()
print('Bank:', accounts.bank.money)
print('Cash:', accounts.money.money)

-- Minimal (just amounts)
local accounts = xPlayer.getAccounts(true)
print('Bank:', accounts.bank)
print('Cash:', accounts.money)
```

### xPlayer.getAccount(accountName)

Returns specific account.

```lua
local bankAccount = xPlayer.getAccount('bank')
print('Bank balance:', bankAccount.money)
```

### xPlayer.addAccountMoney(account, amount, reason)

Adds money to account.

```lua
xPlayer.addAccountMoney('bank', 5000, 'Paycheck received')
```

### xPlayer.removeAccountMoney(account, amount, reason)

Removes money from account.

```lua
if xPlayer.getAccount('bank').money >= 2000 then
    xPlayer.removeAccountMoney('bank', 2000, 'Paid bills')
end
```

### xPlayer.setAccountMoney(account, amount, reason)

Sets account to exact amount.

```lua
xPlayer.setAccountMoney('bank', 10000, 'Admin action')
```

## Paycheck Management

### xPlayer.togglePaycheck(toggle)

Enable/disable paycheck.

```lua
xPlayer.togglePaycheck(false) -- Disable paycheck
xPlayer.togglePaycheck(true)  -- Enable paycheck
```

### xPlayer.isPaycheckEnabled()

Check if paycheck is enabled.

```lua
if xPlayer.isPaycheckEnabled() then
    print('Paycheck is enabled')
end
```

## Inventory (Default ESX Inventory)

### xPlayer.getInventory(minimal)

Returns player inventory.

```lua
-- Full data
local inventory = xPlayer.getInventory()
for itemName, itemData in pairs(inventory) do
    print(itemName, itemData.count, itemData.weight)
end

-- Minimal (just counts)
local inventory = xPlayer.getInventory(true)
for itemName, count in pairs(inventory) do
    print(itemName, count)
end
```

### xPlayer.getInventoryItem(item)

Returns specific item data.

```lua
local breadItem = xPlayer.getInventoryItem('bread')
print('Bread count:', breadItem.count)
print('Bread weight:', breadItem.weight)
```

### xPlayer.addInventoryItem(item, count)

Adds item to inventory.

```lua
xPlayer.addInventoryItem('bread', 5)
```

### xPlayer.removeInventoryItem(item, count)

Removes item from inventory.

```lua
xPlayer.removeInventoryItem('bread', 2)
```

### xPlayer.setInventoryItem(item, count)

Sets item to exact count.

```lua
xPlayer.setInventoryItem('bread', 10)
```

### xPlayer.hasItem(item)

Checks if player has item.

```lua
if xPlayer.hasItem('bread') then
    print('Player has bread')
end
```

### xPlayer.getWeight()

Returns current inventory weight.

```lua
print('Current weight:', xPlayer.getWeight())
```

### xPlayer.getMaxWeight()

Returns max inventory weight.

```lua
print('Max weight:', xPlayer.getMaxWeight())
```

### xPlayer.setMaxWeight(weight)

Sets max inventory weight.

```lua
xPlayer.setMaxWeight(50) -- Backpack equipped
```

### xPlayer.canCarryItem(item, count)

Checks if player can carry item.

```lua
if xPlayer.canCarryItem('bread', 5) then
    xPlayer.addInventoryItem('bread', 5)
else
    xPlayer.showNotification('Inventory full', 'error')
end
```

### xPlayer.canSwapItem(firstItem, firstCount, secondItem, secondCount)

Checks if items can be swapped.

```lua
if xPlayer.canSwapItem('bread', 5, 'water', 3) then
    xPlayer.removeInventoryItem('bread', 5)
    xPlayer.addInventoryItem('water', 3)
end
```

## Weapon Management (Default ESX)

### xPlayer.getLoadout(minimal)

Returns player's weapons.

```lua
-- Full data
local loadout = xPlayer.getLoadout()
for weaponName, weaponData in pairs(loadout) do
    print(weaponName, weaponData.ammo, weaponData.components)
end

-- Minimal (just ammo and components)
local loadout = xPlayer.getLoadout(true)
for weaponName, weaponData in pairs(loadout) do
    print(weaponName, weaponData.ammo)
end
```

### xPlayer.getWeapon(weaponName)

Returns specific weapon data.

```lua
local pistol = xPlayer.getWeapon('WEAPON_PISTOL')
if pistol then
    print('Ammo:', pistol.ammo)
    print('Components:', json.encode(pistol.components))
end
```

### xPlayer.hasWeapon(weaponName)

Checks if player has weapon.

```lua
if xPlayer.hasWeapon('WEAPON_PISTOL') then
    print('Player has pistol')
end
```

### xPlayer.addWeapon(weaponName, ammo)

Gives weapon to player.

```lua
xPlayer.addWeapon('WEAPON_PISTOL', 250)
```

### xPlayer.removeWeapon(weaponName)

Removes weapon from player.

```lua
xPlayer.removeWeapon('WEAPON_PISTOL')
```

### xPlayer.addWeaponAmmo(weaponName, ammo)

Adds ammo to weapon.

```lua
xPlayer.addWeaponAmmo('WEAPON_PISTOL', 50)
```

### xPlayer.removeWeaponAmmo(weaponName, ammo)

Removes ammo from weapon.

```lua
xPlayer.removeWeaponAmmo('WEAPON_PISTOL', 25)
```

### xPlayer.updateWeaponAmmo(weaponName, ammo)

Sets weapon ammo to exact amount.

```lua
xPlayer.updateWeaponAmmo('WEAPON_PISTOL', 100)
```

### xPlayer.addWeaponComponent(weaponName, component)

Adds component to weapon.

```lua
xPlayer.addWeaponComponent('WEAPON_PISTOL', 'suppressor')
```

### xPlayer.removeWeaponComponent(weaponName, component)

Removes component from weapon.

```lua
xPlayer.removeWeaponComponent('WEAPON_PISTOL', 'suppressor')
```

### xPlayer.hasWeaponComponent(weaponName, component)

Checks if weapon has component.

```lua
if xPlayer.hasWeaponComponent('WEAPON_PISTOL', 'suppressor') then
    print('Pistol has suppressor')
end
```

### xPlayer.setWeaponTint(weaponName, tintIndex)

Sets weapon tint.

```lua
xPlayer.setWeaponTint('WEAPON_PISTOL', 2) -- Gold tint
```

### xPlayer.getWeaponTint(weaponName)

Gets weapon tint.

```lua
local tint = xPlayer.getWeaponTint('WEAPON_PISTOL')
print('Tint index:', tint)
```

## Permissions

### xPlayer.getGroup()

Returns player's permission group.

```lua
local group = xPlayer.getGroup()
print('Group:', group) -- 'user', 'admin', 'superadmin'
```

### xPlayer.setGroup(group)

Sets player's permission group.

```lua
xPlayer.setGroup('admin')
```

## Variables & Metadata

### xPlayer.set(key, value)

Sets custom variable.

```lua
xPlayer.set('lastLocation', 'LS Airport')
```

### xPlayer.get(key)

Gets custom variable.

```lua
local lastLocation = xPlayer.get('lastLocation')
print('Last location:', lastLocation)
```

### xPlayer.setMeta(key, value, subKey)

Sets metadata (persisted to database).

```lua
xPlayer.setMeta('title', 'Dr.')
xPlayer.setMeta('licenses', 'driver', true) -- With subkey
```

### xPlayer.getMeta(key, subKey)

Gets metadata.

```lua
local title = xPlayer.getMeta('title')
print('Title:', title)

local hasDriver = xPlayer.getMeta('licenses', 'driver')
```

### xPlayer.clearMeta(key, subKey)

Clears metadata.

```lua
xPlayer.clearMeta('title')
xPlayer.clearMeta('licenses', 'driver') -- Clear subkey
```

## Client Communication

### xPlayer.triggerEvent(eventName, ...)

Triggers client event for this player.

```lua
xPlayer.triggerEvent('myResource:showMenu', {title = 'Shop', items = {}})
```

### xPlayer.showNotification(msg, type, length, title, position)

Shows notification to player.

```lua
xPlayer.showNotification('You received $500', 'success', 3000)
```

### xPlayer.showAdvancedNotification(sender, subject, msg, textureDict, iconType, flash, saveToBrief, hudColorIndex)

Shows GTA-style notification.

```lua
xPlayer.showAdvancedNotification('Police', 'Dispatch', 'Code 3', 'CHAR_CALL911', 1)
```

### xPlayer.showHelpNotification(msg, thisFrame, beep, duration)

Shows help notification.

```lua
xPlayer.showHelpNotification('Press E to interact', false, true, 3000)
```

## Utility

### xPlayer.getPlayTime()

Returns total playtime in seconds.

```lua
local playtime = xPlayer.getPlayTime()
local hours = math.floor(playtime / 3600)
print('Playtime:', hours, 'hours')
```

### xPlayer.executeCommand(command)

Executes command as player.

```lua
xPlayer.executeCommand('dv 5')
```

## Best Practices

1. **Always check if xPlayer exists**:
   ```lua
   local xPlayer = ESX.GetPlayerFromId(source)
   if not xPlayer then return end
   ```

2. **Check before removing**:
   ```lua
   if xPlayer.getMoney() >= price then
       xPlayer.removeMoney(price, 'Bought item')
   else
       xPlayer.showNotification('Not enough money', 'error')
   end
   ```

3. **Check inventory space**:
   ```lua
   if xPlayer.canCarryItem('bread', 5) then
       xPlayer.addInventoryItem('bread', 5)
   else
       xPlayer.showNotification('Inventory full', 'error')
   end
   ```

4. **Always provide reasons**:
   ```lua
   -- GOOD
   xPlayer.addMoney(500, 'Sold apples')
   
   -- BAD (no reason, harder to debug)
   xPlayer.addMoney(500)
   ```

5. **Cache xPlayer reference**:
   ```lua
   -- GOOD
   local xPlayer = ESX.GetPlayerFromId(source)
   xPlayer.addMoney(100)
   xPlayer.setJob('police', 0)
   
   -- BAD (calls GetPlayerFromId twice)
   ESX.GetPlayerFromId(source).addMoney(100)
   ESX.GetPlayerFromId(source).setJob('police', 0)
   ```
