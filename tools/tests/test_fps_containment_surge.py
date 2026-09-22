"""Protect the Containment Surge contract and controller integration."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SECTOR = ROOT / "project/bugbugbug/scripts/fps_sector_contract/fps_sector_contract.gml"
GAMEPLAY_STATE = ROOT / "project/bugbugbug/scripts/fps_gameplay_state/fps_gameplay_state.gml"
CONTROLLER_CREATE = ROOT / "project/bugbugbug/objects/obj_fps_controller/Create_0.gml"
CONTROLLER_STEP = ROOT / "project/bugbugbug/objects/obj_fps_controller/Step_0.gml"
WORLD_DRAW = ROOT / "project/bugbugbug/objects/obj_fps_controller/Draw_0.gml"
HUD_DRAW = ROOT / "project/bugbugbug/objects/obj_fps_controller/Draw_64.gml"
README = ROOT / "project/README.md"


class FpsContainmentSurgeStructureTests(unittest.TestCase):
    """Keep hazard placement, state, reset, and presentation on shared paths."""

    @classmethod
    def setUpClass(cls):
        cls.sector = SECTOR.read_text(encoding="utf-8")
        cls.gameplay_state = GAMEPLAY_STATE.read_text(encoding="utf-8")
        cls.controller_create = CONTROLLER_CREATE.read_text(encoding="utf-8")
        cls.controller_step = CONTROLLER_STEP.read_text(encoding="utf-8")
        cls.world_draw = WORLD_DRAW.read_text(encoding="utf-8")
        cls.hud_draw = HUD_DRAW.read_text(encoding="utf-8")
        cls.readme = README.read_text(encoding="utf-8")

    def test_sector_contract_places_only_deterministic_combat_hazards(self):
        """Placement uses clear-point geometry and stable tile identities."""
        for required in (
            "FPS_SECTOR_CONTAINMENT_SURGE_RADIUS",
            "function fps_sector_make_containment_surge",
            "containment_surges: []",
            "fps_sector_containment_surge_for_tile",
            "fps_sector_containment_surge_contains",
            "fps_sector_containment_surge_exposed",
            "fps_sector_first_clear_point",
            "FPS_SECTOR_ROLE_COMBAT",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.sector)

    def test_cycle_contract_is_fixed_and_one_shot(self):
        """State transitions are fixed, room-scoped, and idempotent per cycle."""
        for required in (
            "FPS_CONTAINMENT_SURGE_IDLE_FRAMES 90",
            "FPS_CONTAINMENT_SURGE_WARNING_FRAMES 45",
            "FPS_CONTAINMENT_SURGE_ACTIVE_FRAMES 30",
            "FPS_CONTAINMENT_SURGE_DAMAGE 12",
            "function fps_containment_surge_create_state",
            "function fps_containment_surge_tick",
            "function fps_containment_surge_can_damage",
            "function fps_containment_surge_mark_damaged",
            "_state.damage_cycle = -1",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.gameplay_state)

    def test_controller_gates_damage_and_resets_hazard_per_room_or_run(self):
        """Runtime damage uses canonical cover/dash gates and clears on reset."""
        for required in (
            "configure_containment_surge = method",
            "containment_surge_state = is_struct(containment_surge)",
            "fps_sector_containment_surge_exposed(sector, containment_surge, x, y)",
            "fps_dash_blocks_damage(dash)",
            "containment_surge_state = fps_containment_surge_mark_damaged(containment_surge_state);",
            "configure_containment_surge();",
            "containment_surge = undefined;",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.controller_create)

        self.assertIn("tick_containment_surge();", self.controller_step)

    def test_world_and_hud_present_the_existing_runtime_marker(self):
        """The warning mesh and native HUD identify the active room hazard."""
        self.assertIn("vertex_submit(enemy_warning_buffer", self.world_draw)
        self.assertIn("fps_containment_surge_phase_name", self.hud_draw)
        self.assertIn("CONTAINMENT SURGE", self.hud_draw)
        self.assertIn("IDLE", self.readme)
        self.assertIn("WARNING", self.readme)
        self.assertIn("ACTIVE", self.readme)


if __name__ == "__main__":
    unittest.main()
