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
	var _position = fps_sector_move_position(
		_player.sector,
		x,
		y,
		_delta_x / _distance * _step,
		_delta_y / _distance * _step,
		collision_radius
	);
	x = _position[0];
	y = _position[1];
} else if (
		_distance <= attack_range
		&& attack_cooldown <= 0
		&& !fps_sector_line_blocked(_player.sector, x, y, _player.x, _player.y)
	) {
	_player.take_damage(attack_damage);
	attack_cooldown = attack_delay;
}
