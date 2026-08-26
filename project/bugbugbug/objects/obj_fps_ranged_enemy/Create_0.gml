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

hit_sphere_height = 60;
hit_sphere_radius = 52;

projectile_speed = 8;
projectile_lifetime = 180;
