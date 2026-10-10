# Balance patch 4 (2026-10-10)

Faisal 2026-10-10: "overall improve on the game in all aspects". Patch 3 left
one lean: on Ember Pass the Elves won 10 of 12 matches at 4v4 and 5v5, both
before and after it. This patch fixes that.

## How it was measured

- **Build:** `release/v0.4.0-alpha` (fdad6d6) merged with Combat & Balance PR #8
  plus patch 3 (now in the alpha as b8a721d). Bots only.
- **Batches:**
  - Seeds 71-76 at 3v3/4v4/5v5 on both maps, before (`p3a`) and after (`p4a`).
  - Six fresh seeds, 77-82, at 4v4 (the live size) on both maps, before (`p3c`)
    and after (`p4c`).
  - A rejected middle step, crossbow 0.65 s (`p4b`).
  - 132 matches in all, 0 script errors.

## What was wrong

The Fire Objective decides most Ember Pass matches, and the Elves held it
longer: 4,266 s against 2,787 s over 24 matches at 4v4. Both sides took it
first about equally often (13 vs 11), but the Elves kept taking it back. That
came down to the ranged fight on Ember Pass's long open bridges. Pooled over
48 Ember matches at 4v4 and 5v5:

| | Elf K/D | Human K/D |
|---|---|---|
| Rangers | **1.70** | 1.06 |
| Healers | **1.67** | 0.82 |
| Mages | 1.41 | 0.99 |
| Knights | 0.70 | 0.67 |

On Wildwood the same Rangers trade evenly (1.32 against 1.35), so the open map
is what makes the Moonbow's faster fire count. It shot every 0.55 s, against
the Crossbow's 0.68 s, for the same damage. Elf healers also lead on both maps:
Lunar Lance, a damage-plus-slow shot every 3 s, gives them a second weapon that
the Human Holy Bubble doesn't.

## The changes

| Tunable (`scripts/stats.gd`) | Old | New |
|---|---|---|
| Human Crossbow `cooldown` | 0.68 s | 0.62 s (Moonbow stays quicker at 0.55) |
| Elf Lunar Lance `cooldown` | 3 s | 4 s |

The middle step, crossbow 0.65 s, played exactly like no change (Elves 22-14,
Ember Pass 9-3), so it was dropped.

## After

| Size, map (seeds 71-76) | Wins E-H (before → after) | Avg length (before → after) |
|---|---|---|
| 3v3 Wildwood | 4-2 → 2-4 | 470 → 529 s |
| 3v3 Ember Pass | 2-4 → 3-3 | 477 → 416 s |
| 4v4 Wildwood | 3-3 → 2-4 | 575 → 465 s |
| 4v4 Ember Pass | **5-1 → 3-3** | 381 → 200 s |
| 5v5 Wildwood | 3-3 → 3-3 | 376 → 380 s |
| 5v5 Ember Pass | **5-1 → 2-4** | 220 → 220 s |

- **4v4 over 24 matches (seeds 71-82):** Elves 17-7 → 11-13. Ember Pass 9-3 →
  4-8; Wildwood 8-4 → 7-5.
- **Everything at 0.62 s (48 matches):** Elves 31-17 before, Humans 27-21
  after. That is a slight Human tilt, after weeks of Elf leans, and within what
  six seeds swing.
- **4v4 Rangers:** Elves 1.51 / Humans 1.12 → 1.16 / 1.39.

## To watch in patch 5

- Elf Knights fell to K/D 0.38 at 4v4 after this patch (Human Knights 0.75).
  The Glaive was already the weakest melee kit.
- 4v4 Ember Pass matches got short: 200 s on seeds 71-76, though 270 s on
  77-82.

## Revert

`git revert <patch 4 commit>`
