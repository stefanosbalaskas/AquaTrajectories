"""Wave 13E original fish model-to-tracker benchmark static contracts."""
import csv
from pathlib import Path
import sys
import tempfile
import unittest
try:
    import numpy as np
except ImportError:  # stdlib-only CI; dedicated inference CI installs NumPy
    np = None

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"inst/python"))
import aqt_oxford_frozen_sequence_benchmark as m


class RealFishModelSequenceContracts(unittest.TestCase):
    @unittest.skipIf(np is None, "NumPy needed for genuine frozen model tensor tests")
    def test_true_source_model_tensor_order_no_guessed_class_identity(self):
        x=np.array([[[0,10,20,50,70,.8,1],
                     [0,40,30,80,60,.1,1]]],dtype=np.float32)
        valid,bad=m.source_tensor_boxes(x,1920,1080,.25)
        self.assertEqual(len(valid),1)
        self.assertEqual(len(bad),0)
        self.assertEqual(valid[0]["xywh"],[20.0,10.0,50.0,40.0])
        self.assertEqual(valid[0]["model_class_index"],1)
        with self.assertRaisesRegex(ValueError,"output schema"):
            m.source_tensor_boxes(np.ones((100,7)),1920,1080)
        with self.assertRaisesRegex(ValueError,"Nonfinite"):
            x[0,0,1]=np.nan
            m.source_tensor_boxes(x,1920,1080)

    def test_invalid_boxes_count_false_positive_not_silently_clipped(self):
        key="F30_T15/f00000.jpg"
        truth={key:{"boxes":[(10,10,20,20)]}}
        pred={key:{"boxes":[{"xywh":[10,10,20,20],"score":.8}],
                   "invalid":[{"score":.9,"box":[-5,2,10,20]}]}}
        result,rows=m.compare_boxes(pred,truth,.7)
        self.assertEqual((result["true_positives"],
                          result["false_positives"],result["false_negatives"]),
                         (1,1,0))
        self.assertEqual(result["n_invalid_high_confidence_detections"],1)
        self.assertEqual(result["F1"],2/3)
        self.assertEqual(rows[0]["model_predictions"],2)

    def test_scoring_includes_fully_empty_ground_truth_frame(self):
        gt={"F30_T15/f00000.jpg":{"boxes":[]}}
        pred={"F30_T15/f00000.jpg":{"boxes":[
            {"xywh":[1,1,10,10],"score":.8}],"invalid":[]}}
        a,_=m.compare_boxes(pred,gt,.5)
        self.assertEqual(a["true_positives"],0)
        self.assertEqual(a["false_positives"],1)
        self.assertEqual(a["n_reference_empty_frames"],1)
        self.assertIsNone(a["recall"])

    def test_real_source_pts_manifest_no_fps_fabrication(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/"frames.csv"
            with p.open("w",newline="") as f:
                w=csv.writer(f)
                w.writerow(["session_id","camera_id","frame_id","time_s",
                            "width_px","height_px"])
                w.writerow(["oxford_eval","oxford_single_video",0,0,1920,1080])
                w.writerow(["oxford_eval","oxford_single_video",1,.043,1920,1080])
                w.writerow(["oxford_eval","oxford_single_video",2,.091,1920,1080])
            times=m.read_video_manifest(p)
            self.assertEqual(times,[0,.043,.091])
            with p.open("a") as f:
                f.write("oxford_eval,oxford_single_video,4,.11,1920,1080\n")
            with self.assertRaisesRegex(ValueError,"frame IDs"):
                m.read_video_manifest(p)

    def test_full_video_reviewed_frame_coverage_and_no_oracle(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td)
            files=[]
            gt={}
            for i in range(3):
                path=root/f"f{i:05d}.jpg"
                path.write_bytes(b"x"*10)
                files.append(path)
                gt[f"F30_T15/{path.name}"]={
                    "boxes":[],"unsupported_annotation_regions":0}
            selected,reviewed=m.validate_frames(root,[0,.04,.08],gt)
            self.assertEqual(selected,files)
            self.assertEqual(len(reviewed),3)
            del gt["F30_T15/f00002.jpg"]
            with self.assertRaisesRegex(ValueError,"coverage"):
                m.validate_frames(root,[0,.04,.08],gt)


if __name__=="__main__":
    unittest.main()
