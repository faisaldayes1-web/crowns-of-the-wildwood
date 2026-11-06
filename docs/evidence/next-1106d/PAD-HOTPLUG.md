# Real DualSense hot-plug check (claude-faisal3, 2026-11-06)

A windowed match that logs every connection event, button press (with the glyph set the HUD would use) and
pulses the pad's rumble when it connects. Needs a person at the laptop3 desk (or anyone with a pad).

From the repo root of this branch, with Godot 4.3 (not headless):

    CROWNS_PAD_LOG=C:/Temp/padlog.txt GODOT=<godot.exe> TMPDIR=<tmp> tools/tests/isolated.sh --path . --script tools/hotplug_live.gd -- --seconds=900

1. Start a match from the menu (Play > Start Match). The log line `ALREADY CONNECTED ...` lists pads present at boot.
2. Unplug / switch off the pad (hold PS button, or pull the cable). Expect `DISCONNECTED device N` and the in-game toast
   "Gamepad disconnected". The hero must stay controllable on keyboard + mouse; nothing latched (no walking on its own).
3. Plug / switch it on again. Expect `CONNECTED ... kind=ps title='DualSense (PS5)'` (Edge: `DualSense Edge (PS5)`),
   a toast "... connected", and a half-second rumble (`rumble pulse sent`).
4. Press buttons: `BUTTON n ... glyph kind=ps` lines; the HUD slot caps should read Cross / Circle / Square / Triangle / R1 / R3.
5. `R` on the keyboard = a one-second full rumble on every pad. `Shift+Esc` quits. Send the log file back.

Pass = every unplug/replug logs a matching event pair, no stuck input, toasts show, rumble felt on connect and on R.
Windowed evidence already gathered by the agent (Edge on Bluetooth, shown by Godot as "PS5 Controller", GUID 030000004c050000f20d):
`pad_edge_check.log` and the `edge_*.png` stills in this folder.
