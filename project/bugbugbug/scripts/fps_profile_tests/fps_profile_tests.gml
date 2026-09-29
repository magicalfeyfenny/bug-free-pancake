suite(function() {
	describe("Versioned persistent profile", function() {
		it("round trips stable lore and unlock identities", function() {
			var _profile = fps_profile_defaults();
			_profile.runs = 4;
			_profile.mouse_sensitivity = 0.24;
			_profile.invert_vertical_look = true;
			fps_profile_discover_lore(_profile, "archive-assignment");
			fps_profile_grant_unlock(_profile, FPS_PROFILE_UNLOCK_RAIL);
			var _round_trip = fps_profile_from_data(fps_profile_to_data(_profile));
			expect(_round_trip.save_version).toBe(FPS_PROFILE_SAVE_VERSION);
			expect(_round_trip.runs).toBe(4);
			expect(_round_trip.discovered_lore[1]).toBeTruthy();
			expect(fps_profile_has_unlock(_round_trip, FPS_PROFILE_UNLOCK_RAIL)).toBeTruthy();
			expect(_round_trip.mouse_sensitivity).toBe(0.24);
			expect(_round_trip.invert_vertical_look).toBeTruthy();

			var _test_file = "containment_protocol_profile_contract_test.ini";
			fps_profile_save_file(_profile, _test_file);
			var _file_round_trip = fps_profile_load_file(_test_file);
			fps_profile_reset_file_as(_test_file);
			expect(_file_round_trip.runs).toBe(4);
			expect(fps_profile_has_unlock(_file_round_trip, FPS_PROFILE_UNLOCK_RAIL)).toBeTruthy();
			expect(_file_round_trip.mouse_sensitivity).toBe(0.24);
			expect(_file_round_trip.invert_vertical_look).toBeTruthy();
			expect(file_exists(_test_file)).toBeFalsy();
		});

		it("migrates legacy data and defaults only invalid aim settings", function() {
			var _legacy_data = {
				save_version: FPS_PROFILE_LEGACY_SAVE_VERSION,
				runs: 7,
				victories: 3,
				discovered_lore: [true, false, true, false, false, false],
				unlocks: [true, false, true],
			};
			var _legacy_profile = fps_profile_from_data(_legacy_data);
			expect(_legacy_profile.save_version).toBe(FPS_PROFILE_SAVE_VERSION);
			expect(_legacy_profile.runs).toBe(7);
			expect(_legacy_profile.victories).toBe(3);
			expect(_legacy_profile.discovered_lore[2]).toBeTruthy();
			expect(fps_profile_has_unlock(_legacy_profile, FPS_PROFILE_UNLOCK_RAIL)).toBeTruthy();
			expect(fps_profile_has_unlock(_legacy_profile, FPS_PROFILE_UNLOCK_VITALS)).toBeTruthy();
			expect(_legacy_profile.mouse_sensitivity).toBe(FPS_PROFILE_DEFAULT_MOUSE_SENSITIVITY);
			expect(_legacy_profile.invert_vertical_look).toBeFalsy();
			var _invalid_settings = fps_profile_to_data(_legacy_profile);
			_invalid_settings.mouse_sensitivity = FPS_PROFILE_MAX_MOUSE_SENSITIVITY + 1;
			_invalid_settings.invert_vertical_look = 2;
			var _safe_settings = fps_profile_from_data(_invalid_settings);
			expect(_safe_settings.runs).toBe(7);
			expect(_safe_settings.victories).toBe(3);
			expect(_safe_settings.discovered_lore[2]).toBeTruthy();
			expect(fps_profile_has_unlock(_safe_settings, FPS_PROFILE_UNLOCK_RAIL)).toBeTruthy();
			expect(_safe_settings.mouse_sensitivity).toBe(FPS_PROFILE_DEFAULT_MOUSE_SENSITIVITY);
			expect(_safe_settings.invert_vertical_look).toBeFalsy();
		});
		it("bounds sensitivity and maps vertical look deterministically", function() {
			expect(fps_profile_adjust_mouse_sensitivity(FPS_PROFILE_MIN_MOUSE_SENSITIVITY, -1)).toBe(FPS_PROFILE_MIN_MOUSE_SENSITIVITY);
			expect(fps_profile_adjust_mouse_sensitivity(FPS_PROFILE_MAX_MOUSE_SENSITIVITY, 1)).toBe(FPS_PROFILE_MAX_MOUSE_SENSITIVITY);
			expect(fps_profile_apply_vertical_look(0, 10, 0.1, false)).toBe(-1);
			expect(fps_profile_apply_vertical_look(0, 10, 0.1, true)).toBe(1);
		});
		it("falls back atomically for missing, corrupt, or unsupported data", function() {
			var _missing = fps_profile_from_data(undefined);
			expect(_missing.runs).toBe(0);
			var _unsupported = fps_profile_defaults();
			_unsupported.save_version = FPS_PROFILE_SAVE_VERSION + 1;
			_unsupported.runs = 99;
			var _unsupported_result = fps_profile_from_data(_unsupported);
			expect(_unsupported_result.runs).toBe(0);
			var _corrupt = {
				save_version: FPS_PROFILE_SAVE_VERSION,
				runs: "not-a-number",
				victories: 0,
				discovered_lore: [],
				unlocks: [],
			};
			expect(fps_profile_data_is_valid(_corrupt)).toBeFalsy();
			expect(fps_profile_reset_data().victories).toBe(0);
		});
		it("broadens future choices through bounded earned unlocks", function() {
			var _profile = fps_profile_defaults();
			_profile = fps_profile_record_run_finished(_profile, true);
			expect(fps_profile_has_unlock(_profile, FPS_PROFILE_UNLOCK_RAIL)).toBeTruthy();
			fps_profile_discover_lore(_profile, "archive-facility");
			fps_profile_discover_lore(_profile, "archive-assignment");
			fps_profile_discover_lore(_profile, "archive-breach");
			_profile = fps_profile_record_run_finished(_profile, true);
			expect(fps_profile_has_unlock(_profile, FPS_PROFILE_UNLOCK_ARCHIVE)).toBeTruthy();
			expect(array_length(fps_run_reward_pool(_profile, fps_weapon_create_loadout())) > 3).toBeTruthy();
			expect(fps_profile_has_unlock(fps_profile_reset_data(), FPS_PROFILE_UNLOCK_RAIL)).toBeFalsy();
		});
	});
});
