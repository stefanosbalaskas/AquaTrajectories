"""External fish association oracle contracts; real source executed in dedicated CI."""
import importlib.util
import pathlib
import sys
import tempfile
import unittest
import zipfile

ROOT=pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"inst/python"))
import aqt_fraunhofer_oracle_bytetrack_hota as m

class RealFishOracleContracts(unittest.TestCase):
    def test_source_ground_truth_ids_are_not_supplied_to_associator(self):
        gt=[(1,999,(0.,0.,8.,8.),1.),(2,999,(1.,0.,8.,8.),1.),
            (1,101,(40.,0.,8.,8.),1.),(2,101,(39.,0.,8.,8.),1.)]
        group=m.group_frames(gt,2)
        self.assertEqual(group[0],[(0.,0.,8.,8.),(40.,0.,8.,8.)])
        self.assertEqual(group[1],[(1.,0.,8.,8.),(39.,0.,8.,8.)])
        self.assertEqual(m.iou(group[0][0],group[0][0]),1.)
        self.assertEqual(m.iou(group[0][0],group[0][1]),0.)

    @unittest.skipUnless(importlib.util.find_spec("scipy") is not None and
                         importlib.util.find_spec("numpy") is not None,
                         "SciPy and NumPy installed by dedicated official CI")
    def test_separate_simple_tracker_never_consumes_original_labels(self):
        frames=[[(10.,10.,8.,8.),(50.,50.,8.,8.)],
                [(11.,10.,8.,8.),(51.,50.,8.,8.)],
                [(12.,10.,8.,8.),(52.,50.,8.,8.)]]
        result=m.simple_iou_hungarian(frames)
        self.assertEqual(len(result),6)
        self.assertEqual(len({x[1] for x in result}),2)
        self.assertEqual(len([x for x in result if x[0]==3]),2)

    def test_real_source_archive_gt_is_read_but_original_identity_flagged_oracle(self):
        with tempfile.TemporaryDirectory() as td:
            source=pathlib.Path(td)/"mot_a.zip"
            with zipfile.ZipFile(source,"w") as z:
                z.writestr("A/gt/gt.txt",
                    "".join(f"{frame},{idx},{idx*20},{idx*20},8,8,1,1,1\n"
                            for frame in range(1,4) for idx in range(1,5)))
                for source_frame in range(1,4):
                    z.writestr(f"A/img1/{source_frame:06d}.jpg",
                               b"real_format_placeholder")
            gt,info=m.original_zip_gt(source,3)
            self.assertEqual(len(gt),12)
            self.assertEqual(info["gt_rows"],12)
            self.assertEqual(info["image_members"],3)
            self.assertEqual(info["original_source_first_frame"],1)
            self.assertEqual(info["local_first_frame"],1)
            self.assertTrue(info["original_image_frame_coverage_verified"])
            frames=m.group_frames(gt,3)
            self.assertEqual(len(frames),3)
            self.assertEqual(len(frames[0]),4)

    def test_source_requires_actual_gt_and_rejects_zip_traversal(self):
        with tempfile.TemporaryDirectory() as td:
            source=pathlib.Path(td)/"unsafe.zip"
            with zipfile.ZipFile(source,"w") as z:
                z.writestr("../../evil.txt","x")
            with self.assertRaisesRegex(ValueError,"Unsafe"):
                m.original_zip_gt(source,101)

    def test_real_absolute_source_frame_origin_is_reindexed_not_fabricated(self):
        with tempfile.TemporaryDirectory() as td:
            path=pathlib.Path(td)/"original_ricefish_a.zip"
            offset=43449
            with zipfile.ZipFile(path,"w") as z:
                z.writestr("mot/gt/gt.txt",
                    "".join(f"{frame},{fish_id},{fish_id*20},10,8,8,1,1,1\n"
                            for frame in range(offset+1,offset+4)
                            for fish_id in range(1,5)))
                for frame in range(offset+1,offset+4):
                    z.writestr(f"mot/img1/{frame:06d}.jpg",b"original image placeholder")
            gt,info=m.original_zip_gt(path,3)
            self.assertEqual(sorted({x[0] for x in gt}),[1,2,3])
            self.assertEqual(len(gt),12)
            self.assertEqual(info["original_source_first_frame"],43450)
            self.assertEqual(info["original_source_last_frame"],43452)
            self.assertTrue(info["original_image_frame_coverage_verified"])

    def test_reject_incomplete_or_mismatched_original_source_jpegs(self):
        with tempfile.TemporaryDirectory() as td:
            path=pathlib.Path(td)/"incomplete.zip"
            with zipfile.ZipFile(path,"w") as z:
                z.writestr("mot/gt/gt.txt",
                    "".join(f"{f},1,10,10,8,8,1,1,1\n"
                            for f in range(1,4)))
                z.writestr("mot/img1/000001.jpg",b"x")
                z.writestr("mot/img1/000002.jpg",b"x")
            with self.assertRaisesRegex(ValueError,"frame image coverage"):
                m.original_zip_gt(path,3)

if __name__=="__main__":
    unittest.main()
