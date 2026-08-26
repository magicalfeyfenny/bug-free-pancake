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
