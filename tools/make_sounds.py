#!/usr/bin/env python3
"""Synthesizes every sound in the game from scratch (no samples): short
effects, an ambience loop and a music loop, written as 16-bit WAVs into
assets/sfx/. Run it after changing a recipe; Godot re-imports on launch.
"""
import math, os, struct, wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
rng = np.random.default_rng(7)


def t(seconds):
    return np.arange(int(SR * seconds)) / SR


def env(n, attack=0.005, decay=0.1, sustain=0.0, release=0.05, hold=0.0):
    """A simple ADSR over n samples (times in seconds)."""
    a, d, h, r = [int(SR * x) for x in (attack, decay, hold, release)]
    out = np.zeros(n)
    i = 0
    seg = min(a, n); out[i:i + seg] = np.linspace(0, 1, seg, endpoint=False); i += seg
    seg = min(d, n - i); out[i:i + seg] = np.linspace(1, sustain, seg, endpoint=False); i += seg
    seg = min(h, n - i); out[i:i + seg] = sustain; i += seg
    seg = min(r, n - i); out[i:i + seg] = np.linspace(sustain, 0, seg, endpoint=False); i += seg
    return out


def expdecay(n, tau):
    return np.exp(-np.arange(n) / SR / tau)


def noise(n):
    return rng.uniform(-1, 1, n)


def lowpass(x, cutoff):
    """One-pole lowpass; cutoff may be an array (per-sample sweep)."""
    if np.isscalar(cutoff):
        cutoff = np.full(len(x), float(cutoff))
    alpha = 1.0 - np.exp(-2 * math.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha[i] * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bandpass(x, lo, hi):
    return highpass(lowpass(x, hi), lo)


def sine(freq, n, phase=0.0):
    """freq may be a scalar or a per-sample array (sweeps)."""
    if np.isscalar(freq):
        freq = np.full(n, float(freq))
    ph = 2 * math.pi * np.cumsum(freq) / SR + phase
    return np.sin(ph)


def tri(freq, n):
    if np.isscalar(freq):
        freq = np.full(n, float(freq))
    ph = (np.cumsum(freq) / SR) % 1.0
    return 4 * np.abs(ph - 0.5) - 1


def square(freq, n, duty=0.5):
    if np.isscalar(freq):
        freq = np.full(n, float(freq))
    ph = (np.cumsum(freq) / SR) % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def tone(freq, seconds, kind="sine", attack=0.005, decay=0.1, sustain=0.3, release=0.1, harmonics=(1.0,)):
    n = int(SR * seconds)
    out = np.zeros(n)
    for k, amp in enumerate(harmonics):
        f = freq * (k + 1)
        osc = {"sine": sine, "tri": tri, "square": square}[kind]
        out += amp * osc(f, n)
    return out * env(n, attack, decay, sustain, release, hold=max(0.0, seconds - attack - decay - release))


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def seq(*parts, gap=0.0):
    """Parts one after another (gap seconds between starts may overlap by negative gap)."""
    out = np.zeros(0)
    pos = 0
    for p in parts:
        end = pos + len(p)
        if end > len(out):
            out = np.concatenate([out, np.zeros(end - len(out))])
        out[pos:end] += p
        pos += len(p) + int(SR * gap)
    return out


def at(part, seconds, total):
    """Place a part at a time offset inside a buffer of `total` seconds."""
    n = int(SR * total)
    out = np.zeros(n)
    i = int(SR * seconds)
    seg = min(len(part), n - i)
    if seg > 0:
        out[i:i + seg] += part[:seg]
    return out


def normalize(x, peak=0.85):
    m = np.max(np.abs(x)) if len(x) else 1.0
    return x / m * peak if m > 0 else x


def write(name, data, peak=0.85, loop=False):
    data = normalize(data, peak)
    data = np.clip(data, -1, 1)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((data * 32767).astype("<i2").tobytes())
    print("wrote", os.path.relpath(path), "%.2fs" % (len(data) / SR))


# --- Effects ---------------------------------------------------------------

def whoosh(seconds=0.22, lo=400, hi=2600, down=True):
    n = int(SR * seconds)
    sweep = np.linspace(hi, lo, n) if down else np.linspace(lo, hi, n)
    return bandpass(noise(n), 200, sweep) * env(n, 0.02, seconds - 0.05, 0.0, 0.03) * 3.0


def thump(freq=90, seconds=0.18, tau=0.05):
    n = int(SR * seconds)
    f = np.linspace(freq * 1.8, freq, n)
    return sine(f, n) * expdecay(n, tau)


def click(seconds=0.02, cutoff=6000):
    n = int(SR * seconds)
    return lowpass(noise(n), cutoff) * expdecay(n, 0.006) * 2.0


def chime(freq, seconds=0.5, bright=0.5):
    n = int(SR * seconds)
    return (sine(freq, n) + bright * 0.5 * sine(freq * 2.0, n) + bright * 0.25 * sine(freq * 3.01, n)) * expdecay(n, seconds * 0.3) * env(n, 0.003, 0.02, 1.0, 0.05, seconds)


def sounds():
    s = {}
    # Melee: a swing is a whoosh; a hit adds a thump and a slap.
    s["swing"] = whoosh(0.2, 300, 2200)
    s["swing_heavy"] = whoosh(0.32, 160, 1500)
    s["hit_flesh"] = mix(thump(110, 0.16, 0.04), lowpass(noise(int(SR * 0.08)), 1800) * expdecay(int(SR * 0.08), 0.02) * 1.5)
    s["hit_shield"] = mix(tone(1900, 0.18, "sine", 0.001, 0.12, 0.0, 0.05, (1.0, 0.4, 0.2)) * 0.6,
                          tone(2600, 0.1, "sine", 0.001, 0.08, 0.0, 0.02) * 0.3, click(0.015, 8000) * 0.8)
    s["punch"] = mix(thump(140, 0.1, 0.03), click(0.01, 3000) * 0.5)
    # Bows: a plucked string with a short twang, arrows land with a thwack.
    n = int(SR * 0.25)
    s["bow"] = mix((sine(np.linspace(520, 380, n), n) * expdecay(n, 0.05)) * 0.8, whoosh(0.12, 800, 3000, False) * 0.5)
    s["arrow_hit"] = mix(thump(220, 0.07, 0.015), lowpass(noise(int(SR * 0.05)), 3000) * expdecay(int(SR * 0.05), 0.01))
    s["volley"] = seq(s["bow"] * 0.8, s["bow"] * 0.7, s["bow"] * 0.6, gap=-0.19)
    s["trap_set"] = mix(click(0.03, 4000), tone(1200, 0.12, "square", 0.001, 0.08, 0.0, 0.03) * 0.15)
    s["trap_snap"] = mix(click(0.02, 9000) * 1.5, tone(2400, 0.15, "sine", 0.001, 0.1, 0.0, 0.04) * 0.5, thump(160, 0.12, 0.03))
    # Magic: bolts shimmer upward, bursts crackle, fire roars.
    n = int(SR * 0.3)
    s["bolt"] = mix(sine(np.linspace(600, 1500, n), n) * env(n, 0.005, 0.2, 0.0, 0.05) * 0.5,
                    sine(np.linspace(900, 2250, n), n) * env(n, 0.005, 0.15, 0.0, 0.05) * 0.25,
                    bandpass(noise(n), 2000, 6000) * env(n, 0.01, 0.1, 0.0, 0.1) * 0.6)
    n = int(SR * 0.25)
    s["bolt_hit"] = mix(bandpass(noise(n), 800, 5000) * expdecay(n, 0.05) * 2.0, sine(np.linspace(1200, 300, n), n) * expdecay(n, 0.06) * 0.5)
    n = int(SR * 0.6)
    s["fireball"] = mix(lowpass(noise(n), np.linspace(400, 1800, n)) * env(n, 0.05, 0.3, 0.6, 0.2) * 2.5,
                        sine(np.linspace(80, 140, n), n) * env(n, 0.05, 0.3, 0.5, 0.2) * 0.4)
    n = int(SR * 0.7)
    s["explosion"] = mix(lowpass(noise(n), np.linspace(3000, 200, n)) * expdecay(n, 0.18) * 3.0, thump(60, 0.5, 0.15) * 1.2)
    n = int(SR * 0.45)
    s["frost"] = mix(sine(np.linspace(2400, 3200, n), n) * expdecay(n, 0.12) * 0.4,
                     bandpass(noise(n), 3000, 9000) * expdecay(n, 0.15) * 1.2, chime(1760, 0.4, 0.3) * 0.5)
    n = int(SR * 0.3)
    s["blink"] = mix(sine(np.linspace(300, 2400, n), n) * env(n, 0.005, 0.25, 0.0, 0.04) * 0.5, bandpass(noise(n), 1500, 7000) * env(n, 0.01, 0.2, 0.0, 0.05))
    # Healing: soft rising thirds; the blessing is a chord that swells.
    s["heal"] = seq(chime(659, 0.35, 0.3) * 0.6, chime(880, 0.45, 0.3) * 0.6, gap=-0.25)
    s["blessing"] = mix(chime(523, 1.0, 0.4), at(chime(659, 0.9, 0.4), 0.08, 1.0), at(chime(784, 0.8, 0.4), 0.16, 1.0), at(chime(1046, 0.7, 0.4), 0.24, 1.0))
    n = int(SR * 0.35)
    s["smite"] = mix(sine(np.linspace(1800, 700, n), n) * env(n, 0.003, 0.25, 0.0, 0.05) * 0.6, bandpass(noise(n), 3000, 8000) * expdecay(n, 0.06))
    s["curse"] = mix(tone(110, 0.6, "square", 0.02, 0.3, 0.3, 0.2, (1.0, 0.3)) * 0.4, sine(np.linspace(900, 200, int(SR * 0.6)), int(SR * 0.6)) * expdecay(int(SR * 0.6), 0.2) * 0.4)
    # Being hit, dying, coming back.
    n = int(SR * 0.2)
    s["hurt"] = mix(square(np.linspace(420, 260, n), n, 0.3) * expdecay(n, 0.05) * 0.4, s["hit_flesh"][:n] * 0.6)
    n = int(SR * 0.6)
    s["death"] = mix(square(np.linspace(360, 90, n), n, 0.4) * env(n, 0.01, 0.5, 0.0, 0.08) * 0.35, thump(70, 0.4, 0.1) * 0.8)
    s["respawn"] = seq(chime(523, 0.3, 0.5) * 0.5, chime(784, 0.3, 0.5) * 0.5, chime(1046, 0.5, 0.5) * 0.5, gap=-0.2)
    n = int(SR * 0.18)
    s["dodge"] = whoosh(0.18, 500, 3000, False) * 0.8
    s["block_up"] = mix(click(0.02, 5000) * 0.6, tone(1400, 0.12, "sine", 0.001, 0.1, 0.0, 0.02, (1.0, 0.5)) * 0.3)
    s["step"] = lowpass(noise(int(SR * 0.07)), 900) * expdecay(int(SR * 0.07), 0.015) * 1.5
    s["step_stone"] = mix(lowpass(noise(int(SR * 0.06)), 2500) * expdecay(int(SR * 0.06), 0.01) * 1.2, thump(200, 0.05, 0.01) * 0.4)
    # Doors and the vault: wood thuds, a crash, a lock giving way, a bell.
    s["door_hit"] = mix(thump(75, 0.25, 0.06) * 1.2, lowpass(noise(int(SR * 0.12)), 1200) * expdecay(int(SR * 0.12), 0.03) * 1.2)
    n = int(SR * 1.2)
    s["door_break"] = mix(lowpass(noise(n), np.linspace(2500, 150, n)) * expdecay(n, 0.3) * 2.5, thump(50, 0.8, 0.25) * 1.5,
                          at(click(0.03, 3000), 0.15, 1.2), at(click(0.03, 2500), 0.32, 1.2), at(click(0.03, 2000), 0.5, 1.2))
    s["door_rebuilt"] = seq(mix(click(0.03, 3000), thump(180, 0.12, 0.03)) * 0.8, mix(click(0.03, 3000), thump(180, 0.12, 0.03)) * 0.8, chime(880, 0.4, 0.4) * 0.5, gap=0.08)
    s["vault_hit"] = mix(tone(2200, 0.14, "sine", 0.001, 0.1, 0.0, 0.03, (1.0, 0.6, 0.3)) * 0.5, click(0.015, 9000), thump(150, 0.1, 0.02) * 0.5)
    s["vault_open"] = mix(seq(click(0.04, 2000) * 1.2, click(0.04, 2000), gap=0.12) * 0.8, at(chime(1318, 0.8, 0.5), 0.25, 1.1), at(chime(1760, 0.7, 0.5), 0.35, 1.1))
    s["barricade"] = mix(click(0.04, 2500), thump(120, 0.15, 0.04))
    # The crown: pickups shine, captures get a fanfare, a drop clatters.
    s["crown_grab"] = mix(chime(1046, 0.5, 0.6), at(chime(1318, 0.45, 0.6), 0.06, 0.6), at(chime(1568, 0.5, 0.6), 0.12, 0.6))
    s["crown_drop"] = seq(mix(click(0.02, 6000), tone(3000, 0.1, "sine", 0.001, 0.08, 0.0, 0.02) * 0.4), mix(click(0.02, 6000), tone(2600, 0.08, "sine", 0.001, 0.06, 0.0, 0.02) * 0.3) * 0.7, gap=0.07)
    s["capture"] = mix(seq(tone(523, 0.18, "tri", 0.005, 0.05, 0.8, 0.05, (1.0, 0.5, 0.25)), tone(659, 0.18, "tri", 0.005, 0.05, 0.8, 0.05, (1.0, 0.5, 0.25)),
                           tone(784, 0.18, "tri", 0.005, 0.05, 0.8, 0.05, (1.0, 0.5, 0.25)), tone(1046, 0.7, "tri", 0.005, 0.1, 0.7, 0.3, (1.0, 0.5, 0.25))),
                       at(tone(261, 1.2, "tri", 0.01, 0.2, 0.6, 0.3, (1.0, 0.3)) * 0.5, 0.0, 1.3))
    s["stolen"] = mix(seq(tone(440, 0.25, "square", 0.005, 0.1, 0.6, 0.05, (1.0, 0.3)) * 0.3, tone(415, 0.6, "square", 0.005, 0.2, 0.5, 0.2, (1.0, 0.3)) * 0.3), thump(55, 0.8, 0.2))
    s["safe"] = seq(chime(784, 0.3, 0.4) * 0.6, chime(1046, 0.5, 0.4) * 0.6, gap=-0.15)
    # Progress and UI.
    s["level_up"] = seq(chime(784, 0.25, 0.5), chime(988, 0.25, 0.5), chime(1318, 0.6, 0.5), gap=-0.12)
    s["rank_up"] = mix(click(0.02, 5000) * 0.5, chime(1318, 0.35, 0.5) * 0.7, at(chime(1760, 0.35, 0.5) * 0.6, 0.05, 0.4))
    s["promote"] = mix(seq(chime(659, 0.3, 0.5), chime(880, 0.3, 0.5), chime(1318, 0.8, 0.5), gap=-0.15), tone(220, 1.0, "tri", 0.02, 0.3, 0.5, 0.3, (1.0, 0.4)) * 0.3)
    s["xp"] = chime(2093, 0.12, 0.2) * 0.4
    s["ui_click"] = mix(click(0.012, 4000) * 0.8, tone(900, 0.06, "sine", 0.001, 0.04, 0.0, 0.02) * 0.3)
    s["ui_open"] = seq(click(0.015, 3000) * 0.6, chime(880, 0.2, 0.3) * 0.4, gap=0.0)
    s["ui_close"] = seq(click(0.015, 3000) * 0.6, chime(660, 0.2, 0.3) * 0.4, gap=0.0)
    s["ui_deny"] = tone(180, 0.16, "square", 0.002, 0.1, 0.0, 0.04, (1.0, 0.4)) * 0.3
    # Grab / interact: a quick hand whoosh; a soft pop and chime when it takes hold.
    s["grab"] = mix(whoosh(0.12, 600, 2400, False) * 0.5, at(click(0.02, 3500) * 0.9, 0.07, 0.4), at(thump(220, 0.08, 0.02) * 0.6, 0.07, 0.4),
                    at(chime(1568, 0.25, 0.3) * 0.35, 0.09, 0.4))
    s["grab_miss"] = whoosh(0.14, 500, 1800, False) * 0.45
    s["station"] = mix(seq(click(0.03, 2000), click(0.03, 2000), gap=0.06), at(chime(1046, 0.5, 0.5), 0.1, 0.6), at(whoosh(0.3, 300, 2000, False) * 0.6, 0.05, 0.6))
    s["match_start"] = mix(seq(tone(392, 0.2, "tri", 0.005, 0.05, 0.8, 0.05, (1.0, 0.5)), tone(523, 0.2, "tri", 0.005, 0.05, 0.8, 0.05, (1.0, 0.5)), tone(784, 0.8, "tri", 0.005, 0.1, 0.7, 0.3, (1.0, 0.5))),
                           thump(65, 0.6, 0.2))
    s["victory"] = seq(tone(523, 0.22, "tri", 0.005, 0.05, 0.8, 0.05, (1.0, 0.5, 0.2)), tone(523, 0.12, "tri", 0.005, 0.05, 0.8, 0.03, (1.0, 0.5, 0.2)), tone(523, 0.12, "tri", 0.005, 0.05, 0.8, 0.03, (1.0, 0.5, 0.2)),
                      tone(698, 0.3, "tri", 0.005, 0.05, 0.8, 0.05, (1.0, 0.5, 0.2)), tone(880, 0.3, "tri", 0.005, 0.05, 0.8, 0.05, (1.0, 0.5, 0.2)), tone(1046, 1.0, "tri", 0.005, 0.1, 0.7, 0.4, (1.0, 0.5, 0.2)))
    s["defeat"] = seq(tone(392, 0.4, "tri", 0.01, 0.1, 0.7, 0.1, (1.0, 0.3)), tone(349, 0.4, "tri", 0.01, 0.1, 0.7, 0.1, (1.0, 0.3)), tone(311, 0.5, "tri", 0.01, 0.1, 0.7, 0.1, (1.0, 0.3)), tone(261, 1.2, "tri", 0.01, 0.2, 0.6, 0.5, (1.0, 0.3)))
    s["horn"] = tone(196, 1.0, "square", 0.05, 0.2, 0.7, 0.3, (1.0, 0.5, 0.3, 0.15)) * 0.4
    # Turrets: a wind-up when placed, a crossbow thunk when they fire, a clank when they break.
    s["turret_place"] = mix(seq(click(0.03, 3000), click(0.03, 3000), click(0.03, 3000), gap=0.07), at(tone(400, 0.4, "square", 0.01, 0.2, 0.5, 0.15, (1.0, 0.3)) * 0.15, 0.0, 0.5))
    s["turret_fire"] = mix(thump(260, 0.08, 0.015), click(0.02, 5000), whoosh(0.1, 800, 2600, False) * 0.5)
    s["turret_break"] = mix(lowpass(noise(int(SR * 0.5)), np.linspace(3000, 300, int(SR * 0.5))) * expdecay(int(SR * 0.5), 0.12) * 2.0,
                            tone(1500, 0.3, "sine", 0.001, 0.2, 0.0, 0.1, (1.0, 0.5)) * 0.4, thump(90, 0.3, 0.08))
    s["turret_upgrade"] = mix(seq(click(0.03, 3000), click(0.03, 3000), gap=0.08), at(chime(1318, 0.4, 0.5) * 0.6, 0.12, 0.55))
    return s


# --- Ambience and music -------------------------------------------------------

def ambience():
    """Wind with slow gusts, a brook, and a few birds. Loops at 12 s."""
    secs = 12.0
    n = int(SR * secs)
    tt = np.arange(n) / SR
    gust = 0.5 + 0.5 * np.sin(2 * math.pi * tt / 12.0) * np.sin(2 * math.pi * tt / 5.0 + 1.0)
    wind = lowpass(noise(n), 300 + 500 * gust) * (0.25 + 0.5 * gust)
    brook = bandpass(noise(n), 1500, 5000) * (0.09 + 0.03 * np.sin(2 * math.pi * tt / 3.3))
    birds = np.zeros(n)
    for start in (1.2, 3.1, 5.6, 7.4, 9.9):
        base = rng.uniform(2400, 3600)
        for k in range(3):
            d = 0.07 + 0.03 * k
            m = int(SR * d)
            f = base * (1.0 + 0.15 * np.sin(np.linspace(0, math.pi, m))) * (1.0 + 0.08 * k)
            chirp = sine(f, m) * env(m, 0.01, d - 0.03, 0.0, 0.02) * 0.09
            birds += at(chirp, start + k * 0.11, secs)
    out = wind + brook + birds
    # Fade the loop seam.
    fade = int(SR * 0.4)
    out[:fade] *= np.linspace(0, 1, fade)
    out[-fade:] *= np.linspace(1, 0, fade)
    return out


NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(name, octave):
    return 440.0 * 2 ** ((NOTE[name] + 12 * (octave - 4) - 9) / 12.0)


def music(tempo=96):
    """A short original theme: a D-dorian folk melody over a bass drone and a
    soft harp arpeggio, 16 bars, plus a light drum. Loops at the end."""
    beat = 60.0 / tempo
    bars = 16
    secs = bars * 4 * beat
    out = np.zeros(int(SR * secs))
    melody = [  # (note, octave, beats)
        ("D", 4, 1), ("F", 4, 1), ("A", 4, 1.5), ("G", 4, 0.5), ("F", 4, 1), ("E", 4, 1), ("D", 4, 2),
        ("C", 4, 1), ("E", 4, 1), ("G", 4, 1.5), ("F", 4, 0.5), ("E", 4, 1), ("D", 4, 1), ("C", 4, 2),
        ("D", 4, 1), ("F", 4, 1), ("A", 4, 1), ("D", 5, 1), ("C", 5, 1.5), ("A", 4, 0.5), ("G", 4, 2),
        ("F", 4, 1), ("G", 4, 1), ("A", 4, 1.5), ("F", 4, 0.5), ("E", 4, 1), ("C", 4, 1), ("D", 4, 2),
        ("A", 4, 1), ("D", 5, 1), ("C", 5, 1), ("A", 4, 1), ("G", 4, 1.5), ("A", 4, 0.5), ("F", 4, 2),
        ("G", 4, 1), ("A", 4, 1), ("G", 4, 1), ("F", 4, 1), ("E", 4, 1.5), ("D", 4, 0.5), ("E", 4, 2),
        ("D", 4, 1), ("F", 4, 1), ("A", 4, 1.5), ("G", 4, 0.5), ("F", 4, 1), ("E", 4, 1), ("D", 4, 1), ("C", 4, 1),
        ("D", 4, 1.5), ("E", 4, 0.5), ("F", 4, 1), ("E", 4, 1), ("D", 4, 4),
    ]
    pos = 0.0
    for name, octv, beats in melody:
        d = beats * beat
        n = int(SR * d)
        f = hz(name, octv)
        vib = f * (1.0 + 0.006 * np.sin(2 * math.pi * 5.5 * np.arange(n) / SR))
        note = (sine(vib, n) * 0.6 + tri(vib, n) * 0.25 + sine(vib * 2, n) * 0.12) * env(n, 0.02, 0.1, 0.75, 0.12, hold=max(0.0, d - 0.24))
        out += at(note * 0.35, pos, secs)
        pos += d
    chords = [("D", "F", "A"), ("C", "E", "G"), ("D", "F", "A"), ("F", "A", "C"),
              ("A", "C", "E"), ("G", "B", "D"), ("D", "F", "A"), ("D", "F", "A")] * 2
    for bar, chord in enumerate(chords):
        start = bar * 4 * beat
        bass = hz(chord[0], 2)
        n = int(SR * 4 * beat)
        out += at((sine(bass, n) + 0.3 * sine(bass * 2, n)) * env(n, 0.05, 0.3, 0.5, 0.4, hold=4 * beat - 0.75) * 0.3, start, secs)
        for k in range(8):
            name = chord[k % 3]
            octv = 3 if k % 3 == 0 else 4
            if k >= 4 and k % 3 == 0:
                octv = 4
            d = beat / 2
            m = int(SR * d)
            harp = sine(hz(name, octv), m) * expdecay(m, 0.18) * env(m, 0.003, 0.02, 1.0, 0.05, d)
            out += at(harp * 0.18, start + k * d, secs)
        for k in range(4):
            drum = thump(70, 0.2, 0.05) * (0.5 if k % 2 == 0 else 0.25)
            out += at(drum, start + k * beat, secs)
            if k % 2 == 1:
                out += at(lowpass(noise(int(SR * 0.05)), 4000) * expdecay(int(SR * 0.05), 0.012) * 0.25, start + k * beat, secs)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, data in sounds().items():
        write(name, data, 0.8)
    write("ambience", ambience(), 0.5, loop=True)
    write("theme", music(), 0.75, loop=True)


if __name__ == "__main__":
    main()
