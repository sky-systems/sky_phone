# Phone voice controls

All controls execute in `sky_phone`. No script entry, patch or extension in `pma-voice` is required.

| Provider | Mute | Speaker |
| --- | --- | --- |
| PMA | Mumble voice target 0 and input distance 0, enforced while muted | Public `setPlayerCall` export adds nearby players to the call |
| SaltyChat | `GetPlayerAlive` / `SetPlayerAlive(false)` | `SetPhoneSpeaker` |
| Yaca | `muteOnPhone` | `enablePhoneSpeaker` |

PMA speaker guests within three metres and the same routing bucket can both hear and speak. Players with an existing/pending phone call or a different PMA call channel are excluded. Overlapping speakers pick the closest handset (channel ID breaks ties). Walking away, disabling speaker, ending a call, disconnecting or stopping the phone releases guest membership without taking players out of a different call.

PMA mute affects all outgoing microphone audio, including proximity and radio. Incoming playback and call membership remain enabled. Unmute restores PMA's normal voice target and the current talker proximity, including voice-range changes made while muted.

SaltyChat mute uses its general alive voice state, so proximity/radio speech is also affected. Call membership remains intact. The previous state is remembered and restored on unmute/hangup/resource stop; a dead/downed player is never marked alive by the phone. Standard replicated death flags (`isDead`, `dead`, `isdead`, `inlaststand`) and server ped health are respected. A custom death resource that only writes SaltyChat's already-false state must also publish a death flag, otherwise a second false write cannot be distinguished from the phone's own mute.

Lua tests cover call membership, range/buckets, overlapping speakers, mute and state restoration. Browser tests cover supported controls and their active colors. Actual audio, including SaltyChat/TeamSpeak behavior while dead and PMA radio transmission, still needs multiplayer FiveM testing.


## Player restrictions and radio item requirement

The shared, editable checks live in `config/functions.lua`. See
[Player checks and opening cancellation](PLAYER_CHECKS.md) to customize death,
handcuffs or cancel phone opening with `PhoneFunctions.CanOpenPhone`.

All three switches default to `true` in `config/config.lua` and `/phonepanel`:

| Setting | Effect |
| --- | --- |
| `Phone.BlockWhenDead` | Blocks phone use during death, unconsciousness and laststand; ends ringing/active calls, video calls, livestreams and both radio frequencies. |
| `Phone.BlockWhenCuffed` | Applies the same restrictions while handcuffed. |
| `Radio.RequirePhoneItem` | Requires `Phone.Item` at manual/automatic radio join. Losing the last phone disconnects both frequencies, including background radio. |

Generic death and restraint flags are normalized by the phone. General `invBusy`, `inv_busy` and `busy` flags do not indicate death or cuffs. Other Sky resources are not queried.

QBCore and Qbox read `isdead`, `inlaststand` and `ishandcuffed` from player metadata using their player APIs. ESX reads its player data/death events and replicated state. Legacy `esx_policejob` sets the ped handcuff flag: `IsPedCuffed` handles cuff/uncuff, automatic cuff expiry and resource restarts without guessing a toggle event. Legacy ESX statuses without a server API are reported only for the sending player; a client clear cannot override server metadata, replicated state or server ped health. This compatibility fallback is not an anti-cheat authority.

Status changes close the UI and release call/camera focus locally. Server checks reject new operations and remove existing sessions, calls and radio membership. PMA speaker guests who are dead/cuffed are excluded. SaltyChat mute restoration also reads medical state independently of the restriction switches; `SaltyChat_IsAlive = false` alone is never considered death.

Radio membership is cleared using PMA `setPlayerRadio(source, 0)`, SaltyChat `SetPlayerRadioChannel(source, "", true/false)` and Yaca `setPlayerRadioChannel(source, 1/2, "0")`. The client also clears provider channels, HUD, speaker state and pending joins. Forced disconnect clears the saved auto-rejoin frequencies; revival does not automatically resume a call or radio session.

Inventory is checked through the existing inventory adapter for the configured phone item, with no database or device/IMEI lookup. Only radio joins and connected radio users are checked; the background interval is one second. Disabling `Radio.RequirePhoneItem` skips these inventory checks. State polling uses 250 ms locally, 500 ms for open phone sessions and the existing one-second call/live checks. Configuration changes apply immediately through Phonepanel and persist in SQL; no database migration is needed.

Run `tests/player_restrictions.lua`, `tests/server_calls_ring_all.lua`, `tests/client_radio_restrictions.lua` and `tests/phone_configurator.lua` with Lua 5.4 from the repository root. The tests cover transitions, missing items, delayed joins, provider cleanup and SQL configuration roundtrips. Verify actual audio and job transitions with two players in FiveM before deployment.
