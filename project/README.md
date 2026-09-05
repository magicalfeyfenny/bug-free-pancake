# Containment Protocol

Open `bugbugbug/bugbugbug.yyp` in GameMaker LTS 2026 and run the project. The
default room starts a deterministic six-space containment sector with a
first-person encounter, optional archive entries, and a visible finale exit.

Controls:

- `WASD`: move
- Mouse: aim
- Left click: fire
- `Esc`: release or recapture the mouse
- `R`: restart after victory or death
- `E`: read a nearby archive entry or close the archive panel
- `N`: restart with the next deterministic sector seed

The chaser and ranged skirmisher use distinct authored low-poly models. Their
editable Blender and OBJ/MTL sources live under `assets/source/models/enemies`,
with GameMaker-ready vertex buffers under `assets/runtime/models`. The arena,
visible enemy projectiles, and weapon remain GameMaker-native primitives.
The generated sector uses six aligned start, connector, combat, safe, archive,
and finale spaces. Its solids are shared by rendering, actor movement,
projectile travel, and hitscan occlusion. Six optional archive entries explain
the facility, assignment, breach, hostiles, shifting sectors, and signal core.
Defeat both enemies to secure the sector.
