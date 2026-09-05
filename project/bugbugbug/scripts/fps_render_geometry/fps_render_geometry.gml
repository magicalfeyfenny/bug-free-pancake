/// Appends one complete untextured 3D vertex to a buffer.
function fps_append_vertex(_buffer, _x, _y, _z, _colour) {
	vertex_position_3d(_buffer, _x, _y, _z);
	vertex_colour(_buffer, _colour, 1);
	vertex_texcoord(_buffer, 0, 0);
}

/// Appends a two-triangle quad using the supplied winding order.
function fps_append_quad(
	_buffer,
	_x1, _y1, _z1,
	_x2, _y2, _z2,
	_x3, _y3, _z3,
	_x4, _y4, _z4,
	_colour
) {
	fps_append_vertex(_buffer, _x1, _y1, _z1, _colour);
	fps_append_vertex(_buffer, _x2, _y2, _z2, _colour);
	fps_append_vertex(_buffer, _x3, _y3, _z3, _colour);
	fps_append_vertex(_buffer, _x1, _y1, _z1, _colour);
	fps_append_vertex(_buffer, _x3, _y3, _z3, _colour);
	fps_append_vertex(_buffer, _x4, _y4, _z4, _colour);
}

/// Appends all six faces of an axis-aligned box.
function fps_append_box(_buffer, _x1, _y1, _z1, _x2, _y2, _z2, _colour) {
	var _dark = merge_color(_colour, c_black, 0.22);
	var _light = merge_color(_colour, c_white, 0.12);

	// Floor and ceiling faces.
	fps_append_quad(_buffer, _x1, _y1, _z1, _x2, _y1, _z1, _x2, _y2, _z1, _x1, _y2, _z1, _dark);
	fps_append_quad(_buffer, _x1, _y1, _z2, _x1, _y2, _z2, _x2, _y2, _z2, _x2, _y1, _z2, _light);

	// Four vertical faces use slight shade changes to make their shape readable.
	fps_append_quad(_buffer, _x1, _y1, _z1, _x1, _y1, _z2, _x2, _y1, _z2, _x2, _y1, _z1, _colour);
	fps_append_quad(_buffer, _x2, _y2, _z1, _x2, _y2, _z2, _x1, _y2, _z2, _x1, _y2, _z1, _dark);
	fps_append_quad(_buffer, _x1, _y2, _z1, _x1, _y2, _z2, _x1, _y1, _z2, _x1, _y1, _z1, _dark);
	fps_append_quad(_buffer, _x2, _y1, _z1, _x2, _y1, _z2, _x2, _y2, _z2, _x2, _y2, _z1, _colour);
}

/// Creates the vertex layout shared by the arena and enemy meshes.
function fps_create_vertex_format() {
	vertex_format_begin();
	vertex_format_add_position_3d();
	vertex_format_add_colour();
	vertex_format_add_texcoord();
	return vertex_format_end();
}

/// Loads one packaged 3D model into the vertex format used by this renderer.
function fps_load_vertex_buffer(_relative_path, _format) {
	var _path = program_directory + _relative_path;
	if (!file_exists(_path)) {
		_path = program_directory + "datafiles/" + _relative_path;
	}
	if (!file_exists(_path)) {
		_path = working_directory + _relative_path;
	}
	if (!file_exists(_path)) {
		show_error("Missing authored 3D model: " + _relative_path, true);
		return -1;
	}

	var _data = buffer_load(_path);
	var _byte_count = buffer_get_size(_data);
	// Each triangle uses three 24-byte position, colour, and texture vertices.
	if (_byte_count <= 0 || _byte_count mod 72 != 0) {
		buffer_delete(_data);
		show_error("Invalid authored 3D model: " + _relative_path, true);
		return -1;
	}

	var _vertex_buffer = vertex_create_buffer_from_buffer(_data, _format);
	buffer_delete(_data);
	vertex_freeze(_vertex_buffer);
	return _vertex_buffer;
}

/// Chooses a readable floor treatment for each generated space role and variant.
function fps_sector_floor_colour(_tile) {
	var _base_colour = make_color_rgb(24, 36, 50);
	switch (_tile.role) {
		case FPS_SECTOR_ROLE_START: _base_colour = make_color_rgb(22, 63, 78); break;
		case FPS_SECTOR_ROLE_CONNECTOR: _base_colour = make_color_rgb(35, 40, 67); break;
		case FPS_SECTOR_ROLE_COMBAT: _base_colour = make_color_rgb(72, 31, 48); break;
		case FPS_SECTOR_ROLE_REWARD: _base_colour = make_color_rgb(76, 58, 27); break;
		case FPS_SECTOR_ROLE_LORE: _base_colour = make_color_rgb(25, 70, 71); break;
		case FPS_SECTOR_ROLE_FINALE: _base_colour = make_color_rgb(64, 39, 80); break;
	}

	// The seed also changes a subtle palette band, so a new layout is visible
	// even when two seeds happen to choose the same role and variant sequence.
	var _style_colour = make_color_rgb(122, 164, 190);
	switch (_tile.style_seed mod 4) {
		case 1: _style_colour = make_color_rgb(170, 135, 84); break;
		case 2: _style_colour = make_color_rgb(105, 137, 187); break;
		case 3: _style_colour = make_color_rgb(161, 101, 164); break;
	}
	_base_colour = merge_color(_base_colour, _style_colour, 0.08);

	if (_tile.variant == 1) {
		return merge_color(_base_colour, c_white, 0.12);
	}
	if (_tile.variant == 2) {
		return merge_color(_base_colour, c_black, 0.12);
	}

	return _base_colour;
}

/// Builds every generated tile, connector wall, and aligned solid once per room.
function fps_build_sector_buffer(_format, _sector) {
	var _buffer = vertex_create_buffer();
	vertex_begin(_buffer, _format);

	var _tile_count = array_length(_sector.tiles);
	for (var _tile_index = 0; _tile_index < _tile_count; _tile_index += 1) {
		var _tile = _sector.tiles[_tile_index];
		var _floor_colour = fps_sector_floor_colour(_tile);
		fps_append_quad(
			_buffer,
			_tile.left, _tile.top, 0,
			_tile.right, _tile.top, 0,
			_tile.right, _tile.bottom, 0,
			_tile.left, _tile.bottom, 0,
			_floor_colour
		);

		// A thin role-colour stripe makes the tile boundary readable at a distance.
		var _stripe_colour = merge_color(_floor_colour, c_white, 0.28);
		fps_append_quad(
			_buffer,
			_tile.left + 8, _tile.top + 8, 1,
			_tile.right - 8, _tile.top + 8, 1,
			_tile.right - 8, _tile.top + 13, 1,
			_tile.left + 8, _tile.top + 13, 1,
			_stripe_colour
		);
	}

	var _width = _sector.width;
	var _height = _sector.height;
	var _wall_height = _sector.wall_height;
	var _wall_thickness = _sector.wall_thickness;
	var _wall_colour = make_color_rgb(48, 58, 78);
	var _ceiling_colour = make_color_rgb(13, 17, 28);
	fps_append_quad(
		_buffer,
		0, 0, _wall_height,
		0, _height, _wall_height,
		_width, _height, _wall_height,
		_width, 0, _wall_height,
		_ceiling_colour
	);
	fps_append_box(_buffer, 0, 0, 0, _width, _wall_thickness, _wall_height, _wall_colour);
	fps_append_box(_buffer, 0, _height - _wall_thickness, 0, _width, _height, _wall_height, _wall_colour);
	fps_append_box(_buffer, 0, _wall_thickness, 0, _wall_thickness, _height - _wall_thickness, _wall_height, _wall_colour);
	fps_append_box(_buffer, _width - _wall_thickness, _wall_thickness, 0, _width, _height - _wall_thickness, _wall_height, _wall_colour);

	var _solid_count = array_length(_sector.solids);
	for (var _solid_index = 0; _solid_index < _solid_count; _solid_index += 1) {
		var _solid = _sector.solids[_solid_index];
		fps_append_box(_buffer, _solid.x1, _solid.y1, 0, _solid.x2, _solid.y2, _solid.height, _solid.colour);
	}

	var _exit = _sector.exit_socket;
	if (is_struct(_exit)) {
		// The marker is decorative; the socket itself remains clear for movement.
		fps_append_box(
			_buffer,
			_exit.x - 10, _exit.y - 10, 0,
			_exit.x + 10, _exit.y + 10, 92,
			make_color_rgb(92, 244, 184)
		);
	}

	vertex_end(_buffer);
	vertex_freeze(_buffer);
	return _buffer;
}

/// Builds a unit box that can be positioned and scaled with the world matrix.
function fps_build_unit_box_buffer(_format, _colour) {
	var _buffer = vertex_create_buffer();
	vertex_begin(_buffer, _format);
	fps_append_box(_buffer, -0.5, -0.5, 0, 0.5, 0.5, 1, _colour);
	vertex_end(_buffer);
	vertex_freeze(_buffer);
	return _buffer;
}
