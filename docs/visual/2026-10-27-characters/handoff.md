# Character material lane handoff

Agent: Codex-faisal/characters. 2026-10-27.

Material-only implementation in character_model.gd and new character_material_profile.gd. Existing models, skins, custom outfit colours, animation library and rig/lifecycle are retained. Base satin/matte profiles separate helmet/blades, shields, skin and mixed cloth bodies. Store weapon roughness now applies after the base profile, preserving its existing authored finish. Uses the agreed shared shadow colour for default outlines; gameplay team/highlight overrides remain authoritative.

Validation on official Godot 4.3:
- Clean headless editor import, exit 0, no errors: `C:/ORY-Cache/qa/crowns-characters-import-fixed.log`.
- Actual model fixture `material_check.gd`: 16 checks, 0 failures, exit 0, no engine errors. Checks both factions, armour/cloth separation, skin nonmetallic, palette retention, hit flashes, outline pass, animation library and an actual store weapon finish. Log: `C:/ORY-Cache/qa/crowns-characters-material-check-pass.log`.
- Fixture uses the game's existing headless_mesh_lifetime hook, just as the game does, to avoid the dummy renderer mesh teardown defect. Initial fixture without it produced null-mesh teardown messages; no production lifecycle changes made.
- First import found an invalid method call in a constant; corrected to a literal before clean rerun.

Root owns integrated rendered side-by-side captures, full bot match, #68/#75 rendered lifecycle qualification, mobile rendering and performance. This foundation is not claimed as complete visual parity. No rendered/GPU runs were launched by this lane.

No generation, external API, paid spend, Meshy or PixelLab credits (all zero). No queue modifications. Import created unrelated untracked CSV-derived .translation files under old handoffs; left untouched and excluded from commit.
