import csv, tempfile, unittest, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "inst" / "python"))
from aqt_m09_external_physical_gate import validate

class SourceStructureOnly(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name)
  self.s=self.root/'survey.csv';self.p=self.root/'pred.csv';self.g=self.root/'split.csv'
  self.write(self.s,[{'experiment_id':'SYNTHETIC_NOT_PHYSICAL_EVIDENCE','session_id':'a','board_pose_id':'hold','landmark_id':str(i),'reference_x_mm':str(10*i),'reference_y_mm':str(5*i),'reference_z_mm':str(20*i),'reference_uncertainty_mm':'0.3','reference_method':'surveyed_physical_target','reference_operator_id':'synthetic_only','source_evidence_sha256':'a'*64} for i in (1,2,3)])
  self.write(self.p,[{'experiment_id':'SYNTHETIC_NOT_PHYSICAL_EVIDENCE','session_id':'a','board_pose_id':'hold','landmark_id':str(i),'pred_x_mm':str(10*i+2),'pred_y_mm':str(5*i+1),'pred_z_mm':str(20*i+3),'reconstruction_version':'synthetic','prediction_source_sha256':'b'*64} for i in (1,2,3)])
  self.write(self.g,[{'experiment_id':'SYNTHETIC_NOT_PHYSICAL_EVIDENCE','board_pose_id':'fit','split_role':'fit'},{'experiment_id':'SYNTHETIC_NOT_PHYSICAL_EVIDENCE','board_pose_id':'hold','split_role':'holdout'}])
 def tearDown(self):self.tmp.cleanup()
 def write(self,path,rows):
  with path.open('w',newline='') as f:
   w=csv.DictWriter(f,fieldnames=rows[0].keys());w.writeheader();w.writerows(rows)
 def test_synthetic_only_numerical_oracle(self):
  r=validate(self.s,self.p,self.g)
  self.assertEqual(r['status'],'CONDITIONAL_ERROR_CALCULATION_ONLY_NOT_INDEPENDENTLY_CERTIFIED')
  self.assertEqual(r['n_holdout_matched_predictions'],3)
  self.assertEqual(r['bias_xyz_mm'],[2.0,1.0,3.0])
  self.assertAlmostEqual(r['euclidean_rmse_mm'],(14)**0.5)
  self.assertTrue(r['submitted_reference_independence_not_externally_certified'])
 def test_same_reference_and_prediction_source_fails(self):
  with self.p.open(newline='') as f:rows=list(csv.DictReader(f))
  for x in rows:x['prediction_source_sha256']='a'*64
  self.write(self.p,rows)
  with self.assertRaisesRegex(ValueError,'same source blob'):validate(self.s,self.p,self.g)
 def test_unregistered_poses_fail(self):
  with self.g.open(newline='') as f:rows=list(csv.DictReader(f));rows.pop();self.write(self.g,rows)
  with self.assertRaisesRegex(ValueError,'separately labeled'):validate(self.s,self.p,self.g)
 def test_synthetic_xyz_cannot_be_mislabeled_as_survey(self):
  with self.s.open(newline='') as f:rows=list(csv.DictReader(f));rows[0]['reference_method']='source_reconstruction';self.write(self.s,rows)
  with self.assertRaisesRegex(ValueError,'surveyed physical truth'):validate(self.s,self.p,self.g)
 def test_duplicate_source_fails(self):
  with self.s.open(newline='') as f:rows=list(csv.DictReader(f));rows.append(rows[0]);self.write(self.s,rows)
  with self.assertRaisesRegex(ValueError,'Duplicate'):validate(self.s,self.p,self.g)

if __name__=='__main__':unittest.main()