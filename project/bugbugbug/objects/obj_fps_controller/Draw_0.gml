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

	var _body_mesh = enemy_buffer;
	var _accent_mesh = enemy_buffer;
	if (_enemy.enemy_kind == FPS_ENEMY_KIND_RANGED) {
		_body_mesh = ranged_enemy_buffer;
		_accent_mesh = ranged_enemy_accent_buffer;
	}
	if (_enemy.hit_flash_frames > 0) {
		_body_mesh = enemy_hit_buffer;
		_accent_mesh = enemy_hit_buffer;
	}

	matrix_set(
		matrix_world,
		matrix_build(
			_enemy.x,
			_enemy.y,
			_enemy.body_z,
			0,
			0,
			0,
			_enemy.body_width,
			_enemy.body_depth,
			_enemy.body_height
		)
	);
	vertex_submit(_body_mesh, pr_trianglelist, -1);

	if (_enemy.shoulder_width > 0) {
		matrix_set(
			matrix_world,
			matrix_build(
				_enemy.x,
				_enemy.y,
				_enemy.shoulder_z,
				0,
				0,
				0,
				_enemy.shoulder_width,
				_enemy.shoulder_depth,
				_enemy.shoulder_height
			)
		);
		vertex_submit(_accent_mesh, pr_trianglelist, -1);
	}

	matrix_set(
		matrix_world,
		matrix_build(
			_enemy.x,
			_enemy.y,
			_enemy.body_z + _enemy.body_height,
			0,
			0,
			0,
			_enemy.head_size,
			_enemy.head_size,
			_enemy.head_height
		)
	);
	vertex_submit(_accent_mesh, pr_trianglelist, -1);
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
