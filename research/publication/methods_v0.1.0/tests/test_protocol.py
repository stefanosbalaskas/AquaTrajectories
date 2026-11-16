"""Fail-closed tests for dossier; do not create any biological results."""
import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from zipfile import ZipFile
import sys

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))
from verify import audit_protocol, ROOT, EXPECTED_TAG_COMMIT
from build_bundle import build

class MethodsProtocolTests(unittest.TestCase):
    def test_structure_pass_does_not_certify_science(self):
        report = audit_protocol()
        self.assertEqual(report["status"] if "status" in report else report["protocol_status"],
                         "STRUCTURAL_PASS_ONLY")
        self.assertEqual(report["schemas"], 12)
        self.assertEqual(report["gates"], 9)
        self.assertFalse(report["scientific_certified"])
        self.assertEqual(report["software_tag_sha"], EXPECTED_TAG_COMMIT)

    def test_schemas_contain_header_only(self):
        import csv
        m = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
        for f in m["required_schema_files"]:
            with self.subTest(f=f):
                with (ROOT/f).open(encoding="utf-8", newline="") as h:
                    self.assertEqual(len(list(csv.reader(h))),1)

    def test_zip_is_byte_for_byte_deterministic_and_privacy_safe(self):
        with tempfile.TemporaryDirectory() as tmp:
            p1=Path(tmp)/"first.zip";p2=Path(tmp)/"second.zip"
            a=build(output=p1)
            b=build(output=p2)
            self.assertEqual(a["sha256"],b["sha256"])
            self.assertFalse(a["scientific_results_supplied"])
            self.assertGreater(a["file_count"],15)
            with ZipFile(p1) as z:
                names=z.namelist()
                self.assertTrue(any(n.endswith("FILE_SHA256.json") for n in names))
                self.assertFalse(any("/raw_videos/" in n for n in names))
                self.assertFalse(any(n.endswith(".pt") or n.endswith(".mp4") for n in names))
                audit=json.loads(z.read("AquaTrajectories_methods_v0.1.0/FILE_SHA256.json"))
                self.assertFalse(audit["scientific_results_supplied"])
                for name,digest in audit["source_files_sha256"].items():
                    actual=hashlib.sha256(z.read("AquaTrajectories_methods_v0.1.0/"+name)).hexdigest()
                    self.assertEqual(actual,digest)

    def test_any_fabricated_science_claim_fails(self):
        import shutil
        from verify import ProtocolError
        with tempfile.TemporaryDirectory() as tmp:
            local=Path(tmp)/"copy"
            shutil.copytree(ROOT,local,ignore=shutil.ignore_patterns("dist","__pycache__"))
            m=json.loads((local/"manifest.json").read_text())
            m["claims"]["physical_exposure_sync"]=True
            (local/"manifest.json").write_text(json.dumps(m))
            with self.assertRaises(ProtocolError):
                audit_protocol(local)

if __name__=="__main__":
    unittest.main()
