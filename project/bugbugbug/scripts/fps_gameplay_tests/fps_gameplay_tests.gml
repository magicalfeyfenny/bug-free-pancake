suite(function() {
	describe("FPS gameplay state", function() {
		it("starts a fresh playable encounter", function() {
			var _state = fps_create_encounter_state();
			expect(_state.player_health).toBe(FPS_PLAYER_MAX_HEALTH);
			expect(_state.enemy_health).toBe(FPS_ENEMY_MAX_HEALTH);
			expect(_state.ranged_enemy_health).toBe(FPS_RANGED_ENEMY_MAX_HEALTH);
			expect(_state.phase).toBe(FPS_STATE_PLAYING);
		});

		it("clamps damage and ignores healing through negative damage", function() {
			expect(fps_apply_damage(100, 34)).toBe(66);
			expect(fps_apply_damage(20, 50)).toBe(0);
			expect(fps_apply_damage(20, -10)).toBe(20);
		});

		it("keeps enemy variant health and death independent", function() {
			var _chaser = create(0, 0, obj_fps_enemy);
			var _ranged = create(0, 0, obj_fps_ranged_enemy);
			_chaser.take_damage(34);
			_ranged.take_damage(34);
			expect(_chaser.current_health).toBe(66);
			expect(_ranged.current_health).toBe(41);

			_chaser.take_damage(66);
			expect(_chaser.alive).toBe(false);
			expect(_ranged.alive).toBe(true);
			expect(_ranged.current_health).toBe(41);
			expect(instance_find(obj_fps_controller, 0).phase).toBe(FPS_STATE_PLAYING);

			instance_destroy(_chaser);
			instance_destroy(_ranged);
		});

		it("waits for both enemies before selecting victory", function() {
			expect(fps_get_terminal_state(0, 2)).toBe(FPS_STATE_DEAD);
			expect(fps_get_terminal_state(100, 0)).toBe(FPS_STATE_VICTORY);
			expect(fps_get_terminal_state(40, 1)).toBe(FPS_STATE_PLAYING);
		});

		it("finds only forward in-range hitscan intersections", function() {
			expect(fps_ray_sphere_distance(0, 0, 0, 1, 0, 0, 10, 0, 0, 2, 20)).toBe(8);
			expect(fps_ray_sphere_distance(0, 0, 0, 1, 0, 0, 10, 4, 0, 2, 20)).toBe(-1);
			expect(fps_ray_sphere_distance(0, 0, 0, -1, 0, 0, 10, 0, 0, 2, 20)).toBe(-1);
			expect(fps_ray_sphere_distance(0, 0, 0, 1, 0, 0, 10, 0, 0, 2, 7)).toBe(-1);
		});

		it("keeps actors inside every arena wall", function() {
			var _minimum = fps_clamp_position(-50, -20, 22, 1366, 768, 24);
			var _maximum = fps_clamp_position(2000, 900, 22, 1366, 768, 24);
			expect(_minimum[0]).toBe(46);
			expect(_minimum[1]).toBe(46);
			expect(_maximum[0]).toBe(1320);
			expect(_maximum[1]).toBe(722);
		});

		it("normalizes diagonal movement to the configured speed", function() {
			var _movement = fps_movement_vector(0, 1, 1, 4);
			var _scaled_length = round(point_distance(0, 0, _movement[0], _movement[1]) * 1000);
			expect(_scaled_length).toBe(4000);
		});

		it("moves evasively across the target line and can reverse direction", function() {
			var _left = fps_evasive_movement_vector(0, 0, 10, 0, 1, 3);
			var _right = fps_evasive_movement_vector(0, 0, 10, 0, -1, 3);
			expect(_left[0]).toBe(0);
			expect(_left[1]).toBe(3);
			expect(_right[0]).toBe(0);
			expect(_right[1]).toBe(-3);
		});

		it("alternates the ranged enemy behavior modes", function() {
			expect(fps_next_ranged_mode(FPS_RANGED_MODE_EVADE)).toBe(FPS_RANGED_MODE_ATTACK);
			expect(fps_next_ranged_mode(FPS_RANGED_MODE_ATTACK)).toBe(FPS_RANGED_MODE_EVADE);
		});

		it("detects projectile contact at the combined collision radius", function() {
			expect(fps_circles_overlap(0, 0, 4, 6, 0, 2)).toBe(true);
			expect(fps_circles_overlap(0, 0, 4, 7, 0, 2)).toBe(false);
		});
	});
});

suite(function() {
	describe("Generated containment sectors", function() {
		it("replays the same layout and placements for the same seed", function() {
			var _first = fps_sector_generate(13579, 1366, 768, 24, 200);
			var _second = fps_sector_generate(13579, 1366, 768, 24, 200);

			expect(_first.layout_signature).toBe(_second.layout_signature);
			expect(_first.start_socket.x).toBe(_second.start_socket.x);
			expect(_first.start_socket.y).toBe(_second.start_socket.y);
			expect(_first.exit_socket.x).toBe(_second.exit_socket.x);
			expect(_first.exit_socket.y).toBe(_second.exit_socket.y);
		});

		it("changes role order or tile treatment for a different seed", function() {
			var _first = fps_sector_generate(13579, 1366, 768, 24, 200);
			var _second = fps_sector_generate(24680, 1366, 768, 24, 200);
			expect(_first.layout_signature == _second.layout_signature).toBeFalsy();
		});

		it("contains every required role and six discoverable archive sockets", function() {
			var _sector = fps_sector_generate(97531, 1366, 768, 24, 200);
			var _roles_seen = array_create(FPS_SECTOR_TILE_COUNT, false);
			var _lore_count = 0;
			var _tile_count = array_length(_sector.tiles);
			for (var _tile_index = 0; _tile_index < _tile_count; _tile_index += 1) {
				_roles_seen[_sector.tiles[_tile_index].role] = true;
			}
			for (var _role_index = 0; _role_index < FPS_SECTOR_TILE_COUNT; _role_index += 1) {
				expect(_roles_seen[_role_index]).toBeTruthy();
			}

			var _socket_count = array_length(_sector.sockets);
			for (var _socket_index = 0; _socket_index < _socket_count; _socket_index += 1) {
				if (_sector.sockets[_socket_index].kind == "lore") {
					_lore_count += 1;
				}
			}
			expect(_lore_count).toBe(FPS_SECTOR_TILE_COUNT);
		});

		it("keeps solids disjoint, sockets clear, and the required route open", function() {
			var _sector = fps_sector_generate(112233, 1366, 768, 24, 200);
			var _solids_are_disjoint = true;
			var _solid_count = array_length(_sector.solids);
			for (var _first_index = 0; _first_index < _solid_count; _first_index += 1) {
				for (var _second_index = _first_index + 1; _second_index < _solid_count; _second_index += 1) {
					if (fps_sector_rects_overlap(_sector.solids[_first_index], _sector.solids[_second_index])) {
						_solids_are_disjoint = false;
					}
				}
			}
			expect(_solids_are_disjoint).toBeTruthy();
			expect(fps_sector_center_path_is_clear(_sector, 22)).toBeTruthy();

			var _socket_count = array_length(_sector.sockets);
			for (var _socket_index = 0; _socket_index < _socket_count; _socket_index += 1) {
				var _socket = _sector.sockets[_socket_index];
				expect(fps_sector_position_is_clear(_sector, _socket.x, _socket.y, _socket.radius)).toBeTruthy();
			}
		});

		it("shares centered connectors while blocking wall-side sight lines", function() {
			var _sector = fps_sector_generate(445566, 1366, 768, 24, 200);
			for (var _tile_index = 0; _tile_index < FPS_SECTOR_TILE_COUNT - 1; _tile_index += 1) {
				var _tile = _sector.tiles[_tile_index];
				var _next_tile = _sector.tiles[_tile_index + 1];
				expect(_tile.east_connector).toBeTruthy();
				expect(_next_tile.west_connector).toBeTruthy();
				expect(fps_sector_line_blocked(_sector, _tile.center_x, _tile.top + 48, _next_tile.center_x, _next_tile.top + 48)).toBeTruthy();
				expect(fps_sector_line_blocked(_sector, _tile.center_x, _tile.center_y, _next_tile.center_x, _next_tile.center_y)).toBeFalsy();
			}
		});

		it("returns six readable lore entries", function() {
			var _entries = fps_create_lore_entries();
			expect(array_length(_entries)).toBe(FPS_SECTOR_TILE_COUNT);
			for (var _entry_index = 0; _entry_index < array_length(_entries); _entry_index += 1) {
				expect(string_length(_entries[_entry_index].id) > 0).toBeTruthy();
				expect(string_length(_entries[_entry_index].title) > 0).toBeTruthy();
					expect(string_length(_entries[_entry_index].text) > 0).toBeTruthy();
			}
		});

		it("keeps a representative seed sample valid and visually varied", function() {
			var _role_variant_seen = [];
			for (var _role_index = 0; _role_index < FPS_SECTOR_TILE_COUNT; _role_index += 1) {
				array_push(_role_variant_seen, array_create(FPS_SECTOR_TILE_VARIANT_COUNT, false));
			}

			var _seed = 7001;
			var _previous_signature = "";
			var _changed_signatures = 0;
			for (var _sample_index = 0; _sample_index < 24; _sample_index += 1) {
				var _sector = fps_sector_generate(_seed, 1366, 768, 24, 200);
				var _repeat = fps_sector_generate(_seed, 1366, 768, 24, 200);
				expect(_repeat.layout_signature).toBe(_sector.layout_signature);
				expect(fps_sector_center_path_is_clear(_sector, 22)).toBeTruthy();

				var _tile_count = array_length(_sector.tiles);
				for (var _tile_index = 0; _tile_index < _tile_count; _tile_index += 1) {
					var _tile = _sector.tiles[_tile_index];
					_role_variant_seen[_tile.role][_tile.variant] = true;
				}

				var _solid_count = array_length(_sector.solids);
				for (var _first_index = 0; _first_index < _solid_count; _first_index += 1) {
					for (var _second_index = _first_index + 1; _second_index < _solid_count; _second_index += 1) {
						expect(fps_sector_rects_overlap(_sector.solids[_first_index], _sector.solids[_second_index])).toBeFalsy();
					}
				}

				var _socket_count = array_length(_sector.sockets);
				for (var _socket_index = 0; _socket_index < _socket_count; _socket_index += 1) {
					var _socket = _sector.sockets[_socket_index];
					expect(fps_sector_position_is_clear(_sector, _socket.x, _socket.y, _socket.radius)).toBeTruthy();
				}

				if (_sample_index > 0 && _sector.layout_signature != _previous_signature) {
					_changed_signatures += 1;
				}
				_previous_signature = _sector.layout_signature;
				_seed = fps_sector_next_seed(_seed);
			}

			expect(_changed_signatures >= 12).toBeTruthy();
			for (var _role_index = 0; _role_index < FPS_SECTOR_TILE_COUNT; _role_index += 1) {
				for (var _variant_index = 0; _variant_index < FPS_SECTOR_TILE_VARIANT_COUNT; _variant_index += 1) {
					expect(_role_variant_seen[_role_index][_variant_index]).toBeTruthy();
				}
			}
		});
	});
});
