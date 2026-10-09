extends RefCounted
## The save file (user://controls.cfg): settings, controls and the account's
## progress (level XP, gold, chests, store items, hero and banner looks).
##
## Written safely: the new save goes to a .tmp file first and is read back,
## the old save is kept as .bak, then the .tmp replaces it. A save that will
## not load falls back to the .bak.
##
## Progress codes move an account between devices (the iPad web build and a
## PC): EXPORT gives a short text code holding the [profile] section and the
## looks; IMPORT on the other device restores it.

const CODE_PREFIX := "CROWNS1-"
## The [settings] keys a progress code carries along with all of [profile].
const LOOK_KEYS := ["hero_name", "hero_hair", "hero_trim", "hero_look", "hero_skin", "hero_face",
	"hero_hair_style", "hero_eye", "hero_mark", "hero_body", "hero_hat", "hero_cape", "hero_outfit",
	"hero_weapon", "banner_bg", "banner_emblem", "banner_frame", "banner_title"]


static func write(cfg: ConfigFile, path: String) -> Error:
	var tmp := path + ".tmp"
	var err := cfg.save(tmp)
	if err != OK:
		return err
	var check := ConfigFile.new()
	if check.load(tmp) != OK:
		DirAccess.remove_absolute(tmp)
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(tmp, path)


static func read(cfg: ConfigFile, path: String) -> Error:
	## The save, or its .bak when the save is missing or will not load.
	if cfg.load(path) == OK:
		return OK
	if FileAccess.file_exists(path + ".bak"):
		cfg.clear()
		if cfg.load(path + ".bak") == OK:
			push_warning("Save %s would not load: using the backup." % path)
			return OK
	cfg.clear()
	return ERR_FILE_NOT_FOUND


static func export_code(cfg: ConfigFile) -> String:
	var data := {"profile": {}, "settings": {}}
	if cfg.has_section("profile"):
		for k in cfg.get_section_keys("profile"):
			data.profile[k] = cfg.get_value("profile", k)
	for k in LOOK_KEYS:
		if cfg.has_section_key("settings", k):
			data.settings[k] = cfg.get_value("settings", k)
	var body := Marshalls.utf8_to_base64(JSON.stringify(data))
	return CODE_PREFIX + body + "-" + _check(body)


static func parse_code(code: String) -> Dictionary:
	## The code's contents, or {} when it is not a whole, unaltered code.
	code = code.strip_edges().replace(" ", "").replace("\n", "").replace("\r", "")
	if not code.begins_with(CODE_PREFIX):
		return {}
	code = code.trim_prefix(CODE_PREFIX)
	var dash := code.rfind("-")
	if dash < 0:
		return {}
	var body := code.substr(0, dash)
	if code.substr(dash + 1) != _check(body):
		return {}
	var data = JSON.parse_string(Marshalls.base64_to_utf8(body))
	if not data is Dictionary or not data.get("profile") is Dictionary or not data.get("settings") is Dictionary:
		return {}
	return data


static func apply_code(cfg: ConfigFile, data: Dictionary) -> void:
	## Puts a parsed code's progress and looks into the save, replacing them.
	if cfg.has_section("profile"):
		cfg.erase_section("profile")
	for k in data.profile:
		var v = data.profile[k]
		if k == "owned_items" and v is Array:
			v = v.filter(func(s): return s is String)
		elif v is float:
			v = int(v)   # JSON gives numbers back as floats
		cfg.set_value("profile", k, v)
	for k in data.settings:
		if k in LOOK_KEYS:
			var v = data.settings[k]
			cfg.set_value("settings", k, int(v) if v is float else v)


static func _check(body: String) -> String:
	return body.sha256_text().substr(0, 8)
