# zones — Poly, box, and sphere zones (lib.zones)

Faster alternative to PolyZone. Use for “when player enters/leaves area” or “is player inside area”. **Note:** Server-side zones have limited support: `onEnter`, `onExit`, and `inside` do not work on server; use client for full behavior.

Reference: [Zones (Shared) – coxdocs.dev](https://coxdocs.dev/ox_lib/Modules/Zones/Shared).

## lib.zones.poly — Polygon zone

`points` = array of `vector3` defining the polygon; `thickness` = height (default `4`).

```lua
local zone = lib.zones.poly({
  points = {
    vec3(413.8, -1026.1, 29),
    vec3(411.6, -1023.1, 29),
    vec3(412.2, -1018.0, 29),
    -- ...
  },
  thickness = 2,
  onEnter = function(self) print('entered', self.id) end,
  onExit = function(self) print('exited', self.id) end,
  inside = function(self) end,  -- called every frame while inside
  debug = true,
})
```

## lib.zones.box — Box zone

```lua
local zone = lib.zones.box({
  coords = vec3(442.5, -1017.6, 28.65),
  size = vec3(2, 2, 2),   -- default vec3(2, 2, 2)
  rotation = 45,          -- degrees, default 0
  onEnter = onEnter,
  onExit = onExit,
  inside = inside,
  debug = true,
})
```

## lib.zones.sphere — Sphere zone

```lua
local zone = lib.zones.sphere({
  coords = vec3(442.5, -1017.6, 28.65),
  radius = 2,             -- default 2
  onEnter = onEnter,
  onExit = onExit,
  inside = inside,
  debug = true,
})
```

## Methods

- **zone:remove()** — Removes the zone (data table can be reused later, e.g. with `lib.zones.poly(zone)`).
- **zone:contains(point)** — Returns `boolean` if `point` (vec3) is inside the zone.
- **zone:setDebug(true|false)** — Toggle debug draw; optional second arg: `vec4(r, g, b, a)` for color.

## Utilities

- **lib.zones.getAllZones()** — All registered zones.
- **lib.zones.getCurrentZones()** — Zones the player is currently inside (client).
- **lib.zones.getNearbyZones()** — Zones near the player (client).

## Creating zones in-game

Use the built-in zone creator: `/zone poly`, `/zone box`, or `/zone sphere`. Controls appear on the right; zones are saved to `ox_lib/created_zones.lua`.
