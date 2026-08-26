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

/// Builds the arena once so normal frames only submit frozen geometry.
function fps_build_arena_buffer(_format, _width, _height, _wall_height, _wall_thickness) {
	var _buffer = vertex_create_buffer();
	vertex_begin(_buffer, _format);

	var _tile_size = 128;
	var _tile_y = 0;
	var _row = 0;
	while (_tile_y < _height) {
		var _tile_x = 0;
		var _column = 0;
		while (_tile_x < _width) {
			var _floor_colour = make_color_rgb(18, 30, 42);
			if ((_row + _column) mod 2 == 0) {
				_floor_colour = make_color_rgb(22, 38, 52);
			}

			fps_append_quad(
				_buffer,
				_tile_x, _tile_y, 0,
				min(_width, _tile_x + _tile_size), _tile_y, 0,
				min(_width, _tile_x + _tile_size), min(_height, _tile_y + _tile_size), 0,
				_tile_x, min(_height, _tile_y + _tile_size), 0,
				_floor_colour
			);
			_tile_x += _tile_size;
			_column += 1;
		}
		_tile_y += _tile_size;
		_row += 1;
	}

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

	var _accent = make_color_rgb(30, 185, 215);
	fps_append_quad(
		_buffer,
		_wall_thickness + 0.5, _wall_thickness + 0.5, 82,
		_width - _wall_thickness - 0.5, _wall_thickness + 0.5, 82,
		_width - _wall_thickness - 0.5, _wall_thickness + 0.5, 88,
		_wall_thickness + 0.5, _wall_thickness + 0.5, 88,
		_accent
	);
	fps_append_quad(
		_buffer,
		_width - _wall_thickness - 0.5, _height - _wall_thickness - 0.5, 82,
		_wall_thickness + 0.5, _height - _wall_thickness - 0.5, 82,
		_wall_thickness + 0.5, _height - _wall_thickness - 0.5, 88,
		_width - _wall_thickness - 0.5, _height - _wall_thickness - 0.5, 88,
		_accent
	);

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
