#!/usr/bin/env python3
"""Composes and renders the game's music in a big, bouncy orchestral fantasy
style (in the spirit of mobile strategy games like Clash of Clans): unison
horn tunes over driving staccato strings, trumpet fanfares, a marching snare,
timpani and cymbal crashes, playful pizzicato, piccolo and xylophone.
Every note is original and written out below; no melody, recording or sample
of any existing game music is used.

Sound: real recorded orchestra samples from the VS Chamber Orchestra 2
Community Edition (VSCO 2 CE, CC0 public domain, see assets/CREDITS.md),
played by the small sampler in this file, with a synthetic concert-hall
reverb. Only the rendered .ogg files ship with the game.

Setup (once, ~0.9 GB of samples, sparse checkout of the folders used):
  git clone --filter=blob:none --no-checkout --depth 1 \\
      https://github.com/sgossner/VSCO-2-CE.git /path/vsco
  cd /path/vsco && git sparse-checkout set --no-cone $(python3 \\
      tools/make_music.py --sparse-paths) && git checkout HEAD
  pip install numpy scipy
Run:
  python3 tools/make_music.py --samples /path/vsco [--preview DIR]
--preview also writes listening mixes (mp3) into DIR.

Tracks (assets/music/)
  menu.ogg                     title / menus theme, loops
  battle_base.ogg              in-match loop, always playing
  battle_drums.ogg             + march snare, bass drum, tambourine (door under attack)
  battle_tension.ogg           + racing violins, brass stabs (crown out of its vault)
  sting_*.ogg                  match start, crown captured, crown lost, victory, defeat
The three battle stems are sample-for-sample the same length and play in sync.
"""
import glob, os, random, re, subprocess, sys, tempfile, wave
import warnings
import numpy as np
import scipy.io.wavfile as wavfile
from scipy.signal import fftconvolve

warnings.filterwarnings("ignore", category=wavfile.WavFileWarning)

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "music")
TAIL = 4.0          # seconds rendered past the end (reverb, ringing notes)
OGG_QUALITY = "3"   # libvorbis -q: ~110 kbps stereo

# --- Instruments ----------------------------------------------------------
# key -> {articulation: glob relative to the VSCO folder}. Pitched samples
# are named with C3 = middle C, so their MIDI number is one octave higher
# than the name reads (checked by pitch analysis).
PITCHED = {
    "horn": {"sus": "Brass/F Horn/sus/*.wav", "stac": "Brass/F Horn/stac/*.wav"},
    "trumpet": {"sus": "Brass/Trumpet/sus/*.wav", "stac": "Brass/Trumpet/stac/*.wav"},
    "trombone": {"sus": "Brass/Tenor Trombone/sus/*.wav", "stac": "Brass/Tenor Trombone/stac/*.wav"},
    "tuba": {"sus": "Brass/Tuba/sus/*.wav", "stac": "Brass/Tuba/stac/*.wav"},
    "violins": {"sus": "Strings/Violin Section/susVib/*.wav", "stac": "Strings/Violin Section/Spic/*.wav",
                "pizz": "Strings/Violin Section/Pizz/*.wav"},
    "violas": {"sus": "Strings/Viola Section/susvib/*.wav", "stac": "Strings/Viola Section/spic/*.wav"},
    "cellos": {"sus": "Strings/Cello Section/susvib/*.wav", "stac": "Strings/Cello Section/spic/*.wav",
               "pizz": "Strings/Cello Section/pizzT/*.wav"},
    "basses": {"pizz": "Strings/Solo Contrabass/Pizz/*.wav"},
    "flute": {"sus": "Woodwinds/Flute/susvib/*.wav", "stac": "Woodwinds/Flute/stac/*.wav"},
    "piccolo": {"sus": "Woodwinds/Piccolo/Sus/*.wav", "stac": "Woodwinds/Piccolo/Stac/*.wav"},
    "oboe": {"sus": "Woodwinds/Oboe/Vib/*.wav", "stac": "Woodwinds/Oboe/Stacc/*.wav"},
    "clarinet": {"stac": "Woodwinds/Clarinet/stac/*.wav"},
    "bassoon": {"stac": "Woodwinds/Bassoon/stac/*.wav"},
    "glock": {"hit": "Percussion/Glock/*.wav"},
    "xylo": {"hit": "Percussion/Xylo/*.wav"},
}
# Unpitched: key -> list of (glob, velocity layer from the name or None).
DRUM_KIT = {
    "snare": "Percussion/Snare2-HitSN_v*_rr*_Sum.wav",
    "kick": "Percussion/BDrumNewhit_v*_rr*_Sum.wav",
    "tamb": "Percussion/Tamb1-Hit_v*_Sum.wav",
    "crash": "VSCO 1 Percussion/varMetal/Cymbals/clash/crash_hit_*_loose*.wav",
    "swell": "VSCO 1 Percussion/varMetal/Cymbals/susp/susp_hit_softmall_roll2_cresc*.wav",
}
# Timpani: five drums, principal tones measured from the recordings.
TIMPANI = {1: 41.5, 2: 46.8, 3: 49.5, 4: 52.4, 5: 54.6}
DYN = {"ppp": 1, "pp": 2, "p": 3, "mp": 4, "mf": 5, "f": 6, "ff": 7, "fff": 8}

SPARSE = sorted({"/" + g.rsplit("/", 1)[0] + "/" for arts in PITCHED.values() for g in arts.values()}
                | {"/Percussion/Timpani/", "/Percussion/Snare2-*", "/Percussion/BDrumNewhit*", "/Percussion/Tamb1-Hit*",
                   "/VSCO 1 Percussion/varMetal/Cymbals/clash/crash_*",
                   "/VSCO 1 Percussion/varMetal/Cymbals/susp/susp_hit_softmall_roll2_cresc*", "/LICENSE"})

NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def p(name):
    """'Bb4' or 'F#5' -> MIDI note number (C4 = 60)."""
    pc = NAMES[name[0]]
    rest = name[1:]
    while rest and rest[0] in "b#":
        pc += -1 if rest[0] == "b" else 1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + pc


def read_wav(path):
    rate, x = wavfile.read(path)
    if x.dtype == np.int16:
        x = x / 32768.0
    elif x.dtype == np.int32:
        x = x / 2147483648.0
    elif x.dtype == np.uint8:
        x = (x - 128) / 128.0
    x = np.asarray(x, dtype=np.float64)
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    x = x[:, :2]
    if rate != SR:
        idx = np.arange(0, len(x) - 1, rate / SR)
        x = np.stack([np.interp(idx, np.arange(len(x)), x[:, c]) for c in range(2)], axis=1)
    # Trim the silence before the attack.
    level = np.abs(x).max(axis=1)
    if level.max() > 0:
        start = int(np.argmax(level > level.max() * 0.02))
        x = x[max(0, start - int(0.004 * SR)):]
    return x


class Sampler:
    def __init__(self, root):
        self.root = root
        self.cache = {}
        self.banks = {}
        self.norm = {}
        self.rng = random.Random(5)

    def _bank(self, inst, art):
        key = (inst, art)
        if key in self.banks:
            return self.banks[key]
        if inst == "timpani":
            files = glob.glob(os.path.join(self.root, "Percussion/Timpani/Timpani*_Hit_v*_rr*_Sum.wav"))
            bank = []
            for f in files:
                m = re.search(r"Timpani(\d)_Hit_v(\d+)", os.path.basename(f))
                bank.append((TIMPANI[int(m.group(1))], int(m.group(2)), f))
        elif inst in DRUM_KIT:
            files = glob.glob(os.path.join(self.root, DRUM_KIT[inst]))
            bank = []
            for f in files:
                b = os.path.basename(f)
                m = re.search(r"_v(\d+)", b)
                d = re.search(r"_(ppp|pp|p|mp|mf|f|ff|fff)_", b)
                vel = int(m.group(1)) if m else (DYN[d.group(1)] if d else 1)
                bank.append((0.0, vel, f))
        else:
            files = glob.glob(os.path.join(self.root, PITCHED[inst][art]))
            bank = []
            for f in files:
                tokens = re.split(r"[_\-]", os.path.basename(f)[:-4])
                note = next((t for t in tokens if re.fullmatch(r"[A-G]#?-?\d", t)), None)
                if note is None:
                    continue
                m = re.search(r"_v(\d+)", os.path.basename(f))
                midi = p(note.replace("#", "#")) + 12   # C3 = middle C in these names
                bank.append((float(midi), int(m.group(1)) if m else 1, f))
        if not bank:
            raise SystemExit("No samples for %s/%s under %s" % (inst, art, self.root))
        self.banks[key] = bank
        # The recordings sit at very different levels from one articulation
        # to the next: scale each set so its loudest layer peaks near 0.5.
        top = max(b[1] for b in bank)
        peaks = [np.abs(self._load(b[2])).max() for b in bank if b[1] == top]
        self.norm[key] = 0.5 / max(1e-4, float(np.median(peaks)))
        return bank

    def _load(self, f):
        if f not in self.cache:
            self.cache[f] = read_wav(f)
        return self.cache[f]

    def note(self, inst, art, pitch, vel):
        """A sample for this note, pitched by resampling. Returns (audio, pitch_ok)."""
        bank = self._bank(inst, art)
        if inst in DRUM_KIT:
            near = bank
        else:
            best = min(abs(b[0] - pitch) for b in bank)
            near = [b for b in bank if abs(abs(b[0] - pitch) - best) < 0.01]
            # Prefer shifting a sample up a little over down (keeps the attack crisp).
            ups = [b for b in near if b[0] <= pitch]
            near = ups or near
            nb = min(near, key=lambda b: abs(b[0] - pitch))[0]
            near = [b for b in near if b[0] == nb]
        layers = sorted({b[1] for b in near})
        pos = (vel - 1) / 126.0 * (len(layers) - 1)
        layer = layers[int(round(pos))]
        choice = self.rng.choice([b for b in near if b[1] == layer])
        x = self._load(choice[2]) * self.norm[(inst, art)]
        if inst in DRUM_KIT:
            return x
        ratio = 2 ** ((pitch - choice[0]) / 12.0)
        if abs(ratio - 1) < 1e-4:
            return x
        idx = np.arange(0, len(x) - 1, ratio)
        return np.stack([np.interp(idx, np.arange(len(x)), x[:, c]) for c in range(2)], axis=1)


# --- Score ----------------------------------------------------------------

class Score:
    """Notes per part, in beats. A part plays one instrument."""

    def __init__(self, tempo, beats):
        self.tempo = tempo
        self.beats = beats
        self.parts = {}
        self.rng = random.Random(11)

    def part(self, name, inst, gain=1.0, pan=0.0, reverb=0.3, art="auto"):
        """pan -1 (left) .. 1 (right); art 'auto' = sustained for long notes, staccato for short."""
        if name not in self.parts:
            self.parts[name] = {"inst": inst, "gain": gain, "pan": pan, "reverb": reverb, "art": art, "notes": []}
        return self.parts[name]

    def note(self, name, beat, dur, pitch, vel):
        self.parts[name]["notes"].append((beat, dur, pitch, vel))

    def line(self, name, start_beat, notes, vel=90, legato=0.92, unit=0.5, shift=0):
        """A melody: notes = [(pitch name | None, length in units)], unit in beats."""
        b = start_beat
        for nm, length in notes:
            d = length * unit
            if nm is not None:
                self.note(name, b, d * legato, p(nm) + shift, vel)
            b += d
        return b

    def seconds(self, beats):
        return beats * 60.0 / self.tempo


def render(score, names, sampler):
    """Mixes the listed parts: (dry, reverb send) stereo arrays."""
    n = int((score.seconds(score.beats) + TAIL) * SR)
    dry = np.zeros((n, 2))
    wet = np.zeros((n, 2))
    for name in names:
        part = score.parts.get(name)
        if part is None:
            continue
        inst = part["inst"]
        pan = part["pan"]
        lg, rg = np.cos((pan + 1) * np.pi / 4) * 1.414, np.sin((pan + 1) * np.pi / 4) * 1.414
        buf = np.zeros((n, 2))
        for beat, dur, pitch, vel in part["notes"]:
            art = part["art"]
            if art == "auto":
                art = "sus" if dur >= 0.45 else "stac"
            arts = PITCHED.get(inst, {"hit": None})
            if art not in arts:
                art = "stac" if "stac" in arts else next(iter(arts))
            x = sampler.note(inst, art, pitch, vel)
            secs = score.seconds(dur)
            if art == "sus":
                rel = 0.18
                keep = min(len(x), int((secs + rel) * SR))
                x = x[:keep].copy()
                fade_from = min(int(secs * SR), keep)
                if keep > fade_from:
                    x[fade_from:] *= np.linspace(1, 0, keep - fade_from)[:, None]
            else:
                keep = min(len(x), int(3.5 * SR))
                x = x[:keep].copy()
                if keep > 64:
                    x[-64:] *= np.linspace(1, 0, 64)[:, None]
            jit = score.rng.uniform(-0.006, 0.006) if beat > 0 else 0.0
            at = max(0, int((score.seconds(beat) + jit) * SR))
            g = (0.45 + 0.55 * vel / 127.0) * score.rng.uniform(0.94, 1.04)
            end = min(n, at + len(x))
            buf[at:end] += x[: end - at] * g
        buf[:, 0] *= lg * part["gain"]
        buf[:, 1] *= rg * part["gain"]
        dry += buf
        wet += buf * part["reverb"]
    return dry, wet


def hall_ir(seconds=2.4, seed=3):
    """A synthetic concert-hall impulse response: decaying, darkening noise."""
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = rng.standard_normal((n, 2)) * np.exp(-t * 6.9 / seconds)[:, None]
    # Darken the tail: blend towards a smoothed copy as time goes on.
    k = 24
    smooth = np.stack([np.convolve(ir[:, c], np.ones(k) / k, mode="same") for c in range(2)], axis=1)
    w = np.clip(t / seconds * 1.6, 0, 1)[:, None]
    ir = ir * (1 - w) + smooth * w * 3.0
    pre = np.zeros((int(0.022 * SR), 2))
    ir = np.vstack([pre, ir])
    return ir / np.sqrt((ir ** 2).sum(axis=0))


IR = None


def reverb(wet):
    global IR
    if IR is None:
        IR = hall_ir()
    out = np.stack([fftconvolve(wet[:, c], IR[:, c])[: len(wet)] for c in range(2)], axis=1)
    return out * 0.9


def mix(score, names, sampler):
    dry, wet = render(score, names, sampler)
    return dry + reverb(wet)


def fold_loop(x, loop_len):
    """Seamless loop: what rings past the loop end is added to its start."""
    out = x[:loop_len].copy()
    tail = x[loop_len:]
    out[: len(tail)] += tail[:loop_len]
    return out


def master(x, peak=0.9, drive=1.6):
    """Normalise with a gentle soft clip for punch (single tracks only)."""
    x = x / max(1e-9, np.abs(x).max())
    x = np.tanh(x * drive) / np.tanh(drive)
    return x * peak


def write_audio(x, path):
    x = np.clip(x, -1.0, 1.0)
    pcm = (x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmpwav = f.name
    with wave.open(tmpwav, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    args = ["ffmpeg", "-y", "-loglevel", "error", "-i", tmpwav]
    if path.endswith(".mp3"):
        args += ["-c:a", "libmp3lame", "-b:a", "192k", path]
    else:
        args += ["-c:a", "libvorbis", "-q:a", OGG_QUALITY, path]
    subprocess.run(args, check=True)
    os.remove(tmpwav)


# --- Harmony helpers ------------------------------------------------------

CHORDS = {  # pitch classes, root first
    "D": [2, 6, 9], "C": [0, 4, 7], "G": [7, 11, 2], "A": [9, 1, 4], "A7": [9, 1, 4, 7],
    "Bm": [11, 2, 6], "Em": [4, 7, 11], "Dm": [2, 5, 9], "Bb": [10, 2, 5], "F": [5, 9, 0],
    "Gm": [7, 10, 2], "Dsus": [2, 7, 9],
}
D_MIXO = [2, 4, 6, 7, 9, 11, 0]
D_MINOR = [2, 4, 5, 7, 9, 10, 0, 1]   # with the leading tone for A major


def in_range(pc, lo):
    return lo + ((pc - lo) % 12)


def voicing(chord, lo):
    return sorted(in_range(pc, lo) for pc in CHORDS[chord])


def bar_chords(bars):
    """Each bar as [first-half chord, second-half chord]."""
    return [c if isinstance(c, list) else [c, c] for c in bars]


def harmony_below(pitch, scale, steps=2):
    if pitch % 12 not in scale:
        return pitch - 3
    n = pitch
    for _ in range(steps):
        n -= 1
        while n % 12 not in scale:
            n -= 1
    return n


def harmonize(s, src, dst, scale, vel_scale=0.88, steps=2, start=0, end=10 ** 6):
    for beat, dur, pitch, vel in list(s.parts[src]["notes"]):
        if start <= beat < end:
            s.note(dst, beat, dur, harmony_below(pitch, scale, steps), int(vel * vel_scale))


def roll(s, part, start, beats, pitch, v0, v1, rate=8):
    """Snare or timpani roll: rate strokes a beat, crescendo v0 -> v1."""
    n = int(beats * rate)
    for k in range(n):
        s.note(part, start + k / rate, 0.9 / rate, pitch, int(v0 + (v1 - v0) * k / max(1, n - 1)))


def ostinato(s, part, bars, start_bar, lo, vel, pattern=(0, 0, 2, 0, 1, 0, 2, 0), step=0.5, accent=1.15):
    """Driving staccato strings: chord-tone indexes per step (0 root, 1 third, 2 fifth, +10 = octave up)."""
    per_bar = int(round(4 / step))
    for i, halves in enumerate(bar_chords(bars)):
        for k in range(per_bar):
            ch = halves[0 if k < per_bar // 2 else 1]
            tones = [in_range(CHORDS[ch][0], lo), in_range(CHORDS[ch][1], lo), in_range(CHORDS[ch][2], lo)]
            idx = pattern[k % len(pattern)]
            n = tones[idx % 10] + (12 if idx >= 10 else 0)
            v = vel * (accent if k % (per_bar // 4) == 0 else 1.0)
            s.note(part, (start_bar + i) * 4 + k * step, step * 0.8, n, int(min(127, v)))


def oompah(s, bass_part, bars, start_bar, lo, vel, beats=(0, 2)):
    for i, halves in enumerate(bar_chords(bars)):
        for b in beats:
            ch = halves[0 if b < 2 else 1]
            root = in_range(CHORDS[ch][0], lo)
            note = root if b == beats[0] or halves[0] != halves[1] else in_range(CHORDS[ch][2], lo)
            s.note(bass_part, (start_bar + i) * 4 + b, 0.4, note, vel)


def chord_hits(s, part, bars, start_bar, lo, vel, beats, dur=0.35):
    for i, halves in enumerate(bar_chords(bars)):
        for b in beats:
            ch = halves[0 if b < 2 else 1]
            for n in voicing(ch, lo):
                s.note(part, (start_bar + i) * 4 + b, dur, n, vel)


def pads(s, part, bars, start_bar, lo, vel):
    for i, halves in enumerate(bar_chords(bars)):
        if halves[0] == halves[1]:
            for n in voicing(halves[0], lo):
                s.note(part, (start_bar + i) * 4, 3.9, n, vel)
        else:
            for h, ch in enumerate(halves):
                for n in voicing(ch, lo):
                    s.note(part, (start_bar + i) * 4 + 2 * h, 1.9, n, vel)


def timp(s, part, pitch_class, beat, vel):
    """A timpani hit on the drum nearest the chord root."""
    best = min(range(40, 57), key=lambda m: (m % 12 != pitch_class, abs(m - 48)))
    s.note(part, beat, 1.0, best, vel)


# --- Menu theme: D major / mixolydian, 120 bpm, 16 bars ---------------------

MENU_A = ["D", "C", "G", "D", "D", "C", "G", "A"]
MENU_B = ["Bm", "G", "D", "A", "Bm", "G", "G", "A"]


def menu_theme():
    s = Score(120, 64)
    s.part("horns", "horn", 1.0, -0.2, 0.42)
    s.part("horns2", "horn", 0.8, -0.35, 0.42)
    s.part("trumpets", "trumpet", 0.85, 0.3, 0.35)
    s.part("trumpets2", "trumpet", 0.6, 0.45, 0.35)
    s.part("trombones", "trombone", 1.6, 0.25, 0.35, art="stac")
    s.part("tuba", "tuba", 0.9, 0.05, 0.2, art="stac")
    s.part("basses", "basses", 0.8, 0.15, 0.2, art="pizz")
    s.part("cellos", "cellos", 0.85, 0.3, 0.25, art="stac")
    s.part("violas", "violas", 0.55, 0.15, 0.3, art="stac")
    s.part("violins", "violins", 0.55, -0.45, 0.4, art="sus")
    s.part("vpizz", "violins", 0.55, -0.5, 0.3, art="pizz")
    s.part("flute", "flute", 0.45, -0.1, 0.4, art="stac")
    s.part("piccolo", "piccolo", 0.5, 0.0, 0.4)
    s.part("glock", "glock", 0.7, 0.35, 0.45, art="hit")
    s.part("xylo", "xylo", 0.45, 0.4, 0.35, art="hit")
    s.part("snare", "snare", 1.2, 0.05, 0.25, art="hit")
    s.part("kick", "kick", 0.9, 0.0, 0.3, art="hit")
    s.part("crash", "crash", 1.0, -0.1, 0.4, art="hit")
    s.part("timpani", "timpani", 0.9, -0.05, 0.35, art="hit")
    bars = MENU_A + MENU_B

    # A: unison horns carry the heroic tune; pizzicato and flute keep it light.
    tune_a = [
        ("A3", 1), ("D4", 1), ("F#4", 1), ("A4", 1), ("D5", 3), ("A4", 1),
        ("G4", 2), ("E4", 1), ("G4", 1), ("C5", 3), ("G4", 1),
        ("B4", 1), ("A4", 1), ("G4", 1), ("F#4", 1), ("G4", 2), ("D4", 2),
        ("F#4", 3), ("E4", 1), ("D4", 3), (None, 1),
        ("A3", 1), ("D4", 1), ("F#4", 1), ("A4", 1), ("D5", 3), ("E5", 1),
        ("E5", 2), ("D5", 1), ("C5", 1), ("G4", 2), ("E4", 2),
        ("D5", 3), ("C5", 1), ("B4", 1), ("A4", 1), ("B4", 2),
        ("A4", 6), (None, 1), ("A4", 1),
    ]
    s.line("horns", 0, tune_a, vel=100, legato=0.9)
    s.line("horns2", 0, tune_a, vel=88, legato=0.9, shift=-12)
    s.line("flute", 0, tune_a, vel=70, legato=0.5, shift=12)
    # B: trumpets take the tune up, horns harmonise, the band fills in.
    tune_b = [
        ("B4", 1), ("D5", 1), ("F#5", 3), ("E5", 1), ("D5", 2),
        ("D5", 1), ("B4", 1), ("G4", 3), ("A4", 1), ("B4", 2),
        ("A4", 1), ("D5", 1), ("F#5", 3), ("G5", 1), ("A5", 2),
        ("E5", 3), ("C#5", 1), ("A4", 4),
        ("B4", 1), ("D5", 1), ("F#5", 3), ("E5", 1), ("D5", 2),
        ("G5", 3), ("F#5", 1), ("E5", 1), ("D5", 1), ("B4", 2),
        ("D5", 1), ("E5", 1), ("F#5", 1), ("G5", 1), ("A5", 3), ("G5", 1),
        ("A5", 4), ("E5", 2), ("C#5", 1), (None, 1),
    ]
    s.line("trumpets", 32, tune_b, vel=104, legato=0.88)
    s.line("horns", 32, tune_b, vel=96, legato=0.9, shift=-12)
    harmonize(s, "trumpets", "trumpets2", D_MIXO, 0.85)
    harmonize(s, "trumpets", "horns2", D_MIXO, 0.9, start=32)
    for k in range(len(s.parts["horns2"]["notes"])):
        b, d, pt, v = s.parts["horns2"]["notes"][k]
        if b >= 32:
            s.parts["horns2"]["notes"][k] = (b, d, pt - 12, v)

    # Engine room: cellos drive eighths, tuba and pizz basses oom on 1 and 3.
    ostinato(s, "cellos", bars, 0, 38, 84)
    oompah(s, "tuba", bars, 0, 33, 96)
    oompah(s, "basses", bars, 0, 33, 92)
    chord_hits(s, "vpizz", MENU_A, 0, 62, 80, (1, 3), 0.3)
    chord_hits(s, "violas", MENU_B, 8, 57, 80, (0.5, 1.5, 2.5, 3.5), 0.2)
    chord_hits(s, "trombones", MENU_B, 8, 50, 92, (0, 2.5))
    pads(s, "violins", MENU_B, 8, 66, 74)
    # Piccolo answers and xylophone sparkles at the phrase ends.
    for start, notes in ((14, ["D6", "E6", "F#6", "G6", "A6", "B6", "A6", "F#6"]),
                         (30, ["A5", "B5", "C#6", "D6", "E6", "F#6", "G6", "A6"]),
                         (46, ["F#6", "E6", "D6", "C#6", "D6", "E6", "F#6", "A6"]),
                         (62, ["A6", "G6", "F#6", "E6", "D6", "C#6", "B5", "A5"])):
        for k, nm in enumerate(notes):
            s.note("piccolo", start + k * 0.25, 0.2, p(nm), 86)
            s.note("xylo", start + k * 0.25, 0.2, p(nm) - 12, 88)
    for bar in range(8, 16):
        s.note("glock", bar * 4, 0.5, in_range(CHORDS[MENU_B[bar - 8]][0], 74), 70)
    # March: snare, bass drum, crashes, timpani.
    for bar in range(16):
        b = bar * 4
        if bar < 8:
            pat = [(0, 70), (1, 90), (1.75, 55), (2, 70), (3, 92), (3.5, 60)]
        else:
            pat = [(0, 100), (0.75, 60), (1, 92), (1.5, 70), (2, 96), (2.5, 66), (2.75, 70), (3, 98), (3.5, 74), (3.75, 80)]
        for k, v in pat:
            s.note("snare", b + k, 0.2, 0, v)
        s.note("kick", b, 0.5, 0, 100)
        if bar >= 8:
            s.note("kick", b + 2, 0.5, 0, 86)
            timp(s, "timpani", CHORDS[MENU_B[bar - 8]][0], b, 104)
    roll(s, "snare", 30, 2, 0, 50, 110)
    roll(s, "snare", 62, 2, 0, 50, 112)
    roll(s, "timpani", 30, 2, p("A2"), 50, 110)
    for b, v in ((0, 80), (32, 118), (48, 96)):
        s.note("crash", b, 3, 0, v)
    return s


# --- Battle loop: D minor, 140 bpm, 16 bars, three stems -------------------

BATTLE = ["Dm", "C", "Bb", "C", "Dm", "C", "Bb", "A",
          "Dm", "Bb", "F", "C", "Gm", "Bb", "C", "A"]


def battle():
    s = Score(140, 64)
    # Base stem.
    s.part("horns", "horn", 1.0, -0.2, 0.4)
    s.part("horns2", "horn", 0.75, -0.35, 0.4)
    s.part("trumpets", "trumpet", 0.85, 0.3, 0.35)
    s.part("cellos", "cellos", 0.95, 0.3, 0.25, art="stac")
    s.part("violas", "violas", 0.6, 0.15, 0.3, art="stac")
    s.part("tuba", "tuba", 0.9, 0.05, 0.2, art="stac")
    s.part("basses", "basses", 0.8, 0.15, 0.2, art="pizz")
    s.part("bassoon", "bassoon", 0.55, -0.15, 0.25, art="stac")
    s.part("xylo", "xylo", 0.5, 0.4, 0.35, art="hit")
    s.part("piccolo", "piccolo", 0.5, 0.0, 0.4)
    s.part("snare_l", "snare", 1.1, 0.05, 0.25, art="hit")
    s.part("timp_l", "timpani", 0.8, -0.05, 0.35, art="hit")
    tune = [
        ("D4", 3), ("D4", 1), ("F4", 2), ("A4", 2),
        ("G4", 3), ("F4", 1), ("E4", 2), ("C4", 2),
        ("D4", 3), ("F4", 1), ("Bb4", 2), ("A4", 1), ("G4", 1),
        ("E4", 4), ("G4", 2), ("C5", 2),
        ("D5", 3), ("C5", 1), ("A4", 2), ("F4", 2),
        ("G4", 3), ("A4", 1), ("G4", 2), ("E4", 2),
        ("F4", 2), ("G4", 1), ("A4", 1), ("Bb4", 2), ("D5", 2),
        ("C#5", 4), ("E5", 2), ("A4", 2),
    ]
    s.line("horns", 0, tune, vel=104, legato=0.88)
    s.line("horns2", 0, tune, vel=90, legato=0.88, shift=-12)
    reprise = [
        ("A4", 1), ("D5", 1), ("F5", 3), ("E5", 1), ("D5", 2),
        ("F5", 3), ("D5", 1), ("Bb4", 4),
        ("A4", 1), ("C5", 1), ("F5", 3), ("G5", 1), ("A5", 2),
        ("G5", 3), ("E5", 1), ("C5", 4),
        ("Bb4", 1), ("D5", 1), ("G5", 3), ("F5", 1), ("D5", 2),
        ("F5", 3), ("D5", 1), ("Bb4", 2), ("D5", 2),
        ("E5", 2), ("G5", 2), ("C6", 2), ("Bb5", 2),
        ("A5", 4), ("E5", 2), ("C#5", 1), (None, 1),
    ]
    s.line("trumpets", 32, reprise, vel=106, legato=0.86)
    s.line("horns", 32, reprise, vel=98, legato=0.88, shift=-12)
    harmonize(s, "trumpets", "horns2", D_MINOR, 0.9)
    for k in range(len(s.parts["horns2"]["notes"])):
        b, d, pt, v = s.parts["horns2"]["notes"][k]
        if b >= 32:
            s.parts["horns2"]["notes"][k] = (b, d, pt - 12, v)
    ostinato(s, "cellos", BATTLE, 0, 38, 88, pattern=(0, 0, 10, 0, 2, 0, 10, 2))
    chord_hits(s, "violas", BATTLE, 0, 57, 78, (0.5, 1.5, 2.5, 3.5), 0.2)
    oompah(s, "tuba", BATTLE, 0, 33, 98)
    oompah(s, "basses", BATTLE, 0, 33, 92)
    oompah(s, "bassoon", BATTLE, 0, 45, 80, beats=(1.5, 3.5))
    for start, notes in ((14, ["D6", "E6", "F6", "G6", "A6", "Bb6", "A6", "G6"]),
                         (30, ["E6", "F6", "G6", "A6", "Bb6", "C#7", "D7", "E7"]),
                         (46, ["C6", "D6", "E6", "F6", "G6", "A6", "Bb6", "C7"]),
                         (62, ["A6", "G6", "F6", "E6", "D6", "C#6", "B5", "A5"])):
        for k, nm in enumerate(notes):
            s.note("piccolo", start + k * 0.25, 0.2, p(nm), 90)
            s.note("xylo", start + k * 0.25, 0.2, p(nm) - 12, 92)
    for i, ch in enumerate(BATTLE):
        b = i * 4
        s.note("snare_l", b + 1, 0.2, 0, 76)
        s.note("snare_l", b + 3, 0.2, 0, 80)
        timp(s, "timp_l", CHORDS[ch][0], b, 96)

    # Drums stem: march snare, bass drum on every beat, tambourine, crashes.
    s.part("snare", "snare", 1.1, 0.05, 0.25, art="hit")
    s.part("kick", "kick", 1.0, 0.0, 0.3, art="hit")
    s.part("tamb", "tamb", 0.45, 0.5, 0.3, art="hit")
    s.part("crash", "crash", 1.0, -0.1, 0.4, art="hit")
    s.part("timpani", "timpani", 1.5, -0.05, 0.35, art="hit")
    for i, ch in enumerate(BATTLE):
        b = i * 4
        for k, v in ((0, 104), (0.5, 60), (0.75, 72), (1, 96), (1.5, 66), (2, 100), (2.25, 60),
                     (2.5, 74), (3, 98), (3.25, 62), (3.5, 82), (3.75, 88)):
            s.note("snare", b + k, 0.15, 0, v)
        for k in range(4):
            s.note("kick", b + k, 0.4, 0, 110 if k % 2 == 0 else 86)
            s.note("tamb", b + k + 0.5, 0.2, 0, 80)
        for k in (0.5, 1.5, 2.5, 3.5):
            timp(s, "timpani", CHORDS[ch][2], b + k, 74)
        if i % 4 == 0:
            s.note("crash", b, 3, 0, 110)
    roll(s, "snare", 62, 2, 0, 60, 120)

    # Tension stem: racing violins, low brass stabs, trumpet calls.
    s.part("violins", "violins", 0.45, -0.45, 0.3, art="stac")
    s.part("trombones", "trombone", 1.5, 0.25, 0.35, art="stac")
    s.part("tpt_stabs", "trumpet", 0.4, 0.45, 0.35, art="stac")
    s.part("swell", "swell", 1.0, 0.0, 0.4, art="hit")
    ostinato(s, "violins", BATTLE, 0, 62, 92, pattern=(0, 10, 2, 10, 1, 10, 2, 10), step=0.25)
    chord_hits(s, "trombones", BATTLE, 0, 50, 104, (0, 1.5, 3), 0.3)
    for i, ch in enumerate(BATTLE[:8]):
        if i % 2 == 0:
            top = voicing(ch, 69)
            for k, v in ((2.5, 96), (2.75, 96), (3, 110)):
                for n in top:
                    s.note("tpt_stabs", i * 4 + k, 0.2, n, v)
    s.note("swell", 60, 4, 0, 100)
    return s


BATTLE_STEMS = {
    "battle_base": ["horns", "horns2", "trumpets", "cellos", "violas", "tuba", "basses", "bassoon", "xylo",
                    "piccolo", "snare_l", "timp_l"],
    "battle_drums": ["snare", "kick", "tamb", "crash", "timpani"],
    "battle_tension": ["violins", "trombones", "tpt_stabs", "swell"],
}


# --- Stingers -------------------------------------------------------------

def band(s, extra=()):
    s.part("horns", "horn", 1.0, -0.2, 0.42)
    s.part("horns2", "horn", 0.8, -0.35, 0.42)
    s.part("trumpets", "trumpet", 0.9, 0.3, 0.38)
    s.part("trombones", "trombone", 0.8, 0.25, 0.38)
    s.part("tuba", "tuba", 0.9, 0.05, 0.25)
    s.part("violins", "violins", 0.6, -0.45, 0.4, art="sus")
    s.part("cellos", "cellos", 0.7, 0.3, 0.3, art="sus")
    s.part("snare", "snare", 0.8, 0.05, 0.25, art="hit")
    s.part("kick", "kick", 0.9, 0.0, 0.3, art="hit")
    s.part("crash", "crash", 0.6, -0.1, 0.45, art="hit")
    s.part("timpani", "timpani", 0.9, -0.05, 0.38, art="hit")
    s.part("glock", "glock", 0.4, 0.35, 0.5, art="hit")
    s.part("xylo", "xylo", 0.5, 0.4, 0.4, art="hit")
    s.part("piccolo", "piccolo", 0.5, 0.0, 0.45)
    s.part("oboe", "oboe", 0.8, -0.1, 0.45, art="sus")
    s.part("bassoon", "bassoon", 0.7, -0.15, 0.3, art="stac")


def held_chord(s, beat, dur, ch, vel, low=True):
    for n in voicing(ch, 62):
        s.note("violins", beat, dur, n, vel)
    for n in voicing(ch, 50):
        s.note("trombones", beat, dur, n, vel)
    if low:
        s.note("cellos", beat, dur, in_range(CHORDS[ch][0], 38), vel)
        s.note("tuba", beat, dur, in_range(CHORDS[ch][0], 33), vel)


def sting_match_start():
    s = Score(132, 6)
    band(s)
    call = [("A4", 1 / 3), ("A4", 1 / 3), ("A4", 1 / 3), ("A4", 0.5), ("C5", 0.5), ("D5", 3.5)]
    s.line("trumpets", 0, call, vel=110, legato=0.85, unit=1)
    s.line("horns", 0, call, vel=104, legato=0.85, unit=1, shift=-12)
    harmonize(s, "trumpets", "horns2", D_MIXO, 0.9)
    held_chord(s, 0, 1.9, "C", 96)
    held_chord(s, 2, 3.5, "D", 112)
    roll(s, "snare", 0, 2, 0, 50, 118)
    roll(s, "timpani", 0, 2, p("A2"), 50, 116)
    timp(s, "timpani", 2, 2, 124)
    s.note("kick", 2, 1, 0, 120)
    s.note("crash", 2, 3, 0, 124)
    for k, nm in enumerate(["D6", "F#6", "A6", "D7"]):
        s.note("glock", 2 + k * 0.125, 0.5, p(nm) - 12, 96)
    return s


def sting_crown_captured():
    s = Score(140, 7)
    band(s)
    s.line("trumpets", 0, [("D5", 0.25), ("F#5", 0.25), ("A5", 0.25), ("D6", 0.25), ("C6", 1), ("B5", 1), ("A5", 3)],
           vel=112, legato=0.9, unit=1)
    s.line("horns", 0, [("A4", 1), ("G4", 1), ("G4", 1), ("F#4", 3)], vel=104, legato=0.9, unit=1)
    s.line("piccolo", 0, [("D6", 0.25), ("F#6", 0.25), ("A6", 0.25), ("D7", 0.25)], vel=90, legato=0.9, unit=1)
    held_chord(s, 1, 0.95, "C", 104)
    held_chord(s, 2, 0.95, "G", 108)
    held_chord(s, 3, 3, "D", 116)
    for beat, pc in ((1, 0), (2, 7), (3, 2)):
        timp(s, "timpani", pc, beat, 116)
        s.note("kick", beat, 0.5, 0, 110)
    s.note("snare", 1, 0.2, 0, 100); s.note("snare", 2, 0.2, 0, 104)
    roll(s, "snare", 2.5, 0.5, 0, 80, 118)
    s.note("crash", 3, 3, 0, 124)
    for k, nm in enumerate(["D6", "A5", "F#5", "D5", "F#5", "A5", "D6"]):
        s.note("glock", 3 + k * 0.125, 0.4, p(nm), 92)
        s.note("xylo", 3 + k * 0.125, 0.2, p(nm) - 12, 90)
    return s


def sting_crown_lost():
    s = Score(96, 6)
    band(s)
    s.line("trombones", 0, [("D4", 1), ("C#4", 1), ("C4", 1), ("B3", 2.5)], vel=104, legato=0.95, unit=1)
    s.line("horns", 0, [("F4", 1), ("E4", 1), ("Eb4", 1), ("D4", 2.5)], vel=92, legato=0.95, unit=1)
    s.line("bassoon", 0, [("D3", 1), ("C#3", 1), ("C3", 1), ("B2", 1)], vel=86, legato=0.6, unit=1)
    for n in voicing("Dm", 62):
        s.note("violins", 0, 3, n, 70)
    s.note("tuba", 3, 2.5, p("G1"), 96)
    s.note("cellos", 3, 2.5, p("G2"), 90)
    roll(s, "timpani", 1.5, 1.5, p("D2"), 40, 96)
    timp(s, "timpani", 7, 3, 108)
    s.note("kick", 3, 1, 0, 96)
    return s


def sting_victory():
    s = Score(120, 12)
    band(s)
    tune = [("A4", 0.5), ("D5", 0.5), ("F#5", 0.5), ("A5", 1.5),
            ("G5", 0.5), ("A5", 0.5), ("B5", 0.5), ("C6", 0.5),
            ("D6", 2), (None, 0.5), ("A5", 0.25), ("B5", 0.25), ("C6", 0.5), ("D6", 4.5)]
    s.line("trumpets", 0, tune, vel=112, legato=0.88, unit=1, shift=-12)
    s.line("horns", 0, tune, vel=106, legato=0.88, unit=1, shift=-12)
    harmonize(s, "horns", "horns2", D_MIXO, 0.9)
    s.line("piccolo", 0, tune, vel=84, legato=0.6, unit=1)
    plan = [(0, 3, "D"), (3, 1, "G"), (4, 1, "C"), (5, 2, "D"), (7, 1, "C"), (8, 4, "D")]
    for beat, dur, ch in plan:
        held_chord(s, beat, dur * 0.97, ch, 108)
        timp(s, "timpani", CHORDS[ch][0], beat, 112)
    for k in range(7):
        s.note("snare", k, 0.2, 0, 84 if k % 2 else 100)
        s.note("kick", k, 0.4, 0, 100 if k % 2 == 0 else 76)
    roll(s, "snare", 7, 1, 0, 70, 122)
    roll(s, "timpani", 7, 1, p("A2"), 70, 122)
    s.note("crash", 0, 2, 0, 110)
    s.note("crash", 5, 2, 0, 110)
    s.note("crash", 8, 4, 0, 127)
    s.note("kick", 8, 1, 0, 124)
    for k, nm in enumerate(["D6", "F#6", "A6", "D7", "A6", "F#6", "A6", "D7"]):
        s.note("glock", 8 + k * 0.125, 0.5, p(nm) - 12, 96)
        s.note("xylo", 8 + k * 0.125, 0.2, p(nm) - 12, 92)
    return s


def sting_defeat():
    s = Score(76, 9)
    band(s)
    s.line("oboe", 0, [("A4", 1), ("G4", 0.5), ("F4", 0.5), ("E4", 1), ("F4", 0.5), ("E4", 0.5), ("D4", 4)],
           vel=96, legato=0.97, unit=1)
    s.line("bassoon", 0, [("D3", 2), ("Bb2", 1), ("A2", 1), ("D2", 1)], vel=82, legato=0.8, unit=1)
    for beat, dur, ch in ((0, 2, "Dm"), (2, 1, "Gm"), (3, 1, "A"), (4, 4, "Dm")):
        for n in voicing(ch, 62):
            s.note("violins", beat, dur, n, 66)
        s.note("cellos", beat, dur, in_range(CHORDS[ch][0], 38), 70)
    s.line("horns", 2, [("Bb3", 1), ("A3", 1), ("A3", 4)], vel=78, legato=0.97, unit=1)
    roll(s, "timpani", 3, 1, p("A2"), 30, 80)
    timp(s, "timpani", 2, 4, 86)
    s.note("tuba", 7.5, 0.4, p("D2"), 100)
    return s


STINGS = {
    "sting_match_start": sting_match_start,
    "sting_crown_captured": sting_crown_captured,
    "sting_crown_lost": sting_crown_lost,
    "sting_victory": sting_victory,
    "sting_defeat": sting_defeat,
}


def main():
    if "--sparse-paths" in sys.argv:
        print(" ".join("'%s'" % x for x in SPARSE))
        return
    if "--samples" not in sys.argv:
        raise SystemExit("usage: make_music.py --samples /path/to/VSCO-2-CE [--preview DIR]")
    sampler = Sampler(sys.argv[sys.argv.index("--samples") + 1])
    preview = None
    if "--preview" in sys.argv:
        preview = sys.argv[sys.argv.index("--preview") + 1]
        os.makedirs(preview, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)

    s = menu_theme()
    n = int(round(s.seconds(s.beats) * SR))
    menu = master(fold_loop(mix(s, list(s.parts), sampler), n))
    write_audio(menu, os.path.join(OUT, "menu.ogg"))

    s = battle()
    n = int(round(s.seconds(s.beats) * SR))
    stems = {k: fold_loop(mix(s, v, sampler), n) for k, v in BATTLE_STEMS.items()}
    # One gain for all stems so their balance holds when layered; each stem
    # then gets the same gentle soft clip for punch.
    full = sum(stems.values())
    g = 1.25 / np.max(np.abs(full))
    drive = 1.4
    stems = {k: np.tanh(x * g * drive) / np.tanh(drive) * 0.8 for k, x in stems.items()}
    for k, x in stems.items():
        write_audio(x, os.path.join(OUT, k + ".ogg"))

    stings = {}
    for k, fn in STINGS.items():
        st = fn()
        x = mix(st, list(st.parts), sampler)
        x = x[: int((st.seconds(st.beats) + 1.6) * SR)]
        fade = int(0.8 * SR)
        x[-fade:] *= np.linspace(1, 0, fade)[:, None]
        stings[k] = master(x)
        write_audio(stings[k], os.path.join(OUT, k + ".ogg"))

    if preview:
        write_audio(np.vstack([menu, menu]), os.path.join(preview, "1-menu-theme.mp3"))
        b, d, t = (stems[k] for k in BATTLE_STEMS)
        demo = np.vstack([b, b + d, b + d + t])
        write_audio(demo * (0.95 / np.abs(demo).max()), os.path.join(preview, "2-battle-calm-then-door-then-crown-stolen.mp3"))
        gap = np.zeros((int(1.2 * SR), 2))
        write_audio(np.vstack([np.vstack([stings[k], gap]) for k in STINGS]),
                    os.path.join(preview, "3-stingers-start-captured-lost-victory-defeat.mp3"))
    for f in sorted(os.listdir(OUT)):
        if f.endswith(".ogg"):
            print("%-28s %6.0f KB" % (f, os.path.getsize(os.path.join(OUT, f)) / 1024))


if __name__ == "__main__":
    main()
