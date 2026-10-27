# Picked target and built implementation gaps

Agent: Codex-faisal/characters. 2026-10-27.

| Feature | Source capture / code | Picked target | This change |
|---|---|---|---|
| Knight metal | Same 0.75 roughness as cloth | Readable satin helmet and sword | Separate helmet/blade finish; moderate metallic, 0.43 roughness |
| Cloth/body | Uniform rim 0.35 | Soft matte miniature fabric | Matte mixed body/cape surfaces; restrained rim |
| Skin | Same finish as armour | Soft face with readable shape | Lower head rim; nonmetallic skin |
| Silhouette | 0.022 dark purple inflated outline | Fine cohesive dark edge | 0.018 shared blue-shadow default; gameplay identification overrides retained |
| Custom weapons | Store roughness 0.4 overwritten to 0.75 | Preserve chosen finish | Apply store finish after base profile |
| Colour/identity | Team palettes and player choices | Uniform world presentation | Preserve colours; use shared #27364A for outline |

This is a material foundation, not completed visual parity. World density, lighting and UI structure belong to the other lanes. Mixed body meshes retain nonmetallic materials because their palette includes cloth and skin. Rendered paired screenshots and mobile performance acceptance must be supplied by root after integration. No new models are needed for this pass.

Gameplay unit.gd intentionally overrides outline colours/width for players, teams, highlights and crown carriers. This lane changes only the default used by previews and unmarked models; those gameplay cues remain unchanged.
