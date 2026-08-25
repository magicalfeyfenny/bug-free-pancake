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

attack_cooldown = max(0, attack_cooldown - 1);

var _delta_x = _player.x - x;
var _delta_y = _player.y - y;
var _distance = point_distance(x, y, _player.x, _player.y);

if (_distance > stop_distance && _distance > 0) {
	var _step = min(move_speed, _distance - stop_distance);
	var _position = fps_clamp_position(
		x + _delta_x / _distance * _step,
		y + _delta_y / _distance * _step,
		collision_radius,
		room_width,
		room_height,
		_player.wall_thickness
	);
	x = _position[0];
	y = _position[1];
} else if (_distance <= attack_range && attack_cooldown <= 0) {
	_player.take_damage(attack_damage);
	attack_cooldown = attack_delay;
}
