window_mouse_set_locked(false);
window_set_cursor(cr_default);
vertex_delete_buffer(arena_buffer);
vertex_delete_buffer(enemy_buffer);
vertex_delete_buffer(enemy_hit_buffer);
vertex_delete_buffer(ranged_enemy_buffer);
vertex_delete_buffer(ranged_enemy_hit_buffer);
vertex_delete_buffer(enemy_projectile_buffer);
var _pickup_mesh_count = array_length(pickup_meshes);
for (var _pickup_mesh_index = 0; _pickup_mesh_index < _pickup_mesh_count; _pickup_mesh_index += 1) {
	vertex_delete_buffer(pickup_meshes[_pickup_mesh_index]);
}
vertex_format_delete(geometry_format);
