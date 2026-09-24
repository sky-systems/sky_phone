# Zones

Use lib.zones.poly, box or sphere for the shape already required by the resource.
A polygon takes vector points and thickness; a box takes coords/size/rotation; a sphere takes
coords/radius. Verify installed defaults instead of encoding an assumed universal shape.

At the pinned source, omitted polygon thickness is `4`, sphere radius `2`, and box rotation
`0` degrees. Specify box size explicitly: its documented default and the constructor's
internal half-extents do not agree at this snapshot. Recheck defaults when changing versions.

Client onEnter/onExit/inside callbacks track the local player; inside can run every frame.
The server does not run these client tracking callbacks. For explicit geometry tests use
the relevant zone:contains(point) contract. Client membership is not server authorization.

Keep callback work bounded and remove owned zones with zone:remove() when their lifecycle ends.
Avoid duplicate registrations after reopening/reconfiguration. Keep debug drawing out of normal
flows; verify client availability before using zone:setDebug. Do not claim zones outperform an
alternative without profiling the relevant workload.

When applicable AGENTS requires Sky interactions/zones, use that established owner instead of
adding parallel registrations. [Zone docs](https://overextended.dev/docs/ox_lib/Zones/Shared)
and [implementation](sources.md).

## The three shapes

Client construction examples; replace these illustration coordinates with the resource's
measured geometry. `onEnter`/`onExit` run on changes, while `inside` is for bounded per-frame
work. Keep ordinary setup, queries and network traffic out of `inside`.

```lua
local preview_visible = false
local sphere = lib.zones.sphere({
    coords = vec3(215.0, -810.0, 30.0),
    radius = 3.0,
    onEnter = function(self)
        preview_visible = true
        print(("Entered preview zone %s"):format(self.id))
    end,
    onExit = function(self)
        preview_visible = false
        print(("Left preview zone %s"):format(self.id))
    end
})

local box = lib.zones.box({
    coords = vec3(220.0, -810.0, 30.0),
    size = vec3(4.0, 6.0, 3.0),
    rotation = 25.0
})

local polygon = lib.zones.poly({
    points = {
        vec3(225.0, -813.0, 30.0), vec3(230.0, -813.0, 30.0),
        vec3(230.0, -807.0, 30.0), vec3(225.0, -807.0, 30.0)
    },
    thickness = 3.0
})

local contained = box:contains(vec3(220.0, -810.0, 30.0))
print(("Point inside example box: %s"):format(contained))
box:setDebug(true, { r = 40, g = 180, b = 255, a = 90 })
box:setDebug(false)

-- At teardown/reconfiguration, release each owned registration.
sphere:remove()
box:remove()
polygon:remove()
```

Constructors can mutate the supplied table. Keep original configuration separately and
rebuild from it when re-registering; blindly reusing a mutated box may halve its size again.
Removal unregisters tracking; retaining an old Lua object does not restart its callbacks.

## Inspection and authoring

`lib.zones.getAllZones()` returns the registry (iterate with `pairs`, do not assume a dense
array). Client `getCurrentZones()` exposes the internal inside/debug tracking set at this
revision; it is not proof that every zone containing the player appears there. The client
`getNearbyZones()` exposes the current spatial-neighborhood list, not an authorization test.
Use `zone:contains(point)` when the exact geometry answer is needed. Server automatic player
tracking/current/nearby state is not equivalent to the client's.

For development, `/zone poly`, `/zone box` and `/zone sphere` open the built-in creator;
its displayed controls guide shape editing. Results are written to `ox_lib/created_zones.lua`
in the selected format. Move the reviewed configuration into its owning resource and keep
debug drawing disabled for ordinary use. The creator is tooling, not a live customer config
storage API; observe the server's permissions.
