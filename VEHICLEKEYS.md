# Garage vehicle keys

Set `Config.Garage.VehicleKeySystem` in the Lua config, or open **Phonepanel >
Configurator > Garage > General > Vehicle key system** when the configurator
is enabled. The setting is saved in SQL and sent to connected phones.

- `auto` (default): use the first running supported resource in the order below.
  If none is running, delivery works without a key integration.
- `none`: disable key delivery.
- A provider name: require that provider. An unavailable explicit provider
  prevents a valet order before the player is charged.
- `custom_client` / `custom_server`: implement the corresponding handler in
  the existing bridge file before selecting it.

| Provider         | Resource                                   | Export side |
| ---------------- | ------------------------------------------ | ----------- |
| qbox             | qbx_vehiclekeys                            | Server      |
| qb               | qb-vehiclekeys                             | Server      |
| quasar           | qs-vehiclekeys                             | Client      |
| mrnewb           | MrNewbVehicleKeys                          | Client      |
| mk               | mk_vehiclekeys                             | Client      |
| wasabi           | wasabi_carlock                             | Client      |
| msk              | msk_vehiclekeys                            | Client      |
| brutal           | brutal_keys                                | Client      |
| vehicles_keys    | vehicles_keys                              | Server      |
| ak47             | ak47_qb_vehiclekeys, then ak47_vehiclekeys | Client      |
| jc (alias: jota) | jc_vehiclekeys                             | Client      |
| kiminaze         | VehicleKeyChain                            | Server      |
| ic3d             | ic3d_vehiclekeys                           | Client      |
| zyke_garages     | zyke_garages                               | Client      |

## Delivery

The provider is selected per order and remains fixed for that delivery.
Resource detection is evaluated again for each new order, including after a
resource restart or a Phonepanel change.

After the valet arrives, the server validates the order, expiry, player
identifier, network ownership, entity type, plate and model. Server exports
run there; client exports run on the requesting player after the completion
callback succeeds. No generic network event accepts arbitrary key requests.
Repeated completion requests cannot issue another key grant.

Server export failures leave cancellation/refund available. Client export
failures are logged and notified; the already confirmed vehicle is retained.
Client-only APIs inherit the key resource's own authorization guarantees.

There are exactly two integration files:

- `sky_phone/source/bridge/server/vehiclekeys.lua`: detection and server exports.
- `sky_phone/source/bridge/client/vehiclekeys.lua`: client exports.

The resource calls key-system exports directly and has no dependency on
`sky_base`. The existing key adapters supplied as the reference remain the
basis for their export signatures; no base helper or base event is called.

## API references

Checked against the reference adapters and the following upstream contracts:

- [QB server exports](https://github.com/qbcore-framework/qb-vehiclekeys/blob/main/server.lua)
- [Qbox server exports](https://docs.qbox.re/resources/qbx_vehiclekeys/exports/server)
- [Kiminaze server exports](https://docs.kiminaze.de/scripts/vehiclekeychain/exports-server/)
- [Jaksam server export](https://documentation.jaksam-scripts.com/vehicles-keys/server/give-keys-to-player-id)
- [Quasar integration](https://github.com/imnotquasar/docs/blob/main/player-systems/vehicle-keys/installation.md)
- [MrNewb client exports](https://mrnewbs-scrips.gitbook.io/guide/vehiclekeys/vehicle-keys-exports/client-exports)
- [AK47 integration](https://docs.menanak47.com/esx/ak47_vehiclekeys/integration)
- [IC3D integration](https://ic3d.gitbook.io/ic3d-marketplace/assets-and-guides/vehicle-keys/exports/snippets/lc-scripts)
- [MSK integrations](https://docu.msk-scripts.de/de/docs/msk_vehiclekeys/guides/integrations/)
- Cfx server signatures: [entity type](https://github.com/citizenfx/fivem/blob/master/ext/native-decls/GetEntityType.md),
  [model](https://github.com/citizenfx/fivem/blob/master/ext/native-decls/GetEntityModel.md),
  [plate](https://github.com/citizenfx/fivem/blob/master/ext/native-decls/GetVehicleNumberPlateText.md).

## Validation

Run from the repository root with Lua 5.4:

```text
lua tests/vehiclekeys.lua
lua tests/server_garage.lua
lua tests/client_garage_valet.lua
lua tests/phone_configurator.lua
```

The tests stub provider exports and FiveM natives. A live server should also
verify one delivery with the installed key resource after restarting
`sky_phone` with OAL enabled.
