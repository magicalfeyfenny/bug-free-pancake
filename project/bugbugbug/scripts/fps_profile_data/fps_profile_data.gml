#macro FPS_PROFILE_SAVE_VERSION 1
#macro FPS_PROFILE_SAVE_FILE "containment_protocol_profile.ini"
#macro FPS_PROFILE_LORE_COUNT 6
#macro FPS_PROFILE_UNLOCK_COUNT 3
#macro FPS_PROFILE_UNLOCK_RAIL "rail-lance"
#macro FPS_PROFILE_UNLOCK_ARCHIVE "archive-echo"
#macro FPS_PROFILE_UNLOCK_VITALS "vital-buffer"

/// Returns the stable identity for one persistent content unlock.
function fps_profile_unlock_id(_index) {
	switch (_index) {
		case 0: return FPS_PROFILE_UNLOCK_RAIL;
		case 1: return FPS_PROFILE_UNLOCK_ARCHIVE;
		case 2: return FPS_PROFILE_UNLOCK_VITALS;
	}

	return "unknown-unlock";
}

/// Creates the safe empty profile used for missing, corrupt, and new saves.
function fps_profile_defaults() {
	return {
		save_version: FPS_PROFILE_SAVE_VERSION,
		runs: 0,
		victories: 0,
		discovered_lore: array_create(FPS_PROFILE_LORE_COUNT, false),
		unlocks: array_create(FPS_PROFILE_UNLOCK_COUNT, false),
	};
}

/// Checks the complete in-memory save contract before it is trusted.
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
		|| _data.save_version != FPS_PROFILE_SAVE_VERSION
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

	return {
		save_version: FPS_PROFILE_SAVE_VERSION,
		runs: max(0, floor(_profile.runs)),
		victories: max(0, floor(_profile.victories)),
		discovered_lore: _discovered_lore,
		unlocks: _unlocks,
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

/// Writes one stable versioned profile and closes the INI before returning.
function fps_profile_save(_profile) {
	var _data = fps_profile_to_data(_profile);
	ini_open(FPS_PROFILE_SAVE_FILE);
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
	ini_close();
	return true;
}

/// Loads the profile or returns documented defaults for absent or unsupported data.
function fps_profile_load() {
	if (!file_exists(FPS_PROFILE_SAVE_FILE)) {
		return fps_profile_defaults();
	}

	ini_open(FPS_PROFILE_SAVE_FILE);
	var _data = {
		save_version: ini_read_real("meta", "version", -1),
		runs: ini_read_real("meta", "runs", 0),
		victories: ini_read_real("meta", "victories", 0),
		discovered_lore: array_create(FPS_PROFILE_LORE_COUNT, false),
		unlocks: array_create(FPS_PROFILE_UNLOCK_COUNT, false),
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

/// Creates the clean profile used by explicit reset and recovery paths.
function fps_profile_reset_data() {
	return fps_profile_defaults();
}

/// Deletes the one profile file and returns a clean in-memory profile.
function fps_profile_reset_file() {
	if (file_exists(FPS_PROFILE_SAVE_FILE)) {
		file_delete(FPS_PROFILE_SAVE_FILE);
	}

	return fps_profile_reset_data();
}
