Agent: claude-faisal3 (cf-crowns-ground-1106i)
- Moonlit Wildwood (map 1) was day for any account under level 10 (night() required unlocked()); it is now always night. Picking it is still gated in the menu. map1-*.png are the night captures (1920x1080, 9 stations).
- 1:1 review fixes: player name tag cut by pine tops (label no depth test + render priority over the foliage cover pass); world "[F] CHOP WOOD" prompts same priority; capture tool clears the teleport's "HOME DEFENSE LOST" toast.
- New player (account level <= 1): opening chat adds the goal and class-pick line, the controls line mentions Q/E unlock, tips stay 30 s. map0-a-spawn.png shows it. Tutorial screen text: skills and class pick.
- Tests: combat_input_test 0 failed, hotplug_test 0 failed, fresh-profile --export-pack + --main-pack boot 0 SCRIPT ERROR.
