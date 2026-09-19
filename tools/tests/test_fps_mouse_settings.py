"""Protect the profile-backed mouse settings contract and controller wiring."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROFILE = ROOT / "project/bugbugbug/scripts/fps_profile_data/fps_profile_data.gml"
PROGRESSION = ROOT / "project/bugbugbug/scripts/fps_run_progression/fps_run_progression.gml"
CONTROLLER_CREATE = ROOT / "project/bugbugbug/objects/obj_fps_controller/Create_0.gml"
CONTROLLER_STEP = ROOT / "project/bugbugbug/objects/obj_fps_controller/Step_0.gml"
DRAW_EVENT = ROOT / "project/bugbugbug/objects/obj_fps_controller/Draw_64.gml"
CONTROLS_DOC = ROOT / "project/README.md"


class FpsMouseSettingsStructureTests(unittest.TestCase):
    """Keep persisted settings, title navigation, and captured input connected."""

    @classmethod
    def setUpClass(cls):
        cls.profile = PROFILE.read_text(encoding="utf-8")
        cls.progression = PROGRESSION.read_text(encoding="utf-8")
        cls.controller_create = CONTROLLER_CREATE.read_text(encoding="utf-8")
        cls.controller_step = CONTROLLER_STEP.read_text(encoding="utf-8")
        cls.draw_event = DRAW_EVENT.read_text(encoding="utf-8")
        cls.controls_doc = CONTROLS_DOC.read_text(encoding="utf-8")

    def test_profile_versions_and_field_level_fallback_are_present(self):
        """The v1 profile remains readable while invalid new fields default safely."""
        self.assertIn("#macro FPS_PROFILE_SAVE_VERSION 2", self.profile)
        self.assertIn("#macro FPS_PROFILE_LEGACY_SAVE_VERSION 1", self.profile)
        self.assertIn("mouse_sensitivity: FPS_PROFILE_DEFAULT_MOUSE_SENSITIVITY", self.profile)
        self.assertIn("invert_vertical_look: false", self.profile)
        self.assertIn("fps_profile_normalize_mouse_sensitivity", self.profile)
        self.assertIn("fps_profile_normalize_invert_vertical_look", self.profile)
        self.assertIn('ini_write_real("settings", "mouse_sensitivity"', self.profile)
        self.assertIn('ini_read_real("settings", "invert_vertical_look"', self.profile)

    def test_settings_state_stays_inside_the_existing_run_contract(self):
        """The controls screen adds one state without a second input owner."""
        self.assertIn("#macro FPS_RUN_SETTINGS 7", self.progression)
        self.assertIn("open_settings = method", self.controller_create)
        self.assertIn("close_settings = method", self.controller_create)
        self.assertIn("adjust_settings = method", self.controller_create)
        self.assertIn('keyboard_check_pressed(ord("C"))', self.controller_step)
        self.assertIn("if (run_state == FPS_RUN_SETTINGS)", self.controller_step)
        self.assertIn("run_contract.phase = FPS_RUN_SETTINGS", self.controller_create)
        self.assertIn("run_contract.phase = FPS_RUN_TITLE", self.controller_create)

    def test_captured_mouse_uses_both_selected_settings(self):
        """The next input frame reads the persisted sensitivity and inversion."""
        self.assertIn("fps_profile_apply_vertical_look(", self.controller_step)
        self.assertIn("mouse_sensitivity", self.controller_step)
        self.assertIn("invert_vertical_look", self.controller_step)
        self.assertIn("apply_profile_settings();", self.controller_create)
        self.assertIn("CONTROLS // AIM SETTINGS", self.draw_event)
        self.assertIn("FPS_PROFILE_MIN_MOUSE_SENSITIVITY", self.draw_event)
        self.assertIn("FPS_PROFILE_MAX_MOUSE_SENSITIVITY", self.draw_event)

    def test_controls_are_documented_without_removing_existing_routes(self):
        """Documentation names the settings route and preserves existing controls."""
        self.assertIn("`C`: open title controls", self.controls_doc)
        for control in ("`WASD`", "Mouse", "`E`", "`Esc`", "`S`", "`A`", "`X`"):
            with self.subTest(control=control):
                self.assertIn(control, self.controls_doc)
        self.assertIn("mouse sensitivity", self.controls_doc)
        self.assertIn("vertical-look inversion", self.controls_doc)


if __name__ == "__main__":
    unittest.main()
