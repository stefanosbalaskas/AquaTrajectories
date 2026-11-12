"""Wave 13F hard-fail scientific release gates and completeness contracts."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"inst/python"))
import aqt_scientific_release_gate as m


class ScientificReleaseGates(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest=ROOT/"inst/evidence/scientific-validation-gates.json"
        cls.object=json.loads(cls.manifest.read_text())

    def test_actual_nine_gate_registry_is_honest_and_complete(self):
        result=m.run(self.manifest)
        self.assertTrue(result["engineering_registry_complete"])
        self.assertFalse(result["scientific_release_permitted"])
        self.assertEqual(result["n_scientifically_blocked_milestones"],9)
        self.assertEqual(len(result["input_manifest_sha256"]),64)

    def test_self_certification_cannot_pass_as_independent_truth(self):
        copy=json.loads(json.dumps(self.object))
        copy["milestones"][0]["scientific_certified"]=True
        with self.assertRaisesRegex(ValueError,"Self-declared"):
            m.validate_manifest(copy)
        copy=json.loads(json.dumps(self.object))
        copy["scientific_release_approved"]=True
        with self.assertRaisesRegex(ValueError,"release approval"):
            m.validate_manifest(copy)

    def test_missing_and_duplicate_priority_records_fail(self):
        copy=json.loads(json.dumps(self.object))
        copy["milestones"].pop()
        with self.assertRaisesRegex(ValueError,"Exactly nine"):
            m.validate_manifest(copy)
        copy=json.loads(json.dumps(self.object))
        copy["milestones"][8]["id"]=1
        with self.assertRaisesRegex(ValueError,"unique"):
            m.validate_manifest(copy)

    def test_scientific_release_mode_fails_nonzero_even_with_valid_registry(self):
        with tempfile.TemporaryDirectory() as td:
            report=Path(td)/"readiness.json"
            code=m.main(["--manifest",str(self.manifest),
                         "--mode","engineering_registry","--report",str(report)])
            self.assertEqual(code,0)
            self.assertFalse(json.loads(report.read_text())["scientific_release_permitted"])
            with self.assertRaisesRegex(FileExistsError,"overwrite"):
                m.main(["--manifest",str(self.manifest),
                        "--mode","engineering_registry","--report",str(report)])
            exit_code=m.main(["--manifest",str(self.manifest),
                              "--mode","scientific_release"])
            self.assertEqual(exit_code,2)


if __name__=="__main__":
    unittest.main()
