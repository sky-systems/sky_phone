# Cell towers and Phonepanel moderation

## Configuration

Manage **Phonepanel → Phone Configurator → Cell towers**. File mode uses
`Config.CellTowers` in `sky_phone/config/config.lua`; SQL mode stores the same
settings in the existing configurator row. New defaults are added automatically.
No database migration is needed.

- `Enabled = true` enables coverage. Set it to `false` for full service everywhere.
- `Towers` contains 18 virtual mast positions as `vector3` (the `vec3` type):
  eight in Los Santos, six along the mainland towns/coast, and four on Cayo Perico.
  Each entry has `Coords` and `Range` in metres; add, edit or remove entries in-game.
- Coverage uses horizontal distance and the strongest overlapping mast. The
  status bar shows 1–4 bars inside coverage and zero outside. Z is retained for
  the position but does not reduce the coverage radius.
- An enabled network with no masts has **no coverage**. It never silently falls
  back to full reception.
- `OfflineApps` is the default app policy. True permits the app without reception;
  false and unlisted apps require reception. `OnlineActions` names callback
  actions that require reception even inside an offline app.

## Default availability

| Without reception | Apps/functions                                                                                                                                                                                                |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Available         | Phone book, favourites and call history; stored message threads; camera and gallery; voice memos; notes; calendar/reminders; calculator; clock; map/GPS and personal markers; health; settings; bundled games |
| Available         | Radio uses its own radio provider. EasyShare is a nearby transfer. Payphones are landlines; their mobile recipients still need reception.                                                                     |
| Available         | Music library, playlists and bundled server tracks                                                                                                                                                            |
| Blocked           | Starting/answering mobile calls, video calls, sending messages/media, GIF searches, live broadcasts                                                                                                           |
| Blocked           | Feather, FlipTok, Picstagram, SkyPic, Weazel News, Mail, DarkChat, Flare, CrewLink                                                                                                                            |
| Blocked           | Banking, Billing, Crypto, CityMarkt, Local Pages, Companies/service requests, SkyRide, Garage/valet, Housing, Weather, CityWarn, App Store                                                                    |
| Blocked           | Cloud account sign-in/registration/device management, media imports and YouTube streaming/additions                                                                                                           |
| Always available  | Closing/unlocking the phone, ending/declining calls, ending streams, radio disconnect, cancelling valet, SIM and device controls, Phonepanel                                                                  |

These are gameplay rules: server persistence and media storage still support
the offline camera/gallery/memos. They do not simulate disconnecting the player's
real network connection. The Wi-Fi display preference does not bypass coverage.
Offline message threads expose the stored conversation; there is no separate
delivery queue or offline snapshot cache.

The server calculates coverage from its OneSync player ped position before
dispatching online callbacks. It checks the receiving mobile phone before
ringing and rechecks active calls/streams in their existing one-second workers.
Leaving coverage ends mobile calls; there is no grace period. Live broadcasts,
including their nearby audio participants, require reception.

## Social moderation

**Phonepanel → Social media** searches published Feather, FlipTok, Picstagram and
Weazel News posts by text/title, author or post ID. Results are paginated in
groups of 50. Confirm a selected post to remove it.

Every list/delete request checks the existing `phonepanel` permission and rate
limit on the server. Social posts use their existing `removed` status; Weazel
articles use `deleted_at`, the administrator's identifier and an incremented
revision. Removals appear in the existing admin audit. Accounts, original media
files and unrelated posts are retained. Existing open feeds refresh through their
normal reload flow.

## Reference and native verification

Design reference: [SD Phone cell towers](https://github.com/Samuels-Development/sd-phone/blob/9a5eb6d4748f7f60360dd5e1367712d70cd36d08/configs/celltowers.lua)
and its shared coverage module at revision
`9a5eb6d4748f7f60360dd5e1367712d70cd36d08`. The reference informed the strongest-mast,
horizontal-distance and offline-action approach; Sky Phone owns its configuration,
code and Cayo coverage.

Inspected official Cfx source revision:
`0d8a2a6f78a9922445d8930305af82a7b1826980`.
The deployed client/server artifact revision was not available.

- [GET_PLAYER_PED declaration](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/ext/native-decls/GetPlayerPed.md):
  server player source string → entity handle; zero when the player has no ped.
  Registration: `code/components/citizen-server-impl/src/PlayerScriptFunctions.cpp`,
  `GET_PLAYER_PED` / `MakeClientFunction`, reads the client's `playerEntity`.
- [GET_ENTITY_COORDS declaration](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/ext/native-decls/GetEntityCoords.md):
  server entity handle → vector, requires OneSync.
  `code/components/citizen-server-impl/src/state/ServerGameState_Scripting.cpp`,
  `GET_ENTITY_COORDS` / `makeEntityFunction`, reads the entity sync tree position
  into `scrVector`; no client RPC and no output pointer argument.
- Client `PLAYER_PED_ID` and `GET_ENTITY_COORDS` use the official GTA native
  metadata and `ext/natives/codegen_out_native_lua.lua` generated wrapper path.
  `code/components/citizen-scripting-lua/src/LuaScriptRuntime.cpp` provides the
  native invocation/vector-result conversion. GTA engine implementations are
  proprietary; only the Cfx binding boundary is inspectable.
- `data/shared/citizen/scripting/lua/scheduler.lua` registers the thread/event
  helpers and NUI JSON bridge. Coverage display runs at one-second intervals;
  active-call enforcement reuses the existing one-second worker. No new
  per-frame native loop was added.

Automated Lua tests cover coverage boundaries, overlap, ocean/Cayo samples,
master bypass, spoofed client coordinates, incoming and active calls, landlines,
configuration save/load and moderation authorization. Frontend/browser tests
cover reception UI, recovery and deletion confirmation.

Live FiveM/OAL validation remains required: walk/drive across mast boundaries,
test incoming/outgoing and company calls with two players, lose reception during
an audio/video call and broadcast, then toggle the master switch through
Phonepanel. Check mainland and Cayo coordinates in the deployed map. No live
runtime performance measurements are claimed.
