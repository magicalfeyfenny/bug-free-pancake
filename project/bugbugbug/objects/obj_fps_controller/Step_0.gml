fps_weapon_tick(loadout);
pickup_notice_frames = max(0, pickup_notice_frames - 1);
pickup_spin = (pickup_spin + 3) mod 360;
muzzle_flash_frames = max(0, muzzle_flash_frames - 1);
hit_marker_frames = max(0, hit_marker_frames - 1);
damage_flash_frames = max(0, damage_flash_frames - 1);
recoil = max(0, recoil - 0.18);

if (run_state == FPS_RUN_RESET_CONFIRM) {
	if (keyboard_check_pressed(vk_enter)) {
		profile = fps_profile_reset_file();
		profile_status = "PROFILE RESET COMPLETE";
		max_health = fps_profile_starting_max_health(profile);
		current_health = max_health;
		run_contract = fps_run_create_state(real(seed_input));
		sync_run_contract();
		set_mouse_capture(false);
	} else if (keyboard_check_pressed(vk_escape)) {
		profile_reset_confirm = false;
		run_contract = fps_run_create_state(real(seed_input));
		sync_run_contract();
		set_mouse_capture(false);
	}
	exit;
}

if (run_state == FPS_RUN_TITLE) {
	if (keyboard_check_pressed(ord("X"))) {
		profile_reset_confirm = true;
		run_contract.phase = FPS_RUN_RESET_CONFIRM;
		sync_run_contract();
		exit;
	}
	if (keyboard_check_pressed(ord("A"))) {
		run_contract.phase = FPS_RUN_ARCHIVE;
		sync_run_contract();
		exit;
	}
	if (keyboard_check_pressed(ord("S"))) {
		seed_editing = !seed_editing;
	}
	if (keyboard_check_pressed(ord("N"))) {
		seed_input = string(irandom_range(1, 999999999));
		seed_editing = false;
	}
	if (seed_editing) {
		if (keyboard_check_pressed(vk_backspace) && string_length(seed_input) > 0) {
			seed_input = string_copy(seed_input, 1, string_length(seed_input) - 1);
		}
		if (keyboard_check_pressed(ord("0"))) append_seed_digit(0);
		if (keyboard_check_pressed(ord("1"))) append_seed_digit(1);
		if (keyboard_check_pressed(ord("2"))) append_seed_digit(2);
		if (keyboard_check_pressed(ord("3"))) append_seed_digit(3);
		if (keyboard_check_pressed(ord("4"))) append_seed_digit(4);
		if (keyboard_check_pressed(ord("5"))) append_seed_digit(5);
		if (keyboard_check_pressed(ord("6"))) append_seed_digit(6);
		if (keyboard_check_pressed(ord("7"))) append_seed_digit(7);
		if (keyboard_check_pressed(ord("8"))) append_seed_digit(8);
		if (keyboard_check_pressed(ord("9"))) append_seed_digit(9);
	}
	if (keyboard_check_pressed(vk_enter)) {
		var _entered_seed = string_length(seed_input) > 0 ? real(seed_input) : FPS_SECTOR_DEFAULT_SEED;
		seed_editing = false;
		start_run(_entered_seed);
	}
	exit;
}

if (run_state == FPS_RUN_ARCHIVE) {
	if (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(ord("E"))) {
		run_contract.phase = FPS_RUN_TITLE;
		sync_run_contract();
		set_mouse_capture(false);
		exit;
	}
	if (keyboard_check_pressed(vk_left)) {
		archive_index = max(0, archive_index - 1);
	}
	if (keyboard_check_pressed(vk_right)) {
		archive_index = min(FPS_PROFILE_LORE_COUNT - 1, archive_index + 1);
	}
	exit;
}

if (run_state == FPS_RUN_REWARD) {
	if (keyboard_check_pressed(ord("1"))) choose_reward(0);
	if (keyboard_check_pressed(ord("2"))) choose_reward(1);
	if (keyboard_check_pressed(ord("3"))) choose_reward(2);
	exit;
}

if (run_state == FPS_RUN_SUMMARY) {
	if (keyboard_check_pressed(vk_enter) || keyboard_check_pressed(ord("R"))) {
		start_run(sector_seed);
	} else if (keyboard_check_pressed(ord("N"))) {
		show_title(irandom_range(1, 999999999));
	} else if (keyboard_check_pressed(ord("A"))) {
		run_contract.phase = FPS_RUN_ARCHIVE;
		sync_run_contract();
		set_mouse_capture(false);
	}
	exit;
}

if (phase != FPS_STATE_PLAYING) {
	exit;
}

if (lore_open) {
	if (keyboard_check_pressed(ord("E"))) {
		lore_open = false;
		lore_index = -1;
		set_mouse_capture(true);
	} else if (keyboard_check_pressed(vk_escape)) {
		lore_open = false;
		lore_index = -1;
		set_mouse_capture(false);
	}
	exit;
}

if (keyboard_check_pressed(ord("E"))) {
	var _near_lore = fps_sector_near_lore(sector, x, y, FPS_WEAPON_PICKUP_RANGE);
	if (_near_lore >= 0) {
		lore_index = _near_lore;
		mark_lore_read(lore_index);
		lore_open = true;
		set_mouse_capture(false);
		exit;
	}

	var _near_pickup = fps_weapon_near_pickup(pickups, x, y, FPS_WEAPON_PICKUP_RANGE);
	if (_near_pickup >= 0) {
		var _pickup_result = fps_weapon_collect_pickup(
			loadout,
			pickups[_near_pickup],
			current_health,
			max_health
		);
		current_health = _pickup_result.health;
		if (_pickup_result.consumed) {
			pickups[_near_pickup].collected = true;
		}
		set_pickup_notice(_pickup_result.message);
		exit;
	}

	var _current_tile = sector.tiles[run_room_index];
	if (
		room_complete
		&& run_room_index < FPS_SECTOR_TILE_COUNT - 1
		&& x >= _current_tile.right - 100
		&& abs(y - _current_tile.center_y) < 180
	) {
		if (advance_room()) {
			exit;
		}
	}
}

if (keyboard_check_pressed(ord("N"))) {
	show_title(irandom_range(1, 999999999));
	exit;
}

if (keyboard_check_pressed(vk_escape)) {
	set_mouse_capture(!mouse_captured);
}

if (!window_has_focus()) {
	exit;
}

if (!mouse_captured) {
	if (mouse_check_button_pressed(mb_left)) {
		set_mouse_capture(true);
	}
	exit;
}

// Desktop focus changes can release the lock even while play remains captured.
if (!window_mouse_get_locked()) {
	window_mouse_set_locked(true);
}

var _switch_index = -1;
if (keyboard_check_pressed(ord("1"))) _switch_index = FPS_WEAPON_PULSE;
if (keyboard_check_pressed(ord("2"))) _switch_index = FPS_WEAPON_SCATTER;
if (keyboard_check_pressed(ord("3"))) _switch_index = FPS_WEAPON_BURST;
if (keyboard_check_pressed(ord("4"))) _switch_index = FPS_WEAPON_RAIL;
if (_switch_index >= 0) {
	if (fps_weapon_switch(loadout, _switch_index)) {
		set_pickup_notice("EQUIPPED " + fps_weapon_current_definition(loadout).label);
	} else {
		set_pickup_notice("LOCKED — FIND WEAPON CACHE");
	}
}

if (keyboard_check_pressed(ord("Q"))) {
	fps_weapon_cycle(loadout, 1);
	set_pickup_notice("EQUIPPED " + fps_weapon_current_definition(loadout).label);
}

if (keyboard_check_pressed(ord("R"))) {
	var _reload_result = fps_weapon_reload(loadout);
	if (_reload_result.reloaded) {
		set_pickup_notice("RELOADED " + string(_reload_result.moved) + " ROUNDS");
	} else if (_reload_result.reason == "FULL") {
		set_pickup_notice("MAGAZINE FULL");
	} else {
		set_pickup_notice("NO RESERVE AMMO");
	}
}

var _mouse_delta_x = clamp(window_mouse_get_delta_x(), -80, 80);
var _mouse_delta_y = clamp(window_mouse_get_delta_y(), -80, 80);
yaw = (yaw + _mouse_delta_x * mouse_sensitivity + 360) mod 360;
pitch = clamp(pitch - _mouse_delta_y * mouse_sensitivity, -72, 72);

var _forward_input = keyboard_check(ord("W")) - keyboard_check(ord("S"));
var _strafe_input = keyboard_check(ord("D")) - keyboard_check(ord("A"));
var _movement = fps_movement_vector(yaw, _forward_input, _strafe_input, move_speed);
var _position = fps_sector_move_position(
	sector,
	x,
	y,
	_movement[0],
	_movement[1],
	collision_radius
);
var _tile = sector.tiles[run_room_index];
var _left_limit = _tile.left + collision_radius;
var _right_limit = _tile.right - collision_radius;
if (!room_complete) {
	_right_limit = _tile.right - 82;
}
x = clamp(_position[0], _left_limit, _right_limit);
y = _position[1];

if (mouse_check_button_pressed(mb_left)) {
	var _shot = fps_weapon_start_shot(loadout);
	if (_shot.fired) {
		loadout.cooldown_frames = _shot.cooldown_frames;
		muzzle_flash_frames = 4;
		recoil = 1;
		fire_weapon_rays(_shot);
	} else if (_shot.reason == "EMPTY") {
		set_pickup_notice("EMPTY — PRESS R TO RELOAD");
	}
}
