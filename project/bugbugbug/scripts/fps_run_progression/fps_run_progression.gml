#macro FPS_RUN_TITLE 0
#macro FPS_RUN_PLAYING 1
#macro FPS_RUN_REWARD 2
#macro FPS_RUN_SUMMARY 3
#macro FPS_RUN_ARCHIVE 4
#macro FPS_RUN_RESET_CONFIRM 5

#macro FPS_RUN_REWARD_REPAIR 0
#macro FPS_RUN_REWARD_AMMO 1
#macro FPS_RUN_REWARD_OVERCHARGE 2
#macro FPS_RUN_REWARD_WEAPON 3
#macro FPS_RUN_REWARD_ARCHIVE 4
#macro FPS_RUN_REWARD_VITALS 5
#macro FPS_RUN_REWARD_LIMIT 3

/// Normalizes seed entry without allowing zero to create a broken generator state.
function fps_run_normalize_seed(_seed) {
	if (!is_real(_seed)) {
		return FPS_SECTOR_DEFAULT_SEED;
	}

	var _normalized = abs(floor(_seed)) mod (FPS_SECTOR_SEED_MODULUS - 1);
	return _normalized <= 0 ? FPS_SECTOR_DEFAULT_SEED : _normalized;
}

/// Creates the explicit run state used by the title, encounter, reward, and summary flows.
function fps_run_create_state(_seed) {
	return {
		seed: fps_run_normalize_seed(_seed),
		phase: FPS_RUN_TITLE,
		room_index: 0,
		room_count: FPS_SECTOR_TILE_COUNT,
		room_complete: false,
		rooms_cleared: 0,
		reward_choices: [],
		reward_selection: -1,
		terminal_phase: FPS_STATE_PLAYING,
	};
}

/// Starts a clean run while preserving only the selected seed and profile state outside it.
function fps_run_begin(_seed) {
	var _state = fps_run_create_state(_seed);
	_state.phase = FPS_RUN_PLAYING;
	_state.room_complete = true;
	return _state;
}

/// Advances to exactly one next generated tile after the current tile is complete.
function fps_run_advance_room(_state) {
	if (!_state.room_complete || _state.room_index >= _state.room_count - 1) {
		return _state;
	}

	_state.room_index += 1;
	_state.room_complete = false;
	_state.phase = FPS_RUN_PLAYING;
	_state.reward_choices = [];
	_state.reward_selection = -1;
	return _state;
}

/// Marks a room clear without ending the run before its later rooms and finale.
function fps_run_mark_room_complete(_state) {
	if (!_state.room_complete) {
		_state.rooms_cleared += 1;
	}
	_state.room_complete = true;
	return _state;
}

/// Opens the deterministic choice screen between combat spaces.
function fps_run_begin_reward(_state, _choices) {
	_state.phase = FPS_RUN_REWARD;
	_state.room_complete = false;
	_state.reward_choices = _choices;
	_state.reward_selection = -1;
	return _state;
}

/// Applies a selected reward and returns the run to a traversable state.
function fps_run_select_reward(_state, _choice_index) {
	if (
		_state.phase != FPS_RUN_REWARD
		|| _choice_index < 0
		|| _choice_index >= array_length(_state.reward_choices)
	) {
		return false;
	}

	_state.rooms_cleared += 1;
	_state.reward_selection = _choice_index;
	_state.phase = FPS_RUN_PLAYING;
	_state.room_complete = true;
	return true;
}

/// Records terminal state separately from the combat phase so summary input stays valid.
function fps_run_finish(_state, _terminal_phase) {
	_state.phase = FPS_RUN_SUMMARY;
	_state.terminal_phase = _terminal_phase;
	_state.room_complete = true;
	return _state;
}

/// Returns the pressure tier that escalates toward the final tile.
function fps_run_room_pressure(_sector, _room_index, _seed) {
	var _role = _sector.tiles[_room_index].role;
	if (_role == FPS_SECTOR_ROLE_FINALE) {
		return 3;
	}
	if (_role != FPS_SECTOR_ROLE_COMBAT) {
		return 0;
	}

	return clamp(1 + floor(_room_index / 2) + (fps_sector_next_seed(_seed) mod 2), 1, 3);
}

/// Builds a role/socket plan for one tile without touching GameMaker's global RNG.
function fps_run_create_room_plan(_sector, _seed, _room_index, _pressure) {
	var _tile = _sector.tiles[_room_index];
	var _is_finale = _tile.role == FPS_SECTOR_ROLE_FINALE;
	var _candidate_sockets = [];
	for (var _socket_index = 0; _socket_index < array_length(_sector.combat_sockets); _socket_index += 1) {
		var _socket = _sector.combat_sockets[_socket_index];
		if (_socket.tile_index == _room_index) {
			array_push(_candidate_sockets, {socket: _socket, index: _socket_index});
		}
	}

	var _entry_count = min(array_length(_candidate_sockets), _is_finale ? 2 : max(1, min(2, _pressure)));
	var _random_state = fps_sector_next_seed(_seed + 7919 * (_room_index + 1));
	var _entries = [];
	var _previous_kind = -1;
	for (var _entry_index = 0; _entry_index < _entry_count; _entry_index += 1) {
		var _kind_pick = fps_sector_take_random(_random_state, _is_finale ? FPS_ENEMY_KIND_COUNT : FPS_ENEMY_KIND_COUNT - 1);
		_random_state = _kind_pick.seed;
		var _kind = _kind_pick.value;
		if (_is_finale && _entry_index == _entry_count - 1) {
			_kind = FPS_ENEMY_KIND_TITAN;
		}
		if (_kind == _previous_kind && !(_is_finale && _entry_index == _entry_count - 1)) {
			_kind = (_kind + 1) mod (_is_finale ? FPS_ENEMY_KIND_COUNT : FPS_ENEMY_KIND_COUNT - 1);
		}

		var _candidate = _candidate_sockets[_entry_index];
		var _socket = _candidate.socket;
		array_push(_entries, {
			identity: fps_enemy_role_name(_kind),
			kind: _kind,
			socket_id: _socket.id,
			socket_index: _candidate.index,
			tile_index: _room_index,
			x: _socket.x,
			y: _socket.y,
		});
		_previous_kind = _kind;
	}

	return {
		seed: _seed,
		room_index: _room_index,
		pressure: _pressure,
		entries: _entries,
		signature: fps_enemy_encounter_signature(_entries),
	};
}

/// Creates the base and profile-expanded reward pool in stable identity order.
function fps_run_reward_pool(_profile) {
	var _pool = [
		{kind: FPS_RUN_REWARD_REPAIR, label: "REPAIR", description: "Restore 35 vital points."},
		{kind: FPS_RUN_REWARD_AMMO, label: "AMMO CELL", description: "Refill the equipped weapon reserve."},
		{kind: FPS_RUN_REWARD_OVERCHARGE, label: "OVERCHARGE", description: "Power the next 15 seconds of fire."},
	];
	if (fps_profile_has_unlock(_profile, FPS_PROFILE_UNLOCK_RAIL)) {
		array_push(_pool, {
			kind: FPS_RUN_REWARD_WEAPON,
			weapon_id: FPS_WEAPON_RAIL,
			label: "RAIL LANCE",
			description: "Add the long-range weapon to this run.",
		});
	}
	if (fps_profile_has_unlock(_profile, FPS_PROFILE_UNLOCK_ARCHIVE)) {
		array_push(_pool, {
			kind: FPS_RUN_REWARD_ARCHIVE,
			label: "ARCHIVE ECHO",
			description: "Record a persistent echo and broaden future cards.",
		});
	}
	if (fps_profile_has_unlock(_profile, FPS_PROFILE_UNLOCK_VITALS)) {
		array_push(_pool, {
			kind: FPS_RUN_REWARD_VITALS,
			label: "VITAL BUFFER",
			description: "Raise this run's maximum health by 15.",
		});
	}

	return _pool;
}

/// Selects three reproducible choices from the current profile-expanded pool.
function fps_run_create_reward_choices(_seed, _room_index, _profile) {
	var _pool = fps_run_reward_pool(_profile);
	var _random_state = fps_sector_next_seed(_seed + 104729 * (_room_index + 1));
	var _choices = [];
	while (array_length(_choices) < min(FPS_RUN_REWARD_LIMIT, array_length(_pool))) {
		var _pick = fps_sector_take_random(_random_state, array_length(_pool));
		_random_state = _pick.seed;
		var _selected = _pool[_pick.value];
		array_push(_choices, _selected);
		var _remaining = [];
		for (var _pool_index = 0; _pool_index < array_length(_pool); _pool_index += 1) {
			if (_pool_index != _pick.value) {
				array_push(_remaining, _pool[_pool_index]);
			}
		}
		_pool = _remaining;
	}

	return _choices;
}

/// Serializes choices by stable IDs for deterministic replay tests and diagnostics.
function fps_run_reward_signature(_choices) {
	var _signature = "";
	for (var _choice_index = 0; _choice_index < array_length(_choices); _choice_index += 1) {
		var _choice = _choices[_choice_index];
		var _weapon_id = variable_struct_exists(_choice, "weapon_id") ? _choice.weapon_id : -1;
		_signature += string(_choice.kind) + ":" + string(_weapon_id) + "|";
	}

	return _signature;
}

/// Applies one selected card while returning all state changes to the controller.
function fps_run_apply_reward(_choice, _loadout, _current_health, _max_health, _profile) {
	var _result = {
		health: _current_health,
		max_health: _max_health,
		message: "REWARD ACCEPTED",
	};
	switch (_choice.kind) {
		case FPS_RUN_REWARD_REPAIR:
			_result.health = min(_max_health, _current_health + 35);
			_result.message = "REPAIRED +" + string(_result.health - _current_health);
			break;
		case FPS_RUN_REWARD_AMMO:
			var _ammo_pickup = {kind: FPS_PICKUP_AMMO, weapon_id: -1, collected: false};
			var _ammo_result = fps_weapon_collect_pickup(_loadout, _ammo_pickup, _current_health, _max_health);
			_result.health = _ammo_result.health;
			_result.message = _ammo_result.consumed ? "AMMO RESERVE REFILLED" : "AMMO RESERVE ALREADY FULL";
			break;
		case FPS_RUN_REWARD_OVERCHARGE:
			_loadout.overcharge_frames = FPS_WEAPON_OVERCHARGE_GAIN;
			_result.message = "OVERCHARGE ONLINE";
			break;
		case FPS_RUN_REWARD_WEAPON:
			var _weapon_id = _choice.weapon_id;
			var _weapon_state = _loadout.states[_weapon_id];
			var _weapon_definition = fps_weapon_definition(_weapon_id);
			_weapon_state.owned = true;
			_weapon_state.magazine = _weapon_definition.magazine_size;
			_weapon_state.reserve = _weapon_definition.initial_reserve;
			_result.message = "ACQUIRED " + _weapon_definition.label;
			break;
		case FPS_RUN_REWARD_ARCHIVE:
			fps_profile_grant_unlock(_profile, FPS_PROFILE_UNLOCK_ARCHIVE);
			_result.message = "ARCHIVE ECHO RECORDED";
			break;
		case FPS_RUN_REWARD_VITALS:
			_result.max_health = _max_health + 15;
			_result.health = min(_result.max_health, _current_health + 15);
			_result.message = "VITAL BUFFER +15 MAX";
			break;
	}

	return _result;
}

/// Returns the readable label used by the reward panel and automated diagnostics.
function fps_run_reward_kind_name(_kind) {
	switch (_kind) {
		case FPS_RUN_REWARD_REPAIR: return "REPAIR";
		case FPS_RUN_REWARD_AMMO: return "AMMO CELL";
		case FPS_RUN_REWARD_OVERCHARGE: return "OVERCHARGE";
		case FPS_RUN_REWARD_WEAPON: return "WEAPON";
		case FPS_RUN_REWARD_ARCHIVE: return "ARCHIVE ECHO";
		case FPS_RUN_REWARD_VITALS: return "VITAL BUFFER";
	}

	return "UNKNOWN REWARD";
}
