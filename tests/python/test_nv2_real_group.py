"""Reproducible real-MOT converter oracle and malformed-source failures."""
import csv, importlib.util, io, json, tempfile, unittest, zipfile
from pathlib import Path

MOD=Path(__file__).resolve().parents[2]/"scripts"/"nv2_fraunhofer_mot_to_csv.py"
spec=importlib.util.spec_from_file_location("nv2_mot",MOD)
nv2=importlib.util.module_from_spec(spec)
spec.loader.exec_module(nv2)

class SourceConverter(unittest.TestCase):
    def make_zip(self,path,rows,name="sequence/gt/gt.txt"):
        with zipfile.ZipFile(path,"w") as z:
            z.writestr(name,"\n".join(rows)+"\n")
    def test_centers_and_provenance(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);path=root/"original.zip"
            self.make_zip(path,["1,007,2,4,6,8,1,1,1",
                "3,007,5,7,3,5,1,1,1",
                "2,009,1,1,10,4,1,1,1"])
            meta=nv2.convert(path,root/"converted","A")
            self.assertEqual(meta["n_source_observations"],3)
            self.assertEqual(meta["n_tracks"],2)
            self.assertEqual(meta["n_frames"],3)
            self.assertFalse(meta["transport_tls_peer_verified"])
            self.assertEqual(meta["clock_status"],
                             "ORDINAL_FRAME_PROXY_NOT_SECONDS")
            with (root/"converted"/"SOURCE_FRAME_CENTER_TRACKS.csv").open() as f:
                rows=list(csv.DictReader(f))
            a=next(r for r in rows if r["frame_id"]=="1")
            self.assertEqual((float(a["x"]),float(a["y"])),(5,8))
            self.assertEqual(a["time_s"],"0")
            self.assertEqual(meta["csv_sha256"],nv2.sha256(
                root/"converted"/"SOURCE_FRAME_CENTER_TRACKS.csv"))
    def test_duplicate_frame_track_is_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);path=root/"test.zip"
            self.make_zip(path,["1,1,0,0,4,5",
                "1,1,2,0,5,6"])
            with self.assertRaisesRegex(ValueError,"Duplicate"):
                nv2.convert(path,root/"out","B")
    def test_bad_width_and_traversal_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);path=root/"test.zip"
            self.make_zip(path,["1,1,0,0,-4,5"])
            with self.assertRaisesRegex(ValueError,"Invalid position"):
                nv2.convert(path,root/"out","A")
            path2=root/"traversal.zip"
            self.make_zip(path2,["1,1,0,0,4,5"],"../gt/gt.txt")
            with self.assertRaisesRegex(ValueError,"Unsafe"):
                nv2.convert(path2,root/"out2","A")
    def test_no_real_annotations_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);path=root/"no_gt.zip"
            self.make_zip(path,["1,1,0,0,4,5"],"dummy/other.txt")
            with self.assertRaisesRegex(ValueError,"exactly one"):
                nv2.convert(path,root/"out","A")

if __name__=="__main__":unittest.main()
