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

	var _is_ranged = _enemy.enemy_kind == FPS_ENEMY_KIND_RANGED;
	var _label_y = _is_ranged ? 86 : 34;
	var _bar_y = _is_ranged ? 105 : 53;
	var _hostile_name = _is_ranged ? "SKIRMISHER" : "CHASER";
	var _health_colour = _is_ranged
		? make_color_rgb(122, 104, 238)
		: make_color_rgb(225, 51, 89);

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
}

// The centered weapon silhouette and recoil make every shot readable without art assets.
var _weapon_y = _gui_height - 98 + recoil * 12;
draw_set_halign(fa_left);
draw_set_color(make_color_rgb(20, 27, 38));
draw_rectangle(_center_x - 82, _weapon_y, _center_x + 82, _gui_height + 8, false);
draw_set_color(make_color_rgb(76, 95, 119));
draw_rectangle(_center_x - 52, _weapon_y - 56, _center_x + 52, _weapon_y + 22, false);
draw_set_color(make_color_rgb(28, 36, 48));
draw_rectangle(_center_x - 18, _weapon_y - 95, _center_x + 18, _weapon_y - 50, false);
draw_set_color(make_color_rgb(34, 201, 221));
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
draw_text(_center_x, _gui_height - 34, "WASD MOVE   •   MOUSE AIM   •   LEFT CLICK FIRE   •   E READ   •   N NEW SEED   •   ESC RELEASE MOUSE");

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

draw_set_alpha(1);
draw_set_color(c_white);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
