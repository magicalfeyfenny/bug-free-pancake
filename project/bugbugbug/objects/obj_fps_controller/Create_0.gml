var _initial_state = fps_create_encounter_state();

max_health = FPS_PLAYER_MAX_HEALTH;
current_health = _initial_state.player_health;
phase = _initial_state.phase;

move_speed = 4;
collision_radius = 22;
eye_height = 68;
yaw = 0;
pitch = 0;
mouse_sensitivity = 0.16;
mouse_captured = true;

wall_height = 200;
wall_thickness = 24;

if (!variable_global_exists("fps_next_sector_seed")) {
	global.fps_next_sector_seed = FPS_SECTOR_DEFAULT_SEED;
}
sector_seed = global.fps_next_sector_seed;
sector = fps_sector_generate(
	sector_seed,
	room_width,
	room_height,
	wall_thickness,
	wall_height
);
global.fps_sector = sector;
x = sector.start_socket.x;
y = sector.start_socket.y;
lore_entries = fps_create_lore_entries();
lore_read = array_create(FPS_SECTOR_TILE_COUNT, false);
lore_open = false;
lore_index = -1;

weapon_damage = 34;
weapon_range = 1600;
weapon_delay = 10;
weapon_cooldown = 0;
muzzle_flash_frames = 0;
hit_marker_frames = 0;
damage_flash_frames = 0;
recoil = 0;

/// Owns desktop pointer capture so every state transition handles it the same way.
set_mouse_capture = method(id, function(_captured) {
	mouse_captured = _captured;
	window_mouse_set_locked(_captured);
	window_set_cursor(_captured ? cr_none : cr_default);
});

/// Ends active play once and releases the pointer for the restart prompt.
finish_encounter = method(id, function(_terminal_phase) {
	if (phase == FPS_STATE_PLAYING) {
		phase = _terminal_phase;
		set_mouse_capture(false);
	}
});

/// Counts living instances across the enemy object family, including child variants.
count_living_enemies = method(id, function() {
	var _living_count = 0;
	var _enemy_count = instance_number(obj_fps_enemy);
	for (var _enemy_index = 0; _enemy_index < _enemy_count; _enemy_index += 1) {
		var _enemy = instance_find(obj_fps_enemy, _enemy_index);
		if (
			instance_exists(_enemy)
			&& variable_instance_exists(_enemy, "initialized")
			&& _enemy.initialized
			&& _enemy.alive
		) {
			_living_count += 1;
		}
	}

	return _living_count;
});

/// Resolves death or victory from the player's health and every living enemy.
refresh_terminal_phase = method(id, function() {
	var _next_phase = fps_get_terminal_state(current_health, count_living_enemies());
	if (_next_phase != FPS_STATE_PLAYING) {
		finish_encounter(_next_phase);
	}
});

/// Applies enemy damage only while the encounter is active.
take_damage = method(id, function(_amount) {
	if (phase == FPS_STATE_PLAYING) {
		current_health = fps_apply_damage(current_health, _amount);
		damage_flash_frames = 12;
		refresh_terminal_phase();
	}
});

display_set_gui_size(room_width, room_height);
window_set_caption("Containment Protocol");
set_mouse_capture(true);

geometry_format = fps_create_vertex_format();
arena_buffer = fps_build_sector_buffer(geometry_format, sector);
enemy_buffer = fps_load_vertex_buffer("models/enemy_chaser.vbuff", geometry_format);
enemy_hit_buffer = fps_load_vertex_buffer("models/enemy_chaser_hit.vbuff", geometry_format);
ranged_enemy_buffer = fps_load_vertex_buffer("models/enemy_skirmisher.vbuff", geometry_format);
ranged_enemy_hit_buffer = fps_load_vertex_buffer("models/enemy_skirmisher_hit.vbuff", geometry_format);
enemy_projectile_buffer = fps_build_unit_box_buffer(geometry_format, make_color_rgb(255, 190, 45));
