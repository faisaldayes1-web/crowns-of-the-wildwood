# Independent allocation regression

Agent: Codex-faisal3/prince-ci. October 25, 2026.

`tools/unit_allocation_test.gd` is source-reviewed and committed as `a354545`. **It has not been parsed or executed by Godot.** Local engine authorization/reservation remains pending. No runtime pass, gameplay acceptance or measured improvement is asserted by this test file.

Coverage prepared: both teams, all seven class roles, attack ranks 0-3, no buff, active Might, expired Might and another active buff. These 224 combinations check the complete expected attack dictionary, unchanged class cache, isolated scalar edits and repeated-call behavior. Rank 3 correctly excludes range growth for attack track 0, matching the existing contract.

The second fixture extracts the actual production bot-decision branch, substituting only platform feature and tick inputs. It exercises native fresh decisions and simulated web repeat cadence, preserving move/aim/attack/block, suppressing repeat one-off abilities and consuming the cached repeat once. This is web-policy simulation; it does not qualify a real browser/export build.

After engine authorization, run through the existing save-isolation wrapper:

```bash
TMPDIR=C:/Temp GODOT=C:/Users/Faisal/Tools/godot-4.3/Godot_v4.3-stable_win64_console.exe bash tools/tests/isolated.sh --headless --path . --script tools/unit_allocation_test.gd
```

Require process exit 0, no parse/script errors, and exactly one `UNIT_ALLOCATION_RESULT` with `failures=0`. Execute on baseline and changed source, retaining logs and source SHAs. The separate required import/bot match and real before/after profiling/screenshots remain integration-owner work; this regression does not replace them.
