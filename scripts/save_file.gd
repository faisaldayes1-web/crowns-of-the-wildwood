extends RefCounted
## The save file (user://controls.cfg): settings, controls and the account's
## progress (level XP, gold, chests, store items, hero and banner looks).
##
## Written safely: the new save goes to a .tmp file first and is read back,
## the old save is kept as .bak, then the .tmp replaces it. A save that will
## not validate falls back to the .bak. Legacy saves remain readable; new
## saves include an identity, version and payload digest to detect truncation.
##
## Progress codes move an account between devices (the iPad web build and a
## PC): EXPORT gives a short text code holding the [profile] section and the
## looks; IMPORT on the other device restores it.

const CODE_PREFIX := "CROWNS1-"
const SAVE_MAGIC := "CROWNS-SAVE"
const SAVE_VERSION := 1
const PROFILE_NUMBERS := ["account_xp", "account_gold", "account_shards", "account_chests"]
## The [settings] keys a progress code carries along with all of [profile].
const LOOK_KEYS := ["hero_name", "hero_hair", "hero_trim", "hero_look", "hero_skin", "hero_face",
	"hero_hair_style", "hero_eye", "hero_mark", "hero_body", "hero_hat", "hero_cape", "hero_outfit",
	"hero_weapon", "banner_bg", "banner_emblem", "banner_frame", "banner_title"]


static func write(cfg: ConfigFile, path: String) -> Error:
	# Validate before touching disk. Do not stamp the caller's ConfigFile: it
	# may also be used to extract the current player's independent save.
	var payload := _payload(cfg)
	if not _valid_payload(payload, path):
		return ERR_FILE_CORRUPT
	var digest := payload.encode_to_text().sha256_text()
	# Keep the header FIRST: a truncated new file must not look like a valid
	# legacy file merely because its metadata footer was lost.
	var stored := ConfigFile.new()
	stored.set_value("save", "magic", SAVE_MAGIC)
	stored.set_value("save", "version", SAVE_VERSION)
	stored.set_value("save", "digest", digest)
	for section in payload.get_sections():
		for key in payload.get_section_keys(section):
			stored.set_value(section, key, payload.get_value(section, key))
	var tmp := path + ".tmp"
	var err := stored.save(tmp)
	if err != OK:
		return err
	var check := ConfigFile.new()
	if check.load(tmp) != OK or not _valid(check, path):
		DirAccess.remove_absolute(tmp)
		return ERR_FILE_CORRUPT
	var previous := ConfigFile.new()
	# A corrupt primary must never replace the last known good backup.
	if previous.load(path) == OK and _valid(previous, path):
		err = DirAccess.copy_absolute(path, path + ".bak")
		if err != OK:
			DirAccess.remove_absolute(tmp)
			return err
	return DirAccess.rename_absolute(tmp, path)


static func read(cfg: ConfigFile, path: String) -> Error:
	## ConfigFile accepts empty/NUL/garbage input as OK: validate its content.
	cfg.clear()
	if cfg.load(path) == OK and _valid(cfg, path):
		return OK
	if FileAccess.file_exists(path + ".bak"):
		cfg.clear()
		if cfg.load(path + ".bak") == OK and _valid(cfg, path):
			push_warning("Save %s would not load: using the backup." % path)
			return OK
	cfg.clear()
	return ERR_FILE_NOT_FOUND


static func _payload(cfg: ConfigFile) -> ConfigFile:
	var out := ConfigFile.new()
	for section in cfg.get_sections():
		if section == "save":
			continue
		for key in cfg.get_section_keys(section):
			out.set_value(section, key, cfg.get_value(section, key))
	return out


static func _valid_profile(cfg: ConfigFile) -> bool:
	# XP has existed since the original single-player save format. Other
	# progress fields are optional for legacy saves, but must have safe types.
	if not cfg.has_section_key("profile", "account_xp"):
		return false
	for key in PROFILE_NUMBERS:
		if cfg.has_section_key("profile", key):
			var value = cfg.get_value("profile", key)
			if not value is int or value < 0:
				return false
	if cfg.has_section_key("profile", "owned_items"):
		var items = cfg.get_value("profile", "owned_items")
		if not (items is Array or items is PackedStringArray):
			return false
		for item in items:
			if not item is String:
				return false
	return true


static func _valid_payload(cfg: ConfigFile, path: String) -> bool:
	# A player file containing only appearance/settings is not a usable
	# profile and must not mask its backup or the copy in controls.cfg.
	if path.replace("\\", "/").contains("/profiles/"):
		return _valid_profile(cfg)
	if cfg.has_section("profile"):
		return _valid_profile(cfg)
	if cfg.has_section("profiles"):
		return false  # a device with a selected player must carry their copy
	# Before player profiles existed, controls.cfg could hold settings and
	# bindings alone. Recognize actual legacy keys, never arbitrary sections.
	for key in ["sound_volume", "music_volume", "hero_name", "movement_schema", "bot_difficulty"]:
		if cfg.has_section_key("settings", key):
			return true
	return cfg.has_section_key("controls", "move_up")


static func _valid(cfg: ConfigFile, path: String) -> bool:
	if not _valid_payload(cfg, path):
		return false
	if cfg.has_section("save"):
		var version = cfg.get_value("save", "version", null)
		if cfg.get_value("save", "magic", "") != SAVE_MAGIC or not version is int or version != SAVE_VERSION:
			return false
		if cfg.get_value("save", "digest", "") != _payload(cfg).encode_to_text().sha256_text():
			return false
	if cfg.has_section("profiles"):
		var current = cfg.get_value("profiles", "current", null)
		if not current is String or current.is_empty():
			return false
	return true


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


# --- Player profiles ----------------------------------------------------------
# Each named player keeps their own file, user://profiles/<id>.cfg, holding
# the [profile] section (level XP, gold, shards, chests, store items) and the
# look keys (name, hero, banner). controls.cfg keeps the device's settings
# and controls plus [profiles] current = <id>, and a copy of the current
# player's data so older builds still read it.

static func profile_of(cfg: ConfigFile) -> ConfigFile:
	## The current player's part of the save, as a profile file.
	var pc := ConfigFile.new()
	if cfg.has_section("profile"):
		for k in cfg.get_section_keys("profile"):
			pc.set_value("profile", k, cfg.get_value("profile", k))
	for k in LOOK_KEYS:
		if cfg.has_section_key("settings", k):
			pc.set_value("settings", k, cfg.get_value("settings", k))
	return pc


static func use_profile(cfg: ConfigFile, pc: ConfigFile) -> void:
	## Puts a player's profile into the save in place of whoever was there
	## (keys the profile lacks fall back to their defaults).
	if not _valid_profile(pc):
		return  # preserve the embedded recovery copy when the player file is bad
	if cfg.has_section("profile"):
		cfg.erase_section("profile")
	for k in LOOK_KEYS:
		if cfg.has_section_key("settings", k):
			cfg.erase_section_key("settings", k)
	if pc.has_section("profile"):
		for k in pc.get_section_keys("profile"):
			cfg.set_value("profile", k, pc.get_value("profile", k))
	for k in LOOK_KEYS:
		if pc.has_section_key("settings", k):
			cfg.set_value("settings", k, pc.get_value("settings", k))
