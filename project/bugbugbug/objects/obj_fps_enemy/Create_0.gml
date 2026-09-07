fps_enemy_apply_role(id, FPS_ENEMY_KIND_CHASER);
hit_flash_frames = 0;

var _player = instance_find(obj_fps_controller, 0);
if (instance_exists(_player) && variable_instance_exists(_player, "sector")) {
	var _socket = fps_sector_combat_socket(_player.sector, 0);
	if (is_struct(_socket)) {
		x = _socket.x;
		y = _socket.y;
	}
}

/// Applies a weapon hit once and announces victory when health reaches zero.
take_damage = method(id, function(_amount) {
	if (alive) {
		current_health = fps_apply_damage(current_health, _amount);
		hit_flash_frames = 5;

		if (current_health <= 0) {
			alive = false;
			var _player = instance_find(obj_fps_controller, 0);
			if (instance_exists(_player)) {
				_player.refresh_terminal_phase();
			}
		}
	}
});

// The renderer may query placed instances while the room is still being built.
initialized = true;
