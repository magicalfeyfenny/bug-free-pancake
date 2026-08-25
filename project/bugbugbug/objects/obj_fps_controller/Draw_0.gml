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

var _enemy = instance_find(obj_fps_enemy, 0);
if (
	instance_exists(_enemy)
	&& variable_instance_exists(_enemy, "initialized")
	&& _enemy.initialized
	&& _enemy.alive
) {
	var _enemy_mesh = _enemy.hit_flash_frames > 0 ? enemy_hit_buffer : enemy_buffer;

	matrix_set(
		matrix_world,
		matrix_build(
			_enemy.x,
			_enemy.y,
			0,
			0,
			0,
			0,
			_enemy.body_width,
			_enemy.body_depth,
			_enemy.body_height
		)
	);
	vertex_submit(_enemy_mesh, pr_trianglelist, -1);

	matrix_set(
		matrix_world,
		matrix_build(
			_enemy.x,
			_enemy.y,
			_enemy.body_height,
			0,
			0,
			0,
			_enemy.head_size,
			_enemy.head_size,
			_enemy.head_size
		)
	);
	vertex_submit(_enemy_mesh, pr_trianglelist, -1);
}

gpu_pop_state();
matrix_set(matrix_world, _old_world);
matrix_set(matrix_view, _old_view);
matrix_set(matrix_projection, _old_projection);
