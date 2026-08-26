// Reuse the shared health and damage contract while this child supplies its own AI.
event_inherited();

max_health = FPS_RANGED_ENEMY_MAX_HEALTH;
current_health = max_health;
enemy_kind = FPS_ENEMY_KIND_RANGED;

move_speed = 3;
collision_radius = 48;
attack_damage = 10;
attack_delay = 30;
attack_cooldown = 0;
evade_duration = 90;
attack_duration = 70;
mode = FPS_RANGED_MODE_EVADE;
mode_frames = evade_duration;
strafe_direction = 1;

body_width = 34;
body_depth = 34;
body_height = 58;
body_z = 18;
head_size = 42;
head_height = 18;
shoulder_width = 96;
shoulder_depth = 18;
shoulder_height = 14;
shoulder_z = 47;
hit_sphere_height = 60;
hit_sphere_radius = 52;

projectile_speed = 8;
projectile_lifetime = 180;
