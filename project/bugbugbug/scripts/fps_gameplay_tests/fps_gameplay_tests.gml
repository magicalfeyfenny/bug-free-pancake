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
	describe("Weapon arsenal and pickup economy", function() {
		it("defines four materially different usable weapon contracts", function() {
			var _pulse = fps_weapon_definition(FPS_WEAPON_PULSE);
			var _scatter = fps_weapon_definition(FPS_WEAPON_SCATTER);
			var _burst = fps_weapon_definition(FPS_WEAPON_BURST);
			var _rail = fps_weapon_definition(FPS_WEAPON_RAIL);
			expect(_pulse.pellets).toBe(1);
			expect(_scatter.pellets).toBe(5);
			expect(_burst.pellets).toBe(3);
			expect(_rail.range > _pulse.range).toBeTruthy();
			expect(_scatter.fire_delay > _pulse.fire_delay).toBeTruthy();
			expect(_burst.identity != _scatter.identity).toBeTruthy();
		});

		it("starts clean, locks unacquired weapons, and switches after acquisition", function() {
			var _loadout = fps_weapon_create_loadout();
			expect(fps_weapon_owned_count(_loadout)).toBe(1);
			expect(fps_weapon_switch(_loadout, FPS_WEAPON_SCATTER)).toBeFalsy();

			var _pickup = {kind: FPS_PICKUP_WEAPON, weapon_id: FPS_WEAPON_SCATTER, collected: false};
			var _result = fps_weapon_collect_pickup(_loadout, _pickup, 100, 100);
			expect(_result.consumed).toBeTruthy();
			expect(fps_weapon_switch(_loadout, FPS_WEAPON_SCATTER)).toBeTruthy();
			expect(fps_weapon_current_definition(_loadout).id).toBe(FPS_WEAPON_SCATTER);
			expect(fps_weapon_owned_count(_loadout)).toBe(2);
		});

		it("consumes rounds, reloads from reserve, and exposes empty state", function() {
			var _loadout = fps_weapon_create_loadout();
			var _shot = fps_weapon_start_shot(_loadout);
			expect(_shot.fired).toBeTruthy();
			expect(_loadout.states[FPS_WEAPON_PULSE].magazine).toBe(11);
			_loadout.states[FPS_WEAPON_PULSE].magazine = 0;
			_loadout.states[FPS_WEAPON_PULSE].reserve = 5;
			var _reload = fps_weapon_reload(_loadout);
			expect(_reload.reloaded).toBeTruthy();
			expect(_reload.moved).toBe(5);
			_loadout.states[FPS_WEAPON_PULSE].magazine = 0;
			_loadout.states[FPS_WEAPON_PULSE].reserve = 0;
			var _empty = fps_weapon_start_shot(_loadout);
			expect(_empty.fired).toBeFalsy();
			expect(_empty.reason).toBe("EMPTY");
		});

		it("retains unusable pickups and applies health, ammo, and overcharge when useful", function() {
			var _loadout = fps_weapon_create_loadout();
			var _health = fps_weapon_apply_health_pickup(100, 100);
			expect(_health.consumed).toBeFalsy();
			_health = fps_weapon_apply_health_pickup(40, 100);
			expect(_health.consumed).toBeTruthy();
			expect(_health.health).toBe(75);

			var _ammo_pickup = {kind: FPS_PICKUP_AMMO, weapon_id: -1, collected: false};
			var _ammo_result = fps_weapon_collect_pickup(_loadout, _ammo_pickup, 100, 100);
			expect(_ammo_result.consumed).toBeFalsy();
			_loadout.states[FPS_WEAPON_PULSE].reserve = 0;
			_ammo_result = fps_weapon_collect_pickup(_loadout, _ammo_pickup, 100, 100);
			expect(_ammo_result.consumed).toBeTruthy();
			expect(_loadout.states[FPS_WEAPON_PULSE].reserve).toBe(FPS_WEAPON_AMMO_PICKUP);

			var _overcharge = {kind: FPS_PICKUP_OVERCHARGE, weapon_id: -1, collected: false};
			var _overcharge_result = fps_weapon_collect_pickup(_loadout, _overcharge, 100, 100);
			expect(_overcharge_result.consumed).toBeTruthy();
			var _charged_shot = fps_weapon_start_shot(_loadout);
			expect(_charged_shot.damage).toBe(51);
		});

		it("reproduces seeded cache rewards and clears inventory on a fresh loadout", function() {
			var _sector = fps_sector_generate(314159, 1366, 768, 24, 200);
			var _first = fps_weapon_create_pickups(_sector, 314159);
			var _repeat = fps_weapon_create_pickups(_sector, 314159);
			var _different = fps_weapon_create_pickups(_sector, 271828);
			expect(fps_weapon_pickup_signature(_first)).toBe(fps_weapon_pickup_signature(_repeat));
			expect(fps_weapon_pickup_signature(_first) != fps_weapon_pickup_signature(_different)).toBeTruthy();
			expect(array_length(_first)).toBe(FPS_SECTOR_TILE_COUNT);
			var _weapon_kinds = 0;
			var _health_kinds = 0;
			var _ammo_kinds = 0;
			var _overcharge_kinds = 0;
			for (var _pickup_index = 0; _pickup_index < array_length(_first); _pickup_index += 1) {
				var _pickup = _first[_pickup_index];
				expect(fps_sector_position_is_clear(_sector, _pickup.x, _pickup.y, 18)).toBeTruthy();
				if (_pickup.kind == FPS_PICKUP_WEAPON) _weapon_kinds += 1;
				if (_pickup.kind == FPS_PICKUP_HEALTH) _health_kinds += 1;
				if (_pickup.kind == FPS_PICKUP_AMMO) _ammo_kinds += 1;
				if (_pickup.kind == FPS_PICKUP_OVERCHARGE) _overcharge_kinds += 1;
			}
			expect(_weapon_kinds).toBe(3);
			expect(_health_kinds).toBe(1);
			expect(_ammo_kinds).toBe(1);
			expect(_overcharge_kinds).toBe(1);

			var _loadout = fps_weapon_create_loadout();
			_loadout.states[FPS_WEAPON_SCATTER].owned = true;
			_loadout.current_index = FPS_WEAPON_SCATTER;
			var _fresh = fps_weapon_create_loadout();
			expect(_fresh.current_index).toBe(FPS_WEAPON_PULSE);
			expect(fps_weapon_owned_count(_fresh)).toBe(1);
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
				expect(fps_sector_position_is_clear(_sector, _socket.x, _socket.y, 54)).toBeTruthy();
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

suite(function() {
	describe("Seeded enemy roster and encounter director", function() {
		it("defines distinct readable roles including a durable finale threat", function() {
			var _burrower = fps_enemy_role_definition(FPS_ENEMY_KIND_BURROWER);
			var _sentry = fps_enemy_role_definition(FPS_ENEMY_KIND_SENTRY);
			var _titan = fps_enemy_role_definition(FPS_ENEMY_KIND_TITAN);
			expect(_burrower.identity).toBe("burrower");
			expect(_sentry.identity).toBe("sentry");
			expect(_titan.identity).toBe("titan");
			expect(_burrower.move_speed > _sentry.move_speed).toBeTruthy();
			expect(_sentry.warning_shape).toBe(FPS_ENEMY_WARNING_BEAM);
			expect(_titan.max_health > FPS_ENEMY_MAX_HEALTH * 3).toBeTruthy();
			expect(_titan.telegraph_frames > _burrower.telegraph_frames).toBeTruthy();
		});

		it("replays mixed compositions from seed and pressure", function() {
			var _sector = fps_sector_generate(314159, 1366, 768, 24, 200);
			var _first = fps_enemy_create_encounter_plan(_sector, 314159, 2);
			var _repeat = fps_enemy_create_encounter_plan(_sector, 314159, 2);
			var _different = fps_enemy_create_encounter_plan(_sector, 271828, 2);
			expect(_first.signature).toBe(_repeat.signature);
			expect(_first.signature != _different.signature).toBeTruthy();
			expect(array_length(_first.entries)).toBe(4);

			var _roles_seen = array_create(FPS_ENEMY_KIND_COUNT, false);
			for (var _seed_index = 0; _seed_index < 24; _seed_index += 1) {
				var _sample = fps_enemy_create_encounter_plan(_sector, 7001 + _seed_index * 97, _seed_index mod 4);
				for (var _entry_index = 0; _entry_index < array_length(_sample.entries); _entry_index += 1) {
					_roles_seen[_sample.entries[_entry_index].kind] = true;
				}
			}
			expect(_roles_seen[FPS_ENEMY_KIND_BURROWER]).toBeTruthy();
			expect(_roles_seen[FPS_ENEMY_KIND_SENTRY]).toBeTruthy();
			expect(_roles_seen[FPS_ENEMY_KIND_TITAN]).toBeTruthy();
		});

		it("uses clear canonical sockets outside protected player start", function() {
			var _sector = fps_sector_generate(97531, 1366, 768, 24, 200);
			expect(array_length(_sector.combat_sockets) >= 4).toBeTruthy();
			for (var _socket_index = 0; _socket_index < array_length(_sector.combat_sockets); _socket_index += 1) {
				var _socket = _sector.combat_sockets[_socket_index];
				expect(_socket.kind).toBe("enemy");
				expect(fps_sector_position_is_clear(_sector, _socket.x, _socket.y, _socket.radius)).toBeTruthy();
				expect(point_distance(_socket.x, _socket.y, _sector.start_socket.x, _sector.start_socket.y) > _socket.radius + _sector.start_socket.radius).toBeTruthy();
			}
		});

		it("keeps telegraphed attacks cover-aware", function() {
			var _burrower = fps_enemy_role_definition(FPS_ENEMY_KIND_BURROWER);
			var _sentry = fps_enemy_role_definition(FPS_ENEMY_KIND_SENTRY);
			var _titan = fps_enemy_role_definition(FPS_ENEMY_KIND_TITAN);
			expect(_burrower.warning_radius > 0).toBeTruthy();
			expect(_sentry.projectile_speed > 0).toBeTruthy();
			expect(_titan.warning_radius > _burrower.warning_radius).toBeTruthy();
			expect(_sentry.warning_shape).toBe(FPS_ENEMY_WARNING_BEAM);
		});
	});
});
