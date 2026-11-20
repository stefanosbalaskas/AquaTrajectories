#!/usr/bin/env python3
"""Independently audit M06 image-boundary-clipped reference boxes in M08.

No GT/modelling file is changed. Outputs only a declared sensitivity table.
"""
from __future__ import annotations
import argparse,csv,json,hashlib
from pathlib import Path

def read_csv(p):
    with open(p,encoding="utf-8-sig",newline="") as f:return list(csv.DictReader(f))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def compare(input_dir,result_dir,anomaly_path,output_path):
    input_dir,result_dir,anomaly_path,output_path=map(Path,(input_dir,result_dir,anomaly_path,output_path))
    if output_path.exists():raise FileExistsError("Refuse overwriting evidence")
    meta=json.loads((input_dir/'M07_PROVENANCE.json').read_text('utf8'))
    for n,h in meta['input_shas'].items():
        if sha(input_dir/n)!=h:raise ValueError('M07 source integrity mismatch')
    anomalies=read_csv(anomaly_path)
    reference=read_csv(input_dir/'M07_OBSERVATIONS.csv')
    ledger=read_csv(result_dir/'tables/M08_REFERENCE_LEDGER.csv')
    steps=read_csv(result_dir/'tables/M08_REFERENCE_ADJACENT_STEPS.csv')
    pairs=read_csv(result_dir/'tables/M08_MATCHED_OBSERVATIONS.csv')
    published=[(i,r) for i,r in enumerate(reference,1) if r['data_path']=='reference']
    assert len(published)==len(ledger)==6621
    if len(anomalies)!=6 or any(a['issue']!='partially_outside_image_clipped_for_evaluation' for a in anomalies):
        raise ValueError('Expected six original audited partially clipped real references')
    clipped=set()
    for z in anomalies:
        if z['sequence']!='brackishMOT-55' or float(z['source_x'])!=-2.0 or float(z['derived_x'])!=0:
            raise ValueError('Unrecognized physical image clipping case')
        matches=[(i,r) for i,r in published if
            r['session_id']==z['sequence'] and str(r['track_id'])==str(z['source_track_id']) and int(r['frame_id'])==int(z['frame'])-1]
        if len(matches)!=1:raise ValueError('Source clipped annotation not uniquely found')
        i,r=matches[0]
        if abs(float(r['bbox_left'])-float(z['derived_x']))>1e-9 or abs(float(r['bbox_width'])-float(z['derived_w']))>1e-9:
            raise ValueError('M07 geometry disagrees with frozen M06 clip audit')
        clipped.add((r['session_id'],str(r['track_id']),int(r['frame_id'])))
    if len(clipped)!=6:raise ValueError('Duplicate source clip cases')
    paired_gt=set((r['session_id'],str(r['reference_track_id']),int(r['frame_id'])) for r in pairs)
    matched_clip=len(clipped & paired_gt)
    touching=[s for s in steps if
       (s['session_id'],str(s['reference_track_id']),int(s['frame_start'])) in clipped or
       (s['session_id'],str(s['reference_track_id']),int(s['frame_end'])) in clipped]
    if matched_clip!=0 or len(touching)!=8 or any(x['status']!='unmatched_endpoint' for x in touching):
        raise ValueError('Source clip influences matched measurement error; audit sensitivity separately')
    n_ref=len(published)
    n_match=len(pairs)
    n_steps=len(steps)
    n_good=sum(r['status']=='matched_same_id' for r in steps)
    result={
      'schema':'AQT_M08_M06_CLIPPED_SOURCE_SENSITIVITY_V1',
      'status':'PASS',
      'source_anomaly_ledger_sha256':sha(anomaly_path),
      'original_publisher_mot_annotations_unchanged':True,
      'evaluation_only_geometry_clipped':True,
      'n_source_reference_boxes_clipped':len(clipped),
      'n_clipped_boxes_matched':matched_clip,
      'n_reference_adjacent_steps_touching_clipped_boxes':len(touching),
      'n_clipped_touching_steps_eligible_for_error':0,
      'all_reference_match_fraction':n_match/n_ref,
      'excluding_six_clipped_reference_match_fraction':n_match/(n_ref-len(clipped)),
      'all_reference_step_pair_fraction':n_good/n_steps,
      'excluding_eight_clipped_touched_steps_pair_fraction':n_good/(n_steps-len(touching)),
      'point_and_step_conditional_error_values_unchanged_by_this_exclusion':True,
      'independent_physical_or_biological_ground_truth_certified':False,
    }
    output_path.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n',encoding='utf8')
    print('M08_M06_CLIPPED_SOURCE_SENSITIVITY_PASS',len(clipped),'clipped GT,',len(touching),'touching steps')
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--input',required=True,type=Path)
    p.add_argument('--result',required=True,type=Path)
    p.add_argument('--m06-anomalies',required=True,type=Path)
    p.add_argument('--out',required=True,type=Path)
    a=p.parse_args()
    compare(a.input,a.result,a.m06_anomalies,a.out)
