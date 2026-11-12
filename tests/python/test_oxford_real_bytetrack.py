"""Wave 13A regression contracts. Real ByteTrack exercised in source-data CI."""
import csv
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"inst/python"))
import aqt_oxford_real_bytetrack as m


def lisa(rows):
    return {"files":[{"fid":i,"src":f"F30_T15/f{i:05d}.jpg",
                       "regions":regions,
                       "rdata":[{"confidence":f"{score:.3f}"}
                                for score in scores],
                       "fdata":{"width":1920,"height":1080}}
                      for i,(regions,scores) in enumerate(rows)]}


class OriginalOxfordByteTrackContracts(unittest.TestCase):
    def test_confidence_and_empty_frames_not_synthesized(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/"source.json"
            p.write_text(json.dumps(lisa([
                ([],[]),([[10,20,50,40]],[0.712]),([],[])])))
            source=m.source_detections(p)
            self.assertEqual(len(source),3)
            grouped=m.group_sequences(source)
            self.assertEqual(len(grouped["F30_T15"]),3)
            self.assertEqual(grouped["F30_T15"][0]["boxes"],[])
            self.assertEqual(grouped["F30_T15"][1]["scores"],[0.712])
            self.assertEqual(grouped["F30_T15"][2]["frame"],2)

    def test_reject_missing_detector_score(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/"source.json"
            sample=lisa([([[10,20,50,40]],[.8])])
            sample["files"][0]["rdata"]=[{}]
            p.write_text(json.dumps(sample))
            with self.assertRaisesRegex(ValueError,"published detector confidence"):
                m.source_detections(p)

    def test_missing_source_frames_are_not_silent(self):
        frames={"F30_T15/f00000.jpg":{"sequence":"F30_T15","frame":0},
                "F30_T15/f00002.jpg":{"sequence":"F30_T15","frame":2}}
        with self.assertRaisesRegex(ValueError,"Missing/repeated"):
            m.group_sequences(frames)

    def test_provenance_and_no_official_identity_claims(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/"data.json";p.write_text("{}")
            output=Path(d)/"export"
            example=[dict(recording="F30_T15",frame_id=1,frame_mot=2,
                          track_id=1,xmin_px=10,ymin_px=10,width_px=20,
                          height_px=15,confidence=.8,class_id=0)]
            stats={"F30_T15":dict(source_frames=3,source_detector_boxes=1,
                                 tracker_assigned_boxes=1,
                                 unassigned_source_boxes=0,
                                 observed_local_track_ids=1,
                                 local_track_gaps=0,
                                 idf1_hota_measured=False)}
            report=m.export_results(example,stats,p,output)
            self.assertEqual(report["n_original_frames"],3)
            self.assertEqual(report["n_tracker_observations"],1)
            self.assertFalse(report["official_HOTA_IDF1_measured"])
            self.assertFalse(report["detector_run_on_video_here"])
            with (output/"real_source_bytetrack.csv").open(newline="") as f:
                entries=list(csv.DictReader(f))
            self.assertEqual(entries[0]["frame_mot"],"2")
            self.assertEqual(m.sha256(output/"real_source_bytetrack.csv"),
                             report["output_sha256"])
            with self.assertRaises(FileExistsError):
                m.export_results(example,stats,p,output)


if __name__=="__main__":
    unittest.main()
