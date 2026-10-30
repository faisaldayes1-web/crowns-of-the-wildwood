extends SceneTree
## Writes THIRD-PARTY-NOTICES.txt for a release folder: this game's own asset
## credits (assets/CREDITS.md), the font licences, GodotSteam's licence, and
## the Godot engine's licence plus every third-party component the engine
## binary carries (read from the running engine, so it matches the version).
## Usage: godot --headless --path . --script tools/write_notices.gd -- <out_file> [--steam]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("usage: -- <out_file> [--steam]")
		quit(2)
		return
	var out := FileAccess.open(args[0], FileAccess.WRITE)
	if out == null:
		push_error("cannot write " + args[0])
		quit(2)
		return
	var line := "=".repeat(78)
	out.store_line("Crowns of the Wildwood: third-party notices")
	out.store_line(line)
	out.store_line("")
	out.store_line(_read("res://assets/CREDITS.md"))
	for f in ["res://assets/fonts/OFL-LilitaOne.txt", "res://assets/fonts/LICENSE-LuckiestGuy.txt"]:
		out.store_line(line)
		out.store_line(f.get_file())
		out.store_line(line)
		out.store_line(_read(f))
	if "--steam" in args:
		out.store_line(line)
		out.store_line("GodotSteam (tools/steam/godotsteam), MIT License")
		out.store_line(line)
		out.store_line(_read_abs(ProjectSettings.globalize_path("res://tools/steam/godotsteam/license.txt")))
		out.store_line("steam_api64.dll is part of the Steamworks SDK, (c) Valve Corporation, redistributed under the Steamworks SDK Access Agreement.")
		out.store_line("")
	out.store_line(line)
	out.store_line("Godot Engine %s" % Engine.get_version_info().string)
	out.store_line(line)
	out.store_line(Engine.get_license_text())
	out.store_line(line)
	out.store_line("Third-party components in the Godot Engine binary")
	out.store_line(line)
	for c in Engine.get_copyright_info():
		out.store_line("")
		out.store_line("- %s" % c.name)
		for part in c.parts:
			out.store_line("  Files: %s" % ", ".join(PackedStringArray(part.files)))
			for who in part.copyright:
				out.store_line("  Copyright: %s" % who)
			out.store_line("  License: %s" % part.license)
	var licences: Dictionary = Engine.get_license_info()
	for name in licences:
		out.store_line("")
		out.store_line(line)
		out.store_line("License: %s" % name)
		out.store_line(line)
		out.store_line(licences[name])
	out.close()
	print("notices written: ", args[0])
	quit()


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else "(missing: %s)" % path


func _read_abs(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else "(missing: %s)" % path
