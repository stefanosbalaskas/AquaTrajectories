"""Original Fraunhofer MOT archive structure/provenance tests."""
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/"inst/python"))
import aqt_fraunhofer_mot_archive_audit as m

class FraunhoferOriginalArchive(unittest.TestCase):
    def test_source_gt_preserves_track_identifiers_and_frame_index(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/"mot_a.zip"
            rows="1,1,0,0,10,10,1,1,1\n1,2,20,20,10,10,1,1,1\n3,1,2,0,10,10,1,1,1\n"
            with zipfile.ZipFile(p,"w") as z:
                z.writestr("mot_a/gt/gt.txt",rows)
                z.writestr("mot_a/seqinfo.ini","[Sequence]\nseqLength=3")
                z.writestr("mot_a/img1/000001.jpg",b"x")
            out=m.inspect_archive(p,sequence="A",
                    original_url="https://cvg.hhi.fraunhofer.de/FishTrackingData/video_a/mot_a.zip")
            self.assertEqual(out["native_gt"]["rows"],3)
            self.assertEqual(out["native_gt"]["n_unique_track_ids"],2)
            self.assertEqual(out["native_gt"]["n_unique_frames"],2)
            self.assertEqual(out["native_gt"]["minimum_frame_id"],1)
            self.assertEqual(out["native_gt"]["maximum_frame_id"],3)
            self.assertEqual(out["image_member_count"],1)
            self.assertFalse(out["original_download_peer_tls_verified"])
            self.assertFalse(out["official_HOTA_IDF1_measured"])

    def test_prohibits_zip_traversal(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/"bad.zip"
            with zipfile.ZipFile(p,"w") as z:
                z.writestr("../../evil.txt","x")
            with self.assertRaisesRegex(ValueError,"Unsafe"):
                m.inspect_archive(p,sequence="A",original_url="source")

    def test_same_frame_id_duplicate_is_recorded_and_not_trusted(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/"mot.zip"
            with zipfile.ZipFile(p,"w") as z:
                z.writestr("gt/gt.txt","1,2,0,0,10,10,1\n1,2,0,0,10,10,1\n")
            audit=m.inspect_archive(p,sequence="B",original_url="source")
            self.assertEqual(audit["native_gt"]["duplicate_frame_and_id"],1)
            self.assertFalse(audit["archive_gt_source_verified"])

if __name__=="__main__":
    unittest.main()
