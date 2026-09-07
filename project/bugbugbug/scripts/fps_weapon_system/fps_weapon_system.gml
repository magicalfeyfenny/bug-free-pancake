#macro FPS_WEAPON_PULSE 0
#macro FPS_WEAPON_SCATTER 1
#macro FPS_WEAPON_BURST 2
#macro FPS_WEAPON_RAIL 3
#macro FPS_WEAPON_COUNT 4

#macro FPS_PICKUP_HEALTH 0
#macro FPS_PICKUP_WEAPON 1
#macro FPS_PICKUP_AMMO 2
#macro FPS_PICKUP_OVERCHARGE 3
#macro FPS_PICKUP_COUNT 4

#macro FPS_WEAPON_PICKUP_RANGE 82
#macro FPS_WEAPON_AMMO_PICKUP 18
#macro FPS_WEAPON_OVERCHARGE_GAIN 360
#macro FPS_WEAPON_OVERCHARGE_MAX 900

/// Returns the authored contract for one usable weapon archetype.
function fps_weapon_definition(_weapon_id) {
	switch (_weapon_id) {
		case FPS_WEAPON_PULSE:
			return {
				id: FPS_WEAPON_PULSE,
				identity: "pulse-rifle",
				label: "PULSE RIFLE",
				pattern: "SINGLE",
				damage: 34,
				range: 1600,
				fire_delay: 10,
				magazine_size: 12,
				reserve_max: 48,
				initial_reserve: 48,
				pickup_reserve: 24,
				pellets: 1,
				spread_degrees: 0,
				colour: make_color_rgb(34, 201, 221),
			};
		case FPS_WEAPON_SCATTER:
			return {
				id: FPS_WEAPON_SCATTER,
				identity: "scatter-cannon",
				label: "SCATTER CANNON",
				pattern: "CONE x5",
				damage: 12,
				range: 720,
				fire_delay: 30,
				magazine_size: 6,
				reserve_max: 24,
				initial_reserve: 24,
				pickup_reserve: 12,
				pellets: 5,
				spread_degrees: 7,
				colour: make_color_rgb(255, 174, 67),
			};
		case FPS_WEAPON_BURST:
			return {
				id: FPS_WEAPON_BURST,
				identity: "burst-carbine",
				label: "BURST CARBINE",
				pattern: "BURST x3",
				damage: 20,
				range: 1200,
				fire_delay: 18,
				magazine_size: 15,
				reserve_max: 45,
				initial_reserve: 45,
				pickup_reserve: 18,
				pellets: 3,
				spread_degrees: 2,
				colour: make_color_rgb(184, 126, 255),
			};
		case FPS_WEAPON_RAIL:
			return {
				id: FPS_WEAPON_RAIL,
				identity: "rail-lance",
				label: "RAIL LANCE",
				pattern: "LONG RANGE",
				damage: 86,
				range: 2400,
				fire_delay: 55,
				magazine_size: 3,
				reserve_max: 9,
				initial_reserve: 9,
				pickup_reserve: 3,
				pellets: 1,
				spread_degrees: 0,
				colour: make_color_rgb(255, 86, 132),
			};
	}

	return fps_weapon_definition(FPS_WEAPON_PULSE);
}

/// Creates one mutable inventory entry while keeping definitions immutable by convention.
function fps_weapon_create_state(_weapon_id, _owned) {
	var _definition = fps_weapon_definition(_weapon_id);
	return {
		weapon_id: _weapon_id,
		owned: _owned,
		magazine: _owned ? _definition.magazine_size : 0,
		reserve: _owned ? _definition.initial_reserve : 0,
	};
}

/// Creates a fresh encounter loadout with only the direct-fire role equipped.
function fps_weapon_create_loadout() {
	return {
		states: [
			fps_weapon_create_state(FPS_WEAPON_PULSE, true),
			fps_weapon_create_state(FPS_WEAPON_SCATTER, false),
			fps_weapon_create_state(FPS_WEAPON_BURST, false),
			fps_weapon_create_state(FPS_WEAPON_RAIL, false),
		],
		current_index: FPS_WEAPON_PULSE,
		cooldown_frames: 0,
		overcharge_frames: 0,
	};
}

/// Returns the current weapon definition for HUD, firing, and feedback.
function fps_weapon_current_definition(_loadout) {
	return fps_weapon_definition(_loadout.current_index);
}

/// Returns the mutable state for the currently equipped weapon.
function fps_weapon_current_state(_loadout) {
	return _loadout.states[_loadout.current_index];
}

/// Counts acquired weapons for readable progression feedback.
function fps_weapon_owned_count(_loadout) {
	var _owned_count = 0;
	var _state_count = array_length(_loadout.states);
	for (var _state_index = 0; _state_index < _state_count; _state_index += 1) {
		if (_loadout.states[_state_index].owned) {
			_owned_count += 1;
		}
	}

	return _owned_count;
}

/// Equips only an acquired weapon and reports whether the input changed loadout state.
function fps_weapon_switch(_loadout, _weapon_id) {
	if (
		_weapon_id < 0
		|| _weapon_id >= array_length(_loadout.states)
		|| !_loadout.states[_weapon_id].owned
	) {
		return false;
	}

	_loadout.current_index = _weapon_id;
	_loadout.cooldown_frames = 0;
	return true;
}

/// Cycles through acquired weapons without ever selecting a locked slot.
function fps_weapon_cycle(_loadout, _direction) {
	var _count = array_length(_loadout.states);
	var _start = _loadout.current_index;
	var _step_direction = _direction >= 0 ? 1 : -1;
	for (var _step = 1; _step <= _count; _step += 1) {
		var _candidate = (_start + _step_direction * _step) mod _count;
		if (_candidate < 0) {
			_candidate += _count;
		}
		if (fps_weapon_switch(_loadout, _candidate)) {
			return true;
		}
	}

	return false;
}

/// Advances cooldown and temporary benefit timers once per gameplay frame.
function fps_weapon_tick(_loadout) {
	_loadout.cooldown_frames = max(0, _loadout.cooldown_frames - 1);
	_loadout.overcharge_frames = max(0, _loadout.overcharge_frames - 1);
}

/// Produces a stable horizontal pellet pattern for each weapon's firing contract.
function fps_weapon_shot_pattern(_definition) {
	var _pattern = [];
	var _pellet_count = _definition.pellets;
	var _centre = (_pellet_count - 1) * 0.5;
	for (var _pellet_index = 0; _pellet_index < _pellet_count; _pellet_index += 1) {
		array_push(_pattern, {
			yaw_offset: (_pellet_index - _centre) * _definition.spread_degrees,
			pitch_offset: 0,
		});
	}

	return _pattern;
}

/// Consumes one magazine round and returns a complete machine-readable shot contract.
function fps_weapon_start_shot(_loadout) {
	var _definition = fps_weapon_current_definition(_loadout);
	var _state = fps_weapon_current_state(_loadout);
	if (_loadout.cooldown_frames > 0) {
		return {fired: false, reason: "COOLDOWN", definition: _definition};
	}
	if (_state.magazine <= 0) {
		return {fired: false, reason: "EMPTY", definition: _definition};
	}

	_state.magazine -= 1;
	var _damage = _definition.damage;
	if (_loadout.overcharge_frames > 0) {
		_damage = ceil(_damage * 1.5);
	}

	return {
		fired: true,
		reason: "FIRED",
		definition: _definition,
		damage: _damage,
		cooldown_frames: _definition.fire_delay,
		pattern: fps_weapon_shot_pattern(_definition),
	};
}

/// Refills the equipped magazine from its reserve and reports the exact transfer.
function fps_weapon_reload(_loadout) {
	var _definition = fps_weapon_current_definition(_loadout);
	var _state = fps_weapon_current_state(_loadout);
	var _needed = _definition.magazine_size - _state.magazine;
	if (_needed <= 0) {
		return {reloaded: false, moved: 0, reason: "FULL", definition: _definition};
	}
	if (_state.reserve <= 0) {
		return {reloaded: false, moved: 0, reason: "NO_RESERVE", definition: _definition};
	}

	var _moved = min(_needed, _state.reserve);
	_state.magazine += _moved;
	_state.reserve -= _moved;
	_loadout.cooldown_frames = 0;
	return {reloaded: true, moved: _moved, reason: "RELOADED", definition: _definition};
}

/// Applies a health pickup without consuming it when health is already full.
function fps_weapon_apply_health_pickup(_current_health, _max_health) {
	var _next_health = min(_max_health, _current_health + 35);
	return {
		consumed: _next_health > _current_health,
		health: _next_health,
		message: _next_health > _current_health ? "VITALS RESTORED" : "VITALS FULL — PICKUP RETAINED",
	};
}

/// Returns a stable human-readable pickup class name.
function fps_weapon_pickup_kind_name(_kind) {
	switch (_kind) {
		case FPS_PICKUP_HEALTH: return "MED GEL";
		case FPS_PICKUP_WEAPON: return "WEAPON CACHE";
		case FPS_PICKUP_AMMO: return "AMMO CELL";
		case FPS_PICKUP_OVERCHARGE: return "OVERCHARGE";
	}

	return "SUPPLY";
}

/// Gives every pickup class a distinct native-marker colour.
function fps_weapon_pickup_colour(_kind) {
	switch (_kind) {
		case FPS_PICKUP_HEALTH: return make_color_rgb(64, 232, 145);
		case FPS_PICKUP_WEAPON: return make_color_rgb(255, 116, 220);
		case FPS_PICKUP_AMMO: return make_color_rgb(255, 198, 74);
		case FPS_PICKUP_OVERCHARGE: return make_color_rgb(118, 224, 255);
	}

	return c_white;
}

/// Resolves one nearby pickup, preserving it when it cannot currently help.
function fps_weapon_collect_pickup(_loadout, _pickup, _current_health, _max_health) {
	var _result = {
		consumed: false,
		health: _current_health,
		message: "PICKUP RETAINED",
	};
	if (_pickup.collected) {
		return _result;
	}

	switch (_pickup.kind) {
		case FPS_PICKUP_HEALTH:
			return fps_weapon_apply_health_pickup(_current_health, _max_health);

		case FPS_PICKUP_WEAPON:
			var _weapon_state = _loadout.states[_pickup.weapon_id];
			var _weapon_definition = fps_weapon_definition(_pickup.weapon_id);
			if (!_weapon_state.owned) {
				_weapon_state.owned = true;
				_weapon_state.magazine = _weapon_definition.magazine_size;
				_weapon_state.reserve = _weapon_definition.initial_reserve;
				return {
					consumed: true,
					health: _current_health,
					message: "ACQUIRED " + _weapon_definition.label,
				};
			}

			var _weapon_room = _weapon_definition.reserve_max - _weapon_state.reserve;
			if (_weapon_room > 0) {
				var _weapon_added = min(_weapon_room, _weapon_definition.pickup_reserve);
				_weapon_state.reserve += _weapon_added;
				return {
					consumed: true,
					health: _current_health,
					message: "CACHE REFILLED " + _weapon_definition.label,
				};
			}
			_result.message = "" + _weapon_definition.label + " FULL — PICKUP RETAINED";
			return _result;

		case FPS_PICKUP_AMMO:
			var _state_count = array_length(_loadout.states);
			for (var _pass = 0; _pass < _state_count; _pass += 1) {
				var _state_index = (_loadout.current_index + _pass) mod _state_count;
				var _ammo_state = _loadout.states[_state_index];
				if (!_ammo_state.owned) {
					continue;
				}
				var _ammo_definition = fps_weapon_definition(_state_index);
				var _ammo_room = _ammo_definition.reserve_max - _ammo_state.reserve;
				if (_ammo_room > 0) {
					var _ammo_added = min(_ammo_room, FPS_WEAPON_AMMO_PICKUP);
					_ammo_state.reserve += _ammo_added;
					return {
						consumed: true,
						health: _current_health,
						message: "AMMO +" + string(_ammo_added) + " " + _ammo_definition.label,
					};
				}
			}
			_result.message = "AMMO FULL — PICKUP RETAINED";
			return _result;

		case FPS_PICKUP_OVERCHARGE:
			var _next_overcharge = min(FPS_WEAPON_OVERCHARGE_MAX, _loadout.overcharge_frames + FPS_WEAPON_OVERCHARGE_GAIN);
			if (_next_overcharge > _loadout.overcharge_frames) {
				_loadout.overcharge_frames = _next_overcharge;
				return {
					consumed: true,
					health: _current_health,
					message: "OVERCHARGE ONLINE",
				};
			}
			_result.message = "OVERCHARGE FULL — PICKUP RETAINED";
			return _result;
	}

	return _result;
}

/// Places one deterministic supply cache in every generated tile.
function fps_weapon_create_pickups(_sector, _seed) {
	var _random_state = fps_sector_next_seed(_seed);
	var _rotation_pick = fps_sector_take_random(_random_state, FPS_SECTOR_TILE_COUNT);
	_random_state = _rotation_pick.seed;
	var _weapon_offset_pick = fps_sector_take_random(_random_state, 3);
	var _weapon_offset = _weapon_offset_pick.value;
	var _plans = [
		{kind: FPS_PICKUP_HEALTH, weapon_id: -1},
		{kind: FPS_PICKUP_WEAPON, weapon_id: 1 + ((_weapon_offset + 0) mod 3)},
		{kind: FPS_PICKUP_AMMO, weapon_id: -1},
		{kind: FPS_PICKUP_WEAPON, weapon_id: 1 + ((_weapon_offset + 1) mod 3)},
		{kind: FPS_PICKUP_OVERCHARGE, weapon_id: -1},
		{kind: FPS_PICKUP_WEAPON, weapon_id: 1 + ((_weapon_offset + 2) mod 3)},
	];
	var _pickups = [];
	var _tile_count = min(FPS_SECTOR_TILE_COUNT, array_length(_sector.tiles));
	for (var _tile_index = 0; _tile_index < _tile_count; _tile_index += 1) {
		var _tile = _sector.tiles[_tile_index];
		var _plan_index = (_tile_index + _rotation_pick.value) mod array_length(_plans);
		var _plan = _plans[_plan_index];
		var _candidates = [
			[_tile.left + 96, _tile.center_y + 174],
			[_tile.right - 104, _tile.center_y - 174],
			[_tile.center_x, _tile.center_y],
			[_tile.left + 104, _tile.top + 218],
			[_tile.right - 104, _tile.bottom - 218],
		];
		var _point = fps_sector_first_clear_point(_sector, _candidates, 18);
		array_push(_pickups, {
			id: "pickup-" + string(_tile_index + 1),
			kind: _plan.kind,
			weapon_id: _plan.weapon_id,
			tile_index: _tile_index,
			x: _point.x,
			y: _point.y,
			collected: false,
		});
	}

	return _pickups;
}

/// Produces a compact deterministic signature for replay and reward tests.
function fps_weapon_pickup_signature(_pickups) {
	var _signature = "";
	var _pickup_count = array_length(_pickups);
	for (var _pickup_index = 0; _pickup_index < _pickup_count; _pickup_index += 1) {
		var _pickup = _pickups[_pickup_index];
		_signature += string(_pickup.kind) + ":" + string(_pickup.weapon_id) + ":" + string(round(_pickup.x)) + ":" + string(round(_pickup.y)) + "|";
	}

	return _signature;
}

/// Finds the nearest uncollected cache in interaction range.
function fps_weapon_near_pickup(_pickups, _x, _y, _range) {
	var _nearest = -1;
	var _nearest_distance = _range + 1;
	var _pickup_count = array_length(_pickups);
	for (var _pickup_index = 0; _pickup_index < _pickup_count; _pickup_index += 1) {
		var _pickup = _pickups[_pickup_index];
		if (_pickup.collected) {
			continue;
		}
		var _distance = point_distance(_x, _y, _pickup.x, _pickup.y);
		if (_distance <= _range && _distance < _nearest_distance) {
			_nearest_distance = _distance;
			_nearest = _pickup_index;
		}
	}

	return _nearest;
}

/// Returns a consistent world-marker scale for each pickup class.
function fps_weapon_pickup_scale(_kind) {
	switch (_kind) {
		case FPS_PICKUP_HEALTH: return 20;
		case FPS_PICKUP_WEAPON: return 27;
		case FPS_PICKUP_AMMO: return 22;
		case FPS_PICKUP_OVERCHARGE: return 24;
	}

	return 20;
}
