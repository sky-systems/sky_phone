# Video calls, livestreams and EasyShare

## Player controls

- **Phone:** the existing contact video icon starts a video call. FaceTime in a connected audio call requests video; the other party accepts or declines. Stopping video preserves the native voice call.
- **Picstagram:** **+ → Go live**, next to New Post and New Story. Enter a title and optional description, then Go live.
- **FlipTok:** **+ / Create → Go live**. Enter a caption, then Go live.
- **Watch:** the feed's LIVE button lists broadcasts. Both perspectives show the viewer count and livechat. Broadcasters get camera switching, own-microphone mute and End live; viewers get Leave.

The screens use Sky UI and the phone theme. Closing the broadcast or phone ends the foreground video session. Titles allow 120 characters, descriptions/captions 1000 and chat messages 300. Names and viewer counts come from the server. Chat is rate-limited to 20 messages/minute; the last 50 comments remain in the active room. There is no recording or replay.

## Default: P2P, no Cloudflare

`Realtime.Transport = "p2p"` and `TurnEnabled = false` are the defaults. No Cloudflare account or credentials are required. Default ICE discovery uses Google's public STUN server. P2P uploads a copy per viewer: 10 viewers at 1200 kbit/s need roughly 12 Mbit/s video upload, plus audio and overhead. Set an appropriate viewer cap.

Cloudflare is optional for connection problems, larger audiences or operator preference:

| Transport        | TURN  | Credentials               |
| ---------------- | ----- | ------------------------- |
| p2p (default)    | false | None                      |
| p2p              | true  | TURN Token ID + API Token |
| cloudflare (SFU) | false | SFU App ID + App Secret   |
| cloudflare       | true  | Both credential pairs     |

SFU uploads the stream once and distributes it to viewers. `ForceRelay` requires TURN and applies only to P2P. Signalling, access checks, chat and counts remain on the FiveM server. Configuration changes terminate active video sessions.

## Configuration and secrets

All Realtime options and RealtimeSecrets fields are available in **/phonepanel**, including localized help, bounds, SQL persistence and credential masking. Secrets are excluded from client configuration.

Create an SFU application at **Cloudflare dashboard → Realtime → SFU** and copy **App ID / App Secret**. Create a TURN key at **Realtime → TURN** and copy **Token ID / API Token**. These are separate credential pairs. See the official [SFU API](https://developers.cloudflare.com/realtime/sfu/https-api/) and [TURN credentials guide](https://developers.cloudflare.com/realtime/turn/generate-credentials/).

In SQL mode, enter credentials in /phonepanel. In file mode, edit feature options in `sky_phone/config/config.lua` but keep its credential placeholders empty. FiveM clients download config.lua, including blocks that execute only on the server. Set credentials through **non-replicated server.cfg convars** before starting the resource:

```cfg
set sky_phone_cf_sfu_app_id "<SFU App ID>"
set sky_phone_cf_sfu_app_secret "<SFU App Secret>"
set sky_phone_cf_turn_key_id "<TURN Token ID>"
set sky_phone_cf_turn_api_token "<TURN API Token>"
ensure sky_phone
```

Use `set`, never `setr` or `sets`. SQL mode uses panel values instead of these convars. Clients receive only expiring TURN credentials and their permitted SFU session/track information. The server uses fixed Cloudflare API paths. No new database schema is needed.

## SaltyChat / YACA voices

The official [SaltyChat source](https://github.com/SaltyHub-net/saltychat-fivem) and [YACA source](https://github.com/yaca-systems/fivem-yaca-typescript) expose state and range, not raw TeamSpeak PCM. Capturing one browser microphone does not capture other TeamSpeak users.

Each contributor therefore captures their own NUI microphone with getUserMedia. Official provider state gates transmission:

- SaltyChat: GetVoiceRange and talk/mute/enabled events. Enable **RequestTalkStates** in SaltyChat's own configuration.
- YACA: isPlayerTalking, isEnabled, getMicrophoneMuteState, getMicrophoneDisabledState and getVoiceRange on yaca-voice.
- PMA: Mumble talking/proximity state.

Use the existing Calls.VoiceProvider setting. Unavailable provider state mutes capture. Each client needs browser microphone permission and the intended default input device; TeamSpeak's selected device and voice effects are not automatically reproduced.

With NearbyAudio enabled, the server checks voice range, configured distance and routing bucket. Nearby clients send audio to the broadcaster, whose Web Audio mixer applies distance attenuation and includes it in the stream. Contributors receive no broadcast audio. Nearby viewers of that room are excluded from the contributor role to avoid feedback. A client can contribute to at most two nearby broadcasts and sees a participation indicator. Range exit, mute, disconnect and teardown stop transmission. Host mute affects the host's own microphone.

Phone WebRTC calls carry **video only**; call audio remains with SaltyChat/YACA/PMA to avoid duplicated voices.

## EasyShare

Contacts open by canonical phone number; Open is localized. Completed transfers cannot regress to waiting after stale bootstrap responses. Reopening the same target triggers a fresh app launch.

Received notes/text/documents, markers and media point to the recipient's copy; all album items are imported. YouTube songs and playlists copy into the recipient library with remapped song IDs and music limits enforced. Chat shares can display text/media/profile snapshots and play music snapshots without access to the sender's private database records. Social posts/profiles, companies, app-store pages, listings and group invitations retain their destination access checks.

## Preview and verification

Development URLs use `?apiPort=3016&realtimePreview=call`, or `realtimePreview=picstagram` / `fliptok` with `liveView=entry`, `host` or `viewer`. The external selector switches app and perspective. These are production views with simulated camera pictures and participants.

Automated checks cover frontend typecheck/lint/tests/build, Lua syntax, call lifecycle, Realtime authorization/topology/chat/counts/proximity, provider microphone gating, Cloudflare API paths/errors/credentials, EasyShare receive/history/music ownership, and Configurator persistence/masking. New Lua tests run in Repository policy CI. An isolated Edge test exercised real RTCPeerConnection video in both call directions, host audio/video to viewer, and nearby audio to host.

**Still requires real FiveM clients:** native game camera capture, SaltyChat/YACA microphone permissions and device selection, range/mute/routing-bucket behavior, private profiles and blocks, disconnect cleanup, P2P across different networks, forced TURN and SFU with actual operator credentials. Test all enabled EasyShare sources/destinations, acceptance/decline/history, same-app Open and saved recipient targets. Browser previews and mocked API tests do not prove the live FiveM or Cloudflare runtime.
