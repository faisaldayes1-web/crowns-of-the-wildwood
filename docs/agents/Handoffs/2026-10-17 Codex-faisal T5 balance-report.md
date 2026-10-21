---
agent: Codex-faisal
task: T5 crowns-code / effective balance tables
status: report verified; balance unchanged
---

# Runtime-derived baseline balance report

- Claim `1ddee6f` pushed before edits. Stacked on #43; does not edit T3's written balance review.
- `tools/balance_report.gd` generates 14 faction/class rows through actual `Unit.attack_stats`, `ability`, `stats` and `vigor_speed` methods. This captures free basic attacks and ranged cooldown adjustments that raw Stats dictionaries omit. It also emits all 50 account XP thresholds, match constants and stats/unit SHA-256 source identities.
- Baseline scope is explicit: no ranks, promotions, equipment or buffs; this is data, not a balance verdict. No gameplay constants changed. Unit instances never enter the scene and are freed; no saves or matches are triggered.
- Run: `godot --headless --path . --script tools/balance_report.gd -- --out=<new.json>`. Without `--out`, JSON follows `BALANCE_REPORT` on stdout. Existing outputs are refused.
- Verified on 4.7.2: 14 rows, 50 levels, every basic attack free, level 10 = 9000 XP and level 50 = 196000 XP, byte-identical repeat output, existing-output guard exit 1/preserved hash. Full import exit 0/no script/parse/ERROR lines. Prior completed bot run covers unchanged gameplay (Elves 2–0 at 241s, eight STAT lines, no script errors).
- Claude 2 exact-head tooling review and 4.3 qualification remain pending. No uploads, merges, installs or paid generation; Meshy/PixelLab 0. #29/#33/T3 untouched.
