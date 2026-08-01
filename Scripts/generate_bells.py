#!/usr/bin/env python3
"""Generate Zazen's synthetic meditation bells using modal synthesis.

The three pitch classes form a wide Western B-flat major voicing for aesthetic
variety; that tuning is not presented as a traditional Buddhist or Himalayan
pitch set.
Each bowl uses a slightly different inharmonic modal profile, a soft felt-mallet
excitation, and the same 20-second duration with a seven-second final fade.

This script uses only Python's standard library:

    python3 Scripts/generate_bells.py
"""

from __future__ import annotations

import argparse
import math
import sys
import wave
from array import array
from dataclasses import dataclass
from pathlib import Path


SAMPLE_RATE = 48_000
DURATION_SECONDS = 20.0
FADE_START_SECONDS = 13.0
ONSET_FADE_SECONDS = 0.08
CHANNELS = 2
TARGET_PEAK_DBFS = -8.0


@dataclass(frozen=True)
class Bowl:
    filename: str
    note: str
    fundamental_hz: float
    base_decay: float
    mode_ratios: tuple[float, ...]


# Modal ratios are based on measured bowl spectra, then used as resonances above
# the chosen fundamental. They are intentionally inharmonic: a metal bowl does
# not behave like a string or an equal-tempered synthesizer.
BOWLS = (
    Bowl(
        filename="synthetic-bell-low.wav",
        note="Bb2",
        fundamental_hz=116.54,
        base_decay=0.075,
        mode_ratios=(1.0, 2.657, 4.697, 7.444, 9.808, 14.2),
    ),
    Bowl(
        filename="synthetic-bell-middle.wav",
        note="D4",
        fundamental_hz=293.66,
        base_decay=0.095,
        mode_ratios=(1.0, 2.753, 5.091, 7.822, 11.484, 16.0),
    ),
    Bowl(
        filename="synthetic-bell-high.wav",
        note="F5",
        fundamental_hz=698.46,
        base_decay=0.110,
        mode_ratios=(1.0, 2.548, 4.783, 7.464, 10.462, 14.5),
    ),
)

MODE_AMPLITUDES = (1.0, 0.40, 0.19, 0.08, 0.035, 0.015)
DECAY_MULTIPLIERS = (1.0, 1.55, 2.35, 3.4, 5.0, 7.0)
RIGHT_CHANNEL_DETUNE = (1.0026, 0.9989, 1.0014, 0.9986, 1.0018, 0.9981)
LEFT_PHASES = (0.0, 0.32, 1.08, 0.61, 1.73, 2.21)
RIGHT_PHASES = (0.18, 0.71, 0.24, 1.39, 0.88, 2.63)


def fade_envelope(time: float) -> float:
    if time <= FADE_START_SECONDS:
        return 1.0
    fade_progress = min(
        (time - FADE_START_SECONDS) / (DURATION_SECONDS - FADE_START_SECONDS),
        1.0,
    )
    return math.cos(fade_progress * math.pi / 2.0)


def onset_envelope(time: float) -> float:
    """Raised-cosine fade with zero value and slope at the first sample."""
    progress = min(time / ONSET_FADE_SECONDS, 1.0)
    return math.sin(progress * math.pi / 2.0) ** 2


def synthesize_channel(bowl: Bowl, time: float, right_channel: bool) -> float:
    # A felt mallet transfers energy over a longer contact time than a hard
    # wooden striker. The slower attack plus strongly attenuated upper modes
    # removes the metallic click while preserving a definite, weighty onset.
    mallet_attack = 1.0 - math.exp(-42.0 * time)
    phases = RIGHT_PHASES if right_channel else LEFT_PHASES

    resonance = 0.0
    for index, (ratio, amplitude, decay_multiplier, phase) in enumerate(
        zip(bowl.mode_ratios, MODE_AMPLITUDES, DECAY_MULTIPLIERS, phases)
    ):
        detune = RIGHT_CHANNEL_DETUNE[index] if right_channel else 1.0
        frequency = bowl.fundamental_hz * ratio * detune
        decay = math.exp(-bowl.base_decay * decay_multiplier * time)
        resonance += amplitude * math.sin(2.0 * math.pi * frequency * time + phase) * decay

    # A short low-frequency contact pulse suggests the body of a firm mallet
    # without reintroducing the sharp high-frequency transient.
    contact_frequency = bowl.fundamental_hz * (0.55 if not right_channel else 0.548)
    contact = (
        0.025
        * math.sin(2.0 * math.pi * contact_frequency * time + 0.2)
        * math.exp(-18.0 * time)
        * (1.0 - math.exp(-70.0 * time))
    )

    return (
        (0.22 * mallet_attack * resonance + contact)
        * onset_envelope(time)
        * fade_envelope(time)
    )


def render_bowl(bowl: Bowl, output_path: Path) -> None:
    frame_count = round(SAMPLE_RATE * DURATION_SECONDS)
    samples = array("f")

    for frame in range(frame_count):
        time = frame / SAMPLE_RATE
        samples.append(synthesize_channel(bowl, time, right_channel=False))
        samples.append(synthesize_channel(bowl, time, right_channel=True))

    peak = max(abs(sample) for sample in samples)
    target_peak = 10.0 ** (TARGET_PEAK_DBFS / 20.0)
    normalization = target_peak / peak if peak > 0 else 1.0

    pcm = array(
        "h",
        (
            max(-32_768, min(32_767, round(sample * normalization * 32_767)))
            for sample in samples
        ),
    )
    if sys.byteorder != "little":
        pcm.byteswap()

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(output_path), "wb") as wav_file:
        wav_file.setnchannels(CHANNELS)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        wav_file.writeframes(pcm.tobytes())

    print(f"{bowl.note:>3} -> {output_path} ({DURATION_SECONDS:.0f}s)")


def main() -> None:
    default_output = Path(__file__).resolve().parents[1] / "Zazen" / "Sounds"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=default_output,
        help=f"Output directory (default: {default_output})",
    )
    args = parser.parse_args()

    for bowl in BOWLS:
        render_bowl(bowl, args.output_dir / bowl.filename)


if __name__ == "__main__":
    main()
