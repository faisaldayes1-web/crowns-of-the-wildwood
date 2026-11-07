---
from: claude-faisallaptop/crowns-tutorial-visual
to: claude-faisal3
status: open
task: crowns-tutorial-visual (first-time player pass, 2026-11-07)
---
# First-time player pass: HUD findings in your files (not edited)

I played from a wiped profile at 1920x1080 (tools/firsttime_capture.gd, frames in
docs/evidence/crowns-tutorial-visual-1107/before/ and after/). I fixed the tutorial text
in guide.gd, tips.gd, menu.gd HOW TO PLAY and game.gd (guide answers, GOAL chat line).
These ones are in hud.gd or the class/Veteran Training panels, so I left them for you:

1. **Wrong onboarding line** (hud.gd `_chat_display_text`, about line 7032): a new player
   reads "Q and E skills unlock as you level." They unlock when a class hat goes on (a
   Level 1 Knight has Q 30 / E 35 ready). Suggested: "Q and E unlock when you put on a class hat."
   Frame: before_17_spawn-prep.
2. **Skill bar overlap at 1080p** once a Knight: the RMB (block) slot sits under the R (Vigor)
   slot, so the RMB keycap is half covered. Frames: before_21_took-knight, before_22_tip-attack.
3. **World prompt overlap**: at the Rogue stand the "YOU · Elf" name tag overlaps
   "LOCKED · ACCOUNT LEVEL 10", and the "PICK A CLASS" plate covers the Mage banner
   (before_19_tip-class).
4. **Veteran Training pops up on the very first hat** at Level 1 ("Buy the experience to
   pick your Knight variant ... LATE GAME · JUST YOU", 12 wood). It covers the screen while the
   first-match tips want attention; a first-timer can't use it yet. (Probably Codex-faisal3's
   class/Veteran area; please forward if so.)
5. **Skills & Upgrades promotion card**: the third move's description ("Charge ...") runs past
   the card's bottom edge and gets cut (before_24_tip-goal).
6. The first-match tip pill is held back while the FIGHT! and YOU ARE NOW banners show (fine),
   and the Veteran Training card follows, so the class/attack tip pill only appears several
   seconds after the hat is on (after_22_tip-attack shows it once they clear).
7. **Guide talk panel does not clip or fit** (`_draw_guide`): three guide answers ran a line
   past the parchment at 1080p (classes, upgrade, where to go). I shortened the texts in
   guide.gd to four lines each; a `_fit_paragraph` there would make it safe for good.

Agent: claude-faisallaptop/crowns-tutorial-visual
