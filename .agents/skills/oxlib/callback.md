# callback — Client ↔ Server communication

Use `lib.callback` for request/response between client and server. Prefer this over TriggerServerCallback/RegisterNetCallback patterns.

## Server: register a callback (handle client requests)

```lua
-- Server: register handler. First arg is source (player id), then any args sent by client.
lib.callback.register('myresource:getData', function(source, key)
  local value = GetStoredValue(key)
  return value
end)
```

## Client: call server (callback style)

```lua
lib.callback('myresource:getData', false, function(value)
  if value then
    print(value)
  end
end, 'someKey')
```

Second argument is `delay` (number or `false`): cooldown in ms before the callback can be triggered again; use `false` for no limit.

## Client: call server (await — yields until response)

```lua
local value = lib.callback.await('myresource:getData', false, 'someKey')
if value then
  print(value)
end
```

## Server: call client

```lua
-- Server: trigger client callback
lib.callback('ox:getNearbyVehicles', source, function(vehicles)
  for i = 1, #vehicles do
    -- use vehicles[i]
  end
end, radius)
```

```lua
-- Server: await client response
local vehicles = lib.callback.await('ox:getNearbyVehicles', source, radius)
```

## Client: register a callback (handle server requests)

```lua
lib.callback.register('ox:getNearbyVehicles', function(radius)
  local coords = GetEntityCoords(cache.ped)
  return lib.getNearbyVehicles(coords, radius, true)
end)
```

Use a unique name (e.g. `resourcename:action`) to avoid clashes. Full docs: [Callback – coxdocs.dev](https://coxdocs.dev/ox_lib/Modules/Callback/Lua/Server) and [Client](https://coxdocs.dev/ox_lib/Modules/Callback/Lua/Client).
