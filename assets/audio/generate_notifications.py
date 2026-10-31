"""Prepare phone alerts from the attributed recordings in source/ (stdlib only)."""

import math
from pathlib import Path
import struct
import wave

ROOT = Path(__file__).resolve().parent
SAMPLE_RATE = 44100
OUTPUT = ROOT.parents[1] / "frontend/public/sounds/notifications"
TONES = {
    "glass": ("iphone-text-653820.wav", 0.21, 1800, 0.27, 12000),
    "triad": ("message-1111.wav", 0, 1400, 0.24, 12000),
    "ripple": ("iphone-text-653820.wav", 0.21, 1400, 0.16, 2200),
}


def prepare(source, offset, duration_ms, peak_level, lowpass_hz):
    with wave.open(str(ROOT / "source" / source)) as recording:
        assert recording.getsampwidth() == 2 and recording.getnchannels() == 1
        rate = recording.getframerate()
        raw = recording.readframes(recording.getnframes())
        samples = struct.unpack("<" + "h" * (len(raw) // 2), raw)

    output = []
    previous_input = 0.0
    highpass = lowpass = 0.0
    highpass_alpha = math.exp(-2 * math.pi * 160 / SAMPLE_RATE)
    lowpass_alpha = 1 - math.exp(-2 * math.pi * lowpass_hz / SAMPLE_RATE)
    count = round(SAMPLE_RATE * duration_ms / 1000)
    for index in range(count):
        position = (offset + index / SAMPLE_RATE) * rate
        left = int(position)
        fraction = position - left
        value = (samples[left] * (1 - fraction) + samples[left + 1] * fraction) / 32768
        # Remove recording rumble; retain recorded pitch and speaker timbre.
        highpass = highpass_alpha * (highpass + value - previous_input)
        previous_input = value
        lowpass += lowpass_alpha * (highpass - lowpass)
        output.append(lowpass)

    scale = peak_level / max(abs(value) for value in output)
    attack = round(SAMPLE_RATE * 0.004)
    release = round(SAMPLE_RATE * 0.22)
    return b"".join(
        struct.pack("<h", round(value * scale * min(1, index / attack) *
                               min(1, (count - index - 1) / release) * 32767))
        for index, value in enumerate(output)
    )


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, (source, offset, duration, level, cutoff) in TONES.items():
        with wave.open(str(OUTPUT / f"{name}.wav"), "wb") as output:
            output.setparams((1, 2, SAMPLE_RATE, 0, "NONE", "not compressed"))
            output.writeframes(prepare(source, offset, duration, level, cutoff))
        print(f"Prepared {name}: {duration} ms from {source}")
