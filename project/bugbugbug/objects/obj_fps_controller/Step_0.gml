fps_weapon_tick(loadout);
pickup_notice_frames = max(0, pickup_notice_frames - 1);
pickup_spin = (pickup_spin + 3) mod 360;
muzzle_flash_frames = max(0, muzzle_flash_frames - 1);
hit_marker_frames = max(0, hit_marker_frames - 1);
damage_flash_frames = max(0, damage_flash_frames - 1);
recoil = max(0, recoil - 0.18);

if (phase != FPS_STATE_PLAYING) {
	if (keyboard_check_pressed(ord("R"))) {
		room_restart();
	}
	if (keyboard_check_pressed(ord("N"))) {
		global.fps_next_sector_seed = fps_sector_next_seed(sector_seed);
		room_restart();
	}
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
		lore_read[lore_index] = true;
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
}

if (keyboard_check_pressed(ord("N"))) {
	global.fps_next_sector_seed = fps_sector_next_seed(sector_seed);
	room_restart();
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
x = _position[0];
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
