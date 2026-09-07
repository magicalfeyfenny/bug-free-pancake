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

if (telegraph_frames > 0) {
	telegraph_frames -= 1;
	if (telegraph_frames <= 0) {
		fps_enemy_resolve_telegraph(id, _player);
	}
	exit;
}

fps_enemy_step_role(id, _player);
