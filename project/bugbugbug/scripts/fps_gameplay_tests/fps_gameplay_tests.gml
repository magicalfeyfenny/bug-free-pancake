suite(function() {
	describe("FPS gameplay state", function() {
		it("starts a fresh playable encounter", function() {
			var _state = fps_create_encounter_state();
			expect(_state.player_health).toBe(FPS_PLAYER_MAX_HEALTH);
			expect(_state.enemy_health).toBe(FPS_ENEMY_MAX_HEALTH);
			expect(_state.phase).toBe(FPS_STATE_PLAYING);
		});

		it("clamps damage and ignores healing through negative damage", function() {
			expect(fps_apply_damage(100, 34)).toBe(66);
			expect(fps_apply_damage(20, 50)).toBe(0);
			expect(fps_apply_damage(20, -10)).toBe(20);
		});

		it("selects death and victory terminal states", function() {
			expect(fps_get_terminal_state(0, 0)).toBe(FPS_STATE_DEAD);
			expect(fps_get_terminal_state(100, 0)).toBe(FPS_STATE_VICTORY);
			expect(fps_get_terminal_state(40, 25)).toBe(FPS_STATE_PLAYING);
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
	});
});
