# Exports

Exports let one resource call functions exposed by another resource.

## Defining exports (Lua)

In your resource’s manifest:

```lua
exports { 'getWidget', 'setWidget' }
```

In your script, define the globals (or use the runtime export API):

```lua
local widget = nil

function getWidget()
  return widget
end

function setWidget(value)
  widget = value
end
```

## Consuming exports (Lua)

```lua
local w = exports.myresource:getWidget()
exports.myresource:setWidget(42)
```

## Server exports

Use **server_export** in the manifest and define the same on the server script. Other resources call them from server context:

```lua
exports.myresource:getData()
```

## Notes

- Prefer **exports** over manifest `export` when possible (e.g. `exports('resname', function() ... end)`).

## Reference

- Resource manifest exports: https://docs.fivem.net/docs/scripting-reference/resource-manifest/resource-manifest/#export
