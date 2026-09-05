var _player = instance_find(obj_fps_controller, 0);
if (!instance_exists(_player) || _player.phase != FPS_STATE_PLAYING) {
	instance_destroy();
	exit;
}

// Projectiles pause with the enemies while desktop input is released.
if (!_player.mouse_captured || !window_has_focus()) {
	exit;
}

life_frames -= 1;
var _previous_x = x;
var _previous_y = y;
x += direction_x * move_speed;
y += direction_y * move_speed;

if (fps_sector_line_blocked(_player.sector, _previous_x, _previous_y, x, y)) {
	instance_destroy();
	exit;
}

if (fps_circles_overlap(x, y, collision_radius, _player.x, _player.y, _player.collision_radius)) {
	_player.take_damage(damage);
	instance_destroy();
	exit;
}

var _minimum = _player.wall_thickness + collision_radius;
if (
	life_frames <= 0
	|| x < _minimum
	|| y < _minimum
	|| x > room_width - _minimum
	|| y > room_height - _minimum
) {
	instance_destroy();
}
