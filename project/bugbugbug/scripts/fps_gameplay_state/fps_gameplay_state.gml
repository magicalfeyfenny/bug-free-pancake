#macro FPS_STATE_PLAYING 0
#macro FPS_STATE_DEAD 1
#macro FPS_STATE_VICTORY 2

#macro FPS_PLAYER_MAX_HEALTH 100
#macro FPS_ENEMY_MAX_HEALTH 100
#macro FPS_RANGED_ENEMY_MAX_HEALTH 75

#macro FPS_ENEMY_KIND_CHASER 0
#macro FPS_ENEMY_KIND_RANGED 1
#macro FPS_ENEMY_KIND_BURROWER 2
#macro FPS_ENEMY_KIND_SENTRY 3
#macro FPS_ENEMY_KIND_TITAN 4
#macro FPS_ENEMY_KIND_COUNT 5

#macro FPS_ENEMY_WARNING_AREA 0
#macro FPS_ENEMY_WARNING_BEAM 1

#macro FPS_RANGED_MODE_EVADE 0
#macro FPS_RANGED_MODE_ATTACK 1

/// Returns a fresh encounter state for startup and restart tests.
function fps_create_encounter_state() {
	return {
		player_health: FPS_PLAYER_MAX_HEALTH,
		enemy_health: FPS_ENEMY_MAX_HEALTH,
		ranged_enemy_health: FPS_RANGED_ENEMY_MAX_HEALTH,
		phase: FPS_STATE_PLAYING,
	};
}

/// Applies non-negative damage without allowing health below zero.
function fps_apply_damage(_health, _damage) {
	return max(0, _health - max(0, _damage));
}

/// Gives player death priority, then grants victory when no enemies remain alive.
function fps_get_terminal_state(_player_health, _living_enemy_count) {
	if (_player_health <= 0) {
		return FPS_STATE_DEAD;
	}

	if (_living_enemy_count <= 0) {
		return FPS_STATE_VICTORY;
	}

	return FPS_STATE_PLAYING;
}

/// Keeps a circular actor inside the solid inner faces of the arena walls.
function fps_clamp_position(_x, _y, _radius, _arena_width, _arena_height, _wall_thickness) {
	var _minimum = _wall_thickness + _radius;
	var _maximum_x = _arena_width - _minimum;
	var _maximum_y = _arena_height - _minimum;

	return [
		clamp(_x, _minimum, _maximum_x),
		clamp(_y, _minimum, _maximum_y),
	];
}

/// Returns the nearest ray hit distance, or -1 when the sphere is not hit in range.
function fps_ray_sphere_distance(
	_origin_x,
	_origin_y,
	_origin_z,
	_direction_x,
	_direction_y,
	_direction_z,
	_sphere_x,
	_sphere_y,
	_sphere_z,
	_sphere_radius,
	_max_distance
) {
	var _offset_x = _origin_x - _sphere_x;
	var _offset_y = _origin_y - _sphere_y;
	var _offset_z = _origin_z - _sphere_z;
	var _direction_length_squared =
		_direction_x * _direction_x
		+ _direction_y * _direction_y
		+ _direction_z * _direction_z;

	if (_direction_length_squared <= 0) {
		return -1;
	}

	var _half_b =
		_offset_x * _direction_x
		+ _offset_y * _direction_y
		+ _offset_z * _direction_z;
	var _c =
		_offset_x * _offset_x
		+ _offset_y * _offset_y
		+ _offset_z * _offset_z
		- _sphere_radius * _sphere_radius;
	var _discriminant = _half_b * _half_b - _direction_length_squared * _c;

	if (_discriminant < 0) {
		return -1;
	}

	var _root = (-_half_b - sqrt(_discriminant)) / _direction_length_squared;
	if (_root < 0) {
		_root = (-_half_b + sqrt(_discriminant)) / _direction_length_squared;
	}

	if (_root < 0 || _root > _max_distance) {
		return -1;
	}

	return _root;
}

/// Converts local movement input into a speed-limited arena-space vector.
function fps_movement_vector(_yaw, _forward_input, _strafe_input, _speed) {
	var _input_length = point_distance(0, 0, _forward_input, _strafe_input);
	if (_input_length <= 0) {
		return [0, 0];
	}

	var _forward = _forward_input / _input_length;
	var _strafe = _strafe_input / _input_length;
	var _move_x =
		lengthdir_x(_forward * _speed, _yaw)
		+ lengthdir_x(_strafe * _speed, _yaw + 90);
	var _move_y =
		lengthdir_y(_forward * _speed, _yaw)
		+ lengthdir_y(_strafe * _speed, _yaw + 90);

	return [_move_x, _move_y];
}

/// Returns a speed-limited sideways vector around the target for evasive movement.
function fps_evasive_movement_vector(
	_actor_x,
	_actor_y,
	_target_x,
	_target_y,
	_strafe_direction,
	_speed
) {
	var _delta_x = _target_x - _actor_x;
	var _delta_y = _target_y - _actor_y;
	var _distance = point_distance(_actor_x, _actor_y, _target_x, _target_y);
	if (_distance <= 0) {
		return [0, 0];
	}

	var _side = _strafe_direction >= 0 ? 1 : -1;
	return [
		-_delta_y / _distance * _speed * _side,
		_delta_x / _distance * _speed * _side,
	];
}

/// Alternates the ranged enemy between its two behavior modes.
function fps_next_ranged_mode(_mode) {
	return _mode == FPS_RANGED_MODE_EVADE
		? FPS_RANGED_MODE_ATTACK
		: FPS_RANGED_MODE_EVADE;
}

/// Reports whether two circular actors touch in the arena plane.
function fps_circles_overlap(_first_x, _first_y, _first_radius, _second_x, _second_y, _second_radius) {
	return point_distance(_first_x, _first_y, _second_x, _second_y)
		<= _first_radius + _second_radius;
}

/// Returns the stable combat contract for one roster role.
function fps_enemy_role_definition(_kind) {
	switch (_kind) {
		case FPS_ENEMY_KIND_CHASER:
			return {
				identity: "chaser",
				label: "CHASER",
				max_health: FPS_ENEMY_MAX_HEALTH,
				move_speed: 1.8,
				stop_distance: 92,
				attack_range: 118,
				attack_damage: 15,
				attack_delay: 45,
				collision_radius: 24,
				hit_sphere_height: 58,
				hit_sphere_radius: 44,
				health_colour: make_color_rgb(225, 51, 89),
				colour: make_color_rgb(225, 51, 89),
				warning_colour: make_color_rgb(255, 126, 76),
				warning_radius: 0,
				warning_shape: FPS_ENEMY_WARNING_AREA,
				telegraph_frames: 0,
				projectile_speed: 0,
				projectile_lifetime: 0,
			};
		case FPS_ENEMY_KIND_RANGED:
			return {
				identity: "skirmisher",
				label: "SKIRMISHER",
				max_health: FPS_RANGED_ENEMY_MAX_HEALTH,
				move_speed: 3,
				stop_distance: 420,
				attack_range: 1400,
				attack_damage: 10,
				attack_delay: 30,
				collision_radius: 48,
				hit_sphere_height: 60,
				hit_sphere_radius: 52,
				health_colour: make_color_rgb(122, 104, 238),
				colour: make_color_rgb(122, 104, 238),
				warning_colour: make_color_rgb(129, 196, 255),
				warning_radius: 0,
				warning_shape: FPS_ENEMY_WARNING_BEAM,
				telegraph_frames: 0,
				projectile_speed: 8,
				projectile_lifetime: 180,
			};
		case FPS_ENEMY_KIND_BURROWER:
			return {
				identity: "burrower",
				label: "BURROWER",
				max_health: 135,
				move_speed: 4.8,
				stop_distance: 86,
				attack_range: 154,
				attack_damage: 24,
				attack_delay: 78,
				collision_radius: 32,
				hit_sphere_height: 42,
				hit_sphere_radius: 50,
				health_colour: make_color_rgb(255, 151, 67),
				colour: make_color_rgb(255, 151, 67),
				warning_colour: make_color_rgb(255, 203, 74),
				warning_radius: 112,
				warning_shape: FPS_ENEMY_WARNING_AREA,
				telegraph_frames: 28,
				projectile_speed: 0,
				projectile_lifetime: 0,
			};
		case FPS_ENEMY_KIND_SENTRY:
			return {
				identity: "sentry",
				label: "SENTRY",
				max_health: 110,
				move_speed: 1.7,
				stop_distance: 520,
				attack_range: 1500,
				attack_damage: 18,
				attack_delay: 84,
				collision_radius: 30,
				hit_sphere_height: 88,
				hit_sphere_radius: 38,
				health_colour: make_color_rgb(76, 195, 226),
				colour: make_color_rgb(76, 195, 226),
				warning_colour: make_color_rgb(255, 104, 91),
				warning_radius: 22,
				warning_shape: FPS_ENEMY_WARNING_BEAM,
				telegraph_frames: 42,
				projectile_speed: 7,
				projectile_lifetime: 220,
			};
		case FPS_ENEMY_KIND_TITAN:
			return {
				identity: "titan",
				label: "TITAN",
				max_health: 360,
				move_speed: 1.15,
				stop_distance: 190,
				attack_range: 280,
				attack_damage: 32,
				attack_delay: 110,
				collision_radius: 54,
				hit_sphere_height: 96,
				hit_sphere_radius: 66,
				health_colour: make_color_rgb(190, 75, 226),
				colour: make_color_rgb(190, 75, 226),
				warning_colour: make_color_rgb(255, 77, 163),
				warning_radius: 188,
				warning_shape: FPS_ENEMY_WARNING_AREA,
				telegraph_frames: 52,
				projectile_speed: 0,
				projectile_lifetime: 0,
			};
	}

	return fps_enemy_role_definition(FPS_ENEMY_KIND_CHASER);
}

/// Returns the stable identity used by encounter signatures and diagnostics.
function fps_enemy_role_name(_kind) {
	return fps_enemy_role_definition(_kind).identity;
}

/// Applies one role contract to a newly created enemy instance.
function fps_enemy_apply_role(_enemy, _kind) {
	var _definition = fps_enemy_role_definition(_kind);
	_enemy.enemy_kind = _kind;
	_enemy.enemy_identity = _definition.identity;
	_enemy.enemy_label = _definition.label;
	_enemy.alive = true;
	_enemy.max_health = _definition.max_health;
	_enemy.current_health = _definition.max_health;
	_enemy.move_speed = _definition.move_speed;
	_enemy.stop_distance = _definition.stop_distance;
	_enemy.attack_range = _definition.attack_range;
	_enemy.attack_damage = _definition.attack_damage;
	_enemy.attack_delay = _definition.attack_delay;
	_enemy.attack_cooldown = _definition.attack_delay;
	_enemy.collision_radius = _definition.collision_radius;
	_enemy.hit_sphere_height = _definition.hit_sphere_height;
	_enemy.hit_sphere_radius = _definition.hit_sphere_radius;
	_enemy.health_colour = _definition.health_colour;
	_enemy.warning_colour = _definition.warning_colour;
	_enemy.warning_radius = _definition.warning_radius;
	_enemy.warning_shape = _definition.warning_shape;
	_enemy.telegraph_frames = 0;
	_enemy.telegraph_max_frames = _definition.telegraph_frames;
	_enemy.projectile_speed = _definition.projectile_speed;
	_enemy.projectile_lifetime = _definition.projectile_lifetime;
	_enemy.mode = FPS_RANGED_MODE_EVADE;
	_enemy.mode_frames = 90;
	_enemy.strafe_direction = 1;
	_enemy.initialized = true;
}

/// Derives a repeatable pressure tier from a supplied encounter seed.
function fps_enemy_encounter_pressure(_seed) {
	return 1 + (fps_sector_next_seed(_seed) mod 3);
}

/// Creates the deterministic role/socket plan consumed by the room controller.
function fps_enemy_create_encounter_plan(_sector, _seed, _pressure) {
	var _safe_pressure = clamp(floor(_pressure), 0, 3);
	var _socket_count = array_length(_sector.combat_sockets);
	var _entry_count = min(_socket_count, 2 + min(2, _safe_pressure));
	var _random_state = fps_sector_next_seed(_seed + 31 * _safe_pressure + 17);
	var _entries = [];
	var _previous_kind = -1;

	for (var _entry_index = 0; _entry_index < _entry_count; _entry_index += 1) {
		var _role_pick = fps_sector_take_random(_random_state, FPS_ENEMY_KIND_COUNT);
		_random_state = _role_pick.seed;
		var _kind = _role_pick.value;
		if (_entry_index == _entry_count - 1 && _safe_pressure >= 2) {
			_kind = FPS_ENEMY_KIND_TITAN;
		}
		if (_kind == _previous_kind) {
			_kind = (_kind + 1 + (_random_state mod (FPS_ENEMY_KIND_COUNT - 1))) mod FPS_ENEMY_KIND_COUNT;
		}

		var _socket = _sector.combat_sockets[_entry_index];
		array_push(_entries, {
			identity: fps_enemy_role_name(_kind),
			kind: _kind,
			socket_id: _socket.id,
			socket_index: _entry_index,
			tile_index: _socket.tile_index,
			x: _socket.x,
			y: _socket.y,
		});
		_previous_kind = _kind;
	}

	return {
		seed: _seed,
		pressure: _safe_pressure,
		entries: _entries,
		signature: fps_enemy_encounter_signature(_entries),
	};
}

/// Serializes an encounter plan without depending on instance creation order.
function fps_enemy_encounter_signature(_entries) {
	var _signature = "";
	for (var _entry_index = 0; _entry_index < array_length(_entries); _entry_index += 1) {
		var _entry = _entries[_entry_index];
		_signature += _entry.identity + "@" + _entry.socket_id + "|";
	}

	return _signature;
}

/// Moves one actor toward a target while preserving the canonical sector solids.
function fps_enemy_move_toward(_enemy, _player, _stop_distance) {
	var _delta_x = _player.x - _enemy.x;
	var _delta_y = _player.y - _enemy.y;
	var _distance = point_distance(_enemy.x, _enemy.y, _player.x, _player.y);
	if (_distance > _stop_distance && _distance > 0) {
		var _step = min(_enemy.move_speed, _distance - _stop_distance);
		var _position = fps_sector_move_position(
			_player.sector,
			_enemy.x,
			_enemy.y,
			_delta_x / _distance * _step,
			_delta_y / _distance * _step,
			_enemy.collision_radius
		);
		_enemy.x = _position[0];
		_enemy.y = _position[1];
	}

	return _distance;
}

/// Moves one actor away from a target while preserving the canonical sector solids.
function fps_enemy_move_away(_enemy, _player) {
	var _delta_x = _enemy.x - _player.x;
	var _delta_y = _enemy.y - _player.y;
	var _distance = point_distance(_enemy.x, _enemy.y, _player.x, _player.y);
	if (_distance <= 0) {
		return _distance;
	}

	var _position = fps_sector_move_position(
		_player.sector,
		_enemy.x,
		_enemy.y,
		_delta_x / _distance * _enemy.move_speed,
		_delta_y / _distance * _enemy.move_speed,
		_enemy.collision_radius
	);
	_enemy.x = _position[0];
	_enemy.y = _position[1];
	return _distance;
}

/// Starts a visible attack telegraph whose resolution can still be blocked by cover.
function fps_enemy_begin_telegraph(_enemy, _frames, _radius, _shape) {
	_enemy.telegraph_frames = _frames;
	_enemy.telegraph_max_frames = _frames;
	_enemy.warning_radius = _radius;
	_enemy.warning_shape = _shape;
}

/// Spawns the shared projectile representation from a role's resolved attack.
function fps_enemy_spawn_projectile(_enemy, _player) {
	var _distance = point_distance(_enemy.x, _enemy.y, _player.x, _player.y);
	if (_distance <= 0 || fps_sector_line_blocked(_player.sector, _enemy.x, _enemy.y, _player.x, _player.y)) {
		return false;
	}

	var _projectile = instance_create_layer(_enemy.x, _enemy.y, "Gameplay", obj_fps_enemy_projectile);
	_projectile.direction_x = (_player.x - _enemy.x) / _distance;
	_projectile.direction_y = (_player.y - _enemy.y) / _distance;
	_projectile.direction_angle = point_direction(_enemy.x, _enemy.y, _player.x, _player.y);
	_projectile.move_speed = _enemy.projectile_speed;
	_projectile.damage = _enemy.attack_damage;
	_projectile.life_frames = _enemy.projectile_lifetime;
	return true;
}

/// Resolves a telegraphed melee, beam, or projectile attack at its warning endpoint.
function fps_enemy_resolve_telegraph(_enemy, _player) {
	var _distance = point_distance(_enemy.x, _enemy.y, _player.x, _player.y);
	var _has_cover = fps_sector_line_blocked(_player.sector, _enemy.x, _enemy.y, _player.x, _player.y);
	if (_has_cover) {
		return;
	}

	switch (_enemy.enemy_kind) {
		case FPS_ENEMY_KIND_BURROWER:
		case FPS_ENEMY_KIND_TITAN:
			if (_distance <= _enemy.warning_radius) {
				_player.take_damage(_enemy.attack_damage);
			}
			break;
		case FPS_ENEMY_KIND_SENTRY:
			fps_enemy_spawn_projectile(_enemy, _player);
			break;
	}

	_enemy.attack_cooldown = _enemy.attack_delay;
}

/// Runs the original direct-fire chase contract.
function fps_enemy_step_chaser(_enemy, _player) {
	var _distance = fps_enemy_move_toward(_enemy, _player, _enemy.stop_distance);
	if (
		_distance <= _enemy.attack_range
		&& _enemy.attack_cooldown <= 0
		&& !fps_sector_line_blocked(_player.sector, _enemy.x, _enemy.y, _player.x, _player.y)
	) {
		_player.take_damage(_enemy.attack_damage);
		_enemy.attack_cooldown = _enemy.attack_delay;
	}
}

/// Runs the skirmisher's evade/attack alternation for dynamically spawned roles.
function fps_enemy_step_ranged(_enemy, _player) {
	_enemy.mode_frames = max(0, _enemy.mode_frames - 1);
	if (_enemy.mode_frames <= 0) {
		_enemy.mode = fps_next_ranged_mode(_enemy.mode);
		if (_enemy.mode == FPS_RANGED_MODE_EVADE) {
			_enemy.mode_frames = 90;
			_enemy.strafe_direction *= -1;
		} else {
			_enemy.mode_frames = 70;
			_enemy.attack_cooldown = 0;
		}
	}

	if (_enemy.mode == FPS_RANGED_MODE_EVADE) {
		var _movement = fps_evasive_movement_vector(
			_enemy.x,
			_enemy.y,
			_player.x,
			_player.y,
			_enemy.strafe_direction,
			_enemy.move_speed
		);
		var _position = fps_sector_move_position(
			_player.sector,
			_enemy.x,
			_enemy.y,
			_movement[0],
			_movement[1],
			_enemy.collision_radius
		);
		if (_position[0] != _enemy.x + _movement[0] || _position[1] != _enemy.y + _movement[1]) {
			_enemy.strafe_direction *= -1;
		}
		_enemy.x = _position[0];
		_enemy.y = _position[1];
		return;
	}

	var _distance = point_distance(_enemy.x, _enemy.y, _player.x, _player.y);
	if (
		_enemy.attack_cooldown <= 0
		&& _distance > 0
		&& !fps_sector_line_blocked(_player.sector, _enemy.x, _enemy.y, _player.x, _player.y)
	) {
		fps_enemy_spawn_projectile(_enemy, _player);
		_enemy.attack_cooldown = _enemy.attack_delay;
	}
}

/// Runs the fast telegraphed charge role.
function fps_enemy_step_burrower(_enemy, _player) {
	var _distance = fps_enemy_move_toward(_enemy, _player, _enemy.stop_distance);
	if (
		_distance <= _enemy.attack_range
		&& _enemy.attack_cooldown <= 0
		&& !fps_sector_line_blocked(_player.sector, _enemy.x, _enemy.y, _player.x, _player.y)
	) {
		fps_enemy_begin_telegraph(_enemy, 28, 112, FPS_ENEMY_WARNING_AREA);
	}
}

/// Runs the long-range warning-shot role with a cover-compatible response.
function fps_enemy_step_sentry(_enemy, _player) {
	var _distance = point_distance(_enemy.x, _enemy.y, _player.x, _player.y);
	if (_distance < 420) {
		fps_enemy_move_away(_enemy, _player);
	} else if (_distance > _enemy.stop_distance) {
		fps_enemy_move_toward(_enemy, _player, _enemy.stop_distance);
	} else {
		var _movement = fps_evasive_movement_vector(
			_enemy.x,
			_enemy.y,
			_player.x,
			_player.y,
			_enemy.strafe_direction,
			_enemy.move_speed
		);
		var _position = fps_sector_move_position(
			_player.sector,
			_enemy.x,
			_enemy.y,
			_movement[0],
			_movement[1],
			_enemy.collision_radius
		);
		_enemy.x = _position[0];
		_enemy.y = _position[1];
	}

	if (
		_distance <= _enemy.attack_range
		&& _enemy.attack_cooldown <= 0
		&& !fps_sector_line_blocked(_player.sector, _enemy.x, _enemy.y, _player.x, _player.y)
	) {
		fps_enemy_begin_telegraph(_enemy, 42, 22, FPS_ENEMY_WARNING_BEAM);
	}
}

/// Runs the slow durable elite's cover-blockable area attack.
function fps_enemy_step_titan(_enemy, _player) {
	var _distance = fps_enemy_move_toward(_enemy, _player, _enemy.stop_distance);
	if (
		_distance <= _enemy.attack_range
		&& _enemy.attack_cooldown <= 0
		&& !fps_sector_line_blocked(_player.sector, _enemy.x, _enemy.y, _player.x, _player.y)
	) {
		fps_enemy_begin_telegraph(_enemy, 52, 188, FPS_ENEMY_WARNING_AREA);
	}
}

/// Dispatches one frame of role-specific behavior after shared lifecycle work.
function fps_enemy_step_role(_enemy, _player) {
	switch (_enemy.enemy_kind) {
		case FPS_ENEMY_KIND_CHASER: fps_enemy_step_chaser(_enemy, _player); break;
		case FPS_ENEMY_KIND_RANGED: fps_enemy_step_ranged(_enemy, _player); break;
		case FPS_ENEMY_KIND_BURROWER: fps_enemy_step_burrower(_enemy, _player); break;
		case FPS_ENEMY_KIND_SENTRY: fps_enemy_step_sentry(_enemy, _player); break;
		case FPS_ENEMY_KIND_TITAN: fps_enemy_step_titan(_enemy, _player); break;
	}
}
