"""Original Fraunhofer Datumaro and YOLO train/eval exact-byte leakage tests."""
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"inst/python"))
import aqt_fraunhofer_train_split_audit as m

def make_archive(path,image_data,tag):
    with zipfile.ZipFile(path,"w",compression=zipfile.ZIP_DEFLATED) as z:
        z.writestr("dataset/images/img000.jpg",image_data)
        z.writestr("dataset/images/img001.jpg",image_data+b"X")
        z.writestr("dataset/annotations/default.json",
            json.dumps({"items":[{"id":"f0","annotations":[{
                "type":"bbox","attributes":{"track_id":tag}}]}]}))

class SourceTrainingSplit(unittest.TestCase):
    def test_identical_image_leak_is_detected_but_does_not_certify_tank_independence(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td)
            a,b,train=(root/x for x in ("a.zip","b.zip","train.zip"))
            make_archive(a,b"fish_original_image_A","A")
            make_archive(b,b"fish_original_image_B","B")
            make_archive(train,b"fish_original_image_A","train")
            report=m.compare({"datumaro_a":a,"datumaro_b":b,"training_yolo":train})
            self.assertGreater(report["source_image_overlap_analysis"]
                ["datumaro_a_versus_training_yolo"]
                ["exactly_identical_source_image_sha256_count"],0)
            self.assertFalse(report["verified_no_exact_file_duplicates_between_train_and_evaluation"])
            self.assertFalse(report["video_holdout_not_temporally_correlated_verified"])
            self.assertTrue(report["sources"]["datumaro_a"]
                ["original_annotation_descriptors"][0]["source_track_attributes_observed"])

    def test_distinct_image_hashes_do_not_claim_independent_video_tanks(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td)
            a,b,train=(root/x for x in ("a.zip","b.zip","train.zip"))
            make_archive(a,b"A",1)
            make_archive(b,b"B",2)
            make_archive(train,b"C",3)
            report=m.compare({"datumaro_a":a,"datumaro_b":b,"training_yolo":train})
            self.assertTrue(report["verified_no_exact_file_duplicates_between_train_and_evaluation"])
            self.assertFalse(report["scientific_cross_domain_transfer_certified"])
            self.assertFalse(report["sources"]["datumaro_a"]["datumaro_tracks_independently_reviewed"])

    def test_zip_traversal_and_missing_images_fail(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td)
            attack=root/"attack.zip"
            with zipfile.ZipFile(attack,"w") as z:
                z.writestr("../outside.jpg",b"fish")
            with self.assertRaisesRegex(ValueError,"Unsafe"):
                m.inspect(attack,"datumaro_a")
            empty=root/"empty.zip"
            with zipfile.ZipFile(empty,"w") as z:
                z.writestr("annotations/default.json",json.dumps({"items":[]}))
            with self.assertRaisesRegex(ValueError,"no original image"):
                m.inspect(empty,"datumaro_b")

if __name__=="__main__":
    unittest.main()
