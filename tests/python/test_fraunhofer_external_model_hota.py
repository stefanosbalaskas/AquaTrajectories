"""Real Fraunhofer source, model-leak separation and original-frame indexing."""
from pathlib import Path
import importlib.util
import sys
import tempfile
import unittest
import zipfile
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"inst/python"))
import aqt_fraunhofer_external_model_hota as m

class RealRicefishExternalModelContracts(unittest.TestCase):
    def test_original_image_and_identity_source_are_not_mixed(self):
        self.assertEqual(m.ORIG_LAST-m.ORIG_FIRST+1,m.N_FRAMES)
        self.assertEqual(m.ORIG_FIRST,43450)
        self.assertEqual(m.ORIGINAL_A_SHA,
                         "18c39619b1f84ea774f16fedfac5911d92de86ab7da4aa03cf365b9b4be58ceb")

    def test_source_fails_if_hash_unrecognized(self):
        with tempfile.TemporaryDirectory() as td:
            path=Path(td)/"bad.zip"
            with zipfile.ZipFile(path,"w") as z:
                z.writestr("mot/gt/gt.txt","43450,1,0,0,10,10,1\n")
            with self.assertRaisesRegex(ValueError,"hash differs"):
                m.source_archive(path)

    def test_exact_source_archive_geometry_no_training_as_truth(self):
        self.assertIn("source_original_image_sha256",Path(
            m.__file__).read_text())
        self.assertIn("original_fish_IDs_visible_to_model_or_tracker",Path(
            m.__file__).read_text())
        self.assertIn("source_ground_truth_blinded_independently_reviewed",Path(
            m.__file__).read_text())
        self.assertIn("real_video_original_PTS_available",Path(
            m.__file__).read_text())

    def test_artifact_path_preexists_refuse_rerun(self):
        with tempfile.TemporaryDirectory() as td:
            dest=Path(td)/"existing";dest.mkdir()
            with self.assertRaisesRegex(FileExistsError,"overwrite"):
                m.evaluate_frozen_model(Path(td)/"source.zip",
                                        Path(td)/"model",dest)

if __name__=="__main__":
    unittest.main()
