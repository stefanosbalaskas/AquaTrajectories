"""Oxford human-reviewed source benchmark contracts and no-accuracy overclaims."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location(
    "aqt_oxford_detection_audit",ROOT/"inst/python/aqt_oxford_detection_audit.py")
mod=importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def source(boxes,seq="F30_T4",frame=0):
    return {f"{seq}/f{frame:05d}.jpg":{
        "sequence":seq,"frame":frame,"image_width_px":100,
        "image_height_px":100,"boxes":boxes}}


class OriginalOxfordAgreement(unittest.TestCase):
    def test_real_format_lisa_and_verified_empty_frames(self):
        with tempfile.TemporaryDirectory() as td:
            path=Path(td)/"manual.json"
            obj={"project":{},"files":[
                {"fid":0,"src":"F30_T4/f00000.jpg","fdata":{"width":100,"height":100},
                 "regions":[],"rdata":[]},
                {"fid":1,"src":"F30_T4/f00001.jpg","fdata":{"width":100,"height":100},
                 "regions":[[1,2,10,20]],"rdata":[{"object_type":"fish"}]}]}
            path.write_text(json.dumps(obj))
            frames=mod.parsed_annotations(path)
            self.assertEqual(len(frames),2)
            self.assertEqual(frames["F30_T4/f00000.jpg"]["boxes"],[])
            self.assertEqual(frames["F30_T4/f00001.jpg"]["boxes"],[(1.,2.,10.,20.)])
            obj["files"].append(obj["files"][0])
            path.write_text(json.dumps(obj))
            with self.assertRaisesRegex(ValueError,"Duplicate"):
                mod.parsed_annotations(path)

    def test_match_permutation_and_zero_truth_false_positives(self):
        gt={**source([(0,0,10,10)],frame=0),
            **source([],frame=1)}
        pred={**source([(1,0,10,10)],frame=0),
              **source([(20,20,10,10)],frame=1)}
        out=mod.score_sources(gt,pred,.5)
        self.assertEqual(out["pooled"]["tp"],1)
        self.assertEqual(out["pooled"]["fp"],1)
        self.assertEqual(out["pooled"]["fn"],0)
        self.assertEqual(out["pooled"]["reference_empty_frames"],1)
        self.assertEqual(out["pooled"]["false_positives_on_reference_empty_frames"],1)
        self.assertEqual(out["pooled"]["precision"],.5)
        self.assertFalse(out["original_human_annotation_prediction_blind_certified"])
        self.assertFalse(out["AquaTrajectories_detector_accuracy_measured"])
        self.assertFalse(out["track_identity_HOTA_or_IDF1_measured"])

    def test_global_cardinality_beats_greedy(self):
        gt=[(0,0,10,10),(8,0,10,10)]
        pred=[(7,0,10,10),(0,0,10,10)]
        pairs=mod.optimal_matches(gt,pred,.1)
        self.assertEqual(len(pairs),2)
        self.assertEqual({(i,j) for i,j,_ in pairs},{(0,1),(1,0)})
        self.assertEqual(mod.optimal_matches([],[],0.5),())

    def test_prediction_ground_truth_scope_must_match(self):
        gt=source([],frame=0)
        pred=source([],frame=1)
        with self.assertRaisesRegex(ValueError,"key sets differ"):
            mod.score_sources(gt,pred)
        with self.assertRaisesRegex(ValueError,"threshold"):
            mod.score_sources(gt,gt,0)

    def test_source_cli_outputs_only_derived_metrics(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td)
            p=root/"auto.json";g=root/"manual.json"
            def lisarow(src,boxes):
                return {"fid":0,"src":src,"regions":boxes,
                        "rdata":[{} for _ in boxes],
                        "fdata":{"width":100,"height":100}}
            gt={"files":[lisarow("F30_T4/f00000.jpg",[[10,10,20,20]])]}
            pd={"files":[lisarow("F30_T4/f00000.jpg",[[10,10,20,20]])]}
            p.write_text(json.dumps(pd))
            g.write_text(json.dumps(gt))
            out=root/"audit.json"
            self.assertEqual(mod.main(["--auto",str(p),"--manual",str(g),
                                       "--out",str(out)]),0)
            report=json.loads(out.read_text())
            self.assertEqual(report["pooled"]["tp"],1)
            self.assertEqual(report["pooled"]["f1"],1)
            self.assertFalse(report["AquaTrajectories_detector_accuracy_measured"])
            with self.assertRaises(FileExistsError):
                mod.main(["--auto",str(p),"--manual",str(g),"--out",str(out)])


if __name__=="__main__":
    unittest.main()
