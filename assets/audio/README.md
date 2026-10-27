# Phone notification audio

These alerts use third-party phone audio published under CC0. These are not official Apple-distributed
system files, and the recorded message sound is not labelled as Rebound.

| Preference ID | English name | German name | File | Duration |
| --- | --- | --- | --- | --- |
| `chime` | iPhone Message | iPhone-Nachricht | `glass.wav` | 1800 ms |
| `signal` | Classic | Klassisch | `triad.wav` | 1400 ms |
| `soft` | Muffled | Gedämpft | `ripple.wav` | 1400 ms |

Render with `python assets/audio/generate_notifications.py` from the repository
root. Python's standard library produces deterministic mono, 44.1 kHz, 16-bit
PCM WAV files from the included sources in `frontend/public/sounds/notifications/`. The frontend build
publishes those files with the NUI; playback requires no external service.

## Sources and processing

- **iPhone Text Sound**, ukjoncollins, Freesound sound 653820, published 2022-10-17:
  https://freesound.org/people/ukjoncollins/sounds/653820/
  The source describes an iPhone text/message recording without vibration and
  declares CC0. The included HQ MP3 is from
  https://cdn.freesound.org/previews/653/653820_200878-hq.mp3
  SHA-256: `1fba18903bc704a68c278461ed6105d4db3ee7d4eb4ea3443597e9cfd137f931`.
  The accompanying WAV is a mono 44.1 kHz PCM conversion decoded with Chromium.
  Normal and muffled alerts use this recording with the first 210 ms removed.
- **Message #1**, Joseph SARDIN / BigSoundBank, sound 1111:
  https://bigsoundbank.com/message-1-s1111.html
  The source describes a note matching an iPhone incoming-message alert and
  declares CC0. The included original PCM WAV is from
  https://bigsoundbank.com/UPLOAD/bwf-en/1111.wav
  SHA-256: `5293cb67e49dff613bd2166e9448d66d61b0786b4f8de9051b1091fd36b2f42e`.

The generator retains the source pitch, removes low-frequency recording rumble,
trims the notification length, sets a restrained peak level and fades the edges.
The muffled option applies a 2.2 kHz low-pass filter and lower volume to the
same iPhone recording. It is a processed variant, not a third recorded tone.

Full source license: `source/CC0-1.0.txt`, retrieved from
https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt

Existing preference IDs, app notification toggles and focus mode remain
compatible. Playback uses the phone's media volume controller.
