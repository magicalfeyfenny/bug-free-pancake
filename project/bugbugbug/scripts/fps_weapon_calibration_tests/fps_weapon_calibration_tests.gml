suite(function() {
	describe("Run-scoped weapon calibration", function() {
		it("adds one stable card while retaining the three-choice limit", function() {
			var _profile = fps_profile_defaults();
			var _loadout = fps_weapon_create_loadout();
			var _pool = fps_run_reward_pool(_profile, _loadout);
			var _calibration_count = 0;
			var _calibration_label = "";
			var _calibration_description = "";
			for (var _choice_index = 0; _choice_index < array_length(_pool); _choice_index += 1) {
				var _choice = _pool[_choice_index];
				if (_choice.kind == FPS_RUN_REWARD_CALIBRATION) {
					_calibration_count += 1;
					_calibration_label = _choice.label;
					_calibration_description = _choice.description;
				}
			}
			expect(_calibration_count).toBe(1);
			expect(_calibration_label).toBe("CALIBRATION");
			expect(string_length(_calibration_description) > 0).toBeTruthy();

			var _first = fps_run_create_reward_choices(314159, 2, _profile, _loadout);
			var _repeat = fps_run_create_reward_choices(314159, 2, _profile, _loadout);
			expect(fps_run_reward_signature(_first)).toBe(fps_run_reward_signature(_repeat));
			expect(array_length(_first)).toBe(FPS_RUN_REWARD_LIMIT);
		});

		it("calibrates the equipped weapon once without changing profile data", function() {
			var _profile = fps_profile_defaults();
			var _profile_before = fps_profile_to_data(_profile);
			var _loadout = fps_weapon_create_loadout();
			var _card = {kind: FPS_RUN_REWARD_CALIBRATION};
			fps_run_apply_reward(_card, _loadout, 100, 100, _profile);
			expect(_loadout.states[FPS_WEAPON_PULSE].calibrated).toBeTruthy();
			expect(fps_weapon_calibration_available(_loadout)).toBeFalsy();
			var _pool_after_calibration = fps_run_reward_pool(_profile, _loadout);
			expect(array_length(_pool_after_calibration)).toBe(3);

			fps_run_apply_reward(_card, _loadout, 100, 100, _profile);
			expect(_loadout.states[FPS_WEAPON_PULSE].calibrated).toBeTruthy();
			expect(fps_weapon_calibrate_current(_loadout)).toBeFalsy();
			var _matching_loadout = fps_weapon_create_loadout();
			fps_run_apply_reward(_card, _matching_loadout, 100, 100, _profile);
			var _next_choices = fps_run_create_reward_choices(314159, 3, _profile, _loadout);
			var _matching_next_choices = fps_run_create_reward_choices(314159, 3, _profile, _matching_loadout);
			expect(fps_run_reward_signature(_next_choices)).toBe(fps_run_reward_signature(_matching_next_choices));
			for (var _next_index = 0; _next_index < array_length(_next_choices); _next_index += 1) {
				expect(_next_choices[_next_index].kind == FPS_RUN_REWARD_CALIBRATION).toBeFalsy();
			}

			var _profile_after = fps_profile_to_data(_profile);
			expect(_profile_after.runs).toBe(_profile_before.runs);
			expect(_profile_after.victories).toBe(_profile_before.victories);
			expect(_profile_after.mouse_sensitivity).toBe(_profile_before.mouse_sensitivity);
			expect(_profile_after.invert_vertical_look).toBe(_profile_before.invert_vertical_look);
			for (var _lore_index = 0; _lore_index < FPS_PROFILE_LORE_COUNT; _lore_index += 1) {
				expect(_profile_after.discovered_lore[_lore_index]).toBe(_profile_before.discovered_lore[_lore_index]);
			}
			for (var _unlock_index = 0; _unlock_index < FPS_PROFILE_UNLOCK_COUNT; _unlock_index += 1) {
				expect(_profile_after.unlocks[_unlock_index]).toBe(_profile_before.unlocks[_unlock_index]);
			}
			var _fresh_loadout = fps_weapon_create_loadout();
			expect(_fresh_loadout.states[FPS_WEAPON_PULSE].calibrated).toBeFalsy();
			expect(fps_weapon_calibration_available(_fresh_loadout)).toBeTruthy();
		});

		it("scales damage through the shared shot contract for every weapon pattern", function() {
			var _expected_damage_tenths = [374, 132, 220, 946];
			for (var _weapon_id = 0; _weapon_id < FPS_WEAPON_COUNT; _weapon_id += 1) {
				var _loadout = fps_weapon_create_loadout();
				var _state = _loadout.states[_weapon_id];
				var _definition = fps_weapon_definition(_weapon_id);
				var _base_damage = _definition.damage;
				_state.owned = true;
				_state.magazine = _definition.magazine_size;
				_state.reserve = _definition.initial_reserve;
				expect(fps_weapon_switch(_loadout, _weapon_id)).toBeTruthy();
				expect(fps_weapon_calibrate_current(_loadout)).toBeTruthy();

				var _shot = fps_weapon_start_shot(_loadout);
				expect(round(_shot.damage * 10)).toBe(_expected_damage_tenths[_weapon_id]);
				expect(fps_weapon_definition(_weapon_id).damage).toBe(_base_damage);
				expect(array_length(_shot.pattern)).toBe(_definition.pellets);
				expect(_shot.cooldown_frames).toBe(_definition.fire_delay);
				expect(_shot.definition.range).toBe(_definition.range);
				expect(_state.magazine).toBe(_definition.magazine_size - 1);
				expect(_state.reserve).toBe(_definition.initial_reserve);
			}
		});

		it("keeps the bonus on its weapon after switching and stacks with overcharge", function() {
			var _loadout = fps_weapon_create_loadout();
			var _scatter = _loadout.states[FPS_WEAPON_SCATTER];
			_scatter.owned = true;
			_scatter.magazine = fps_weapon_definition(FPS_WEAPON_SCATTER).magazine_size;
			expect(fps_weapon_calibrate_current(_loadout)).toBeTruthy();

			expect(fps_weapon_switch(_loadout, FPS_WEAPON_SCATTER)).toBeTruthy();
			var _scatter_shot = fps_weapon_start_shot(_loadout);
			expect(_scatter_shot.damage).toBe(fps_weapon_definition(FPS_WEAPON_SCATTER).damage);
			expect(_scatter.calibrated).toBeFalsy();
			expect(_loadout.states[FPS_WEAPON_PULSE].calibrated).toBeTruthy();

			expect(fps_weapon_switch(_loadout, FPS_WEAPON_PULSE)).toBeTruthy();
			_loadout.overcharge_frames = FPS_WEAPON_OVERCHARGE_GAIN;
			var _calibrated_shot = fps_weapon_start_shot(_loadout);
			expect(round(_calibrated_shot.damage * 10)).toBe(561);
			expect(_loadout.overcharge_frames).toBe(FPS_WEAPON_OVERCHARGE_GAIN);
		});
	});
});
