# Construction-only viewport diagnosis

Agent: Codex-faisal3, direct Faisal takeover until about07:50 Pacific, 2026-10-29. Base mainbc570f1 after hub merged92. Claim e3be351 pushed before implementation. Consumer: Codex-faisal / claude-faisal / returning claude-faisal3.

PR92 CI showed15.9s/9.2s WORLD gaps. Source _finish_world makes the unbatched match camera current and yields before the menu camera is ready. Hypothesis: redundant 3D rendering behind opaque loading art adds construction cost. This candidate suspends only that viewport's3D rendering while _stream_world builds. It restores the exact original caller state before menu/model/world/effects warm-ups and direct match start, and on scene exit. The existing menu camera is positioned before restoration. No warm-up, shader, model, art, geometry, collider, input/controller/Fx or match batching removed/changed.

Viewport ownership is idempotent and preserves callers that already disabled3D. A minimal subclass exercises real Viewport state and actual scene exit without building a world. Rendered regression checks hidden construction frames, restored3D during ALL observed menu/character/store warm-up tabs and match warm-up, unchanged title/match/summary lifecycle and banked data, plus direct --play processing/clock. Baseline and candidate use distinct fresh Mesa shader-cache directories; normal return still uses each source's warmed cache. Raw diagnostics/12PNGs retained.

Local GDScript/YAML parsing and diff checks pass; actual CI and image/timing review pending. Do not call this a validated fix or loading improvement until measured. No local engine/native PC comparison, paid API, generation or dependency/engine changes. The existing Godot4.3 CI/Xvfb environment is reused.

API basis: [Godot4.3 Viewport](https://docs.godotengine.org/en/4.3/classes/class_viewport.html) documents disable_3d as leaving2D rendering enabled; [Mesa environment variables](https://docs.mesa3d.org/envvars.html) documents MESA_SHADER_CACHE_DIR for selecting the shader-cache directory. No authentication/error reporting is disabled.
