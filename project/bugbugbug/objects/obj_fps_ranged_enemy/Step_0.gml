hit_flash_frames = max(0, hit_flash_frames - 1);

if (!alive) {
	exit;
}

var _player = instance_find(obj_fps_controller, 0);
if (
	!instance_exists(_player)
	|| _player.phase != FPS_STATE_PLAYING
	|| !_player.mouse_captured
	|| !window_has_focus()
) {
	exit;
}

mode_frames = max(0, mode_frames - 1);
// Movement and firing get separate windows so the enemy visibly alternates tactics.
if (mode_frames <= 0) {
	mode = fps_next_ranged_mode(mode);
	if (mode == FPS_RANGED_MODE_EVADE) {
		mode_frames = evade_duration;
		strafe_direction *= -1;
	} else {
		mode_frames = attack_duration;
		attack_cooldown = 0;
	}
}

if (mode == FPS_RANGED_MODE_EVADE) {
	var _movement = fps_evasive_movement_vector(
		x,
		y,
		_player.x,
		_player.y,
		strafe_direction,
		move_speed
	);
	var _position = fps_clamp_position(
		x + _movement[0],
		y + _movement[1],
		collision_radius,
		room_width,
		room_height,
		_player.wall_thickness
	);
	if (_position[0] != x + _movement[0] || _position[1] != y + _movement[1]) {
		strafe_direction *= -1;
	}
	x = _position[0];
	y = _position[1];
	exit;
}

attack_cooldown = max(0, attack_cooldown - 1);
var _distance = point_distance(x, y, _player.x, _player.y);
if (attack_cooldown <= 0 && _distance > 0) {
	var _projectile = instance_create_layer(x, y, "Gameplay", obj_fps_enemy_projectile);
	_projectile.direction_x = (_player.x - x) / _distance;
	_projectile.direction_y = (_player.y - y) / _distance;
	_projectile.direction_angle = point_direction(x, y, _player.x, _player.y);
	_projectile.move_speed = projectile_speed;
	_projectile.damage = attack_damage;
	_projectile.life_frames = projectile_lifetime;
	attack_cooldown = attack_delay;
}
