#macro FPS_STATE_PLAYING 0
#macro FPS_STATE_DEAD 1
#macro FPS_STATE_VICTORY 2

#macro FPS_PLAYER_MAX_HEALTH 100
#macro FPS_ENEMY_MAX_HEALTH 100

/// Returns a fresh encounter state for startup and restart tests.
function fps_create_encounter_state() {
	return {
		player_health: FPS_PLAYER_MAX_HEALTH,
		enemy_health: FPS_ENEMY_MAX_HEALTH,
		phase: FPS_STATE_PLAYING,
	};
}

/// Applies non-negative damage without allowing health below zero.
function fps_apply_damage(_health, _damage) {
	return max(0, _health - max(0, _damage));
}

/// Gives player death priority if both sides reach zero together.
function fps_get_terminal_state(_player_health, _enemy_health) {
	if (_player_health <= 0) {
		return FPS_STATE_DEAD;
	}

	if (_enemy_health <= 0) {
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
