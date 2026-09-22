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
	describe("Phase Dash combat mobility", function() {
		it("starts ready, normalizes direction, and blocks damage while phasing", function() {
			var _dash = fps_dash_create_state();
			expect(fps_dash_ready(_dash)).toBeTruthy();
			expect(fps_dash_start(_dash, 3, 4)).toBeTruthy();
			expect(round(point_distance(0, 0, _dash.direction_x, _dash.direction_y) * 1000)).toBe(1000);
			expect(fps_dash_is_active(_dash)).toBeTruthy();
			expect(fps_dash_blocks_damage(_dash)).toBeTruthy();
			var _movement = fps_dash_movement(_dash);
			expect(round(point_distance(0, 0, _movement[0], _movement[1]) * 1000)).toBe(18000);
		});

		it("rejects retriggers, expires, and recharges from a fresh state", function() {
			var _dash = fps_dash_create_state();
			expect(fps_dash_start(_dash, 1, 0)).toBeTruthy();
			expect(fps_dash_start(_dash, 0, 1)).toBeFalsy();
			for (var _active_frame = 0; _active_frame < FPS_DASH_ACTIVE_FRAMES; _active_frame += 1) {
				_dash = fps_dash_tick(_dash);
			}
			expect(fps_dash_is_active(_dash)).toBeFalsy();
			expect(fps_dash_ready(_dash)).toBeFalsy();
			for (var _cooldown_frame = 0; _cooldown_frame < FPS_DASH_COOLDOWN_FRAMES; _cooldown_frame += 1) {
				_dash = fps_dash_tick(_dash);
			}
			expect(fps_dash_ready(_dash)).toBeTruthy();
			expect(fps_dash_start(_dash, 0, 0)).toBeFalsy();
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
	describe("Containment Surge hazard", function() {
		it("places one deterministic clear hazard on each combat tile only", function() {
			var _first = fps_sector_generate(13579, 1366, 768, 24, 200);
			var _repeat = fps_sector_generate(13579, 1366, 768, 24, 200);
			var _combat_count = 0;

			for (var _tile_index = 0; _tile_index < FPS_SECTOR_TILE_COUNT; _tile_index += 1) {
				var _tile = _first.tiles[_tile_index];
				var _surge = fps_sector_containment_surge_for_tile(_first, _tile_index);
				if (_tile.role == FPS_SECTOR_ROLE_COMBAT) {
					_combat_count += 1;
					var _repeat_surge = fps_sector_containment_surge_for_tile(_repeat, _tile_index);
					expect(is_struct(_surge)).toBeTruthy();
					expect(_surge.id).toBe("containment-surge-" + string(_tile_index + 1));
					expect(fps_sector_position_is_clear(_first, _surge.x, _surge.y, _surge.radius)).toBeTruthy();
					expect(_repeat_surge.x).toBe(_surge.x);
					expect(_repeat_surge.y).toBe(_surge.y);
				} else {
					expect(is_struct(_surge)).toBeFalsy();
				}
			}

			expect(_combat_count).toBe(1);
			expect(array_length(_first.containment_surges)).toBe(_combat_count);
		});

		it("cycles on fixed timings and allows one exposed hit per active cycle", function() {
			var _state = fps_containment_surge_create_state("test-surge");
			for (var _idle_frame = 0; _idle_frame < FPS_CONTAINMENT_SURGE_IDLE_FRAMES; _idle_frame += 1) {
				_state = fps_containment_surge_tick(_state);
			}
			expect(_state.phase).toBe(FPS_CONTAINMENT_SURGE_WARNING);

			for (var _warning_frame = 0; _warning_frame < FPS_CONTAINMENT_SURGE_WARNING_FRAMES; _warning_frame += 1) {
				_state = fps_containment_surge_tick(_state);
			}
			expect(_state.phase).toBe(FPS_CONTAINMENT_SURGE_ACTIVE);
			expect(fps_containment_surge_can_damage(_state)).toBeTruthy();
			_state = fps_containment_surge_mark_damaged(_state);
			expect(fps_containment_surge_can_damage(_state)).toBeFalsy();

			for (var _active_frame = 0; _active_frame < FPS_CONTAINMENT_SURGE_ACTIVE_FRAMES; _active_frame += 1) {
				_state = fps_containment_surge_tick(_state);
			}
			expect(_state.phase).toBe(FPS_CONTAINMENT_SURGE_IDLE);
			expect(_state.cycle_index).toBe(1);
			expect(_state.damage_cycle).toBe(-1);

			var _fresh_state = fps_containment_surge_create_state("test-surge");
			expect(_fresh_state.phase).toBe(FPS_CONTAINMENT_SURGE_IDLE);
			expect(_fresh_state.cycle_index).toBe(0);
		});

		it("uses the shared footprint, cover, and Phase Dash protection contracts", function() {
			var _surge = {x: 0, y: 0, radius: 64};
			var _covered_sector = {
				solids: [fps_sector_make_solid(-4, -12, 4, 12, 100, make_color_rgb(40, 40, 40), "test-cover")],
			};
			expect(fps_sector_containment_surge_contains(_surge, 32, 0)).toBeTruthy();
			expect(fps_sector_containment_surge_contains(_surge, 65, 0)).toBeFalsy();
			expect(fps_sector_containment_surge_exposed(_covered_sector, _surge, 24, 0)).toBeFalsy();

			var _dash = fps_dash_create_state();
			expect(fps_dash_start(_dash, 1, 0)).toBeTruthy();
			expect(fps_dash_blocks_damage(_dash)).toBeTruthy();
		});
	});
});

suite(function() {
	describe("Sector HUD route projection", function() {
		it("keeps generated role order and marks current, cleared, and next spaces", function() {
			var _sector = fps_sector_generate(97531, 1366, 768, 24, 200);
			var _route = fps_sector_route_entries(_sector, 2, true);

			expect(array_length(_route)).toBe(FPS_SECTOR_TILE_COUNT);
			for (var _tile_index = 0; _tile_index < FPS_SECTOR_TILE_COUNT; _tile_index += 1) {
				expect(_route[_tile_index].id).toBe(_sector.tiles[_tile_index].id);
				expect(_route[_tile_index].index).toBe(_tile_index);
				expect(_route[_tile_index].role_name).toBe(_sector.tiles[_tile_index].role_name);
			}

			expect(_route[0].is_cleared).toBeTruthy();
			expect(_route[1].is_cleared).toBeTruthy();
			expect(_route[2].is_current).toBeTruthy();
			expect(_route[2].status).toBe("CURRENT");
			expect(_route[3].is_next).toBeTruthy();
			expect(_route[3].status).toBe("NEXT");
			expect(_route[5].is_finale).toBeTruthy();
			expect(_route[5].status).toBe("FINALE");
		});

		it("only exposes the next space after a clear and resets across seeded sectors", function() {
			var _seed = 13579;
			var _sector = fps_sector_generate(_seed, 1366, 768, 24, 200);
			var _blocked_route = fps_sector_route_entries(_sector, 4, false);
			var _cleared_route = fps_sector_route_entries(_sector, 4, true);
			var _repeat_sector = fps_sector_generate(_seed, 1366, 768, 24, 200);
			var _different_sector = fps_sector_generate(24680, 1366, 768, 24, 200);

			expect(_blocked_route[5].is_next).toBeFalsy();
			expect(_blocked_route[5].status).toBe("FINALE");
			expect(_cleared_route[5].is_next).toBeTruthy();
			expect(_cleared_route[5].is_finale).toBeTruthy();
			expect(_cleared_route[5].status).toBe("NEXT / FINALE");
			expect(_repeat_sector.layout_signature).toBe(_sector.layout_signature);
			expect(_different_sector.layout_signature != _sector.layout_signature).toBeTruthy();

			var _reset_route = fps_sector_route_entries(_repeat_sector, 0, false);
			expect(_reset_route[0].is_current).toBeTruthy();
			expect(_reset_route[0].status).toBe("CURRENT");
			expect(_reset_route[1].is_cleared).toBeFalsy();
			expect(_reset_route[1].is_next).toBeFalsy();
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
			expect(_titan.phase_name).toBe("AWAKENING");
			expect(_titan.phase_threshold).toBe(FPS_TITAN_PHASE_TWO_THRESHOLD);
			expect(_titan.phase_two.name).toBe("SIEGE");
			expect(_titan.phase_two.move_speed > _titan.move_speed).toBeTruthy();
			expect(_titan.phase_two.attack_damage > _titan.attack_damage).toBeTruthy();
			expect(_titan.phase_two.telegraph_frames < _titan.telegraph_frames).toBeTruthy();
		});
		it("changes Titan phase once at its threshold and resets through the role contract", function() {
			var _controller = instance_find(obj_fps_controller, 0);
			var _previous_notice = _controller.pickup_notice;
			var _titan = create(0, 0, obj_fps_enemy);
			fps_enemy_apply_role(_titan, FPS_ENEMY_KIND_TITAN);

			expect(_titan.combat_phase).toBe(FPS_TITAN_PHASE_AWAKENING);
			_titan.take_damage(_titan.max_health - _titan.phase_threshold - 1);
			expect(_titan.current_health).toBe(_titan.phase_threshold + 1);

			_titan.take_damage(1);
			expect(_titan.combat_phase).toBe(FPS_TITAN_PHASE_SIEGE);
			expect(_titan.move_speed).toBe(fps_enemy_role_definition(FPS_ENEMY_KIND_TITAN).phase_two.move_speed);
			expect(_titan.collision_radius).toBe(fps_enemy_role_definition(FPS_ENEMY_KIND_TITAN).collision_radius);
			expect(_controller.pickup_notice).toBe("TITAN PHASE SHIFT // SIEGE");
			expect(fps_enemy_update_phase(_titan)).toBeFalsy();

			fps_enemy_apply_role(_titan, FPS_ENEMY_KIND_TITAN);
			expect(_titan.combat_phase).toBe(FPS_TITAN_PHASE_AWAKENING);
			expect(_titan.current_health).toBe(_titan.max_health);

			_controller.pickup_notice = _previous_notice;
			instance_destroy(_titan);
		});

		it("keeps phase changes isolated from non-Titan roles", function() {
			var _enemy = create(0, 0, obj_fps_enemy);
			fps_enemy_apply_role(_enemy, FPS_ENEMY_KIND_CHASER);
			_enemy.take_damage(1);
			expect(_enemy.combat_phase).toBe(FPS_ENEMY_PHASE_NONE);
			instance_destroy(_enemy);
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

suite(function() {
	describe("Replayable run progression", function() {
		it("transitions from a clean run through reward selection and room advance", function() {
			var _state = fps_run_begin(12345);
			expect(_state.phase).toBe(FPS_RUN_PLAYING);
			expect(_state.room_index).toBe(0);
			expect(_state.room_complete).toBeTruthy();

			var _choices = [
				{kind: FPS_RUN_REWARD_REPAIR, label: "REPAIR", description: ""},
				{kind: FPS_RUN_REWARD_AMMO, label: "AMMO", description: ""},
				{kind: FPS_RUN_REWARD_OVERCHARGE, label: "OVERCHARGE", description: ""},
			];
			_state.room_complete = false;
			_state = fps_run_begin_reward(_state, _choices);
			expect(_state.phase).toBe(FPS_RUN_REWARD);
			expect(fps_run_select_reward(_state, 1)).toBeTruthy();
			expect(_state.phase).toBe(FPS_RUN_PLAYING);
			expect(_state.room_complete).toBeTruthy();
			expect(_state.rooms_cleared).toBe(1);
			_state = fps_run_advance_room(_state);
			expect(_state.room_index).toBe(1);
			expect(_state.room_complete).toBeFalsy();
			_state = fps_run_finish(_state, FPS_STATE_VICTORY);
			expect(_state.phase).toBe(FPS_RUN_SUMMARY);
			expect(_state.terminal_phase).toBe(FPS_STATE_VICTORY);
			var _restart = fps_run_begin(_state.seed);
			expect(_restart.phase).toBe(FPS_RUN_PLAYING);
			expect(_restart.room_index).toBe(0);
			expect(_restart.rooms_cleared).toBe(0);
		});

		it("starts at zero and awards each enemy role exactly once", function() {
			var _state = fps_run_begin(12345);
			expect(_state.score).toBe(0);

			var _chaser = fps_run_award_enemy(_state, FPS_ENEMY_KIND_CHASER, "sector-tile-3", "combat-chaser");
			expect(_chaser.awarded).toBeTruthy();
			expect(_chaser.points).toBe(FPS_RUN_SCORE_CHASER);
			var _chaser_repeat = fps_run_award_enemy(_state, FPS_ENEMY_KIND_CHASER, "sector-tile-3", "combat-chaser");
			expect(_chaser_repeat.awarded).toBeFalsy();
			expect(_state.score).toBe(FPS_RUN_SCORE_CHASER);

			var _ranged = fps_run_award_enemy(_state, FPS_ENEMY_KIND_RANGED, "sector-tile-3", "combat-ranged");
			var _burrower = fps_run_award_enemy(_state, FPS_ENEMY_KIND_BURROWER, "sector-tile-4", "combat-burrower");
			var _sentry = fps_run_award_enemy(_state, FPS_ENEMY_KIND_SENTRY, "sector-tile-4", "combat-sentry");
			var _titan = fps_run_award_enemy(_state, FPS_ENEMY_KIND_TITAN, "sector-tile-6", "finale-enemy-2");
			expect(_ranged.points).toBe(FPS_RUN_SCORE_RANGED);
			expect(_burrower.points).toBe(FPS_RUN_SCORE_BURROWER);
			expect(_sentry.points).toBe(FPS_RUN_SCORE_SENTRY);
			expect(_titan.points).toBe(FPS_RUN_SCORE_TITAN);
			expect(_state.score).toBe(
				FPS_RUN_SCORE_CHASER
					+ FPS_RUN_SCORE_RANGED
					+ FPS_RUN_SCORE_BURROWER
					+ FPS_RUN_SCORE_SENTRY
					+ FPS_RUN_SCORE_TITAN
			);
		});

		it("awards room and finale bonuses only once", function() {
			var _state = fps_run_begin(12345);
			var _room = fps_run_award_room(_state, "sector-tile-3", false);
			expect(_room.awarded).toBeTruthy();
			expect(_room.points).toBe(FPS_RUN_SCORE_ROOM_CLEAR);
			var _room_repeat = fps_run_award_room(_state, "sector-tile-3", false);
			expect(_room_repeat.awarded).toBeFalsy();
			expect(_state.score).toBe(FPS_RUN_SCORE_ROOM_CLEAR);

			var _finale = fps_run_award_room(_state, "sector-tile-6", true);
			expect(_finale.awarded).toBeTruthy();
			expect(_finale.points).toBe(FPS_RUN_SCORE_FINALE_CLEAR);
			var _finale_repeat = fps_run_award_room(_state, "sector-tile-6", true);
			expect(_finale_repeat.awarded).toBeFalsy();
			expect(_state.score).toBe(FPS_RUN_SCORE_ROOM_CLEAR + FPS_RUN_SCORE_FINALE_CLEAR);
		});

		it("replays score events and resets score for a restarted seed", function() {
			var _first = fps_run_begin(314159);
			fps_run_award_enemy(_first, FPS_ENEMY_KIND_CHASER, "sector-tile-3", "combat-chaser");
			fps_run_award_enemy(_first, FPS_ENEMY_KIND_TITAN, "sector-tile-6", "finale-enemy-2");
			fps_run_award_room(_first, "sector-tile-3", false);
			fps_run_award_room(_first, "sector-tile-6", true);

			var _repeat = fps_run_begin(314159);
			fps_run_award_enemy(_repeat, FPS_ENEMY_KIND_CHASER, "sector-tile-3", "combat-chaser");
			fps_run_award_enemy(_repeat, FPS_ENEMY_KIND_TITAN, "sector-tile-6", "finale-enemy-2");
			fps_run_award_room(_repeat, "sector-tile-3", false);
			fps_run_award_room(_repeat, "sector-tile-6", true);
			expect(_repeat.score).toBe(_first.score);

			var _restart = fps_run_begin(_first.seed);
			expect(_restart.score).toBe(0);
			expect(array_length(_restart.enemy_score_awards)).toBe(0);
			expect(array_length(_restart.room_score_awards)).toBe(0);
		});

		it("replays room plans and reward choices from the same seed and profile", function() {
			var _profile = fps_profile_defaults();
			var _sector = fps_sector_generate(314159, 1366, 768, 24, 200);
			var _combat_index = 0;
			for (var _tile_index = 0; _tile_index < FPS_SECTOR_TILE_COUNT; _tile_index += 1) {
				if (_sector.tiles[_tile_index].role == FPS_SECTOR_ROLE_COMBAT) {
					_combat_index = _tile_index;
				}
			}
			var _first_plan = fps_run_create_room_plan(_sector, 314159, _combat_index, 2);
			var _repeat_plan = fps_run_create_room_plan(_sector, 314159, _combat_index, 2);
			var _different_plan = fps_run_create_room_plan(_sector, 271828, _combat_index, 2);
			expect(_first_plan.signature).toBe(_repeat_plan.signature);
			expect(_first_plan.signature != _different_plan.signature).toBeTruthy();

			var _first_choices = fps_run_create_reward_choices(314159, 2, _profile);
			var _repeat_choices = fps_run_create_reward_choices(314159, 2, _profile);
			expect(fps_run_reward_signature(_first_choices)).toBe(fps_run_reward_signature(_repeat_choices));
			expect(array_length(_first_choices)).toBe(FPS_RUN_REWARD_LIMIT);
		});

		it("escalates the finale and reserves its durable threat", function() {
			var _sector = fps_sector_generate(97531, 1366, 768, 24, 200);
			var _pressure = fps_run_room_pressure(_sector, FPS_SECTOR_TILE_COUNT - 1, 97531);
			var _plan = fps_run_create_room_plan(_sector, 97531, FPS_SECTOR_TILE_COUNT - 1, _pressure);
			expect(_pressure).toBe(3);
			expect(array_length(_plan.entries) > 0).toBeTruthy();
			expect(_plan.entries[array_length(_plan.entries) - 1].kind).toBe(FPS_ENEMY_KIND_TITAN);
			var _terminal = fps_run_finish(fps_run_begin(97531), FPS_STATE_VICTORY);
			expect(_terminal.phase).toBe(FPS_RUN_SUMMARY);
		});

		it("carries reward effects into the next encounter without sharing fresh-loadout state", function() {
			var _loadout = fps_weapon_create_loadout();
			var _profile = fps_profile_defaults();
			var _repair = fps_run_apply_reward(
				{kind: FPS_RUN_REWARD_REPAIR},
				_loadout,
				40,
				100,
				_profile
			);
			expect(_repair.health).toBe(75);
			var _overcharge = fps_run_apply_reward(
				{kind: FPS_RUN_REWARD_OVERCHARGE},
				_loadout,
				_repair.health,
				_repair.max_health,
				_profile
			);
			expect(_loadout.overcharge_frames).toBe(FPS_WEAPON_OVERCHARGE_GAIN);
			expect(fps_weapon_owned_count(fps_weapon_create_loadout())).toBe(1);
		});
	});
});

suite(function() {
	describe("Run pause contract", function() {
		it("freezes simulation state and restores it on resume", function() {
			var _state = fps_run_begin(314159);
			_state.room_index = 3;
			_state.rooms_cleared = 2;
			_state.room_complete = false;
			expect(fps_run_simulation_active(_state)).toBeTruthy();

			expect(fps_run_pause(_state)).toBeTruthy();
			expect(_state.phase).toBe(FPS_RUN_PAUSED);
			expect(fps_run_simulation_active(_state)).toBeFalsy();
			expect(_state.seed).toBe(314159);
			expect(_state.room_index).toBe(3);
			expect(_state.rooms_cleared).toBe(2);
			expect(_state.room_complete).toBeFalsy();
			expect(fps_run_pause(_state)).toBeFalsy();

			expect(fps_run_resume(_state)).toBeTruthy();
			expect(_state.phase).toBe(FPS_RUN_PLAYING);
			expect(fps_run_simulation_active(_state)).toBeTruthy();
			expect(_state.room_index).toBe(3);
			expect(_state.rooms_cleared).toBe(2);
		});

		it("rejects pause transitions outside active gameplay", function() {
			var _title = fps_run_create_state(12345);
			expect(fps_run_pause(_title)).toBeFalsy();
			expect(fps_run_resume(_title)).toBeFalsy();

			var _summary = fps_run_finish(fps_run_begin(12345), FPS_STATE_VICTORY);
			expect(fps_run_pause(_summary)).toBeFalsy();
			expect(fps_run_resume(_summary)).toBeFalsy();

			var _restart = fps_run_begin(_summary.seed);
			expect(_restart.phase).toBe(FPS_RUN_PLAYING);
			expect(fps_run_simulation_active(_restart)).toBeTruthy();
		});

		it("syncs the controller pause gate without changing terminal state", function() {
			var _controller = instance_find(obj_fps_controller, 0);
			var _previous_contract = _controller.run_contract;
			var _previous_phase = _controller.phase;
			var _previous_run_started = _controller.run_started;
			var _previous_mouse_captured = _controller.mouse_captured;

			_controller.run_contract = fps_run_begin(24680);
			_controller.phase = FPS_STATE_PLAYING;
			_controller.run_started = true;
			_controller.sync_run_contract();
			expect(_controller.pause_run()).toBeTruthy();
			expect(_controller.run_state).toBe(FPS_RUN_PAUSED);
			expect(global.fps_run_paused).toBeTruthy();
			expect(_controller.phase).toBe(FPS_STATE_PLAYING);
			expect(_controller.resume_run()).toBeTruthy();
			expect(_controller.run_state).toBe(FPS_RUN_PLAYING);
			expect(global.fps_run_paused).toBeFalsy();

			_controller.run_contract = _previous_contract;
			_controller.phase = _previous_phase;
			_controller.run_started = _previous_run_started;
			_controller.sync_run_contract();
			_controller.set_mouse_capture(_previous_mouse_captured);
		});
	});
});

suite(function() {
	describe("Run score controller integration", function() {
		it("keeps score in the controller's run contract", function() {
			var _controller = instance_find(obj_fps_controller, 0);
			var _previous_contract = _controller.run_contract;
			var _previous_phase = _controller.phase;
			var _previous_run_started = _controller.run_started;
			var _previous_mouse_captured = _controller.mouse_captured;

			_controller.run_contract = fps_run_begin(24680);
			_controller.run_contract.room_index = 2;
			_controller.run_contract.room_complete = false;
			_controller.phase = FPS_STATE_PLAYING;
			_controller.run_started = true;
			_controller.sync_run_contract();
			expect(_controller.award_room_score(false)).toBeTruthy();
			expect(_controller.run_contract.score).toBe(FPS_RUN_SCORE_ROOM_CLEAR);
			expect(_controller.run_contract.rooms_cleared).toBe(0);
			expect(_controller.run_contract.terminal_phase).toBe(FPS_STATE_PLAYING);

			_controller.run_contract = _previous_contract;
			_controller.phase = _previous_phase;
			_controller.run_started = _previous_run_started;
			_controller.sync_run_contract();
			_controller.set_mouse_capture(_previous_mouse_captured);
		});
	});
});
