"""Generate original, reusable dual-tone horn WAV assets (no dependencies).
Run: python tools/generate_horns.py
"""
import math
import random
import struct
import wave
from pathlib import Path

OUTPUT = Path(__file__).resolve().parents[1] / 'assets/audio/horns'
RATE = 22050


def write_horn(name, frequencies, duration, seed):
    rng = random.Random(seed)
    phases = [rng.random() * math.tau for _ in frequencies]
    samples = bytearray()
    for index in range(round(duration * RATE)):
        t = index / RATE
        attack = min(1.0, t / 0.018)
        release = min(1.0, (duration - t) / 0.08)
        envelope = math.sin(attack * math.pi / 2) * math.sin(release * math.pi / 2)
        value = 0.0
        for frequency, phase in zip(frequencies, phases):
            angle = math.tau * frequency * t + phase + 0.01 * math.sin(math.tau * 7 * t)
            value += math.sin(angle) + 0.34 * math.sin(2 * angle) + 0.19 * math.sin(3 * angle) + 0.08 * math.sin(5 * angle)
        value /= len(frequencies) * 1.61
        value *= envelope * (0.96 + 0.04 * math.sin(math.tau * 19 * t))
        samples.extend(struct.pack('<h', round(max(-1.0, min(1.0, value)) * 24575)))
    with wave.open(str(OUTPUT / f'{name}.wav'), 'wb') as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(samples)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for index, (name, tones) in enumerate([('compact', (440, 554)), ('sedan', (350, 440)), ('van', (260, 330))]):
        write_horn(name + '_short', tones, 0.38 + index * 0.04, index)
        write_horn(name + '_held', tones, 2.8 + index * 0.2, index)
    print('Generated six original mono horn WAVs (three voices, short and held)')


if __name__ == '__main__':
    main()
