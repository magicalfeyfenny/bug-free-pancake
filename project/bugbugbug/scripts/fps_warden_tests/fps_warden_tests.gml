suite(function() {
	describe("Barrier Warden role", function() {
		it("defines a stable, seeded role with a readable guarded attack", function() {
			var _warden = fps_enemy_role_definition(FPS_ENEMY_KIND_WARDEN);
			expect(_warden.identity).toBe("warden");
			expect(_warden.label).toBe("WARDEN");
			expect(_warden.barrier_up_frames > 0).toBeTruthy();
			expect(_warden.barrier_open_frames > 0).toBeTruthy();
			expect(_warden.barrier_arc_half_angle * 2).toBe(120);
			expect(_warden.warning_shape).toBe(FPS_ENEMY_WARNING_AREA);
			expect(_warden.telegraph_frames > 0).toBeTruthy();
			expect(fps_run_enemy_score(FPS_ENEMY_KIND_WARDEN)).toBe(FPS_RUN_SCORE_WARDEN);
		});

		it("turns toward the player at a bounded rate and resets its barrier state", function() {
			var _warden = create(0, 0, obj_fps_enemy);
			fps_enemy_apply_role(_warden, FPS_ENEMY_KIND_WARDEN);
			var _player = {x: 0, y: 100};

			expect(_warden.warden_barrier_state).toBe(FPS_WARDEN_BARRIER_UP);
			expect(_warden.warden_barrier_frames_remaining).toBe(
				fps_enemy_role_definition(FPS_ENEMY_KIND_WARDEN).barrier_up_frames
			);
			expect(_warden.combat_phase_name).toBe("BARRIER UP");
			expect(fps_enemy_turn_warden(_warden, _player)).toBeTruthy();
			expect(_warden.warden_facing_angle).toBe(_warden.warden_barrier_turn_speed);

			_warden.warden_barrier_state = FPS_WARDEN_BARRIER_OPEN;
			_warden.warden_facing_angle = 180;
			fps_enemy_apply_role(_warden, FPS_ENEMY_KIND_WARDEN);
			expect(_warden.warden_barrier_state).toBe(FPS_WARDEN_BARRIER_UP);
			expect(_warden.warden_barrier_frames_remaining).toBe(
				fps_enemy_role_definition(FPS_ENEMY_KIND_WARDEN).barrier_up_frames
			);
			expect(_warden.warden_facing_angle).toBe(0);
			instance_destroy(_warden);
		});

		it("holds each barrier state for its exact fixed frame duration", function() {
			var _warden = create(0, 0, obj_fps_enemy);
			var _definition = fps_enemy_role_definition(FPS_ENEMY_KIND_WARDEN);
			fps_enemy_apply_role(_warden, FPS_ENEMY_KIND_WARDEN);

			for (var _frame = 0; _frame < _definition.barrier_up_frames - 1; _frame += 1) {
				fps_enemy_update_warden_barrier(_warden);
			}
			expect(_warden.warden_barrier_state).toBe(FPS_WARDEN_BARRIER_UP);
			expect(_warden.warden_barrier_frames_remaining).toBe(1);
			expect(fps_enemy_update_warden_barrier(_warden)).toBeTruthy();
			expect(_warden.warden_barrier_state).toBe(FPS_WARDEN_BARRIER_OPEN);
			expect(_warden.combat_phase_name).toBe("BARRIER OPEN");

			for (var _open_frame = 0; _open_frame < _definition.barrier_open_frames - 1; _open_frame += 1) {
				fps_enemy_update_warden_barrier(_warden);
			}
			expect(_warden.warden_barrier_state).toBe(FPS_WARDEN_BARRIER_OPEN);
			expect(_warden.warden_barrier_frames_remaining).toBe(1);
			expect(fps_enemy_update_warden_barrier(_warden)).toBeTruthy();
			expect(_warden.warden_barrier_state).toBe(FPS_WARDEN_BARRIER_UP);
			instance_destroy(_warden);
		});

		it("blocks the frontal 120-degree arc only while the barrier is up", function() {
			var _warden = create(0, 0, obj_fps_enemy);
			fps_enemy_apply_role(_warden, FPS_ENEMY_KIND_WARDEN);
			_warden.warden_facing_angle = 0;

			var _front_x = lengthdir_x(100, 0);
			var _front_y = lengthdir_y(100, 0);
			var _edge_x = lengthdir_x(100, 60);
			var _edge_y = lengthdir_y(100, 60);
			var _flank_x = lengthdir_x(100, 61);
			var _flank_y = lengthdir_y(100, 61);
			expect(fps_enemy_weapon_hit_blocked(_warden, _front_x, _front_y)).toBeTruthy();
			expect(fps_enemy_weapon_hit_blocked(_warden, _edge_x, _edge_y)).toBeTruthy();
			expect(fps_enemy_weapon_hit_blocked(_warden, _flank_x, _flank_y)).toBeFalsy();
			expect(fps_enemy_weapon_hit_blocked(_warden, -100, 0)).toBeFalsy();

			_warden.warden_barrier_state = FPS_WARDEN_BARRIER_OPEN;
			expect(fps_enemy_weapon_hit_blocked(_warden, _front_x, _front_y)).toBeFalsy();
			instance_destroy(_warden);
		});

		it("resolves its close strike through the shared warning and cover path", function() {
			var _sector = fps_sector_generate(9182, 1366, 768, 24, 200);
			var _player = {
				x: _sector.start_socket.x,
				y: _sector.start_socket.y,
				sector: _sector,
				damage_received: 0,
			};
		_player.take_damage = method(_player, function(_amount) {
			damage_received += _amount;
		});

			var _warden = create(_player.x + 100, _player.y, obj_fps_enemy);
			fps_enemy_apply_role(_warden, FPS_ENEMY_KIND_WARDEN);
			_warden.attack_cooldown = 0;
			expect(fps_sector_line_blocked(_sector, _warden.x, _warden.y, _player.x, _player.y)).toBeFalsy();
			fps_enemy_step_warden(_warden, _player);
			expect(_warden.telegraph_frames).toBe(_warden.telegraph_max_frames);
			fps_enemy_resolve_telegraph(_warden, _player);
			expect(_player.damage_received).toBe(_warden.attack_damage);

			_player.damage_received = 0;
			_player.x = _warden.x + _warden.warning_radius + 1;
			fps_enemy_resolve_telegraph(_warden, _player);
			expect(_player.damage_received).toBe(0);
			instance_destroy(_warden);
		});

		it("keeps barrier damage rules out of every other role and awards one score", function() {
			for (var _kind = 0; _kind < FPS_ENEMY_KIND_COUNT; _kind += 1) {
				if (_kind == FPS_ENEMY_KIND_WARDEN) {
					continue;
				}
				var _enemy = create(0, 0, obj_fps_enemy);
				fps_enemy_apply_role(_enemy, _kind);
				expect(fps_enemy_update_warden_barrier(_enemy)).toBeFalsy();
				expect(fps_enemy_weapon_hit_blocked(_enemy, 100, 0)).toBeFalsy();
				instance_destroy(_enemy);
			}

			var _run = fps_run_begin(7123);
			var _award = fps_run_award_enemy(_run, FPS_ENEMY_KIND_WARDEN, "combat-2", "warden-1");
			var _repeat = fps_run_award_enemy(_run, FPS_ENEMY_KIND_WARDEN, "combat-2", "warden-1");
			expect(_award.awarded).toBeTruthy();
			expect(_award.points).toBe(FPS_RUN_SCORE_WARDEN);
			expect(_repeat.awarded).toBeFalsy();
			expect(_run.score).toBe(FPS_RUN_SCORE_WARDEN);
		});
	});
});

suite(function() {
	describe("Seeded Warden encounter integration", function() {
		it("repeats room roles, permits Warden in combat, and reserves Titan for the finale", function() {
			var _sector = fps_sector_generate(314159, 1366, 768, 24, 200);
			var _combat_index = -1;
			for (var _tile_index = 0; _tile_index < FPS_SECTOR_TILE_COUNT; _tile_index += 1) {
				if (_sector.tiles[_tile_index].role == FPS_SECTOR_ROLE_COMBAT) {
					_combat_index = _tile_index;
					break;
				}
			}
			expect(_combat_index >= 0).toBeTruthy();

			var _warden_seen = false;
			for (var _seed_index = 0; _seed_index < 64; _seed_index += 1) {
				var _seed = 7001 + _seed_index * 97;
				var _first = fps_run_create_room_plan(_sector, _seed, _combat_index, 2);
				var _repeat = fps_run_create_room_plan(_sector, _seed, _combat_index, 2);
				expect(_first.signature).toBe(_repeat.signature);
				for (var _entry_index = 0; _entry_index < array_length(_first.entries); _entry_index += 1) {
					var _entry = _first.entries[_entry_index];
					expect(_entry.kind == FPS_ENEMY_KIND_TITAN).toBeFalsy();
					if (_entry.kind == FPS_ENEMY_KIND_WARDEN) {
						_warden_seen = true;
						expect(_entry.identity).toBe("warden");
					}
				}

				var _finale = fps_run_create_room_plan(
					_sector,
					_seed,
					FPS_SECTOR_TILE_COUNT - 1,
					3
				);
				expect(_finale.entries[array_length(_finale.entries) - 1].kind).toBe(FPS_ENEMY_KIND_TITAN);
			}
			expect(_warden_seen).toBeTruthy();
		});
	});
});
