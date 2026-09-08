# Containment Protocol

Open `bugbugbug/bugbugbug.yyp` in GameMaker LTS 2026 and run the project. The
title flow accepts a random seed or a numeric seed and carries one run through
six deterministic spaces, escalating encounters, reward choices, a finale,
and a victory or death summary.

Controls:

- `WASD`: move
- Mouse: aim
- Left click: fire the equipped weapon
- `1`-`4` or `Q`: switch among acquired weapons
- `R`: reload during play; restart the current seed after a summary
- `E`: collect a nearby supply cache, read an archive entry, close the archive panel, or enter the next space
- `Esc`: release or recapture the mouse during play; close a lore panel
- `Enter`: begin the selected seed or confirm a summary action
- `S`: edit the numeric seed; `N`: choose a random seed or return to the title with one
- `A`: reread discovered archives from the title or summary; `X`: reset the profile after confirmation

The chaser and ranged skirmisher use distinct authored low-poly models. Their
editable Blender and OBJ/MTL sources live under `assets/source/models/enemies`,
with GameMaker-ready vertex buffers under `assets/runtime/models`. The arena,
visible enemy projectiles, and weapon remain GameMaker-native primitives.
The generated sector uses six aligned start, connector, combat, safe, archive,
and finale spaces. Its solids are shared by rendering, actor movement,
projectile travel, and hitscan occlusion. Each seed places three weapon caches,
med gel, an ammo cell, and a temporary overcharge in clear tile positions.
Cleared combat spaces offer three deterministic reward cards. A versioned local
profile records discoveries, victories, and bounded unlocks; unsupported or
corrupt profile data falls back to a clean profile.
The Pulse Rifle, Scatter Cannon, Burst Carbine, and Rail Lance trade firing
pattern, reach, cadence, and ammunition differently. Six optional archive
entries explain the facility, assignment, breach, hostiles, shifting sectors,
and signal core. Clear the mixed encounters and durable finale threat to
secure the run.
