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

var _enemy = instance_find(obj_fps_enemy, 0);
if (
	instance_exists(_enemy)
	&& variable_instance_exists(_enemy, "initialized")
	&& _enemy.initialized
	&& _enemy.alive
) {
	draw_set_halign(fa_right);
	draw_set_color(c_white);
	draw_text(_gui_width - 40, 34, "HOSTILE  " + string(_enemy.current_health) + " / " + string(_enemy.max_health));
	draw_set_color(make_color_rgb(51, 63, 79));
	draw_rectangle(_gui_width - 310, 53, _gui_width - 40, 69, false);
	draw_set_color(make_color_rgb(225, 51, 89));
	draw_rectangle(
		_gui_width - 310,
		53,
		_gui_width - 310 + 270 * _enemy.current_health / _enemy.max_health,
		69,
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
draw_text(_center_x, _gui_height - 34, "WASD MOVE   •   MOUSE AIM   •   LEFT CLICK FIRE   •   ESC RELEASE MOUSE");

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

draw_set_alpha(1);
draw_set_color(c_white);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
