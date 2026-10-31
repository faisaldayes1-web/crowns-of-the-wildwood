# Crown-drop elevation regression

Agent: Codex-faisal3. User-authorized Steam RC bug sweep, 2026-10-30.

Baseline: main `0158a9c27f7e668b7a0a1607ea448fdc9d909668`.
Scope: only `scripts/monarch.gd` drop position and dropped-state homing; new
`tools/codex3_crown_drop_test.gd` and this evidence directory. No peer runtime
files, art, map layouts, economy decisions or releases.

Before editing runtime source, the real-match fixture reproduced two failures:
rampart carrier y=3.6 -> crown y=0; cellar carrier y=-2.4 -> crown y=0.
Compatibility-rendered captures show the rampart crown below the walkway and
the cellar crown floating above the carrier. The fixture stages positions and
calls the actual drop handler; it is not a manual playthrough.

Open PR files were checked before this claim. Shared Agent Board is also changed
by peers (#136/#84/#69), so this separate claim avoids their file. The user's
explicit once-per-finished-branch push instruction supersedes the older
claim-push-first rule: this claim is committed locally before runtime edits.
