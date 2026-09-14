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
