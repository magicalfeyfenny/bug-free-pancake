suite(function() {
	describe("Signal fragment sector contract", function() {
		it("places three clear, stable sockets away from archives and supplies", function() {
			for (var _sample_index = 0; _sample_index < 24; _sample_index += 1) {
				var _seed = 57329 + _sample_index * 7919;
				var _sector = fps_sector_generate(_seed, 1366, 768, 24, 200);
				var _repeat = fps_sector_generate(_seed, 1366, 768, 24, 200);
				var _pickups = fps_weapon_create_pickups(_sector, _seed);
				var _fragments = _sector.signal_fragment_sockets;
				expect(array_length(_fragments)).toBe(FPS_SECTOR_SIGNAL_FRAGMENT_COUNT);

				for (var _fragment_index = 0; _fragment_index < array_length(_fragments); _fragment_index += 1) {
					var _fragment = _fragments[_fragment_index];
					var _repeat_fragment = _repeat.signal_fragment_sockets[_fragment_index];
					expect(_fragment.tile_index).toBe(_fragment_index + 2);
					expect(_fragment.role).toBe(_sector.tiles[_fragment.tile_index].role);
					expect(_fragment.kind).toBe("signal-fragment");
					expect(_fragment.id).toBe(_repeat_fragment.id);
					expect(_fragment.x).toBe(_repeat_fragment.x);
					expect(_fragment.y).toBe(_repeat_fragment.y);
					expect(fps_sector_position_is_clear(_sector, _fragment.x, _fragment.y, 54)).toBeTruthy();
					expect(
						fps_sector_near_signal_fragment(
							_sector,
							[],
							_fragment.x,
							_fragment.y,
							FPS_WEAPON_PICKUP_RANGE
						)
					).toBe(_fragment_index);
					expect(
						fps_sector_near_signal_fragment(
							_sector,
							[_fragment.id],
							_fragment.x,
							_fragment.y,
							FPS_WEAPON_PICKUP_RANGE
						)
					).toBe(-1);

					for (var _socket_index = 0; _socket_index < array_length(_sector.sockets); _socket_index += 1) {
						var _socket = _sector.sockets[_socket_index];
						if (_socket.id == _fragment.id) {
							continue;
						}
						expect(
							point_distance(_fragment.x, _fragment.y, _socket.x, _socket.y)
								> _fragment.radius + _socket.radius + 12
						).toBeTruthy();
						if (_socket.kind == "lore" && _socket.tile_index == _fragment.tile_index) {
							expect(
								point_distance(_fragment.x, _fragment.y, _socket.x, _socket.y)
									> 2 * FPS_WEAPON_PICKUP_RANGE
							).toBeTruthy();
						}
					}

					for (var _pickup_index = 0; _pickup_index < array_length(_pickups); _pickup_index += 1) {
						var _pickup = _pickups[_pickup_index];
						if (_pickup.tile_index == _fragment.tile_index) {
							expect(
								point_distance(_fragment.x, _fragment.y, _pickup.x, _pickup.y)
									> 2 * FPS_WEAPON_PICKUP_RANGE
							).toBeTruthy();
						}
					}
				}
			}
		});
	});
});

suite(function() {
	describe("Signal fragment run contract", function() {
		it("awards each stable fragment ID once and resets on a fresh run", function() {
			var _state = fps_run_begin(314159);
			var _first = fps_run_collect_signal_fragment(_state, "signal-fragment-sector-tile-3");
			expect(_first.collected).toBeTruthy();
			expect(_first.points).toBe(FPS_RUN_SCORE_SIGNAL_FRAGMENT);
			expect(_first.count).toBe(1);
			expect(_state.score).toBe(FPS_RUN_SCORE_SIGNAL_FRAGMENT);

			var _duplicate = fps_run_collect_signal_fragment(_state, "signal-fragment-sector-tile-3");
			expect(_duplicate.collected).toBeFalsy();
			expect(_duplicate.count).toBe(1);
			expect(_state.score).toBe(FPS_RUN_SCORE_SIGNAL_FRAGMENT);

			fps_run_collect_signal_fragment(_state, "signal-fragment-sector-tile-4");
			var _third = fps_run_collect_signal_fragment(_state, "signal-fragment-sector-tile-5");
			expect(_third.count).toBe(FPS_SECTOR_SIGNAL_FRAGMENT_COUNT);
			expect(_state.score).toBe(FPS_RUN_SCORE_SIGNAL_FRAGMENT * FPS_SECTOR_SIGNAL_FRAGMENT_COUNT);

			var _restart = fps_run_begin(_state.seed);
			expect(array_length(_restart.signal_fragments_collected)).toBe(0);
			expect(_restart.score).toBe(0);
		});
	});
});

suite(function() {
	describe("Signal fragment controller integration", function() {
		it("collects from its tile before and after room clear", function() {
			var _controller = instance_find(obj_fps_controller, 0);
			var _previous_contract = _controller.run_contract;
			var _previous_phase = _controller.phase;
			var _previous_run_started = _controller.run_started;
			var _previous_x = _controller.x;
			var _previous_y = _controller.y;
			var _previous_notice = _controller.pickup_notice;
			var _previous_notice_frames = _controller.pickup_notice_frames;
			var _fragment_index = 1;
			var _fragment = _controller.sector.signal_fragment_sockets[_fragment_index];

			for (var _clear_state = 0; _clear_state < 2; _clear_state += 1) {
				_controller.run_contract = fps_run_begin(24680);
				_controller.run_contract.room_index = _fragment.tile_index;
				_controller.run_contract.room_complete = _clear_state == 1;
				_controller.phase = FPS_STATE_PLAYING;
				_controller.run_started = true;
				_controller.x = _fragment.x;
				_controller.y = _fragment.y;
				_controller.sync_run_contract();

				expect(_controller.collect_signal_fragment(_fragment_index)).toBeTruthy();
				expect(array_length(_controller.run_contract.signal_fragments_collected)).toBe(1);
				expect(_controller.run_contract.score).toBe(FPS_RUN_SCORE_SIGNAL_FRAGMENT);
			}

			_controller.run_contract = _previous_contract;
			_controller.phase = _previous_phase;
			_controller.run_started = _previous_run_started;
			_controller.x = _previous_x;
			_controller.y = _previous_y;
			_controller.pickup_notice = _previous_notice;
			_controller.pickup_notice_frames = _previous_notice_frames;
			_controller.sync_run_contract();
		});
	});
});
