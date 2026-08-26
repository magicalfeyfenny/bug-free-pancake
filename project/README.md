# Containment Protocol

Open `bugbugbug/bugbugbug.yyp` in GameMaker LTS 2026 and run the project. The
default room starts a self-contained first-person encounter.

Controls:

- `WASD`: move
- Mouse: aim
- Left click: fire
- `Esc`: release or recapture the mouse
- `R`: restart after victory or death

The chaser and ranged skirmisher use distinct authored low-poly models. Their
editable Blender and OBJ/MTL sources live under `assets/source/models/enemies`,
with GameMaker-ready vertex buffers under `assets/runtime/models`. The arena,
visible enemy projectiles, and weapon remain GameMaker-native primitives.
Defeat both enemies to secure the room.
