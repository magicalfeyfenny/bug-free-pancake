/// Returns the short HUD state for the Warden's rotating barrier.
function fps_enemy_warden_barrier_name(_state) {
	return _state == FPS_WARDEN_BARRIER_UP ? "BARRIER UP" : "BARRIER OPEN";
}

/// Advances the Warden's fixed guarded/open cycle once per active frame.
function fps_enemy_update_warden_barrier(_enemy) {
	if (!instance_exists(_enemy) || _enemy.enemy_kind != FPS_ENEMY_KIND_WARDEN) {
		return false;
	}

	_enemy.warden_barrier_frames_remaining = max(0, _enemy.warden_barrier_frames_remaining - 1);
	if (_enemy.warden_barrier_frames_remaining > 0) {
		return false;
	}

	var _definition = fps_enemy_role_definition(FPS_ENEMY_KIND_WARDEN);
	if (_enemy.warden_barrier_state == FPS_WARDEN_BARRIER_UP) {
		_enemy.warden_barrier_state = FPS_WARDEN_BARRIER_OPEN;
		_enemy.warden_barrier_frames_remaining = _definition.barrier_open_frames;
	} else {
		_enemy.warden_barrier_state = FPS_WARDEN_BARRIER_UP;
		_enemy.warden_barrier_frames_remaining = _definition.barrier_up_frames;
	}

	_enemy.combat_phase_name = fps_enemy_warden_barrier_name(_enemy.warden_barrier_state);
	return true;
}

/// Turns the Warden's visible barrier toward the player at a fixed rate.
function fps_enemy_turn_warden(_enemy, _player) {
	if (!instance_exists(_enemy) || _enemy.enemy_kind != FPS_ENEMY_KIND_WARDEN) {
		return false;
	}

	var _target_angle = point_direction(_enemy.x, _enemy.y, _player.x, _player.y);
	var _turn = clamp(
		angle_difference(_target_angle, _enemy.warden_facing_angle),
		-_enemy.warden_barrier_turn_speed,
		_enemy.warden_barrier_turn_speed
	);
	_enemy.warden_facing_angle += _turn;
	return true;
}

/// Blocks only frontal weapon hits while a Warden's barrier is raised.
function fps_enemy_weapon_hit_blocked(_enemy, _source_x, _source_y) {
	if (
		!instance_exists(_enemy)
		|| _enemy.enemy_kind != FPS_ENEMY_KIND_WARDEN
		|| _enemy.warden_barrier_state != FPS_WARDEN_BARRIER_UP
	) {
		return false;
	}

	var _incoming_angle = point_direction(_enemy.x, _enemy.y, _source_x, _source_y);
	return abs(angle_difference(_incoming_angle, _enemy.warden_facing_angle))
		<= _enemy.warden_barrier_arc_half_angle;
}
