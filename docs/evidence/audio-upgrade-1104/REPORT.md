# Crowns ElevenLabs listening/levels report

Format: one-shots WAV PCM16 44.1 kHz mono (assets/sfx/override/); music and ambience Ogg Vorbis 44.1 kHz stereo (assets/music/el/). Target -18 dBFS RMS, peak <= -1 dBFS (gain = min of both, so sparse clips sit below -18 RMS rather than clip). Music loops: 2 s tail-to-head crossfade (seamless). Vocal check: eleven_scribe_v1 on all 5 music files, every transcript empty.

Table measured from the committed files (one-shots re-levelled after the mono downmix).

| clip | format | seconds | RMS dBFS | peak dBFS |
|---|---|---|---|---|
| arrow_hit | wav mono | 0.6 | -18.3 | -1.0 |
| blink | wav mono | 0.68 | -18.0 | -1.4 |
| block_up | wav mono | 0.6 | -18.4 | -1.0 |
| bolt | wav mono | 0.88 | -18.0 | -1.7 |
| bolt_hit | wav mono | 0.68 | -18.0 | -2.4 |
| bow | wav mono | 0.54 | -18.0 | -3.7 |
| curse | wav mono | 1.2 | -18.0 | -3.8 |
| dodge | wav mono | 0.46 | -18.9 | -1.0 |
| explosion | wav mono | 1.48 | -18.0 | -1.7 |
| fireball | wav mono | 1.2 | -18.0 | -5.4 |
| frost | wav mono | 1.2 | -19.2 | -1.0 |
| heal | wav mono | 1.28 | -18.0 | -1.2 |
| hit_flesh | wav mono | 0.48 | -23.1 | -1.0 |
| hit_magic | wav mono | 0.6 | -18.0 | -1.7 |
| smite | wav mono | 1.28 | -18.0 | -1.0 |
| swing | wav mono | 0.56 | -18.0 | -6.2 |
| ui_click | wav mono | 0.08 | -18.0 | -6.6 |
| ui_close | wav mono | 0.48 | -19.8 | -1.0 |
| ui_deny | wav mono | 0.28 | -21.0 | -1.0 |
| ui_open | wav mono | 0.49 | -18.4 | -1.0 |
| volley | wav mono | 1.15 | -18.7 | -1.0 |
| ambience_day | ogg stereo | 30.0 | -18.0 | -2.1 |
| ambience_night | ogg stereo | 30.0 | -26.2 | -1.6 |
| ambience_twilight | ogg stereo | 30.0 | -32.4 | -1.7 |
| ambience_volcano | ogg stereo | 30.0 | -18.0 | -2.2 |
| ambience_winter | ogg stereo | 30.0 | -28.7 | -2.0 |
| battle_bright | ogg stereo | 73.0 | -18.1 | -2.8 |
| battle_dark | ogg stereo | 73.0 | -18.0 | -2.2 |
| menu | ogg stereo | 73.0 | -18.0 | -1.5 |
| sting_defeat | ogg stereo | 7.54 | -18.0 | -1.8 |
| sting_victory | ogg stereo | 7.0 | -19.8 | -1.4 |

Sparse ambiences (night, twilight, winter) and hit_flesh/ui_deny sit below -18 RMS because the -1 dBFS peak limit binds; the game's AMBIENCE_DB mix level is unchanged.
