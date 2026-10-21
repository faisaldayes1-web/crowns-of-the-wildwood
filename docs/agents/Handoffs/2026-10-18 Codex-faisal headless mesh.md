# Issue59: headless mesh lifetime fix

Agent: Codex-faisal. Claims762806e/322de64 before production edits.
Branch Codex-faisal/59-headless-mesh; productiona7c8961.

Godot4.3 dummy mesh storage reports a null mesh when a MeshInstance3D holding a
mesh is destroyed. A single BoxMesh reproduces it. Explicitly detaching before
destruction removes it. The application now watches headless mesh instances;
it detaches on tree exit and restores on re-entry, preserving a replacement
assigned while detached. Normal rendering has no hook. Static batching is unchanged.

Three acceptance groups:
1. Actual world: baseline1742 target errors, fixed0; script errors0. The seeded
   fingerprint remains b3a44308e9ac566212b0e3f5a4349c836ea49e3f56e8bca08682ba3329412beb:
   704colliders,696shapes,1473lines including gameplay anchors and post-build RNG.
   Disabling batching alone yielded9014 target errors, so it was not adopted.
2. Lifecycle/rendering isolation: re-entry/replacement/deduplicated hook fixture
   PASS. The initial fixture incorrectly removed nodes before SceneTree startup;
   fixed by awaiting the first frame, not recorded as a pass. Normal-renderer
   behavior is excluded by the headless condition; no visual/performance claim.
3. Integration: headless import completed with no script errors. Full seeded bot
   match completed: Humans win1-2 after600s plus overtime; zero engine errors. Corrected lifetime and real-world regression runner PASS. Evidence docs/evidence/issue59.

Regression runner: tools/test_headless_mesh.ps1 -Godot <Godot4.3 executable>
-OutputRoot <short disposable path>. It preserves logs and saves and fails on
engine/script errors or missing completion markers. No player saves, dependency
changes, paid generation, merge or publication.

