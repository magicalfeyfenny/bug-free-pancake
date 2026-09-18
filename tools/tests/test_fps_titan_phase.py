"""Protect the Titan's bounded phase contract and existing combat wiring."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
GAMEPLAY_STATE = ROOT / "project/bugbugbug/scripts/fps_gameplay_state/fps_gameplay_state.gml"
ENEMY_CREATE = ROOT / "project/bugbugbug/objects/obj_fps_enemy/Create_0.gml"
HUD = ROOT / "project/bugbugbug/objects/obj_fps_controller/Draw_64.gml"
README = ROOT / "project/README.md"


class FpsTitanPhaseStructureTests(unittest.TestCase):
    """Keep phase selection in the Titan role and preserve shared combat paths."""

    @classmethod
    def setUpClass(cls):
        cls.gameplay_state = GAMEPLAY_STATE.read_text(encoding="utf-8")
        cls.enemy_create = ENEMY_CREATE.read_text(encoding="utf-8")
        cls.hud = HUD.read_text(encoding="utf-8")
        cls.readme = README.read_text(encoding="utf-8")

    def test_titan_role_owns_named_threshold_and_phase_values(self):
        """The role contract defines the named first and second phases."""
        titan_start = self.gameplay_state.index("case FPS_ENEMY_KIND_TITAN:")
        titan_end = self.gameplay_state.index(
            "\n\t}\n\n\treturn fps_enemy_role_definition",
            titan_start,
        )
        titan_block = self.gameplay_state[titan_start:titan_end]

        for required in (
            'phase_name: "AWAKENING"',
            "phase_threshold: FPS_TITAN_PHASE_TWO_THRESHOLD",
            'name: "SIEGE"',
            "move_speed: 1.65",
            "attack_damage: 40",
            "telegraph_frames: 44",
        ):
            with self.subTest(required=required):
                self.assertIn(required, titan_block)

    def test_damage_transition_uses_existing_notice_and_telegraph_paths(self):
        """Damage changes the role state and reports it through current UI/combat hooks."""
        self.assertIn("fps_enemy_update_phase(id)", self.enemy_create)
        self.assertIn(
            '_phase_player.set_pickup_notice("TITAN PHASE SHIFT // " + combat_phase_name);',
            self.enemy_create,
        )
        self.assertIn("function fps_enemy_apply_combat_phase", self.gameplay_state)
        self.assertIn("function fps_enemy_update_phase", self.gameplay_state)
        titan_step_start = self.gameplay_state.index("function fps_enemy_step_titan")
        titan_step_end = self.gameplay_state.index("/// Dispatches one frame", titan_step_start)
        titan_step = self.gameplay_state[titan_step_start:titan_step_end]
        self.assertIn("fps_enemy_begin_telegraph(", titan_step)
        self.assertIn("_enemy.telegraph_max_frames", titan_step)
        self.assertIn("_enemy.warning_shape", titan_step)
        self.assertIn("fps_sector_line_blocked", titan_step)

    def test_hud_and_documentation_expose_the_named_phase(self):
        """The active enemy HUD and player documentation identify the escalation."""
        self.assertIn('variable_instance_exists(_enemy, "combat_phase_name")', self.hud)
        self.assertIn('_hostile_name += " // " + _enemy.combat_phase_name;', self.hud)
        self.assertIn("AWAKENING", self.readme)
        self.assertIn("SIEGE", self.readme)


if __name__ == "__main__":
    unittest.main()
