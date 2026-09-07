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

loadout = fps_weapon_create_loadout();
pickups = fps_weapon_create_pickups(sector, sector_seed);
encounter_pressure = fps_enemy_encounter_pressure(sector_seed);
encounter_plan = fps_enemy_create_encounter_plan(sector, sector_seed, encounter_pressure);
pickup_notice = "PULSE RIFLE READY";
pickup_notice_frames = 90;
pickup_spin = 0;
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

/// Keeps pickup and weapon state changes visible without consuming unavailable supplies.
set_pickup_notice = method(id, function(_message) {
	pickup_notice = _message;
	pickup_notice_frames = 100;
});

/// Applies every acquired weapon's deterministic ray pattern to the shared enemy family.
fire_weapon_rays = method(id, function(_shot) {
	var _pattern_count = array_length(_shot.pattern);
	for (var _pattern_index = 0; _pattern_index < _pattern_count; _pattern_index += 1) {
		var _pattern = _shot.pattern[_pattern_index];
		var _shot_pitch = clamp(pitch + _pattern.pitch_offset, -89, 89);
		var _horizontal_length = dcos(_shot_pitch);
		var _direction_x = lengthdir_x(_horizontal_length, yaw + _pattern.yaw_offset);
		var _direction_y = lengthdir_y(_horizontal_length, yaw + _pattern.yaw_offset);
		var _direction_z = dsin(_shot_pitch);
		var _nearest_enemy = noone;
		var _nearest_hit_distance = _shot.definition.range + 1;
		var _enemy_count = instance_number(obj_fps_enemy);
		for (var _enemy_index = 0; _enemy_index < _enemy_count; _enemy_index += 1) {
			var _enemy = instance_find(obj_fps_enemy, _enemy_index);
			if (
				!instance_exists(_enemy)
				|| !variable_instance_exists(_enemy, "initialized")
				|| !_enemy.initialized
				|| !_enemy.alive
			) {
				continue;
			}
			if (fps_sector_line_blocked(sector, x, y, _enemy.x, _enemy.y)) {
				continue;
			}

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
				_shot.definition.range
			);

			if (_hit_distance >= 0 && _hit_distance < _nearest_hit_distance) {
				_nearest_enemy = _enemy;
				_nearest_hit_distance = _hit_distance;
			}
		}

		if (instance_exists(_nearest_enemy)) {
			_nearest_enemy.take_damage(_shot.damage);
			hit_marker_frames = 6;
		}
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
burrower_buffer = fps_build_enemy_role_buffer(geometry_format, FPS_ENEMY_KIND_BURROWER, false);
burrower_hit_buffer = fps_build_enemy_role_buffer(geometry_format, FPS_ENEMY_KIND_BURROWER, true);
sentry_buffer = fps_build_enemy_role_buffer(geometry_format, FPS_ENEMY_KIND_SENTRY, false);
sentry_hit_buffer = fps_build_enemy_role_buffer(geometry_format, FPS_ENEMY_KIND_SENTRY, true);
titan_buffer = fps_build_enemy_role_buffer(geometry_format, FPS_ENEMY_KIND_TITAN, false);
titan_hit_buffer = fps_build_enemy_role_buffer(geometry_format, FPS_ENEMY_KIND_TITAN, true);
enemy_buffers = [enemy_buffer, ranged_enemy_buffer, burrower_buffer, sentry_buffer, titan_buffer];
enemy_hit_buffers = [enemy_hit_buffer, ranged_enemy_hit_buffer, burrower_hit_buffer, sentry_hit_buffer, titan_hit_buffer];
enemy_projectile_buffer = fps_build_unit_box_buffer(geometry_format, make_color_rgb(255, 190, 45));
enemy_warning_buffer = fps_build_unit_box_buffer(geometry_format, make_color_rgb(255, 114, 74));
pickup_meshes = [];
for (var _pickup_kind = 0; _pickup_kind < FPS_PICKUP_COUNT; _pickup_kind += 1) {
	array_push(pickup_meshes, fps_build_unit_box_buffer(geometry_format, fps_weapon_pickup_colour(_pickup_kind)));
}

var _encounter_entry_count = array_length(encounter_plan.entries);
for (var _encounter_entry_index = 0; _encounter_entry_index < _encounter_entry_count; _encounter_entry_index += 1) {
	var _encounter_entry = encounter_plan.entries[_encounter_entry_index];
	var _encounter_socket = sector.combat_sockets[_encounter_entry.socket_index];
	var _enemy = instance_create_layer(_encounter_socket.x, _encounter_socket.y, "Gameplay", obj_fps_enemy);
	fps_enemy_apply_role(_enemy, _encounter_entry.kind);
	_enemy.spawn_socket_id = _encounter_entry.socket_id;
	_enemy.spawn_tile_index = _encounter_entry.tile_index;
	_enemy.x = _encounter_socket.x;
	_enemy.y = _encounter_socket.y;
}
