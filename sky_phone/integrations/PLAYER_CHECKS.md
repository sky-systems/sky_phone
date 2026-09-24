# Player checks and opening cancellation

Edit `config/functions.lua` to customize the phone's player checks. The same file
loads on the client and server. Restart `sky_phone` after changing it.

| Function                                     | Contract                                                          |
| -------------------------------------------- | ----------------------------------------------------------------- |
| `PhoneFunctions.IsDead(context)`             | Return a boolean for death or incapacitation.                     |
| `PhoneFunctions.IsHandcuffed(context)`       | Return a boolean for handcuffs.                                   |
| `PhoneFunctions.CanOpenPhone(player_source)` | Return `true` to allow opening, or `false, error_code` to cancel. |

The status context contains `isServer`, `ped`, `state` (generic player state),
`framework` (the phone adapter's status data), `report` (the server's validated
client status report), and `legacyDead` (the client ESX death-event latch).
`source` is the player's server ID on the server and absent on the client.
Status functions must return booleans. Keep client-only natives inside the client
branch and use only the phone's own documented third-party integrations.

The existing **Block when dead** and **Block when cuffed** settings still decide
whether these states block phone use. These settings remain configurable through
the Phone Configurator. The functions are code hooks and are not stored in SQL.

`CanOpenPhone` receives the player's server ID on the server and `nil` on the
client. Keep its existing `GetBlockReason` check, then add your own synchronous
condition before `return true`. Return `false` to cancel silently on the client;
server and NUI responses use `request_cancelled` when no error code is supplied.
An optional error code must have an entry in `DeviceErrors` in your locales.

The opening check runs for keybinds, exports, usable items and incoming calls. It
is repeated after asynchronous device preparation, when receiving the snapshot,
before NUI confirmation, and before replaying an open phone after a CEF reload.
It may run several times per opening: do not use `Wait`, asynchronous callbacks,
SQL, notifications or other side effects inside these functions.

Death and cuff checks also feed the existing active-session, call and radio
restrictions. A custom opening condition is an admission check; it is not polled
to close an already open phone. Existing ownership, inventory, session and rate
checks still run independently on the server. Client reports can only add a
restriction and cannot clear server death/cuff evidence.

The relocated native calls keep their existing contract: `IsEntityDead(Ped)` and
`IsPedCuffed(Ped)` run on the client; `GetEntityHealth(Ped)` runs on the server.
The client wrapper dispatch was checked against Cfx revision
`0d8a2a6f78a9922445d8930305af82a7b1826980` (`ScriptHost.cpp`, native dispatch),
and the official native declarations. GTA engine implementation is not public;
automated Lua tests do not replace an in-game test with OAL enabled.
