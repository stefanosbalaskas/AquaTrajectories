#!/usr/bin/env python3
"""Independent audit of Milestone 08 source-based reference measurement output.

Does not call M08 matcher, analyzer, renderer, or summary functions.
Uses independent sparse maximum bipartite matching for cardinality validation.
"""
from __future__ import annotations
import argparse,csv,hashlib,json,math
from pathlib import Path
from collections import defaultdict
import numpy as np
from scipy.sparse import csr_matrix
from scipy.sparse.csgraph import maximum_bipartite_matching

SRC_FILES={"M07_FRAMES.csv","M07_OBSERVATIONS.csv","M07_PER_SEQUENCE_SOURCE_COUNTS.csv"}

def read(p):
    with open(p,newline='',encoding='utf8') as f:return list(csv.DictReader(f))

def sha(p):
    h=hashlib.sha256()
    with open(p,'rb') as f:
        for ch in iter(lambda:f.read(1<<20),b''):h.update(ch)
    return h.hexdigest()

def close(a,b,eps=1e-7):
    if a is None or b is None:return a is None and b is None
    return math.isfinite(float(a)) and math.isfinite(float(b)) and abs(float(a)-float(b)) <=eps*max(1,abs(float(a)),abs(float(b)))

def check(condition,msg):
    if not condition:raise AssertionError(msg)

def box_iou(r,p):
    x1=max(float(r['bbox_left']),float(p['bbox_left']))
    y1=max(float(r['bbox_top']),float(p['bbox_top']))
    x2=min(float(r['bbox_left'])+float(r['bbox_width']),float(p['bbox_left'])+float(p['bbox_width']))
    y2=min(float(r['bbox_top'])+float(r['bbox_height']),float(p['bbox_top'])+float(p['bbox_height']))
    inter=max(0,x2-x1)*max(0,y2-y1)
    ar=float(r['bbox_width'])*float(r['bbox_height'])
    ap=float(p['bbox_width'])*float(p['bbox_height'])
    return inter/(ar+ap-inter) if ar+ap>inter else 0.

def run(source,output,write_output=None):
    source=Path(source);output=Path(output)
    prov=json.loads((source/'M07_PROVENANCE.json').read_text('utf8'))
    check(set(prov['input_shas'])==SRC_FILES,'Missing original M07 input digest')
    for f,expect in prov['input_shas'].items():check(sha(source/f)==expect,'Source modified: '+f)
    obs=read(source/'M07_OBSERVATIONS.csv')
    frame=read(source/'M07_FRAMES.csv')
    check(all(not r['time_s'] for r in frame),'Physical source time unexpectedly provided')
    pairs=read(output/'tables'/'M08_MATCHED_OBSERVATIONS.csv')
    ref_ledger=read(output/'tables'/'M08_REFERENCE_LEDGER.csv')
    model_ledger=read(output/'tables'/'M08_MODEL_LEDGER.csv')
    adjacent=read(output/'tables'/'M08_REFERENCE_ADJACENT_STEPS.csv')
    group=read(output/'tables'/'M08_FRAME_GROUP_GEOMETRY.csv')
    sums=read(output/'tables'/'M08_SEQUENCE_SUMMARIES.csv')
    sens=read(output/'tables'/'M08_IOU_SENSITIVITY.csv')
    scientific=json.loads((output/'M08_SCIENTIFIC_RESULTS.json').read_text('utf8'))
    manifest=json.loads((output/'M08_OUTPUT_MANIFEST.json').read_text('utf8'))
    check(manifest['source_provenance_sha256']==sha(source/'M07_PROVENANCE.json'),'Wrong source provenance')
    check(all(sha(output/name)==digest for name,digest in manifest['output_sha256'].items()),'Output digest mismatch')
    check(scientific['published_GT_used_only_at_evaluation'] is True,'GT source not segregated')
    check(scientific['physical_calibration_available'] is False,'Invalid physical calibration claim')
    threshold=float(scientific['primary_iou'])
    ref=[(i,r) for i,r in enumerate(obs,1) if r['data_path']=='reference']
    mod=[(i,r) for i,r in enumerate(obs,1) if r['data_path']=='model']
    check(len(ref)==len(ref_ledger) and len(mod)==len(model_ledger),'Missing raw GT/model ledger rows')
    ref_by_source={i:r for i,r in ref};mod_by_source={i:r for i,r in mod}
    frame_group=defaultdict(lambda: {'reference':[],'model':[]})
    for i,r in enumerate(obs,1):frame_group[(r['session_id'],r['camera_id'],int(r['frame_id']))][r['data_path']].append((i,r))
    pairs_by_frame=defaultdict(list);pairs_by_ref={};pairs_by_mod={}
    pos_errors=[]
    for pair in pairs:
        ir=int(pair['reference_source_row']);ip=int(pair['model_source_row'])
        check(ir in ref_by_source and ip in mod_by_source,'Illegal reference/model source row')
        a=ref_by_source[ir];b=mod_by_source[ip]
        check(ir not in pairs_by_ref and ip not in pairs_by_mod,'Duplicate association')
        check((a['session_id'],a['camera_id'],a['frame_id']) ==
              (b['session_id'],b['camera_id'],b['frame_id']),'Cross-camera/frame association')
        check(pair['reference_track_id']==a['track_id'] and pair['model_track_id']==b['track_id'],'Track identity mismatch')
        iou=box_iou(a,b)
        check(iou+1e-10>=threshold and close(iou,pair['iou']),'IoU mismatch')
        err=math.dist((float(a['x']),float(a['y'])),(float(b['x']),float(b['y'])))
        check(close(err,pair['position_error_px']),'Position geometry mismatch')
        pos_errors.append(err)
        frameid=(a['session_id'],a['camera_id'],int(a['frame_id']))
        pairs_by_frame[frameid].append((ir,ip))
        pairs_by_ref[ir]=ip;pairs_by_mod[ip]=ir
    matched_ref=set(pairs_by_ref);matched_mod=set(pairs_by_mod)
    check(len({int(x['source_row']) for x in ref_ledger})==len(ref) and
          len({int(x['source_row']) for x in model_ledger})==len(mod),'Incomplete ledger row keys')
    for ledger,source_ids,status_true in [(ref_ledger,matched_ref,'matched'),(model_ledger,matched_mod,'matched')]:
        for row in ledger:
            idx=int(row['source_row'])
            check((row['evaluation_status']==status_true)==(idx in source_ids),'Incorrect match eligibility')
    maxcard_checks=0
    thresholds=[float(t['iou_threshold']) for t in sens]
    card_counts={t:0 for t in thresholds}
    for key,pool in sorted(frame_group.items()):
        a=pool['reference'];b=pool['model']
        actual=pairs_by_frame[key]
        for t in thresholds:
            if not a or not b:continue
            # Completely separate sparse cardinality oracle, not Hungarian cost minimization.
            edges=np.asarray([[box_iou(x[1],y[1])>=t for y in b] for x in a],dtype=np.int8)
            graph=csr_matrix(edges)
            maxcard=int(np.count_nonzero(maximum_bipartite_matching(graph,perm_type='row')!=-1))
            card_counts[t]+=maxcard
            if close(t,threshold):
                check(len(actual)==maxcard,'Hungarian matching did not maximize cardinality: '+str(key))
            maxcard_checks+=1
    for t in sens:
        check(card_counts[float(t['iou_threshold'])]==int(t['n_matched']),
              'IoU sensitivity association cardinality is not independently optimal')
    ref_keys=defaultdict(list)
    for i,r in ref:ref_keys[(r['session_id'],r['camera_id'],r['track_id'])].append((int(r['frame_id']),i,r))
    independent_steps={}
    for (seq,cam,tid),rows in ref_keys.items():
        rows.sort()
        for (f0,i0,a),(f1,i1,b) in zip(rows,rows[1:]):
            if f1!=f0+1:continue
            reference_step=math.dist((float(a['x']),float(a['y'])),(float(b['x']),float(b['y'])))
            status='unmatched_endpoint'
            model_step=abs_err=None
            if i0 in pairs_by_ref and i1 in pairs_by_ref:
                j0,j1=pairs_by_ref[i0],pairs_by_ref[i1]
                if mod_by_source[j0]['track_id']==mod_by_source[j1]['track_id']:
                    status='matched_same_id'
                    p=mod_by_source[j0];q=mod_by_source[j1]
                    model_step=math.dist((float(p['x']),float(p['y'])),(float(q['x']),float(q['y'])))
                    abs_err=abs(model_step-reference_step)
                else:status='model_id_discontinuity'
            independent_steps[(seq,cam,tid,f0,f1)]=(reference_step,status,model_step,abs_err)
    check(len(adjacent)==len(independent_steps),'Reference-adjacent step denominator changed')
    for r in adjacent:
        k=(r['session_id'],r['camera_id'],r['reference_track_id'],int(r['frame_start']),int(r['frame_end']))
        check(k in independent_steps,'Unexpected reference step')
        truth,status,mdl,err=independent_steps.pop(k)
        check(r['status']==status and close(r['reference_step_px'],truth),'Step type/reference mismatch')
        if status=='matched_same_id':
            check(close(r['model_step_px'],mdl) and close(r['absolute_step_error_px'],err),'Paired error mismatch')
        else:check(not r['model_step_px'] and not r['absolute_step_error_px'],'Unsupported step fabricated')
    check(not independent_steps,'Missing original adjacent steps')
    # Group geometry independent per frame, with source-mask-specific subset selection.
    checked_group=0
    for r in group:
        k=(r['session_id'],r['camera_id'],int(r['frame_id']))
        pop=frame_group[k];g=pop['reference'];p=pop['model']
        check(int(r['n_reference'])==len(g) and int(r['n_model'])==len(p) and int(r['n_matched'])==len(pairs_by_frame[k]),'Group denominators drift')
        ids=pairs_by_frame[k]
        if len(ids)<2:
            check(not r['reference_matched_rg_px'] and not r['model_matched_rg_px'],'Unsupported school geometry fabricated')
            continue
        def radius(points):
            v=np.asarray(points,dtype=float)
            centroid=np.asarray([sum(v[:,0])/len(v),sum(v[:,1])/len(v)])
            return math.sqrt(sum((x-centroid[0])**2+(y-centroid[1])**2 for x,y in v)/len(v))
        truth=radius([(float(ref_by_source[i]['x']),float(ref_by_source[i]['y'])) for i,j in ids])
        predicted=radius([(float(mod_by_source[j]['x']),float(mod_by_source[j]['y'])) for i,j in ids])
        check(close(truth,r['reference_matched_rg_px']) and close(predicted,r['model_matched_rg_px']),'Group radius mismatch')
        checked_group+=1
    values=[]
    for seqrow in sums:
        seq=seqrow['sequence']
        expected_matches=sum(p['session_id']==seq for p in pairs)
        expected_ref=sum(r['session_id']==seq for i,r in ref)
        expected_step=sum(r['session_id']==seq for r in adjacent)
        expected_good=sum(r['session_id']==seq and r['status']=='matched_same_id' for r in adjacent)
        check(int(seqrow['n_reference'])==expected_ref and int(seqrow['n_matched'])==expected_matches
              and int(seqrow['n_reference_adjacent_steps'])==expected_step
              and int(seqrow['n_paired_same_id_steps'])==expected_good,'Per-video denominator mismatch')
        values.append(seq)
    check(len(values)==len(set(values))==5,'Unexpected real sequence scope')
    pooled=scientific['pooled_descriptive']
    check(int(pooled['n_matched'])==len(pairs) and int(pooled['n_reference_adjacent_steps'])==len(adjacent),'Pooled counts mismatch')
    if pos_errors:check(close(float(np.median(pos_errors)),pooled['median_position_error_px']),'Pooled median mismatch')
    out={"schema":"AQT_M08_INDEPENDENT_SOURCE_MEASUREMENT_ORACLE_V1","status":"PASS",
      "independent_sparse_matching_cardinality_checks":maxcard_checks,
      "source_observation_sha256":sha(source/'M07_OBSERVATIONS.csv'),
      "source_frame_sha256":sha(source/'M07_FRAMES.csv'),
      "matched_source_iou_and_position_checks":len(pairs),
      "reference_step_checks":len(adjacent),
      "matched_group_geometry_checks":checked_group,
      "reference_ledger_rows":len(ref_ledger),"model_ledger_rows":len(model_ledger),
      "sensitivity_independent_cardinality":{str(t):v for t,v in card_counts.items()},
      "no_biological_or_physical_accuracy_certification":True,
      "image_space_reference_conditional_only":True,
      "source_outputs_untouched":True}
    if write_output:
        dest=Path(write_output)
        if dest.exists():raise FileExistsError('Refuse overwriting prior audit')
        dest.write_text(json.dumps(out,indent=2,sort_keys=True)+'\n',encoding='utf8')
    print('M08_INDEPENDENT_REFERENCE_ORACLE_PASS',json.dumps({k:out[k] for k in ['matched_source_iou_and_position_checks','reference_step_checks','matched_group_geometry_checks','independent_sparse_matching_cardinality_checks']},sort_keys=True))
    return out

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--input',required=True,type=Path)
    p.add_argument('--result',required=True,type=Path)
    p.add_argument('--out',required=True,type=Path)
    a=p.parse_args()
    run(a.input,a.result,write_output=a.out)
