"""Protect the run score's contract and controller presentation wiring."""

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROGRESSION = ROOT / "project/bugbugbug/scripts/fps_run_progression/fps_run_progression.gml"
CONTROLLER = ROOT / "project/bugbugbug/objects/obj_fps_controller/Create_0.gml"
DRAW_EVENT = ROOT / "project/bugbugbug/objects/obj_fps_controller/Draw_64.gml"
ENEMY = ROOT / "project/bugbugbug/objects/obj_fps_enemy/Create_0.gml"


class FpsScoreHudStructureTests(unittest.TestCase):
    """Keep score state, event awards, and displayed summaries connected."""

    @classmethod
    def setUpClass(cls):
        cls.progression = PROGRESSION.read_text(encoding="utf-8")
        cls.controller = CONTROLLER.read_text(encoding="utf-8")
        cls.draw_event = DRAW_EVENT.read_text(encoding="utf-8")
        cls.enemy = ENEMY.read_text(encoding="utf-8")

    def test_run_contract_owns_score_and_duplicate_ledgers(self):
        """A fresh run owns score and stable award identities."""
        state_start = self.progression.index("function fps_run_create_state")
        state_end = self.progression.index("/// Starts a clean run", state_start)
        state_block = self.progression[state_start:state_end]

        self.assertIn("score: 0", state_block)
        self.assertIn("enemy_score_awards: []", state_block)
        self.assertIn("room_score_awards: []", state_block)
        self.assertIn("function fps_run_award_enemy", self.progression)
        self.assertIn("function fps_run_award_room", self.progression)
        self.assertIn("fps_run_has_score_award", self.progression)

    def test_controller_awards_at_event_boundaries(self):
        """Deaths and room transitions call the pure award contract."""
        self.assertIn("_player.award_enemy_score(id);", self.enemy)
        self.assertIn("fps_run_award_enemy(", self.controller)
        self.assertIn("fps_run_award_room(", self.controller)
        self.assertIn("award_room_score(false);", self.controller)
        self.assertIn("award_room_score(true);", self.controller)

    def test_hud_and_summary_read_score_from_run_contract(self):
        """Both active and terminal displays use the run contract score."""
        display_start = self.controller.index(
            "signal_fragment_display_values = method(id, function() {"
        )
        display_end = self.controller.index("\n});", display_start) + len("\n});")
        display_method = self.controller[display_start:display_end]

        self.assertIn("run_contract.score", display_method)
        self.assertEqual(self.draw_event.count("_signal_fragment_display.score_text"), 2)

        summary_start = self.draw_event.index("if (run_state == FPS_RUN_SUMMARY)")
        summary_end = self.draw_event.index("if (", summary_start + 1)
        summary_block = self.draw_event[summary_start:summary_end]
        self.assertRegex(summary_block, r"run_contract\.rooms_cleared")
        self.assertRegex(summary_block, r"_signal_fragment_display\.score_text")
        self.assertRegex(
            summary_block,
            r'"SEED "[\s\S]*run_contract\.rooms_cleared[\s\S]*_signal_fragment_display\.score_text',
        )

        route_start = self.draw_event.index("if (run_state == FPS_RUN_PLAYING)")
        self.assertLess(
            self.draw_event.index("_signal_fragment_display.score_text"),
            route_start,
        )


if __name__ == "__main__":
    unittest.main()
