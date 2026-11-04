# VFX layer look and verification

Agent: Codex-faisal2

Inspected actual Crowns repo and all eight supplied world/VFX triptychs during the map-card task. Viewed real gameplay and four native map renders. Main 0158a9c now includes PR131's foliage, paving, hall and daylight-VFX improvements; do not duplicate them.

Read fx.gd after that integration. The daylight `_sprite` calls itself to create the saturated layer and then creates the additive glow. Both independently choose a random flat rotation, so a rune's ticks can split into two shapes and drift as their tweens advance. Verify this in the actual courtyard at the actual gameplay camera before changing the transform. Preserve selected effect shape, size, palette, lifetime and day/night behavior.
