#macro FPS_SECTOR_ROLE_START 0
#macro FPS_SECTOR_ROLE_CONNECTOR 1
#macro FPS_SECTOR_ROLE_COMBAT 2
#macro FPS_SECTOR_ROLE_REWARD 3
#macro FPS_SECTOR_ROLE_LORE 4
#macro FPS_SECTOR_ROLE_FINALE 5

#macro FPS_SECTOR_TILE_COUNT 6
#macro FPS_SECTOR_TILE_VARIANT_COUNT 3
#macro FPS_SECTOR_DEFAULT_SEED 20260905
#macro FPS_SECTOR_SEED_MODULUS 2147483647
#macro FPS_SECTOR_DOOR_HALF_HEIGHT 112

/// Returns the stable role name used by the sector HUD and test diagnostics.
function fps_sector_role_name(_role) {
	switch (_role) {
		case FPS_SECTOR_ROLE_START: return "START";
		case FPS_SECTOR_ROLE_CONNECTOR: return "CONNECTOR";
		case FPS_SECTOR_ROLE_COMBAT: return "COMBAT";
		case FPS_SECTOR_ROLE_REWARD: return "SAFE";
		case FPS_SECTOR_ROLE_LORE: return "ARCHIVE";
		case FPS_SECTOR_ROLE_FINALE: return "FINALE";
	}

	return "UNKNOWN";
}

/// Advances the small deterministic generator used by layout and placement.
function fps_sector_next_seed(_seed) {
	var _value = abs(floor(_seed));
	if (_value <= 0) {
		_value = FPS_SECTOR_DEFAULT_SEED;
	}

	_value = 1 + (_value mod (FPS_SECTOR_SEED_MODULUS - 1));
	return (_value * 48271) mod FPS_SECTOR_SEED_MODULUS;
}

/// Takes one deterministic bounded value without touching GameMaker's global RNG.
function fps_sector_take_random(_seed, _count) {
	var _next = fps_sector_next_seed(_seed);
	return {
		seed: _next,
		value: _next mod max(1, _count),
	};
}

/// Creates the one rectangle representation shared by collision and line of sight.
function fps_sector_make_solid(_x1, _y1, _x2, _y2, _height, _colour, _kind) {
	return {
		x1: min(_x1, _x2),
		y1: min(_y1, _y2),
		x2: max(_x1, _x2),
		y2: max(_y1, _y2),
		height: _height,
		colour: _colour,
		kind: _kind,
	};
}

/// Returns true only when two solids have a real area of overlap.
function fps_sector_rects_overlap(_first, _second) {
	return _first.x1 < _second.x2
		&& _first.x2 > _second.x1
		&& _first.y1 < _second.y2
		&& _first.y2 > _second.y1;
}

/// Tests a circular actor against one axis-aligned solid rectangle.
function fps_sector_circle_hits_solid(_x, _y, _radius, _solid) {
	var _nearest_x = clamp(_x, _solid.x1, _solid.x2);
	var _nearest_y = clamp(_y, _solid.y1, _solid.y2);
	return point_distance(_x, _y, _nearest_x, _nearest_y) <= _radius;
}

/// Tests a line segment against a solid for hitscan, projectile, and cover checks.
function fps_sector_segment_hits_solid(_x1, _y1, _x2, _y2, _solid) {
	var _minimum_t = 0;
	var _maximum_t = 1;
	var _delta_x = _x2 - _x1;
	var _delta_y = _y2 - _y1;

	if (abs(_delta_x) < 0.0001) {
		if (_x1 < _solid.x1 || _x1 > _solid.x2) {
			return false;
		}
	} else {
		var _inverse_x = 1 / _delta_x;
		var _x_enter = (_solid.x1 - _x1) * _inverse_x;
		var _x_exit = (_solid.x2 - _x1) * _inverse_x;
		if (_x_enter > _x_exit) {
			var _swap_x = _x_enter;
			_x_enter = _x_exit;
			_x_exit = _swap_x;
		}
		_minimum_t = max(_minimum_t, _x_enter);
		_maximum_t = min(_maximum_t, _x_exit);
		if (_minimum_t > _maximum_t) {
			return false;
		}
	}

	if (abs(_delta_y) < 0.0001) {
		if (_y1 < _solid.y1 || _y1 > _solid.y2) {
			return false;
		}
	} else {
		var _inverse_y = 1 / _delta_y;
		var _y_enter = (_solid.y1 - _y1) * _inverse_y;
		var _y_exit = (_solid.y2 - _y1) * _inverse_y;
		if (_y_enter > _y_exit) {
			var _swap_y = _y_enter;
			_y_enter = _y_exit;
			_y_exit = _swap_y;
		}
		_minimum_t = max(_minimum_t, _y_enter);
		_maximum_t = min(_maximum_t, _y_exit);
	}

	return _minimum_t <= _maximum_t;
}

/// Returns whether an actor can occupy a point inside the generated sector.
function fps_sector_position_is_clear(_sector, _x, _y, _radius) {
	if (
		_x < _sector.wall_thickness + _radius
		|| _y < _sector.wall_thickness + _radius
		|| _x > _sector.width - _sector.wall_thickness - _radius
		|| _y > _sector.height - _sector.wall_thickness - _radius
	) {
		return false;
	}

	var _solid_count = array_length(_sector.solids);
	for (var _solid_index = 0; _solid_index < _solid_count; _solid_index += 1) {
		if (fps_sector_circle_hits_solid(_x, _y, _radius, _sector.solids[_solid_index])) {
			return false;
		}
	}

	return true;
}

/// Returns whether an interior wall blocks a planar line of sight.
function fps_sector_line_blocked(_sector, _x1, _y1, _x2, _y2) {
	var _solid_count = array_length(_sector.solids);
	for (var _solid_index = 0; _solid_index < _solid_count; _solid_index += 1) {
		if (fps_sector_segment_hits_solid(_x1, _y1, _x2, _y2, _sector.solids[_solid_index])) {
			return true;
		}
	}

	return false;
}

/// Slides an actor along a wall while preserving the outer arena boundary.
function fps_sector_move_position(_sector, _x, _y, _move_x, _move_y, _radius) {
	var _next_x = clamp(
		_x + _move_x,
		_sector.wall_thickness + _radius,
		_sector.width - _sector.wall_thickness - _radius
	);
	if (fps_sector_position_is_clear(_sector, _next_x, _y, _radius)) {
		_x = _next_x;
	}

	var _next_y = clamp(
		_y + _move_y,
		_sector.wall_thickness + _radius,
		_sector.height - _sector.wall_thickness - _radius
	);
	if (fps_sector_position_is_clear(_sector, _x, _next_y, _radius)) {
		_y = _next_y;
	}

	return [_x, _y];
}

/// Creates a named tile with aligned connector and interaction boundaries.
function fps_sector_make_tile(_index, _role, _variant, _style_seed, _left, _right, _top, _bottom) {
	var _center_y = (_top + _bottom) * 0.5;
	return {
		id: "sector-tile-" + string(_index + 1),
		index: _index,
		role: _role,
		role_name: fps_sector_role_name(_role),
		variant: _variant,
		style_seed: _style_seed,
		left: _left,
		right: _right,
		top: _top,
		bottom: _bottom,
		center_x: (_left + _right) * 0.5,
		center_y: _center_y,
		west_connector: _index > 0,
		east_connector: _index < FPS_SECTOR_TILE_COUNT - 1,
		connector_y: _center_y,
		connector_half_height: FPS_SECTOR_DOOR_HALF_HEIGHT,
	};
}

/// Defines the cover and set dressing for one tile variant.
function fps_sector_tile_solids(_tile, _wall_height) {
	var _features = [];
	var _left = _tile.left;
	var _right = _tile.right;
	var _top = _tile.top;
	var _bottom = _tile.bottom;
	var _center_x = _tile.center_x;
	var _center_y = _tile.center_y;
	var _feature_height = min(_wall_height - 30, 138);

	switch (_tile.role) {
		case FPS_SECTOR_ROLE_START:
			if (_tile.variant == 0) {
				array_push(_features, fps_sector_make_solid(_left + 36, _top + 96, _left + 58, _top + 144, _feature_height, make_color_rgb(47, 100, 128), "start-pylon"));
				array_push(_features, fps_sector_make_solid(_right - 58, _bottom - 144, _right - 36, _bottom - 96, _feature_height, make_color_rgb(47, 100, 128), "start-pylon"));
			} else if (_tile.variant == 1) {
				array_push(_features, fps_sector_make_solid(_left + 38, _center_y - 148, _left + 62, _center_y - 112, 64, make_color_rgb(38, 117, 145), "start-rail"));
				array_push(_features, fps_sector_make_solid(_right - 62, _center_y + 112, _right - 38, _center_y + 148, 64, make_color_rgb(38, 117, 145), "start-rail"));
			} else {
				array_push(_features, fps_sector_make_solid(_left + 38, _top + 96, _left + 62, _top + 128, 74, make_color_rgb(60, 126, 148), "start-pylon"));
				array_push(_features, fps_sector_make_solid(_right - 62, _top + 96, _right - 38, _top + 128, 74, make_color_rgb(60, 126, 148), "start-pylon"));
				array_push(_features, fps_sector_make_solid(_left + 38, _bottom - 128, _left + 62, _bottom - 96, 74, make_color_rgb(60, 126, 148), "start-pylon"));
				array_push(_features, fps_sector_make_solid(_right - 62, _bottom - 128, _right - 38, _bottom - 96, 74, make_color_rgb(60, 126, 148), "start-pylon"));
			}
			break;

		case FPS_SECTOR_ROLE_CONNECTOR:
			if (_tile.variant == 0) {
				array_push(_features, fps_sector_make_solid(_left + 46, _top + 112, _left + 78, _top + 146, 82, make_color_rgb(57, 72, 98), "connector-bollard"));
				array_push(_features, fps_sector_make_solid(_right - 78, _bottom - 146, _right - 46, _bottom - 112, 82, make_color_rgb(57, 72, 98), "connector-bollard"));
			} else if (_tile.variant == 1) {
				array_push(_features, fps_sector_make_solid(_left + 44, _top + 92, _left + 92, _top + 126, 72, make_color_rgb(77, 65, 110), "connector-rail"));
				array_push(_features, fps_sector_make_solid(_right - 92, _bottom - 126, _right - 44, _bottom - 92, 72, make_color_rgb(77, 65, 110), "connector-rail"));
			} else {
				array_push(_features, fps_sector_make_solid(_left + 46, _center_y - 170, _left + 70, _center_y - 132, 66, make_color_rgb(46, 93, 122), "connector-bollard"));
				array_push(_features, fps_sector_make_solid(_right - 70, _center_y + 132, _right - 46, _center_y + 170, 66, make_color_rgb(46, 93, 122), "connector-bollard"));
			}
			break;

		case FPS_SECTOR_ROLE_COMBAT:
			if (_tile.variant == 0) {
				array_push(_features, fps_sector_make_solid(_left + 42, _center_y - 112, _left + 78, _center_y - 64, _feature_height, make_color_rgb(111, 52, 70), "combat-cover"));
				array_push(_features, fps_sector_make_solid(_right - 78, _center_y + 64, _right - 42, _center_y + 112, _feature_height, make_color_rgb(111, 52, 70), "combat-cover"));
			} else if (_tile.variant == 1) {
				array_push(_features, fps_sector_make_solid(_left + 54, _top + 128, _right - 54, _top + 160, 92, make_color_rgb(121, 64, 62), "combat-barricade"));
				array_push(_features, fps_sector_make_solid(_left + 54, _bottom - 160, _right - 54, _bottom - 128, 92, make_color_rgb(121, 64, 62), "combat-barricade"));
			} else {
				array_push(_features, fps_sector_make_solid(_left + 44, _top + 130, _left + 78, _top + 164, _feature_height, make_color_rgb(133, 54, 66), "combat-pillar"));
				array_push(_features, fps_sector_make_solid(_right - 78, _top + 130, _right - 44, _top + 164, _feature_height, make_color_rgb(133, 54, 66), "combat-pillar"));
				array_push(_features, fps_sector_make_solid(_left + 44, _bottom - 164, _left + 78, _bottom - 130, _feature_height, make_color_rgb(133, 54, 66), "combat-pillar"));
				array_push(_features, fps_sector_make_solid(_right - 78, _bottom - 164, _right - 44, _bottom - 130, _feature_height, make_color_rgb(133, 54, 66), "combat-pillar"));
			}
			break;

		case FPS_SECTOR_ROLE_REWARD:
			if (_tile.variant == 0) {
				array_push(_features, fps_sector_make_solid(_left + 52, _center_y - 116, _left + 88, _center_y - 66, 76, make_color_rgb(157, 111, 44), "safe-crate"));
				array_push(_features, fps_sector_make_solid(_right - 88, _center_y + 66, _right - 52, _center_y + 116, 76, make_color_rgb(157, 111, 44), "safe-crate"));
			} else if (_tile.variant == 1) {
				array_push(_features, fps_sector_make_solid(_center_x - 64, _center_y - 104, _center_x - 32, _center_y - 56, 84, make_color_rgb(173, 129, 49), "safe-pedestal"));
				array_push(_features, fps_sector_make_solid(_center_x + 32, _center_y + 56, _center_x + 64, _center_y + 104, 84, make_color_rgb(173, 129, 49), "safe-pedestal"));
			} else {
				array_push(_features, fps_sector_make_solid(_left + 48, _top + 122, _left + 82, _top + 158, 68, make_color_rgb(183, 137, 51), "safe-crate"));
				array_push(_features, fps_sector_make_solid(_right - 82, _top + 122, _right - 48, _top + 158, 68, make_color_rgb(183, 137, 51), "safe-crate"));
				array_push(_features, fps_sector_make_solid(_left + 48, _bottom - 158, _left + 82, _bottom - 122, 68, make_color_rgb(183, 137, 51), "safe-crate"));
				array_push(_features, fps_sector_make_solid(_right - 82, _bottom - 158, _right - 48, _bottom - 122, 68, make_color_rgb(183, 137, 51), "safe-crate"));
			}
			break;

		case FPS_SECTOR_ROLE_LORE:
			if (_tile.variant == 0) {
				array_push(_features, fps_sector_make_solid(_left + 40, _center_y - 126, _left + 78, _center_y - 74, 106, make_color_rgb(61, 139, 137), "archive-console"));
				array_push(_features, fps_sector_make_solid(_center_x + 34, _top + 122, _center_x + 66, _top + 162, 92, make_color_rgb(39, 104, 126), "archive-light"));
			} else if (_tile.variant == 1) {
				array_push(_features, fps_sector_make_solid(_center_x - 22, _top + 142, _center_x + 22, _top + 194, 148, make_color_rgb(62, 154, 151), "archive-monolith"));
				array_push(_features, fps_sector_make_solid(_left + 44, _bottom - 154, _left + 72, _bottom - 116, 82, make_color_rgb(42, 111, 132), "archive-light"));
			} else {
				array_push(_features, fps_sector_make_solid(_center_x - 74, _top + 136, _center_x - 42, _top + 196, 118, make_color_rgb(48, 137, 145), "archive-arch"));
				array_push(_features, fps_sector_make_solid(_center_x + 42, _top + 136, _center_x + 74, _top + 196, 118, make_color_rgb(48, 137, 145), "archive-arch"));
			}
			break;

		case FPS_SECTOR_ROLE_FINALE:
			if (_tile.variant == 0) {
				array_push(_features, fps_sector_make_solid(_left + 54, _center_y - 126, _left + 88, _center_y - 78, _feature_height, make_color_rgb(113, 67, 144), "finale-pillar"));
				array_push(_features, fps_sector_make_solid(_right - 88, _center_y + 78, _right - 54, _center_y + 126, _feature_height, make_color_rgb(113, 67, 144), "finale-pillar"));
			} else if (_tile.variant == 1) {
				array_push(_features, fps_sector_make_solid(_left + 48, _top + 126, _left + 88, _top + 160, 102, make_color_rgb(125, 77, 151), "finale-ring"));
				array_push(_features, fps_sector_make_solid(_right - 88, _top + 126, _right - 48, _top + 160, 102, make_color_rgb(125, 77, 151), "finale-ring"));
				array_push(_features, fps_sector_make_solid(_center_x - 46, _bottom - 154, _center_x + 46, _bottom - 122, 72, make_color_rgb(125, 77, 151), "finale-ring"));
			} else {
				array_push(_features, fps_sector_make_solid(_left + 48, _top + 112, _left + 80, _top + 146, _feature_height, make_color_rgb(136, 69, 146), "finale-pillar"));
				array_push(_features, fps_sector_make_solid(_right - 80, _top + 112, _right - 48, _top + 146, _feature_height, make_color_rgb(136, 69, 146), "finale-pillar"));
				array_push(_features, fps_sector_make_solid(_left + 48, _bottom - 146, _left + 80, _bottom - 112, _feature_height, make_color_rgb(136, 69, 146), "finale-pillar"));
				array_push(_features, fps_sector_make_solid(_right - 80, _bottom - 146, _right - 48, _bottom - 112, _feature_height, make_color_rgb(136, 69, 146), "finale-pillar"));
			}
			break;
	}

	return _features;
}

/// Returns the first clear point from a tile's authored socket candidates.
function fps_sector_first_clear_point(_sector, _candidates, _radius) {
	var _candidate_count = array_length(_candidates);
	for (var _candidate_index = 0; _candidate_index < _candidate_count; _candidate_index += 1) {
		var _candidate = _candidates[_candidate_index];
		if (fps_sector_position_is_clear(_sector, _candidate[0], _candidate[1], _radius)) {
			return {x: _candidate[0], y: _candidate[1]};
		}
	}

	var _fallback = _candidates[0];
	return {x: _fallback[0], y: _fallback[1]};
}

/// Keeps enemy sockets clear of solids and every previously declared socket.
function fps_sector_enemy_socket_is_available(_sector, _x, _y, _radius) {
	if (!fps_sector_position_is_clear(_sector, _x, _y, _radius)) {
		return false;
	}

	var _socket_count = array_length(_sector.sockets);
	for (var _socket_index = 0; _socket_index < _socket_count; _socket_index += 1) {
		var _socket = _sector.sockets[_socket_index];
		if (point_distance(_x, _y, _socket.x, _socket.y) <= _radius + _socket.radius + 12) {
			return false;
		}
	}

	return true;
}

/// Adds deterministic enemy sockets to combat and finale tiles only.
function fps_sector_add_enemy_sockets(_sector, _tile) {
	// Reserve the largest roster footprint so every planned role starts clear.
	var _socket_radius = 54;
	var _candidates = [
		[
			[_tile.left + 72, _tile.center_y - 112],
			[_tile.center_x, _tile.top + 96],
			[_tile.right - 72, _tile.center_y - 112],
		],
		[
			[_tile.right - 72, _tile.center_y + 112],
			[_tile.center_x, _tile.bottom - 96],
			[_tile.left + 72, _tile.center_y + 112],
		],
	];

	for (var _candidate_index = 0; _candidate_index < array_length(_candidates); _candidate_index += 1) {
		var _candidate_set = _candidates[_candidate_index];
		var _candidate_count = array_length(_candidate_set);
		for (var _point_index = 0; _point_index < _candidate_count; _point_index += 1) {
			var _candidate = _candidate_set[_point_index];
			if (!fps_sector_enemy_socket_is_available(_sector, _candidate[0], _candidate[1], _socket_radius)) {
				continue;
			}

			var _socket_id = "finale-enemy-" + string(_candidate_index + 1);
			if (_tile.role == FPS_SECTOR_ROLE_COMBAT) {
				_socket_id = _candidate_index == 0 ? "combat-chaser" : "combat-ranged";
			}
			var _socket = fps_sector_make_socket(
				_socket_id,
				"enemy",
				_tile.role,
				_tile.index,
				_candidate[0],
				_candidate[1],
				_socket_radius,
				-1
			);
			array_push(_sector.combat_sockets, _socket);
			array_push(_sector.sockets, _socket);
			break;
		}
	}
}

/// Creates one stable socket used by actors, lore, and the exit marker.
function fps_sector_make_socket(_id, _kind, _role, _tile_index, _x, _y, _radius, _entry_index) {
	return {
		id: _id,
		kind: _kind,
		role: _role,
		tile_index: _tile_index,
		x: _x,
		y: _y,
		radius: _radius,
		entry_index: _entry_index,
	};
}

/// Builds a connected six-tile sector from one deterministic seed.
function fps_sector_generate(_seed, _width, _height, _wall_thickness, _wall_height) {
	var _random_state = fps_sector_next_seed(_seed);
	var _tile_width = (_width - 2 * _wall_thickness) / FPS_SECTOR_TILE_COUNT;
	var _top = _wall_thickness;
	var _bottom = _height - _wall_thickness;
	var _roles = [
		FPS_SECTOR_ROLE_START,
		FPS_SECTOR_ROLE_CONNECTOR,
		FPS_SECTOR_ROLE_COMBAT,
		FPS_SECTOR_ROLE_REWARD,
		FPS_SECTOR_ROLE_LORE,
		FPS_SECTOR_ROLE_FINALE,
	];
	var _middle_roles = [FPS_SECTOR_ROLE_COMBAT, FPS_SECTOR_ROLE_REWARD, FPS_SECTOR_ROLE_LORE];

	// The endpoints stay stable while the three middle spaces change order per seed.
	for (var _middle_index = 0; _middle_index < array_length(_middle_roles); _middle_index += 1) {
		var _role_pick = fps_sector_take_random(_random_state, array_length(_middle_roles) - _middle_index);
		_random_state = _role_pick.seed;
		var _swap_index = _middle_index + _role_pick.value;
		var _swap_role = _middle_roles[_middle_index];
		_middle_roles[_middle_index] = _middle_roles[_swap_index];
		_middle_roles[_swap_index] = _swap_role;
		_roles[_middle_index + 2] = _middle_roles[_middle_index];
	}

	var _tiles = [];
	var _solids = [];
	var _layout_signature = "";
	for (var _tile_index = 0; _tile_index < FPS_SECTOR_TILE_COUNT; _tile_index += 1) {
		var _variant_pick = fps_sector_take_random(_random_state, FPS_SECTOR_TILE_VARIANT_COUNT);
		_random_state = _variant_pick.seed;
		var _style_pick = fps_sector_take_random(_random_state, 1000);
		_random_state = _style_pick.seed;
		var _left = _wall_thickness + _tile_index * _tile_width;
		var _right = _left + _tile_width;
		var _tile = fps_sector_make_tile(
			_tile_index,
			_roles[_tile_index],
			_variant_pick.value,
			_style_pick.value,
			_left,
			_right,
			_top,
			_bottom
		);
		array_push(_tiles, _tile);
		_layout_signature += _tile.role_name + ":" + string(_tile.variant) + ":" + string(_tile.style_seed) + "|";

		var _tile_features = fps_sector_tile_solids(_tile, _wall_height);
		var _feature_count = array_length(_tile_features);
		for (var _feature_index = 0; _feature_index < _feature_count; _feature_index += 1) {
			array_push(_solids, _tile_features[_feature_index]);
		}
	}

	// A centered opening is the shared connector contract for every adjacent pair.
	for (var _door_index = 0; _door_index < FPS_SECTOR_TILE_COUNT - 1; _door_index += 1) {
		var _door_x = _tiles[_door_index].right;
		var _door_y = _tiles[_door_index].connector_y;
		array_push(_solids, fps_sector_make_solid(_door_x - 4, _top, _door_x + 4, _door_y - FPS_SECTOR_DOOR_HALF_HEIGHT, _wall_height, make_color_rgb(69, 79, 101), "door-wall"));
		array_push(_solids, fps_sector_make_solid(_door_x - 4, _door_y + FPS_SECTOR_DOOR_HALF_HEIGHT, _door_x + 4, _bottom, _wall_height, make_color_rgb(69, 79, 101), "door-wall"));
	}

	var _sector = {
		seed: _seed,
		width: _width,
		height: _height,
		wall_thickness: _wall_thickness,
		wall_height: _wall_height,
		tiles: _tiles,
		solids: _solids,
		sockets: [],
		layout_signature: _layout_signature,
		start_socket: undefined,
		exit_socket: undefined,
		combat_sockets: [],
	};

	for (var _socket_tile_index = 0; _socket_tile_index < FPS_SECTOR_TILE_COUNT; _socket_tile_index += 1) {
		var _socket_tile = _tiles[_socket_tile_index];
		var _lore_candidates = [
			[_socket_tile.left + 96, _socket_tile.bottom - 84],
			[_socket_tile.right - 72, _socket_tile.top + 84],
			[_socket_tile.center_x, _socket_tile.center_y + 156],
		];
		var _lore_point = fps_sector_first_clear_point(_sector, _lore_candidates, 20);
		array_push(_sector.sockets, fps_sector_make_socket(
			"lore-" + string(_socket_tile_index + 1),
			"lore",
			_socket_tile.role,
			_socket_tile_index,
			_lore_point.x,
			_lore_point.y,
			20,
			_socket_tile_index
		));

		if (_socket_tile.role == FPS_SECTOR_ROLE_START) {
			var _start_candidates = [
				[_socket_tile.left + 72, _socket_tile.center_y],
				[_socket_tile.left + 72, _socket_tile.center_y - 90],
				[_socket_tile.left + 72, _socket_tile.center_y + 90],
			];
			var _start_point = fps_sector_first_clear_point(_sector, _start_candidates, 22);
			_sector.start_socket = fps_sector_make_socket("player-start", "start", _socket_tile.role, _socket_tile_index, _start_point.x, _start_point.y, 22, -1);
			array_push(_sector.sockets, _sector.start_socket);
		}


		if (
			_socket_tile.role == FPS_SECTOR_ROLE_COMBAT
			|| _socket_tile.role == FPS_SECTOR_ROLE_FINALE
		) {
			fps_sector_add_enemy_sockets(_sector, _socket_tile);
		}

		if (_socket_tile.role == FPS_SECTOR_ROLE_FINALE) {
			var _exit_candidates = [
				[_socket_tile.right - 72, _socket_tile.center_y],
				[_socket_tile.right - 72, _socket_tile.center_y - 90],
				[_socket_tile.right - 72, _socket_tile.center_y + 90],
			];
			var _exit_point = fps_sector_first_clear_point(_sector, _exit_candidates, 22);
			_sector.exit_socket = fps_sector_make_socket("sector-exit", "exit", _socket_tile.role, _socket_tile_index, _exit_point.x, _exit_point.y, 22, -1);
			array_push(_sector.sockets, _sector.exit_socket);
		}
	}

	return _sector;
}

/// Returns the tile containing a point, or -1 outside the generated strip.
function fps_sector_tile_at(_sector, _x, _y) {
	var _tile_count = array_length(_sector.tiles);
	for (var _tile_index = 0; _tile_index < _tile_count; _tile_index += 1) {
		var _tile = _sector.tiles[_tile_index];
		if (_x >= _tile.left && _x < _tile.right && _y >= _tile.top && _y < _tile.bottom) {
			return _tile_index;
		}
	}

	return -1;
}

/// Finds a lore socket within the player's interaction range.
function fps_sector_near_lore(_sector, _x, _y, _range) {
	var _socket_count = array_length(_sector.sockets);
	var _nearest_entry = -1;
	var _nearest_distance = _range + 1;
	for (var _socket_index = 0; _socket_index < _socket_count; _socket_index += 1) {
		var _socket = _sector.sockets[_socket_index];
		if (_socket.kind != "lore") {
			continue;
		}

		var _distance = point_distance(_x, _y, _socket.x, _socket.y);
		if (_distance <= _range && _distance < _nearest_distance) {
			_nearest_distance = _distance;
			_nearest_entry = _socket.entry_index;
		}
	}

	return _nearest_entry;
}

/// Finds the requested combat socket, returning noone when the role is absent.
function fps_sector_combat_socket(_sector, _index) {
	if (_index < 0 || _index >= array_length(_sector.combat_sockets)) {
		return noone;
	}

	return _sector.combat_sockets[_index];
}

/// Checks the straight center route that every tile promises to keep open.
function fps_sector_center_path_is_clear(_sector, _radius) {
	if (!is_struct(_sector.start_socket) || !is_struct(_sector.exit_socket)) {
		return false;
	}

	var _step = 12;
	var _distance = point_distance(_sector.start_socket.x, _sector.start_socket.y, _sector.exit_socket.x, _sector.exit_socket.y);
	var _steps = ceil(_distance / _step);
	for (var _step_index = 0; _step_index <= _steps; _step_index += 1) {
		var _amount = _step_index / _steps;
		var _x = lerp(_sector.start_socket.x, _sector.exit_socket.x, _amount);
		var _y = lerp(_sector.start_socket.y, _sector.exit_socket.y, _amount);
		if (!fps_sector_position_is_clear(_sector, _x, _y, _radius)) {
			return false;
		}
	}

	return true;
}
