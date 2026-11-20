#!/usr/bin/env python3
"""Compare independent Python and native R frame-index science tables.

No standalone certification if the R output is missing. Fail closed; do not
substitute Python figures for R verification, and do not tolerate scope drift.
"""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path

def read(path):
    with Path(path).open(newline='',encoding='utf-8-sig') as f:return list(csv.DictReader(f))

def keyed(rows):
    d={}
    for row in rows:
        k=(row['data_path'],row['session_id'],row['camera_id'])
        if k in d:raise ValueError('Duplicate scientific analysis scope')
        d[k]=row
    return d

def compare(r_dir,py_dir,out):
    r_dir=Path(r_dir);py_dir=Path(py_dir);out=Path(out)
    if out.exists():raise FileExistsError('Parity report destination exists')
    rp=r_dir/'tables'/'M07_PER_SEQUENCE_SUMMARY.csv'
    yp=py_dir/'tables'/'PER_SEQUENCE_FRAME_SCIENCE.csv'
    r=keyed(read(rp)); p=keyed(read(yp))
    if set(r)!=set(p) or len(r)!=10:
        raise ValueError('R and Python scope denominators disagree')
    ints=['n_recorded_frames','n_frames_with_observations',
          'n_frames_without_observations','n_observations',
          'n_local_track_labels','n_adjacent_frame_steps',
          'n_unbridged_within_track_gaps','n_frames_with_pair_geometry']
    diffs=[];maxerr=0.
    for scope in sorted(r):
        rr=r[scope];pp=p[scope]
        for k in ints:
            if int(rr[k])!=int(pp[k]):
                diffs.append({'scope':scope,'metric':k,'r':rr[k],'python':pp[k]})
        a=float(rr['observed_path_sum_px']);b=float(pp['observed_path_sum_px'])
        err=abs(a-b)
        maxerr=max(err,maxerr)
        if err>max(1e-8,1e-10*max(abs(a),abs(b))):
            diffs.append({'scope':scope,'metric':'observed_path_sum_px','r':a,'python':b})
    rep={'protocol':'AQT_M07_CROSS_LANGUAGE_SCIENCE_PARITY_V1',
         'n_scopes':len(r),'n_metrics_checked_per_scope':len(ints)+1,
         'max_absolute_path_sum_discrepancy_px':maxerr,
         'pass':not diffs,'differences':diffs,
         'interpretation':'Numerical software parity, not biological identity truth or empirical physical-time validation'}
    out.write_text(json.dumps(rep,indent=2)+'\n',encoding='utf8')
    if diffs:raise ValueError('R/Python independent numerical parity FAILED; inspect '+str(out))
    print('M07_R_PYTHON_REAL_DATA_NUMERICAL_PARITY_PASS 10 scopes * 9 metrics')
    return rep

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--r-report',required=True,type=Path)
    p.add_argument('--python-report',required=True,type=Path)
    p.add_argument('--out',required=True,type=Path)
    a=p.parse_args();compare(a.r_report,a.python_report,a.out)
if __name__=='__main__':main()
