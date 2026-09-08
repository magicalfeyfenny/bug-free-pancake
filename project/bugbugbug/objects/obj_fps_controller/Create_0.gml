var _initial_state = fps_create_encounter_state();
profile = fps_profile_load();

max_health = fps_profile_starting_max_health(profile);
current_health = _initial_state.player_health;
phase = _initial_state.phase;

move_speed = 4;
collision_radius = 22;
eye_height = 68;
yaw = 0;
pitch = 0;
mouse_sensitivity = 0.16;
mouse_captured = false;

wall_height = 200;
wall_thickness = 24;

sector_seed = fps_run_normalize_seed(FPS_SECTOR_DEFAULT_SEED);
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

run_contract = fps_run_create_state(sector_seed);
run_state = run_contract.phase;
run_room_index = run_contract.room_index;
seed_input = string(sector_seed);
seed_editing = false;
archive_index = 0;
profile_reset_confirm = false;
profile_status = "PROFILE READY";
summary_reason = "";
run_started = false;
room_complete = false;

loadout = fps_weapon_create_loadout();
pickups = fps_weapon_create_pickups(sector, sector_seed);
encounter_pressure = 0;
encounter_plan = {entries: [], signature: ""};
pickup_notice = "PRESS ENTER TO BEGIN CONTAINMENT PROTOCOL";
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

/// Copies the pure run contract into the controller fields used by input and HUD code.
sync_run_contract = method(id, function() {
	run_state = run_contract.phase;
	run_room_index = run_contract.room_index;
	room_complete = run_contract.room_complete;
});

/// Destroys only transient enemies and projectiles when a room or run changes.
clear_room_instances = method(id, function() {
	while (instance_number(obj_fps_enemy) > 0) {
		var _enemy = instance_find(obj_fps_enemy, 0);
		if (instance_exists(_enemy)) {
			instance_destroy(_enemy);
		}
	}
	while (instance_number(obj_fps_enemy_projectile) > 0) {
		var _projectile = instance_find(obj_fps_enemy_projectile, 0);
		if (instance_exists(_projectile)) {
			instance_destroy(_projectile);
		}
	}
});

/// Creates only the encounter assigned to the current generated tile.
spawn_room_encounter = method(id, function() {
	var _tile = sector.tiles[run_room_index];
	encounter_pressure = fps_run_room_pressure(sector, run_room_index, sector_seed);
	encounter_plan = fps_run_create_room_plan(
		sector,
		sector_seed,
		run_room_index,
		encounter_pressure
	);
	var _entry_count = array_length(encounter_plan.entries);
	for (var _entry_index = 0; _entry_index < _entry_count; _entry_index += 1) {
		var _entry = encounter_plan.entries[_entry_index];
		var _enemy = instance_create_layer(_entry.x, _entry.y, "Gameplay", obj_fps_enemy);
		fps_enemy_apply_role(_enemy, _entry.kind);
		_enemy.spawn_socket_id = _entry.socket_id;
		_enemy.spawn_tile_index = _entry.tile_index;
		_enemy.x = _entry.x;
		_enemy.y = _entry.y;
	}

	if (_tile.role != FPS_SECTOR_ROLE_COMBAT && _tile.role != FPS_SECTOR_ROLE_FINALE) {
		run_contract = fps_run_mark_room_complete(run_contract);
		sync_run_contract();
	} else if (_entry_count <= 0) {
		run_contract = fps_run_mark_room_complete(run_contract);
		sync_run_contract();
	}
});

/// Starts a fresh deterministic run and clears every run-scoped object and value.
start_run = method(id, function(_seed) {
	clear_room_instances();
	sector_seed = fps_run_normalize_seed(_seed);
	run_contract = fps_run_begin(sector_seed);
	sync_run_contract();
	profile = fps_profile_record_run_started(profile);
	fps_profile_save(profile);
	max_health = fps_profile_starting_max_health(profile);
	current_health = max_health;
	phase = FPS_STATE_PLAYING;
	sector = fps_sector_generate(
		sector_seed,
		room_width,
		room_height,
		wall_thickness,
		wall_height
	);
	global.fps_sector = sector;
	global.fps_next_sector_seed = fps_sector_next_seed(sector_seed);
	x = sector.start_socket.x;
	y = sector.start_socket.y;
	lore_read = array_create(FPS_SECTOR_TILE_COUNT, false);
	lore_open = false;
	lore_index = -1;
	loadout = fps_weapon_create_loadout();
	pickups = fps_weapon_create_pickups(sector, sector_seed);
	encounter_plan = {entries: [], signature: ""};
	room_complete = true;
	run_started = true;
	summary_reason = "";
	seed_input = string(sector_seed);
	profile_status = "RUN IN PROGRESS";
	set_mouse_capture(true);
	vertex_delete_buffer(arena_buffer);
	arena_buffer = fps_build_sector_buffer(geometry_format, sector);
	spawn_room_encounter();
	set_pickup_notice("SEED " + string(sector_seed) + " // CONTAINMENT PROTOCOL STARTED");
});

/// Moves the player into the next generated tile only after its current room is clear.
advance_room = method(id, function() {
	if (!room_complete || run_room_index >= FPS_SECTOR_TILE_COUNT - 1) {
		return false;
	}

	clear_room_instances();
	run_contract = fps_run_advance_room(run_contract);
	sync_run_contract();
	var _tile = sector.tiles[run_room_index];
	x = _tile.left + 72;
	y = _tile.center_y;
	spawn_room_encounter();
	set_mouse_capture(true);
	set_pickup_notice("ENTERED " + _tile.role_name + " // ROOM " + string(run_room_index + 1));
	return true;
});

/// Opens the profile-expanded reward cards after a non-finale combat room.
begin_reward = method(id, function() {
	if (run_state != FPS_RUN_PLAYING) {
		return;
	}

	var _choices = fps_run_create_reward_choices(sector_seed, run_room_index, profile);
	run_contract = fps_run_begin_reward(run_contract, _choices);
	sync_run_contract();
	set_mouse_capture(false);
	set_pickup_notice("ROOM SECURED // CHOOSE YOUR NEXT ADVANTAGE");
});

/// Applies one reward card and restores valid input for the next room transition.
choose_reward = method(id, function(_choice_index) {
	if (run_state != FPS_RUN_REWARD || _choice_index < 0 || _choice_index >= array_length(run_contract.reward_choices)) {
		return false;
	}

	var _choice = run_contract.reward_choices[_choice_index];
	var _result = fps_run_apply_reward(_choice, loadout, current_health, max_health, profile);
	current_health = _result.health;
	max_health = _result.max_health;
	fps_profile_save(profile);
	run_contract = fps_run_select_reward(run_contract, _choice_index);
	sync_run_contract();
	set_mouse_capture(true);
	set_pickup_notice(_result.message);
	return true;
});

/// Ends a run exactly once and persists discoveries and victory unlocks.
finish_encounter = method(id, function(_terminal_phase) {
	if (phase == FPS_STATE_PLAYING && run_state != FPS_RUN_SUMMARY) {
		phase = _terminal_phase;
		summary_reason = _terminal_phase == FPS_STATE_VICTORY
			? "THE SIGNAL CORE IS SECURED"
			: "CONTAINMENT FAILED BEFORE THE CORE"
		;
		run_contract = fps_run_finish(run_contract, _terminal_phase);
		sync_run_contract();
		profile = fps_profile_record_run_finished(profile, _terminal_phase == FPS_STATE_VICTORY);
		fps_profile_save(profile);
		set_mouse_capture(false);
	}
});

/// Returns the title screen with the selected seed available for the next run.
show_title = method(id, function(_seed) {
	clear_room_instances();
	phase = FPS_STATE_PLAYING;
	seed_input = string(fps_run_normalize_seed(_seed));
	run_contract = fps_run_create_state(real(seed_input));
	sync_run_contract();
	run_started = false;
	profile_reset_confirm = false;
	archive_index = 0;
	set_mouse_capture(false);
	profile_status = "PROFILE READY";
});

/// Appends one numeric seed digit while keeping input bounded and reproducible.
append_seed_digit = method(id, function(_digit) {
	if (string_length(seed_input) < 10) {
		seed_input += string(_digit);
	}
});

/// Refreshes archive progress after a newly discovered lore entry.
mark_lore_read = method(id, function(_index) {
	if (_index < 0 || _index >= array_length(lore_entries)) {
		return;
	}

	lore_read[_index] = true;
	fps_profile_discover_lore(profile, lore_entries[_index].id);
	fps_profile_save(profile);
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
	if (current_health <= 0) {
		finish_encounter(FPS_STATE_DEAD);
		return;
	}
	if (run_state != FPS_RUN_PLAYING || count_living_enemies() > 0) {
		return;
	}

	var _role = sector.tiles[run_room_index].role;
	if (_role == FPS_SECTOR_ROLE_FINALE) {
		finish_encounter(FPS_STATE_VICTORY);
	} else if (_role == FPS_SECTOR_ROLE_COMBAT) {
		begin_reward();
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
set_mouse_capture(false);

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
