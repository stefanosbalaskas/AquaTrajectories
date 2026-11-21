"""Independent conversion oracle, security and negative tests for real ZeF GT."""
import csv
import importlib.util
import tempfile
import unittest
from pathlib import Path
FILE=Path(__file__).resolve().parents[2]/"scripts"/"nv2_zef_to_csv.py"
spec=importlib.util.spec_from_file_location("nv2_zef",FILE)
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
def line(frame,fish,x,y,occ=0):
    return ",".join(map(str,[frame,fish,19.61,28.313,7.93,
        x,y,1377,1214,156,78,occ,1666,961,1438,911,251,85,0]))
class ZeFTests(unittest.TestCase):
    def test_real_format_and_source_provenance(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d); source=p/"gt.txt"
            source.write_text("\n".join([
                line(1,2,1464,1284,1),line(1,1,1523,1283,0),
                line(2,1,1500,1290),line(2,2,1460,1288)])+"\n")
            meta=mod.convert(source,p/"output","01")
            self.assertEqual(meta["n_tracks"],2)
            self.assertEqual(meta["n_frames"],2)
            self.assertEqual(meta["max_simultaneous_source_ids"],2)
            self.assertTrue(meta["transport_tls_peer_verified"])
            self.assertFalse(meta["origin_verified_by_independent_frozen_digest"])
            with (p/"output"/"SOURCE_FRAME_CENTER_TRACKS.csv").open() as f:
                vals=list(csv.DictReader(f))
            self.assertEqual(len(vals),4)
            a=next(x for x in vals if x["track_id"]=="1" and x["frame_id"]=="1")
            self.assertEqual((float(a["x"]),float(a["y"])),(1523,1283))
            self.assertEqual(a["time_s"],"0")
            self.assertEqual(meta["csv_sha256"],mod.hash_file(
                p/"output"/"SOURCE_FRAME_CENTER_TRACKS.csv"))
    def test_missing_head_and_original_row_preserved(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);source=p/"gt.txt"
            source.write_text("\n".join([
                line(1,1,100,200),line(1,2,-1,-1),
                line(2,1,101,201),line(3,1,102,202)])+"\n")
            meta=mod.convert(source,p/"output","02")
            self.assertEqual(meta["n_original_annotated_rows"],4)
            self.assertEqual(meta["n_source_observations"],3)
            self.assertEqual(meta["n_excluded_unusable_points"],1)
            rows=list(csv.DictReader((p/"output"/"EXCLUDED_TOP_VIEW_POINTS.csv").open()))
            self.assertEqual(rows[0]["source_line"],"2")
    def test_bad_duplicates_columns_and_unchanged_output(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d); source=p/"gt.txt"
            source.write_text(line(1,1,5,5)+"\n"+line(1,1,7,8)+"\n")
            with self.assertRaisesRegex(ValueError,"Duplicate"):
                mod.convert(source,p/"bad","03")
            source.write_text("1,1,5,5\n")
            with self.assertRaisesRegex(ValueError,"19 columns"):
                mod.convert(source,p/"bad","03")
            source.write_text("\n".join([line(1,1,5,5),
                line(2,1,6,6),line(3,1,7,7)])+"\n")
            mod.convert(source,p/"out","03")
            with self.assertRaises(FileExistsError):
                mod.convert(source,p/"out","03")
    def test_inconsistent_source_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);source=p/"gt.txt"
            source.write_text("\n".join([line(1,1,10,12),
                line(2,1,12,12,occ=2),line(3,1,15,15)])+"\n")
            with self.assertRaisesRegex(ValueError,"occlusion"):
                mod.convert(source,p/"invalid","04")
if __name__=="__main__":unittest.main()
