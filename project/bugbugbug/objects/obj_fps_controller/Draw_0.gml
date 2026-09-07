draw_clear(make_color_rgb(7, 10, 18));
draw_clear_depth(1);

var _old_world = matrix_get(matrix_world);
var _old_view = matrix_get(matrix_view);
var _old_projection = matrix_get(matrix_projection);
var _horizontal_length = dcos(pitch);
var _look_x = lengthdir_x(_horizontal_length, yaw);
var _look_y = lengthdir_y(_horizontal_length, yaw);
var _look_z = dsin(pitch);

matrix_set(
	matrix_view,
	matrix_build_lookat(
		x,
		y,
		eye_height,
		x + _look_x,
		y + _look_y,
		eye_height + _look_z,
		0,
		0,
		-1
	)
);
matrix_set(
	matrix_projection,
	matrix_build_projection_perspective_fov(75, room_width / room_height, 1, 5000)
);
matrix_set(matrix_world, matrix_build_identity());

gpu_push_state();
gpu_set_ztestenable(true);
gpu_set_zwriteenable(true);
gpu_set_cullmode(cull_noculling);

vertex_submit(arena_buffer, pr_trianglelist, -1);

var _pickup_count = array_length(pickups);
for (var _pickup_index = 0; _pickup_index < _pickup_count; _pickup_index += 1) {
	var _pickup = pickups[_pickup_index];
	if (_pickup.collected) {
		continue;
	}

	var _pickup_height = 18 + 5 * dsin(pickup_spin + _pickup_index * 42);
	var _pickup_scale = fps_weapon_pickup_scale(_pickup.kind);
	matrix_set(
		matrix_world,
		matrix_build(
			_pickup.x,
			_pickup.y,
			_pickup_height,
			0,
			0,
			pickup_spin + _pickup_index * 42,
			_pickup_scale,
			_pickup_scale,
			_pickup_scale * 1.7
		)
	);
	vertex_submit(pickup_meshes[_pickup.kind], pr_trianglelist, -1);
}

var _enemy_count = instance_number(obj_fps_enemy);
for (var _enemy_index = 0; _enemy_index < _enemy_count; _enemy_index += 1) {
	var _enemy = instance_find(obj_fps_enemy, _enemy_index);
	if (
		!instance_exists(_enemy)
		|| !variable_instance_exists(_enemy, "initialized")
		|| !_enemy.initialized
		|| !_enemy.alive
	) {
		continue;
	}

	var _enemy_kind = clamp(floor(_enemy.enemy_kind), 0, FPS_ENEMY_KIND_COUNT - 1);
	if (_enemy.telegraph_frames > 0) {
		var _warning_angle = point_direction(_enemy.x, _enemy.y, x, y);
		var _warning_x = _enemy.x;
		var _warning_y = _enemy.y;
		var _warning_scale_x = _enemy.warning_radius * 2;
		var _warning_scale_y = _enemy.warning_radius * 2;
		if (_enemy.warning_shape == FPS_ENEMY_WARNING_BEAM) {
			var _warning_length = min(point_distance(_enemy.x, _enemy.y, x, y), _enemy.attack_range);
			_warning_x += lengthdir_x(_warning_length * 0.5, _warning_angle);
			_warning_y += lengthdir_y(_warning_length * 0.5, _warning_angle);
			_warning_scale_x = _enemy.warning_radius * 2;
			_warning_scale_y = max(24, _warning_length);
		}
		matrix_set(
			matrix_world,
			matrix_build(
				_warning_x,
				_warning_y,
				1.5,
				0,
				0,
				_warning_angle,
				_warning_scale_x,
				_warning_scale_y,
				0.08
			)
		);
		vertex_submit(enemy_warning_buffer, pr_trianglelist, -1);
	}

	var _enemy_mesh = _enemy.hit_flash_frames > 0
		? enemy_hit_buffers[_enemy_kind]
		: enemy_buffers[_enemy_kind];

	var _facing = point_direction(_enemy.x, _enemy.y, x, y);
	matrix_set(
		matrix_world,
		matrix_build(
			_enemy.x,
			_enemy.y,
			0,
			0,
			0,
			_facing,
			1,
			1,
			1
		)
	);
	vertex_submit(_enemy_mesh, pr_trianglelist, -1);
}

var _projectile_count = instance_number(obj_fps_enemy_projectile);
for (var _projectile_index = 0; _projectile_index < _projectile_count; _projectile_index += 1) {
	var _projectile = instance_find(obj_fps_enemy_projectile, _projectile_index);
	if (!instance_exists(_projectile)) {
		continue;
	}

	matrix_set(
		matrix_world,
		matrix_build(
			_projectile.x,
			_projectile.y,
			_projectile.flight_height,
			0,
			0,
			_projectile.direction_angle,
			_projectile.body_length,
			_projectile.body_width,
			_projectile.body_width
		)
	);
	vertex_submit(enemy_projectile_buffer, pr_trianglelist, -1);
}

gpu_pop_state();
matrix_set(matrix_world, _old_world);
matrix_set(matrix_view, _old_view);
matrix_set(matrix_projection, _old_projection);
