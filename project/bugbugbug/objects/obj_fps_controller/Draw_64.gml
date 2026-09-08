var _gui_width = display_get_gui_width();
var _gui_height = display_get_gui_height();
var _center_x = _gui_width * 0.5;
var _center_y = _gui_height * 0.5;

draw_set_font(-1);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_alpha(1);

// Health stays visible throughout play and terminal states.
draw_set_color(make_color_rgb(5, 9, 15));
draw_rectangle(28, 28, 322, 82, false);
draw_set_color(make_color_rgb(51, 63, 79));
draw_rectangle(40, 53, 310, 69, false);
draw_set_color(current_health > 30 ? make_color_rgb(42, 218, 154) : make_color_rgb(238, 65, 78));
draw_rectangle(40, 53, 40 + 270 * current_health / max_health, 69, false);
draw_set_color(c_white);
draw_text(40, 34, "VITALS  " + string(current_health) + " / " + string(max_health));

var _current_definition = fps_weapon_current_definition(loadout);
var _current_state = fps_weapon_current_state(loadout);
draw_set_color(_current_definition.colour);
draw_text(40, 88, _current_definition.label + "  [" + string(loadout.current_index + 1) + "]");
draw_set_color(c_white);
draw_text(
	40,
	108,
	"MAG " + string(_current_state.magazine) + " / " + string(_current_definition.magazine_size)
		+ "   RES " + string(_current_state.reserve)
		+ "   " + _current_definition.pattern
);
draw_set_color(make_color_rgb(51, 63, 79));
draw_rectangle(40, 128, 310, 136, false);
draw_set_color(_current_definition.colour);
draw_rectangle(
	40,
	128,
	40 + 270 * _current_state.magazine / _current_definition.magazine_size,
	136,
	false
);
draw_set_color(c_white);
var _weapon_strip = "";
for (var _weapon_index = 0; _weapon_index < FPS_WEAPON_COUNT; _weapon_index += 1) {
	var _weapon_state = loadout.states[_weapon_index];
	var _weapon_definition = fps_weapon_definition(_weapon_index);
	_weapon_strip += (_weapon_state.owned ? string(_weapon_index + 1) + ":" + _weapon_definition.identity : string(_weapon_index + 1) + ":LOCKED") + "   ";
}
draw_text(40, 148, _weapon_strip);
if (loadout.overcharge_frames > 0) {
	draw_set_color(make_color_rgb(118, 224, 255));
	draw_text(40, 168, "OVERCHARGE  " + string(ceil(loadout.overcharge_frames / 60)) + "s");
}

var _tile_index = fps_sector_tile_at(sector, x, y);
var _tile_label = _tile_index >= 0 ? sector.tiles[_tile_index].role_name : "TRANSIT";
var _archive_count = 0;
for (var _archive_index = 0; _archive_index < array_length(lore_read); _archive_index += 1) {
	if (lore_read[_archive_index]) {
		_archive_count += 1;
	}
}
draw_set_halign(fa_center);
draw_set_color(make_color_rgb(211, 226, 240));
draw_text(
	_center_x,
	10,
	"SECTOR " + string(max(0, _tile_index + 1)) + " / " + string(FPS_SECTOR_TILE_COUNT)
		+ "   " + _tile_label
		+ "   SEED " + string(sector_seed)
		+ "   ARCHIVES " + string(_archive_count) + " / " + string(FPS_SECTOR_TILE_COUNT)
);

var _enemy_count = instance_number(obj_fps_enemy);
var _enemy_row = 0;
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

	var _label_y = 34 + _enemy_row * 44;
	var _bar_y = 53 + _enemy_row * 44;
	var _hostile_name = _enemy.enemy_label;
	var _health_colour = _enemy.health_colour;

	draw_set_halign(fa_right);
	draw_set_color(c_white);
	draw_text(
		_gui_width - 40,
		_label_y,
		_hostile_name + "  " + string(_enemy.current_health) + " / " + string(_enemy.max_health)
	);
	draw_set_color(make_color_rgb(51, 63, 79));
	draw_rectangle(_gui_width - 310, _bar_y, _gui_width - 40, _bar_y + 16, false);
	draw_set_color(_health_colour);
	draw_rectangle(
		_gui_width - 310,
		_bar_y,
		_gui_width - 310 + 270 * _enemy.current_health / _enemy.max_health,
		_bar_y + 16,
		false
	);
	_enemy_row += 1;
}

// The centered weapon silhouette and recoil make every shot readable without art assets.
var _weapon_y = _gui_height - 98 + recoil * 12;
draw_set_halign(fa_left);
draw_set_color(make_color_rgb(20, 27, 38));
draw_rectangle(_center_x - 82, _weapon_y, _center_x + 82, _gui_height + 8, false);
draw_set_color(merge_color(_current_definition.colour, c_white, 0.2));
draw_rectangle(_center_x - 52, _weapon_y - 56, _center_x + 52, _weapon_y + 22, false);
draw_set_color(make_color_rgb(28, 36, 48));
draw_rectangle(_center_x - 18, _weapon_y - 95, _center_x + 18, _weapon_y - 50, false);
draw_set_color(_current_definition.colour);
draw_rectangle(_center_x - 44, _weapon_y - 46, _center_x + 44, _weapon_y - 38, false);

if (muzzle_flash_frames > 0) {
	draw_set_color(make_color_rgb(255, 206, 68));
	draw_triangle(
		_center_x,
		_weapon_y - 132,
		_center_x - 34,
		_weapon_y - 82,
		_center_x + 34,
		_weapon_y - 82,
		false
	);
}

var _crosshair_gap = 8 + recoil * 8;
draw_set_color(hit_marker_frames > 0 ? make_color_rgb(98, 255, 176) : c_white);
draw_rectangle(_center_x - _crosshair_gap - 10, _center_y - 1, _center_x - _crosshair_gap, _center_y + 1, false);
draw_rectangle(_center_x + _crosshair_gap, _center_y - 1, _center_x + _crosshair_gap + 10, _center_y + 1, false);
draw_rectangle(_center_x - 1, _center_y - _crosshair_gap - 10, _center_x + 1, _center_y - _crosshair_gap, false);
draw_rectangle(_center_x - 1, _center_y + _crosshair_gap, _center_x + 1, _center_y + _crosshair_gap + 10, false);

if (damage_flash_frames > 0) {
	draw_set_alpha(0.08 + 0.2 * damage_flash_frames / 12);
	draw_set_color(c_red);
	draw_rectangle(0, 0, _gui_width, _gui_height, false);
	draw_set_alpha(1);
}

draw_set_halign(fa_center);
draw_set_color(make_color_rgb(184, 199, 216));
draw_text(
	_center_x,
	_gui_height - 34,
	"WASD MOVE   •   MOUSE AIM   •   CLICK FIRE   •   1-4/Q SWITCH   •   R RELOAD   •   E INTERACT   •   N NEW SEED   •   ESC RELEASE"
);

if (phase == FPS_STATE_PLAYING && pickup_notice_frames > 0) {
	draw_set_alpha(0.78);
	draw_set_color(c_black);
	draw_rectangle(_center_x - 250, _center_y - 158, _center_x + 250, _center_y - 118, false);
	draw_set_alpha(1);
	draw_set_color(make_color_rgb(255, 226, 150));
	draw_set_valign(fa_middle);
	draw_text(_center_x, _center_y - 138, pickup_notice);
}

if (phase != FPS_STATE_PLAYING) {
	draw_set_alpha(0.78);
	draw_set_color(c_black);
	draw_rectangle(0, 0, _gui_width, _gui_height, false);
	draw_set_alpha(1);
	draw_set_color(phase == FPS_STATE_VICTORY ? make_color_rgb(98, 255, 176) : make_color_rgb(255, 92, 105));
	draw_set_valign(fa_middle);
	draw_text(_center_x, _center_y - 28, phase == FPS_STATE_VICTORY ? "ROOM SECURED" : "YOU DIED");
	draw_set_color(c_white);
	draw_text(_center_x, _center_y + 20, "PRESS R TO RESTART");
} else if (!mouse_captured) {
	draw_set_alpha(0.65);
	draw_set_color(c_black);
	draw_rectangle(_center_x - 220, _center_y - 48, _center_x + 220, _center_y + 48, false);
	draw_set_alpha(1);
	draw_set_color(c_white);
	draw_set_valign(fa_middle);
	draw_text(_center_x, _center_y, "CLICK TO CAPTURE MOUSE");
}

if (phase == FPS_STATE_PLAYING && !lore_open) {
	var _near_pickup = fps_weapon_near_pickup(pickups, x, y, FPS_WEAPON_PICKUP_RANGE);
	if (_near_pickup >= 0) {
		var _pickup = pickups[_near_pickup];
		var _pickup_label = fps_weapon_pickup_kind_name(_pickup.kind);
		if (_pickup.kind == FPS_PICKUP_WEAPON) {
			_pickup_label = "WEAPON CACHE: " + fps_weapon_definition(_pickup.weapon_id).label;
		}
		draw_set_alpha(0.78);
		draw_set_color(c_black);
		draw_rectangle(_center_x - 250, _center_y + 24, _center_x + 250, _center_y + 64, false);
		draw_set_alpha(1);
		draw_set_color(fps_weapon_pickup_colour(_pickup.kind));
		draw_set_valign(fa_middle);
		draw_text(_center_x, _center_y + 44, "PRESS E TO COLLECT " + _pickup_label);
	}

	var _near_lore = fps_sector_near_lore(sector, x, y, 72);
	if (_near_lore >= 0) {
		draw_set_alpha(0.78);
		draw_set_color(c_black);
		draw_rectangle(_center_x - 190, _center_y + 72, _center_x + 190, _center_y + 112, false);
		draw_set_alpha(1);
		draw_set_color(make_color_rgb(102, 255, 225));
		draw_set_valign(fa_middle);
		draw_text(_center_x, _center_y + 92, "PRESS E TO READ ARCHIVE " + string(_near_lore + 1));
	}
}

if (lore_open && phase == FPS_STATE_PLAYING && lore_index >= 0) {
	var _entry = lore_entries[lore_index];
	draw_set_alpha(0.88);
	draw_set_color(make_color_rgb(4, 10, 18));
	draw_rectangle(128, 132, _gui_width - 128, _gui_height - 132, false);
	draw_set_alpha(1);
	draw_set_color(make_color_rgb(102, 255, 225));
	draw_set_valign(fa_top);
	draw_text(_center_x, 174, _entry.title);
	draw_set_color(c_white);
	draw_text_ext(_center_x - 410, 244, _entry.text, 8, 820);
	draw_set_color(make_color_rgb(184, 199, 216));
	draw_set_valign(fa_bottom);
	draw_text(_center_x, _gui_height - 174, "PRESS E TO CLOSE   •   ESC CLOSES WITHOUT CAPTURING MOUSE");
}

if (run_state == FPS_RUN_TITLE || run_state == FPS_RUN_RESET_CONFIRM) {
	draw_set_alpha(0.92);
	draw_set_color(make_color_rgb(3, 8, 15));
	draw_rectangle(0, 0, _gui_width, _gui_height, false);
	draw_set_alpha(1);
	draw_set_halign(fa_center);
	draw_set_valign(fa_top);
	draw_set_color(make_color_rgb(102, 255, 225));
	draw_text(_center_x, 92, "CONTAINMENT PROTOCOL");
	draw_set_color(c_white);
	draw_text(_center_x, 132, "A SEEDED CONTAINMENT ROGUELITE");
	draw_set_color(make_color_rgb(184, 199, 216));
	draw_text(_center_x, 184, "ENTER  BEGIN RUN");
	draw_text(_center_x, 216, "N  RANDOM SEED     S  EDIT SEED     A  ARCHIVE");
	draw_text(_center_x, 248, "X  RESET PROFILE");
	draw_set_color(make_color_rgb(255, 226, 150));
	draw_text(_center_x, 302, "SEED  " + seed_input + (seed_editing ? "_" : ""));
	draw_set_color(c_white);
	draw_text(_center_x, 350, "RUNS " + string(profile.runs) + "   VICTORIES " + string(profile.victories));
	draw_text(_center_x, 382, "ARCHIVES " + string(fps_profile_discovered_lore_count(profile)) + " / " + string(FPS_PROFILE_LORE_COUNT));
	draw_set_color(make_color_rgb(118, 224, 255));
	draw_text(_center_x, 430, profile_status);
	if (run_state == FPS_RUN_RESET_CONFIRM) {
		draw_set_alpha(0.9);
		draw_set_color(c_black);
		draw_rectangle(_center_x - 300, 480, _center_x + 300, 590, false);
		draw_set_alpha(1);
		draw_set_color(make_color_rgb(255, 92, 105));
		draw_text(_center_x, 500, "RESET PROFILE AND ERASE DISCOVERIES?");
		draw_set_color(c_white);
		draw_text(_center_x, 548, "ENTER CONFIRM   ESC CANCEL");
	}
}

if (run_state == FPS_RUN_ARCHIVE) {
	draw_set_alpha(0.94);
	draw_set_color(make_color_rgb(3, 8, 15));
	draw_rectangle(0, 0, _gui_width, _gui_height, false);
	draw_set_alpha(1);
	draw_set_halign(fa_center);
	draw_set_valign(fa_top);
	draw_set_color(make_color_rgb(102, 255, 225));
	draw_text(_center_x, 86, "DISCOVERED ARCHIVE");
	if (fps_profile_discovered_lore_count(profile) <= 0) {
		draw_set_color(make_color_rgb(184, 199, 216));
		draw_text(_center_x, 260, "NO ARCHIVES RECORDED");
	} else {
		var _archive_entry = lore_entries[archive_index];
		if (profile.discovered_lore[archive_index]) {
			draw_set_color(c_white);
			draw_text(_center_x, 156, _archive_entry.title);
			draw_set_color(make_color_rgb(211, 226, 240));
			draw_text_ext(_center_x - 410, 236, _archive_entry.text, 8, 820);
		} else {
			draw_set_color(make_color_rgb(103, 118, 136));
			draw_text(_center_x, 260, "ARCHIVE " + string(archive_index + 1) + " // LOCKED");
		}
	}
	draw_set_color(make_color_rgb(184, 199, 216));
	draw_set_valign(fa_bottom);
	draw_text(_center_x, _gui_height - 96, "LEFT / RIGHT BROWSE   E OR ESC BACK");
}

if (run_state == FPS_RUN_REWARD) {
	draw_set_alpha(0.9);
	draw_set_color(make_color_rgb(3, 8, 15));
	draw_rectangle(0, 0, _gui_width, _gui_height, false);
	draw_set_alpha(1);
	draw_set_halign(fa_center);
	draw_set_valign(fa_top);
	draw_set_color(make_color_rgb(102, 255, 225));
	draw_text(_center_x, 96, "ROOM SECURED // CHOOSE AN ADVANTAGE");
	draw_set_color(make_color_rgb(184, 199, 216));
	draw_text(_center_x, 132, "Your choice is part of this seed's replayable run.");
	var _choice_count = array_length(run_contract.reward_choices);
	var _card_width = 260;
	var _card_gap = 24;
	var _cards_left = _center_x - (_choice_count * _card_width + (_choice_count - 1) * _card_gap) * 0.5;
	for (var _choice_index = 0; _choice_index < _choice_count; _choice_index += 1) {
		var _choice = run_contract.reward_choices[_choice_index];
		var _card_left = _cards_left + _choice_index * (_card_width + _card_gap);
		var _card_right = _card_left + _card_width;
		draw_set_color(make_color_rgb(14, 29, 43));
		draw_rectangle(_card_left, 220, _card_right, 430, false);
		draw_set_color(make_color_rgb(102, 255, 225));
		draw_rectangle(_card_left, 220, _card_right, 226, false);
		draw_set_color(c_white);
		draw_text(_card_left + _card_width * 0.5, 250, string(_choice_index + 1) + "  " + _choice.label);
		draw_set_color(make_color_rgb(211, 226, 240));
		draw_text_ext(_card_left + 24, 308, _choice.description, 8, _card_width - 48);
	}
	draw_set_color(make_color_rgb(255, 226, 150));
	draw_set_valign(fa_bottom);
	draw_text(_center_x, _gui_height - 96, "PRESS 1, 2, OR 3 TO COMMIT THE NEXT ROOM");
}

if (run_state == FPS_RUN_SUMMARY) {
	draw_set_alpha(0.94);
	draw_set_color(make_color_rgb(3, 8, 15));
	draw_rectangle(0, 0, _gui_width, _gui_height, false);
	draw_set_alpha(1);
	draw_set_halign(fa_center);
	draw_set_valign(fa_top);
	draw_set_color(phase == FPS_STATE_VICTORY ? make_color_rgb(98, 255, 176) : make_color_rgb(255, 92, 105));
	draw_text(_center_x, 112, phase == FPS_STATE_VICTORY ? "CONTAINMENT COMPLETE" : "CONTAINMENT FAILED");
	draw_set_color(c_white);
	draw_text(_center_x, 164, summary_reason);
	draw_set_color(make_color_rgb(211, 226, 240));
	draw_text(_center_x, 228, "SEED " + string(sector_seed) + "   ROOMS CLEARED " + string(run_contract.rooms_cleared));
	draw_text(_center_x, 260, "ARCHIVES THIS RUN " + string(fps_profile_discovered_lore_count(profile)) + " / " + string(FPS_PROFILE_LORE_COUNT));
	draw_set_color(make_color_rgb(184, 199, 216));
	draw_text(_center_x, 344, "ENTER / R  RESTART SEED     N  TITLE WITH NEW SEED     A  ARCHIVE");
}

if (
	run_state == FPS_RUN_PLAYING
	&& room_complete
	&& run_room_index < FPS_SECTOR_TILE_COUNT - 1
	&& x >= sector.tiles[run_room_index].right - 100
) {
	draw_set_alpha(0.78);
	draw_set_color(c_black);
	draw_rectangle(_center_x - 260, _center_y + 120, _center_x + 260, _center_y + 164, false);
	draw_set_alpha(1);
	draw_set_color(make_color_rgb(255, 226, 150));
	draw_set_halign(fa_center);
	draw_set_valign(fa_middle);
	draw_text(_center_x, _center_y + 142, "PRESS E TO ENTER " + sector.tiles[run_room_index + 1].role_name);
}

draw_set_alpha(1);
draw_set_color(c_white);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
