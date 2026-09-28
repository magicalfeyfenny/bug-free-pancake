"""Protect signal-fragment placement, scoring, and controller wiring."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SECTOR = ROOT / "project/bugbugbug/scripts/fps_sector_contract/fps_sector_contract.gml"
PROGRESSION = ROOT / "project/bugbugbug/scripts/fps_run_progression/fps_run_progression.gml"
CONTROLLER = ROOT / "project/bugbugbug/objects/obj_fps_controller/Create_0.gml"
STEP_EVENT = ROOT / "project/bugbugbug/objects/obj_fps_controller/Step_0.gml"
WORLD_DRAW = ROOT / "project/bugbugbug/objects/obj_fps_controller/Draw_0.gml"
HUD_DRAW = ROOT / "project/bugbugbug/objects/obj_fps_controller/Draw_64.gml"
FRAGMENT_TESTS = ROOT / "project/bugbugbug/scripts/fps_signal_fragment_tests/fps_signal_fragment_tests.gml"
PROJECT = ROOT / "project/bugbugbug/bugbugbug.yyp"


def function_body(source, name):
    """Return one named GML function through the next function declaration."""
    start = source.index(f"function {name}(")
    end = source.find("\nfunction ", start + 1)
    return source[start:] if end < 0 else source[start:end]


class FpsSignalFragmentTests(unittest.TestCase):
    """Keep deterministic socket and run-scoped collection paths connected."""

    @classmethod
    def setUpClass(cls):
        cls.sector = SECTOR.read_text(encoding="utf-8")
        cls.progression = PROGRESSION.read_text(encoding="utf-8")
        cls.controller = CONTROLLER.read_text(encoding="utf-8")
        cls.step_event = STEP_EVENT.read_text(encoding="utf-8")
        cls.world_draw = WORLD_DRAW.read_text(encoding="utf-8")
        cls.hud_draw = HUD_DRAW.read_text(encoding="utf-8")
        cls.fragment_tests = FRAGMENT_TESTS.read_text(encoding="utf-8")
        cls.project = PROJECT.read_text(encoding="utf-8")

    def test_sector_generation_owns_distinct_stable_middle_tile_sockets(self):
        """Fragments use their own stable sockets and avoid occupied points."""
        placement = function_body(self.sector, "fps_sector_add_signal_fragment_sockets")
        generation_start = self.sector.index("function fps_sector_generate(")
        generation_end = self.sector.index("/// Projects generated tiles", generation_start)
        generation = self.sector[generation_start:generation_end]

        self.assertIn("signal_fragment_sockets: []", generation)
        self.assertIn("fps_sector_add_signal_fragment_sockets(_sector);", generation)
        self.assertIn("_tile_index = 2", placement)
        self.assertIn("_tile_index < FPS_SECTOR_TILE_COUNT - 1", placement)
        self.assertIn("fps_sector_socket_position_is_available", placement)
        self.assertIn('"signal-fragment-" + _tile.id', placement)
        self.assertIn('"signal-fragment"', placement)
        self.assertIn("array_push(_sector.signal_fragment_sockets, _fragment)", placement)
        self.assertIn("array_push(_sector.sockets, _fragment)", placement)

        lookup = function_body(self.sector, "fps_sector_near_signal_fragment")
        self.assertIn("_collected_ids[_collected_index] == _fragment.id", lookup)
        self.assertIn("point_distance(_x, _y, _fragment.x, _fragment.y)", lookup)
        self.assertIn("_distance <= _range", lookup)

    def test_run_contract_awards_each_stable_fragment_id_once(self):
        """A fresh run owns its collected IDs and adds exactly 75 points once."""
        state = function_body(self.progression, "fps_run_create_state")
        collect = function_body(self.progression, "fps_run_collect_signal_fragment")

        self.assertIn("signal_fragments_collected: []", state)
        self.assertIn("#macro FPS_RUN_SCORE_SIGNAL_FRAGMENT 75", self.progression)
        self.assertIn("fps_run_has_score_award(_state.signal_fragments_collected, _fragment_id)", collect)
        self.assertIn("array_push(_state.signal_fragments_collected, _fragment_id)", collect)
        self.assertIn("_state.score += FPS_RUN_SCORE_SIGNAL_FRAGMENT", collect)
        self.assertIn("count: array_length(_state.signal_fragments_collected)", collect)

    def test_controller_interaction_and_displays_use_run_collection_state(self):
        """E collects nearby fragments in play; markers and summaries read the run ledger."""
        collect_start = self.controller.index("collect_signal_fragment = method")
        collect_end = self.controller.index("/// Pauses the active run", collect_start)
        collect = self.controller[collect_start:collect_end]
        interaction_start = self.step_event.rindex('if (keyboard_check_pressed(ord("E"))) {')
        step_interaction = self.step_event[
            interaction_start:
            self.step_event.index("var _near_lore", interaction_start)
        ]

        self.assertIn("run_state != FPS_RUN_PLAYING", collect)
        self.assertIn("phase != FPS_STATE_PLAYING", collect)
        self.assertIn("point_distance(x, y, _fragment.x, _fragment.y)", collect)
        self.assertIn("fps_run_collect_signal_fragment(run_contract, _fragment.id)", collect)
        self.assertNotIn("room_complete", collect)
        self.assertNotIn("fps_profile_", collect)
        self.assertIn("fps_sector_near_signal_fragment", step_interaction)
        self.assertIn("collect_signal_fragment(_near_fragment)", step_interaction)

        self.assertIn("signal_fragment_buffer", self.world_draw)
        self.assertIn("run_contract.signal_fragments_collected", self.world_draw)
        self.assertIn('"   SIGNAL FRAGMENTS "', self.hud_draw)
        self.assertIn('"SIGNAL FRAGMENTS "', self.hud_draw)
        self.assertIn('"PRESS E TO COLLECT SIGNAL FRAGMENT"', self.hud_draw)
        self.assertIn('"name":"fps_signal_fragment_tests"', self.project)
        self.assertIn("collects from its tile before and after room clear", self.fragment_tests)
        self.assertIn("places three clear, stable sockets away from archives and supplies", self.fragment_tests)


if __name__ == "__main__":
    unittest.main()
