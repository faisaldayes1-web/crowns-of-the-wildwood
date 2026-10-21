"""Agent: Codex-faisal. Real Windows junction regressions; retain inert evidence."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import uuid

MODULE = Path(__file__).resolve().parents[1] / "steam" / "check_depot.py"
SPEC = importlib.util.spec_from_file_location("junction_depot", MODULE)
depot = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(depot)


@unittest.skipUnless(os.name == "nt" and hasattr(Path, "is_junction"), "Windows Python 3.12 junction fixture")
class JunctionTests(unittest.TestCase):
    def setUp(self):
        base = Path(os.environ.get("ORY_DEPOT_FIXTURE_ROOT", str(Path(tempfile.gettempdir()) / "ory-depot-junction-evidence"))).resolve()
        self.root = base / uuid.uuid4().hex
        self.root.mkdir(parents=True)
        self.candidate = self.root / "candidate"
        self.outside = self.root / "outside"
        for directory in (self.candidate, self.outside):
            directory.mkdir()
            for name in depot.REQUIRED:
                (directory / name).write_bytes(b"inert junction regression fixture")
        (self.outside / "outside-only.txt").write_text("must not be inventoried")

    def junction(self, link, target):
        self.assertTrue(link.absolute().is_relative_to(self.root))
        self.assertTrue(target.resolve().is_relative_to(self.root))
        subprocess.run(["cmd", "/c", "mklink", "/J", str(link), str(target)], check=True, capture_output=True)
        self.assertTrue(link.is_junction())

    def test_root_junction_rejected_without_inventory(self):
        self.junction(self.root / "root-link", self.outside)
        report = depot.inspect_depot(self.root / "root-link")
        self.assertEqual(report["status"], "FAIL")
        self.assertEqual(report["files"], [])

    def test_nested_junction_rejected_and_not_traversed(self):
        self.junction(self.candidate / "linked-content", self.outside)
        report = depot.inspect_depot(self.candidate)
        self.assertEqual(report["status"], "FAIL")
        self.assertTrue(any("linked-content" in error for error in report["errors"]))
        self.assertEqual(len(report["files"]), len(depot.REQUIRED))
        self.assertFalse(any("outside-only" in row["path"] for row in report["files"]))


if __name__ == "__main__":
    unittest.main()
