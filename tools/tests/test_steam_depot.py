"""Agent: Codex-faisal. No engine, Steam client or network required."""
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[1] / "steam" / "check_depot.py"
SPEC = importlib.util.spec_from_file_location("check_depot", MODULE)
depot = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(depot)


class DepotTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in depot.REQUIRED:
            (self.root / name).write_bytes(b"fixture, not an executable")

    def test_complete_inventory_is_stable_and_hashed(self):
        first = depot.inspect_depot(self.root)
        self.assertEqual(first["status"], "PASS")
        self.assertEqual(first, depot.inspect_depot(self.root))
        self.assertEqual(len(first["files"]), 3)
        self.assertEqual(first["files"][0]["sha256"], hashlib.sha256(b"fixture, not an executable").hexdigest())

    def test_missing_required_file(self):
        (self.root / depot.REQUIRED[1]).unlink()
        self.assertEqual(depot.inspect_depot(self.root)["status"], "FAIL")

    def test_empty_binary(self):
        (self.root / depot.REQUIRED[0]).write_bytes(b"")
        self.assertEqual(depot.inspect_depot(self.root)["status"], "FAIL")

    def test_nested_case_insensitive_development_id(self):
        nested = self.root / "nested"
        nested.mkdir()
        (nested / "STEAM_APPID.TXT").write_text("480")
        report = depot.inspect_depot(self.root)
        self.assertEqual(report["status"], "FAIL")
        self.assertTrue(any("Development App ID" in error for error in report["errors"]))

    def test_missing_directory(self):
        self.assertEqual(depot.inspect_depot(self.root / "absent")["status"], "FAIL")

    def test_content_change_changes_hash(self):
        first = depot.inspect_depot(self.root)
        (self.root / depot.REQUIRED[0]).write_bytes(b"changed fixture")
        self.assertNotEqual(first["files"], depot.inspect_depot(self.root)["files"])


if __name__ == "__main__":
    unittest.main()
