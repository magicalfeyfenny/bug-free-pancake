weapon_cooldown = max(0, weapon_cooldown - 1);
muzzle_flash_frames = max(0, muzzle_flash_frames - 1);
hit_marker_frames = max(0, hit_marker_frames - 1);
damage_flash_frames = max(0, damage_flash_frames - 1);
recoil = max(0, recoil - 0.18);

if (phase != FPS_STATE_PLAYING) {
	if (keyboard_check_pressed(ord("R"))) {
		room_restart();
	}
	if (keyboard_check_pressed(ord("N"))) {
		global.fps_next_sector_seed = fps_sector_next_seed(sector_seed);
		room_restart();
	}
	exit;
}

if (lore_open) {
	if (keyboard_check_pressed(ord("E"))) {
		lore_open = false;
		lore_index = -1;
		set_mouse_capture(true);
	} else if (keyboard_check_pressed(vk_escape)) {
		lore_open = false;
		lore_index = -1;
		set_mouse_capture(false);
	}
	exit;
}

if (keyboard_check_pressed(ord("E"))) {
	var _near_lore = fps_sector_near_lore(sector, x, y, 72);
	if (_near_lore >= 0) {
		lore_index = _near_lore;
		lore_read[lore_index] = true;
		lore_open = true;
		set_mouse_capture(false);
		exit;
	}
}

if (keyboard_check_pressed(ord("N"))) {
	global.fps_next_sector_seed = fps_sector_next_seed(sector_seed);
	room_restart();
	exit;
}

if (keyboard_check_pressed(vk_escape)) {
	set_mouse_capture(!mouse_captured);
}

if (!window_has_focus()) {
	exit;
}

if (!mouse_captured) {
	if (mouse_check_button_pressed(mb_left)) {
		set_mouse_capture(true);
	}
	exit;
}

// Desktop focus changes can release the lock even while play remains captured.
if (!window_mouse_get_locked()) {
	window_mouse_set_locked(true);
}

var _mouse_delta_x = clamp(window_mouse_get_delta_x(), -80, 80);
var _mouse_delta_y = clamp(window_mouse_get_delta_y(), -80, 80);
yaw = (yaw + _mouse_delta_x * mouse_sensitivity + 360) mod 360;
pitch = clamp(pitch - _mouse_delta_y * mouse_sensitivity, -72, 72);

var _forward_input = keyboard_check(ord("W")) - keyboard_check(ord("S"));
var _strafe_input = keyboard_check(ord("D")) - keyboard_check(ord("A"));
var _movement = fps_movement_vector(yaw, _forward_input, _strafe_input, move_speed);
var _position = fps_sector_move_position(
	sector,
	x,
	y,
	_movement[0],
	_movement[1],
	collision_radius
);
x = _position[0];
y = _position[1];

if (mouse_check_button_pressed(mb_left) && weapon_cooldown <= 0) {
	weapon_cooldown = weapon_delay;
	muzzle_flash_frames = 4;
	recoil = 1;

	var _horizontal_length = dcos(pitch);
	var _direction_x = lengthdir_x(_horizontal_length, yaw);
	var _direction_y = lengthdir_y(_horizontal_length, yaw);
	var _direction_z = dsin(pitch);
	var _nearest_enemy = noone;
	var _nearest_hit_distance = weapon_range + 1;
	var _enemy_count = instance_number(obj_fps_enemy);
	for (var _enemy_index = 0; _enemy_index < _enemy_count; _enemy_index += 1) {
		var _enemy = instance_find(obj_fps_enemy, _enemy_index);
		if (
			!instance_exists(_enemy)
			|| !variable_instance_exists(_enemy, "initialized")
			|| !_enemy.initialized
			|| !_enemy.alive
		) {
			continue;
		}
		if (fps_sector_line_blocked(sector, x, y, _enemy.x, _enemy.y)) {
			continue;
		}

		var _hit_distance = fps_ray_sphere_distance(
			x,
			y,
			eye_height,
			_direction_x,
			_direction_y,
			_direction_z,
			_enemy.x,
			_enemy.y,
			_enemy.hit_sphere_height,
			_enemy.hit_sphere_radius,
			weapon_range
		);

		if (_hit_distance >= 0 && _hit_distance < _nearest_hit_distance) {
			_nearest_enemy = _enemy;
			_nearest_hit_distance = _hit_distance;
		}
	}

	if (instance_exists(_nearest_enemy)) {
		_nearest_enemy.take_damage(weapon_damage);
		hit_marker_frames = 6;
	}
}
