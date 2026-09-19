#macro FPS_PROFILE_SAVE_VERSION 2
#macro FPS_PROFILE_LEGACY_SAVE_VERSION 1
#macro FPS_PROFILE_SAVE_FILE "containment_protocol_profile.ini"
#macro FPS_PROFILE_LORE_COUNT 6
#macro FPS_PROFILE_UNLOCK_COUNT 3
#macro FPS_PROFILE_UNLOCK_RAIL "rail-lance"
#macro FPS_PROFILE_UNLOCK_ARCHIVE "archive-echo"
#macro FPS_PROFILE_UNLOCK_VITALS "vital-buffer"
#macro FPS_PROFILE_DEFAULT_MOUSE_SENSITIVITY 0.16
#macro FPS_PROFILE_MIN_MOUSE_SENSITIVITY 0.04
#macro FPS_PROFILE_MAX_MOUSE_SENSITIVITY 0.50
#macro FPS_PROFILE_MOUSE_SENSITIVITY_STEP 0.02

/// Returns the stable identity for one persistent content unlock.
function fps_profile_unlock_id(_index) {
	switch (_index) {
		case 0: return FPS_PROFILE_UNLOCK_RAIL;
		case 1: return FPS_PROFILE_UNLOCK_ARCHIVE;
		case 2: return FPS_PROFILE_UNLOCK_VITALS;
	}

	return "unknown-unlock";
}

/// Accepts only bounded sensitivity values from the persistent profile.
function fps_profile_mouse_sensitivity_is_valid(_value) {
	return is_real(_value)
		&& _value >= FPS_PROFILE_MIN_MOUSE_SENSITIVITY
		&& _value <= FPS_PROFILE_MAX_MOUSE_SENSITIVITY;
}

/// Accepts the boolean forms written by GameMaker and the INI loader.
function fps_profile_invert_vertical_look_is_valid(_value) {
	return is_bool(_value) || (is_real(_value) && (_value == 0 || _value == 1));
}

/// Converts missing, malformed, or out-of-range sensitivity to the safe default.
function fps_profile_normalize_mouse_sensitivity(_value) {
	return fps_profile_mouse_sensitivity_is_valid(_value)
		? _value
		: FPS_PROFILE_DEFAULT_MOUSE_SENSITIVITY;
}

/// Converts missing or malformed inversion data to the safe non-inverted default.
function fps_profile_normalize_invert_vertical_look(_value) {
	return fps_profile_invert_vertical_look_is_valid(_value) && _value != 0;
}

/// Changes sensitivity in bounded steps for the title settings screen.
function fps_profile_adjust_mouse_sensitivity(_value, _direction) {
	var _safe_value = fps_profile_normalize_mouse_sensitivity(_value);
	var _safe_direction = is_real(_direction) ? clamp(round(_direction), -1, 1) : 0;
	var _next_value = _safe_value + _safe_direction * FPS_PROFILE_MOUSE_SENSITIVITY_STEP;
	return clamp(round(_next_value * 100) / 100, FPS_PROFILE_MIN_MOUSE_SENSITIVITY, FPS_PROFILE_MAX_MOUSE_SENSITIVITY);
}

/// Applies one captured vertical mouse delta using the selected inversion setting.
function fps_profile_apply_vertical_look(_pitch, _mouse_delta_y, _sensitivity, _invert_vertical_look) {
	var _safe_sensitivity = fps_profile_normalize_mouse_sensitivity(_sensitivity);
	var _direction = fps_profile_normalize_invert_vertical_look(_invert_vertical_look) ? 1 : -1;
	return clamp(_pitch + _direction * _mouse_delta_y * _safe_sensitivity, -72, 72);
}

/// Creates the safe empty profile used for missing, corrupt, and new saves.
function fps_profile_defaults() {
	return {
		save_version: FPS_PROFILE_SAVE_VERSION,
		runs: 0,
		victories: 0,
		discovered_lore: array_create(FPS_PROFILE_LORE_COUNT, false),
		unlocks: array_create(FPS_PROFILE_UNLOCK_COUNT, false),
		mouse_sensitivity: FPS_PROFILE_DEFAULT_MOUSE_SENSITIVITY,
		invert_vertical_look: false,
	};
}

/// Checks the persistent profile data shared by v1 saves and the current contract.
function fps_profile_data_is_valid(_data) {
	if (!is_struct(_data)) {
		return false;
	}
	if (
		!variable_struct_exists(_data, "save_version")
		|| !variable_struct_exists(_data, "runs")
		|| !variable_struct_exists(_data, "victories")
		|| !variable_struct_exists(_data, "discovered_lore")
		|| !variable_struct_exists(_data, "unlocks")
	) {
		return false;
	}
	if (
		!is_real(_data.save_version)
		|| (
			_data.save_version != FPS_PROFILE_SAVE_VERSION
			&& _data.save_version != FPS_PROFILE_LEGACY_SAVE_VERSION
		)
		|| !is_real(_data.runs)
		|| !is_real(_data.victories)
		|| !is_array(_data.discovered_lore)
		|| !is_array(_data.unlocks)
	) {
		return false;
	}

	if (
		array_length(_data.discovered_lore) != FPS_PROFILE_LORE_COUNT
		|| array_length(_data.unlocks) != FPS_PROFILE_UNLOCK_COUNT
	) {
		return false;
	}
	for (var _lore_index = 0; _lore_index < FPS_PROFILE_LORE_COUNT; _lore_index += 1) {
		if (!is_bool(_data.discovered_lore[_lore_index]) && !is_real(_data.discovered_lore[_lore_index])) {
			return false;
		}
	}
	for (var _unlock_index = 0; _unlock_index < FPS_PROFILE_UNLOCK_COUNT; _unlock_index += 1) {
		if (!is_bool(_data.unlocks[_unlock_index]) && !is_real(_data.unlocks[_unlock_index])) {
			return false;
		}
	}

	return true;
}

/// Converts a profile to a small, explicit record used by tests and file IO.
function fps_profile_to_data(_profile) {
	if (!is_struct(_profile)) {
		return fps_profile_defaults();
	}
	var _discovered_lore = array_create(FPS_PROFILE_LORE_COUNT, false);
	var _unlocks = array_create(FPS_PROFILE_UNLOCK_COUNT, false);
	for (var _lore_index = 0; _lore_index < FPS_PROFILE_LORE_COUNT; _lore_index += 1) {
		_discovered_lore[_lore_index] = _profile.discovered_lore[_lore_index];
	}
	for (var _unlock_index = 0; _unlock_index < FPS_PROFILE_UNLOCK_COUNT; _unlock_index += 1) {
		_unlocks[_unlock_index] = _profile.unlocks[_unlock_index];
	}
	var _mouse_sensitivity = FPS_PROFILE_DEFAULT_MOUSE_SENSITIVITY;
	if (variable_struct_exists(_profile, "mouse_sensitivity")) {
		_mouse_sensitivity = fps_profile_normalize_mouse_sensitivity(_profile.mouse_sensitivity);
	}
	var _invert_vertical_look = false;
	if (variable_struct_exists(_profile, "invert_vertical_look")) {
		_invert_vertical_look = fps_profile_normalize_invert_vertical_look(_profile.invert_vertical_look);
	}

	return {
		save_version: FPS_PROFILE_SAVE_VERSION,
		runs: max(0, floor(_profile.runs)),
		victories: max(0, floor(_profile.victories)),
		discovered_lore: _discovered_lore,
		unlocks: _unlocks,
		mouse_sensitivity: _mouse_sensitivity,
		invert_vertical_look: _invert_vertical_look,
	};
}

/// Rebuilds a profile only from a validated record, falling back atomically.
function fps_profile_from_data(_data) {
	if (!fps_profile_data_is_valid(_data)) {
		return fps_profile_defaults();
	}

	var _profile = fps_profile_defaults();
	_profile.runs = max(0, floor(_data.runs));
	_profile.victories = max(0, floor(_data.victories));
	for (var _lore_index = 0; _lore_index < FPS_PROFILE_LORE_COUNT; _lore_index += 1) {
		_profile.discovered_lore[_lore_index] = _data.discovered_lore[_lore_index] != 0;
	}
	for (var _unlock_index = 0; _unlock_index < FPS_PROFILE_UNLOCK_COUNT; _unlock_index += 1) {
		_profile.unlocks[_unlock_index] = _data.unlocks[_unlock_index] != 0;
	}
	if (variable_struct_exists(_data, "mouse_sensitivity")) {
		_profile.mouse_sensitivity = fps_profile_normalize_mouse_sensitivity(_data.mouse_sensitivity);
	}
	if (variable_struct_exists(_data, "invert_vertical_look")) {
		_profile.invert_vertical_look = fps_profile_normalize_invert_vertical_look(_data.invert_vertical_look);
	}

	return _profile;
}

/// Returns the number of archive entries discovered across all runs.
function fps_profile_discovered_lore_count(_profile) {
	var _count = 0;
	for (var _lore_index = 0; _lore_index < FPS_PROFILE_LORE_COUNT; _lore_index += 1) {
		if (_profile.discovered_lore[_lore_index]) {
			_count += 1;
		}
	}

	return _count;
}

/// Returns whether a stable unlock identity is active in the profile.
function fps_profile_has_unlock(_profile, _unlock_id) {
	for (var _unlock_index = 0; _unlock_index < FPS_PROFILE_UNLOCK_COUNT; _unlock_index += 1) {
		if (
			fps_profile_unlock_id(_unlock_index) == _unlock_id
			&& _profile.unlocks[_unlock_index]
		) {
			return true;
		}
	}

	return false;
}

/// Grants one bounded unlock and reports whether the profile changed.
function fps_profile_grant_unlock(_profile, _unlock_id) {
	for (var _unlock_index = 0; _unlock_index < FPS_PROFILE_UNLOCK_COUNT; _unlock_index += 1) {
		if (fps_profile_unlock_id(_unlock_index) == _unlock_id) {
			var _was_locked = !_profile.unlocks[_unlock_index];
			_profile.unlocks[_unlock_index] = true;
			return _was_locked;
		}
	}

	return false;
}

/// Records one archive identity without allowing unknown content into the save.
function fps_profile_discover_lore(_profile, _lore_id) {
	var _entries = fps_create_lore_entries();
	for (var _lore_index = 0; _lore_index < array_length(_entries); _lore_index += 1) {
		if (_entries[_lore_index].id == _lore_id) {
			var _was_new = !_profile.discovered_lore[_lore_index];
			_profile.discovered_lore[_lore_index] = true;
			return _was_new;
		}
	}

	return false;
}

/// Adds a run to the persistent history before gameplay begins.
function fps_profile_record_run_started(_profile) {
	_profile.runs += 1;
	return _profile;
}

/// Applies bounded rewards earned by a completed run.
function fps_profile_record_run_finished(_profile, _victory) {
	if (_victory) {
		_profile.victories += 1;
		fps_profile_grant_unlock(_profile, FPS_PROFILE_UNLOCK_RAIL);
	}
	if (fps_profile_discovered_lore_count(_profile) >= 3) {
		fps_profile_grant_unlock(_profile, FPS_PROFILE_UNLOCK_ARCHIVE);
	}
	if (_profile.victories >= 2) {
		fps_profile_grant_unlock(_profile, FPS_PROFILE_UNLOCK_VITALS);
	}

	return _profile;
}

/// Returns the starting health broadened by an earned profile unlock.
function fps_profile_starting_max_health(_profile) {
	return FPS_PLAYER_MAX_HEALTH + (fps_profile_has_unlock(_profile, FPS_PROFILE_UNLOCK_VITALS) ? 15 : 0);
}

/// Writes one stable versioned profile to a named INI and closes it before returning.
function fps_profile_save_file(_profile, _filename) {
	var _data = fps_profile_to_data(_profile);
	ini_open(_filename);
	ini_write_real("meta", "version", _data.save_version);
	ini_write_real("meta", "runs", _data.runs);
	ini_write_real("meta", "victories", _data.victories);
	for (var _lore_index = 0; _lore_index < FPS_PROFILE_LORE_COUNT; _lore_index += 1) {
		var _lore_id = fps_create_lore_entries()[_lore_index].id;
		ini_write_real("lore", _lore_id, _data.discovered_lore[_lore_index] ? 1 : 0);
	}
	for (var _unlock_index = 0; _unlock_index < FPS_PROFILE_UNLOCK_COUNT; _unlock_index += 1) {
		var _unlock_id = fps_profile_unlock_id(_unlock_index);
		ini_write_real("unlocks", _unlock_id, _data.unlocks[_unlock_index] ? 1 : 0);
	}
	ini_write_real("settings", "mouse_sensitivity", _data.mouse_sensitivity);
	ini_write_real("settings", "invert_vertical_look", _data.invert_vertical_look ? 1 : 0);
	ini_close();
	return true;
}

/// Loads a named profile or returns documented defaults for absent or unsupported data.
function fps_profile_load_file(_filename) {
	if (!file_exists(_filename)) {
		return fps_profile_defaults();
	}

	ini_open(_filename);
	var _data = {
		save_version: ini_read_real("meta", "version", -1),
		runs: ini_read_real("meta", "runs", 0),
		victories: ini_read_real("meta", "victories", 0),
		discovered_lore: array_create(FPS_PROFILE_LORE_COUNT, false),
		unlocks: array_create(FPS_PROFILE_UNLOCK_COUNT, false),
		mouse_sensitivity: ini_read_real(
			"settings",
			"mouse_sensitivity",
			FPS_PROFILE_DEFAULT_MOUSE_SENSITIVITY
		),
		invert_vertical_look: ini_read_real("settings", "invert_vertical_look", 0),
	};
	for (var _lore_index = 0; _lore_index < FPS_PROFILE_LORE_COUNT; _lore_index += 1) {
		var _lore_id = fps_create_lore_entries()[_lore_index].id;
		_data.discovered_lore[_lore_index] = ini_read_real("lore", _lore_id, 0) != 0;
	}
	for (var _unlock_index = 0; _unlock_index < FPS_PROFILE_UNLOCK_COUNT; _unlock_index += 1) {
		var _unlock_id = fps_profile_unlock_id(_unlock_index);
		_data.unlocks[_unlock_index] = ini_read_real("unlocks", _unlock_id, 0) != 0;
	}
	ini_close();
	return fps_profile_from_data(_data);
}

/// Writes the player profile to its one stable local save file.
function fps_profile_save(_profile) {
	return fps_profile_save_file(_profile, FPS_PROFILE_SAVE_FILE);
}

/// Loads the player profile from its one stable local save file.
function fps_profile_load() {
	return fps_profile_load_file(FPS_PROFILE_SAVE_FILE);
}

/// Creates the clean profile used by explicit reset and recovery paths.
function fps_profile_reset_data() {
	return fps_profile_defaults();
}

/// Deletes a named profile file and returns a clean in-memory profile.
function fps_profile_reset_file_as(_filename) {
	if (file_exists(_filename)) {
		file_delete(_filename);
	}

	return fps_profile_reset_data();
}

/// Deletes the one profile file and returns a clean in-memory profile.
function fps_profile_reset_file() {
	return fps_profile_reset_file_as(FPS_PROFILE_SAVE_FILE);
}
