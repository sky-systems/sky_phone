# Phone notification audio

These are original, iPhone-inspired glass alerts, not recordings or copies of
Apple's Note, Tri-tone, or Rebound audio. No third-party audio is sampled.

| Preference ID | English name | German name | File | Duration |
| --- | --- | --- | --- | --- |
| `chime` | Glass | Glas | `glass.wav` | 1200 ms |
| `signal` | Triad | Dreiklang | `triad.wav` | 1400 ms |
| `soft` | Ripple | Impuls | `ripple.wav` | 1000 ms |

Render with `python assets/audio/generate_notifications.py` from the repository
root. Python's standard library produces deterministic mono, 44.1 kHz, 16-bit
PCM WAV files in `frontend/public/sounds/notifications/`. The frontend build
publishes those files with the NUI; playback requires no external service.

The sound uses lower-register struck keys, a rounded FM attack, quiet octave
body, filtered hammer noise and short early reflections. Each alert has its own
decay and brightness; peak levels stay below 0.25 to keep alerts restrained.
Existing saved preference IDs, app notification toggles and focus
mode remain compatible. Playback uses the phone's media volume controller.
