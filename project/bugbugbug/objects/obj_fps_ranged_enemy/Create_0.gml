// Reuse the shared health and damage contract while this child supplies its own AI.
event_inherited();
fps_enemy_apply_role(id, FPS_ENEMY_KIND_RANGED);

var _player = instance_find(obj_fps_controller, 0);
if (instance_exists(_player) && variable_instance_exists(_player, "sector")) {
	var _socket = fps_sector_combat_socket(_player.sector, 1);
	if (is_struct(_socket)) {
		x = _socket.x;
		y = _socket.y;
	}
}
