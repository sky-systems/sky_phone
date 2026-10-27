"""Render original, iPhone-inspired glass alerts. No Apple audio is sampled.

Run with Python 3 from any directory; uses only the standard library.
"""

import math
from pathlib import Path
import random
import struct
import wave


SAMPLE_RATE = 44100
OUTPUT = Path(__file__).resolve().parents[2] / "frontend/public/sounds/notifications"
# Lower registers, contrasting rhythms and softer, resonant key strikes.
TONES = {
    "glass": (1200, [(0.0, 880.0, 1.0), (0.105, 1174.66, 0.74)]),
    "triad": (1400, [(0.0, 987.77, 0.84), (0.105, 1318.51, 0.7), (0.235, 1174.66, 1.0)]),
    "ripple": (1000, [(0.0, 698.46, 1.0), (0.12, 1046.50, 0.62)]),
}
PROFILES = {
    "glass": (0.24, 0.21, 0.8),
    "triad": (0.20, 0.16, 0.7),
    "ripple": (0.14, 0.09, 0.55),
}


def render(name, duration_ms, notes):
    samples = [0.0] * round(SAMPLE_RATE * duration_ms / 1000)
    decay, brightness, level = PROFILES[name]
    noise = random.Random(42)
    for onset, frequency, strength in notes:
        start = round(onset * SAMPLE_RATE)
        hammer = 0.0
        for index in range(start, len(samples)):
            time = (index - start) / SAMPLE_RATE
            attack = 1.0 - math.exp(-time / 0.0035)
            # A rounded struck-key fundamental with a brief, brighter attack.
            phase = 2 * math.pi * frequency * time
            value = math.exp(-time / decay) * math.sin(
                phase + 0.45 * math.exp(-time / 0.018) * math.sin(phase)
            )
            value += brightness * math.exp(-time / (decay * 0.55)) * math.sin(phase * 2.002)
            value += brightness * 0.25 * math.exp(-time / 0.045) * math.sin(phase * 3.99)
            # Quiet octave body and filtered hammer noise avoid a bare sine beep.
            value += 0.18 * math.exp(-time / (decay * 0.8)) * math.sin(phase * 0.5)
            hammer = 0.75 * hammer + 0.25 * noise.uniform(-1, 1)
            value += 0.045 * hammer * math.exp(-time / 0.008)
            samples[index] += value * attack * strength

    # Quiet early reflections add body without a long notification tail.
    dry = samples[:]
    for delay_ms, gain in [(17, 0.075), (31, 0.04), (53, 0.02)]:
        delay = round(SAMPLE_RATE * delay_ms / 1000)
        for index in range(delay, len(samples)):
            samples[index] += dry[index - delay] * gain

    peak = max(abs(value) for value in samples)
    # Match the restrained output of the previous notification tones.
    scale = 0.25 * level / peak
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
            output.writeframes(render(name, duration, notes))
        print(f"Rendered {name}: {duration} ms")
