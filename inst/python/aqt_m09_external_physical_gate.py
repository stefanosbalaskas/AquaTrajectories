#!/usr/bin/env python3
"""AquaTrajectories external physical-target *audit*, not a certification.

Stdlib-only. All executed synthetic tests are software tests. The tool never
claims independent survey truth or biological accuracy solely from user CSVs.
Inputs and outputs are immutable and report-level SHA256 is recorded.
"""
import argparse,csv,hashlib,json,math,statistics
from pathlib import Path

REQ_SURVEY=('experiment_id','session_id','board_pose_id','landmark_id','reference_x_mm','reference_y_mm','reference_z_mm','reference_uncertainty_mm','reference_method','reference_operator_id','source_evidence_sha256')
REQ_PRED=('experiment_id','session_id','board_pose_id','landmark_id','pred_x_mm','pred_y_mm','pred_z_mm','reconstruction_version','prediction_source_sha256')
REQ_SPLIT=('experiment_id','board_pose_id','split_role')
KEY=('experiment_id','session_id','board_pose_id','landmark_id')

def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def read_csv(path,columns):
 p=Path(path)
 if not p.is_file():raise FileNotFoundError(f'Missing original source: {p}')
 with p.open(newline='',encoding='utf-8-sig') as f:
  r=csv.DictReader(f)
  if r.fieldnames is None or not set(columns)<=set(r.fieldnames):raise ValueError(f'Schema missing: {set(columns)-set(r.fieldnames or [])}')
  rows=list(r)
 if not rows:raise ValueError(f'Empty evidence: {p}')
 return rows

def finite(row,fields):
 vals=[]
 for name in fields:
  try:z=float(row[name])
  except (TypeError,ValueError):raise ValueError(f'Unparsable {name}')
  if not math.isfinite(z):raise ValueError(f'Nonfinite {name}')
  vals.append(z)
 return vals

def unique(rows,keys,typ):
 seen=set()
 for row in rows:
  k=tuple(row[x] for x in keys)
  if any(not q.strip() for q in k):raise ValueError(f'Blank {typ} key')
  if k in seen:raise ValueError(f'Duplicate {typ} key: {k}')
  seen.add(k)
 return seen

def validate(survey_file,pred_file,split_file):
 survey=read_csv(survey_file,REQ_SURVEY);pred=read_csv(pred_file,REQ_PRED);split=read_csv(split_file,REQ_SPLIT)
 su=unique(survey,KEY,'survey');pr=unique(pred,KEY,'predicted');spl=unique(split,('experiment_id','board_pose_id'),'split')
 roles={ (r['experiment_id'],r['board_pose_id']):r['split_role'].strip().lower() for r in split}
 if set(roles.values()) != {'fit','holdout'}:raise ValueError('Need separately labeled fit and holdout board poses')
 for row in survey+pred:
  if (row['experiment_id'],row['board_pose_id']) not in roles:raise ValueError('Unregistered calibration/test board pose')
 holdouts=[r for r in survey if roles[(r['experiment_id'],r['board_pose_id'])]=='holdout']
 if len(holdouts)<2:raise ValueError('At least 2 heldout surveyed target points required')
 for row in survey:
  finite(row,('reference_x_mm','reference_y_mm','reference_z_mm','reference_uncertainty_mm'))
  if float(row['reference_uncertainty_mm'])<=0:raise ValueError('Survey uncertainty must be positive')
  if row['reference_method'].strip().lower() not in ('surveyed_physical_target','surveyed_with_traceable_ruler','independent_metrology'):
   raise ValueError('Source-derived stereo XYZ may not be called surveyed physical truth')
  if not row['reference_operator_id'].strip():raise ValueError('Reference observer/source declaration missing')
  h=row['source_evidence_sha256'].strip()
  if len(h)!=64 or any(c not in '0123456789abcdef' for c in h.lower()):raise ValueError('Need original independent reference file SHA256')
 for row in pred:
  finite(row,('pred_x_mm','pred_y_mm','pred_z_mm'))
  if not row['reconstruction_version'].strip():raise ValueError('Reconstruction version missing')
  h=row['prediction_source_sha256'].strip()
  if len(h)!=64 or any(c not in '0123456789abcdef' for c in h.lower()):raise ValueError('Missing source prediction digest')
 survey_by_key={tuple(x[k] for k in KEY):x for x in holdouts}
 pred_by_key={tuple(x[k] for k in KEY):x for x in pred if roles[(x['experiment_id'],x['board_pose_id'])]=='holdout'}
 overlap=sorted(set(survey_by_key)&set(pred_by_key))
 if not overlap:raise ValueError('No exact target+session+pose+landmark correspondence')
 errors=[]
 for key in overlap:
  sr=survey_by_key[key];p=pred_by_key[key]
  if sr['source_evidence_sha256'].lower()==p['prediction_source_sha256'].lower():
   raise ValueError('Reference and model prediction appear to share the same source blob')
  r=finite(sr,('reference_x_mm','reference_y_mm','reference_z_mm'))
  q=finite(p,('pred_x_mm','pred_y_mm','pred_z_mm'))
  errors.append([q[i]-r[i] for i in range(3)])
 n=len(errors)
 bias=[statistics.mean(e[i] for e in errors) for i in range(3)]
 mae=[statistics.mean(abs(e[i]) for e in errors) for i in range(3)]
 rmse=[math.sqrt(statistics.mean(e[i]**2 for e in errors)) for i in range(3)]
 norm=[math.sqrt(sum(t*t for t in e)) for e in errors]
 result={'schema':'AQT_M09_EXTERNAL_XYZ_AUDIT_V1','status':'CONDITIONAL_ERROR_CALCULATION_ONLY_NOT_INDEPENDENTLY_CERTIFIED',
    'n_original_survey_rows':len(survey),'n_original_prediction_rows':len(pred),
    'n_holdout_survey_points':len(holdouts),'n_holdout_matched_predictions':n,
    'holdout_position_coverage':n/len(holdouts),'bias_xyz_mm':bias,'mae_xyz_mm':mae,'rmse_xyz_mm':rmse,
    'euclidean_mae_mm':statistics.mean(norm),'euclidean_rmse_mm':math.sqrt(statistics.mean(t*t for t in norm)),
    'submitted_reference_independence_not_externally_certified':True,
    'biological_identity_certified':False,'calibration_fit_correctness_certified':False,
    'interpretation':'Source-defined XYZ errors for supplied holdout correspondences; not third-party external biological or physical certification',
    'sha256':{'survey':digest(survey_file),'predictions':digest(pred_file),'split_roles':digest(split_file)}}
 return result

def main():
 a=argparse.ArgumentParser();a.add_argument('--survey',required=True);a.add_argument('--predictions',required=True);a.add_argument('--board-splits',required=True);a.add_argument('--out',required=True);o=a.parse_args()
 dest=Path(o.out)
 if dest.exists():raise FileExistsError('Evidence output already exists; original results are immutable')
 if not dest.parent.is_dir():raise FileNotFoundError('Output parent must exist')
 results=validate(o.survey,o.predictions,o.board_splits)
 dest.write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8')
 print('M09_CONDITIONAL_XYZ_SOURCE_AUDIT_COMPLETE',results['n_holdout_matched_predictions'])
 print('NOT_INDEPENDENTLY_CERTIFIED - external survey and camera provenance require manual review')

if __name__=='__main__':main()