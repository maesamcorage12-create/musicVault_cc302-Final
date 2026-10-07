"""Generates the 30 placeholder MP3 tracks used by VibeVault.

The capstone project ships with a fixed 30 song catalog, so the repository needs
30 real, playable audio files.  Rather than commit copyrighted music, this tool
synthesises 30 short instrumental loops (one per catalog entry) and encodes them
to MP3 with ffmpeg.

Every generated loop is deterministic: the same catalog id always produces the
same audio, so regenerating the assets never produces spurious diffs.

Usage
-----
    python tool/generate_audio.py --ffmpeg <path-to-ffmpeg.exe>

Requires: numpy, and an ffmpeg binary able to encode libmp3lame.
"""

from __future__ import annotations

import argparse
import math
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import wave
from dataclasses import dataclass

import numpy as np

SAMPLE_RATE = 44_100
TARGET_SECONDS = 26.0
BITRATE = "96k"

# Note helpers ---------------------------------------------------------------

_NOTE_OFFSETS = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
                 "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}

_FLAT_OFFSETS = {"Db": 1, "Eb": 3, "Gb": 6, "Ab": 8, "Bb": 10}


def note_hz(name: str) -> float:
    """'A2' -> 110.0 Hz, 'Bb1' -> 58.27 Hz"""
    if len(name) > 2 and name[1] == "b":
        letter, octave = name[:2], int(name[2])
        semitone = _FLAT_OFFSETS[letter] + (octave - 4) * 12
    else:
        letter, octave = name[:-1], int(name[-1])
        semitone = _NOTE_OFFSETS[letter] + (octave - 4) * 12
    return 440.0 * (2.0 ** (semitone / 12.0))


def chord_hz(root: str, semitones: list[int]) -> list[float]:
    base = note_hz(root)
    return [base * (2.0 ** (s / 12.0)) for s in semitones]


# Styles ---------------------------------------------------------------------

@dataclass(frozen=True)
class Style:
    drums: bool          # kick / snare / hat layer
    arp_div: int         # how many subdivisions per beat the arp uses
    pad_detune: float    # chorus depth in semitones
    brightness: float    # relative weight of the bright arp layer
    swing: float         # fraction of a beat to delay off-beats


CHILL = Style(drums=False, arp_div=2, pad_detune=0.08, brightness=0.45, swing=0.16)
LOFI = Style(drums=True, arp_div=2, pad_detune=0.14, brightness=0.30, swing=0.22)
POP = Style(drums=True, arp_div=4, pad_detune=0.10, brightness=0.85, swing=0.0)
ELECTRONIC = Style(drums=True, arp_div=4, pad_detune=0.12, brightness=1.0, swing=0.0)

# (root, progression in semitones from the root, style)
# Progressions are simple triads/sevenths that keep the loops consonant.
RECIPES: list[tuple[str, list[list[int]], Style]] = [
    ("F#2", [[0, 4, 7, 11], [-3, 0, 4, 7], [-5, -1, 2, 7], [-7, -3, 0, 4]], CHILL),
    ("D2", [[0, 4, 7], [5, 9, 12], [-3, 0, 4], [-5, -1, 2]], POP),
    ("A1", [[0, 3, 7, 10], [-2, 1, 5, 8], [-4, 0, 3, 7], [-5, -1, 2, 5]], LOFI),
    ("E2", [[0, 4, 7], [0, 4, 7], [-2, 2, 5], [-5, -1, 2]], ELECTRONIC),
    ("B1", [[0, 4, 7, 9], [-3, 0, 4, 7], [2, 5, 9], [-1, 2, 7]], POP),
    ("C2", [[0, 4, 7], [-4, 0, 3], [-5, -1, 2], [-7, -3, 0]], CHILL),
    ("G1", [[0, 4, 7, 11], [-4, 0, 3, 7], [-2, 2, 5, 9], [-5, -1, 2, 6]], ELECTRONIC),
    ("E2", [[0, 3, 7, 10], [-3, 0, 5, 8], [-5, 0, 4, 7], [-7, -2, 2, 5]], LOFI),
    ("A1", [[0, 4, 7], [3, 7, 10], [-2, 2, 5], [-4, 0, 3]], POP),
    ("D2", [[0, 7, 12, 16], [-5, 0, 7, 12], [-3, 2, 7, 11], [-7, -2, 3, 7]], ELECTRONIC),
    ("F#1", [[0, 4, 7, 11], [-4, 0, 3, 8], [-5, -1, 2, 7], [-7, -3, 0, 5]], CHILL),
    ("C2", [[0, 3, 7], [-2, 1, 5], [-5, -1, 2], [-7, -3, 0]], LOFI),
    ("G2", [[0, 4, 7], [7, 11, 14], [5, 9, 12], [-3, 0, 4]], POP),
    ("Bb1", [[0, 4, 7], [-2, 2, 7], [-4, 0, 5], [-7, -3, 2]], ELECTRONIC),
    ("D2", [[0, 4, 7, 9], [-3, 0, 4, 9], [-5, -1, 2, 7], [-7, -3, 0, 4]], POP),
    ("A1", [[0, 3, 7, 10], [-5, -1, 2, 7], [-3, 0, 4, 7], [-7, -4, 0, 3]], LOFI),
    ("E1", [[0, 4, 7], [0, 5, 9], [-2, 2, 5], [-3, 0, 4]], ELECTRONIC),
    ("Bb2", [[0, 4, 7, 11], [-5, -1, 2, 7], [-3, 0, 3, 7], [-7, -3, 0, 4]], CHILL),
    ("C2", [[0, 4, 7], [2, 5, 9], [-3, 0, 4], [-5, -1, 2]], POP),
    ("G1", [[0, 3, 7, 14], [-5, 0, 3, 10], [-7, -2, 2, 9], [-3, 0, 5, 12]], CHILL),
    ("A1", [[0, 4, 7], [0, 4, 9], [-2, 2, 7], [-4, 0, 5]], ELECTRONIC),
    ("D2", [[0, 3, 7, 10], [-2, 1, 5, 8], [-4, 0, 3, 7], [-7, -3, 0, 4]], LOFI),
    ("F2", [[0, 4, 7], [5, 9, 12], [-3, 0, 4], [-1, 2, 7]], POP),
    ("Eb2", [[0, 4, 7, 11], [-2, 2, 5, 9], [-5, -1, 2, 7], [-3, 0, 4, 7]], CHILL),
    ("C2", [[0, 4, 7], [-1, 3, 7], [-3, 0, 4], [-5, -2, 2]], ELECTRONIC),
    ("F1", [[0, 3, 7, 10], [-4, 0, 5, 8], [-7, -3, 0, 5], [-5, -1, 2, 7]], LOFI),
    ("G2", [[0, 4, 7], [5, 9, 12], [-4, 0, 3], [-1, 2, 7]], POP),
    ("D2", [[0, 3, 7], [-3, 0, 3], [-5, -1, 2], [-7, -4, 0]], LOFI),
    ("Eb1", [[0, 4, 7], [0, 4, 7], [-2, 2, 5], [-5, -1, 2]], ELECTRONIC),
    ("A1", [[0, 4, 7, 11], [-4, 0, 3, 7], [-5, -1, 2, 7], [-3, 0, 4, 9]], CHILL),
]

# BPM per catalog id, tuned per genre.
BPM = [78, 104, 72, 120, 112, 70, 124, 68, 126, 74,
       122, 70, 100, 118, 108, 66, 128, 76, 106, 72,
       124, 68, 102, 75, 120, 64, 110, 70, 122, 73]


# Synthesis primitives -------------------------------------------------------

def env_adsr(n: int, attack: float, decay: float, sustain: float,
             release: float, total: int) -> np.ndarray:
    """Simple ADSR shaped over `total` samples, sized `n`."""
    a = max(1, int(attack * n))
    d = max(1, int(decay * n))
    r = max(1, int(release * n))
    s = max(0, total - a - d - r)
    out = np.concatenate([
        np.linspace(0.0, 1.0, a, endpoint=False),
        np.linspace(1.0, sustain, d, endpoint=False),
        np.full(s, sustain),
        np.linspace(sustain, 0.0, r, endpoint=False),
    ])
    if out.size < n:
        out = np.pad(out, (0, n - out.size))
    return out[:n]


def place(track: np.ndarray, segment: np.ndarray, start: int,
          gain: float = 1.0) -> None:
    """Mix `segment` into `track` at `start`, clipped to the track length."""
    if start >= track.size or start < -segment.size:
        return
    begin = max(0, start)
    seg_begin = begin - start
    end = min(track.size, start + segment.size)
    if end <= begin:
        return
    track[begin:end] += segment[seg_begin:seg_begin + (end - begin)] * gain


def osc(freq: float, n: int, kind: str = "saw", detune: float = 0.0) -> np.ndarray:
    """Band-limited-ish oscillator; `detune` shifts the frequency in semitones."""
    f = freq * (2.0 ** (detune / 12.0))
    t = np.arange(n, dtype=np.float64) / SAMPLE_RATE
    phase = 2.0 * np.pi * f * t
    if kind == "sine":
        return np.sin(phase)
    if kind == "tri":
        return 2.0 * np.abs(2.0 * ((f * t) % 1.0) - 1.0) - 1.0
    if kind == "square":
        return np.sign(np.sin(phase))
    # Saw approximated from a small harmonic stack so it is not pure aliasing.
    out = np.zeros(n, dtype=np.float64)
    for h in (1, 2, 3, 5, 7):
        out += np.sin(phase * h) / h
    return out * 0.7


def kick(n: int) -> np.ndarray:
    t = np.arange(n, dtype=np.float64) / SAMPLE_RATE
    freq = 48.0 + 95.0 * np.exp(-t * 34.0)
    phase = 2.0 * np.pi * np.cumsum(freq) / SAMPLE_RATE
    body = np.sin(phase) * np.exp(-t * 6.5)
    click = np.random.default_rng(0).normal(0, 1, n) * np.exp(-t * 240) * 0.18
    return body + click


def hat(n: int, rng: np.random.Generator) -> np.ndarray:
    t = np.arange(n, dtype=np.float64) / SAMPLE_RATE
    noise = rng.normal(0, 1, n)
    # Crude high-pass: differentiate the noise.
    shaped = np.diff(noise, prepend=0.0) * 0.6
    return shaped * np.exp(-t * 62.0)


def snare(n: int, rng: np.random.Generator) -> np.ndarray:
    t = np.arange(n, dtype=np.float64) / SAMPLE_RATE
    noise = rng.normal(0, 1, n) * np.exp(-t * 26.0) * 0.5
    tone = (np.sin(2 * np.pi * 190 * t) + np.sin(2 * np.pi * 288 * t))
    return (noise + tone * 0.32 * np.exp(-t * 34.0)) * 0.8


def reverb(x: np.ndarray, taps: int = 9, decay: float = 0.55) -> np.ndarray:
    """Cheap multi-tap delay reverb; keeps the generator fast and dep-free."""
    out = x.copy()
    base = int(0.037 * SAMPLE_RATE)
    for i in range(1, taps + 1):
        delay = base * i + (i * 137) % 400
        gain = decay ** i
        place(out, x[: max(0, out.size - delay)], delay, gain * 0.5)
    return out


def render(index: int) -> np.ndarray:
    root, progression, style = RECIPES[index % len(RECIPES)]
    bpm = BPM[index]
    rng = np.random.default_rng(1000 + index)

    beat = 60.0 / bpm
    bars = max(8, int(round(TARGET_SECONDS / (beat * 4))))
    total = int(bars * 4 * beat * SAMPLE_RATE)
    track = np.zeros(total + SAMPLE_RATE, dtype=np.float64)
    length = total

    beat_samples = int(beat * SAMPLE_RATE)
    bar_samples = beat_samples * 4

    for bar in range(bars):
        chord = progression[bar % len(progression)]
        tones = chord_hz(root, chord)
        bar_start = bar * bar_samples

        # ---- Pad --------------------------------------------------------
        pad_n = int(bar_samples * 1.05)
        pad = np.zeros(pad_n, dtype=np.float64)
        for f in tones:
            pad += osc(f, pad_n, "saw", -style.pad_detune) * 0.32
            pad += osc(f, pad_n, "saw", style.pad_detune) * 0.32
            pad += osc(f * 2.0, pad_n, "sine") * 0.10
        pad *= env_adsr(pad_n, 0.30, 0.25, 0.75, 0.35, pad_n)
        place(track, pad, bar_start, 0.30)

        # ---- Bass -------------------------------------------------------
        bass_root = tones[0] / 2.0
        pattern = [0.0, 1.5, 2.0, 3.5] if bpm >= 100 else [0.0, 2.0]
        for offset in pattern:
            n = int(beat_samples * 1.1)
            f = bass_root if offset in (0.0, 2.0) else bass_root * 1.5
            note = osc(f, n, "tri") * 0.9 + osc(f * 0.5, n, "sine") * 0.4
            note *= env_adsr(n, 0.006, 0.10, 0.62, 0.30, n)
            start = bar_start + int(offset * beat_samples)
            if offset > 2.0:
                start += int(style.swing * beat_samples)
            place(track, note, start, 0.42)

        # ---- Arp / lead --------------------------------------------------
        step = beat_samples // style.arp_div
        arp_seq = [0, 1, 2, 3, 2, 1, 3, 2]
        total_steps = 4 * style.arp_div
        for s in range(total_steps):
            if style.brightness < 0.5 and s % 2 == 1:
                continue
            if rng.random() < 0.16:
                continue
            f = tones[arp_seq[s % len(arp_seq)] % len(tones)] * 4.0
            if rng.random() < 0.12:
                f *= 2.0
            n = int(step * 2.4)
            note = osc(f, n, "saw", -0.05) * 0.5 + osc(f, n, "sine") * 0.5
            note *= env_adsr(n, 0.004, 0.22, 0.28, 0.55, n)
            start = bar_start + s * step
            if s % 2 == 1:
                start += int(style.swing * beat_samples * 0.5)
            place(track, note, start, 0.20 * (0.5 + style.brightness))

        # ---- Drums ------------------------------------------------------
        if style.drums:
            kick_bpm = style is ELECTRONIC or style is POP
            for offset in ([0.0, 1.5, 2.5] if kick_bpm else [0.0, 2.0]):
                place(track, kick(int(beat_samples * 0.9)),
                      bar_start + int(offset * beat_samples), 0.55)
            for offset in (1.0, 3.0):
                place(track, snare(int(beat_samples * 0.8), rng),
                      bar_start + int(offset * beat_samples), 0.30)
            for s in range(8):
                gain = 0.14 if s % 2 == 0 else 0.09
                place(track, hat(int(beat_samples * 0.28), rng),
                      bar_start + int(s * beat_samples / 2), gain)

    track = track[:length]
    track = reverb(track)

    # Gentle side-chain ducking on the pad/bass for a pumping feel.
    if style.drums:
        duck_period = beat_samples
        duck = np.ones(length, dtype=np.float64)
        for i in range(0, length, duck_period):
            end = min(length, i + int(duck_period * 0.35))
            duck[i:end] = np.linspace(0.72, 1.0, end - i)
        track *= duck

    fade = int(0.6 * SAMPLE_RATE)
    track[:fade] *= np.linspace(0.0, 1.0, fade)
    track[-fade:] *= np.linspace(1.0, 0.0, fade)

    peak = float(np.max(np.abs(track))) or 1.0
    track = np.tanh(track / peak * 1.35) / 1.35
    peak = float(np.max(np.abs(track))) or 1.0
    track = track / peak * 0.89
    return track


def write_wav(path: str, samples: np.ndarray) -> None:
    pcm = np.clip(samples, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2")
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(pcm.tobytes())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", default="ffmpeg", help="ffmpeg executable")
    parser.add_argument(
        "--out",
        default=os.path.join("assets", "audio"),
        help="output directory for the mp3 files",
    )
    parser.add_argument("--count", type=int, default=30)
    args = parser.parse_args()

    ffmpeg = shutil.which(args.ffmpeg) or args.ffmpeg
    if not (os.path.isfile(ffmpeg) or shutil.which(ffmpeg)):
        print(f"ffmpeg not found: {args.ffmpeg}", file=sys.stderr)
        return 2

    os.makedirs(args.out, exist_ok=True)
    durations: list[float] = []

    with tempfile.TemporaryDirectory() as tmp:
        for index in range(args.count):
            name = f"song_{index + 1:02d}"
            wav_path = os.path.join(tmp, f"{name}.wav")
            mp3_path = os.path.join(args.out, f"{name}.mp3")

            samples = render(index)
            write_wav(wav_path, samples)
            durations.append(len(samples) / SAMPLE_RATE)

            cmd = [
                ffmpeg, "-y", "-loglevel", "error",
                "-i", wav_path,
                "-codec:a", "libmp3lame",
                "-b:a", BITRATE,
                "-ac", "1",
                "-ar", str(SAMPLE_RATE),
                "-metadata", f"title={name}",
                mp3_path,
            ]
            subprocess.run(cmd, check=True)
            print(f"  {name}.mp3  {len(samples) / SAMPLE_RATE:6.2f}s  "
                  f"{os.path.getsize(mp3_path) / 1024:7.1f} KiB")

    total = sum(durations)
    print(f"\n{args.count} tracks, {total:.1f}s total audio, "
          f"{sum(os.path.getsize(os.path.join(args.out, f)) for f in os.listdir(args.out) if f.endswith('.mp3')) / 1048576:.2f} MiB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
