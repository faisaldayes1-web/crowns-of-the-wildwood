#!/usr/bin/env python3
"""Composes and renders the game's music: a bouncy orchestral fantasy style
(brass fanfares, pizzicato strings, snare and timpani, playful woodwinds).
Every note here is original and written out below; nothing is sampled from
another piece of music.

Pipeline: the score below -> one MIDI file per stem (mido) -> rendered by
FluidSynth with the FluidR3_GM soundfont (MIT licence, see assets/CREDITS.md)
-> loop tails folded back to the start so loops are seamless -> .ogg (Vorbis)
in assets/music/. Only the rendered .ogg files ship with the game.

Needs: pip install mido numpy; apt-get install fluidsynth fluid-soundfont-gm
ffmpeg. Run:  python3 tools/make_music.py [--preview DIR]
--preview also writes listening mixes (mp3) into DIR.

Tracks
  menu.ogg                     title / menus theme, loops
  battle_base.ogg              in-match loop, always playing
  battle_drums.ogg             + march snare, bass drum, timpani (door under attack)
  battle_tension.ogg           + spiccato strings, low brass stabs (crown stolen)
  sting_*.ogg                  match start, crown captured, crown lost, victory, defeat
The three battle stems are sample-for-sample the same length and play in sync.
"""
import os, random, subprocess, sys, tempfile, wave
import numpy as np
import mido

SR = 44100
SF2 = "/usr/share/sounds/sf2/FluidR3_GM.sf2"
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "music")
TAIL = 3.0          # seconds rendered past the end for reverb / ringing notes
OGG_QUALITY = "2"   # libvorbis -q: ~80-96 kbps stereo, small enough for the web build

# General MIDI programs (0-based) and the drum channel's orchestra kit.
GLOCK, XYLO, STRINGS, TREMOLO, PIZZ, HARP, TIMPANI = 9, 13, 48, 44, 45, 46, 47
TRUMPET, TROMBONE, TUBA, HORN, BRASS = 56, 57, 58, 60, 61
OBOE, BASSOON, CLARINET, PICCOLO, FLUTE = 68, 70, 71, 72, 73
DRUMS = "drums"
SNARE, KICK, CRASH, SIDESTICK = 38, 36, 49, 37

NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def p(name):
    """'Bb4' -> MIDI note number (C4 = 60)."""
    pc = NAMES[name[0]]
    rest = name[1:]
    while rest and rest[0] in "b#":
        pc += -1 if rest[0] == "b" else 1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + pc


CHORDS = {  # pitch classes, root first
    "Bb": [10, 2, 5], "Eb": [3, 7, 10], "F": [5, 9, 0], "F7": [5, 9, 0, 3],
    "Gm": [7, 10, 2], "Cm": [0, 3, 7], "C7": [0, 4, 7, 10], "D": [2, 6, 9],
    "Dsus": [2, 7, 9], "Ab": [8, 0, 3],
}


def in_range(pc, lo):
    """The pitch of class pc at or just above lo."""
    n = lo + ((pc - lo) % 12)
    return n


def voicing(chord, lo):
    """Close-position chord tones from lo upwards (root, third, fifth...)."""
    return sorted(in_range(pc, lo) for pc in CHORDS[chord])


class Score:
    """Notes per instrument, in beats. A stem is a set of instruments."""

    def __init__(self, tempo, beats):
        self.tempo = tempo
        self.beats = beats
        self.parts = {}   # name -> dict(program, vol, pan, notes=[(beat, dur, pitch, vel)])
        self.rng = random.Random(11)

    def part(self, name, program, vol=100, pan=64):
        if name not in self.parts:
            self.parts[name] = {"program": program, "vol": vol, "pan": pan, "notes": []}
        return self.parts[name]

    def note(self, name, beat, dur, pitch, vel):
        self.parts[name]["notes"].append((beat, dur, pitch, vel))

    def line(self, name, start_beat, notes, vel=90, legato=0.9, unit=0.5, shift=0):
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

    def midi(self, names, path):
        """Writes the listed parts (one channel each) as a type-1 MIDI file."""
        tpb = 480
        mf = mido.MidiFile(type=1, ticks_per_beat=tpb)
        meta = mido.MidiTrack()
        meta.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(self.tempo), time=0))
        end_tick = int((self.beats + TAIL * self.tempo / 60.0) * tpb)
        meta.append(mido.MetaMessage("end_of_track", time=end_tick))
        mf.tracks.append(meta)
        chan = 0
        for name in names:
            part = self.parts.get(name)
            if part is None:
                continue
            if part["program"] == DRUMS:
                ch = 9
            else:
                ch = chan if chan < 9 else chan + 1
                chan += 1
            tr = mido.MidiTrack()
            events = [(0, mido.Message("control_change", channel=ch, control=7, value=part["vol"])),
                      (0, mido.Message("control_change", channel=ch, control=10, value=part["pan"])),
                      (0, mido.Message("control_change", channel=ch, control=91, value=50)),
                      (0, mido.Message("program_change", channel=ch, program=48 if ch == 9 else part["program"]))]
            for beat, dur, pitch, vel in part["notes"]:
                # A touch of human timing and dynamics.
                jit = self.rng.uniform(-0.012, 0.012) if beat > 0 else 0.0
                on = max(0, int((beat + jit) * tpb))
                off = max(on + 1, int((beat + dur) * tpb))
                v = max(1, min(127, int(vel + self.rng.uniform(-6, 6))))
                events.append((on, mido.Message("note_on", channel=ch, note=pitch, velocity=v)))
                events.append((off, mido.Message("note_off", channel=ch, note=pitch, velocity=0)))
            events.sort(key=lambda e: (e[0], 0 if e[1].type == "note_off" else 1))
            last = 0
            for tick, msg in events:
                tr.append(msg.copy(time=tick - last))
                last = tick
            mf.tracks.append(tr)
        mf.save(path)


def render(score, names, tmp, tag):
    """MIDI -> float stereo array (samples, 2) via FluidSynth."""
    mid = os.path.join(tmp, tag + ".mid")
    wav = os.path.join(tmp, tag + ".wav")
    score.midi(names, mid)
    subprocess.run(["fluidsynth", "-ni", "-q", "-g", "0.5", "-r", str(SR), "-F", wav, SF2, mid],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    with wave.open(wav) as w:
        data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).reshape(-1, 2)
    return data.astype(np.float64) / 32768.0


def fit(x, n):
    if len(x) >= n:
        return x[:n]
    return np.vstack([x, np.zeros((n - len(x), 2))])


def fold_loop(x, loop_len):
    """Seamless loop: what rings past the loop end is added to its start."""
    x = fit(x, loop_len + int(TAIL * SR))
    out = x[:loop_len].copy()
    out[: len(x) - loop_len] += x[loop_len:]
    return out


def write_ogg(x, path, peak=None):
    x = np.clip(x, -1.0, 1.0)
    pcm = (x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmpwav = f.name
    with wave.open(tmpwav, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    args = ["ffmpeg", "-y", "-loglevel", "error", "-i", tmpwav]
    if path.endswith(".mp3"):
        args += ["-c:a", "libmp3lame", "-b:a", "160k", path]
    else:
        args += ["-c:a", "libvorbis", "-q:a", OGG_QUALITY, path]
    subprocess.run(args, check=True)
    os.remove(tmpwav)


# --- Shared figures -------------------------------------------------------

def oompah(s, bars, bass="tuba", chord_part="pizz", bass_lo=34, chord_lo=55, vel=80):
    """Oom-pah: bass on 1 and 3 (root, fifth), short chords on 2 and 4.
    bars = list of chord names; a bar may be a [first half, second half] pair."""
    for i, c in enumerate(bars):
        halves = c if isinstance(c, list) else [c, c]
        for h, ch in enumerate(halves):
            b = i * 4 + h * 2
            root = in_range(CHORDS[ch][0], bass_lo)
            low = root if h == 0 or halves[0] != halves[1] else in_range(CHORDS[ch][2], bass_lo)
            s.note(bass, b, 0.6, low, vel)
            for n in voicing(ch, chord_lo):
                s.note(chord_part, b + 1, 0.3, n, vel - 15)


def pad(s, part, bars, lo, vel):
    for i, c in enumerate(bars):
        halves = c if isinstance(c, list) else [c]
        for h, ch in enumerate(halves):
            d = 4 / len(halves)
            for n in voicing(ch, lo):
                s.note(part, i * 4 + h * d, d * 0.98, n, vel)


def roll(s, part, start, beats, pitch, v0, v1, rate=6):
    """A drum or timpani roll: rate strokes a beat, crescendo v0 -> v1."""
    n = int(beats * rate)
    for k in range(n):
        s.note(part, start + k / rate, 0.9 / rate, pitch, int(v0 + (v1 - v0) * k / max(1, n - 1)))


BB_MAJOR = [10, 0, 2, 3, 5, 7, 9]
G_MINOR = [7, 9, 10, 0, 2, 3, 5]


def harmony_below(pitch, scale, steps=2):
    """The scale note `steps` scale degrees under pitch (a third by default)."""
    pc = pitch % 12
    if pc not in scale:
        return pitch - 3
    n = pitch
    for _ in range(steps):
        n -= 1
        while n % 12 not in scale:
            n -= 1
    return n


def harmonize(s, src, dst, scale, vel_scale=0.85, steps=2):
    for beat, dur, pitch, vel in list(s.parts[src]["notes"]):
        s.note(dst, beat, dur, harmony_below(pitch, scale, steps), int(vel * vel_scale))


# --- Menu theme: Bb major, 112 bpm, 16 bars --------------------------------

def menu_theme():
    s = Score(112, 64)
    A = ["Bb", "Eb", "F", "Bb", "Gm", "Eb", "C7", "F"]
    B = ["Bb", "Eb", "F", "Gm", "Eb", "F", ["Bb", "Gm"], ["Cm", "F7"]]
    s.part("tuba", TUBA, 92, 60)
    s.part("pizz", PIZZ, 100, 40)
    s.part("strings", STRINGS, 72, 44)
    s.part("flute", FLUTE, 100, 78)
    s.part("oboe", OBOE, 95, 70)
    s.part("clarinet", CLARINET, 92, 52)
    s.part("glock", GLOCK, 110, 84)
    s.part("trumpet", TRUMPET, 100, 88)
    s.part("horn", HORN, 105, 76)
    s.part("timpani", TIMPANI, 100, 64)
    s.part("drums", DRUMS, 92, 64)
    oompah(s, A + B, vel=78)
    # Section A: the woodwinds carry a playful tune over the pizzicato.
    a_tune = [
        ("F5", 1), (None, 1), ("D5", 1), ("F5", 1), ("Bb5", 2), ("A5", 1), ("G5", 1),
        ("G5", 1), (None, 1), ("Eb5", 1), ("G5", 1), ("Bb5", 2), ("G5", 2),
        ("A5", 1), ("G5", 1), ("F5", 1), ("Eb5", 1), ("D5", 1), ("Eb5", 1), ("F5", 2),
        ("D5", 2), ("Bb4", 2), (None, 2), ("F4", 1), ("Bb4", 1),
        ("D5", 1), (None, 1), ("Bb4", 1), ("D5", 1), ("G5", 2), ("F5", 1), ("Eb5", 1),
        ("Eb5", 1), ("D5", 1), ("C5", 1), ("Bb4", 1), ("G5", 2), ("Eb5", 2),
        ("C5", 1), ("D5", 1), ("E5", 1), ("F5", 1), ("G5", 2), ("Bb5", 2),
        ("A5", 4), (None, 2), ("F5", 1), ("F5", 1),
    ]
    s.line("flute", 0, a_tune, vel=92, legato=0.55)
    s.line("oboe", 16, a_tune[25:], vel=70, legato=0.6, shift=-12)  # joins for the second half
    for beat, dur, pitch, vel in list(s.parts["flute"]["notes"]):
        if abs(beat - round(beat)) < 1e-6 and beat < 32:
            s.note("glock", beat, 0.4, pitch + 12, 88)
    pad(s, "strings", A, 50, 42)
    # Section B: brass fanfare, strings swell, timpani and a march snare.
    b_tune = [
        ("Bb4", 3), ("F4", 1), ("Bb4", 1), ("D5", 1), ("F5", 2),
        ("G5", 3), ("F5", 1), ("Eb5", 2), ("G5", 2),
        ("F5", 2), ("Eb5", 1), ("D5", 1), ("C5", 2), ("A4", 2),
        ("Bb4", 3), ("A4", 1), ("Bb4", 2), ("D5", 2),
        ("Eb5", 3), ("D5", 1), ("Eb5", 1), ("F5", 1), ("G5", 2),
        ("F5", 3), ("Eb5", 1), ("D5", 1), ("C5", 1), ("A4", 2),
        ("Bb4", 2), ("D5", 2), ("G5", 2), ("F5", 2),
        ("Eb5", 2), ("C5", 2), ("F5", 1), (None, 3),
    ]
    s.line("trumpet", 32, b_tune, vel=96, legato=0.8)
    harmonize(s, "trumpet", "horn", BB_MAJOR)
    pad(s, "strings", B, 53, 70)
    # Clarinet bubbles: staccato chord-tone eighths under the brass.
    for i, c in enumerate(B):
        halves = c if isinstance(c, list) else [c, c]
        for k in range(8):
            ch = halves[k // 4]
            tones = voicing(ch, 58)
            s.note("clarinet", 32 + i * 4 + k * 0.5, 0.22, tones[[0, 1, 2, 1][k % 4]] + (12 if k % 8 >= 6 else 0), 62)
    for i, c in enumerate(B):
        ch = c[0] if isinstance(c, list) else c
        s.note("timpani", 32 + i * 4, 0.5, in_range(CHORDS[ch][0], 41), 92)
    roll(s, "timpani", 30, 2, p("F2"), 50, 100)
    roll(s, "timpani", 62, 2, p("F2"), 50, 105)
    # Snare: light backbeat in A, a march in B, rolls into each section.
    for bar in range(16):
        b = bar * 4
        if bar < 8:
            for k in (1, 3):
                s.note("drums", b + k, 0.2, SNARE, 52)
            s.note("drums", b + 3.5, 0.2, SNARE, 36)
        else:
            for k, v in ((0, 88), (1, 64), (1.5, 58), (2, 80), (3, 70), (3.5, 60)):
                s.note("drums", b + k, 0.2, SNARE, v)
            for k in (0, 2):
                s.note("drums", b + k, 0.3, KICK, 70)
    roll(s, "drums", 30, 2, SNARE, 40, 96, rate=8)
    roll(s, "drums", 62, 2, SNARE, 40, 100, rate=8)
    s.note("drums", 32, 2, CRASH, 90)
    s.note("drums", 0, 2, CRASH, 70)
    return s


# --- Battle loop: G minor, 132 bpm, 16 bars, three stems -------------------

BATTLE = ["Gm", "Eb", "Bb", "F", "Gm", "Eb", "Cm", "D",
          "Gm", "Eb", "Bb", "F", "Eb", "F", "Gm", "D"]


def battle():
    s = Score(132, 64)
    # Base stem.
    s.part("tuba", TUBA, 115, 60)
    s.part("pizzbass", PIZZ, 100, 50)
    s.part("pizz", PIZZ, 92, 36)
    s.part("horn", HORN, 108, 76)
    s.part("trumpet", TRUMPET, 96, 88)
    s.part("flute", FLUTE, 115, 80)
    s.part("xylo", XYLO, 127, 92)
    s.part("bassoon", BASSOON, 85, 56)
    s.part("snare", DRUMS, 127, 64)
    for i, ch in enumerate(BATTLE):
        b = i * 4
        root = in_range(CHORDS[ch][0], 31)
        fifth = in_range(CHORDS[ch][2], root)
        # Bouncing pizzicato bass: root, octave, fifth, octave.
        for k, n in enumerate([root, root + 12, fifth, root + 12] * 2):
            s.note("pizzbass", b + k * 0.5, 0.3, n + 12, 86 if k % 2 == 0 else 70)
        s.note("tuba", b, 0.45, root, 84)
        s.note("tuba", b + 2, 0.45, fifth if fifth - root < 12 else root, 78)
        s.note("bassoon", b + 1.5, 0.25, root + 12, 60)
        s.note("bassoon", b + 3.5, 0.25, fifth + 12 if fifth + 12 < 60 else fifth, 60)
        for k in (0.5, 1.5, 2.5, 3.5):
            for n in voicing(ch, 62):
                s.note("pizz", b + k, 0.2, n, 66)
        s.note("snare", b + 1, 0.2, SNARE, 84)
        s.note("snare", b + 3, 0.2, SNARE, 84)
        s.note("snare", b + 3.75, 0.2, SNARE, 56)
    tune = [
        ("G4", 1), (None, 1), ("G4", 1), ("A4", 1), ("Bb4", 2), ("D5", 2),
        ("Eb5", 3), ("D5", 1), ("C5", 2), ("Bb4", 2),
        ("D5", 1), (None, 1), ("D5", 1), ("Eb5", 1), ("F5", 2), ("D5", 2),
        ("C5", 4), ("A4", 2), ("F4", 2),
        ("G4", 1), (None, 1), ("G4", 1), ("A4", 1), ("Bb4", 2), ("D5", 2),
        ("G5", 3), ("F5", 1), ("Eb5", 2), ("D5", 2),
        ("C5", 1), ("D5", 1), ("Eb5", 1), ("F5", 1), ("G5", 2), ("Eb5", 2),
        ("A4", 1), ("D5", 1), ("F#5", 2), ("A5", 2), (None, 2),
    ]
    s.line("horn", 0, tune, vel=96, legato=0.8)
    reprise = tune[:20] + [
        ("G5", 2), ("Bb5", 2), ("G5", 1), ("F5", 1), ("Eb5", 2),
        ("F5", 2), ("A5", 2), ("F5", 1), ("Eb5", 1), ("D5", 2),
        ("D5", 1), ("Eb5", 1), ("D5", 1), ("C5", 1), ("Bb4", 2), ("A4", 2),
        ("A4", 3), (None, 1), ("F#4", 2), ("A4", 1), (None, 1),
    ]
    s.line("trumpet", 32, reprise, vel=98, legato=0.75)
    s.line("horn", 32, reprise, vel=84, legato=0.8, shift=-12)
    # Woodwind runs at the ends of phrases, doubled by the xylophone.
    runs = {14: ["G5", "A5", "Bb5", "C6", "D6", "Eb6", "D6", "C6"],
            30: ["A5", "Bb5", "C6", "D6", "Eb6", "F#6", "G6", "A6"],
            46: ["F5", "G5", "A5", "Bb5", "C6", "D6", "Eb6", "F6"],
            62: ["D6", "C6", "Bb5", "A5", "G5", "F#5", "E5", "D5"]}
    for start, ns in runs.items():
        for k, nm in enumerate(ns):
            s.note("flute", start + k * 0.25, 0.2, p(nm), 80)
            s.note("xylo", start + k * 0.25, 0.2, p(nm), 76)
    for start in (4, 20, 36, 52):  # little xylophone answers
        for k, nm in enumerate(["D6", "Bb5", "D6", "F6"]):
            s.note("xylo", start + 3 + k * 0.25, 0.2, p(nm), 70)

    # Drums stem: march snare, bass drum on every beat, timpani pulse, crashes.
    s.part("march", DRUMS, 96, 64)
    s.part("timpani", TIMPANI, 100, 64)
    for i, ch in enumerate(BATTLE):
        b = i * 4
        pattern = [(0, 96), (0.5, 50), (0.75, 60), (1, 84), (1.5, 56), (2, 92), (2.25, 50),
                   (2.5, 62), (3, 86), (3.25, 52), (3.5, 70), (3.75, 76)]
        for k, v in pattern:
            s.note("march", b + k, 0.15, SNARE, v)
        for k in range(4):
            s.note("march", b + k, 0.3, KICK, 92 if k % 2 == 0 else 74)
        root = in_range(CHORDS[ch][0], 40)
        fifth = in_range(CHORDS[ch][2], 36)
        for k in range(8):
            s.note("timpani", b + k * 0.5, 0.4, root if k % 4 != 2 else fifth, 96 if k % 2 == 0 else 70)
        if i % 4 == 0:
            s.note("march", b, 2, CRASH, 96)
    roll(s, "timpani", 30, 2, p("D3"), 60, 112)
    roll(s, "march", 62, 2, SNARE, 50, 110, rate=8)

    # Tension stem: spiccato strings, low brass stabs, high tremolo.
    s.part("spiccato", STRINGS, 100, 40)
    s.part("lowbrass", TROMBONE, 88, 70)
    s.part("tremolo", TREMOLO, 78, 30)
    s.part("brass", BRASS, 92, 90)
    for i, ch in enumerate(BATTLE):
        b = i * 4
        root = in_range(CHORDS[ch][0], 43)
        third = in_range(CHORDS[ch][1], root)
        fifth = in_range(CHORDS[ch][2], root)
        figure = [root, root + 12, fifth, root + 12, third + 12, root + 12, fifth, root + 12]
        for k in range(16):
            s.note("spiccato", b + k * 0.25, 0.16, figure[k % 8], 92 if k % 4 == 0 else 72)
        for k in (0, 1.5, 3):
            for n in voicing(ch, 46):
                s.note("lowbrass", b + k, 0.35, n, 100 if k == 0 else 88)
        for n in voicing(ch, 74):
            s.note("tremolo", b, 3.95, n, 60)
        if i % 2 == 1:
            for n in voicing(ch, 60):
                s.note("brass", b + 3, 0.5, n, 92)
                s.note("brass", b + 3.5, 0.4, n, 100)
    return s


BATTLE_STEMS = {
    "battle_base": ["tuba", "pizzbass", "pizz", "horn", "trumpet", "flute", "xylo", "bassoon", "snare"],
    "battle_drums": ["march", "timpani"],
    "battle_tension": ["spiccato", "lowbrass", "tremolo", "brass"],
}


# --- Stingers -------------------------------------------------------------

def sting_match_start():
    s = Score(132, 6)
    for nm, v in (("trumpet", TRUMPET), ("horn", HORN), ("strings", STRINGS), ("timpani", TIMPANI), ("tuba", TUBA), ("glock", GLOCK)):
        s.part(nm, v, 105, 64)
    s.part("drums", DRUMS, 100, 64)
    call = [("F4", 1 / 3), ("F4", 1 / 3), ("F4", 1 / 3), ("Bb4", 0.5), ("D5", 0.5), ("F5", 3.5)]
    s.line("trumpet", 0, call, vel=104, legato=0.85, unit=1)
    harmonize(s, "trumpet", "horn", BB_MAJOR)
    for n in voicing("Bb", 58):
        s.note("strings", 2, 3.5, n, 96)
    s.note("tuba", 2, 3.0, p("Bb1"), 100)
    roll(s, "timpani", 0, 2, p("F2"), 50, 115, rate=8)
    s.note("timpani", 2, 1, p("Bb2"), 120)
    roll(s, "drums", 0, 2, SNARE, 40, 105, rate=8)
    s.note("drums", 2, 3, CRASH, 112)
    for k, nm in enumerate(["Bb5", "D6", "F6", "Bb6"]):
        s.note("glock", 2 + k * 0.125, 0.5, p(nm), 90)
    return s


def sting_crown_captured():
    s = Score(140, 7)
    for nm, v in (("trumpet", TRUMPET), ("horn", HORN), ("strings", STRINGS), ("timpani", TIMPANI), ("tuba", TUBA),
                  ("glock", GLOCK), ("xylo", XYLO), ("flute", FLUTE)):
        s.part(nm, v, 105, 64)
    s.part("drums", DRUMS, 100, 64)
    s.line("trumpet", 0, [("Bb4", 0.25), ("D5", 0.25), ("F5", 0.25), ("Bb5", 0.25), ("G5", 1), ("A5", 1), ("Bb5", 3)],
           vel=106, legato=0.9, unit=1)
    harmonize(s, "trumpet", "horn", BB_MAJOR)
    s.line("flute", 0, [("Bb5", 0.25), ("D6", 0.25), ("F6", 0.25), ("Bb6", 0.25), ("G6", 1), ("A6", 1), ("Bb6", 3)],
           vel=80, legato=0.9, unit=1)
    for beat, ch in ((1, "Eb"), (2, "F"), (3, "Bb")):
        for n in voicing(ch, 55):
            s.note("strings", beat, 1 if beat < 3 else 3, n, 96)
        s.note("tuba", beat, 0.9 if beat < 3 else 3, in_range(CHORDS[ch][0], 34), 100)
        s.note("timpani", beat, 0.5, in_range(CHORDS[ch][0], 41), 108)
    s.note("drums", 3, 3, CRASH, 110)
    s.note("drums", 1, 0.2, SNARE, 90); s.note("drums", 2, 0.2, SNARE, 95)
    roll(s, "drums", 2.5, 0.5, SNARE, 70, 105, rate=8)
    for k, nm in enumerate(["Bb6", "F6", "D6", "Bb5", "D6", "F6", "Bb6"]):
        s.note("glock", 3 + k * 0.125, 0.4, p(nm), 86)
        s.note("xylo", 3 + k * 0.125, 0.2, p(nm) - 12, 70)
    return s


def sting_crown_lost():
    s = Score(96, 6)
    for nm, v in (("trombone", TROMBONE), ("horn", HORN), ("tremolo", TREMOLO), ("timpani", TIMPANI), ("tuba", TUBA)):
        s.part(nm, v, 105, 64)
    s.line("trombone", 0, [("D4", 1), ("Db4", 1), ("C4", 1), ("B3", 2.5)], vel=98, legato=0.9, unit=1)
    s.line("horn", 0, [("Bb3", 1), ("A3", 1), ("Ab3", 1), ("G3", 2.5)], vel=84, legato=0.9, unit=1)
    for n in voicing("Gm", 55):
        s.note("tremolo", 0, 5.5, n, 62)
    s.note("tuba", 3, 2.5, p("G1"), 90)
    roll(s, "timpani", 2, 1.5, p("D2"), 40, 90, rate=8)
    s.note("timpani", 3.5, 1, p("G2"), 100)
    return s


def sting_victory():
    s = Score(120, 12)
    for nm, v, pan in (("trumpet", TRUMPET, 88), ("horn", HORN, 76), ("strings", STRINGS, 44), ("timpani", TIMPANI, 64),
                       ("tuba", TUBA, 60), ("glock", GLOCK, 84), ("xylo", XYLO, 92), ("flute", FLUTE, 80), ("pizz", PIZZ, 40)):
        s.part(nm, v, 108, pan)
    s.part("drums", DRUMS, 100, 64)
    tune = [("F4", 0.5), ("Bb4", 0.5), ("D5", 0.5), ("F5", 1.5),
            ("Eb5", 0.5), ("F5", 0.5), ("G5", 0.5), ("A5", 0.5),
            ("Bb5", 2), (None, 0.5), ("F5", 0.25), ("G5", 0.25), ("A5", 0.5), ("Bb5", 4.5)]
    s.line("trumpet", 0, tune, vel=108, legato=0.85, unit=1)
    harmonize(s, "trumpet", "horn", BB_MAJOR)
    s.line("flute", 0, tune, vel=80, legato=0.85, unit=1, shift=12)
    plan = [(0, 3, "Bb"), (3, 1, "Eb"), (4, 1, "F"), (5, 2, "Bb"), (7, 1, "F"), (8, 4, "Bb")]
    for beat, dur, ch in plan:
        for n in voicing(ch, 55):
            s.note("strings", beat, dur, n, 98)
        s.note("tuba", beat, min(dur, 1.0), in_range(CHORDS[ch][0], 34), 104)
        s.note("timpani", beat, 0.5, in_range(CHORDS[ch][0], 41), 106)
        for k in range(int(dur * 2)):
            if k % 2 == 1:
                for n in voicing(ch, 60):
                    s.note("pizz", beat + k * 0.5, 0.2, n, 80)
    for k in range(7):
        s.note("drums", k, 0.2, SNARE, 80 if k % 2 else 96)
        s.note("drums", k, 0.3, KICK, 84 if k % 2 == 0 else 60)
    roll(s, "drums", 7, 1, SNARE, 60, 115, rate=8)
    roll(s, "timpani", 7, 1, p("F2"), 70, 120, rate=8)
    s.note("drums", 0, 2, CRASH, 100)
    s.note("drums", 5, 2, CRASH, 100)
    s.note("drums", 8, 4, CRASH, 120)
    s.note("timpani", 8, 1, p("Bb2"), 124)
    for k, nm in enumerate(["Bb5", "D6", "F6", "Bb6", "F6", "D6", "F6", "Bb6"]):
        s.note("glock", 8 + k * 0.125, 0.5, p(nm), 92)
        s.note("xylo", 8 + k * 0.125, 0.2, p(nm) - 12, 76)
    return s


def sting_defeat():
    s = Score(76, 9)
    for nm, v, pan in (("oboe", OBOE, 76), ("horn", HORN, 70), ("strings", STRINGS, 44), ("timpani", TIMPANI, 64),
                       ("pizz", PIZZ, 50), ("bassoon", BASSOON, 56)):
        s.part(nm, v, 100, pan)
    s.line("oboe", 0, [("D5", 1), ("C5", 0.5), ("Bb4", 0.5), ("A4", 1), ("Bb4", 0.5), ("A4", 0.5), ("G4", 4)],
           vel=88, legato=0.95, unit=1)
    s.line("bassoon", 0, [("G3", 2), ("Eb3", 1), ("D3", 1), ("G2", 4)], vel=70, legato=0.95, unit=1)
    for beat, dur, ch in ((0, 2, "Gm"), (2, 1, "Cm"), (3, 1, "D"), (4, 4, "Gm")):
        for n in voicing(ch, 55):
            s.note("strings", beat, dur, n, 66)
    s.line("horn", 2, [("Eb4", 1), ("D4", 1), ("D4", 4)], vel=66, legato=0.95, unit=1)
    roll(s, "timpani", 3, 1, p("D2"), 30, 70, rate=8)
    s.note("timpani", 4, 1, p("G2"), 80)
    s.note("pizz", 7.5, 0.3, p("G2"), 90)
    s.note("pizz", 7.5, 0.3, p("G3"), 80)
    return s


STINGS = {
    "sting_match_start": sting_match_start,
    "sting_crown_captured": sting_crown_captured,
    "sting_crown_lost": sting_crown_lost,
    "sting_victory": sting_victory,
    "sting_defeat": sting_defeat,
}


def normalize(x, peak=0.89):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def main():
    preview = None
    if "--preview" in sys.argv:
        preview = sys.argv[sys.argv.index("--preview") + 1]
        os.makedirs(preview, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        s = menu_theme()
        n = int(round(s.seconds(s.beats) * SR))
        menu = normalize(fold_loop(render(s, list(s.parts), tmp, "menu"), n), 0.85)
        write_ogg(menu, os.path.join(OUT, "menu.ogg"))

        s = battle()
        n = int(round(s.seconds(s.beats) * SR))
        stems = {k: fold_loop(render(s, v, tmp, k), n) for k, v in BATTLE_STEMS.items()}
        # One gain for all stems so their balance holds when they are layered.
        full = sum(stems.values())
        g = 0.85 / np.max(np.abs(full))
        for k, x in stems.items():
            write_ogg(x * g, os.path.join(OUT, k + ".ogg"))

        stings = {}
        for k, fn in STINGS.items():
            st = fn()
            x = render(st, list(st.parts), tmp, k)
            x = fit(x, int((st.seconds(st.beats) + 1.0) * SR))
            fade = int(0.6 * SR)
            x[-fade:] *= np.linspace(1, 0, fade)[:, None]
            stings[k] = normalize(x, 0.85)
            write_ogg(stings[k], os.path.join(OUT, k + ".ogg"))

        if preview:
            write_ogg(np.vstack([menu, menu]), os.path.join(preview, "1-menu-theme.mp3"))
            base = stems["battle_base"] * g
            drums = stems["battle_drums"] * g
            tens = stems["battle_tension"] * g
            demo = np.vstack([base, base + drums, base + drums + tens])
            write_ogg(demo, os.path.join(preview, "2-battle-calm-then-door-then-crown-stolen.mp3"))
            for i, k in enumerate(STINGS):
                write_ogg(stings[k], os.path.join(preview, "%d-%s.mp3" % (3 + i, k.replace("_", "-"))))
    for f in sorted(os.listdir(OUT)):
        if f.endswith(".ogg"):
            print("%-28s %6.0f KB" % (f, os.path.getsize(os.path.join(OUT, f)) / 1024))


if __name__ == "__main__":
    main()
