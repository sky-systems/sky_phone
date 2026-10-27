"""Render original, iPhone-inspired glass alerts. No Apple audio is sampled.

Run with Python 3 from any directory; uses only the standard library.
"""

import math
from pathlib import Path
import struct
import wave


SAMPLE_RATE = 44100
OUTPUT = Path(__file__).resolve().parents[2] / "frontend/public/sounds/notifications"
# Distinct original melodies with a struck-glass attack and a short resonant tail.
TONES = {
    "glass": (1200, [(0.0, 1318.51, 0.9), (0.115, 1760.0, 0.62)]),
    "triad": (1400, [(0.0, 1046.50, 0.85), (0.13, 1318.51, 0.8), (0.29, 1567.98, 1.0)]),
    "ripple": (1000, [(0.0, 1396.91, 0.75), (0.085, 1174.66, 0.6), (0.18, 1760.0, 0.46)]),
}
PARTIALS = [(1.0, 1.0, 0.19), (2.756, 0.22, 0.085), (5.404, 0.065, 0.042)]


def render(duration_ms, notes):
    samples = [0.0] * round(SAMPLE_RATE * duration_ms / 1000)
    for onset, frequency, strength in notes:
        start = round(onset * SAMPLE_RATE)
        for index in range(start, len(samples)):
            time = (index - start) / SAMPLE_RATE
            attack = 1.0 - math.exp(-time / 0.0015)
            value = sum(
                gain * math.exp(-time / decay) * math.sin(2 * math.pi * frequency * ratio * time)
                for ratio, gain, decay in PARTIALS
            )
            samples[index] += value * attack * strength

    # Quiet early reflections add body without a long notification tail.
    dry = samples[:]
    for delay_ms, gain in [(23, 0.12), (47, 0.065), (79, 0.025)]:
        delay = round(SAMPLE_RATE * delay_ms / 1000)
        for index in range(delay, len(samples)):
            samples[index] += dry[index - delay] * gain

    peak = max(abs(value) for value in samples)
    # Match the restrained output of the previous notification tones.
    scale = 0.25 / peak
    fade_samples = round(SAMPLE_RATE * 0.025)
    return b"".join(
        struct.pack("<h", round(value * scale * min(1, (len(samples) - index - 1) / fade_samples) * 32767))
        for index, value in enumerate(samples)
    )


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, (duration, notes) in TONES.items():
        target = OUTPUT / f"{name}.wav"
        with wave.open(str(target), "wb") as output:
            output.setparams((1, 2, SAMPLE_RATE, 0, "NONE", "not compressed"))
            output.writeframes(render(duration, notes))
        print(f"Rendered {name}: {duration} ms")
