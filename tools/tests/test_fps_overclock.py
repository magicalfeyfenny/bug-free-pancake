"""Protect the selected run protocol across timing, score, and presentation paths."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROGRESSION = ROOT / "project/bugbugbug/scripts/fps_run_progression/fps_run_progression.gml"
GAMEPLAY_STATE = ROOT / "project/bugbugbug/scripts/fps_gameplay_state/fps_gameplay_state.gml"
CONTROLLER_CREATE = ROOT / "project/bugbugbug/objects/obj_fps_controller/Create_0.gml"
CONTROLLER_STEP = ROOT / "project/bugbugbug/objects/obj_fps_controller/Step_0.gml"
HUD = ROOT / "project/bugbugbug/objects/obj_fps_controller/Draw_64.gml"
PROJECT = ROOT / "project/bugbugbug/bugbugbug.yyp"
TEST_SCRIPT = ROOT / "project/bugbugbug/scripts/fps_overclock_tests/fps_overclock_tests.gml"
README = ROOT / "project/README.md"


class FpsOverclockStructureTests(unittest.TestCase):
    """Keep protocol state inside current run, enemy, controller, and HUD contracts."""

    @classmethod
    def setUpClass(cls):
        cls.progression = PROGRESSION.read_text(encoding="utf-8")
        cls.gameplay_state = GAMEPLAY_STATE.read_text(encoding="utf-8")
        cls.controller_create = CONTROLLER_CREATE.read_text(encoding="utf-8")
        cls.controller_step = CONTROLLER_STEP.read_text(encoding="utf-8")
        cls.hud = HUD.read_text(encoding="utf-8")
        cls.project = PROJECT.read_text(encoding="utf-8")
        cls.test_script = TEST_SCRIPT.read_text(encoding="utf-8")
        cls.readme = README.read_text(encoding="utf-8")

    def test_protocol_is_run_scoped_and_standard_remains_the_default(self):
        """New contracts default to Standard and preserve a selected mode through lifecycle changes."""
        self.assertIn("#macro FPS_RUN_PROTOCOL_STANDARD 0", self.progression)
        self.assertIn("#macro FPS_RUN_PROTOCOL_OVERCLOCK 1", self.progression)
        self.assertIn("protocol: fps_run_normalize_protocol(_protocol)", self.progression)
        self.assertIn("fps_run_create_state(_seed, _protocol = FPS_RUN_PROTOCOL_STANDARD)", self.progression)
        self.assertIn("fps_run_begin(_seed, _protocol = FPS_RUN_PROTOCOL_STANDARD)", self.progression)
        self.assertIn("_state = fps_run_create_state(_seed, _protocol)", self.progression)
        self.assertIn("_state.protocol == FPS_RUN_PROTOCOL_OVERCLOCK", self.progression)

    def test_protocol_only_changes_attack_cadence_and_score_awards(self):
        """Enemy phase delays and existing score awards apply the fixed protocol values."""
        self.assertIn("(_base_delay * 4) div 5", self.gameplay_state)
        self.assertIn("max(1, (_base_delay * 4) div 5)", self.gameplay_state)
        self.assertIn("fps_enemy_attack_delay_for_protocol(", self.gameplay_state)
        self.assertIn("_enemy.run_protocol", self.gameplay_state)
        self.assertIn("fps_run_score_points(_state, fps_run_enemy_score(_kind))", self.progression)
        self.assertIn("fps_run_score_points(_state, fps_run_room_score(_is_finale))", self.progression)

    def test_controller_selection_and_generation_paths_stay_separate(self):
        """Title input selects a run mode while seeded generation keeps its existing arguments."""
        self.assertIn("title_protocol = FPS_RUN_PROTOCOL_STANDARD", self.controller_create)
        self.assertIn("select_title_protocol = method", self.controller_create)
        self.assertIn("fps_enemy_apply_role(_enemy, _entry.kind, run_contract.protocol)", self.controller_create)
        selection_start = self.controller_create.index("select_title_protocol = method")
        selection_end = self.controller_create.index("/// Copies validated profile aim settings", selection_start)
        self.assertNotIn("fps_profile_save", self.controller_create[selection_start:selection_end])
        self.assertIn('keyboard_check_pressed(ord("P"))', self.controller_step)
        self.assertIn("select_title_protocol(_next_protocol)", self.controller_step)
        self.assertIn("run_contract = fps_run_begin(sector_seed, title_protocol)", self.controller_create)
        self.assertIn("run_contract = fps_run_create_state(real(seed_input), title_protocol)", self.controller_create)
        self.assertIn("run_contract = fps_run_create_state(real(seed_input), title_protocol)", self.controller_step)

        plan_start = self.progression.index("function fps_run_create_room_plan")
        plan_end = self.progression.index("/// Creates the base and profile-expanded reward pool", plan_start)
        self.assertNotIn("protocol", self.progression[plan_start:plan_end])

    def test_title_hud_and_summary_expose_the_selected_protocol(self):
        """The title offers selection and active and terminal displays read the run contract."""
        self.assertIn('"P  SWITCH PROTOCOL  //  " + fps_run_protocol_name(title_protocol)', self.hud)
        self.assertIn('"   PROTOCOL " + fps_run_protocol_name(run_contract.protocol)', self.hud)
        summary_start = self.hud.index("if (run_state == FPS_RUN_SUMMARY)")
        summary_end = self.hud.index("if (", summary_start + 1)
        self.assertIn('"PROTOCOL " + fps_run_protocol_name(run_contract.protocol)', self.hud[summary_start:summary_end])

    def test_focused_gamemaker_suite_is_registered_and_documents_the_control(self):
        """The dedicated deterministic suite is a project resource and its control is documented."""
        self.assertIn('"name":"fps_overclock_tests"', self.project)
        self.assertIn("fps_overclock_tests.yy", self.project)
        self.assertIn('suite(function() {', self.test_script)
        for claim in (
            '"keeps generated layout, encounter, pickup, and reward signatures independent of protocol"',
            '"uses exact whole-frame 80 percent attack delays with a one-frame minimum"',
            '"applies run timing to every role and the Titan Siege phase"',
            '"multiplies enemy and room awards exactly and keeps duplicate awards idempotent"',
            '"selects either title protocol and carries it through active and terminal run state"',
        ):
            with self.subTest(claim=claim):
                self.assertIn(claim, self.test_script)
        self.assertIn("`P`: switch between `STANDARD` and `OVERCLOCK`", self.readme)
        self.assertIn("80% of each enemy attack delay", self.readme)


if __name__ == "__main__":
    unittest.main()
