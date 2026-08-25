window_mouse_set_locked(false);
window_set_cursor(cr_default);
vertex_delete_buffer(arena_buffer);
vertex_delete_buffer(enemy_buffer);
vertex_delete_buffer(enemy_hit_buffer);
vertex_format_delete(geometry_format);
