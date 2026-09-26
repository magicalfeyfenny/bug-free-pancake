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
	describe("Containment Surge controller integration", function() {
		it("binds HUD state to the active room hazard and clears it on a safe-room transition", function() {
			var _controller = instance_find(obj_fps_controller, 0);
			var _previous_sector = _controller.sector;
			var _previous_sector_seed = _controller.sector_seed;
			var _previous_contract = _controller.run_contract;
			var _previous_phase = _controller.phase;
			var _previous_run_started = _controller.run_started;
			var _previous_x = _controller.x;
			var _previous_y = _controller.y;
			var _previous_health = _controller.current_health;
			var _previous_notice = _controller.pickup_notice;
			var _previous_notice_frames = _controller.pickup_notice_frames;
			var _previous_surge = _controller.containment_surge;
			var _previous_surge_state = _controller.containment_surge_state;
			var _previous_dash = _controller.dash;
			var _sector = fps_sector_generate(13579, 1366, 768, 24, 200);

			expect(_sector.tiles[2].role).toBe(FPS_SECTOR_ROLE_COMBAT);
			expect(_sector.tiles[3].role).toBe(FPS_SECTOR_ROLE_SAFE);

			_controller.sector = _sector;
			_controller.sector_seed = 13579;
			_controller.run_contract = fps_run_begin(13579);
			_controller.run_contract.room_index = 2;
			_controller.run_contract.room_complete = false;
			_controller.sync_run_contract();
			_controller.phase = FPS_STATE_PLAYING;
			_controller.run_started = true;
			_controller.x = _sector.tiles[2].center_x + 200;
			_controller.y = _sector.tiles[2].center_y + 200;
			_controller.configure_containment_surge();

			var _combat_surge = _controller.containment_surge;
			expect(is_struct(_combat_surge)).toBeTruthy();
			expect(_combat_surge.id).toBe("containment-surge-3");
			expect(_controller.containment_surge_state.phase).toBe(FPS_CONTAINMENT_SURGE_IDLE);

			for (var _idle_frame = 0; _idle_frame < FPS_CONTAINMENT_SURGE_IDLE_FRAMES; _idle_frame += 1) {
				_controller.tick_containment_surge();
			}
			expect(_controller.pickup_notice).toBe("CONTAINMENT SURGE // WARNING");
			expect(fps_containment_surge_phase_name(_controller.containment_surge_state.phase)).toBe("WARNING");

			for (var _warning_frame = 0; _warning_frame < FPS_CONTAINMENT_SURGE_WARNING_FRAMES; _warning_frame += 1) {
				_controller.tick_containment_surge();
			}
			expect(_controller.pickup_notice).toBe("CONTAINMENT SURGE // ACTIVE");
			expect(fps_containment_surge_phase_name(_controller.containment_surge_state.phase)).toBe("ACTIVE");
			expect(_controller.current_health).toBe(_previous_health);

			// Reconfiguring the room creates a fresh cycle with the same seeded identity.
			_controller.configure_containment_surge();
			expect(_controller.containment_surge.id).toBe(_combat_surge.id);
			expect(_controller.containment_surge.x).toBe(_combat_surge.x);
			expect(_controller.containment_surge.y).toBe(_combat_surge.y);
			expect(_controller.containment_surge_state.phase).toBe(FPS_CONTAINMENT_SURGE_IDLE);
			expect(_controller.containment_surge_state.cycle_index).toBe(0);

			// Room entry uses this same encounter setup path; non-combat rooms have no HUD field.
			_controller.run_contract.room_index = 3;
			_controller.run_contract.room_complete = false;
			_controller.sync_run_contract();
			_controller.spawn_room_encounter();
			expect(is_struct(_controller.containment_surge)).toBeFalsy();
			expect(is_struct(_controller.containment_surge_state)).toBeFalsy();

			_controller.sector = _previous_sector;
			_controller.sector_seed = _previous_sector_seed;
			_controller.run_contract = _previous_contract;
			_controller.phase = _previous_phase;
			_controller.run_started = _previous_run_started;
			_controller.x = _previous_x;
			_controller.y = _previous_y;
			_controller.current_health = _previous_health;
			_controller.pickup_notice = _previous_notice;
			_controller.pickup_notice_frames = _previous_notice_frames;
			_controller.containment_surge = _previous_surge;
			_controller.containment_surge_state = _previous_surge_state;
			_controller.dash = _previous_dash;
			_controller.sync_run_contract();
		});
	});
});
