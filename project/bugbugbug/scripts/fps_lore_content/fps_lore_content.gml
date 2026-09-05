/// Returns the six optional archive entries placed across the generated sector.
function fps_create_lore_entries() {
	return [
		{
			id: "archive-facility",
			title: "ARCHIVE 01 // THE FACILITY",
			text: "Containment Protocol was built beneath the old relay station. Every sector is sealed, numbered, and watched from above.",
		},
		{
			id: "archive-assignment",
			title: "ARCHIVE 02 // YOUR ASSIGNMENT",
			text: "Operator Ciela, your brief is simple: cross the changing sectors, recover the signal core, and bring the facility back online.",
		},
		{
			id: "archive-breach",
			title: "ARCHIVE 03 // THE BREACH",
			text: "The first hostile forms arrived as a pressure wave. The doors held for seven minutes. Then the lights learned to move.",
		},
		{
			id: "archive-hostiles",
			title: "ARCHIVE 04 // HOSTILE PATTERNS",
			text: "Chasers follow heat. Skirmishers follow motion. Neither pattern survives a quiet operator who keeps the walls between them.",
		},
		{
			id: "archive-sectors",
			title: "ARCHIVE 05 // SHIFTING SECTORS",
			text: "The sector lattice rebuilds itself after every failed attempt. The route changes, but its emergency connectors always meet at the center line.",
		},
		{
			id: "archive-signal-core",
			title: "ARCHIVE 06 // THE SIGNAL CORE",
			text: "At the final door, the core is still broadcasting. Recover it and the containment network can remember how to close.",
		},
	];
}
