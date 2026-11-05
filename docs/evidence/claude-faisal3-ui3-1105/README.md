# claude-faisal3 UI round 3 (11-05): dialogue, class cards, action card, Armor

| Faisal item | Root cause | Fix |
|---|---|---|
| Talking screen "too small, low quality" | the guide's portrait was a 267x380 painted card stretched to 360 px in a small boxed rect | full-screen talk: dimmed game, 3D bust of the speaker rendered from the real model at 1024 px with 4x MSAA on a transparent background (scripts/portrait_rig.gd, framed from the head mesh), wide parchment panel with name tag, typewriter line, Next/Close with real key glyphs |
| Class selector cards: small figures on flat green | `_card_art` drew the painted card (flat green backdrop) into a small frame | same HD busts (512 px, rendered once at match start) on a soft team-colour gradient with glow, filling the box edge to edge; main card art enlarged, caption below the face |
| Veteran Training / action card "generic dark web pop-up" | `_slate_card` dark slate polygon | `_wood_card`: the HUD's wooden board with brass rim and gold corners, parchment inset for the words, price and button on the wood |
| Armor menu "MS Paint" | 44x38 px option boxes, glyph fallbacks below 48 px, overflowing rows, diagonal slash for "none" | six sub-tabs (Look, Tint, Hat, Cape, Weapon, Rank), 4x2 paged grid of 150 px tiles using the store's rendered item icons with rarity frames, lock veil that keeps the art, price on the tile, hover tooltip, clear WORN state, ring-and-slash for "none"; live 3D hero preview unchanged (drag to turn) |

Phones and browsers keep the painted cards (Portrait.supported()).
Captures: tools/ui_capture3.gd (dialogue-*.png, class-banner.png, action-card.png, veteran-training.png, armor-N.png).
