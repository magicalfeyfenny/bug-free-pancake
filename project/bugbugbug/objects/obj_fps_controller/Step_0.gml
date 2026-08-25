weapon_cooldown = max(0, weapon_cooldown - 1);
muzzle_flash_frames = max(0, muzzle_flash_frames - 1);
hit_marker_frames = max(0, hit_marker_frames - 1);
damage_flash_frames = max(0, damage_flash_frames - 1);
recoil = max(0, recoil - 0.18);

if (phase != FPS_STATE_PLAYING) {
	if (keyboard_check_pressed(ord("R"))) {
		room_restart();
	}
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
var _position = fps_clamp_position(
	x + _movement[0],
	y + _movement[1],
	collision_radius,
	room_width,
	room_height,
	wall_thickness
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
	var _enemy = instance_find(obj_fps_enemy, 0);

	if (
		instance_exists(_enemy)
		&& variable_instance_exists(_enemy, "initialized")
		&& _enemy.initialized
		&& _enemy.alive
	) {
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

		if (_hit_distance >= 0) {
			_enemy.take_damage(weapon_damage);
			hit_marker_frames = 6;
		}
	}
}
