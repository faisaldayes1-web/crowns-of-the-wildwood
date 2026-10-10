# Music group changelog

Branch `group/music-*`. Newest entry at the top. See [README.md](README.md) for the format.

### 2026-10-10 08:47 UTC · `d7ff55e` · Real orchestra samples, bigger heroic march style

- **What:** Faisal asked for the music to sound like Clash of Clans music. The music is now played by recorded orchestra instruments (horns, trumpets, trombones, tuba, string sections, piccolo, flute, oboe, bassoon, xylophone, glockenspiel, snare, bass drum, cymbals, timpani) in a concert-hall reverb instead of the General MIDI soundfont, and every tune is rewritten in a bigger mobile-strategy style: a unison horn melody over driving staccato cellos, trumpet fanfares, a marching snare with crashes, and piccolo and xylophone runs. The menu theme is a heroic D major march; the battle loop is a D minor march at 140 bpm with the same three layers (drums when your door is hit, racing violins and brass stabs when your crown is out). New stingers for battle start, crown captured or lost, victory and defeat. The tunes are original; nothing is copied from Clash of Clans.
- **Files:** tools/make_music.py, assets/music/*.ogg, assets/CREDITS.md
- **Tunables:** none in the game. Music folder 1.5 MB → 2.0 MB (Vorbis q2 → q3).
- **Tested:** sampler pitch check on every instrument (all within 0.2 semitone); Godot import; headless `--demo` bot match with no script errors.
- **Revert:** `git revert d7ff55e` (goes back to the soundfont version)

### 2026-10-09 11:47 UTC · `dfa19c9` · Bouncy orchestral music: menu theme, layered battle loop, stingers

- **What:** New original music in a bouncy orchestral fantasy style (brass fanfares, pizzicato strings, snare and timpani, woodwinds, xylophone and glockenspiel). The title and menus play a Bb major theme; a match plays a G minor battle march that gets louder and busier when you are in trouble: march drums and timpani come in while your door is being hit or enemies are inside your castle, and racing strings and low brass come in while your crown is out of its vault. Short fanfares play when the battle starts, when a crown is captured (a cheer for your team, a sad brass slide when the enemy scores), and on victory or defeat. Menu and match music crossfade, the music dips under sound effects and under each fanfare, and the Music Volume slider controls all of it (at zero the old fanfare effects play instead). The old synth placeholder theme is removed.
- **Files:** tools/make_music.py (new), assets/music/*.ogg (new, ~1.5 MB), scripts/sfx.gd, scripts/game.gd (three stinger calls), tools/make_sounds.py (no longer writes theme.wav), assets/sfx/theme.wav (deleted), assets/CREDITS.md, docs/changelog/README.md
- **Tunables:** new in scripts/sfx.gd: `STING_DB` -4, `CROSSFADE` 1.6 s, `LAYER_FADE` 1.2 s, `DOOR_ALARM` 6 s; music bus ducking compressor threshold -22 dB, ratio 3. `MUSIC_MATCH_DB` -11 and `MUSIC_TITLE_DB` -5 (unchanged).
- **Tested:** `--check-only` on sfx.gd; a headless 6-minute `--demo` bot match (no script errors; the drum layer came in and out with door attacks, loop wrapped seamlessly every 29 s, the start fanfare ducked the loop, victory faded the loop out); headless title screen (menu theme fades in).
- **Revert:** `git revert dfa19c9`
