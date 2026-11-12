"""Frozen fish SavedModel provenance and audit-contract tests; TF in genuine CI."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"inst/python"))
import aqt_oxford_frozen_model_smoke as m


class OriginalOxfordFrozenModelContracts(unittest.TestCase):
    def test_git_hash_matches_actual_git_blob_contract(self):
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/"a.pb"
            path.write_bytes(b"a"*1200)
            raw=path.read_bytes()
            want=hashlib.sha1(b"blob "+str(len(raw)).encode()+b"\0"+raw).hexdigest()
            self.assertEqual(m.git_blob_hash(path),want)
            self.assertEqual(m.digest_file(path),hashlib.sha256(raw).hexdigest())

    def test_all_model_components_hash_checked(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            mocked={}
            for name in m.MODEL_BLOBS:
                p=root/name
                p.parent.mkdir(parents=True,exist_ok=True)
                p.write_bytes(name.encode().ljust(1200,b"\x00"))
                mocked[name]=m.git_blob_hash(p)
            with patch.object(m,"MODEL_BLOBS",mocked):
                result=m.check_frozen_model(root)
                self.assertEqual(set(result),set(mocked))
                self.assertEqual(result["saved_model.pb"]["bytes"],1200)
                (root/"saved_model.pb").write_bytes(b"b"*1200)
                with self.assertRaisesRegex(ValueError,"blob mismatch"):
                    m.check_frozen_model(root)

    def test_missing_original_component_fails_closed(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaisesRegex(ValueError,"Missing exported"):
                m.check_frozen_model(d)

    def test_results_cannot_preclaim_accuracy(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            result=root/"evidence.json"
            result.write_text("placeholder")
            with self.assertRaisesRegex(FileExistsError,"overwrite"):
                m.main(["--model-dir",str(root),"--frame-jpeg",
                        str(root/"one.jpg"),"--out",str(result)])


if __name__=="__main__":
    unittest.main()
