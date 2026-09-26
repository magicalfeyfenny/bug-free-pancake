"""Protect the Barrier Warden role and its existing encounter integrations."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
GAMEPLAY = ROOT / "project/bugbugbug/scripts/fps_gameplay_state/fps_gameplay_state.gml"
WARDEN_COMBAT = ROOT / "project/bugbugbug/scripts/fps_warden_combat/fps_warden_combat.gml"
PROGRESSION = ROOT / "project/bugbugbug/scripts/fps_run_progression/fps_run_progression.gml"
GEOMETRY = ROOT / "project/bugbugbug/scripts/fps_render_geometry/fps_render_geometry.gml"
CONTROLLER = ROOT / "project/bugbugbug/objects/obj_fps_controller/Create_0.gml"
ENEMY_STEP = ROOT / "project/bugbugbug/objects/obj_fps_enemy/Step_0.gml"
ENEMY_DRAW = ROOT / "project/bugbugbug/objects/obj_fps_controller/Draw_0.gml"
HUD = ROOT / "project/bugbugbug/objects/obj_fps_controller/Draw_64.gml"
GAMEPLAY_TESTS = ROOT / "project/bugbugbug/scripts/fps_warden_tests/fps_warden_tests.gml"
PROJECT = ROOT / "project/bugbugbug/bugbugbug.yyp"
README = ROOT / "project/README.md"


def function_block(source, name):
    """Return one documented GML function without relying on later file order."""
    start = source.index(f"function {name}(")
    end = source.find("\n/// ", start + 1)
    return source[start:] if end < 0 else source[start:end]


class FpsWardenStructureTests(unittest.TestCase):
    """Keep role behavior connected to combat, scoring, visuals, and tests."""

    @classmethod
    def setUpClass(cls):
        cls.gameplay = GAMEPLAY.read_text(encoding="utf-8")
        cls.warden_combat = WARDEN_COMBAT.read_text(encoding="utf-8")
        cls.progression = PROGRESSION.read_text(encoding="utf-8")
        cls.geometry = GEOMETRY.read_text(encoding="utf-8")
        cls.controller = CONTROLLER.read_text(encoding="utf-8")
        cls.enemy_step = ENEMY_STEP.read_text(encoding="utf-8")
        cls.enemy_draw = ENEMY_DRAW.read_text(encoding="utf-8")
        cls.hud = HUD.read_text(encoding="utf-8")

    def test_warden_is_a_named_role_before_the_reserved_titan(self):
        """The final kind remains Titan so ordinary plans can exclude it."""
        self.assertIn("#macro FPS_ENEMY_KIND_WARDEN 4", self.gameplay)
        self.assertIn("#macro FPS_ENEMY_KIND_TITAN 5", self.gameplay)
        self.assertIn("#macro FPS_ENEMY_KIND_COUNT 6", self.gameplay)
        self.assertIn('identity: "warden"', self.gameplay)
        self.assertIn('label: "WARDEN"', self.gameplay)

    def test_barrier_cycle_and_front_arc_are_role_scoped(self):
        """Only a raised Warden barrier blocks a hit inside the declared arc."""
        apply_role = function_block(self.gameplay, "fps_enemy_apply_role")
        cycle = function_block(self.warden_combat, "fps_enemy_update_warden_barrier")
        hit_gate = function_block(self.warden_combat, "fps_enemy_weapon_hit_blocked")

        self.assertIn("barrier_up_frames: 96", self.gameplay)
        self.assertIn("barrier_open_frames: 36", self.gameplay)
        self.assertIn("barrier_arc_half_angle: 60", self.gameplay)
        self.assertIn("FPS_WARDEN_BARRIER_UP", apply_role)
        self.assertIn("FPS_WARDEN_BARRIER_OPEN", cycle)
        self.assertIn("combat_phase_name", cycle)
        self.assertIn("FPS_WARDEN_BARRIER_UP", hit_gate)
        self.assertIn("angle_difference", hit_gate)
        self.assertIn("warden_barrier_arc_half_angle", hit_gate)

    def test_warden_strike_uses_shared_movement_warning_and_cover_resolution(self):
        """The new attack enters the existing area-telegraph path."""
        step_warden = function_block(self.gameplay, "fps_enemy_step_warden")
        resolve = function_block(self.gameplay, "fps_enemy_resolve_telegraph")

        self.assertIn("fps_enemy_move_toward", step_warden)
        self.assertIn("fps_enemy_begin_telegraph", step_warden)
        self.assertIn("fps_sector_line_blocked", step_warden)
        self.assertIn("case FPS_ENEMY_KIND_WARDEN", resolve)
        self.assertLess(resolve.index("fps_sector_line_blocked"), resolve.index("switch ("))
        self.assertIn("fps_enemy_update_warden_barrier(id)", self.enemy_step)
        self.assertIn("fps_enemy_turn_warden(id, _player)", self.enemy_step)

    def test_weapon_hits_pass_through_the_barrier_gate_before_damage(self):
        """A blocked ray stops at the Warden while ordinary hits keep their path."""
        start = self.controller.index("fire_weapon_rays = method")
        end = self.controller.index("\n});", start) + len("\n});")
        fire_rays = self.controller[start:end]
        gate = fire_rays.index("fps_enemy_weapon_hit_blocked")
        damage = fire_rays.index("_nearest_enemy.take_damage(_shot.damage)")
        self.assertLess(gate, damage)

    def test_seeded_room_plan_reserves_titan_and_scores_warden(self):
        """Room composition and duplicate-safe scoring include the new role."""
        create_plan = function_block(self.progression, "fps_run_create_room_plan")
        self.assertIn("_is_finale ? FPS_ENEMY_KIND_COUNT : FPS_ENEMY_KIND_COUNT - 1", create_plan)
        self.assertIn("_kind = FPS_ENEMY_KIND_TITAN", create_plan)
        self.assertIn("#macro FPS_RUN_SCORE_WARDEN 200", self.progression)
        self.assertIn("case FPS_ENEMY_KIND_WARDEN: return FPS_RUN_SCORE_WARDEN", self.progression)
        self.assertIn("fps_enemy_weapon_hit_blocked", self.controller)
        self.assertIn("fps_enemy_apply_role(_enemy, _entry.kind)", self.controller)

    def test_native_model_hud_and_registered_contract_tests_cover_warden(self):
        """Procedural geometry, barrier state, and focused evidence reach the project."""
        self.assertIn("case FPS_ENEMY_KIND_WARDEN", self.geometry)
        self.assertIn("_enemy.warden_facing_angle", self.enemy_draw)
        self.assertIn('_hostile_name += " // " + _enemy.combat_phase_name;', self.hud)
        project = PROJECT.read_text(encoding="utf-8")
        self.assertIn("scripts/fps_warden_combat/fps_warden_combat.yy", project)
        self.assertIn("scripts/fps_warden_tests/fps_warden_tests.yy", project)

        tests = GAMEPLAY_TESTS.read_text(encoding="utf-8")
        for required in (
            "barrier_up_frames",
            "barrier_open_frames",
            "fps_enemy_weapon_hit_blocked",
            "fps_enemy_resolve_telegraph",
            "fps_run_create_room_plan",
            "FPS_ENEMY_KIND_TITAN",
        ):
            with self.subTest(required=required):
                self.assertIn(required, tests)

        self.assertIn("Barrier Warden", README.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
