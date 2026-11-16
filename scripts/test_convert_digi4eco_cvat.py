import unittest
import tempfile
from pathlib import Path
import importlib.util

MODULE=Path(__file__).resolve().parent/"convert_digi4eco_cvat.py"
spec=importlib.util.spec_from_file_location("digi4eco",MODULE)
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

XML="""<annotations><meta><task><original_size><width>1920</width><height>1080</height></original_size></task></meta>
<track id="7" label="Fish"><box frame="0" outside="0" occluded="0" xtl="10" ytl="20" xbr="30" ybr="40"/>
<box frame="1" outside="0" occluded="1" xtl="11" ytl="20" xbr="31" ybr="40"/>
<box frame="2" outside="1" occluded="0" xtl="11" ytl="20" xbr="31" ybr="40"/></track>
<track id="12" label="Fish"><box frame="1" outside="0" occluded="0" xtl="100" ytl="50" xbr="140" ybr="80"/></track></annotations>"""

class ConverterTests(unittest.TestCase):
    def test_offline_conversion_source_labels_not_predictions(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)
            (p/"annotations.xml").write_text(XML,encoding="utf8")
            (p/"video.mp4").write_bytes(b"TEST_FIXTURE_NOT_REAL_VIDEO")
            (p/"pts.csv").write_text("7.0\n7.04\n7.08\n")
            report=module.convert(p/"annotations.xml",p/"video.mp4",p/"pts.csv",p/"output","TEST","CAM1")
            self.assertEqual(report["source_frame_count"],3)
            self.assertEqual(report["original_annotation_box_rows"],4)
            self.assertEqual(report["source_original_track_count"],2)
            self.assertEqual(report["source_outside_box_rows"],1)
            self.assertEqual(report["source_occluded_box_rows"],1)
            self.assertFalse(report["aqt_detector_or_tracker_predictions_created"])
            rows=module.csv.DictReader((p/"output"/"source_2d_tracks.csv").open())
            data=list(rows)
            self.assertEqual(data[0]["x"],"20")
            self.assertEqual(data[2]["observed"],"FALSE")
            self.assertEqual(data[2]["x"],"")
            self.assertEqual(data[1]["original_occluded"],"TRUE")
    def test_pts_out_of_order_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);(p/"pts.csv").write_text("0\n.1\n.1\n")
            with self.assertRaises(ValueError):
                module.read_pts(p/"pts.csv")
    def test_doctype_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);(p/"bad.xml").write_text("<!DOCTYPE foo><annotations/>")
            with self.assertRaises(ValueError):
                module.xml_data(p/"bad.xml")

if __name__=="__main__":
    unittest.main()
