# Containment Protocol

Open `bugbugbug/bugbugbug.yyp` in GameMaker LTS 2026 and run the project. The
title flow accepts a random seed or a numeric seed and carries one run through
six deterministic spaces, escalating encounters, reward choices, a finale,
and a victory or death summary.

Controls:

- `WASD`: move
- `Space`: Phase Dash in the movement or facing direction; briefly ignores damage while recharging
- Mouse: aim
- Left click: fire the equipped weapon
- `1`-`4` or `Q`: switch among acquired weapons
- `R`: reload during play; restart the current seed after a summary
- `E`: collect a nearby supply cache, read an archive entry, close the archive panel, or enter the next space
- `Esc`: pause or resume an active run; close a lore panel
- `Enter`: begin the selected seed or confirm a summary action
- `S`: edit the numeric seed; `N`: choose a random seed or return to the title with one
- `C`: open title controls; use `Up`/`Down` to select, `Left`/`Right` to adjust, and `Enter` to toggle inversion
- `A`: reread discovered archives from the title or summary; `X`: reset the profile after confirmation

The chaser and ranged skirmisher use distinct authored low-poly models. Their
editable Blender and OBJ/MTL sources live under `assets/source/models/enemies`,
with GameMaker-ready vertex buffers under `assets/runtime/models`. The arena,
visible enemy projectiles, and weapon remain GameMaker-native primitives.
The Burrower, Sentry, Barrier Warden, and Titan use editable GameMaker-native
geometry. A Warden closes to short range and telegraphs a cover-blockable area
strike. Its shield turns toward the player at a fixed rate, blocks weapon hits
inside a 120-degree front arc while raised, and opens on a fixed frame cycle;
the active HUD labels each barrier state. A defeated Warden awards 200 run
points once.
The generated sector uses six aligned start, connector, combat, safe, archive,
and finale spaces. Its solids are shared by rendering, actor movement,
projectile travel, and hitscan occlusion. Each seed places three weapon caches,
med gel, an ammo cell, and a temporary overcharge in clear tile positions.
During an active run, the route strip shows all six generated spaces in order;
`CURRENT`, `CLEARED`, `NEXT`, and `FINALE` markers track the selected seed as
rooms change.
The active HUD and victory or death summary show the run score. Defeated roles
award fixed points, each cleared generated space awards one room bonus, and the
finale awards its bonus only on victory; restarting a seed resets the score.
Cleared combat spaces offer three deterministic reward cards. A versioned local
profile records discoveries, victories, bounded unlocks, mouse sensitivity, and
vertical-look inversion; legacy profile data migrates without losing discoveries,
victories, or unlock ownership, while unsupported or corrupt data falls back to
safe defaults.
The Pulse Rifle, Scatter Cannon, Burst Carbine, and Rail Lance trade firing
pattern, reach, cadence, and ammunition differently. Six optional archive
entries explain the facility, assignment, breach, hostiles, shifting sectors,
and signal core. Clear the mixed encounters and durable finale threat to
secure the run. The finale Titan begins in the named AWAKENING phase and
shifts once to SIEGE at half health; the combat notice announces the shift
while the existing warning, line-of-sight, and collision rules remain active.
