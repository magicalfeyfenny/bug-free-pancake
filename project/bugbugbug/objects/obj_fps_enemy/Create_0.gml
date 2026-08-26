max_health = FPS_ENEMY_MAX_HEALTH;
current_health = max_health;
alive = true;
enemy_kind = FPS_ENEMY_KIND_CHASER;

move_speed = 1.8;
collision_radius = 24;
stop_distance = 92;
attack_range = 118;
attack_damage = 15;
attack_delay = 45;
attack_cooldown = attack_delay;

body_width = 46;
body_depth = 38;
body_height = 70;
head_size = 38;
head_height = head_size;
body_z = 0;
shoulder_width = 0;
shoulder_depth = 0;
shoulder_height = 0;
shoulder_z = 0;
hit_sphere_height = 58;
hit_sphere_radius = 44;
hit_flash_frames = 0;

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
