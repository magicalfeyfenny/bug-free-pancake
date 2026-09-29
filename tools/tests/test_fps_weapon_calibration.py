"""Protect calibration reward flow through the run, controller, and HUD."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WEAPONS = ROOT / "project/bugbugbug/scripts/fps_weapon_system/fps_weapon_system.gml"
PROGRESSION = ROOT / "project/bugbugbug/scripts/fps_run_progression/fps_run_progression.gml"
CONTROLLER = ROOT / "project/bugbugbug/objects/obj_fps_controller/Create_0.gml"
STEP_EVENT = ROOT / "project/bugbugbug/objects/obj_fps_controller/Step_0.gml"
HUD = ROOT / "project/bugbugbug/objects/obj_fps_controller/Draw_64.gml"
PROJECT = ROOT / "project/bugbugbug/bugbugbug.yyp"


def function_body(source, name):
    """Return one named GML function through the next function declaration."""
    start = source.index(f"function {name}(")
    end = source.find("\nfunction ", start + 1)
    return source[start:] if end < 0 else source[start:end]


class FpsWeaponCalibrationTests(unittest.TestCase):
    """Check that the deterministic reward and its HUD state stay connected."""

    @classmethod
    def setUpClass(cls):
        cls.weapons = WEAPONS.read_text(encoding="utf-8")
        cls.progression = PROGRESSION.read_text(encoding="utf-8")
        cls.controller = CONTROLLER.read_text(encoding="utf-8")
        cls.step_event = STEP_EVENT.read_text(encoding="utf-8")
        cls.hud = HUD.read_text(encoding="utf-8")
        cls.project = PROJECT.read_text(encoding="utf-8")

    def test_loadout_and_shared_shot_boundary_own_run_scoped_damage(self):
        """Calibration belongs to mutable weapon state and affects each shot once."""
        create_state = function_body(self.weapons, "fps_weapon_create_state")
        calibration = function_body(self.weapons, "fps_weapon_calibration_available")
        apply_calibration = function_body(self.weapons, "fps_weapon_calibrate_current")
        start_shot = function_body(self.weapons, "fps_weapon_start_shot")

        self.assertIn("calibrated: false", create_state)
        self.assertIn("_loadout.states[_state_index].calibrated", calibration)
        self.assertIn("_state.calibrated = true", apply_calibration)
        self.assertIn("if (_state.calibrated)", start_shot)
        self.assertIn("_damage *= FPS_WEAPON_CALIBRATION_MULTIPLIER", start_shot)
        self.assertIn("FPS_WEAPON_CALIBRATION_MULTIPLIER 1.1", self.weapons)
        self.assertIn("pattern: fps_weapon_shot_pattern(_definition)", start_shot)

    def test_reward_pool_and_application_use_loadout_state(self):
        """Selection records one calibration and removes it from future pools."""
        reward_pool = function_body(self.progression, "fps_run_reward_pool")
        reward_choices = function_body(self.progression, "fps_run_create_reward_choices")
        apply_reward = function_body(self.progression, "fps_run_apply_reward")
        signature = function_body(self.progression, "fps_run_reward_signature")

        self.assertIn("FPS_RUN_REWARD_CALIBRATION 6", self.progression)
        self.assertIn("fps_weapon_calibration_available(_loadout)", reward_pool)
        self.assertIn('label: "CALIBRATION"', reward_pool)
        self.assertIn("fps_run_reward_pool(_profile, _loadout)", reward_choices)
        self.assertIn("fps_weapon_calibrate_current(_loadout)", apply_reward)
        self.assertIn("case FPS_RUN_REWARD_CALIBRATION: return", self.progression)
        self.assertIn("string(_choice.kind)", signature)
        self.assertIn("string(_weapon_id)", signature)
        self.assertIn('variable_struct_exists(_choice, "weapon_id")', signature)

    def test_controller_feeds_the_card_and_calibrated_marker_to_existing_hud(self):
        """Reward text and per-weapon status reach the current panels and controls."""
        begin_reward_start = self.controller.index("begin_reward = method")
        begin_reward_end = self.controller.index("/// Applies one reward card", begin_reward_start)
        begin_reward = self.controller[begin_reward_start:begin_reward_end]
        choose_reward_start = self.controller.index("choose_reward = method")
        choose_reward_end = self.controller.index("/// Ends a run exactly once", choose_reward_start)
        choose_reward = self.controller[choose_reward_start:choose_reward_end]
        reward_panel_start = self.hud.index("if (run_state == FPS_RUN_REWARD)")
        reward_panel_end = self.hud.index("if (run_state == FPS_RUN_SUMMARY)", reward_panel_start)
        reward_panel = self.hud[reward_panel_start:reward_panel_end]

        self.assertIn("fps_run_create_reward_choices(sector_seed, run_room_index, profile, loadout)", begin_reward)
        self.assertIn("fps_run_apply_reward(_choice, loadout", choose_reward)
        self.assertIn("_choice.label", reward_panel)
        self.assertIn("_choice.description", reward_panel)
        self.assertIn("_current_state.calibrated", self.hud)
        self.assertIn("_weapon_state.calibrated", self.hud)
        self.assertIn("CALIBRATED", self.hud)
        self.assertIn('choose_reward(0)', self.step_event)
        self.assertIn('choose_reward(1)', self.step_event)
        self.assertIn('choose_reward(2)', self.step_event)
        self.assertIn('"name":"fps_weapon_calibration_tests"', self.project)


if __name__ == "__main__":
    unittest.main()
