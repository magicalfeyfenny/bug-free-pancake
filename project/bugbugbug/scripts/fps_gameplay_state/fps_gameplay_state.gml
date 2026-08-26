#macro FPS_STATE_PLAYING 0
#macro FPS_STATE_DEAD 1
#macro FPS_STATE_VICTORY 2

#macro FPS_PLAYER_MAX_HEALTH 100
#macro FPS_ENEMY_MAX_HEALTH 100
#macro FPS_RANGED_ENEMY_MAX_HEALTH 75

#macro FPS_ENEMY_KIND_CHASER 0
#macro FPS_ENEMY_KIND_RANGED 1

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
