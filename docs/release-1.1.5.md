# Sky Phone 1.1.5

## Changes

- Fix Yaca calls being rejected with "configured voice service is unavailable" when its enabled export returns numeric `1` instead of boolean `true`. Disabled and invalid provider states still block calls.
- Preserve compatibility with Yaca releases before `isEnabled` existed, and adapt older radio selectors and realtime speaking/mute APIs. Calls, speaker and mute keep using Yaca's stable server exports.
- Fix radio volume with Yaca 3.3.0's reversed export arguments. Reconnecting older Yaca no longer invokes toggle-only channel mute exports.
- Record the API changes across all 53 official tags from 1.0.0 through 3.6.0 in the [Yaca compatibility audit](https://github.com/sky-systems/sky_phone/blob/1.1.5/docs/yaca-voice-compatibility.md). This is source/API coverage; live multiplayer Yaca/TeamSpeak acceptance remains pending.

## Update instructions

These steps cover upgrading from 1.1.4. For older installations, also apply the intervening release instructions.

1. Back up the installed resource, retained configuration and custom files under `source/`, including `source/html/sounds`.
2. Replace `fxmanifest.lua`, `SOURCE.txt`, `README.md`, `integrations/README.md` and the complete `source/` directory from the 1.1.5 release ZIP, then restore your custom files. The new shared `source/bridge/yaca.lua` must be installed together with the manifest that loads it. Preserve existing configuration and locale overrides.
3. Keep the intended voice resource running before Phone. Yaca requires its normal `yaca-voice` resource name; choose `yaca`, `yaca-voice` or `auto` through your existing Phone configuration/Configurator. No Yaca patch or forced Yaca upgrade is needed for this change.
4. Run `refresh`, then `restart sky_phone` in the server console so FiveM reloads the manifest. Restart resources that register external Phone apps afterward, or use a full server restart in the normal startup order.
5. With two players on a Yaca test server, accept and end a mobile/payphone call, check mute and speaker audio, reconnect both radio frequencies and move the volume slider. If using realtime microphone capture, check speaking, microphone mute/disable and Phone/provider restarts before updating players.

No configuration, Configurator, SQL, item, locale, custom asset or mandatory dependency migration is required. Dedicated secondary radio transmission still depends on Yaca's own 3.x selector support; earlier releases retain primary transmission and raw secondary reception.

## Changed shipped files

- `fxmanifest.lua` — version 1.1.5 and the shared Yaca bridge entry.
- `SOURCE.txt` — release source-commit reference.
- `README.md` and `integrations/README.md` — voice compatibility documentation.
- `source/bridge/yaca.lua` — new shared provider compatibility bridge.
- `source/bridge/server/voice.lua`, `source/bridge/client/radio.lua`, `source/client/realtime.lua` — adapter changes.
- `source/html/` — rebuilt NUI entry points and generated assets; install the complete `source/` directory as above.

There are no shipped removals or renames outside generated `source/html/` assets. Configuration, locales, SQL, LICENSE and THIRD_PARTY_NOTICES keep their contents. Repository tests and audit sources are not included in the deployable resource folder.
