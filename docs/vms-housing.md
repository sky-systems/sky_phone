# VMS Housing bridge

Select `vms` under Housing in Phone Configurator, or set
`Config.Housing.System = "vms"` when file-based configuration is active.
Start `vms_housing` before the phone. Existing saved Configurator values take
precedence over file settings.

## Supported phone features

| Feature                                               | Current bridge                                    |
| ----------------------------------------------------- | ------------------------------------------------- |
| Owned and rented properties                           | Listed from VMS server data                       |
| Properties with a matching key or assigned permission | Listed after server authorization                 |
| Owner/keyholder label                                 | Available; renters use the keyholder label        |
| Entrance waypoint                                     | Available after another server access check       |
| EasyShare                                             | Available; sharing does not grant property access |
| Remote lock controls                                  | Unavailable                                       |
| List holders, grant/revoke keys or edit permissions   | Unavailable                                       |
| CCTV and stored-vehicle counts                        | Unavailable                                       |

The published [server exports](https://docs.vames-store.com/assets/vms_housing/developer-api/server-exports)
provide reads and access checks, but no dedicated external lock toggle, key
grant/revoke, CCTV, or stored-vehicle-count operation. Physical key serials are
not player identifiers and cannot be used as a list of named keyholders.

VMS also publishes [client menus](https://docs.vames-store.com/assets/vms_housing/developer-api/client-exports):
`OpenManageMenu()`, `OpenMarketplace()`, and `OpenFurnitureMenu()`. These offer
possible future shortcuts into VMS's own interfaces. The phone currently does
not launch them or implement their purchase, rental, furniture, or management
flows. Their availability and permissions remain owned by VMS.

## Item-based key setup and troubleshooting

Follow the VMS [installation instructions](https://docs.vames-store.com/assets/vms_housing/installation)
for the selected inventory. With `Config.UseKeysOnItem = true`, register
`house_key`; its documented ox_inventory definition uses weight 10,
`stack = false`, and `close = true`.

VMS Housing 1.5.2 was observed returning `nil` from the server `HasKeys` export
when no matching key item is held, despite its documented boolean annotation.
The bridge treats only that missing `HasKeys` result as no key, then checks
`HasAnyPermission`. A missing key does not abort the whole property list.
Unexpected types and export exceptions still produce a provider error.

If `house_key` is not registered, ox_inventory returns no item count and VMS's
inventory adapter can fail while comparing it with a number. Complete the item
installation rather than changing access checks to accept an inventory error.

## Development verification

`tests/housing_vms.lua` covers nil/boolean key results, independently assigned
permissions, denied waypoints, unexpected types, and provider exceptions. CI
runs it alongside the existing TK Housing tests.

Live checks with VMS 1.5.2 and ox_inventory confirmed the missing-item failure,
`true` with a matching key item, and `nil` after removing that item. The deployed
bridge returned an empty authorized list and denied a waypoint for an isolated
outsider probe using real VMS exports. The in-game owner workflow displayed the
property and its details and successfully set an entrance waypoint. Sending an
EasyShare message and other inventory/framework combinations were not tested.

The export boundary was checked against
[`citizenfx/fivem@72e56f5`](https://github.com/citizenfx/fivem/blob/72e56f5e3533394cebb7b977228e04c266c9ca1c/data/shared/citizen/scripting/lua/scheduler.lua#L641),
particularly `exportProcessResult` and the export call wrapper, and the
corresponding deployed scheduler code. This source revision is not a verified
match for the entire deployed artifact. VMS's escrowed export implementation
was not available as readable source; its return behavior was verified at runtime.
