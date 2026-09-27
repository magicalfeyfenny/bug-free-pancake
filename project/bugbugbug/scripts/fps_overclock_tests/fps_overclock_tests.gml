suite(function() {
	describe("Overclock run contract", function() {
		it("defaults to Standard and keeps the selected protocol through reset and summary", function() {
			var _title = fps_run_create_state(314159);
			expect(_title.protocol).toBe(FPS_RUN_PROTOCOL_STANDARD);
			expect(fps_run_protocol_name(_title.protocol)).toBe("STANDARD");
			expect(fps_run_create_state(314159, -1).protocol).toBe(FPS_RUN_PROTOCOL_STANDARD);

			var _run = fps_run_begin(314159, FPS_RUN_PROTOCOL_OVERCLOCK);
			expect(_run.protocol).toBe(FPS_RUN_PROTOCOL_OVERCLOCK);
			var _summary = fps_run_finish(_run, FPS_STATE_DEAD);
			expect(_summary.protocol).toBe(FPS_RUN_PROTOCOL_OVERCLOCK);
			expect(fps_run_protocol_name(_summary.protocol)).toBe("OVERCLOCK");

			var _restart = fps_run_begin(_summary.seed, _summary.protocol);
			expect(_restart.protocol).toBe(FPS_RUN_PROTOCOL_OVERCLOCK);
			expect(_restart.score).toBe(0);
			expect(array_length(_restart.enemy_score_awards)).toBe(0);
			expect(array_length(_restart.room_score_awards)).toBe(0);
		});

		it("keeps generated layout, encounter, pickup, and reward signatures independent of protocol", function() {
			var _profile = fps_profile_defaults();
			var _sector = fps_sector_generate(314159, 1366, 768, 24, 200);
			var _combat_index = -1;
			for (var _tile_index = 0; _tile_index < FPS_SECTOR_TILE_COUNT; _tile_index += 1) {
				if (_sector.tiles[_tile_index].role == FPS_SECTOR_ROLE_COMBAT) {
					_combat_index = _tile_index;
					break;
				}
			}

			var _standard = fps_run_begin(314159, FPS_RUN_PROTOCOL_STANDARD);
			var _overclock = fps_run_begin(314159, FPS_RUN_PROTOCOL_OVERCLOCK);
			var _standard_plan = fps_run_create_room_plan(_sector, _standard.seed, _combat_index, 2);
			var _overclock_plan = fps_run_create_room_plan(_sector, _overclock.seed, _combat_index, 2);
			expect(_overclock_plan.signature).toBe(_standard_plan.signature);

			var _standard_pickups = fps_weapon_create_pickups(_sector, _standard.seed);
			var _overclock_pickups = fps_weapon_create_pickups(_sector, _overclock.seed);
			expect(fps_weapon_pickup_signature(_overclock_pickups)).toBe(
				fps_weapon_pickup_signature(_standard_pickups)
			);

			var _standard_choices = fps_run_create_reward_choices(_standard.seed, _combat_index, _profile);
			var _overclock_choices = fps_run_create_reward_choices(_overclock.seed, _combat_index, _profile);
			expect(fps_run_reward_signature(_overclock_choices)).toBe(
				fps_run_reward_signature(_standard_choices)
			);
		});

		it("uses exact whole-frame 80 percent attack delays with a one-frame minimum", function() {
			var _base_delays = [45, 30, 78, 84, 110];
			var _expected_delays = [36, 24, 62, 67, 88];
			for (var _index = 0; _index < array_length(_base_delays); _index += 1) {
				expect(fps_enemy_attack_delay_for_protocol(
					_base_delays[_index],
					FPS_RUN_PROTOCOL_STANDARD
				)).toBe(_base_delays[_index]);
				expect(fps_enemy_attack_delay_for_protocol(
					_base_delays[_index],
					FPS_RUN_PROTOCOL_OVERCLOCK
				)).toBe(_expected_delays[_index]);
			}
			expect(fps_enemy_attack_delay_for_protocol(1, FPS_RUN_PROTOCOL_OVERCLOCK)).toBe(1);
		});

		it("applies run timing to every role and the Titan Siege phase", function() {
			var _expected_delays = [36, 24, 62, 67, 88];
			var _enemy = instance_create_layer(0, 0, "Gameplay", obj_fps_enemy);
			for (var _kind = 0; _kind < FPS_ENEMY_KIND_COUNT; _kind += 1) {
				fps_enemy_apply_role(_enemy, _kind, FPS_RUN_PROTOCOL_OVERCLOCK);
				expect(_enemy.run_protocol).toBe(FPS_RUN_PROTOCOL_OVERCLOCK);
				expect(_enemy.attack_delay).toBe(_expected_delays[_kind]);
				expect(_enemy.attack_cooldown).toBe(_expected_delays[_kind]);
			}

			expect(fps_enemy_apply_combat_phase(_enemy, FPS_TITAN_PHASE_SIEGE)).toBeTruthy();
			expect(_enemy.attack_delay).toBe(70);
			instance_destroy(_enemy);
		});

		it("multiplies enemy and room awards exactly and keeps duplicate awards idempotent", function() {
			var _standard = fps_run_begin(12345);
			var _standard_enemy = fps_run_award_enemy(
				_standard,
				FPS_ENEMY_KIND_RANGED,
				"standard-room",
				"standard-ranged"
			);
			expect(_standard_enemy.points).toBe(FPS_RUN_SCORE_RANGED);

			var _overclock = fps_run_begin(12345, FPS_RUN_PROTOCOL_OVERCLOCK);
			var _expected_scores = [150, 187.5, 225, 262.5, 750];
			for (var _kind = 0; _kind < FPS_ENEMY_KIND_COUNT; _kind += 1) {
				var _award = fps_run_award_enemy(
					_overclock,
					_kind,
					"room-a",
					"enemy-" + string(_kind)
				);
				expect(_award.points).toBe(_expected_scores[_kind]);
			}
			var _duplicate = fps_run_award_enemy(_overclock, FPS_ENEMY_KIND_RANGED, "room-a", "enemy-1");
			expect(_duplicate.awarded).toBeFalsy();
			expect(_duplicate.points).toBe(0);

			var _room = fps_run_award_room(_overclock, "room-a", false);
			var _finale = fps_run_award_room(_overclock, "finale", true);
			expect(_room.points).toBe(375);
			expect(_finale.points).toBe(1500);
			expect(_overclock.score).toBe(3450);

			var _repeat = fps_run_begin(12345, FPS_RUN_PROTOCOL_OVERCLOCK);
			for (var _repeat_kind = 0; _repeat_kind < FPS_ENEMY_KIND_COUNT; _repeat_kind += 1) {
				fps_run_award_enemy(
					_repeat,
					_repeat_kind,
					"room-a",
					"enemy-" + string(_repeat_kind)
				);
			}
			fps_run_award_room(_repeat, "room-a", false);
			fps_run_award_room(_repeat, "finale", true);
			expect(_repeat.score).toBe(_overclock.score);

			var _restart = fps_run_begin(_overclock.seed, _overclock.protocol);
			expect(_restart.score).toBe(0);
			expect(_restart.protocol).toBe(FPS_RUN_PROTOCOL_OVERCLOCK);
		});
	});
});

suite(function() {
	describe("Overclock controller integration", function() {
		it("selects either title protocol and carries it through active and terminal run state", function() {
			var _controller = instance_find(obj_fps_controller, 0);
			var _previous_contract = _controller.run_contract;
			var _previous_protocol = _controller.title_protocol;
			_controller.run_contract = fps_run_create_state(24680, FPS_RUN_PROTOCOL_STANDARD);
			_controller.sync_run_contract();

			expect(_controller.select_title_protocol(FPS_RUN_PROTOCOL_OVERCLOCK)).toBeTruthy();
			expect(_controller.title_protocol).toBe(FPS_RUN_PROTOCOL_OVERCLOCK);
			expect(_controller.run_contract.protocol).toBe(FPS_RUN_PROTOCOL_OVERCLOCK);
			expect(_controller.select_title_protocol(FPS_RUN_PROTOCOL_STANDARD)).toBeTruthy();
			expect(_controller.run_contract.protocol).toBe(FPS_RUN_PROTOCOL_STANDARD);
			expect(_controller.select_title_protocol(FPS_RUN_PROTOCOL_OVERCLOCK)).toBeTruthy();

			_controller.run_contract = fps_run_begin(
				_controller.run_contract.seed,
				_controller.title_protocol
			);
			_controller.sync_run_contract();
			expect(_controller.run_state).toBe(FPS_RUN_PLAYING);
			expect(_controller.run_contract.protocol).toBe(FPS_RUN_PROTOCOL_OVERCLOCK);

			_controller.run_contract = fps_run_finish(_controller.run_contract, FPS_STATE_DEAD);
			_controller.sync_run_contract();
			expect(_controller.run_state).toBe(FPS_RUN_SUMMARY);
			expect(fps_run_protocol_name(_controller.run_contract.protocol)).toBe("OVERCLOCK");
			expect(_controller.select_title_protocol(FPS_RUN_PROTOCOL_STANDARD)).toBeFalsy();
			expect(_controller.run_contract.protocol).toBe(FPS_RUN_PROTOCOL_OVERCLOCK);

			_controller.run_contract = _previous_contract;
			_controller.title_protocol = _previous_protocol;
			_controller.sync_run_contract();
		});
	});
});
