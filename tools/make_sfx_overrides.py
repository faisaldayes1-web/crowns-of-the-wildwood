#!/usr/bin/env python3
"""Builds assets/sfx/override/*.wav from raw ElevenLabs clips.

Agent: claude-faisal3. The six clips replace the synthesized swing_heavy,
hit_heavy, hit_shield, hurt, death and crown_grab through OVERRIDES in
scripts/sfx.gd; the originals stay in assets/sfx/.

Each raw clip (stereo, 48 kHz, padded with silence) is: mixed to mono,
trimmed to where it is audible (-45 dB below its peak) with a 3 ms fade in
and a fade out, capped at MAX_S seconds, resampled to 44.1 kHz, then scaled so its active RMS (samples
above 0.01) matches the original clip it replaces. A clip whose peak would
pass PEAK_CEIL_DB is limited by gain instead (the report says by how much).

    python tools/make_sfx_overrides.py <raw_dir> [--pick name=v2 ...]
"""
import sys, wave, math, os
import numpy as np
from scipy.signal import resample_poly

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SFX = os.path.join(ROOT, "assets", "sfx")
OUT = os.path.join(SFX, "override")
SR = 44100
PEAK_CEIL_DB = -1.0
MAX_S = {"swing_heavy": 0.6, "hit_heavy": 0.45, "hit_shield": 0.7, "hurt": 0.5, "death": 1.0, "crown_grab": 1.0}   # combat clips stay short: a long tail would smear a flurry of hits
PICK = {"swing_heavy": "v1", "hit_heavy": "v1", "hit_shield": "v2", "hurt": "v2", "death": "v1", "crown_grab": "v1"}


def read(path):
    w = wave.open(path)
    n, ch, sr = w.getnframes(), w.getnchannels(), w.getframerate()
    d = np.frombuffer(w.readframes(n), dtype="<i2").astype(np.float64) / 32768.0
    if ch > 1:
        d = d.reshape(-1, ch).mean(1)
    return d, sr


def active_rms(d):
    a = d[np.abs(d) > 0.01]
    return float(np.sqrt((a ** 2).mean())) if len(a) else 1e-9


def db(x):
    return 20 * math.log10(max(x, 1e-9))


def main():
    raw = sys.argv[1]
    for a in sys.argv[2:]:
        if "=" in a:
            k, v = a.split("=")
            PICK[k] = v
    os.makedirs(OUT, exist_ok=True)
    print("name  pick  dur_s  orig_active_rms  new_active_rms  new_peak_db  gain_db")
    for name, ver in PICK.items():
        d, sr = read(os.path.join(raw, f"{name}_{ver}.wav"))
        ref, _ = read(os.path.join(SFX, f"{name}.wav"))
        loud = np.where(np.abs(d) > np.abs(d).max() * 10 ** (-45 / 20))[0]
        d = d[max(loud[0] - int(0.003 * sr), 0): loud[-1] + int(0.01 * sr)]
        d = resample_poly(d, SR, sr)[: int(MAX_S[name] * SR)]
        f_in = min(int(0.003 * SR), len(d) // 4)
        f_out = min(int(0.04 * SR), len(d) // 3)
        d[:f_in] *= np.linspace(0, 1, f_in)
        d[-f_out:] *= np.linspace(1, 0, f_out)
        gain = active_rms(ref) / active_rms(d)
        peak_gain = 10 ** (PEAK_CEIL_DB / 20) / np.abs(d).max()
        gain = min(gain, peak_gain)
        d = d * gain
        pcm = (np.clip(d, -1, 1) * 32767).astype("<i2")
        with wave.open(os.path.join(OUT, f"{name}.wav"), "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
        print(f"{name:12s} {ver}  {len(d)/SR:5.2f}  {db(active_rms(ref)):7.1f}  {db(active_rms(d)):7.1f}  {db(np.abs(d).max()):7.1f}  {db(gain):6.1f}")


if __name__ == "__main__":
    main()
