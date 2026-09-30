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
		it("binds HUD state to the active hazard and clears it on safe-room and run-reset transitions", function() {
			var _controller = instance_find(obj_fps_controller, 0);
			var _previous_sector = _controller.sector;
			var _previous_global_sector = global.fps_sector;
			var _previous_sector_seed = _controller.sector_seed;
			var _previous_contract = _controller.run_contract;
			var _previous_phase = _controller.phase;
			var _previous_run_started = _controller.run_started;
			var _previous_profile = fps_profile_from_data(
				fps_profile_to_data(_controller.profile)
			);
			var _previous_max_health = _controller.max_health;
			var _previous_x = _controller.x;
			var _previous_y = _controller.y;
			var _previous_health = _controller.current_health;
			var _previous_mouse_sensitivity = _controller.mouse_sensitivity;
			var _previous_invert_vertical_look = _controller.invert_vertical_look;
			var _previous_mouse_captured = _controller.mouse_captured;
			var _previous_lore_read = _controller.lore_read;
			var _previous_lore_open = _controller.lore_open;
			var _previous_lore_index = _controller.lore_index;
			var _previous_loadout = _controller.loadout;
			var _previous_pickups = _controller.pickups;
			var _previous_encounter_pressure = _controller.encounter_pressure;
			var _previous_encounter_plan = _controller.encounter_plan;
			var _previous_notice = _controller.pickup_notice;
			var _previous_notice_frames = _controller.pickup_notice_frames;
			var _previous_profile_status = _controller.profile_status;
			var _previous_summary_reason = _controller.summary_reason;
			var _previous_seed_input = _controller.seed_input;
			var _previous_surge = _controller.containment_surge;
			var _previous_surge_state = _controller.containment_surge_state;
			var _previous_dash = _controller.dash;
			var _previous_global_next_seed = variable_global_exists("fps_next_sector_seed")
				? global.fps_next_sector_seed
				: undefined;
			var _sector = fps_sector_generate(13579, 1366, 768, 24, 200);
			var _combat_tile_index = -1;
			var _safe_tile_index = -1;

			for (var _tile_index = 0; _tile_index < array_length(_sector.tiles); _tile_index += 1) {
				if (_sector.tiles[_tile_index].role == FPS_SECTOR_ROLE_COMBAT) {
					_combat_tile_index = _tile_index;
				} else if (_sector.tiles[_tile_index].role == FPS_SECTOR_ROLE_REWARD) {
					_safe_tile_index = _tile_index;
				}
			}
			expect(_combat_tile_index >= 0).toBeTruthy();
			expect(_safe_tile_index >= 0).toBeTruthy();

			_controller.sector = _sector;
			_controller.sector_seed = 13579;
			_controller.run_contract = fps_run_begin(13579);
			_controller.run_contract.room_index = _combat_tile_index;
			_controller.run_contract.room_complete = false;
			_controller.sync_run_contract();
			_controller.phase = FPS_STATE_PLAYING;
			_controller.run_started = true;
			_controller.x = _sector.tiles[_combat_tile_index].center_x + 200;
			_controller.y = _sector.tiles[_combat_tile_index].center_y + 200;
			_controller.configure_containment_surge();

			var _combat_surge = _controller.containment_surge;
			expect(is_struct(_combat_surge)).toBeTruthy();
			expect(_combat_surge.id).toBe("containment-surge-" + string(_combat_tile_index + 1));
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

			// A completed room must stop the live controller timer before another phase begins.
			var _completed_state = fps_containment_surge_create_state(_combat_surge.id);
			_completed_state.phase = FPS_CONTAINMENT_SURGE_WARNING;
			_completed_state.phase_frames = 1;
			_controller.containment_surge_state = _completed_state;
			_controller.run_contract.room_complete = true;
			_controller.sync_run_contract();
			var _completed_health = _controller.current_health;
			_controller.tick_containment_surge();
			expect(_controller.room_complete).toBeTruthy();
			expect(_controller.containment_surge_state.phase).toBe(FPS_CONTAINMENT_SURGE_WARNING);
			expect(_controller.containment_surge_state.phase_frames).toBe(1);
			expect(_controller.current_health).toBe(_completed_health);

			// Room entry uses this same encounter setup path; non-combat rooms have no HUD field.
			_controller.run_contract.room_index = _safe_tile_index;
			_controller.run_contract.room_complete = false;
			_controller.sync_run_contract();
			_controller.spawn_room_encounter();
			expect(is_struct(_controller.containment_surge)).toBeFalsy();
			expect(is_struct(_controller.containment_surge_state)).toBeFalsy();

			// A real run restart must discard the prior room's active hazard state.
			_controller.containment_surge = _combat_surge;
			var _stale_surge_state = fps_containment_surge_create_state(_combat_surge.id);
			_stale_surge_state.phase = FPS_CONTAINMENT_SURGE_ACTIVE;
			_stale_surge_state.cycle_index = 2;
			_controller.containment_surge_state = _stale_surge_state;
			_controller.start_run(24680, false);
			expect(_controller.sector_seed).toBe(24680);
			expect(_controller.run_contract.seed).toBe(24680);
			expect(_controller.run_room_index).toBe(0);
			expect(_controller.run_started).toBeTruthy();
			expect(is_struct(_controller.containment_surge)).toBeFalsy();
			expect(is_struct(_controller.containment_surge_state)).toBeFalsy();
			_controller.clear_room_instances();

			_controller.sector = _previous_sector;
			global.fps_sector = _previous_global_sector;
			_controller.sector_seed = _previous_sector_seed;
			_controller.run_contract = _previous_contract;
			_controller.phase = _previous_phase;
			_controller.run_started = _previous_run_started;
			_controller.profile = _previous_profile;
			_controller.max_health = _previous_max_health;
			_controller.x = _previous_x;
			_controller.y = _previous_y;
			_controller.current_health = _previous_health;
			_controller.mouse_sensitivity = _previous_mouse_sensitivity;
			_controller.invert_vertical_look = _previous_invert_vertical_look;
			_controller.lore_read = _previous_lore_read;
			_controller.lore_open = _previous_lore_open;
			_controller.lore_index = _previous_lore_index;
			_controller.loadout = _previous_loadout;
			_controller.pickups = _previous_pickups;
			_controller.encounter_pressure = _previous_encounter_pressure;
			_controller.encounter_plan = _previous_encounter_plan;
			_controller.pickup_notice = _previous_notice;
			_controller.pickup_notice_frames = _previous_notice_frames;
			_controller.profile_status = _previous_profile_status;
			_controller.summary_reason = _previous_summary_reason;
			_controller.seed_input = _previous_seed_input;
			_controller.containment_surge = _previous_surge;
			_controller.containment_surge_state = _previous_surge_state;
			_controller.dash = _previous_dash;
			global.fps_next_sector_seed = _previous_global_next_seed;
			vertex_delete_buffer(_controller.arena_buffer);
			_controller.arena_buffer = fps_build_sector_buffer(
				_controller.geometry_format,
				_controller.sector
			);
			_controller.set_mouse_capture(_previous_mouse_captured);
			_controller.sync_run_contract();
		});
	});
});
