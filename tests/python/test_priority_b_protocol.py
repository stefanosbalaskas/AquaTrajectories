"""Priority B synthetic exact-case qualification; never claim real tracker accuracy."""
import csv
import json
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest import mock

sys.path.insert(0,str(Path(__file__).resolve().parents[2]/"inst/python"))
import aqt_priority_b_benchmark as b
import aqt_priority_b_adapters as ad
import aqt_priority_b_splits as sp

class TestPriorityB(unittest.TestCase):
    def write_csv(self,path,header,rows):
        with path.open("w",newline="",encoding="utf-8") as f:
            writer=csv.writer(f);writer.writerow(header);writer.writerows(rows)

    def build_fixture(self,root):
        (root/"frames.csv").write_text("frame,review_status\n"+
              "".join(f"{i},fully_annotated\n" for i in range(1,6)))
        self.write_csv(root/"timestamps.csv",["frame","time_s"],
                        ((i,(i-1)/10) for i in range(1,6)))
        gt=[];pr=[];yolo=[];slea=[];idtra=[]
        for f in range(1,5):
            for animal,x in ((1,10+f),(2,60+f)):
                gt.append((f,animal,x,10,8,8,1))
                yolo.append((f,animal,x+.2,10,8,8,.92))
                pr.append((f,animal,x+4.2,14,.92))
                slea.append((f,animal,x+4,14,.84))
                if not (f==3 and animal==2):
                    idtra.append((f,animal,x+4,14,""))
        with (root/"gt.txt").open("w",newline="") as f:csv.writer(f).writerows(gt)
        with (root/"yolo.txt").open("w",newline="") as f:csv.writer(f).writerows(yolo)
        for name,rows in (("yolo.csv",pr),("sleap.csv",slea),("idtrackerai.csv",idtra)):
            self.write_csv(root/name,["frame","track_id","x_px","y_px","score"],rows)
        methods=[]
        for name in ("idtrackerai","sleap","yolo_bytetrack"):
            label = "yolo" if name=="yolo_bytetrack" else name
            r={"wall_seconds":2 if name=="idtrackerai" else 3,
               "hardware_id":"HOST1","device":"CPU","input_video_sha256":"a"*64,
               "n_input_frames":5,
               "software_versions":{name:"frozen-test-version"},
               "phase":"full_inference_and_tracking"}
            (root/(label+"-runtime.json")).write_text(json.dumps(r))
            provenance={"model_or_config_sha256":"b"*64,
                        "test_split_used_for_training_or_tuning":False}
            (root/(label+"-train.json")).write_text(json.dumps(provenance))
            methods.append({"method":name,"centres_csv":label+".csv",
              "boxes_mot":"yolo.txt" if name=="yolo_bytetrack" else None,
              "runtime_json":label+"-runtime.json",
              "training_provenance_json":label+"-train.json",
              "score_semantics":"absent" if name=="idtrackerai" else
                                "detection_confidence",
              "prediction_source":"model_generated",
              "test_video_used_for_training_or_selection":False})
        return {"protocol":b.PROTOCOL,"sequence":"TOY_ONLY",
          "gt_mot":"gt.txt","frame_manifest":"frames.csv",
          "timestamps":"timestamps.csv","source_split":"test",
          "declared_source_video_sha256":"a"*64,
          "annotation_independence":"unverified",
          "dataset_annotator_model_assistance":False,
          "centre_gate_px":3,"detection_confidence_threshold":.5,
          "iou_threshold":.5,"methods":methods}

    def test_three_method_same_data_with_official_trackeval(self):
        import trackeval
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);spec=self.build_fixture(root)
            lock_path=root/"lock.json";b.freeze(root,spec,lock_path)
            lock=json.loads(lock_path.read_text())
            ans=b.compare(root,spec,lock)
            self.assertEqual(ans["n_fully_annotated_frames_including_empty"],5)
            self.assertEqual(ans["n_gt_fish_boxes"],8)
            self.assertEqual(len(ans["results"]),3)
            self.assertTrue(ans["runtime_rank_valid"])
            yolo=ans["results"][2]
            self.assertAlmostEqual(yolo["tracking"]["centre_HOTA"],1,places=8)
            self.assertAlmostEqual(yolo["tracking"]["centre_IDF1"],1,places=8)
            self.assertAlmostEqual(yolo["centre_AP101"],1,places=8)
            self.assertAlmostEqual(yolo["bbox_metrics"]["box_AP50_101"],1,places=8)
            self.assertAlmostEqual(yolo["bbox_metrics"]["official_iou_HOTA"],1,places=8)
            self.assertIsNone(ans["results"][0]["centre_AP101"])
            self.assertIsNone(ans["results"][0]["bbox_metrics"])
            self.assertEqual(ans["results"][0]["fragmentation"]["identity_fragmentations"],1)
            self.assertLess(ans["results"][0]["behaviour_error"]["supported_pair_fraction"],1)
            self.assertEqual(yolo["behaviour_error"]["n_gt_consecutive_fish_pairs"],6)
            self.assertEqual(yolo["behaviour_error"]["n_supported_pairs_same_predicted_identity"],6)
            self.assertFalse(ans["physical_units_validated"])
            self.assertEqual(ans["results"][0]["centre_AP_score_semantics"],"absent")

    def test_switch_and_false_positive_reduce_accuracy(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);spec=self.build_fixture(root)
            z=root/"sleap.csv"
            rows=list(csv.DictReader(z.open()))
            for row in rows:
                if int(row["frame"])>=3:
                    row["track_id"]=str(3-int(row["track_id"]))
            self.write_csv(z,["frame","track_id","x_px","y_px","score"],
                ([r[k] for k in ("frame","track_id","x_px","y_px","score")] for r in rows))
            lock=root/"lock.json";b.freeze(root,spec,lock)
            q=b.compare(root,spec,json.loads(lock.read_text()))
            self.assertLess(q["results"][1]["tracking"]["centre_IDF1"],1)
            self.assertGreater(q["results"][1]["tracking"]["centre_IDSW"],0)
            self.assertGreater(q["results"][1]["fragmentation"]["adjacent_identity_label_changes"],0)
            self.assertLess(q["results"][1]["behaviour_error"]["supported_pair_fraction"],1)

    def test_mutated_predictions_and_partial_frames_refused(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);spec=self.build_fixture(root)
            lock=root/"lock.json";b.freeze(root,spec,lock)
            (root/"yolo.csv").write_text((root/"yolo.csv").read_text()+"5,999,12,12,0.9\n")
            with self.assertRaisesRegex(ValueError,"hash mismatch"):
                b.compare(root,spec,json.loads(lock.read_text()))
            with self.assertRaises(FileExistsError):
                b.freeze(root,spec,lock)
            (root/"frames.csv").write_text("frame,review_status\n1,partially_annotated\n")
            with self.assertRaisesRegex(ValueError,"non-reviewed"):
                b.official.manifest(root/"frames.csv")

    def test_missing_gt_and_source_leakage_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);spec=self.build_fixture(root)
            spec["methods"][0]["test_video_used_for_training_or_selection"]=True
            with self.assertRaisesRegex(ValueError,"tuned on test"):
                b.validate_spec(root,spec)
            spec["methods"][0]["test_video_used_for_training_or_selection"]=False
            spec["methods"][0]["prediction_source"]="oracle_box_association"
            with self.assertRaisesRegex(ValueError,"detection-oracle"):
                b.validate_spec(root,spec)
            spec["methods"][0]["prediction_source"]="model_generated"
            spec["methods"][0]["boxes_mot"]="yolo.txt"
            with self.assertRaisesRegex(ValueError,"alias"):
                b.validate_spec(root,spec)

    def test_runtime_non_comparability_when_hardware_differs(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);spec=self.build_fixture(root)
            p=root/"sleap-runtime.json";d=json.loads(p.read_text())
            d["hardware_id"]="OTHER_HOST";p.write_text(json.dumps(d))
            lock=root/"lock.json";b.freeze(root,spec,lock)
            result=b.compare(root,spec,json.loads(lock.read_text()))
            self.assertFalse(result["runtime_rank_valid"])

    def test_idtracker_csv_tidy_identity_probability_not_detection_score(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            source=root/"idtracker_tidy.csv"
            self.write_csv(source,["frame","time","individual","x","y","probability"],[
              [0,0.0,0,5,6,.8],[0,0,1,15,16,.3],
              [1,.1,0,"nan","nan",.5],[1,.1,1,16,16,.4]])
            converted=root/"converted.csv"
            report=ad.convert(source,"idtrackerai",0,2,converted)
            self.assertEqual(report["n_centres"],3)
            self.assertTrue(report["identity_probability_not_used_as_detection_confidence"])
            rows=list(csv.DictReader(converted.open()))
            self.assertEqual(rows[0]["score"],"")
            self.assertEqual(rows[0]["frame"],"1")
            self.assertEqual(rows[1]["track_id"],"2")

    def test_sleap_adapter_uses_predicted_visible_keypoints_only(self):
        try:
            import numpy as np
        except ImportError:
            self.skipTest("numpy absent")
        class Track:
            name="animal-A"
        PredictedInstance=type("PredictedInstance",(),{
          "numpy":lambda self:np.asarray([[1.,3.],[3.,5.],[float("nan"),2.]]),
          "track":Track(),"score":.9})
        class Frame:
            frame_idx=0;video=object()
            def __iter__(self):return iter([PredictedInstance()])
        fake=types.SimpleNamespace(load_slp=lambda _: [Frame()])
        with tempfile.TemporaryDirectory() as temp:
            source=Path(temp)/"pred.slp";source.touch()
            with mock.patch.dict(sys.modules,{"sleap_io":fake}):
                rows,report=ad.sleap_rows(source,0,1)
            self.assertEqual(rows,[(1,1,2.0,4.0,.9)])
            self.assertFalse(report["native_fish_bbox_supplied"])

    def test_disjoint_group_split_audit_and_leakage(self):
        with tempfile.TemporaryDirectory() as temp:
            src=Path(temp)/"splits.csv"
            rows=[
             ["A","record1","fish_group_1","session1","1"*64,"train","training_labels"],
             ["A","record2","fish_group_2","session2","2"*64,"val","training_labels"],
             ["A","record3","fish_group_3","session3","3"*64,"test","fully_annotated"]]
            self.write_csv(src,sp.COLUMNS,rows)
            audit=sp.validate_split(src)
            self.assertEqual(audit["by_split"],{"train":1,"val":1,"test":1})
            prov={"model_or_config_sha256":"b"*64,
                  "training_source_video_sha256":["1"*64],
                  "model_selection_source_video_sha256":["2"*64],
                  "source_split_manifest_sha256":audit["source_manifest_sha256"],
                  "test_split_used_for_training_or_tuning":False}
            p=Path(temp)/"provenance.json";p.write_text(json.dumps(prov))
            self.assertTrue(sp.validate_model_provenance(p,audit))
            rows[2][2]="fish_group_1"
            self.write_csv(src,sp.COLUMNS,rows)
            with self.assertRaisesRegex(ValueError,"fish_group_id"):
                sp.validate_split(src)

if __name__=="__main__":
    unittest.main()
